"""Checks for running two Godot projects side by side on one PC.

    python tools/coexist.py [--only a|b|c]

(a) import ports: two concurrent imports with and without --lsp-port/--dap-port
(b) focus: does an off-screen windowed Godot ever take the foreground window?
(c) contention: perf.measure must notice another Godot rendering, and shots.py must still work.
Prints PASS/FAIL (or SKIP when the game side does not exist yet); exit 1 if any FAIL.
"""
import argparse
import ctypes
import os
import re
import subprocess
import sys
import threading
import time
from ctypes import wintypes

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths  # noqa: E402
import proc  # noqa: E402

PROBE_ROOT = os.path.join(paths.OUT, "coexist")
PROBE = os.path.join(PROBE_ROOT, "probe")
PORT_RE = re.compile(r"\b(port|bind|listen\w*)\b|address already in use|already in use", re.I)
NOISE = ("still in use", "Pages in use", "resources still in use")

PROJECT_GODOT = '''config_version=5

[application]

config/name="%s"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7")
config/use_custom_user_dir=true
config/custom_user_dir_name="%s"

[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/size/no_focus=true

[rendering]

renderer/rendering_method="forward_plus"
'''

MAIN_TSCN = '''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://probe.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
'''

# The script draws a GPU-heavy full-screen shader so that it is visible in nvidia-smi pmon.
PROBE_GD = '''extends Node2D

var hold := 0.0
var t := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hold="):
			hold = float(a.substr(7))
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment() { vec2 p = UV * 8.0; float s = 0.0; for (int i = 0; i < 400; i++) { s += sin(p.x * float(i) * 0.01 + TIME) * cos(p.y * float(i) * 0.013 - TIME); } COLOR = vec4(0.5 + 0.5 * sin(s), 0.3, 0.6, 1.0); }"
	var r := ColorRect.new()
	r.size = Vector2(640, 360)
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	add_child(r)

func _process(delta: float) -> void:
	t += delta
	if hold > 0.0 and t >= hold:
		get_tree().quit()
'''


def make_probe(root=PROBE, name="InnerSun Coexist Probe", user_dir="InnerSunCoexistProbe"):
    os.makedirs(root, exist_ok=True)
    for fn, txt in (("project.godot", PROJECT_GODOT % (name, user_dir)), ("main.tscn", MAIN_TSCN),
                    ("probe.gd", PROBE_GD)):
        with open(os.path.join(root, fn), "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)
    return root


def probe_args(hold, root=PROBE, vsync_off=True):
    a = ["--path", root, "--resolution", "640x360", "--position", "-32000,-32000"]
    if vsync_off:
        a.append("--disable-vsync")
    return a + ["--", f"--hold={hold}"]


def port_lines(out):
    return [l.strip() for l in out.splitlines() if PORT_RE.search(l) and not any(n in l for n in NOISE)]


# ---------------------------------------------------------------- (a)
def check_a():
    make_probe()
    other_root = paths.GAME if os.path.exists(os.path.join(paths.GAME, "project.godot")) else None
    if other_root is None:
        other_root = make_probe(os.path.join(PROBE_ROOT, "probe_b"), "InnerSun Coexist Probe B", "InnerSunCoexistProbeB")
        print("  note: game/project.godot missing, using a second probe as the stand-in for Inner Sun")
    results = {}
    for ports in (False, True):
        outs = {}

        def go(key, root):
            args = ["--headless", "--path", root, "--import"]
            if ports:
                args += ["--lsp-port", str(proc.free_port()), "--dap-port", str(proc.free_port())]
            outs[key] = proc.run_godot(args, 300, log_name=f"coexist_import_{key}_{'ports' if ports else 'noports'}")

        th = [threading.Thread(target=go, args=("game", other_root)), threading.Thread(target=go, args=("probe", PROBE))]
        [t.start() for t in th]
        [t.join() for t in th]
        lines = []
        for k, r in outs.items():
            lines += [f"[{k}] {l}" for l in port_lines(r.out)]
        results[ports] = (outs, lines)
        tag = "WITH ports" if ports else "WITHOUT ports"
        print(f"  imports {tag}: " + ", ".join(f"{k} exit {r.returncode} {r.seconds:.0f}s timeout={r.timed_out}"
                                               for k, r in outs.items()))
        for l in lines[:10]:
            print("    port-related:", l)
        if not lines:
            print("    no port/bind/listen lines")
    ok = all(r.returncode == 0 and not r.timed_out for p in results.values() for r in p[0].values())
    with_ports_lines = results[True][1]
    return ok and not with_ports_lines, "imports exit 0 and no port clash lines when ports are passed" if ok else \
        "an import failed or timed out"


# ---------------------------------------------------------------- (b)
def _fg():
    u = ctypes.WinDLL("user32")
    u.GetForegroundWindow.restype = wintypes.HWND
    u.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    u.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    h = u.GetForegroundWindow()
    buf = ctypes.create_unicode_buffer(256)
    u.GetWindowTextW(h, buf, 256)
    pid = wintypes.DWORD(0)
    u.GetWindowThreadProcessId(h, ctypes.byref(pid))
    return int(h or 0), buf.value, int(pid.value)


def check_b():
    """The real game in bot mode (off-screen, --run-ticks) must never take the foreground.
    The game's Boot autoload makes bot-driven windows unfocusable; normal play keeps focus."""
    before = _fg()
    print(f"  foreground before: {before[1]!r} (pid {before[2]})")
    args = ["--path", paths.GAME, "--resolution", "1280x720", "--position", "-32000,-32000",
            "--", "--scenario=fire_drill", "--seed=3", "--run-ticks=900"]
    stolen, samples = [], 0
    with proc.GodotJob(args, log_name="coexist_focus_game") as job:
        t_end = time.time() + 60
        while job.poll() is None and time.time() < t_end:
            h, title, pid = _fg()
            samples += 1
            if pid in job.pids() or "Inner Sun" in title:
                stolen.append((round(time.time() - job.t0, 2), title, pid))
            time.sleep(0.25)
        res = job.wait(15)
    print(f"  game ran {res.seconds:.1f}s, exit {res.returncode}, {samples} foreground samples")
    if stolen:
        print("  FOCUS STOLEN:", stolen[:3])
    else:
        print("  focus never moved to the game window")
    ok = (not stolen) and samples > 10 and res.returncode == 0
    return ok, f"game in bot mode: {samples} samples, stolen={len(stolen)}"


# ---------------------------------------------------------------- (c)
def check_c():
    import perf
    make_probe()
    if not os.path.exists(os.path.join(paths.GAME, "project.godot")):
        return None, "game/project.godot missing, perf and shots need the game side"
    ok = True
    notes = []
    with proc.GodotJob(probe_args(25), log_name="coexist_other_game") as other:
        time.sleep(4)
        print("  other game pids:", other.pids())
        r = perf.measure("fire_drill", 1, seconds=5, runs=1)
        listed = [p for p, _ in (tuple(x) for x in r.get("other_processes", []))]
        has_probe = any(p in listed for p in other.pids())
        print(f"  perf: contended={r.get('contended')} samples={r.get('contention_samples')} "
              f"others={r.get('other_processes')} trusted={r.get('trusted')} err={r.get('error')}")
        if r.get("error"):
            return None, "perf run failed on the game side: " + str(r["error"])
        if not (r.get("contended") and has_probe):
            ok = False
            notes.append("perf did not report contended=true with the probe listed")
        import shots
        rc = shots.main(["--out", os.path.join(paths.OUT, "coexist", "shots")])
        if rc != 0:
            ok = False
            notes.append("shots.py failed while the probe was running")
        other.wait(40)
    return ok, "; ".join(notes) or "contention detected and shots succeeded"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["a", "b", "c"])
    a = ap.parse_args()
    checks = [("a imports without/with ports", "a", check_a), ("b focus", "b", check_b), ("c contention", "c", check_c)]
    fails = 0
    for title, key, fn in checks:
        if a.only and a.only != key:
            continue
        print(f"== ({title})")
        try:
            ok, msg = fn()
        except proc.ToolError as e:
            ok, msg = None, str(e)
        except Exception as e:  # keep going, report clearly
            ok, msg = False, f"{type(e).__name__}: {e}"
        word = "SKIP" if ok is None else ("PASS" if ok else "FAIL")
        print(f"{word} {title}: {msg}")
        fails += ok is False
    print("coexist:", "FAIL" if fails else "ok")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
