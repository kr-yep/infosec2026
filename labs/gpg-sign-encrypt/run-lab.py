"""Run the GPG exercise using temporary, fictional identities only."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


GPG = os.environ.get("GPG") or shutil.which("gpg")
if not GPG:
    raise SystemExit("Install GnuPG or set GPG to its executable path.")
OUTPUT = Path("output")
OUTPUT.mkdir(exist_ok=True)
WORK = Path(tempfile.mkdtemp(prefix="infosec-gpg-"))
EVENTS = []


def home_arg(path):
    text = path.as_posix()
    # Git for Windows' MSYS build requires POSIX home paths.
    if os.name == "nt" and "/git/" in GPG.replace("\\", "/").lower():
        text = "/" + text[0].lower() + text[2:]
    return text


def run(role, args, *, expected=0, record=None):
    home = WORK / role
    home.mkdir(exist_ok=True)
    result = subprocess.run(
        [GPG, "--homedir", home_arg(home), "--batch", "--yes",
         "--pinentry-mode", "loopback", "--passphrase", "", *map(str, args)],
        capture_output=True, timeout=60,
    )
    if result.returncode != expected:
        raise RuntimeError(f"{role}: {args[0]}: {result.stderr.decode(errors='replace')}")
    if record:
        EVENTS.append({"case": record, "exit_code": result.returncode,
                       "stdout": result.stdout.decode(errors="replace"),
                       "stderr": result.stderr.decode(errors="replace")})
    return result


def fingerprint(role):
    result = run(role, ["--with-colons", "--list-keys"])
    return next(line.split(":")[9] for line in result.stdout.decode().splitlines()
                if line.startswith("fpr:"))


for role in ("alice", "bob"):
    run(role, ["--quick-generate-key", f"{role.title()} Lab <{role}@example.invalid>",
               "ed25519", "sign", "0"])
    run(role, ["--quick-add-key", fingerprint(role), "cv25519", "encrypt", "0"])
alice, bob = fingerprint("alice"), fingerprint("bob")
for role in ("alice", "bob"):
    public = OUTPUT / f"{role}-public.asc"
    public.write_bytes(run(role, ["--armor", "--export", fingerprint(role)]).stdout)
run("alice", ["--import", OUTPUT / "bob-public.asc"])
run("bob", ["--import", OUTPUT / "alice-public.asc"])
run("verifier", ["--import", OUTPUT / "alice-public.asc"])
original = b"Information security lab: sign, encrypt, decrypt, and verify.\n"
message = OUTPUT / "message.txt"
message.write_bytes(original)

run("alice", ["--trust-model", "always", "--local-user", alice, "--recipient", bob,
              "--output", OUTPUT / "message.gpg", "--sign", "--encrypt", message])
run("bob", ["--status-fd", "1", "--no-auto-key-retrieve", "--output",
            OUTPUT / "decrypted.txt", "--decrypt", OUTPUT / "message.gpg"],
    record="bob_decrypts_and_verifies")
assert (OUTPUT / "decrypted.txt").read_bytes() == original
run("verifier", ["--status-fd", "1", "--no-auto-key-retrieve", "--output",
                 WORK / "unauthorized.txt", "--decrypt", OUTPUT / "message.gpg"],
    expected=2, record="public_key_only_cannot_decrypt")
run("alice", ["--local-user", alice, "--armor", "--output", OUTPUT / "message.sig.asc",
              "--detach-sign", message])
run("verifier", ["--status-fd", "1", "--no-auto-key-retrieve", "--verify",
                 OUTPUT / "message.sig.asc", message], record="detached_signature_valid")
tampered = WORK / "tampered.txt"
tampered.write_bytes(original.replace(b"security", b"insecure"))
run("verifier", ["--status-fd", "1", "--no-auto-key-retrieve", "--verify",
                 OUTPUT / "message.sig.asc", tampered],
    expected=1, record="tampered_message_rejected")
result = {"gpg_version": run("verifier", ["--version"]).stdout.decode().splitlines()[0],
          "alice_fingerprint": alice, "bob_fingerprint": bob,
          "original_equals_decrypted": True,
          "message_sha256": hashlib.sha256(original).hexdigest(), "cases": EVENTS}
(OUTPUT / "verification.json").write_text(
    json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"passed": len(EVENTS), "original_equals_decrypted": True,
                  "private_keyrings": "temporary local directory, never exported"}))
