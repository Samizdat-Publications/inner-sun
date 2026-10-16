"""Open a normal, focusable game window for hands-on testing with real keyboard and mouse.

    python tools/play.py [--exe] [--minutes 30] [-- <game args>]

The window is not parked off-screen (that is the point), so it takes over the screen: use it only when
someone (Claude driving the mouse, or Stewart) is actually playing. The run sits in a job object like
every other tool launch, so nothing outlives this script. A separate profile folder
(harness/out/play_profile) keeps test runs out of Stewart's own profile and run history.

    --exe        play the exported build (builds/InnerSun.exe) instead of the project in the editor binary
    game args    e.g. --seed=7, --scenario=fire_drill, --scenario=drill_segment --fight=rival_light
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

PROFILE = os.path.join(paths.ROOT, "harness", "out", "play_profile")


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    game_args = []
    if "--" in argv:
        i = argv.index("--")
        argv, game_args = argv[:i], argv[i + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", action="store_true", help="the exported build in builds/")
    ap.add_argument("--minutes", type=float, default=30.0, help="close the window after this long")
    a = ap.parse_args(argv)
    os.makedirs(PROFILE, exist_ok=True)
    if not any(g.startswith("--profile-dir") for g in game_args):
        game_args.append(f"--profile-dir={PROFILE}")
    if a.exe:
        exe = os.path.join(paths.ROOT, "builds", "InnerSun.exe")
        if not os.path.exists(exe):
            print(f"play: no exported build at {exe} (run python tools/export.py)")
            return 1
        args = ["--"] + game_args
    else:
        exe = None
        args = ["--path", paths.GAME, "--"] + game_args
    print(f"play: {'exported build' if a.exe else 'project'} {' '.join(game_args)}")
    r = proc.run_godot(args, int(a.minutes * 60), log_name="play", exe=exe)
    print(f"play: window closed (exit {r.returncode}{', timed out' if r.timed_out else ''})")
    for line in proc.bad_lines(r.out):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
