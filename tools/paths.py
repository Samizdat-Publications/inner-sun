"""Locate the repo folders and the external tools (Godot 4.7, ffmpeg) without relying on PATH."""
import glob
import os
import shutil

LOCAL = os.environ.get("LOCALAPPDATA", "")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GAME = os.path.join(ROOT, "game")
OUT = os.path.join(ROOT, "harness", "out")
REVIEW = os.path.join(ROOT, "review")


def _first(cands):
    for c in cands:
        if c and os.path.exists(c):
            return c
    return None


_VERSION = {}


def _check_version(exe):
    if exe in _VERSION:
        return
    _VERSION[exe] = ""
    try:
        import proc  # lazy: proc imports this module
        v = proc.run_godot(["--version"], 30, exe=exe).out.strip()
    except Exception as e:
        v = f"unknown ({e})"
    _VERSION[exe] = v
    if not v.startswith("4.7.2.stable"):
        import sys
        print(f"WARNING: expected Godot 4.7.2.stable, found {v!r} at {exe}", file=sys.stderr, flush=True)


def godot(console=True, check=True):
    """Path of the Godot 4.7 executable (console build by default, so stdout is captured).

    The first call per process runs --version and warns loudly if it is not 4.7.2.stable."""
    name = "godot_console" if console else "godot"
    found = shutil.which(name)
    links = os.path.join(LOCAL, "Microsoft", "WinGet", "Links", name + ".exe")
    pk = glob.glob(os.path.join(LOCAL, "Microsoft", "WinGet", "Packages", "GodotEngine.GodotEngine*",
                                "Godot_v4.7*_win64" + ("_console" if console else "") + ".exe"))
    p = _first([found, links] + sorted(pk, reverse=True))
    if not p:
        raise FileNotFoundError("Godot 4.7 not found (winget install GodotEngine.GodotEngine)")
    if check:
        _check_version(p)
    return p


def ffmpeg(tool="ffmpeg"):
    found = shutil.which(tool)
    links = os.path.join(LOCAL, "Microsoft", "WinGet", "Links", tool + ".exe")
    p = _first([found, links])
    if not p:
        raise FileNotFoundError(f"{tool} not found (winget install Gyan.FFmpeg)")
    return p
