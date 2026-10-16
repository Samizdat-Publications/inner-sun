"""Whole-run balance (M1 step 7): the policy bots play full runs headless, then a report.

    python tools/balance.py --full --runs 1000 --procs 6 --pack

--runs is the TOTAL across the bots (default cautious,greedy,balanced): 1000 runs is about 334 per
bot. Every bot plays the same seeds (seed_base ..), so they meet the same maps. The seeds of each bot
are split into contiguous parts; at most --procs Godot processes run at once, below-normal priority,
each in its own job (tools/proc.py). Each part keeps a profile in its own folder under the output
(--profile-dir), so learned codex carries over between that part's runs as it would for a player;
nothing touches user://. With --pack and no path a fresh frozen pack is made first
(tools/snapshot.py); with a path that pack is used.
Writes harness/out/balance/full_<stamp>/{parts/*.jsonl, profiles/, results.jsonl, full_report.md}
and copies the report to harness/out/balance/full_report.md.
"""
import collections
import datetime as dt
import json
import os
import re
import shutil
import statistics
import time
from concurrent.futures import ThreadPoolExecutor

import paths
import proc

DONE_RE = re.compile(r"FULLRUNS done runs=(\d+) ticks=(\d+) secs=([\d.]+) ticks_per_sec=([\d.]+)")
RES = ["hull", "ore", "gems", "coolant", "cells", "bits", "charges"]
DEFAULT_BOTS = "cautious,greedy,balanced"


def _part(task, timeout, pack, game_target, spawn):
    bot, seed0, count, path, prof = task
    args = ["--headless"] + game_target(pack) + ["--script", "res://tools/full_runs.gd", "--",
            f"--runs={count}", f"--seed-base={seed0}", f"--bot={bot}", f"--out={path}", f"--profile-dir={prof}"]
    job = spawn(args)
    try:
        r = job.wait(timeout)
    finally:
        job.close()
    lines = 0
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            lines = sum(1 for l in f if l.strip())
    m = DONE_RE.search(r.out)
    return {"bot": bot, "seed0": seed0, "count": count, "path": path, "lines": lines, "exit": r.returncode,
            "timed_out": r.timed_out, "secs": r.seconds, "tps": float(m.group(4)) if m else 0.0,
            "done": bool(m), "bad": proc.bad_lines(r.out, 5)}


def _pct(a, b):
    return 100.0 * a / b if b else 0.0


def _med(xs):
    return statistics.median(xs) if xs else 0


def _q(xs, q):
    if not xs:
        return 0
    s = sorted(xs)
    return s[min(len(s) - 1, int(q * (len(s) - 1) + 0.5))]


def _dist(xs):
    c = collections.Counter(xs)
    return ", ".join(f"{k}: {c[k]}" for k in sorted(c))


def _bot_section(b, rs):
    n = len(rs)
    out = [f"## {b} ({n} runs)", ""]
    if not n:
        return out + ["no runs", ""]
    res = collections.Counter(r["result"] for r in rs)
    out.append("- results: " + ", ".join(f"{k} {v} ({_pct(v, n):.1f}%)" for k, v in res.most_common()))
    dead = [r for r in rs if r["result"] != "won"]
    causes = collections.Counter(_cause(r) for r in dead)
    ends = collections.Counter(r.get("cause") or "unknown" for r in dead)
    out.append("- run end causes (hull, crew_<cause>, flooded): " + ", ".join(f"{k} {v}" for k, v in ends.most_common()))
    out.append("- killers (share of all runs): " + ", ".join(f"{k} {v} ({_pct(v, n):.1f}%)" for k, v in causes.most_common()))
    out.append("- rows reached: " + _dist([r["rows_reached"] for r in rs]))
    out.append("- death row (non-wins): " + _dist([r["rows_reached"] for r in dead]))
    t = [r["time_s"] for r in rs]
    out.append(f"- run length s: median {_med(t):.0f}, p10 {_q(t, 0.1):.0f}, p90 {_q(t, 0.9):.0f}")
    fights = [f for r in rs for f in r.get("fights", [])]
    fr = collections.Counter((("gate " if f[1] else "") + f[2]) for f in fights)
    out.append("- fights per run: " + _dist([len(r.get("fights", [])) for r in rs]))
    out.append("- fight results: " + ", ".join(f"{k} {v}" for k, v in sorted(fr.items())))
    fs = [f[3] for f in fights if not f[1]]
    gs = [f[3] for f in fights if f[1]]
    out.append(f"- fight length s: rivals median {_med(fs):.0f}, gate median {_med(gs):.0f}")
    gate = [f for f in fights if f[1]]
    gw = sum(1 for f in gate if f[2] == "won")
    out.append(f"- gate reached {len(gate)} times, won {gw} ({_pct(gw, len(gate)):.0f}%)")
    for k, label in [("strikes_overtaken", "pursuer strikes on overtaken nodes"), ("strikes_caught", "pursuer strikes while caught"),
                     ("catches", "pursuer catches"), ("bit_breaks", "bit breaks"), ("coolant_outs", "coolant outs"),
                     ("crew_lost", "crew lost"), ("fires", "fires started"), ("nodes_overtaken", "nodes overtaken"),
                     ("rockfalls_hit", "rockfalls hit"), ("rockfalls_absorbed", "rockfalls absorbed"),
                     ("rockfall_hull", "hull lost to rockfalls"), ("blasts", "blasts"), ("blast_ore", "ore from blasts"),
                     ("blast_gems", "gems from blasts"), ("douses", "douses"), ("steep_s", "drilling s past 60 degrees")]:
        xs = [r.get(k, 0) for r in rs]
        out.append(f"- {label}: mean {statistics.fmean(xs):.2f}, runs with any {_pct(sum(1 for x in xs if x), n):.0f}%")
    deaths = collections.Counter(c for r in rs for c in r.get("crew_deaths", []))
    out.append("- crew death causes: " + (", ".join(f"{k} {v}" for k, v in deaths.most_common()) or "none"))
    won = [r for r in rs if r["result"] == "won"]
    for label, group in [("all", rs), ("winners", won), ("losers", dead)]:
        if group:
            g = [r["gained"]["gems"] for r in group]
            o = [r["gained"]["ore"] for r in group]
            out.append(f"- {label}: gems gained median {_med(g):.0f}, ore gained median {_med(o):.0f}")
    bought = collections.Counter(x for r in rs for x in r.get("bought", []))
    out.append("- store lines bought (store line: count): " + (", ".join(f"{k}: {v}" for k, v in sorted(bought.items())) or "none"))
    out += ["", "Resources on arrival per row (median [p10-p90]):", "",
            "| row | runs | t s | " + " | ".join(RES) + " |", "|---" * (len(RES) + 3) + "|"]
    by_row = collections.defaultdict(list)
    for r in rs:
        for snap in r.get("rows", []):
            by_row[snap[0]].append(snap)
    for row in sorted(by_row):
        snaps = by_row[row]
        cells = [f"{_med([s[1] for s in snaps]):.0f}"]
        for i in range(len(RES)):
            xs = [s[2 + i] for s in snaps]
            cells.append(f"{_med(xs):.0f} [{_q(xs, 0.1)}-{_q(xs, 0.9)}]")
        out.append(f"| {row} | {len(snaps)} | " + " | ".join(cells) + " |")
    out.append("")
    return out


def _cause(r):
    c = r.get("killer") or r.get("cause") or "unknown"
    if r["result"] == "stuck":
        return "stuck"
    return c


def _event_section(all_rows, db_events):
    n = len(all_rows)
    ev = collections.Counter(e for r in all_rows for e in r.get("events", []))
    ch = collections.Counter(c for r in all_rows for c in r.get("choices", []))
    oc = collections.Counter(c for r in all_rows for c in r.get("outcomes", []))
    out = ["## Events (all bots)", "", f"{n} runs.", "", "| event | started | per 1000 runs |", "|---|---|---|"]
    for e in sorted(set(db_events) | set(ev)):
        out.append(f"| {e} | {ev[e]} | {1000.0 * ev[e] / max(1, n):.0f} |")
    never = [e for e in sorted(db_events) if ev[e] == 0]
    out += ["", "Events never seen: " + (", ".join(never) if never else "none"), "",
            "| choice (event/page/option) | times | outcomes (next page: times) |", "|---|---|---|"]
    for c in sorted(ch):
        outs = sorted((k.split(">", 1)[1], v) for k, v in oc.items() if k.split(">", 1)[0] == c)
        out.append(f"| {c} | {ch[c]} | " + ", ".join(f"{p}: {v}" for p, v in outs) + " |")
    out.append("")
    return out


def run_full(a, game_target, make_pack):
    pack = a.pack
    if pack == "auto":
        pack = make_pack()
        if not pack:
            print("balance --full: FAIL (snapshot failed)")
            return 1
    bots = [b for b in (a.bots if a.bots != "auto,idle,random" else DEFAULT_BOTS).split(",") if b]
    per_bot = -(-a.runs // len(bots))
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    base = os.path.join(paths.OUT, "balance", "full_" + stamp)
    parts_dir = os.path.join(base, "parts")
    os.makedirs(parts_dir, exist_ok=True)
    nparts = max(1, min(a.procs * 3, per_bot // 10 or 1))  # several parts per process keeps the tail short
    tasks = []
    for bot in bots:
        base_n, extra = divmod(per_bot, nparts)
        off = 0
        for i in range(nparts):
            size = base_n + (1 if i < extra else 0)
            if size:
                tasks.append((bot, a.seed_base + off, size, os.path.join(parts_dir, f"{bot}_{i:02d}.jsonl"),
                              os.path.join(base, "profiles", f"{bot}_{i:02d}")))
            off += size
    lock = __import__("threading").Lock()

    def spawn(args):
        with lock:
            return proc.GodotJob(args, below_normal=True)

    others = proc.other_godot_processes() if hasattr(proc, "other_godot_processes") else []
    t0 = time.time()
    print(f"balance --full: {per_bot} runs x {len(bots)} bots in {len(tasks)} parts, {a.procs} at a time, "
          f"{'pack ' + pack if pack else 'live project'}, output {base}", flush=True)
    with ThreadPoolExecutor(max_workers=a.procs) as ex:
        results = list(ex.map(lambda t: _part(t, a.timeout, pack, game_target, spawn), tasks))
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
    for b in bots:
        rows[b].sort(key=lambda r: r["seed"])
    with open(os.path.join(base, "results.jsonl"), "w", encoding="utf-8", newline="\n") as f:
        for b in bots:
            for row in rows[b]:
                f.write(json.dumps(row) + "\n")
    ev_dir = os.path.join(paths.GAME, "data", "events")
    db_events = sorted(os.path.splitext(x)[0] for x in os.listdir(ev_dir) if x.endswith(".json"))
    total = sum(len(v) for v in rows.values())
    out = [f"# Full-run balance report {stamp}", "",
           f"{total} runs ({per_bot} per bot, seeds {a.seed_base}..{a.seed_base + per_bot - 1}), {a.procs} processes, "
           f"wall {wall:.0f} s ({wall / 60:.1f} min, {wall * 1000 / max(1, total) / 60:.1f} min per 1000 runs). "
           f"{'Pack: ' + os.path.basename(pack) if pack else 'Live project (no pack).'}",
           ("Another Godot was running during the batch: wall time untrusted." if others else ""), "",
           "| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |",
           "|---|---|---|---|---|---|---|---|---|"]
    for b in bots:
        rs = rows[b]
        n = len(rs)
        if not n:
            continue
        won = sum(1 for r in rs if r["result"] == "won")
        stuck = sum(1 for r in rs if r["result"] == "stuck")
        causes = collections.Counter(_cause(r) for r in rs if r["result"] != "won")
        top = causes.most_common(1)
        gate = [f for r in rs for f in r.get("fights", []) if f[1]]
        gw = sum(1 for f in gate if f[2] == "won")
        out.append(f"| {b} | {n} | {_pct(won, n):.1f} | {stuck} | {_med([r['rows_reached'] for r in rs]):.0f} | "
                   f"{_med([r['time_s'] for r in rs]):.0f} | {statistics.fmean([len(r.get('fights', [])) for r in rs]):.2f} | "
                   f"{_pct(gw, len(gate)):.0f} | {top[0][0] + ' ' + format(_pct(top[0][1], n), '.0f') + '%' if top else '-'} |")
    out += ["", "Dig verbs, means per run:", "",
            "| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |",
            "|---|---|---|---|---|---|---|---|---|"]
    for b in bots:
        rs = rows[b]
        if rs:
            m = [statistics.fmean([r.get(k, 0) for r in rs]) for k in
                 ("rockfalls_hit", "rockfalls_absorbed", "rockfall_hull", "blasts", "blast_ore", "blast_gems", "douses", "steep_s")]
            out.append(f"| {b} | " + " | ".join(f"{x:.2f}" for x in m[:7]) + f" | {m[7]:.0f} |")
    out.append("")
    for b in bots:
        out += _bot_section(b, rows[b])
    out += _event_section([r for b in bots for r in rows[b]], db_events)
    out += ["## Processes", "", "| bot | seeds | lines | exit | ticks/s | secs |", "|---|---|---|---|---|---|"]
    for r in results:
        out.append(f"| {r['bot']} | {r['seed0']}..{r['seed0'] + r['count'] - 1} | {r['lines']}/{r['count']} | "
                   f"{r['exit']}{' timeout' if r['timed_out'] else ''} | {r['tps']:.0f} | {r['secs']:.0f} |")
    report = os.path.join(base, "full_report.md")
    with open(report, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    shutil.copyfile(report, os.path.join(paths.OUT, "balance", "full_report.md"))
    failed = [r for r in results if r["exit"] != 0 or r["timed_out"] or r["lines"] < r["count"] or not r["done"]]
    print("\n".join(out[:4 + 4 + len(bots) + 4 + len(bots)]))
    print("report:", report)
    for r in failed:
        print(f"balance --full: part {os.path.basename(r['path'])} FAILED (exit {r['exit']}, timeout={r['timed_out']}, "
              f"lines {r['lines']}/{r['count']}) {r['bad'][:2]}")
    stuck = sum(1 for b in bots for r in rows[b] if r["result"] == "stuck")
    print("balance --full:", "FAIL" if failed or stuck else "ok", f"({wall:.0f}s, {stuck} stuck)")
    return 1 if failed or stuck else 0
