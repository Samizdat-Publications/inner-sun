"""Crew art: full figures and cut-out puppet parts (160 px per meter, standing height 1.8 m = 288 px).

    python pipeline/artpass_crew.py analyze            label the components of every parts sheet (debug sheet)
    python pipeline/artpass_crew.py build [name ...]   write game/assets/crew/<name>/

Per character (see pipeline/manifests/crew_<name>.json): the full figure (strict side view, facing right) as
full_albedo / full_normal / full_emission, and six parts (head, torso, upper_arm, forearm, thigh, shin) each as
<part>_albedo / <part>_normal, plus pivots. Parts are cut from the generated parts sheet by connected components
(the sheet is keyed like the props), sorted into the 2 x 3 layout the prompt asks for (row 1 head, torso; row 2
upper arm, forearm with hand; row 3 thigh, shin with boot). Tiny stray components are merged into the nearest
part, anything else outside the layout is reported. Parts are scaled so that head + torso + thigh + shin (less
the joint overlaps) equals the figure height of 1.8 m, i.e. the same scale as the full figure.

Pivots (pixel coordinates inside the part image, y down): every part has "pivot", its joint with its parent
(neck for the head, hip for the torso root, shoulder, elbow, hip, knee) and "child", the joint where the next part
attaches (torso also lists "neck", "shoulder_l", "hip"). Limb parts are drawn vertical, so the pivot sits on the
vertical centre line of the part at the joint overlap margin.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artpass_post as ap  # noqa: E402
import common  # noqa: E402
import normals  # noqa: E402
import style_post as sp  # noqa: E402

PPM = 160
HEIGHT_M = 1.8
CANDS = ap.CANDS
OUT = os.path.join(common.ROOT, "game", "assets", "crew")

# chosen candidates (full figure, parts sheet)
CREW = {
    "vasquez": ("crew_vasquez_full_v3", "crew_vasquez_parts_v2"),
    "okafor": ("crew_okafor_full_v1", "crew_okafor_parts_v1"),
    "lindqvist": ("crew_lindqvist_full_v2", "crew_lindqvist_parts_v2"),
    "rival_a": ("crew_rival_a_full_v1", "crew_rival_a_parts_v2"),
    "rival_b": ("crew_rival_b_full_v1", "crew_rival_b_parts_v1"),
}
PARTS = ["head", "torso", "upper_arm", "forearm", "thigh", "shin"]
GRADE = 0.34
# per-character scale calibration so the static puppet assembly (artpass_overview.puppet) is 288 px like the figure
CAL = {"vasquez": 0.98, "okafor": 0.908}
MARGIN = 0.07      # joint overlap margin as a fraction of the part length (the pivot sits this far in)


def load_png(name):
    return Image.open(os.path.join(CANDS, name + ".png")).convert("RGBA")


def components(arr, min_frac=0.012):
    """Connected components of the keyed sheet (dilated so a hand and its fingers stay together)."""
    rgb = arr[..., :3]
    smear = (rgb[..., 0] - rgb[..., 1] > 0.22) & (rgb[..., 2] - rgb[..., 1] > 0.18) & (rgb[..., 2] > 0.4)
    arr[..., 3] = np.where(ndi.binary_dilation(smear, iterations=1), 0, arr[..., 3])   # airbrushed magenta smudges
    m = arr[..., 3] > 0.5
    core = ndi.binary_opening(m, iterations=3)      # break thin bridges between touching parts
    lab, n = ndi.label(ndi.binary_dilation(core, iterations=6))
    lab = np.where(m, lab, 0)
    areas = ndi.sum(m, lab, range(1, n + 1))
    total = m.sum()
    big = [i + 1 for i, a in enumerate(areas) if a >= min_frac * total]
    small = [i + 1 for i, a in enumerate(areas) if a < min_frac * total]
    cen = {i: ndi.center_of_mass(lab == i) for i in range(1, n + 1)}
    groups = {b: [b] for b in big}
    for s in small:   # merge strays into the nearest big component
        if not big:
            break
        d = [(cen[s][0] - cen[b][0]) ** 2 + (cen[s][1] - cen[b][1]) ** 2 for b in big]
        groups[big[int(np.argmin(d))]].append(s)
    comps = []
    for b, members in groups.items():
        mask = np.isin(lab, members)
        ys, xs = np.where(mask)
        comps.append({"mask": mask, "bbox": (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1), "area": int(mask.sum()),
                      "cy": float(ys.mean()), "cx": float(xs.mean()), "merged": len(members) - 1})
    return comps


def assign(comps):
    """Sort components into the 2 x 3 layout. Returns {part: comp} or None when the count is wrong."""
    if len(comps) != 6:
        return None
    rows = sorted(comps, key=lambda c: c["cy"])
    out = {}
    for r, (a, b) in enumerate((PARTS[0:2], PARTS[2:4], PARTS[4:6])):
        pair = sorted(rows[r * 2:r * 2 + 2], key=lambda c: c["cx"])
        out[a], out[b] = pair[0], pair[1]
    # a head is smaller than a torso whatever the column order
    if out["head"]["area"] > out["torso"]["area"]:
        out["head"], out["torso"] = out["torso"], out["head"]
    return out


def crop_part(arr, comp):
    x0, y0, x1, y1 = comp["bbox"]
    p = arr[y0:y1, x0:x1].copy()
    p[..., 3] = np.where(comp["mask"][y0:y1, x0:x1], p[..., 3], 0)
    return p


def pivots(parts):
    """parts: {name: array at final scale}. Pivot dictionary in part pixel coordinates."""
    piv = {}
    for name, p in parts.items():
        h, w = p.shape[:2]
        a = p[..., 3] > 0.5
        ys, xs = np.where(a)

        def cx_at(y0, y1):
            m = a[max(0, y0):max(1, y1)]
            xx = np.where(m)[1]
            return float(xx.mean()) if xx.size else w / 2

        top = int(h * MARGIN)
        bot = int(h * (1 - MARGIN))
        if name == "head":
            piv[name] = {"pivot": [round(cx_at(bot - 4, bot + 4), 1), float(bot)], "child": None}
        elif name == "torso":
            piv[name] = {"pivot": [round(cx_at(bot - 4, bot + 4), 1), float(bot)],
                         "neck": [round(cx_at(top, top + 8), 1), float(top)],
                         "shoulder": [round(cx_at(top + int(h * 0.12), top + int(h * 0.12) + 8), 1), round(top + h * 0.12, 1)],
                         "child": None}
        else:
            piv[name] = {"pivot": [round(cx_at(top, top + 6), 1), float(top)],
                         "child": [round(cx_at(bot - 6, bot), 1), float(bot)]}
    return piv


def analyze():
    tiles = []
    for who, (_, sheet) in CREW.items():
        arr = ap.key_adaptive(load_png(sheet), 0.0)
        comps = components(arr)
        im = Image.fromarray((arr * 255).astype(np.uint8), "RGBA")
        bg = Image.new("RGBA", im.size, (60, 60, 70, 255))
        bg.alpha_composite(im)
        d = ImageDraw.Draw(bg)
        for i, c in enumerate(sorted(comps, key=lambda c: (round(c["cy"] / 300), c["cx"]))):
            x0, y0, x1, y1 = c["bbox"]
            d.rectangle([x0, y0, x1, y1], outline=(0, 255, 0), width=4)
            d.text((x0 + 8, y0 + 8), str(i), fill=(255, 255, 0))
        print(who, len(comps), "components", [(c["area"], c["merged"]) for c in comps], "assigned" if assign(comps) else "NOT 6")
        tiles.append(bg.convert("RGB").resize((450, int(450 * bg.height / bg.width))))
    W = sum(t.width + 4 for t in tiles)
    sh = Image.new("RGB", (W, max(t.height for t in tiles)))
    x = 0
    for t in tiles:
        sh.paste(t, (x, 0))
        x += t.width + 4
    p = os.path.join(common.ROOT, "harness", "out", "artpass", "crew_components.jpg")
    sh.save(p)
    print(p)


def figure(who, full):
    arr = sp.trim(ap.key_adaptive(load_png(full), 0.0))
    th = int(HEIGHT_M * PPM)
    tw = int(round(arr.shape[1] * th / arr.shape[0]))
    arr = sp.resize(arr, (tw, th), False)
    return arr


# parts route failed twice for these (sheets merged limbs or drew extra boots): painted 4-frame walk cycle instead
WALK = {"lindqvist": "crew_lindqvist_walk_v1", "rival_a": "crew_rival_a_walk_v1", "rival_b": "crew_rival_b_walk_v1"}


def build_walk(who, d, rep):
    arr = ap.key_adaptive(load_png(WALK[who]), 0.0)
    comps = sorted(components(arr), key=lambda c: c["cx"])
    if len(comps) != 4:
        rep["walk"] = "FAILED: %d components" % len(comps)
        return False
    frames = [crop_part(arr, c) for c in comps]
    hs = [f.shape[0] for f in frames]
    s = HEIGHT_M * PPM / float(np.mean([hs[1], hs[3]]))      # the two upright passing frames are 1.8 m
    fr = [sp.resize(f, (max(2, int(round(f.shape[1] * s))), max(2, int(round(f.shape[0] * s)))), False) for f in frames]
    W = max(f.shape[1] for f in fr) + 8
    H = max(f.shape[0] for f in fr)
    rep["walk_cell"] = [W, H]
    rep["walk_source"] = WALK[who]
    for i, f in enumerate(fr):
        cv = np.zeros((H, W, 4), np.float32)
        ys, xs = np.where(f[..., 3] > 0.5)
        ox = int(round(W / 2 - xs.mean()))
        ox = max(0, min(W - f.shape[1], ox))
        cv[H - f.shape[0]:, ox:ox + f.shape[1]] = f
        al = sp.grade(cv, GRADE)
        ap.put(d, "walk_%d" % i, al, ap.nkw(W, {"cyl": 0.38}))
    return True


def build(who):
    full, sheet = CREW[who]
    d = os.path.join(OUT, who)
    os.makedirs(d, exist_ok=True)
    rep = {"full": full, "sheet": sheet}
    fig = figure(who, full)
    fem = ap.emission_by(fig, "amber")
    alb = sp.grade(fig, GRADE)
    kw = ap.nkw(alb.shape[1], {"cyl": 0.42})
    rep["full_size"] = ap.put(d, "full", alb, kw, fem)
    if who in WALK:
        rep["parts"] = "route failed twice (parts sheets %s merged or duplicated limbs); fallback walk cycle" % sheet
        ok = build_walk(who, d, rep)
        common.save_manifest("crew_" + who, rep)
        print(who, "walk", "ok" if ok else "FAILED", rep.get("walk_cell"))
        return ok
    arr = ap.key_adaptive(load_png(sheet), 0.0)
    comps = components(arr)
    asg = assign(comps)
    if asg is None:
        rep["parts"] = "FAILED: %d components" % len(comps)
        common.save_manifest("crew_" + who, rep)
        print(who, "parts FAILED", len(comps))
        return False
    raw = {p: crop_part(arr, asg[p]) for p in PARTS}
    # scale: head + torso + thigh + shin, less overlaps (head neck stump, torso hip, thigh/shin overlaps) = 1.8 m
    stack = sum(raw[p].shape[0] for p in ("head", "torso", "thigh", "shin"))
    s = HEIGHT_M * PPM / (stack * (1 - 3 * MARGIN)) * CAL.get(who, 1.0)
    parts = {}
    for p in PARTS:
        h, w = raw[p].shape[:2]
        parts[p] = sp.resize(raw[p], (max(2, int(round(w * s))), max(2, int(round(h * s)))), False)
    piv = pivots(parts)
    rep["scale_from_sheet"] = round(float(s), 4)
    rep["parts"] = {}
    for p in PARTS:
        a = parts[p]
        al = sp.grade(a, GRADE)
        kw = ap.nkw(a.shape[1], {"bevel_radius": 6, "bevel_height_px": 3.0})
        r = ap.put(d, p, al, kw)
        r["pivots"] = piv[p]
        rep["parts"][p] = r
    rep["notes"] = ("pivot = joint with the parent, child = joint where the next part attaches; pixel coordinates "
                    "inside the part image, y down. Limbs hang vertical. Hierarchy: torso > head, upper_arm > "
                    "forearm, thigh > shin (torso pivot = hip, torso.neck and torso.shoulder attach head and arm).")
    common.save_manifest("crew_" + who, rep)
    print(who, "parts ok", {p: parts[p].shape[:2] for p in PARTS})
    return True


if __name__ == "__main__":
    if sys.argv[1] == "analyze":
        analyze()
    else:
        for w in (sys.argv[2:] or CREW):
            build(w)
