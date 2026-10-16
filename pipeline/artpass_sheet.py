"""Labeled contact sheets for the art pass.

    python pipeline/artpass_sheet.py cands out.jpg prefix [prefix ...]   candidates matching name prefixes
    python pipeline/artpass_sheet.py files out.jpg path[|label] ...      arbitrary images (alpha on checker)
Options: --cell N (cell size, default 360) --cols N
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def checker(size, s=12):
    im = Image.new("RGB", size, (60, 60, 70))
    d = ImageDraw.Draw(im)
    for y in range(0, size[1], s):
        for x in range(0, size[0], s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=(90, 90, 100))
    return im


def sheet(items, out, cell=360, cols=4):
    rows = (len(items) + cols - 1) // cols
    W, H = cols * (cell + 6), rows * (cell + 22)
    sh = Image.new("RGB", (W, H), (20, 20, 20))
    d = ImageDraw.Draw(sh)
    for i, (path, label) in enumerate(items):
        im = Image.open(path).convert("RGBA")
        sc = min(cell / im.width, cell / im.height)
        im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.LANCZOS)
        bg = checker(im.size)
        bg.paste(im, mask=im.split()[3])
        x, y = (i % cols) * (cell + 6), (i // cols) * (cell + 22)
        sh.paste(bg, (x, y + 16))
        d.text((x + 2, y + 2), label, fill=(255, 220, 160))
    sh.save(out, quality=88)
    print(out, sh.size)


if __name__ == "__main__":
    a = list(sys.argv[1:])
    cell = int(a[a.index("--cell") + 1]) if "--cell" in a else 360
    cols = int(a[a.index("--cols") + 1]) if "--cols" in a else 4
    for opt in ("--cell", "--cols"):
        if opt in a:
            i = a.index(opt)
            del a[i:i + 2]
    mode, out, rest = a[0], a[1], a[2:]
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    items = []
    if mode == "cands":
        for pre in rest:
            for p in sorted(glob.glob(os.path.join(ROOT, "harness", "out", "artpass_cands", pre + "*.png"))):
                items.append((p, os.path.basename(p)[:-4]))
    else:
        for r in rest:
            p, _, l = r.partition("|")
            items.append((p, l or os.path.basename(p)))
    sheet(items, out, cell, cols)
