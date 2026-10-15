"""Render the art style bake-off scene and compose the comparison sheet.

    python tools/bakeoff.py [--out harness/out/bakeoff] [--glow game|off|k=v,...] [--boost 2.4]
                            [--only 01_lamp,...] [--res 1920x1080] [--gpu-index N] [--timeout 300]

Frames land in --out (1920x1080): 01_lamp 02_alarm 03_sweep_a/b/c 04_zoom06 05a/b/c_close_<style>
06_noglow_lamp 06_noglow_alarm. Then 05_closeup.png (three crops side by side), compare.jpg (labeled grid of
01, 02, 03_b and 05) and a numeric glow check (difference between the lamp frame with and without glow).
Godot needs a real window to render, so the window is parked off-screen and the whole process tree runs in a
job object (tools/proc.py), exactly like tools/shots.py.
"""
import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

SCENE = "res://view/bakeoff/bakeoff.tscn"
FRAMES = ["01_lamp", "02_alarm", "03_sweep_a", "03_sweep_b", "03_sweep_c", "04_zoom06",
          "05a_close_pixel", "05b_close_painted", "05c_close_blender", "06_noglow_lamp", "06_noglow_alarm"]
STYLES = ["PIXEL", "PAINTED", "BLENDER"]


def _font(size):
    from PIL import ImageFont
    for p in (r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf", r"C:\Windows\Fonts\segoeuib.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def compose(out_dir):
    """Labeled comparison sheet of every style that has assets (a style with none is left out and cropped away)."""
    from PIL import Image, ImageDraw
    p = lambda n: os.path.join(out_dir, n + ".png")  # noqa: E731
    have_pixel = os.path.exists(os.path.join(paths.GAME, "assets", "bakeoff", "pixel", "room_wall_albedo.png"))
    names = [("05a_close_pixel", "PIXEL")] * have_pixel + [("05b_close_painted", "PAINTED"), ("05c_close_blender", "BLENDER")]
    crops = []
    for n, _ in names:
        if os.path.exists(p(n)):
            im = Image.open(p(n)).convert("RGB")
            w, h = im.size
            crops.append(im.crop((w // 2 - w // 6, 0, w // 2 + w // 6, h)))
    if len(crops) == len(names):
        sheet = Image.new("RGB", (crops[0].width * len(crops), crops[0].height))
        for i, c in enumerate(crops):
            sheet.paste(c, (i * crops[0].width, 0))
        sheet.save(p("05_closeup"))
    label = " | ".join(t for _, t in names)
    cells = [("01  lamp only", "01_lamp"), ("02  alarm + fire, lamp 0.4", "02_alarm"),
             ("03  sweep light, position b", "03_sweep_b"), (f"05  closeup 2.6x: {label}", "05_closeup")]
    W, H = 960, 540
    grid = Image.new("RGB", (W * 2, H * 2), (10, 10, 10))
    f = _font(26)
    for i, (title, n) in enumerate(cells):
        if not os.path.exists(p(n)):
            continue
        im = Image.open(p(n)).convert("RGB")
        if n != "05_closeup" and not have_pixel:
            im = im.crop((680, 270, 1880, 810))   # the two populated rooms, 20:9
            im = im.resize((W, int(W * im.height / im.width)), Image.LANCZOS)
            im = im.crop((0, 0, W, H)) if im.height >= H else im
        else:
            im = im.resize((W, H), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, W, 38), fill=(0, 0, 0))
        d.text((10, 4), title, fill=(255, 220, 160), font=f)
        grid.paste(im, ((i % 2) * W, (i // 2) * H))
    grid.save(os.path.join(out_dir, "compare.jpg"), quality=90)
    print("compare.jpg written" + ("" if have_pixel else " (PIXEL omitted: no assets)"))


def glow_check(out_dir):
    import numpy as np
    from PIL import Image
    for state, a, b in (("lamp", "01_lamp", "06_noglow_lamp"), ("alarm", "02_alarm", "06_noglow_alarm")):
        if not (os.path.exists(os.path.join(out_dir, a + ".png")) and os.path.exists(os.path.join(out_dir, b + ".png"))):
            continue
        ga = np.asarray(Image.open(os.path.join(out_dir, a + ".png")).convert("RGB"), np.float32)
        gb = np.asarray(Image.open(os.path.join(out_dir, b + ".png")).convert("RGB"), np.float32)
        d = (ga - gb).clip(0, None).sum(axis=2)
        print(f"GLOW check ({state}): whole frame mean added brightness {d.mean():.2f}/765, "
              f"pixels brightened by >24: {(d > 24).sum()}, max {d.max():.0f}")
        # rooms: world x of room i = i*400, camera at world x 560, zoom 1.6, screen centre 960
        for i, name in enumerate(STYLES):
            x0 = int((i * 400 - 560) * 1.6 + 960)
            x1 = int(x0 + 320 * 1.6)
            y0 = int((0 - 110) * 1.6 + 540)
            y1 = int(y0 + 240 * 1.6)
            r = d[max(y0, 0):y1, max(x0, 0):x1]
            print(f"   {name:8s} room: mean added {r.mean():6.2f}, px>24 {(r > 24).sum():6d}, max {r.max():5.0f}")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(paths.OUT, "bakeoff"))
    ap.add_argument("--glow", default="game")
    ap.add_argument("--boost", default="1.0")
    ap.add_argument("--only", default="")
    ap.add_argument("--res", default="1920x1080")
    ap.add_argument("--gpu-index", default=None)
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args(argv)
    out_dir = os.path.abspath(a.out)
    try:
        proc.require_game()
        os.makedirs(out_dir, exist_ok=True)
        for f in glob.glob(os.path.join(out_dir, "*.png")):
            os.remove(f)
        if not a.no_import:
            proc.import_project(900)
        args = ["--path", paths.GAME, SCENE, "--resolution", a.res, "--position", "-32000,-32000"]
        if a.gpu_index is not None:
            args += ["--gpu-index", str(a.gpu_index)]
        args += ["--", "--bakeoff", f"--out={out_dir}", f"--glow={a.glow}", f"--boost={a.boost}"]
        if a.only:
            args.append(f"--only={a.only}")
        r = proc.run_godot(args, a.timeout, log_name="bakeoff")
    except proc.ToolError as e:
        print("bakeoff: FAIL (" + str(e) + ")")
        return 1
    for l in proc.bad_lines(r.out):
        print(l)
    for l in r.out.splitlines():
        if l.startswith(("SHOT", "BAKEOFF")):
            print(l.strip())
    want = [n for n in FRAMES if not a.only or n in a.only.split(",")]
    missing = [n for n in want if not os.path.exists(os.path.join(out_dir, n + ".png"))]
    proc.gpu_warning(proc.adapter_from(r.out) or next((l.split("renderer", 1)[1].strip() for l in r.out.splitlines()
                                                      if l.startswith("BAKEOFF done")), ""))
    if r.timed_out:
        print(f"bakeoff: FAIL (timed out after {a.timeout}s, process tree killed)")
        return 1
    if missing:
        print("bakeoff: FAIL (missing " + ",".join(missing) + f", exit {r.returncode})")
        return 1
    compose(out_dir)
    glow_check(out_dir)
    print(f"bakeoff: ok ({len(want)} frames in {out_dir}, exit {r.returncode}, {r.seconds:.0f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
