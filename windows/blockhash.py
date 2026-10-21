"""Hashes of the 256-byte chunks of one 64 KB block of an EE RAM dump, to compare two machines without moving dumps.

    python blockhash.py ram_60.bin 1ef            -> "<offset> <hash>" for every non-zero chunk
    python blockhash.py ram_60.bin 1ef 0x1eff800 0x1effa00   -> also a hex dump of that range
"""
import hashlib
import sys

ram = open(sys.argv[1], "rb").read()
base = int(sys.argv[2], 16) * 0x10000
for off in range(base, base + 0x10000, 256):
    chunk = ram[off:off + 256]
    if any(chunk):
        print(f"{off:07x} {hashlib.sha1(chunk).hexdigest()[:12]}")
if len(sys.argv) > 4:
    lo, hi = int(sys.argv[3], 16), int(sys.argv[4], 16)
    for off in range(lo, hi, 16):
        print(f"{off:07x}: {ram[off:off + 16].hex(' ')}")
