"""M1 art pass generation (painted pulp, Gemini gemini-3-pro-image, same call and STYLE/KEY as painted_gen.py).

    python pipeline/artpass_gen.py wall_bridge,wall_bracing --variants 2 [--workers 4]
    python pipeline/artpass_gen.py crew_vasquez_parts --ref harness/out/artpass_cands/crew_vasquez_full_v1.png

Candidates go to harness/out/artpass_cands/<item>_v<n>.png (gitignored; prompts and parameters are kept in
pipeline/manifests/artpass_<item>.json). Reference images are passed as an inlineData part next to the text
part of generateContent (documented multimodal input). Each call is logged to docs/SPEND.md (flat estimate).
A failed call is retried at most twice, then reported.
"""
import argparse
import base64
import io
import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import painted_gen as pg  # noqa: E402

OUT = os.path.join(common.ROOT, "harness", "out", "artpass_cands")
STYLE, KEY = pg.STYLE, pg.KEY
EST = 0.14
LOCK = threading.Lock()

ROOM_TAIL = (" Fills the whole frame edge to edge like a painted backdrop, no floor, no ceiling, no people, no free-standing "
             "machinery in front of the wall (machines are separate objects), the wall itself carries the character of "
             "the room. ")


def room(desc):
    return ("4:3", "The back wall of a drill-ship room, interior cutaway, seen straight on: " + desc + ROOM_TAIL + STYLE)


def prop(aspect, desc):
    return (aspect, desc + " Flat front elevation, orthographic, subject centred. " + STYLE + " " + KEY)


ROCK_STYLE = ("painted pulp magazine illustration of natural rock, gouache and oil painterly brushwork with confident "
              "strokes, strong value structure, moody palette, flat even lighting, seen straight on, orthographic. "
              "ONLY natural stone and minerals: NO machinery, NO metal plates, NO rivets, NO gauges, NO switches, NO "
              "pipes, NO hazard stripes, NO text, NO border, NO vignette, NO objects of any kind.")


def rocktex(desc):
    return ("1:1", desc + " Fills the whole frame edge to edge. " + ROCK_STYLE)


def tex(aspect, desc):
    return (aspect, desc + " Fills the whole frame edge to edge, flat even lighting, no objects, no border. " + STYLE)


CREW_COMMON = ("Full body, facing RIGHT in strict side view (profile, not three quarter), relaxed idle stance, both feet "
               "flat on the ground at the very bottom of the frame, arms hanging naturally at the sides, the whole "
               "figure from head to boots visible, nothing under the boots: no floor, no ground, no grating, no platform, no "
               "objects or machinery around the figure. ")

CREW = {
    "vasquez": ("a woman in her thirties, the ship's pilot: a worn brown leather flight jacket with a fleece collar over "
                "a slate-blue coverall, a radio headset with a boom microphone, short dark hair, tan flying gloves, "
                "lace-up boots, a brass wristwatch"),
    "okafor": ("a broad-shouldered bald man in his forties, the reactor engineer: a heavy scorched leather welding apron "
               "over a grey coverall, welding goggles pushed up on his forehead, thick gauntlet gloves, short beard, "
               "heavy steel-toe boots"),
    "lindqvist": ("a tall lean blond young man, the repair technician: a many-pocketed olive utility vest over a rust-orange "
                  "coverall, a big steel pipe wrench strapped diagonally across his back, a knit cap, tool pouches on "
                  "the belt, work boots"),
    "rival_a": ("a rival black-budget crewman in dark charcoal coveralls with red piping, a round sealed dome helmet with "
                "a dark smoked visor and a small respirator, black gloves and boots, stenciled shoulder patch without "
                "readable letters"),
    "rival_b": ("a rival black-budget crewman in dark maroon-black coveralls, an angular visored hardhat with a rubber "
                "respirator mask and round goggles, bandolier of canisters across the chest, black gloves, heavy boots"),
}


def crew_full(who):
    return ("3:4", "Character: " + CREW[who] + ". " + CREW_COMMON + STYLE + " " + KEY)


def crew_parts(who):
    return ("3:4", "Use the attached image as the exact reference for this character (same face, outfit, colours, gear, "
            "painting style, same scale). Draw a CUT-OUT PUPPET PARTS SHEET of this same character: six separate "
            "body parts, each isolated and not touching any other part, with wide empty gaps between them, all "
            "in strict side view facing right, laid out in a grid of 2 columns and 3 rows. Top row: left the HEAD "
            "with neck stump and any headgear, right the TORSO with the belt and any torso gear (no arms, no legs). "
            "Middle row: left the UPPER ARM (shoulder to elbow, hanging straight down, vertical), right the FOREARM "
            "WITH HAND (elbow to fingertips, hanging straight down, vertical, hand relaxed). Bottom row: left the "
            "THIGH (hip to knee, vertical), right the SHIN WITH BOOT (knee to sole, vertical, boot pointing right, "
            "sole flat at the bottom). Every part is drawn a little longer than the real joint, with a plain "
            "rounded continuation of the sleeve or trouser past each joint end, so the parts can be rotated at "
            "the joints and overlap without gaps. Each part is a complete painted object, nothing cut off. "
            "No second arm or leg, no extra items, no labels. EXACTLY SIX objects on the sheet and no more: never "
            "draw a pair of boots or both legs; the upper arm is only the sleeve from shoulder to elbow (no hand); the "
            "forearm piece starts at the elbow and ends with the glove or hand; the thigh is a vertical trouser tube "
            "that ends in a plain cut at the knee with NO boot or shoe on it; the shin piece is the lower trouser "
            "leg with ONE boot. Parts stand upright and well apart, none overlapping another, a clean flat magenta "
            "gap between all of them, no shadows or smudges on the background. " + STYLE + " " + KEY)


def crew_walk(who):
    return ("16:9", "Use the attached image as the exact reference for this character (same face, outfit, colours, gear, "
            "painting style). Draw a WALK CYCLE SPRITE SHEET of this same character: exactly FOUR full-body figures in "
            "one row, left to right, each in strict side view facing RIGHT, evenly spaced with wide flat magenta gaps "
            "so no figure touches or overlaps another, all the same size, all standing on the same invisible ground "
            "line, every head and boot fully inside the frame. Frame 1: contact pose, right leg forward heel down, left "
            "leg back, arms swinging opposite. Frame 2: passing pose, legs close together, body slightly higher, arms "
            "at the sides. Frame 3: contact pose mirrored, left leg forward heel down, right leg back. Frame 4: "
            "passing pose again with the other leg lifted. Clear distinct poses, natural stride. No floor, no shadow, "
            "no labels. " + STYLE + " " + KEY)


ITEMS = {
    # room back walls
    "wall_bridge": room("riveted dark blue-steel plates, a wide armored viewport slit across the upper half framed in "
                        "thick brass, showing only black rock strata outside with faint green seismograph glow on the "
                        "glass, pinned blueprint sheets and strip-chart paper (no readable text), a big round brass depth "
                        "dial, rows of small dim indicator lamps, vertical conduits at both sides. Cold blue and CRT green "
                        "accents."),
    "wall_bracing": room("heavy riveted steel with massive hazard-striped structural ribs and diagonal I-beam braces, thick "
                         "loops of hydraulic hoses and fat pipes along the wall, a hazard-striped pressure warning panel "
                         "with two brass gauges, big bolted gusset plates. Yellow and black hazard accents on dark steel."),
    "wall_weapons": room("olive-drab and dark steel armored plates, stenciled red warning panels (no readable text), a "
                         "chain hoist rail with a hanging chain across the top, empty heavy mounting brackets and shelves, "
                         "a hazard-striped blast shutter panel, thick cable trays. Olive green and warning red accents."),
    "wall_drill": room("massive riveted steel with huge exposed gear wheels and a heavy roller chain drive set into the "
                       "wall, thick I-beam columns with yellow and black hazard stripes, oil stains and grease streaks, "
                       "vibration damper springs, caged amber work lamps. Warm amber and oily black accents."),
    "wall_coolant": room("teal-tinted riveted steel plates, dense runs of pipes of many diameters with flanges, valve wheels "
                         "and elbows, wet streaks, frost patches and condensation drips, round brass pressure gauges. "
                         "Cold teal and blue-white accents on dark steel."),
    # room props
    "prop_helm": prop("1:1", "A ship's helm and seismic scanner console: a sloped control desk on a steel base, a pilot's "
                      "yoke wheel, two round CRT monitors with BRIGHT GLOWING GREEN PHOSPHOR screens showing a seismic "
                      "waveform and a depth profile, banks of chunky toggle switches and push buttons, brass gauges, and "
                      "on top a boxy military radio set with dials and a coiled cord handset."),
    "prop_jack": prop("2:3", "A tall hydraulic bracing jack frame: a heavy steel A-frame with a thick chrome piston rod and "
                      "a big cylinder, brass collars, bolted foot plates top and bottom, hydraulic hoses, hazard-striped "
                      "base, standing about twice as tall as wide."),
    "prop_manifold": prop("1:1", "A hydraulic pressure manifold cabinet: a squat steel block with a row of brass valve "
                          "wheels, three enamel pressure gauges with cream faces, several flanged pipes entering from the "
                          "top and sides, a hazard stripe plate, a small red lever."),
    "prop_breech": prop("3:2", "A borer turret breech: a heavy cylindrical gun breech block with a big round breech door with "
                        "locking lugs and a hand wheel, mounted on a steel cradle with recoil springs and a short "
                        "barrel stub pointing RIGHT, a mining charge launcher tube on top, a shell hoist rail, a small "
                        "amber warning lamp."),
    "prop_ammo": prop("2:3", "A steel ammunition rack: an open framework of angle iron holding rows of fat steel and brass "
                      "mining charges and shells lying on their sides in stacked shelves, a hazard-striped frame, a "
                      "hanging tag, worn paint."),
    "prop_drillmotor": prop("2:3", "The drill motor and gearbox housing: on the upper part a huge electric motor drum with "
                            "cooling fins and a junction box, coupled to a big gearbox casing with an inspection plate "
                            "and bolts, mounted on a heavy bedplate, and a thick splined vertical drive shaft running "
                            "straight DOWN from the bottom of the gearbox all the way to the bottom edge of the image, "
                            "ending cut off at the frame edge."),
    "prop_bitrack": prop("1:1", "A steel rack of spare drill bits: three heavy tungsten-carbide tricone rock drill bits "
                         "with scarred teeth standing in a welded frame with hazard stripes, oily and worn."),
    "prop_tank": prop("2:3", "A tall cylindrical coolant tank with domed ends on steel legs, riveted bands, a vertical sight "
                      "glass tube with GLOWING CYAN-BLUE liquid inside, a valve wheel and a flanged pipe at the bottom, "
                      "a pressure gauge on top, frost and condensation."),
    "prop_pump": prop("3:2", "A coolant pump set: a large electric pump motor with cooling fins coupled to a round pump "
                      "casing, thick flanged pipes with two valve wheels going up and sideways, a small gauge, bolted "
                      "to a steel skid."),
    # fittings
    "fit_door_closed": prop("9:16", "A heavy steel bulkhead door, closed, tall and narrow (about one metre wide and two "
                            "metres tall) in a thick hazard-striped frame, riveted plate, a central wheel handle, a "
                            "small slit window, grime."),
    "fit_door_open": prop("9:16", "ONLY the hazard-striped steel DOOR FRAME of the attached reference door (same frame, same "
                          "style, same size), with NO door leaf: the door has slid away completely, so the whole tall "
                          "rectangular doorway opening between the frame posts is EMPTY and filled with flat solid "
                          "magenta #ff00ff, exactly the same magenta as the background. Only a narrow strip of the "
                          "door's edge shows inside the right post. The frame is the only object."),
    "fit_ladder": ("9:16", "A vertical steel ladder seen straight on: two flat side rails and perfectly evenly spaced round "
                   "rungs every quarter metre, worn paint, a few bolts, extending past the top and the bottom edge of the "
                   "frame (cropped there), about half a metre wide, centred. " + STYLE + " " + KEY),
    "fit_hatch": prop("21:9", "A floor hatch rim in side elevation: a short horizontal steel coaming about 0.8 metre wide "
                      "and 0.2 metre tall, hazard-striped yellow and black, with two stout end posts and a hinge bracket, "
                      "bolts, scuffs."),
    "fit_grating": tex("21:9", "Seamless flat texture of a steel catwalk floor deck seen straight on from the side: the whole "
                       "frame is heavy perforated steel grating plate with evenly spaced oval holes (dark behind them), a "
                       "worn bright top edge, light rust. ONLY the plate: no stripe, no gauges, no objects."),
    "fit_hull": tex("21:9", "Seamless flat texture of a ship's outer hull armour seen straight on: overlapping bolted steel "
                    "plates with big rivets, weld seams, rock dust, rust streaks and scorch marks, dark cold blue-grey "
                    "with a worn lighter edge. ONLY the plating."),
    "fit_crown": ("21:9", "The drill crown of a giant boring machine seen from the side in flat elevation, very wide and low "
                  "(about five times wider than tall): a broad shallow cutting head made of a massive steel disc body "
                  "with a heavy collar on top where the tower attaches, a row of large tungsten-carbide cutter teeth and "
                  "cone cutters all along the bottom edge, the teeth glowing HOT ORANGE-RED at their tips, scorched "
                  "metal, rock dust. Centred, with plenty of magenta above and below. " + STYLE + " " + KEY),
    # rock tiles (square, fill the frame; seamless is made in post)
    "rock_soft": rocktex("Broad-shape flat texture of soft crumbly sedimentary rock seen straight on: warm brown-grey "
                     "sandstone and shale with faint wavy horizontal bedding and a few crumbled pits. Large simple shapes, "
                     "low contrast."),
    "rock_rock": rocktex("Broad-shape flat texture of ordinary grey granite-like rock seen straight on: cool grey with "
                     "chipped blocky facets and hairline cracks. Large simple shapes, medium contrast."),
    "rock_dense": rocktex("Broad-shape flat texture of dense dark blue-grey basalt seen straight on: tight heavy grain, "
                      "a few large smooth cleaved faces and sparse cracks. Large simple shapes."),
    "rock_hard": rocktex("Broad-shape flat texture of very hard dark glassy rock seen straight on: near-black volcanic glass "
                     "with conchoidal fracture facets and faint cold blue sheen on the edges. Large simple shapes."),
    "rock_iron": rocktex("Broad-shape flat texture of grey rock cut by thick veins of iron ore seen straight on: rust-orange "
                     "and brown bands plus metallic steel-blue glints in the veins. Large simple shapes."),
    "rock_gem": rocktex("Broad-shape flat texture of dark grey rock with a pocket of clustered GLOWING GREEN emerald "
                    "crystals growing out of it, bright green crystal points in the middle, rock all around. Large "
                    "simple shapes."),
    "rock_water": rocktex("Broad-shape flat texture of very dark wet black rock with glossy puddle-like dark pools and "
                      "thin streaks of seeping water, cold blue-black. Large simple shapes, low contrast."),
    "rock_shaft": rocktex("Broad-shape flat texture of the dark back wall of a freshly bored shaft: smooth curved "
                      "cut marks from a drill, very dark cold grey-brown rock, low contrast, calm."),
}
for _w in CREW:
    ITEMS["crew_%s_full" % _w] = crew_full(_w)
    ITEMS["crew_%s_parts" % _w] = crew_parts(_w)
    ITEMS["crew_%s_walk" % _w] = crew_walk(_w)


def gen_one(item, v, key, ref=None, model="gemini-3-pro-image"):
    aspect, prompt = ITEMS[item]
    parts = [{"text": prompt}]
    if ref:
        parts.append({"inlineData": {"mimeType": "image/png",
                                     "data": base64.b64encode(open(ref, "rb").read()).decode()}})
    body = {"contents": [{"parts": parts}],
            "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect, "imageSize": "2K"}}}
    err = None
    for attempt in range(3):          # first try plus at most two retries
        r, err = pg.http_post(f"{pg.BASE}/models/{model}:generateContent", body, key)
        if r is not None:
            b64 = pg.find_image(r)
            if b64:
                from PIL import Image
                im = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA")
                p = os.path.join(OUT, f"{item}_v{v}.png")
                im.save(p)
                with LOCK:
                    common.save_manifest("artpass_" + item, {
                        "service": "Gemini", "model": model, "aspect": aspect, "size": "2K", "variant": v,
                        "prompt": prompt, "reference": os.path.relpath(ref, common.ROOT) if ref else None,
                        "seed": "none (the API gives no seed)", "usd_estimate": EST,
                        "output": os.path.relpath(p, common.ROOT), "attempts": attempt + 1})
                    common.log_spend("Gemini " + model, f"artpass {item} v{v}", EST)
                return item, v, p, None
            err = "no image: " + str(r)[:200]
        if err and "429" in str(err):
            import time
            time.sleep(30)        # spend-based rate limit: back off before the (at most two) retries
    return item, v, None, err


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("items")
    ap.add_argument("--variants", type=int, default=1)
    ap.add_argument("--start", type=int, default=1)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--ref", default=None)
    ap.add_argument("--delay", type=float, default=0.0)
    a = ap.parse_args()
    key = common.get_key("GEMINI_API_KEY", "GOOGLE_API_KEY")
    if not key:
        sys.exit("artpass_gen: no Gemini key")
    os.makedirs(OUT, exist_ok=True)
    jobs = [(i, v) for i in a.items.split(",") for v in range(a.start, a.start + a.variants)]
    if a.delay:   # sequential with a pause (the API has a spend-based rate limit)
        import time
        for i, v in jobs:
            item, v, p, err = gen_one(i, v, key, a.ref)
            print(item, v, "ok" if p else "FAILED " + str(err)[:160], flush=True)
            time.sleep(a.delay)
        return
    with ThreadPoolExecutor(a.workers) as ex:
        futs = [ex.submit(gen_one, i, v, key, a.ref) for i, v in jobs]
        for f in futs:
            item, v, p, err = f.result()
            print(item, v, "ok" if p else "FAILED " + str(err))


if __name__ == "__main__":
    main()
