"""Same scenario and seed twice: headless, then windowed off-screen under Movie Maker. The hashes must match.

    python tools/determinism.py [--scenario fire_drill] [--seed 7] [--ticks 1200]

The game prints `FINAL tick=<t> hash=<h>` in both modes and quits. Exit 1 if they differ.
"""
import argparse
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

FINAL = re.compile(r"FINAL tick=(\d+) hash=(\S+)")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", default="fire_drill")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--ticks", type=int, default=1200)
    ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args(argv)
    try:
        proc.require_game()
        if not a.no_import:
            proc.import_project(900)
        game = ["--scenario=" + a.scenario, f"--seed={a.seed}", f"--run-ticks={a.ticks}"]
        r1 = proc.run_godot(["--headless", "--path", paths.GAME, "--"] + game, 900, log_name="determinism_headless")
        tmp = os.path.join(paths.OUT, "determinism")
        os.makedirs(tmp, exist_ok=True)
        avi = os.path.join(tmp, "m.avi")
        r2 = proc.run_godot(["--path", paths.GAME, "--resolution", "1280x720", "--position", "-32000,-32000",
                             "--write-movie", avi, "--fixed-fps", "30", "--disable-vsync", "--"] + game, 1800,
                            log_name="determinism_movie")
    except proc.ToolError as e:
        print("determinism: FAIL (" + str(e) + ")")
        return 1
    finally:
        shutil.rmtree(os.path.join(paths.OUT, "determinism"), ignore_errors=True)
    res = []
    for name, r in (("headless", r1), ("movie", r2)):
        m = FINAL.search(r.out)
        res.append(m.groups() if m else None)
        print(f"  {name}: exit {r.returncode}, {r.seconds:.0f}s, " + (f"tick={m.group(1)} hash={m.group(2)}" if m else
              "no FINAL line " + str(proc.bad_lines(r.out, 3))))
    if None in res:
        print("determinism: FAIL (missing FINAL line)")
        return 1
    if res[0] != res[1]:
        print(f"determinism: FAIL (headless {res[0]} != movie {res[1]})")
        return 1
    print(f"determinism: ok (hash {res[0][1]} at tick {res[0][0]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
