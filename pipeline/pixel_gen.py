"""PixelLab (pixflux, v2 API) candidate generation for the style bake-off.

    python pipeline/pixel_gen.py wall,reactor,lamp,grating,crew --seeds 1,2,3

Candidates go to harness/out/pixel_cands/<item>_s<seed>.png (not committed). The chosen ones are
promoted by pipeline/pixel_post.py. Every call is logged to docs/SPEND.md and the manifest.
Native scale is 40 px per meter: room 160x120, crew 72 px tall.
"""
import argparse
import base64
import io
import json
import os
import sys
import time
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

API = "https://api.pixellab.ai/v2"
OUT = os.path.join(common.ROOT, "harness", "out", "pixel_cands")

STYLE = ("1970s retro-futurist black-budget hardware, grimy lived-in industrial pulp sci-fi, "
         "dark moody palette, warm brass and amber accents, cold blue-grey steel, "
         "crisp high-resolution pixel art, strong readable shapes")

ITEMS = {
    "wall": dict(
        size=(160, 120), no_bg=False, view="side", direction=None, outline="lineless",
        shading="detailed shading", detail="highly detailed",
        prompt=("flat side-on interior wall of a drill ship reactor room, riveted dark steel plates in a grid "
                "with raised rivet rows, vertical conduit pipes and a cable tray, three round brass and enamel "
                "pressure gauges, a small hazard stripe panel, subtle grime, seen straight on, no floor, no "
                "ceiling, no people, " + STYLE)),
    "reactor": dict(
        size=(64, 72), no_bg=True, view="side", direction="east", outline="single color black outline",
        shading="detailed shading", detail="highly detailed",
        prompt=("squat cylindrical nuclear reactor core machine, side view, steel housing with brass bands, "
                "yellow and black hazard stripes on the base, a round glowing green-yellow core window in the "
                "middle, chunky bolts, thick pipes on top, standing on a short plinth, " + STYLE)),
    "lamp": dict(
        size=(32, 24), no_bg=True, view="side", direction="east", outline="single color black outline",
        shading="medium shading", detail="medium detail",
        prompt=("industrial ceiling lamp fixture, caged bulb hanging from a short steel bracket, brass cap, "
                "bulb glass clear, seen from the side, " + STYLE)),
    "grating": dict(
        size=(160, 12), no_bg=False, view="side", direction=None, outline="lineless",
        shading="medium shading", detail="medium detail",
        prompt=("strip of steel floor grating seen from the side, metal diamond plate and grille edge, "
                "thin horizontal strip, " + STYLE)),
    "crew": dict(
        size=(48, 72), no_bg=True, view="side", direction="east", outline="single color black outline",
        shading="detailed shading", detail="highly detailed",
        prompt=("full body expedition engineer standing, facing right, side view, grimy olive-brown coverall "
                "jumpsuit, yellow hard hat with a headlamp, leather tool belt with tools, heavy work boots, "
                "gloves, slight stubble, " + STYLE)),
}


def _key():
    k = common.get_key("PIXELLAB_API_KEY",)
    if not k:
        sys.exit("pixel_gen: no PixelLab key in the environment or the shared .env")
    return k


def post(path, body, key):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), method="POST",
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=240) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode(errors="replace")[:400]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("items")
    ap.add_argument("--seeds", default="1")
    ap.add_argument("--extra", default="", help="text appended to every prompt")
    ap.add_argument("--tag", default="")
    a = ap.parse_args()
    key = _key()
    os.makedirs(OUT, exist_ok=True)
    total = 0.0
    for item in a.items.split(","):
        spec = ITEMS[item]
        for seed in [int(s) for s in a.seeds.split(",")]:
            w, h = spec["size"]
            prompt = spec["prompt"] + (" " + a.extra if a.extra else "")
            body = {"description": prompt, "image_size": {"width": w, "height": h},
                    "no_background": spec["no_bg"], "view": spec["view"], "outline": spec["outline"],
                    "shading": spec["shading"], "detail": spec["detail"], "seed": seed,
                    "text_guidance_scale": 8}
            if spec["direction"]:
                body["direction"] = spec["direction"]
            r = post("/create-image-pixflux", body, key)
            if "error" in r:
                print(item, seed, "FAILED", r["error"], r["body"][:200])
                continue
            usd = float((r.get("usage") or {}).get("usd") or 0.0)
            total += usd
            b64 = r["image"]["base64"].split(",", 1)[-1]
            p = os.path.join(OUT, f"{item}{a.tag}_s{seed}.png")
            open(p, "wb").write(base64.b64decode(b64))
            print(item, seed, "ok", f"${usd:.3f}", p)
            common.save_manifest("pixel_" + item, {"service": "PixelLab", "endpoint": "create-image-pixflux",
                                                   "request": body, "usd": usd, "output": os.path.relpath(p, common.ROOT)})
            common.log_spend("PixelLab pixflux", f"bakeoff pixel {item}{a.tag} seed {seed}", usd)
    print(f"total ${total:.3f}")


if __name__ == "__main__":
    main()
