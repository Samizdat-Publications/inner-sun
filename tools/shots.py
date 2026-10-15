"""Render the named scenario moments to PNG (default harness/out/shots).

    python tools/shots.py [--scenario fire_drill] [--seed 1] [--names start,fire,...] [--out DIR]
                          [--res 1920x1080] [--gpu-index N] [--timeout 300]

Godot needs a real window to render, so the window is parked off-screen (-32000,-32000), the run
quits by itself, and the whole process tree is killed by job object if it overruns the timeout.
"""
import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

DEFAULT_NAMES = "start,fire,flood,arrive,fire_out,end"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", default="fire_drill")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--names", default=DEFAULT_NAMES)
    ap.add_argument("--out", default=os.path.join(paths.OUT, "shots"))
    ap.add_argument("--res", default="1920x1080")
    ap.add_argument("--gpu-index", default=None)
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args(argv)
    names = [n for n in a.names.split(",") if n]
    out_dir = os.path.abspath(a.out)
    try:
        proc.require_game()
        os.makedirs(out_dir, exist_ok=True)
        for f in glob.glob(os.path.join(out_dir, "*.png")):
            os.remove(f)
        if not a.no_import:
            proc.import_project(900)
        args = ["--path", paths.GAME, "--resolution", a.res, "--position", "-32000,-32000"]
        if a.gpu_index is not None:
            args += ["--gpu-index", str(a.gpu_index)]
        args += ["--", f"--scenario={a.scenario}", f"--seed={a.seed}", f"--shots={','.join(names)}", f"--out={out_dir}"]
        r = proc.run_godot(args, a.timeout, log_name="shots")
    except proc.ToolError as e:
        print("shots: FAIL (" + str(e) + ")")
        return 1
    for l in proc.bad_lines(r.out):
        print(l)
    for l in r.out.splitlines():
        if l.startswith("SHOT"):
            print(l.strip())
    missing = [n for n in names if not os.path.exists(os.path.join(out_dir, n + ".png"))]
    adapter = proc.adapter_from(r.out)
    proc.gpu_warning(adapter)
    if r.timed_out:
        print(f"shots: FAIL (timed out after {a.timeout}s, process tree killed)")
        return 1
    if missing:
        print("shots: FAIL (missing " + ",".join(missing) + f", exit {r.returncode})")
        return 1
    print(f"shots: ok ({len(names)} files in {out_dir}, exit {r.returncode}, {r.seconds:.0f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
