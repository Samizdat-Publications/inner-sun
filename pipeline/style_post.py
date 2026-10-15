"""Turn chosen generation candidates into game-ready bake-off sprites for the PIXEL and PAINTED styles.

    python pipeline/style_post.py pixel   --pick wall=wall_s1,reactor=reactor_s2,lamp=lamp_s1,floor=grating_s1,crew=crew_s2
    python pipeline/style_post.py painted --pick wall=wall_v1,reactor=reactor_v2,...

Candidates are read from harness/out/pixel_cands or harness/out/painted_cands (PNG). Props and the crew
may sit on a flat magenta key (painted) or be transparent already (pixel). Output (game/assets/bakeoff/<style>/):
room_wall, floor, reactor, lamp, crew  each as _albedo.png + _normal.png, and reactor/lamp/crew _emission.png.

Native scales: pixel 40 px per meter (room 160x120, crew about 72 px tall, shown 2x nearest); painted 160 px per
meter (room 640x480, crew about 288 px tall, shown 0.5x linear + mipmaps). Props are trimmed to their opaque box;
the reactor and crew are bottom aligned, the lamp is top aligned (the scene anchors them that way).
Emission sprites are cut from the albedo by colour (green core window, warm bulb, headlamp) and get a soft halo.
Every step is deterministic. Parameters go to pipeline/manifests/<style>_post.json.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import normals  # noqa: E402

PPM = {"pixel": 40, "painted": 160}
# target sizes in meters: (w, h) of the canvas (wall, floor) or the visible height (reactor, lamp, crew)
ROOM_M = (4.0, 3.0)
FLOOR_H_M = 0.25
REACTOR_H_M = 1.7
LAMP_H_M = 0.5
CREW_H_M = 1.8


def load_cand(style, name):
    p = os.path.join(common.ROOT, "harness", "out", style + "_cands", name + ".png")
    return Image.open(p).convert("RGBA")


def key_magenta(im):
    """Soft chroma key against #ff00ff, then bleed clean colour into the fringe."""
    a = np.asarray(im, np.float32) / 255.0
    rgb = a[..., :3]
    key = np.array([1.0, 0.0, 1.0], np.float32)
    d = np.linalg.norm(rgb - key, axis=2)
    alpha = np.clip((d - 0.25) / 0.35, 0, 1) * a[..., 3]
    core = alpha > 0.95
    from scipy import ndimage as ndi
    core = ndi.binary_erosion(core, iterations=1)
    rgb = normals.bleed(np.where(core[..., None], rgb, 0), core.astype(np.float32), iters=4)
    rgb = np.where(core[..., None], np.asarray(im, np.float32)[..., :3] / 255.0, rgb)
    return np.dstack([rgb, alpha])


def trim(arr):
    ys, xs = np.where(arr[..., 3] > 0.5)
    return arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def resize(arr, size, nearest):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    # premultiply-safe resize: resize colour bled across alpha, alpha separately
    rgb = Image.fromarray((np.clip(normals.bleed(arr[..., :3], arr[..., 3]), 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    al = Image.fromarray((arr[..., 3] * 255 + 0.5).astype(np.uint8), "L")
    flt = Image.NEAREST if nearest else Image.LANCZOS
    rgb = rgb.resize(size, flt)
    al = al.resize(size, flt)
    out = np.dstack([np.asarray(rgb, np.float32) / 255.0, np.asarray(al, np.float32) / 255.0])
    if nearest:
        out[..., 3] = (out[..., 3] > 0.5).astype(np.float32)
    return out


def emission_from(arr, kind):
    rgb, a = arr[..., :3], arr[..., 3]
    lum = normals.luminance(rgb)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if kind == "core":      # green-yellow glowing window
        m = (g > 0.55) & (g > r * 1.05) & (g > b * 1.15) & (lum > 0.5)
    elif kind == "bulb":    # warm white-hot bulb, the brightest blob
        m = (lum > max(0.8, np.percentile(lum[a > 0.5], 97))) & (r > 0.8)
    else:                   # "lens": near white
        m = (lum > 0.85) & (b > 0.7)
    m = m & (a > 0.5)
    from scipy import ndimage as ndi
    if kind == "lens":      # only the headlamp: the top fifth of the figure
        m[int(arr.shape[0] * 0.2):] = False
    if m.sum() == 0:
        return None
    if kind == "core":      # keep the largest blob and fill the white-hot centre
        lab, n = ndi.label(m)
        if n > 1:
            m = lab == (1 + int(np.argmax(ndi.sum(m, lab, range(1, n + 1)))))
        m = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=3))
    m = ndi.binary_opening(m, iterations=1) if m.sum() > 40 else m
    col = rgb / np.maximum(rgb.max(axis=2, keepdims=True), 1e-3)
    ea = m.astype(np.float32)
    sig = max(2.0, arr.shape[1] * 0.03)
    halo = np.asarray(Image.fromarray((ea * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(sig)), np.float32) / 255
    halo = np.clip(halo * 1.6, 0, 1) ** 1.3
    inten = np.clip(np.maximum(ea, halo * 0.35), 0, 1)
    c = normals.bleed(np.where(m[..., None], col, 0), ea, iters=int(sig * 2.5))
    return np.dstack([np.clip(c, 0, 1), inten])


# Painted albedo is graded to the mean brightness of the Blender (style C) set so the lit comparison is fair
# (the game lights albedo through a dark CanvasModulate, so very dark paintings vanish). Gamma solve, colour only.
TARGET_MEAN = {"room_wall": 0.33, "floor": 0.40, "crew": 0.34}


def grade(arr, target):
    m = arr[..., 3] > 0.5
    mean = float(arr[..., :3][m].mean())
    g = np.log(target) / np.log(max(mean, 1e-3))
    out = arr.copy()
    out[..., :3] = np.clip(arr[..., :3], 0, 1) ** g
    return out


def save(arr, path):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)


def nparams(style, kind, arr):
    w = arr.shape[1]
    if style == "pixel":
        base = dict(bevel_radius=3, bevel_height_px=1.6, detail_gain=6.0, detail_sigmas=(0.5, 2.0), quant=4)
    else:
        base = dict(bevel_radius=10, bevel_height_px=4.0, detail_gain=10.0, detail_sigmas=(1.0, 6.0), smooth=0.6)
    if kind == "reactor":
        base["cyl"] = {"cx": w / 2, "radius": w * 0.3, "height": w * 0.3}
    if kind == "crew":
        base["cyl"] = {"cx": w * 0.5, "radius": w * 0.42, "height": w * 0.2}
    return base


def main():
    style = sys.argv[1]
    pick = dict(kv.split("=") for kv in sys.argv[sys.argv.index("--pick") + 1].split(","))
    ppm = PPM[style]
    nearest = style == "pixel"
    out = os.path.join(common.ROOT, "game", "assets", "bakeoff", style)
    os.makedirs(out, exist_ok=True)
    report = {}
    for item, cand in pick.items():
        im = load_cand(style, cand)
        arr = np.asarray(im, np.float32) / 255.0
        if style == "painted" and item in ("reactor", "lamp", "crew"):
            arr = key_magenta(im)
        if item in ("reactor", "lamp", "crew"):
            arr = trim(arr)
            hm = {"reactor": REACTOR_H_M, "lamp": LAMP_H_M, "crew": CREW_H_M}[item]
            th = int(round(hm * ppm))
            tw = max(1, int(round(arr.shape[1] * th / arr.shape[0])))
            arr = resize(arr, (tw, th), nearest)
            name = item
        elif item == "wall":
            arr = resize(arr, (int(ROOM_M[0] * ppm), int(ROOM_M[1] * ppm)), nearest)
            arr[..., 3] = 1.0
            name = "room_wall"
        else:                      # floor strip: fill width, crop to height
            w = int(ROOM_M[0] * ppm)
            h = int(FLOOR_H_M * ppm)
            sc = w / arr.shape[1]
            arr = resize(arr, (w, max(h, int(round(arr.shape[0] * sc)))), nearest)
            top = (arr.shape[0] - h) // 2
            arr = arr[top:top + h]
            arr[..., 3] = 1.0
            name = "floor"
        if style == "painted" and name in TARGET_MEAN:
            arr = grade(arr, TARGET_MEAN[name])
        alb = arr.copy()
        save(alb, os.path.join(out, name + "_albedo.png"))
        n = normals.normal_map(alb, **nparams(style, name, alb))
        Image.fromarray(n, "RGBA").save(os.path.join(out, name + "_normal.png"))
        em = None
        if name == "reactor":
            em = emission_from(alb, "core")
        elif name == "lamp":
            em = emission_from(alb, "bulb")
        elif name == "crew":
            em = emission_from(alb, "lens")
        if em is not None:
            save(em, os.path.join(out, name + "_emission.png"))
        report[name] = {"candidate": cand, "size": [alb.shape[1], alb.shape[0]], "emission": em is not None}
        print(f"{name}: {alb.shape[1]}x{alb.shape[0]} px, emission {'yes' if em is not None else 'NO (no matching pixels)'}")
    common.save_manifest(style + "_post", {"pick": pick, "ppm": ppm, "result": report,
                                           "script": "pipeline/style_post.py + pipeline/normals.py"})


if __name__ == "__main__":
    main()
