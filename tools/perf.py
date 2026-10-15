"""Performance measurement that knows when the GPU was shared.

    python tools/perf.py [--scenario fire_drill] [--seed 1] [--seconds 10] [--runs 3]

Each run is a windowed off-screen game with vsync off. While it runs, `nvidia-smi pmon` is sampled
once a second; a sample from any PID that is not in our own job with sm above 5 percent (other
Godot processes included) counts as contention. Best uncontended run wins, else the best run is
marked trusted:false. Result goes to harness/out/perf/last.json.
"""
import argparse
import json
import os
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

SM_LIMIT = 5


def _sampler(stop, lines):
    while not stop.is_set():
        try:
            r = subprocess.run(["nvidia-smi", "pmon", "-s", "u", "-d", "1", "-c", "1"], capture_output=True,
                               text=True, encoding="utf-8", errors="replace", timeout=15)
            lines.extend(r.stdout.splitlines())
        except Exception:
            stop.wait(1.0)


def parse_pmon(lines, own_pids):
    """Return (samples_from_others, names_of_others). pmon columns: gpu pid type sm mem ... command."""
    n, names = 0, set()
    for l in lines:
        q = l.split()
        if len(q) < 5 or q[0].startswith("#") or not q[1].isdigit():
            continue
        sm = q[3]
        # Under WDDM nvidia-smi pmon reports sm as "-" for graphics processes, so a foreign Godot
        # process present on the GPU counts as contention even without a number.
        foreign_godot = sm == "-" and q[-1].lower().startswith("godot")
        if (foreign_godot or (sm.isdigit() and int(sm) > SM_LIMIT)) and int(q[1]) not in own_pids:
            n += 1
            names.add(f"{q[-1]}({q[1]})")
    return n, sorted(names)


def idle_gpu_util():
    """Whole-GPU utilization (percent) before our run starts: 3 samples, the maximum."""
    best = 0
    for _ in range(3):
        try:
            v = subprocess.run(["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"],
                               capture_output=True, text=True, timeout=15).stdout.split()
            best = max(best, int(v[0]))
        except Exception:
            pass
        time.sleep(0.3)
    return best


def _one_run(scenario, seed, seconds, tmp_json, timeout):
    args = ["--path", paths.GAME, "--resolution", "1920x1080", "--position", "-32000,-32000", "--disable-vsync",
            "--", f"--scenario={scenario}", f"--seed={seed}", f"--perf={tmp_json}", f"--perf-seconds={seconds}"]
    others = proc.other_godot_processes()
    idle = idle_gpu_util()
    stop, lines, own = threading.Event(), [], set()
    th = threading.Thread(target=_sampler, args=(stop, lines), daemon=True)
    with proc.GodotJob(args, log_name="perf") as job:
        th.start()
        end = time.time() + timeout
        while job.poll() is None and time.time() < end:
            own.update(job.pids())
            time.sleep(0.25)
        res = job.wait(5)
    stop.set()
    th.join(20)
    n, names = parse_pmon(lines, own)
    if idle > 10:
        n += 1
        names.append(f"gpu busy before start ({idle}%)")
    return res, n, names, others


def measure(scenario="fire_drill", seed=1, seconds=10, runs=3):
    try:
        proc.require_game()
    except proc.ToolError as e:
        return {"error": str(e), "trusted": False, "contended": False, "contention_samples": 0,
                "other_processes": []}
    d = os.path.join(paths.OUT, "perf")
    os.makedirs(d, exist_ok=True)
    cands, last_err = [], None
    for k in range(runs):
        tmp = os.path.join(d, f"run{k}.json")
        if os.path.exists(tmp):
            os.remove(tmp)
        res, n, names, others = _one_run(scenario, seed, seconds, tmp, seconds + 60)
        if not os.path.exists(tmp):
            last_err = (f"run {k + 1} wrote no perf json (exit {res.returncode}, timed_out={res.timed_out}) "
                        + "; ".join(proc.bad_lines(res.out)[:3]))
            continue
        with open(tmp, encoding="utf-8") as f:
            data = json.load(f)
        data.update({"contended": n > 0, "contention_samples": n, "contention_by": names,
                     "other_processes": [list(o) for o in others]})
        cands.append(data)
    if not cands:
        return {"error": last_err or "no runs", "trusted": False, "contended": False, "contention_samples": 0,
                "other_processes": []}
    clean = [c for c in cands if not c["contended"]]
    best = max(clean or cands, key=lambda c: c.get("avg_fps", 0))
    best["trusted"] = bool(clean)
    best["not_nvidia"] = proc.gpu_warning(best.get("adapter", ""))
    best["runs_done"] = len(cands)
    return best


def summary(r):
    if r.get("error"):
        return "perf: FAIL (" + str(r["error"]) + ")"
    return (f"perf: avg {r.get('avg_fps')} fps, 1% low {r.get('low_1pct_fps')}, p95 {r.get('p95_ms')} ms, "
            f"gpu {r.get('gpu_ms')} ms, {r.get('adapter')}, trusted={r.get('trusted')} "
            f"(contended={r.get('contended')}, samples={r.get('contention_samples')})")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", default="fire_drill")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--seconds", type=float, default=10)
    ap.add_argument("--runs", type=int, default=3)
    a = ap.parse_args(argv)
    r = measure(a.scenario, a.seed, a.seconds, a.runs)
    d = os.path.join(paths.OUT, "perf")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "last.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(r, f, indent=2)
    print(summary(r))
    return 1 if (r.get("error") or r.get("not_nvidia")) else 0


if __name__ == "__main__":
    sys.exit(main())
