"""Minimal ISO9660 lister/extractor (handles multi-extent files and >4 GB images).

  python iso_extract.py <iso> list
  python iso_extract.py <iso> extract <outdir> [NAME ...]   (NAME = path like DATA/PZS4US0.AFS)
"""
import os
import struct
import sys

SECTOR = 2048


def read_dir(f, lba, size, prefix, out):
    f.seek(lba * SECTOR)
    data = f.read(size)
    pos = 0
    while pos < len(data):
        ln = data[pos]
        if ln == 0:
            pos = (pos // SECTOR + 1) * SECTOR  # records never straddle sectors
            continue
        rec = data[pos:pos + ln]
        ext = struct.unpack_from("<I", rec, 2)[0]
        dlen = struct.unpack_from("<I", rec, 10)[0]
        flags = rec[25]
        nlen = rec[32]
        name = rec[33:33 + nlen]
        pos += ln
        if name in (b"\x00", b"\x01"):
            continue
        name = name.decode("ascii", "replace").split(";")[0]
        path = prefix + name
        if flags & 2:
            read_dir(f, ext, dlen, path + "/", out)
        else:
            # flag 0x80 = not the final extent: consecutive records share the name
            out.setdefault(path, []).append((ext, dlen))


def entries(iso):
    with open(iso, "rb") as f:
        f.seek(16 * SECTOR)
        pvd = f.read(SECTOR)
        root = pvd[156:156 + 34]
        lba = struct.unpack_from("<I", root, 2)[0]
        size = struct.unpack_from("<I", root, 10)[0]
        out = {}
        read_dir(f, lba, size, "", out)
        return out


def main():
    iso, cmd = sys.argv[1], sys.argv[2]
    ents = entries(iso)
    if cmd == "list":
        for p, exts in ents.items():
            print(f"{sum(e[1] for e in exts):>12}  {len(exts)} ext  lba {exts[0][0]:>8}  {p}")
        return
    outdir = sys.argv[3]
    want = set(sys.argv[4:])
    with open(iso, "rb") as f:
        for p, exts in ents.items():
            if want and p not in want:
                continue
            dst = os.path.join(outdir, *p.split("/"))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as o:
                for lba, ln in exts:
                    f.seek(lba * SECTOR)
                    left = ln
                    while left:
                        chunk = f.read(min(left, 64 << 20))
                        if not chunk:
                            raise SystemExit(f"short read in {p}")
                        o.write(chunk)
                        left -= len(chunk)
            print(f"{p}  {os.path.getsize(dst)}")


if __name__ == "__main__":
    main()
