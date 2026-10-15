"""Parallel headless balance runs.

    python tools/balance.py --runs 2000 --procs 6 --bots auto,idle,random --seed-base 1000

For each bot the seeds seed_base .. seed_base+runs-1 are split into contiguous chunks, one per
process. At most --procs Godot processes run at once (below-normal priority, each in its own job).
Writes harness/out/balance/<stamp>/{parts/*.jsonl, results.jsonl, report.md}.
"""
import argparse
import datetime as dt
import json
import os
import ctypes
import json as _json
import re
import statistics
import sys
import time
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402

BAL_RE = re.compile(r"BALANCE done runs=(\d+) ticks=(\d+) secs=([\d.]+) ticks_per_sec=([\d.]+)")


class _MEM(ctypes.Structure):
    _fields_ = [("dwLength", ctypes.c_uint32), ("dwMemoryLoad", ctypes.c_uint32), ("ullTotalPhys", ctypes.c_uint64),
                ("ullAvailPhys", ctypes.c_uint64), ("ullTotalPageFile", ctypes.c_uint64),
                ("ullAvailPageFile", ctypes.c_uint64), ("ullTotalVirtual", ctypes.c_uint64),
                ("ullAvailVirtual", ctypes.c_uint64), ("ullAvailExtendedVirtual", ctypes.c_uint64)]


def free_ram_gb():
    m = _MEM()
    m.dwLength = ctypes.sizeof(m)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
    return m.ullAvailPhys / 2 ** 30


_SPAWN_LOCK = __import__("threading").Lock()


def wait_for_ram(min_gb=2.0):
    """Hold the next spawn while free RAM is under min_gb (spawns are serialized so the check is honest)."""
    noted = False
    while free_ram_gb() < min_gb:
        if not noted:
            print(f"balance: holding spawn, free RAM {free_ram_gb():.1f} GB < {min_gb} GB", flush=True)
            noted = True
        time.sleep(5)


def game_target(pack):
    return ["--main-pack", os.path.abspath(pack)] if pack else ["--path", paths.GAME]


def chunks(n, k):
    base, extra = divmod(n, k)
    res, start = [], 0
    for i in range(k):
        size = base + (1 if i < extra else 0)
        if size:
            res.append((start, size))
        start += size
    return res


def run_part(task, timeout, pack=None):
    bot, seed0, count, path = task
    args = ["--headless"] + game_target(pack) + ["--script", "res://tools/balance_runner.gd", "--",
            f"--runs={count}", f"--seed-base={seed0}", f"--bot={bot}", f"--out={path}"]
    with _SPAWN_LOCK:
        wait_for_ram()
        job = proc.GodotJob(args, below_normal=True)
        time.sleep(2)  # let the new process commit its memory before the next RAM check
    try:
        r = job.wait(timeout)
    finally:
        job.close()
    lines = 0
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            lines = sum(1 for l in f if l.strip())
    m = BAL_RE.search(r.out)
    return {"bot": bot, "seed0": seed0, "count": count, "path": path, "lines": lines, "exit": r.returncode,
            "timed_out": r.timed_out, "secs": r.seconds, "tps": float(m.group(4)) if m else 0.0,
            "ticks": int(m.group(2)) if m else 0, "bal": bool(m), "bad": proc.bad_lines(r.out, 5)}


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def bench(a):
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    base = os.path.join(paths.OUT, "balance", stamp)
    os.makedirs(base, exist_ok=True)
    out_file = os.path.join(base, "bench_runner_out.json")
    args = ["--headless"] + game_target(a.pack) + ["--script", "res://tools/balance_runner.gd", "--", "--bench",
                                                  f"--out={out_file}"]
    r = proc.run_godot(args, a.timeout, log_name="balance_bench")
    line = next((l.strip() for l in r.out.splitlines() if l.startswith("BENCH ")), None)
    if not line or r.returncode != 0:
        print(f"balance --bench: FAIL (exit {r.returncode}, BENCH line={bool(line)}, timeout={r.timed_out}) "
              f"{proc.bad_lines(r.out, 3)}")
        return 1
    data = _json.loads(line[len("BENCH "):])
    with open(os.path.join(base, "bench.json"), "w", encoding="utf-8", newline="\n") as f:
        _json.dump(data, f, indent=2)
    with open(os.path.join(base, "report.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(f"# Balance bench {stamp}\n\nOne process, normal priority, {r.seconds:.0f} s wall.\n\n```json\n"
                + _json.dumps(data, indent=2) + "\n```\n")
    print(line)
    print("report:", os.path.join(base, "report.md"))
    print("balance --bench: ok")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=2000)
    ap.add_argument("--procs", type=int, default=6)
    ap.add_argument("--bots", default="auto,idle,random")
    ap.add_argument("--seed-base", type=int, default=1000)
    ap.add_argument("--m1-tick-factor", type=float, default=4.0)
    ap.add_argument("--m1-ticks-per-run", type=int, default=30000)
    ap.add_argument("--timeout", type=int, default=7200, help="per process, seconds")
    ap.add_argument("--pack", default=None, help="run the runner from a frozen .pck (--main-pack) instead of --path game")
    ap.add_argument("--bench", action="store_true", help="one NORMAL-priority process: balance_runner.gd --bench")
    a = ap.parse_args(argv)
    try:
        if a.pack:
            if not os.path.exists(a.pack):
                raise proc.ToolError(f"pack not found: {a.pack}")
        else:
            proc.require_game()
    except proc.ToolError as e:
        print("balance: FAIL (" + str(e) + ")")
        return 1
    if a.bench:
        return bench(a)
    bots = [b for b in a.bots.split(",") if b]
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    base = os.path.join(paths.OUT, "balance", stamp)
    parts_dir = os.path.join(base, "parts")
    os.makedirs(parts_dir, exist_ok=True)
    tasks = []
    for bot in bots:
        for i, (off, size) in enumerate(chunks(a.runs, a.procs)):
            tasks.append((bot, a.seed_base + off, size, os.path.join(parts_dir, f"{bot}_{i:02d}.jsonl")))
    t0 = time.time()
    print(f"balance: {len(tasks)} parts, {a.procs} at a time, output {base}", flush=True)
    with ThreadPoolExecutor(max_workers=a.procs) as ex:
        results = list(ex.map(lambda t: run_part(t, a.timeout, a.pack), tasks))
    wall = time.time() - t0

    rows = {b: [] for b in bots}
    for r in results:
        if os.path.exists(r["path"]):
            with open(r["path"], encoding="utf-8") as f:
                for l in f:
                    if l.strip():
                        try:
                            rows[r["bot"]].append(json.loads(l))
                        except ValueError:
                            pass
    with open(os.path.join(base, "results.jsonl"), "w", encoding="utf-8", newline="\n") as f:
        for b in bots:
            for row in rows[b]:
                f.write(json.dumps(row) + "\n")

    out = [f"# Balance report {stamp}", "", f"runs per bot {a.runs}, processes {a.procs}, seeds from {a.seed_base}", ""]
    table = []
    for b in bots:
        rs = rows[b]
        n = len(rs)
        surv = sum(1 for r in rs if r.get("outcome") == "survived")
        causes = {}
        for r in rs:
            if r.get("outcome") != "survived":
                c = r.get("cause") or "unknown"
                causes[c] = causes.get(c, 0) + 1
        ticks = [r.get("ticks", 0) for r in rs]
        ff = [r["first_fire_out_s"] for r in rs if r.get("first_fire_out_s", -1) != -1]
        mw = [r.get("max_water_m3", 0) for r in rs]
        out += [f"## Bot: {b}", "", f"- runs: {n}", f"- survival: {pct(surv, n):.1f}% ({surv}/{n})"]
        if causes:
            out.append("- death causes: " + ", ".join(f"{c} {k} ({pct(k, n):.1f}%)" for c, k in
                                                      sorted(causes.items(), key=lambda x: -x[1])))
        else:
            out.append("- death causes: none")
        out += [f"- ticks: median {statistics.median(ticks) if ticks else 0:.0f}, mean {statistics.fmean(ticks) if ticks else 0:.0f}",
                f"- mean first_fire_out_s: {statistics.fmean(ff):.1f} (over {len(ff)} runs)" if ff else
                "- mean first_fire_out_s: n/a (no run put a fire out)",
                f"- mean max_water_m3: {statistics.fmean(mw) if mw else 0:.2f}", ""]
        table.append((b, n, pct(surv, n), statistics.fmean(ticks) if ticks else 0))
    out += ["## Processes", "", "| bot | seeds | lines | exit | ticks/s | secs |", "|---|---|---|---|---|---|"]
    for r in results:
        out.append(f"| {r['bot']} | {r['seed0']}..{r['seed0'] + r['count'] - 1} | {r['lines']}/{r['count']} | "
                   f"{r['exit']}{' timeout' if r['timed_out'] else ''} | {r['tps']:.0f} | {r['secs']:.0f} |")
    tps = [r["tps"] for r in results if r["tps"] > 0]
    mean_tps = statistics.fmean(tps) if tps else 0.0
    out += ["", f"Total wall time: {wall:.0f} s.", ""]
    bj = os.path.join(base, "bench.json")
    if os.path.exists(bj):
        out += ["## Bench", "", "```json", open(bj, encoding="utf-8").read(), "```", ""]
    out.append("## M1-scale estimate")
    out.append("")
    if mean_tps > 0:
        per_run = a.m1_ticks_per_run * a.m1_tick_factor / mean_tps
        wall1000 = 1000 * per_run / a.procs
        out.append(f"Measured mean {mean_tps:.0f} ticks/s per process with {a.procs} processes busy. At M1 scale a tick is "
                   f"assumed {a.m1_tick_factor:g}x as costly and a run {a.m1_ticks_per_run} ticks, so one M1 layer-run "
                   f"takes about {per_run:.0f} s per process, and 1000 runs on {a.procs} processes take about "
                   f"{wall1000:.0f} s ({wall1000 / 60:.1f} min).")
    else:
        out.append("No ticks_per_sec was reported, so no projection is possible.")
    with open(os.path.join(base, "report.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")

    failed = [r for r in results if r["exit"] != 0 or r["timed_out"] or r["lines"] < r["count"] or not r["bal"]]
    print("\n| bot | runs | survival % | mean ticks |\n|---|---|---|---|")
    for b, n, s, t in table:
        print(f"| {b} | {n} | {s:.1f} | {t:.0f} |")
    print("report:", os.path.join(base, "report.md"))
    for r in failed:
        print(f"balance: part {os.path.basename(r['path'])} FAILED (exit {r['exit']}, timeout={r['timed_out']}, "
              f"lines {r['lines']}/{r['count']}, BALANCE line={r['bal']}) {r['bad'][:2]}")
    print("balance:", "FAIL" if failed else "ok", f"({wall:.0f}s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
