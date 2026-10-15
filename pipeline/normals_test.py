"""Sanity test for pipeline/normals.py: feed it the Blender albedo (a known-good form) and compare against the
real Blender normal pass. Writes harness/out/normals_test/*.png (not part of the game).

    python pipeline/normals_test.py
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import normals  # noqa: E402

SRC = os.path.join(common.ROOT, "game", "assets", "bakeoff", "blender")
OUT = os.path.join(common.ROOT, "harness", "out", "normals_test")
os.makedirs(OUT, exist_ok=True)


def load(n):
    return Image.open(os.path.join(SRC, n)).convert("RGBA")


def over(im, bg=(60, 40, 80)):
    b = Image.new("RGBA", im.size, bg + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")


rows = []
for name, kind in (("room_wall", "wall"), ("reactor", "cyl"), ("crew", "crew")):
    alb = load(name + "_albedo.png")
    true = load(name + "_normal.png")
    for style, scale in (("painted", 1.0), ("pixel", 0.25)):
        a = alb.resize((max(1, int(alb.width * scale)), max(1, int(alb.height * scale))), Image.BOX if scale < 1 else Image.LANCZOS)
        arr = np.asarray(a, np.float32) / 255.0
        if style == "pixel":
            arr[..., 3] = (arr[..., 3] > 0.5).astype(np.float32)
            n = normals.normal_map(arr, bevel_radius=3, bevel_height_px=1.6, detail_gain=6.0,
                                   detail_sigmas=(0.5, 2.0), slope=1.0, quant=4,
                                   cyl={"cx": arr.shape[1] / 2, "radius": arr.shape[1] * 0.3, "height": arr.shape[1] * 0.3} if kind == "cyl" else None)
        else:
            n = normals.normal_map(arr, bevel_radius=10, bevel_height_px=4.0, detail_gain=10.0,
                                   detail_sigmas=(1.0, 6.0), slope=1.0, smooth=0.6,
                                   cyl={"cx": arr.shape[1] / 2, "radius": arr.shape[1] * 0.3, "height": arr.shape[1] * 0.3} if kind == "cyl" else None)
        mine = Image.fromarray(n, "RGBA")
        h = 300
        tiles = [over(a).resize((int(a.width * h / a.height), h), Image.NEAREST),
                 over(mine).resize((int(a.width * h / a.height), h), Image.NEAREST),
                 over(true).resize((int(a.width * h / a.height), h), Image.LANCZOS)]
        W = sum(t.width + 4 for t in tiles)
        row = Image.new("RGB", (W, h), (20, 20, 20))
        x = 0
        for t in tiles:
            row.paste(t, (x, 0))
            x += t.width + 4
        row.save(os.path.join(OUT, f"{name}_{style}.png"))
        print("wrote", f"{name}_{style}.png")
