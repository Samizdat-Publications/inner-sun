"""Painted pulp illustration candidates for the style bake-off (Gemini image models, REST, no SDK needed).

    python pipeline/painted_gen.py wall,reactor,lamp,floor,crew --variants 2 [--model gemini-3-pro-image]

UNTESTED against the live API in the session that wrote it (no usable key was available), so the first call
may need the model id or endpoint adjusted. Current docs (checked 2026-10-15, ai.google.dev image-generation):
models gemini-nano-banana-2.1 (default recommendation), gemini-3-pro-image (premium), gemini-3.1-flash-image,
gemini-3.1-flash-lite-image; the new Interactions endpoint POST /v1beta/interactions with response_format
{type: image, aspect_ratio, image_size}; the classic POST /v1beta/models/<id>:generateContent also still exists.
This script tries Interactions first and falls back to generateContent once.

Candidates go to harness/out/painted_cands/<item>_v<n>.png. Props are requested on a flat magenta key
(#ff00ff) which pipeline/style_post.py keys out. Every call is logged to docs/SPEND.md (flat estimate per
image, see EST_USD) and the manifest. Do not run it in a loop: at most 2 retries per failed call.
"""
import argparse
import base64
import io
import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

BASE = "https://generativelanguage.googleapis.com/v1beta"
OUT = os.path.join(common.ROOT, "harness", "out", "painted_cands")
EST_USD = {"gemini-3-pro-image": 0.14, "gemini-nano-banana-2.1": 0.07, "gemini-3.1-flash-image": 0.07}

STYLE = ("painted pulp magazine cover illustration, 1970s retro-futurist black-budget hardware, gouache and oil "
         "painterly brushwork with visible confident strokes, strong value structure, dark moody palette with warm "
         "amber and brass accents and cold blue-grey steel, riveted steel, enamel and brass gauges, hazard stripes, "
         "chunky switches, grimy and lived in, Journey to the Center of the Earth meets The X-Files. "
         "Flat orthographic side view, NO perspective, NO vignette, NO text, NO border, evenly lit (no dramatic "
         "cast shadows, the game adds lighting), readable shapes at small size.")

KEY = ("Background: perfectly flat solid magenta #ff00ff, nothing else in the background, no shadow on the "
       "background, subject fully inside the frame with a small margin.")

ITEMS = {
    "wall": ("4:3", "The back wall of a drill-ship reactor room, interior cutaway, seen straight on: riveted dark steel "
             "plates in a grid, vertical conduits at both sides, a cable tray across the upper third, three round brass "
             "and enamel pressure gauges with cream faces, a small hazard stripe panel, a junction box with switches, a "
             "vent grille. Fills the whole frame edge to edge, no floor, no ceiling, no people. " + STYLE),
    "reactor": ("1:1", "A squat cylindrical reactor core machine about as tall as it is wide, standing on a plinth with "
                "yellow and black hazard stripes, steel housing with brass bands, a round brass-bezel porthole in the "
                "middle with a BRIGHT GLOWING GREEN-YELLOW CORE visible inside, domed cap with a short stack, two thick "
                "side pipes with flanges, a small control box with three buttons. " + STYLE + " " + KEY),
    "lamp": ("1:1", "A caged industrial ceiling lamp fixture hanging from a short steel bracket, conical enamel shade, "
             "brass cap, wire cage, a BRIGHT WARM WHITE-HOT bulb at the centre. " + STYLE + " " + KEY),
    "floor": ("21:9", "A long horizontal steel floor edge beam seen from the side: tread plate on top, an I-beam web with "
              "round lightening holes, rivets, a yellow safety nosing line. Fills the whole frame edge to edge. " + STYLE),
    "crew": ("3:4", "Full body expedition engineer standing, facing RIGHT in strict side view, grimy olive coverall "
             "jumpsuit, yellow hard hat with a small headlamp whose lens is bright white, leather tool belt with a "
             "hammer and pouches, heavy boots, gloves, stubble, relaxed idle stance, feet at the very bottom of the "
             "frame. " + STYLE + " " + KEY),
}


def http_post(url, body, key):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={"x-goog-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.load(r), None
    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}: {e.read().decode(errors='replace')[:300]}"
    except Exception as e:  # noqa: BLE001
        return None, str(e)


def find_image(obj):
    """Depth-first search a response for base64 image data (field 'data' or 'inlineData.data')."""
    if isinstance(obj, dict):
        for k in ("data", "image_bytes", "bytesBase64Encoded"):
            v = obj.get(k)
            if isinstance(v, str) and len(v) > 2000:
                return v
        for v in obj.values():
            r = find_image(v)
            if r:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_image(v)
            if r:
                return r
    return None


def generate(model, prompt, aspect, key, size="2K"):
    body = {"model": model, "input": [{"type": "text", "text": prompt}],
            "response_format": {"type": "image", "mime_type": "image/png", "aspect_ratio": aspect, "image_size": size}}
    r, err = http_post(BASE + "/interactions", body, key)
    if r is None:
        body2 = {"contents": [{"parts": [{"text": prompt}]}],
                 "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect, "imageSize": size}}}
        r, err2 = http_post(f"{BASE}/models/{model}:generateContent", body2, key)
        if r is None:
            return None, f"interactions: {err} | generateContent: {err2}"
    b64 = find_image(r)
    if not b64:
        return None, "no image in the response"
    return base64.b64decode(b64), None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("items")
    ap.add_argument("--variants", type=int, default=1)
    ap.add_argument("--model", default="gemini-3-pro-image")
    ap.add_argument("--start", type=int, default=1)
    ap.add_argument("--size", default="2K")
    a = ap.parse_args()
    key = common.get_key("GEMINI_API_KEY", "GOOGLE_API_KEY")
    if not key:
        sys.exit("painted_gen: no Gemini key in the environment or the shared .env")
    os.makedirs(OUT, exist_ok=True)
    total = 0.0
    for item in a.items.split(","):
        aspect, prompt = ITEMS[item]
        for v in range(a.start, a.start + a.variants):
            data, err = generate(a.model, prompt, aspect, key, a.size)
            if data is None:
                print(item, v, "FAILED", err)
                continue
            from PIL import Image
            p = os.path.join(OUT, f"{item}_v{v}.png")
            Image.open(io.BytesIO(data)).convert("RGBA").save(p)
            usd = EST_USD.get(a.model, 0.10)
            total += usd
            print(item, v, "ok", p)
            common.save_manifest("painted_" + item, {"service": "Gemini", "model": a.model, "aspect": aspect,
                                                      "size": a.size, "prompt": prompt, "variant": v,
                                                      "usd_estimate": usd, "output": os.path.relpath(p, common.ROOT)})
            common.log_spend("Gemini " + a.model, f"bakeoff painted {item} v{v}", usd)
    print(f"estimated total ${total:.2f}")


if __name__ == "__main__":
    main()
