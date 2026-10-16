r"""Export the Windows build and prove it runs.

    python tools/export.py
    python tools/export.py --playtest [--label m1a-playtest]   also: a whole bot-driven run in the exported
        game must finish; then builds\PLAYTEST is written (Play Inner Sun.bat launches the build) and a zip
        of the build goes to builds\milestones\<label>\ for the making-of record.

Under the editor lock: `--export-release "Windows Desktop" <root>\builds\InnerSun.exe`; then the exported
exe is run off-screen through GodotJob and its output (or log file) must contain `FINAL tick=1200 hash=...`.
"""
import datetime as dt
import os
import re
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

BUILDS = os.path.join(paths.ROOT, "builds")
EXE = os.path.join(BUILDS, "InnerSun.exe")


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    cli = list(args)  # the run below reuses `args` for the game's own arguments
    if "-h" in args or "--help" in args:
        print(__doc__)
        return 0
    try:
        proc.require_game()
        os.makedirs(BUILDS, exist_ok=True)
        with proc.editor_lock():
            r = proc.run_godot(["--headless", "--path", paths.GAME, "--export-release", "Windows Desktop", EXE], 1200,
                               log_name="export")
    except proc.ToolError as e:
        print("export: FAIL (" + str(e) + ")")
        return 1
    for l in proc.bad_lines(r.out):
        print(l)
    if r.returncode != 0 or not os.path.exists(EXE):
        print(f"export: FAIL (exit {r.returncode}, exe exists={os.path.exists(EXE)}, timed_out={r.timed_out})")
        return 1
    size = os.path.getsize(EXE)
    console = os.path.join(BUILDS, "InnerSun.console.exe")
    exe = console if os.path.exists(console) else EXE
    log = os.path.join(paths.OUT, "logs", "export_run.log")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    if os.path.exists(log):
        os.remove(log)
    args = ["--position", "-32000,-32000", "--log-file", log, "--", "--scenario=fire_drill", "--seed=7",
            "--run-ticks=1200"]
    r2 = proc.run_godot(args, 300, exe=exe)
    text = r2.out + (open(log, encoding="utf-8", errors="replace").read() if os.path.exists(log) else "")
    m = re.search(r"FINAL tick=1200 hash=(\S+)", text)
    print(f"  exe {EXE} size {size / 1e6:.1f} MB (+ pck {'embedded' if not os.path.exists(os.path.join(BUILDS, 'InnerSun.pck')) else 'separate'})")
    print(f"  ran {os.path.basename(exe)}: exit {r2.returncode}, {r2.seconds:.0f}s, timed_out={r2.timed_out}")
    if not m:
        print("export: FAIL (no `FINAL tick=1200 hash=` line from the exported build) " + str(proc.bad_lines(text, 3)))
        return 1
    print(f"export: ok (hash {m.group(1)}, {size / 1e6:.1f} MB)")
    if "--playtest" in cli:
        label = cli[cli.index("--label") + 1] if "--label" in cli else "playtest"
        return playtest(exe, label)
    return 0


def _git(*cmd):
    try:
        return subprocess.check_output(["git", "-C", paths.ROOT] + list(cmd), text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "nogit"


def playtest(exe, label):
    """A whole run, bot-driven, inside the exported game; then the PLAYTEST marker and a milestone zip."""
    prof = os.path.join(paths.OUT, "profile_export")
    shutil.rmtree(prof, ignore_errors=True)
    log = os.path.join(paths.OUT, "logs", "export_playtest.log")
    if os.path.exists(log):
        os.remove(log)
    args = ["--headless", "--log-file", log, "--", "--mode=run", "--bot=balanced", "--seed=11",
            "--run-ticks=36000", f"--profile-dir={prof}"]
    r = proc.run_godot(args, 900, exe=exe)
    text = r.out + (open(log, encoding="utf-8", errors="replace").read() if os.path.exists(log) else "")
    m = re.search(r"FINAL tick=(\d+) hash=(\S+)", text)
    bad = proc.bad_lines(text, 5)
    print(f"  playtest run in the exported game: exit {r.returncode}, {r.seconds:.0f}s, {m.group(0) if m else 'no FINAL line'}")
    if not m or bad:
        print("export: PLAYTEST FAIL " + str(bad))
        return 1
    stamp = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    commit = _git("rev-parse", "--short", "HEAD")
    with open(os.path.join(BUILDS, "PLAYTEST"), "w", encoding="utf-8", newline="\n") as f:
        f.write(f"Inner Sun playtest build {label}\nbuilt {stamp} from commit {commit}\n")
    out_dir = os.path.join(BUILDS, "milestones", label)
    os.makedirs(out_dir, exist_ok=True)
    zpath = os.path.join(out_dir, f"InnerSun_{label}_{commit}.zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for name in os.listdir(BUILDS):
            full = os.path.join(BUILDS, name)
            if os.path.isfile(full) and (name.startswith("InnerSun") or name == "PLAYTEST"):
                z.write(full, name)
    print(f"export: playtest ok (builds/PLAYTEST written; milestone zip {zpath}, {os.path.getsize(zpath) / 1e6:.0f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
