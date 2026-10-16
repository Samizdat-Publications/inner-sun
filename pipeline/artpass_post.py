"""M1 art pass post-processing: candidates -> game-ready albedo / normal / emission PNGs (160 px per meter).

    python pipeline/artpass_post.py rooms,fittings,rock [--only name,name]
    (crew has its own script: pipeline/artpass_crew.py)

Reads harness/out/artpass_cands/<item>_v<n>.png (see artpass_gen.py), keys magenta, trims, resizes to the real
size in meters, grades to the shared brightness target (same gamma solve as style_post.py, the reactor room of the
bake-off sits at 0.33 to 0.35), builds normal maps with pipeline/normals.py and cuts emission sprites by colour.
Tileable assets are made seamless by a seam cross-fade and their normals are computed on a tiled copy so the
edges match. Every step is deterministic. Parameters go to pipeline/manifests/artpass_post.json.
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import normals  # noqa: E402
import style_post as sp  # noqa: E402

PPM = 160
CANDS = os.path.join(common.ROOT, "harness", "out", "artpass_cands")
SHIP = os.path.join(common.ROOT, "game", "assets", "ship")
ROCK = os.path.join(common.ROOT, "game", "assets", "rock")

# chosen candidate per item (the lead picked by looking at the contact sheets)
PICK = {}
try:
    PICK = json.load(open(os.path.join(common.ROOT, "pipeline", "manifests", "artpass_picks.json"), encoding="utf-8"))
except Exception:  # noqa: BLE001
    pass

CROPS = {"fit_crown": 0.085, "prop_jack": 0.065}
NOFILL = {"fit_door_open"}
PROP_TARGET = 0.34
WALL_TARGET = 0.32

# name -> (candidate item, out name, size spec, grade target, normal extras, emission kind)
ROOMS = {
    "bridge_wall": ("wall_bridge", None),
    "bracing_wall": ("wall_bracing", None),
    "weapons_wall": ("wall_weapons", None),
    "drill_wall": ("wall_drill", None),
    "coolant_wall": ("wall_coolant", None),
}
# props: out name -> (candidate, dimension "h" or "w", meters, normal-extras, emission kind)
PROPS = {
    "bridge_helm": ("prop_helm", "w", 1.8, {}, "screen"),
    "bracing_jack": ("prop_jack", "h", 2.4, {}, None),
    "bracing_manifold": ("prop_manifold", "h", 1.1, {}, None),
    "weapons_breech": ("prop_breech", "w", 1.9, {}, "amber"),
    "weapons_ammo": ("prop_ammo", "h", 1.6, {}, None),
    "drill_motor": ("prop_drillmotor", "h", 2.8, {}, None),
    "drill_bitrack": ("prop_bitrack", "h", 0.9, {}, None),
    "coolant_tank": ("prop_tank", "h", 2.1, {"cyl": 0.32}, "cyan"),
    "coolant_pump": ("prop_pump", "w", 1.5, {}, None),
}


def load(item):
    v = PICK.get(item, 1)
    return Image.open(os.path.join(CANDS, f"{item}_v{v}.png")).convert("RGBA"), f"{item}_v{v}"


def key_adaptive(im, crop=0.035, fill=True):
    """Key the flat backdrop whatever shade of magenta it came out (and drop a cream frame the model sometimes
    paints): crop a small margin, take the median of the outer ring as the key colour, soft key on distance."""
    w, h = im.size
    cx, cy = int(w * crop), int(h * crop)
    im = im.crop((cx, cy, w - cx, h - cy))
    a = np.asarray(im, np.float32) / 255.0
    rgb = a[..., :3]
    ring = np.concatenate([rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3), rgb[:, :3].reshape(-1, 3),
                           rgb[:, -3:].reshape(-1, 3)])
    key = np.median(ring, axis=0)
    d = np.linalg.norm((rgb - key) * np.array([1.0, 1.6, 1.0], np.float32), axis=2)
    alpha = np.clip((d - 0.16) / 0.22, 0, 1) * a[..., 3]
    # second backdrop shade: the model sometimes paints a brighter magenta inside openings (jack frame, door)
    r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mg = (r_ > 0.55) & (b_ > 0.5) & (g_ < 0.5) & (np.abs(r_ - b_) < 0.25) & (r_ - g_ > 0.3)
    alpha = np.where((r_ > 0.7) & (b_ > 0.7) & (g_ < 0.4), 0, alpha)     # any leftover pure magenta pocket
    if mg.mean() > 0.002:
        key2 = np.median(rgb[mg], axis=0)
        d2 = np.linalg.norm((rgb - key2) * np.array([1.0, 1.6, 1.0], np.float32), axis=2)
        alpha = np.minimum(alpha, np.clip((d2 - 0.16) / 0.22, 0, 1))
    if fill:
        holes = ndi.binary_fill_holes(alpha > 0.5) & ~(alpha > 0.5)
        lab, n = ndi.label(holes)
        if n:       # only fill small pinholes (bright paint that matched the key), never real openings
            sz = ndi.sum(holes, lab, range(1, n + 1))
            small = np.isin(lab, [i + 1 for i, s in enumerate(sz) if s < 0.0015 * alpha.size])
            alpha = np.maximum(alpha, small.astype(np.float32))
    mag = (r_ > 0.5) & (b_ > 0.42) & (g_ < 0.45) & (r_ - g_ > 0.25) & (b_ - g_ > 0.2)   # pinkish leftovers
    alpha = np.where(ndi.binary_dilation(mag, iterations=1), 0, alpha)
    core = ndi.binary_erosion(alpha > 0.75, iterations=1)
    bl = normals.bleed(np.where(core[..., None], rgb, 0), core.astype(np.float32), iters=4)
    rgb2 = np.where(core[..., None], rgb, bl)
    return np.dstack([rgb2, alpha])


def seamless(arr, axes, band=0.25):
    """Make an array periodic along the given axes (0 = y, 1 = x) with a seam cross-fade."""
    out = arr.copy()
    for ax in axes:
        n = out.shape[ax]
        d = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(np.float32) / (band * n)
        d = np.clip(d, 0, 1)
        w = d * d * (3 - 2 * d)            # 0 at the seam, 1 away from it
        shifted = np.roll(out, n // 2, axis=ax)
        shape = [1] * out.ndim
        shape[ax] = n
        w = w.reshape(shape)
        out = out * w + shifted * (1 - w)
    return out


def tiled_normal(alb, kw, tile_x=False, tile_y=False):
    ty = 3 if tile_y else 1
    tx = 3 if tile_x else 1
    big = np.tile(alb, (ty, tx, 1))
    n = normals.normal_map(big, **kw)
    h, w = alb.shape[:2]
    y0 = h if tile_y else 0
    x0 = w if tile_x else 0
    return n[y0:y0 + h, x0:x0 + w]


def nkw(w, extras=None):
    kw = dict(bevel_radius=10, bevel_height_px=4.0, detail_gain=10.0, detail_sigmas=(1.0, 6.0), smooth=0.6)
    ex = dict(extras or {})
    if "cyl" in ex:
        f = ex.pop("cyl")
        kw["cyl"] = {"cx": w / 2, "radius": w * f, "height": w * f * 0.8}
    kw.update(ex)
    return kw


def emission_by(arr, kind):
    """Colour-cut emission sprite (rgb normalised to full brightness, alpha = intensity with a soft halo)."""
    rgb, a = arr[..., :3], arr[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = normals.luminance(rgb)
    if kind == "screen":      # CRT phosphor green
        m = (g > r * 1.25) & (g > b * 1.05) & (g > 0.25)
    elif kind == "cyan":      # sight glass
        m = (b > 0.45) & (g > 0.35) & (r < b * 0.7)
    elif kind == "gem":       # emerald crystals
        m = (g > 0.4) & (g > r * 1.3) & (g > b * 1.1)
    elif kind == "hot":       # glowing cutter tips
        m = (r > 0.65) & (r > g * 1.25) & (lum > 0.38)
    elif kind == "amber":     # small warning lamp
        m = (r > 0.8) & (g > 0.45) & (b < 0.4) & (lum > 0.6)
    else:
        return None
    m &= a > 0.5
    m = ndi.binary_opening(m, iterations=1) if m.sum() > 60 else m
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=2))
    if n:
        sizes = ndi.sum(m, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= max(12, 0.0004 * m.size)])
        m &= keep
    if m.sum() < 12:
        return None
    if kind in ("screen", "gem"):
        m = ndi.binary_closing(m, iterations=4) & (a > 0.5)
    col = rgb / np.maximum(rgb.max(axis=2, keepdims=True), 1e-3)
    ea = m.astype(np.float32)
    sig = max(2.0, arr.shape[1] * 0.02)
    from PIL import ImageFilter
    halo = np.asarray(Image.fromarray((ea * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(sig)), np.float32) / 255
    halo = np.clip(halo * 1.6, 0, 1) ** 1.3
    inten = np.clip(np.maximum(ea, halo * 0.35), 0, 1)
    c = normals.bleed(np.where(m[..., None], col, 0), ea, iters=int(sig * 2.5))
    return np.dstack([np.clip(c, 0, 1), inten])


def put(folder, name, alb, kw, em=None, tile_x=False, tile_y=False):
    os.makedirs(folder, exist_ok=True)
    sp.save(alb, os.path.join(folder, name + "_albedo.png"))
    Image.fromarray(tiled_normal(alb, kw, tile_x, tile_y), "RGBA").save(os.path.join(folder, name + "_normal.png"))
    if em is not None:
        sp.save(em, os.path.join(folder, name + "_emission.png"))
    return {"size": [alb.shape[1], alb.shape[0]], "emission": em is not None}


def do_prop(name, item, dim, meters, extras, ekind, target=PROP_TARGET, size=None):
    im, cand = load(item)
    arr = sp.trim(key_adaptive(im, CROPS.get(item, 0.035), item not in NOFILL))
    if size is None:
        if dim == "h":
            th = int(round(meters * PPM))
            tw = max(1, int(round(arr.shape[1] * th / arr.shape[0])))
        else:
            tw = int(round(meters * PPM))
            th = max(1, int(round(arr.shape[0] * tw / arr.shape[1])))
    else:
        tw, th = size
    if name == "door_open":    # keep only the frame: the model leaves a stray wheel blob in the doorway
        lab, n = ndi.label(arr[..., 3] > 0.5)
        if n > 1:
            big = 1 + int(np.argmax(ndi.sum(arr[..., 3] > 0.5, lab, range(1, n + 1))))
            arr[..., 3] = np.where(lab == big, arr[..., 3], 0)
    arr = sp.resize(arr, (tw, th), False)
    em = emission_by(arr, ekind) if ekind else None
    alb = sp.grade(arr, target)
    r = put(SHIP, name, alb, nkw(tw, extras), em)
    r["candidate"] = cand
    return r


def do_room(name, item):
    im, cand = load(item)
    arr = np.asarray(im, np.float32) / 255.0
    arr = sp.resize(arr, (int(4 * PPM), int(3 * PPM)), False)
    arr[..., 3] = 1.0
    alb = sp.grade(arr, WALL_TARGET)
    r = put(SHIP, name, alb, nkw(arr.shape[1]))
    r["candidate"] = cand
    return r


def center_crop(arr, aspect):
    h, w = arr.shape[:2]
    if w / h > aspect:
        nw = int(h * aspect)
        x0 = (w - nw) // 2
        return arr[:, x0:x0 + nw]
    nh = int(w / aspect)
    y0 = (h - nh) // 2
    return arr[y0:y0 + nh]


def do_fittings(only):
    rep = {}

    def want(n):
        return not only or n in only

    if want("door_closed"):
        rep["door_closed"] = do_prop("door_closed", "fit_door_closed", "h", 2.1, {}, None, size=(160, 336))
    if want("door_open"):
        rep["door_open"] = do_prop("door_open", "fit_door_open", "h", 2.1, {}, None, size=(160, 336))
    if want("hatch_rim"):
        rep["hatch_rim"] = do_prop("hatch_rim", "fit_hatch", "w", 0.8, {"bevel_radius": 5, "bevel_height_px": 3.0}, None,
                                   size=(128, 32))
    if want("ladder"):
        rep["ladder"] = do_ladder()
    if want("floor_grating"):
        im, cand = load("fit_grating")
        arr = np.asarray(im, np.float32) / 255.0
        arr = center_crop(arr, 8.0 * 2) if False else arr
        h, w = arr.shape[:2]
        cw = w // 2
        ch = cw // 8
        y0 = (h - ch) // 2
        arr = arr[y0:y0 + ch, (w - cw) // 2:(w - cw) // 2 + cw]
        arr = sp.resize(arr, (320, 40), False)
        arr = seamless(arr, [1])
        arr[..., 3] = 1.0
        alb = sp.grade(arr, 0.38)
        rep["floor_grating"] = put(SHIP, "floor_grating", alb, nkw(320, {"bevel_height_px": 0.0}), tile_x=True)
        rep["floor_grating"]["candidate"] = cand
    if want("hull"):
        im, cand = load("fit_hull")
        base = np.asarray(im, np.float32) / 255.0
        h, w = base.shape[:2]
        cw = w // 2
        ch = cw * 48 // 320
        # top strip: upper band of the plating, tiles horizontally
        top = base[int(h * 0.15):int(h * 0.15) + ch, int(w * 0.25):int(w * 0.25) + cw]
        top = seamless(sp.resize(top, (320, 48), False), [1])
        top[..., 3] = 1.0
        alb = sp.grade(top, 0.34)
        rep["hull_top"] = put(SHIP, "hull_top", alb, nkw(320, {"bevel_height_px": 0.0}), tile_x=True)
        # side strips: other bands rotated, tile vertically
        for nm, y_frac, k in (("hull_left", 0.55, 1), ("hull_right", 0.4, -1)):
            band = base[int(h * y_frac):int(h * y_frac) + ch, int(w * 0.2):int(w * 0.2) + cw]
            s = sp.resize(band, (320, 48), False)
            s = np.rot90(s, k)                     # 48 wide, 320 tall
            s = seamless(np.ascontiguousarray(s), [0])
            s[..., 3] = 1.0
            alb = sp.grade(s, 0.34)
            rep[nm] = put(SHIP, nm, alb, nkw(48, {"bevel_height_px": 0.0}), tile_y=True)
        rep["hull_top"]["candidate"] = cand
    if want("drill_crown"):
        im, cand = load("fit_crown")
        arr = sp.trim(key_adaptive(im, CROPS.get("fit_crown", 0.035)))
        tw = int(8 * PPM)
        th = 300          # squashed from the painted 21:9 proportions to a flat 1.9 m disc
        arr = sp.resize(arr, (tw, th), False)
        em = emission_by(arr, "hot")
        alb = sp.grade(arr, PROP_TARGET)
        rep["drill_crown"] = put(SHIP, "drill_crown", alb, nkw(tw, {"bevel_radius": 14, "bevel_height_px": 6.0}), em)
        rep["drill_crown"]["candidate"] = cand
    return rep


def do_ladder():
    im, cand = load("fit_ladder")
    a = key_adaptive(im)
    ys, xs = np.where(a[..., 3] > 0.5)
    arr = a[:, xs.min():xs.max() + 1]
    h, w = arr.shape[:2]
    lum = normals.luminance(arr[..., :3])
    mid = lum[:, int(w * 0.25):int(w * 0.75)].mean(axis=1)
    mid = mid - ndi.uniform_filter1d(mid, 80)
    ac = np.correlate(mid, mid, "full")[h - 1:]
    lo = int(h * 0.04)
    hi = int(h * 0.3)
    period = lo + int(np.argmax(ac[lo:hi]))
    # start on a rung (the strongest row in the first period after a margin)
    start = int(h * 0.2)
    seg = mid[start:start + period]
    y0 = start + int(np.argmax(np.abs(seg)))
    n_rungs = 4
    y1 = y0 + period * n_rungs
    if y1 > h:
        y0 = max(0, h - period * n_rungs)
        y1 = y0 + period * n_rungs
    crop = arr[y0:y1]
    crop = sp.resize(crop, (80, 160), False)
    crop = seamless(crop, [0], band=0.12)
    alb = sp.grade(crop, PROP_TARGET)
    r = put(SHIP, "ladder", alb, nkw(80, {"bevel_radius": 5, "bevel_height_px": 3.0}), tile_y=True)
    r["candidate"] = cand
    r["period_px_src"] = period
    return r


def do_rock(only):
    rep = {}
    targets = {"soft": 0.36, "rock": 0.32, "dense": 0.28, "hard": 0.20, "iron": 0.31, "gem": 0.28, "water": 0.17,
               "shaft": 0.16}
    for k, tgt in targets.items():
        if only and "rock_" + k not in only:
            continue
        im, cand = load("rock_" + k)
        arr = np.asarray(im, np.float32) / 255.0
        arr = center_crop(arr, 1.0)
        arr[..., 3] = 1.0
        em = emission_by(arr, "gem") if k == "gem" else None
        arr = seamless(arr, [0, 1])
        arr = sp.resize(arr, (128, 128), False)
        arr[..., 3] = 1.0
        em_r = None
        if k == "gem":
            em_full = emission_by(arr, "gem")
            em_r = em_full
        alb = sp.grade(arr, tgt)
        kw = dict(bevel_radius=1, bevel_height_px=0.0, detail_gain=14.0, detail_sigmas=(1.0, 5.0), smooth=0.5)
        rep["rock_" + k] = put(ROCK, k, alb, kw, em_r, tile_x=True, tile_y=True)
        rep["rock_" + k]["candidate"] = cand
    return rep


def copy_reactor():
    src = os.path.join(common.ROOT, "game", "assets", "bakeoff", "painted")
    os.makedirs(SHIP, exist_ok=True)
    mp = {"room_wall": "reactor_wall", "reactor": "reactor_core", "lamp": "lamp", "floor": "floor_plate"}
    out = {}
    for s, d in mp.items():
        for k in ("albedo", "normal", "emission"):
            p = os.path.join(src, f"{s}_{k}.png")
            if os.path.exists(p):
                shutil.copyfile(p, os.path.join(SHIP, f"{d}_{k}.png"))
        out[d] = "copied from bakeoff/painted/" + s
    return out


def main():
    groups = sys.argv[1].split(",")
    only = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else set()
    rep = {}
    if "rooms" in groups:
        for n, (item, _) in ROOMS.items():
            if not only or n in only:
                rep[n] = do_room(n, item)
        for n, (item, dim, m, ex, ek) in PROPS.items():
            if not only or n in only:
                rep[n] = do_prop(n, item, dim, m, ex, ek)
        if not only:
            rep["reactor"] = copy_reactor()
    if "fittings" in groups:
        rep.update(do_fittings(only))
    if "rock" in groups:
        rep.update(do_rock(only))
    for k, v in rep.items():
        print(k, v)
    common.save_manifest("artpass_post", {"groups": groups, "ppm": PPM, "picks": PICK, "result": rep,
                                          "script": "pipeline/artpass_post.py + pipeline/normals.py + style_post.py"})


if __name__ == "__main__":
    main()
