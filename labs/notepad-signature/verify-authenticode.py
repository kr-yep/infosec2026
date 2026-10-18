"""Verify the course's old installer without running it or changing Windows trust."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

from cryptography import x509
from cryptography.hazmat.primitives import hashes
from signify.authenticode import AuthenticodeFile, TRUSTED_CERTIFICATE_STORE
from signify.x509 import Certificate, CertificateStore

parser = argparse.ArgumentParser()
parser.add_argument("--input", type=Path, default=Path("input"))
parser.add_argument("--output", type=Path, default=Path("output"))
args = parser.parse_args()
installer = args.input / "npp.8.8.3.Installer.x64.exe"
data = installer.read_bytes()
root_pem = (args.input / "nppRoot.crt").read_bytes()
root_x509 = x509.load_pem_x509_certificate(root_pem)
root_fingerprint = root_x509.fingerprint(hashes.SHA1()).hex().upper()
if root_fingerprint != "C80539FF7076D22E73A01F164108DAFBF06E45E4":
    raise ValueError("Root certificate does not match the course fingerprint")

store = TRUSTED_CERTIFICATE_STORE | CertificateStore(
    [Certificate.from_pem(root_pem)], trusted=True)


def verify(content, trust):
    with io.BytesIO(content) as stream:
        signed = AuthenticodeFile.from_stream(stream)
        status, error = signed.explain_verify(
            trusted_certificate_store=trust,
            verification_context_kwargs={"allow_fetching": False},
        )
        return {"status": status.name, "error": str(error) if error else None}


before = verify(data, TRUSTED_CERTIFICATE_STORE)
after = verify(data, store)
# Alter one byte in the first PE section, leaving signature structures intact.
tampered = bytearray(data)
pe = struct.unpack_from("<I", data, 0x3C)[0]
optional_size = struct.unpack_from("<H", data, pe + 20)[0]
first_section = pe + 24 + optional_size
raw_pointer = struct.unpack_from("<I", data, first_section + 20)[0]
if not 0 < raw_pointer < len(data):
    raise ValueError("Unexpected PE section offset")
tampered[raw_pointer] ^= 1
negative = verify(bytes(tampered), store)
assert before["status"] == "CERTIFICATE_ERROR", before
assert after["status"] == "OK", after
assert negative["status"] == "INVALID_DIGEST", negative
result = {
    "installer_sha256": hashlib.sha256(data).hexdigest(),
    "root_sha1": root_fingerprint,
    "root_subject": root_x509.subject.rfc4514_string(),
    "root_not_before": root_x509.not_valid_before_utc.isoformat(),
    "root_not_after": root_x509.not_valid_after_utc.isoformat(),
    "default_store": before, "isolated_store_with_lab_root": after,
    "tampered_first_section": negative,
    "network_revocation_fetching": False,
    "revocation_limit": "Offline verification; no current CRL/OCSP evidence supplied",
    "windows_certificate_store_modified": False,
    "installer_executed": False,
}
args.output.mkdir(parents=True, exist_ok=True)
(args.output / "authenticode.json").write_text(
    json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: value["status"] for key, value in result.items()
                  if isinstance(value, dict)}))
