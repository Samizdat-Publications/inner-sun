"""Unpack FTL's data folder into research_private/ for the FTL parity side track (D052).

    python tools/ftl_unpack.py                 data/ (XML and layout text) into research_private/
    python tools/ftl_unpack.py --list          print the archive index instead
    python tools/ftl_unpack.py --prefix img/   another folder of the archive (big: images)

Reads the installed ftl.dat (FTL 1.6 "PKG" archive) read-only and writes ONLY under
research_private/ftl_<version>_unpacked/, which is git-ignored. Nothing it writes may be committed:
research notes describe behavior in our own words; exact values stay in research_private/
(docs/research/ftl-reference.md, "Firewall").

PKG layout (big-endian), as documented by the modding community (Slipstream's PkgPack):
  b"PKG\\n", u16 header size, u16 entry size, u32 entry count, u32 path region size;
  entries of (u32 path hash, u32 flags << 24 | path offset, u32 data offset, u32 data size,
  u32 unpacked size); then NUL-terminated paths. Flag 1 means zlib-deflated.
"""
import argparse
import os
import re
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402

FTL_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\FTL Faster Than Light"
PRIVATE = os.path.join(paths.ROOT, "research_private")


def read_index(f) -> list:
    if f.read(4) != b"PKG\n":
        raise SystemExit("not a PKG archive (FTL 1.6 or later expected)")
    header_size, entry_size, count, path_size = struct.unpack(">HHII", f.read(12))
    f.seek(header_size)
    raw = f.read(entry_size * count)
    names = f.read(path_size)
    entries = []
    for i in range(count):
        _h, off_flags, data_off, data_size, unpacked = struct.unpack_from(">IIIII", raw, i * entry_size)
        p_off = off_flags & 0xFFFFFF
        name = names[p_off:names.index(b"\0", p_off)].decode("ascii")
        entries.append((name, off_flags >> 24, data_off, data_size, unpacked))
    return entries


def game_version(ftl_dir: str) -> str:
    log = os.path.join(ftl_dir, "FTL.log")
    try:
        with open(log, encoding="utf-8", errors="replace") as f:
            first = f.readline()
        if first.startswith("Version:"):
            return re.sub(r"[^0-9A-Za-z._-]", "", first.split(":", 1)[1]) or "unknown"
    except OSError:
        pass
    return "unknown"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ftl-dir", default=FTL_DIR)
    ap.add_argument("--prefix", default="data/")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args(argv)
    dat = os.path.join(a.ftl_dir, "ftl.dat")
    out = os.path.join(PRIVATE, "ftl_%s_unpacked" % game_version(a.ftl_dir))
    with open(dat, "rb") as f:
        entries = read_index(f)
        if a.list:
            for name, flags, _off, _size, unpacked in entries:
                print("%10d %02x %s" % (unpacked, flags, name))
            return 0
        n = 0
        for name, flags, data_off, data_size, unpacked in entries:
            if not name.startswith(a.prefix):
                continue
            dest = os.path.abspath(os.path.join(out, name))
            if not dest.startswith(os.path.abspath(out) + os.sep):
                print("skip unsafe path %s" % name, file=sys.stderr)
                continue
            f.seek(data_off)
            data = f.read(data_size)
            if flags & 1:
                data = zlib.decompress(data)
            if len(data) != unpacked:
                print("size mismatch %s: %d != %d" % (name, len(data), unpacked), file=sys.stderr)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as w:
                w.write(data)
            n += 1
    print("ftl_unpack: %d files under %s" % (n, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
