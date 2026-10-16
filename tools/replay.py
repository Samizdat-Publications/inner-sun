"""Replay a saved run (a record from the game's runs folder) and check it rebuilds exactly.

    python tools/replay.py <record.json>          headless: prints REPLAY ... match|MISMATCH
    python tools/replay.py --latest [--dir <profile dir>]
    python tools/replay.py <record.json> --watch  opens the game window and plays the run back

Records live in <profile dir>/runs/: the playtest build uses %APPDATA%\\InnerSun\\runs\\ (Godot's custom
user folder). A MISMATCH means a determinism bug: the record and the game no longer agree.
"""
import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

DEFAULT_DIR = os.path.join(os.environ.get("APPDATA", ""), "InnerSun")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("record", nargs="?", default="")
    ap.add_argument("--latest", action="store_true", help="the newest record in --dir")
    ap.add_argument("--dir", default=DEFAULT_DIR, help="profile folder (default: the game's user folder)")
    ap.add_argument("--watch", action="store_true", help="play it back in a game window")
    ap.add_argument("--timeout", type=int, default=1800)
    a = ap.parse_args(argv)
    path = a.record
    if a.latest:
        recs = sorted(glob.glob(os.path.join(a.dir, "runs", "*.json")), key=os.path.getmtime)
        if not recs:
            print(f"replay: no records in {os.path.join(a.dir, 'runs')}")
            return 1
        path = recs[-1]
    if not path or not os.path.exists(path):
        print(f"replay: record not found: {path!r}")
        return 1
    path = os.path.abspath(path)
    print(f"replay: {path}")
    if a.watch:
        r = proc.run_godot(["--path", paths.GAME, "--", f"--replay={path}"], a.timeout, log_name="replay_watch")
        print(f"replay: window closed (exit {r.returncode})")
        return 0
    r = proc.run_godot(["--headless", "--path", paths.GAME, "--script", "res://tools/replay_run.gd", "--",
                        f"--record={path}"], a.timeout, log_name="replay")
    line = next((l for l in r.out.splitlines() if l.startswith("REPLAY")), "")
    print(line or "replay: no REPLAY line (see harness/out/logs/replay.log)")
    for l in proc.bad_lines(r.out):
        print(l)
    return 0 if " match " in line else 1


if __name__ == "__main__":
    sys.exit(main())
