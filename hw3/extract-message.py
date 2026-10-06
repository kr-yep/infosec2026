"""Extract this assignment's cleartext without changing its signed bytes."""

from pathlib import Path

source = Path("input/dp.src1.asc").read_bytes()
header, separator, remainder = source.partition(b"\n\n")
if not separator or not header.startswith(b"-----BEGIN PGP SIGNED MESSAGE-----"):
    raise ValueError("Expected the assignment's LF armor header")

message, marker, signature = remainder.partition(b"-----BEGIN PGP SIGNATURE-----")
if not marker or not message.endswith(b"\r\n"):
    raise ValueError("Missing signature boundary or final CRLF")
if any(line.startswith(b"- ") for line in message.split(b"\r\n")):
    raise ValueError("Unexpected dash-escaped content; review the source first")

Path("output").mkdir(exist_ok=True)
Path("output/dp.txt").write_bytes(message)
print(f"Extracted {len(message)} bytes, preserving CRLF and the final newline.")
