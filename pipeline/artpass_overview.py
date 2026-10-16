"""Overview sheet of the M1 art pass: room composites (wall + props + crew), fittings, rock tiles, crew.

    python pipeline/artpass_overview.py [out.jpg]      default harness/out/artpass/overview.jpg

Also renders a static puppet assembly of each cut-out character (rest pose from the pivots in
pipeline/manifests/crew_<name>.json) next to the full figure, to check scale and joint overlap.
Composites are unlit (albedo only, emission added), flat view of what the game will draw before lights.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SHIP = os.path.join(ROOT, "game", "assets", "ship")
CREW = os.path.join(ROOT, "game", "assets", "crew")
ROCK = os.path.join(ROOT, "game", "assets", "rock")


def L(folder, name, kind="albedo"):
    p = os.path.join(folder, f"{name}_{kind}.png")
    return Image.open(p).convert("RGBA") if os.path.exists(p) else None


def paste(dst, im, x, y, emission=None):
    dst.alpha_composite(im, (int(x), int(y)))
    if emission is not None:
        e = np.asarray(emission, np.float32) / 255.0
        d = np.asarray(dst.crop((int(x), int(y), int(x) + im.width, int(y) + im.height)), np.float32) / 255.0
        a = e[..., 3:4]
        d[..., :3] = np.clip(d[..., :3] + e[..., :3] * a * 0.9, 0, 1)
        dst.paste(Image.fromarray((d * 255).astype(np.uint8), "RGBA"), (int(x), int(y)))


FLOOR_Y = 440     # floor line inside a 640 x 480 room


def room(wall, props, crew=None):
    im = L(SHIP, wall).copy()
    g = L(SHIP, "floor_grating")
    for x in range(0, 640, g.width):
        im.alpha_composite(g, (x, FLOOR_Y))
    for name, x, ybottom_off in props:
        a = L(SHIP, name)
        paste(im, a, x, FLOOR_Y - a.height + ybottom_off, L(SHIP, name, "emission"))
    if crew:
        c = L(CREW, crew[0], "full") if False else Image.open(os.path.join(CREW, crew[0], "full_albedo.png")).convert("RGBA")
        paste(im, c, crew[1], FLOOR_Y - c.height + 6)
    return im


def puppet(who):
    d = os.path.join(CREW, who)
    man = json.load(open(os.path.join(ROOT, "pipeline", "manifests", f"crew_{who}.json"), encoding="utf-8"))["runs"][-1]
    if not isinstance(man.get("parts"), dict):
        return None
    P = {p: Image.open(os.path.join(d, p + "_albedo.png")).convert("RGBA") for p in man["parts"]}
    pv = {p: man["parts"][p]["pivots"] for p in man["parts"]}
    cv = Image.new("RGBA", (260, 330), (0, 0, 0, 0))
    hipx, hipy = 130, 190
    t = P["torso"]
    tx, ty = hipx - pv["torso"]["pivot"][0], hipy - pv["torso"]["pivot"][1]

    def put(part, jx, jy):
        im = P[part]
        cv.alpha_composite(im, (int(round(jx - pv[part]["pivot"][0])), int(round(jy - pv[part]["pivot"][1]))))
        return im

    # back to front: far arm (darkened copy), legs, torso, head, near arm
    th = pv["thigh"]
    kneex, kneey = hipx - th["pivot"][0] + th["child"][0], hipy - th["pivot"][1] + th["child"][1]
    put("thigh", hipx, hipy)
    put("shin", kneex, kneey)
    cv.alpha_composite(t, (int(tx), int(ty)))
    nk = pv["torso"]["neck"]
    put("head", tx + nk[0], ty + nk[1])
    sh = pv["torso"]["shoulder"]
    sx, sy = tx + sh[0], ty + sh[1]
    ua = pv["upper_arm"]
    put("upper_arm", sx, sy)
    put("forearm", sx - ua["pivot"][0] + ua["child"][0], sy - ua["pivot"][1] + ua["child"][1])
    return cv


def label(im, text, d=None):
    d = ImageDraw.Draw(im)
    d.text((6, 4), text, fill=(255, 220, 160))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "harness", "out", "artpass", "overview.jpg")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    rooms = [
        ("REACTOR (bake-off)", room("reactor_wall", [("reactor_core", 250, 0), ("lamp", 280, -250)], None)),
        ("BRIDGE", room("bridge_wall", [("bridge_helm", 160, 0)], ("vasquez", 60))),
        ("BRACING", room("bracing_wall", [("bracing_jack", 40, 0), ("bracing_manifold", 300, 0), ("bracing_jack", 440, 0)], None)),
        ("WEAPONS", room("weapons_wall", [("weapons_breech", 60, 0), ("weapons_ammo", 450, 0)], None)),
        ("DRILL ROOM", room("drill_wall", [("drill_motor", 120, 0), ("drill_bitrack", 470, 0)], None)),
        ("COOLANT AND PUMPS", room("coolant_wall", [("coolant_tank", 70, 0), ("coolant_tank", 300, 0), ("coolant_pump", 470, 0)], None)),
    ]
    # reactor room: the bake-off scene had the reactor on a plinth, bottom aligned
    W = 3 * 646
    sheet = Image.new("RGB", (W, 2 * 500 + 700 + 480 + 440), (22, 22, 22))
    for i, (t, im) in enumerate(rooms):
        x, y = (i % 3) * 646, (i // 3) * 500
        sheet.paste(im.convert("RGB"), (x, y + 18))
        label(sheet.crop((x, y, x + 640, y + 18)) and sheet, "")
        ImageDraw.Draw(sheet).text((x + 6, y + 3), t, fill=(255, 220, 160))
    y0 = 1000
    # fittings row
    fits = ["door_closed", "door_open", "ladder", "hatch_rim", "floor_grating", "hull_top", "hull_left", "hull_right"]
    x = 0
    ImageDraw.Draw(sheet).text((6, y0), "FITTINGS", fill=(255, 220, 160))
    bg = Image.new("RGB", (W, 360), (60, 60, 70))
    for n in fits:
        a = L(SHIP, n)
        b = Image.new("RGB", a.size, (60, 60, 70))
        b.paste(a, mask=a)
        bg.paste(b, (x, 10))
        x += a.width + 12
    # hull strips tiled to show seamlessness, ladder tiled
    lad = L(SHIP, "ladder")
    for k in range(2):
        bg.alpha_composite(lad, (x, 10 + k * 160)) if False else bg.paste(lad, (x, 10 + k * 160), lad)
    x += lad.width + 12
    gr = L(SHIP, "floor_grating")
    for k in range(2):
        bg.paste(gr, (x + k * gr.width, 10), gr)
    ht = L(SHIP, "hull_top")
    for k in range(2):
        bg.paste(ht, (x + k * ht.width, 60), ht)
    cr = L(SHIP, "drill_crown")
    cre = L(SHIP, "drill_crown", "emission")
    cc = Image.new("RGBA", cr.size, (60, 60, 70, 255))
    cc.alpha_composite(cr)
    paste(cc, Image.new("RGBA", (1, 1), (0, 0, 0, 0)), 0, 0)
    e = np.asarray(cre, np.float32) / 255.0
    d = np.asarray(cc, np.float32) / 255.0
    d[..., :3] = np.clip(d[..., :3] + e[..., :3] * e[..., 3:4] * 0.9, 0, 1)
    ccim = Image.fromarray((d * 255).astype(np.uint8), "RGBA").convert("RGB").resize((640, 150))
    bg.paste(ccim, (x, 150))
    sheet.paste(bg, (0, y0 + 16))
    # rocks row
    y1 = y0 + 16 + 360 + 6
    ImageDraw.Draw(sheet).text((6, y1), "ROCK TILES (128 px, each shown 2 x 2 tiled; gem with emission)", fill=(255, 220, 160))
    x = 0
    for n in ["soft", "rock", "dense", "hard", "iron", "gem", "water", "shaft"]:
        a = L(ROCK, n)
        t2 = Image.new("RGB", (256, 256))
        for ix in range(2):
            for iy in range(2):
                t2.paste(a.convert("RGB"), (ix * 128, iy * 128))
        if n == "gem":
            e = L(ROCK, n, "emission")
            if e is not None:
                for ix in range(2):
                    for iy in range(2):
                        ee = np.asarray(e, np.float32) / 255.0
                        reg = np.asarray(t2.crop((ix * 128, iy * 128, ix * 128 + 128, iy * 128 + 128)), np.float32) / 255.0
                        reg = np.clip(reg + ee[..., :3] * ee[..., 3:4] * 0.9, 0, 1)
                        t2.paste(Image.fromarray((reg * 255).astype(np.uint8)), (ix * 128, iy * 128))
        sheet.paste(t2, (x, y1 + 16))
        ImageDraw.Draw(sheet).text((x + 3, y1 + 16 + 240), n, fill=(255, 255, 255))
        x += 262
    # crew row
    y2 = y1 + 16 + 262
    ImageDraw.Draw(sheet).text((6, y2), "CREW: idle figure, puppet assembly (or walk frames)", fill=(255, 220, 160))
    x = 0
    for who in ["vasquez", "okafor", "lindqvist", "rival_a", "rival_b"]:
        f = Image.open(os.path.join(CREW, who, "full_albedo.png")).convert("RGBA")
        b = Image.new("RGB", (f.width, 300), (60, 60, 70))
        b.paste(f, (0, 300 - f.height), f)
        sheet.paste(b, (x, y2 + 16))
        x += f.width + 4
        pp = puppet(who)
        if pp is not None:
            b = Image.new("RGB", pp.size, (60, 60, 70))
            b.paste(pp, (0, 0), pp)
            sheet.paste(b, (x, y2 + 16 - 20))
            x += pp.width + 8
        else:
            for i in range(4):
                p = os.path.join(CREW, who, f"walk_{i}_albedo.png")
                if os.path.exists(p):
                    w = Image.open(p).convert("RGBA")
                    b = Image.new("RGB", w.size, (60, 60, 70))
                    b.paste(w, (0, 0), w)
                    b = b.resize((int(w.width * 0.7), int(w.height * 0.7)))
                    sheet.paste(b, (x, y2 + 16 + 90))
                    x += b.width + 2
            x += 6
    sheet = sheet.crop((0, 0, W, y2 + 16 + 340))
    sheet.save(out, quality=88)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
