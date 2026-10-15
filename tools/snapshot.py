r"""Freeze the current game into a .pck so balance runs can use a stable build while the lead keeps editing.

    python tools/snapshot.py

Under the editor lock: `--export-pack "Windows Desktop" <root>\harness\out\snap\<stamp>-<git hash>.pck`.
Only the last 3 snapshots are kept. Use the printed path with `tools/balance.py --pack`.
"""
import datetime as dt
import glob
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

SNAP = os.path.join(paths.OUT, "snap")


def git_hash():
    try:
        return subprocess.check_output(["git", "-C", paths.ROOT, "rev-parse", "--short", "HEAD"], text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "nogit"


def main(argv=None):
    try:
        proc.require_game()
        os.makedirs(SNAP, exist_ok=True)
        pck = os.path.join(SNAP, f"{dt.datetime.now():%Y%m%d-%H%M%S}-{git_hash()}.pck")
        with proc.editor_lock():
            r = proc.run_godot(["--headless", "--path", paths.GAME, "--export-pack", "Windows Desktop", pck], 1200,
                               log_name="snapshot")
    except proc.ToolError as e:
        print("snapshot: FAIL (" + str(e) + ")")
        return 1
    for l in proc.bad_lines(r.out):
        print(l)
    if r.returncode != 0 or not os.path.exists(pck):
        print(f"snapshot: FAIL (exit {r.returncode}, pck exists={os.path.exists(pck)}, timed_out={r.timed_out})")
        return 1
    for old in sorted(glob.glob(os.path.join(SNAP, "*.pck")))[:-3]:
        os.remove(old)
    print(pck)
    print(f"snapshot: ok ({os.path.getsize(pck) / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
