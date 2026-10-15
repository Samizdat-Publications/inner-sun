"""Compose the raw Blender passes into game-ready sprites (style C of the bake-off).

    python pipeline/blender_post.py [raw_dir] [out_dir]

albedo   = flat albedo pass * ambient occlusion (mild), straight alpha
normal   = camera-space normal pass, renormalised, OpenGL (green = +Y up); fully transparent texels get the
           flat normal and the colour of the nearest opaque neighbour so linear filtering never halos
emission = glow-only pass plus a soft baked halo, straight colour, alpha = intensity
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

RAW = sys.argv[1] if len(sys.argv) > 1 else os.path.join(common.ROOT, "harness", "out", "blender_raw")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(common.ROOT, "game", "assets", "bakeoff", "blender")
os.makedirs(OUT, exist_ok=True)

LAYERS = {"wall": "room_wall", "reactor": "reactor", "lamp": "lamp", "floor": "floor"}
CREW = [f"crew_f{i}" for i in range(4)]


def load(n):
    p = os.path.join(RAW, n + ".png")
    return np.asarray(Image.open(p).convert("RGBA"), dtype=np.float32) / 255.0 if os.path.exists(p) else None


def bleed(rgb, a, iters=6):
    """Spread opaque colours into the transparent texels (no halo under linear filtering)."""
    rgb = rgb.copy()
    known = a > 0.5
    for _ in range(iters):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            s = np.roll(np.roll(rgb, dy, 0), dx, 1)
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += s * k[..., None]
            cnt += k
        new = (~known) & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][..., None]
        known = known | new
    return rgb


def make(name, tag, outname):
    alb, nrm, ao, emi = (load(f"{name}{tag}_{k}") for k in ("alb", "nrm", "ao", "emi"))
    a = alb[..., 3]
    # albedo: AO multiplied in gently, edges bled so the straight alpha has clean colour
    occ = np.clip(ao[..., :3].mean(axis=2), 0, 1) ** 1.1
    col = alb[..., :3] * (0.30 + 0.70 * occ)[..., None]
    col = bleed(col, a)
    out = np.dstack([np.clip(col, 0, 1), a])
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, outname + "_albedo.png"))
    # normal
    v = nrm[..., :3] * 2.0 - 1.0
    ln = np.linalg.norm(v, axis=2, keepdims=True)
    v = np.where(ln > 1e-4, v / np.maximum(ln, 1e-4), np.array([0, 0, 1.0], np.float32))
    n = v * 0.5 + 0.5
    n = bleed(n, a)
    n[a < 0.02] = np.array([0.5, 0.5, 1.0])
    outn = np.dstack([np.clip(n, 0, 1), a])
    Image.fromarray((outn * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, outname + "_normal.png"))
    if emi is not None:
        ea = emi[..., 3]
        sig = {"reactor": 9, "lamp": 6, "crew": 3}.get(name, 6)
        pm = Image.fromarray((ea * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(sig))
        halo = np.asarray(pm, np.float32) / 255.0
        halo = np.clip(halo * 1.6, 0, 1) ** 1.3
        inten = np.clip(np.maximum(ea, halo * 0.35), 0, 1)
        c = bleed(emi[..., :3], ea, iters=int(sig * 2.5))
        eo = np.dstack([np.clip(c, 0, 1), inten])
        Image.fromarray((eo * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, outname + "_emission.png"))


for k, v in LAYERS.items():
    make(k, "", v)
for i, c in enumerate(CREW):
    make("crew", f"_f{i}", "crew" if i == 0 else f"crew_f{i}")
common.save_manifest("blender_sprites", {
    "tool": "Blender 5.1 headless, Cycles CPU, orthographic camera, emission albedo + camera-space normal override + AO",
    "script": "pipeline/blender/bake_sprites.py + pipeline/blender_post.py",
    "ppm": 160, "seed": 1977, "outputs": sorted(os.listdir(OUT))})
print("blender_post: ok", len(os.listdir(OUT)), "files in", OUT)
