"""Render the UI gallery (every HUD panel and overlay in the states that matter) to PNG files.

    python tools/gallery.py [--out DIR] [--res 1920x1080] [--gpu-index N] [--timeout 300]

Saves one PNG per state (hud_calm, hud_crisis, hud_drill, dossier_page, dossier_known,
dossier_greyed, store) to harness/out/gallery/ by default. Godot needs a real window to render, so
the window is parked off-screen and unfocusable (see tools/proc.py), the run quits by itself, and the
whole process tree is killed by job object if it overruns the timeout. Run it only when the UI
changed: it shows a window for about a second.
"""
import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

STATES = ["hud_calm", "hud_crisis", "hud_drill", "dossier_page", "dossier_known", "dossier_greyed", "store"]


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(paths.OUT, "gallery"))
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
        args = ["--path", paths.GAME, "res://view/ui_gallery.tscn", "--resolution", a.res,
                "--position", "-32000,-32000"]
        if a.gpu_index is not None:
            args += ["--gpu-index", str(a.gpu_index)]
        args += ["--", f"--gallery={out_dir}"]
        r = proc.run_godot(args, a.timeout, log_name="gallery")
    except proc.ToolError as e:
        print("gallery: FAIL (" + str(e) + ")")
        return 1
    for l in proc.bad_lines(r.out):
        print(l)
    for l in r.out.splitlines():
        if l.startswith("GALLERY"):
            print(l.strip())
    missing = [n for n in STATES if not os.path.exists(os.path.join(out_dir, n + ".png"))]
    proc.gpu_warning(proc.adapter_from(r.out))
    if r.timed_out:
        print(f"gallery: FAIL (timed out after {a.timeout}s, process tree killed)")
        return 1
    if missing:
        print("gallery: FAIL (missing " + ",".join(missing) + f", exit {r.returncode})")
        return 1
    print(f"gallery: ok ({len(STATES)} files in {out_dir}, exit {r.returncode}, {r.seconds:.0f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
