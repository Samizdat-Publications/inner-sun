"""Tile albedo / normal / emission of a style folder on a checker background for a quick look.

    python pipeline/preview_sheet.py game/assets/bakeoff/blender out.png [scale]
"""
import os
import sys

from PIL import Image

d, out = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
names = sorted({f.rsplit("_", 1)[0] for f in os.listdir(d) if f.endswith("_albedo.png")})
tiles = []
for n in names:
    row = []
    for k in ("albedo", "normal", "emission"):
        p = os.path.join(d, f"{n}_{k}.png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            bg = Image.new("RGBA", im.size, (70, 40, 90, 255) if k != "emission" else (0, 0, 0, 255))
            bg.alpha_composite(im)
            if scale != 1:
                bg = bg.resize((int(bg.width * scale), int(bg.height * scale)), Image.LANCZOS)
            row.append(bg)
    tiles.append(row)
W = max(sum(t.width + 6 for t in r) for r in tiles)
H = sum(max(t.height for t in r) + 6 for r in tiles)
sheet = Image.new("RGB", (W, H), (30, 30, 30))
y = 0
for r in tiles:
    x = 0
    for t in r:
        sheet.paste(t.convert("RGB"), (x, y))
        x += t.width + 6
    y += max(t.height for t in r) + 6
sheet.save(out)
print(out, sheet.size)
