"""Compare two EE RAM dumps (PS2X_DETDUMP) and list the differing ranges.

    python ramdiff.py p1/ram_60.bin p2/ram_60.bin [gap]

Ranges closer than `gap` bytes (default 64) are merged; each line shows the first bytes of both sides,
so the cause of a desync can be named by address.
"""
import sys

a = open(sys.argv[1], "rb").read()
b = open(sys.argv[2], "rb").read()
gap = int(sys.argv[3]) if len(sys.argv) > 3 else 64
BLOCK = 4096
diffs = []
for off in range(0, min(len(a), len(b)), BLOCK):
    if a[off:off + BLOCK] != b[off:off + BLOCK]:
        for i in range(off, min(off + BLOCK, len(a))):
            if a[i] != b[i]:
                diffs.append(i)
ranges = []
for i in diffs:
    if ranges and i - ranges[-1][1] <= gap:
        ranges[-1][1] = i
    else:
        ranges.append([i, i])
print(f"{len(diffs)} bytes differ in {len(ranges)} ranges")
for s, e in ranges[:60]:
    n = min(16, e - s + 1)
    print(f"0x{s:07x}-0x{e:07x} ({e - s + 1:6} B)  A {a[s:s + n].hex()}  B {b[s:s + n].hex()}")
