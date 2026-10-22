"""Regenerate candidates for the painted drill crown (same prompt/model as artpass fit_crown v1, no reference).

    python pipeline/crown_regen.py gen --n 8 [--start 1]     # Gemini calls -> harness/out/crown_candidates/raw_NN.png
    python pipeline/crown_regen.py post                       # raw -> crown_NN_{albedo,normal,emission}.png + sheet.png

Post uses exactly the artpass_post.py drill_crown recipe (crop 0.085, key, trim, resize to 1280x300, hot emission,
grade 0.34, normals with bevel 14 / 6.0). Nothing under game/ is touched.
"""
import glob
import io
import os
import sys
import base64

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import painted_gen as pg  # noqa: E402
import artpass_gen as ag  # noqa: E402
import artpass_post as ap  # noqa: E402
import style_post as sp  # noqa: E402

OUT = os.path.join(common.ROOT, "harness", "out", "crown_candidates")
CUR = os.path.join(common.ROOT, "game", "assets", "ship", "drill_crown_albedo.png")


def gen(n, start):
    key = common.get_key("GEMINI_API_KEY", "GOOGLE_API_KEY")
    if not key:
        sys.exit("no Gemini key")
    os.makedirs(OUT, exist_ok=True)
    aspect, prompt = ag.ITEMS["fit_crown"]
    for v in range(start, start + n):
        body = {"contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect, "imageSize": "2K"}}}
        ok = False
        for attempt in range(3):
            r, err = pg.http_post(f"{pg.BASE}/models/gemini-3-pro-image:generateContent", body, key)
            b64 = pg.find_image(r) if r is not None else None
            if b64:
                Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA").save(os.path.join(OUT, "raw_%02d.png" % v))
                common.save_manifest("crown_regen", {
                    "service": "Gemini", "model": "gemini-3-pro-image", "aspect": aspect, "size": "2K", "variant": v,
                    "prompt": prompt, "reference": None, "seed": "none (the API gives no seed)",
                    "usd_estimate": ag.EST, "output": "harness/out/crown_candidates/raw_%02d.png" % v, "attempts": attempt + 1})
                common.log_spend("Gemini gemini-3-pro-image", "crown regen candidate %02d (stray cones fix)" % v, ag.EST)
                ok = True
                break
        print(v, "ok" if ok else "FAILED " + str(err)[:150], flush=True)


def post():
    tiles = []
    cur = Image.open(CUR).convert("RGBA")
    for p in sorted(glob.glob(os.path.join(OUT, "raw_*.png"))):
        nn = os.path.basename(p)[4:6]
        im = Image.open(p).convert("RGBA")
        arr = sp.trim(ap.key_adaptive(im, ap.CROPS["fit_crown"]))
        tw, th = 1280, 300
        arr = sp.resize(arr, (tw, th), False)
        em = ap.emission_by(arr, "hot")
        alb = sp.grade(arr, ap.PROP_TARGET)
        name = "crown_" + nn
        ap.put(OUT, name, alb, ap.nkw(tw, {"bevel_radius": 14, "bevel_height_px": 6.0}), em)
        tiles.append((nn, Image.open(os.path.join(OUT, name + "_albedo.png")).convert("RGBA")))
    W, H, pad = 1280, 300, 36
    rows = [("CURRENT", cur)] + [("crown_" + n, t) for n, t in tiles]
    sheet = Image.new("RGBA", (W + 20, len(rows) * (H + pad) + 10), (40, 40, 48, 255))
    d = ImageDraw.Draw(sheet)
    for i, (lab, t) in enumerate(rows):
        y = 10 + i * (H + pad)
        d.text((12, y + 4), lab, fill=(255, 255, 255, 255))
        sheet.alpha_composite(t, (10, y + pad - 8))
    sheet.convert("RGB").save(os.path.join(OUT, "sheet.png"))
    print("sheet", sheet.size)


if __name__ == "__main__":
    if sys.argv[1] == "gen":
        a = sys.argv[2:]
        gen(int(a[a.index("--n") + 1]) if "--n" in a else 8, int(a[a.index("--start") + 1]) if "--start" in a else 1)
    else:
        post()
