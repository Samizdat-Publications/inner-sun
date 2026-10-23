"""Draw the ship redesign options as to-scale cutaway schematics (no game change).

    python pipeline/ship_redesign_sketch.py

Writes docs/plans/ship_redesign/{today,option_a,option_b,option_c,all}.png. Each option is plain data
below: rooms (x, y, w, h in meters, label, kind), doors in vertical walls, hatches in floors, airlocks
(outer doors that vent a room to the rock), and the hull outline. 1 m grid, +y down, like the game.
"""
import os

from PIL import Image, ImageDraw, ImageFont

PPM = 46
PAD = 60
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "plans", "ship_redesign")

COL = {
    "helm": (70, 120, 170), "bracing": (150, 120, 60), "reactor": (60, 150, 90), "weapons": (170, 70, 60),
    "drill": (170, 110, 50), "coolant": (50, 140, 150), "medbay": (120, 160, 120), "lock": (150, 70, 130),
    "hall": (70, 74, 80), "store": (110, 100, 90),
}
BG = (22, 24, 28)
HULL = (48, 54, 62)
EDGE = (190, 196, 205)
DOOR = (240, 160, 50)
HATCH = (240, 220, 80)
AIRLOCK = (235, 70, 60)


def _font(size, bold=False):
    for name in (["arialbd.ttf", "seguisb.ttf"] if bold else ["arial.ttf", "segoeui.ttf"]):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


TODAY = {
    "title": "TODAY: Light Drill",
    "notes": ["6 rooms of 4 x 3 m in a 2 x 3 block", "every room is a system; no corridors",
              "3 doors, 4 hatches, no airlocks"],
    "size": (8, 9),
    "hull": [(0, 0), (8, 0), (8, 9), (0, 9)],
    "rooms": [(0, 0, 4, 3, "BRIDGE", "helm"), (4, 0, 4, 3, "BRACING", "bracing"),
              (0, 3, 4, 3, "REACTOR", "reactor"), (4, 3, 4, 3, "WEAPONS", "weapons"),
              (0, 6, 4, 3, "DRILL", "drill"), (4, 6, 4, 3, "COOLANT", "coolant")],
    "doors": [(4, 3), (4, 6), (4, 9)],
    "hatches": [(1, 3), (3, 6), (7, 3), (5, 6)],
    "airlocks": [],
    "crown": (0, 8),
}

# A: a central ladder spine with small pods hung off both sides; a tapered tower.
OPTION_A = {
    "title": "A: SPINE TOWER",
    "notes": ["a ladder spine; 8 small pods off it", "every pod has its own door, so fires",
              "and floods can be shut in; 2 airlocks", "tapered: narrow bridge, wide middle"],
    "size": (11, 13),
    "hull": [(3, 0), (8, 0), (9.5, 2), (11, 4.5), (11, 9.5), (9.5, 11), (8, 13), (3, 13), (1.5, 11), (0, 9.5), (0, 4.5), (1.5, 2)],
    "rooms": [(3.5, 0.5, 4, 2, "BRIDGE", "helm"),
              (5, 2.5, 1, 8.5, "", "hall"),
              (1.5, 2.5, 3.5, 2, "WEAPONS", "weapons"), (6, 2.5, 3.5, 2, "BRACING", "bracing"),
              (0.5, 4.5, 4.5, 3, "REACTOR", "reactor"), (6, 4.5, 4.5, 3, "MEDBAY", "medbay"),
              (0.5, 7.5, 4.5, 2, "COOLANT", "coolant"), (6, 7.5, 3, 2, "DIVE LOCK", "lock"),
              (3, 11, 5, 2, "DRILL", "drill")],
    "doors": [(5, 4.5), (6, 4.5), (5, 7.5), (6, 7.5), (5, 9.5), (6, 9.5)],
    "hatches": [(5.5, 2.5), (5.5, 11)],
    "airlocks": [(0.5, 9.5, "L"), (9, 9.5, "R")],
    "crown": (2.5, 8.5),
}

# B: three decks of different widths, like an oil rig; hatches alternate sides; sponson airlocks.
OPTION_B = {
    "title": "B: STACKED DECKS",
    "notes": ["3 decks: narrow top, wide middle,", "mid-size bottom; a corridor on each deck",
              "hatches alternate sides (longer walks)", "sponson airlocks on the wide deck"],
    "size": (13, 11),
    "hull": [(3.5, 0), (9.5, 0), (9.5, 3), (13, 3), (13, 7), (11, 7), (11, 11), (2, 11), (2, 7), (0, 7), (0, 3), (3.5, 3)],
    "rooms": [(3.5, 0.5, 3, 2.5, "BRIDGE", "helm"), (6.5, 0.5, 3, 2.5, "BRACING", "bracing"),
              (0, 3, 2, 4, "LOCK", "lock"), (2, 3, 3, 4, "WEAPONS", "weapons"), (5, 3, 3, 4, "REACTOR", "reactor"),
              (8, 3, 3, 4, "MEDBAY", "medbay"), (11, 3, 2, 4, "LOCK", "lock"),
              (2, 7, 3, 2.5, "COOLANT", "coolant"), (5, 7, 3, 2.5, "DRILL", "drill"), (8, 7, 3, 2.5, "DIVE LOCK", "lock"),
              (2, 9.5, 9, 1.5, "", "hall")],
    "doors": [(6.5, 3), (2, 7), (5, 7), (8, 7), (11, 7), (5, 9.5), (8, 9.5)],
    "hatches": [(4, 3), (9, 7), (3, 9.5), (10, 9.5)],
    "airlocks": [(0, 7, "L"), (12.2, 7, "R")],
    "crown": (2.5, 10.5),
}

# C: a compact FTL-style grid of 2 x 2 m rooms round a corridor ring; a teardrop that ends in the drill.
OPTION_C = {
    "title": "C: COMPACT GRID",
    "notes": ["11 small rooms of 2 x 2 m round a", "corridor ring (FTL-style paths)",
              "teardrop hull, the drill is its tip", "2 airlocks; doors on every room"],
    "size": (12, 12),
    "hull": [(4, 0), (8, 0), (10.5, 1.5), (12, 4), (12, 8), (10, 10.5), (8, 12), (4, 12), (2, 10.5), (0, 8), (0, 4), (1.5, 1.5)],
    "rooms": [(4, 0.5, 4, 2, "BRIDGE", "helm"),
              (2, 2.5, 8, 1, "", "hall"), (2, 6.5, 8, 1, "", "hall"), (2, 3.5, 1, 3, "", "hall"), (9, 3.5, 1, 3, "", "hall"),
              (0, 3.5, 2, 2, "WEAP", "weapons"), (10, 3.5, 2, 2, "BRACE", "bracing"),
              (3, 3.5, 3, 3, "REACTOR", "reactor"), (6, 3.5, 3, 3, "MEDBAY", "medbay"),
              (0, 5.5, 2, 2.5, "LOCK", "lock"), (10, 5.5, 2, 2.5, "LOCK", "lock"),
              (2, 7.5, 3, 2.5, "COOLANT", "coolant"), (7, 7.5, 3, 2.5, "STORES", "store"),
              (5, 7.5, 2, 2.5, "", "hall"), (4, 10, 4, 2, "DRILL", "drill")],
    "doors": [(2, 4), (10, 4), (3, 5), (9, 5), (6, 5), (2, 6), (10, 6), (5, 9), (7, 9)],
    "hatches": [(6, 2.5), (6, 10)],
    "airlocks": [(0, 8, "L"), (11.2, 8, "R")],
    "crown": (3.5, 8.5),
}


def draw(opt):
    w_m, h_m = opt["size"]
    W = int(w_m * PPM + PAD * 2)
    H = int(h_m * PPM + PAD * 2 + 70 + 34 * len(opt["notes"]) + 40)
    img = Image.new("RGB", (max(W, 560), H), BG)
    d = ImageDraw.Draw(img)
    ox = (img.width - w_m * PPM) / 2
    oy = PAD + 50

    def p(x, y):
        return (ox + x * PPM, oy + y * PPM)

    d.text((20, 18), opt["title"], fill=(240, 220, 160), font=_font(30, True))
    # Crown under the hull (the drill head).
    cx0, cx1 = opt["crown"]
    base = h_m
    d.polygon([p(cx0, base), p(cx1, base), p(cx1 - 0.6, base + 1.1), p(cx0 + 0.6, base + 1.1)], fill=(80, 70, 60), outline=EDGE)
    n = int((cx1 - cx0) / 0.7)
    for i in range(n):
        tx = cx0 + 0.7 + i * (cx1 - cx0 - 1.4) / max(1, n - 1) - 0.2
        d.rectangle([p(tx, base + 1.1), p(tx + 0.4, base + 1.4)], fill=(230, 110, 40))
    # Hull.
    d.polygon([p(x, y) for x, y in opt["hull"]], fill=HULL, outline=EDGE, width=3)
    # Rooms.
    for x, y, w, h, label, kind in opt["rooms"]:
        c = COL[kind]
        d.rectangle([p(x, y), p(x + w, y + h)], fill=tuple(int(v * 0.55) for v in c), outline=c, width=3)
        if label:
            f = _font(17 if w >= 3 else 14, True)
            tw = d.textlength(label, font=f)
            cxp, cyp = p(x + w / 2, y + h / 2)
            d.text((cxp - tw / 2, cyp - 10), label, fill=(235, 235, 235), font=f)
    # Doors in vertical walls: (x, floor_y) -> a 2 m tall opening, drawn as an orange bar.
    for x, fy in opt["doors"]:
        d.rectangle([p(x - 0.12, fy - 1.9), p(x + 0.12, fy)], fill=DOOR)
    # Hatches in floors: (x, y) -> a 0.8 m opening.
    for x, y in opt["hatches"]:
        d.rectangle([p(x - 0.45, y - 0.12), p(x + 0.45, y + 0.12)], fill=HATCH)
    # Airlocks: an outer door that vents the room to the rock.
    for x, y, side in opt["airlocks"]:
        x0 = x if side == "L" else x
        d.rectangle([p(x0, y - 1.9), p(x0 + 0.8, y)], outline=AIRLOCK, width=4)
        ax, ay = p(x0 + (0 if side == "L" else 0.8), y - 1.0)
        dx = -26 if side == "L" else 26
        d.line([(ax, ay), (ax + dx, ay)], fill=AIRLOCK, width=4)
        d.polygon([(ax + dx, ay - 7), (ax + dx + (-10 if side == "L" else 10), ay), (ax + dx, ay + 7)], fill=AIRLOCK)
    # Scale bar.
    sy = oy + (h_m + 1.8) * PPM
    d.line([(ox, sy), (ox + 2 * PPM, sy)], fill=EDGE, width=3)
    d.text((ox + 2 * PPM + 8, sy - 11), "2 m", fill=EDGE, font=_font(16))
    ny = sy + 30
    for line in opt["notes"]:
        d.text((24, ny), line, fill=(215, 215, 210), font=_font(20))
        ny += 34
    return img


def legend():
    img = Image.new("RGB", (560, 150), BG)
    d = ImageDraw.Draw(img)
    f = _font(18)
    items = [(DOOR, "door (open and close; shuts in fire, water, heat)"), (HATCH, "hatch (ladder between decks)"),
             (AIRLOCK, "airlock: vents a room to the rock (purge)"), (COL["hall"], "corridor (crew walk; no system)")]
    for i, (c, t) in enumerate(items):
        y = 14 + i * 32
        d.rectangle([16, y + 2, 44, y + 22], fill=c)
        d.text((56, y), t, fill=(220, 220, 215), font=f)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    imgs = []
    for name, opt in [("today", TODAY), ("option_a", OPTION_A), ("option_b", OPTION_B), ("option_c", OPTION_C)]:
        im = draw(opt)
        im.save(os.path.join(OUT, name + ".png"))
        imgs.append(im)
    lg = legend()
    W = sum(i.width for i in imgs) + 20 * (len(imgs) + 1)
    H = max(i.height for i in imgs) + lg.height + 40
    sheet = Image.new("RGB", (W, H), BG)
    x = 20
    for im in imgs:
        sheet.paste(im, (x, 20))
        x += im.width + 20
    sheet.paste(lg, (20, H - lg.height - 10))
    sheet.save(os.path.join(OUT, "all.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
