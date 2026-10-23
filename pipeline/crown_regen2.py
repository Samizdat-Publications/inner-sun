"""Crown regen round 2. Track A: image edit of the CURRENT crown (cutter row repair), body kept from the original
via a feathered band composite. Track B: fresh generations with explicit cutter-row constraints.

    python pipeline/crown_regen2.py A --n 10 [--start 1]
    python pipeline/crown_regen2.py B --n 6 [--start 1]
    python pipeline/crown_regen2.py post        # raw -> r2_NN maps, composite for A
Outputs under harness/out/crown_candidates/round2/. Nothing under game/ is touched.
"""
import base64, glob, io, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common, painted_gen as pg, artpass_gen as ag, artpass_post as ap, style_post as sp  # noqa: E402

OUT = os.path.join(common.ROOT, "harness", "out", "crown_candidates", "round2")
CUR = os.path.join(common.ROOT, "game", "assets", "ship", "drill_crown_albedo.png")
W, H = 1280, 300
PADH = 549   # 21:9 canvas
EDIT = ("Keep this image exactly the same: the steel disc body, collar, panels, rivets, gauges, switches, hazard stripes, "
        "smoke, colours, lighting, brushwork, composition, size and flat magenta background must not change at all. "
        "Change ONLY the row of cutter teeth along the bottom edge: make it one single even, regular, continuous row of "
        "identical glowing orange-red rectangular carbide teeth, evenly spaced, all the same size and shape, the same "
        "style as the existing teeth. Remove the two round cone-shaped spiral drill bits right of the centre (and every "
        "other cone or drill bit), and remove anything hanging below the row of teeth that does not belong, leaving "
        "flat magenta below the teeth.")
TAIL = (" The cutter edge is ONE single continuous row of identical rectangular cutter teeth, evenly spaced, all the same "
        "size, glowing hot orange-red at the tips, nothing hanging below the row, NO cone cutters, NO spiral drill bits, "
        "NO round bits, perfectly symmetrical left to right.")


def call(parts, aspect, key):
    body = {"contents": [{"parts": parts}], "generationConfig": {"responseModalities": ["IMAGE"],
            "imageConfig": {"aspectRatio": aspect, "imageSize": "2K"}}}
    err = None
    for attempt in range(3):
        r, err = pg.http_post(f"{pg.BASE}/models/gemini-3-pro-image:generateContent", body, key)
        b64 = pg.find_image(r) if r is not None else None
        if b64:
            return Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA"), attempt + 1, None
    return None, 3, err


def gen(track, n, start):
    key = common.get_key("GEMINI_API_KEY", "GOOGLE_API_KEY")
    if not key:
        sys.exit("no Gemini key")
    os.makedirs(OUT, exist_ok=True)
    aspect, base = ag.ITEMS["fit_crown"]
    if track == "A":
        cur = Image.open(CUR).convert("RGBA")
        can = Image.new("RGBA", (W, PADH), (255, 0, 255, 255))
        can.alpha_composite(cur, (0, (PADH - H) // 2))
        buf = io.BytesIO(); can.convert("RGB").save(buf, "PNG")
        parts = [{"text": EDIT}, {"inlineData": {"mimeType": "image/png", "data": base64.b64encode(buf.getvalue()).decode()}}]
        prompt = EDIT
    else:
        prompt = base + TAIL
        parts = [{"text": prompt}]
    for v in range(start, start + n):
        im, att, err = call(parts, aspect, key)
        if im:
            im.save(os.path.join(OUT, "raw%s_%02d.png" % (track, v)))
            common.save_manifest("crown_regen2", {"service": "Gemini", "model": "gemini-3-pro-image", "track": track,
                "aspect": aspect, "size": "2K", "variant": v, "prompt": prompt,
                "reference": "game/assets/ship/drill_crown_albedo.png on magenta 1280x549" if track == "A" else None,
                "seed": "none (the API gives no seed)", "usd_estimate": ag.EST,
                "output": "harness/out/crown_candidates/round2/raw%s_%02d.png" % (track, v), "attempts": att})
            common.log_spend("Gemini gemini-3-pro-image", "crown regen round2 track %s #%02d" % (track, v), ag.EST * att)
        print(track, v, "ok" if im else "FAILED " + str(err)[:150], flush=True)


def band_mask(h, y0=0.50, y1=0.58):
    ys = np.arange(h) / h
    m = np.clip((ys - y0) / (y1 - y0), 0, 1)
    return (m * m * (3 - 2 * m))[:, None]


def register(im, cur):
    """Map the edited canvas back onto the original crown: search scale and offset on the body region."""
    big = np.asarray(im.convert("RGB").resize((W, PADH), Image.LANCZOS), np.float32) / 255.0
    c = cur[..., :3]
    ca = cur[..., 3]
    y0 = (PADH - H) // 2
    best = (1e9, 1.0, 0, 0)
    ys = np.arange(70, 165)
    for sy in np.arange(0.94, 1.065, 0.01):
        for dy in range(-24, 25, 2):
            # source row for output row y: (y + y0 + dy - PADH/2)/sy + PADH/2
            src = ((ys + y0 + dy - PADH / 2) / sy + PADH / 2)
            lo = np.floor(src).astype(int)
            if lo.min() < 0 or lo.max() >= PADH - 1:
                continue
            f = (src - lo)[:, None, None]
            rows = big[lo] * (1 - f) + big[lo + 1] * f
            m = ca[ys][..., None]
            e = float((np.abs(rows[:, 100:-100] - c[ys][:, 100:-100]) * m[:, 100:-100]).mean())
            if e < best[0]:
                best = (e, sy, dy, 0)
    e, sy, dy, _ = best
    ys_all = np.arange(H)
    src = ((ys_all + y0 + dy - PADH / 2) / sy + PADH / 2)
    src = np.clip(src, 0, PADH - 1.001)
    lo = np.floor(src).astype(int)
    f = (src - lo)[:, None, None]
    out = big[lo] * (1 - f) + big[lo + 1] * f
    return out, e, sy, dy


def process(path, track):
    im = Image.open(path).convert("RGBA")
    if track == "A":
        cur = np.asarray(Image.open(CUR).convert("RGBA"), np.float32) / 255.0
        reg, e, sy, dy = register(im, cur)
        print("  reg err %.4f sy %.2f dy %d" % (e, sy, dy))
        # key the magenta of the registered image to get its alpha
        tmp = Image.fromarray((np.dstack([reg, np.ones((H, W))]) * 255).astype(np.uint8), "RGBA")
        k = ap.key_adaptive(tmp, 0.0)
        r_, g_, b_ = k[..., 0], k[..., 1], k[..., 2]
        cast = np.clip(np.minimum(r_ - g_, b_ - g_) * 3, 0, 1)      # magenta cast the key left on the metal
        cast = ndi.gaussian_filter(cast, 1.0)
        for ch in (0, 2):
            k[..., ch] = k[..., ch] - cast * (k[..., ch] - g_) * 1.0
        m = band_mask(H, 0.60, 0.66)[..., None]
        rgb = cur[..., :3] * (1 - m) + k[..., :3] * m
        al = cur[..., 3:4] * (1 - m) + k[..., 3:4] * m
        # drop pinkish leftovers in the band
        return np.dstack([rgb, np.clip(al, 0, 1)]).astype(np.float32)
    arr = sp.trim(ap.key_adaptive(im, ap.CROPS["fit_crown"]))
    arr = sp.resize(arr, (W, H), False)
    return sp.grade(arr, ap.PROP_TARGET)


def post():
    for p in sorted(glob.glob(os.path.join(OUT, "raw?_*.png"))):
        tr, nn = os.path.basename(p)[3], os.path.basename(p)[5:7]
        alb = process(p, tr)
        em = ap.emission_by(alb, "hot")
        ap.put(OUT, "cand%s_%s" % (tr, nn), alb, ap.nkw(W, {"bevel_radius": 14, "bevel_height_px": 6.0}), em)
        print("post", tr, nn, flush=True)


if __name__ == "__main__":
    c = sys.argv[1]
    a = sys.argv[2:]
    if c == "post":
        post()
    else:
        gen(c, int(a[a.index("--n") + 1]), int(a[a.index("--start") + 1]) if "--start" in a else 1)
