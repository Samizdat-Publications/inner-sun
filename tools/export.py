r"""Export the Windows build and prove it runs.

    python tools/export.py

Under the editor lock: `--export-release "Windows Desktop" <root>\builds\InnerSun.exe`; then the exported
exe is run off-screen through GodotJob and its output (or log file) must contain `FINAL tick=1200 hash=...`.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

BUILDS = os.path.join(paths.ROOT, "builds")
EXE = os.path.join(BUILDS, "InnerSun.exe")


def main(argv=None):
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
