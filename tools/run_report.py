"""Summarize Stewart's saved runs for playtest triage, without launching Godot.

    python tools/run_report.py                 the newest 5 runs in the game's user folder
    python tools/run_report.py --last 10       the newest 10
    python tools/run_report.py --since 2026-10-17
    python tools/run_report.py --dir <folder>  another runs folder (default %APPDATA%\\InnerSun\\runs)

Per run: when, seed, how it ended, rows and depth, time, ore and gems, then the commands the player
gave by type with the time each was first used (which verbs he found and which he never touched),
and the longest stretches with no command at all (where he may have been watching, stuck or bored).
A record is a seed plus the command log plus a summary (game/meta/run_record.gd); `t` is in sim ticks
at 60 Hz. Reads JSON only.
"""
import argparse
import datetime
import glob
import json
import os
import sys

TICK_HZ = 60.0
GAP_S = 45.0  ## Report quiet stretches at least this long.
# Verbs worth checking for discovery, with the key that triggers each in the game.
VERBS = [
    ("steer", "A/D, S, scanner click"), ("power", "Q W E R T, Shift"), ("change_bit", "B"),
    ("blast", "F2 + click"), ("douse", "F or DOUSE button"), ("send_miner", "G + click"),
    ("recall_miner", "G"), ("assign", "1-3 then a room"), ("target", "F1-F3 then click the enemy"),
]


def fmt_s(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    return "%d:%02d" % (m, s)


def stamp_of(path: str) -> str:
    base = os.path.basename(path)
    try:
        d = datetime.datetime.strptime(base[:15], "%Y%m%d-%H%M%S")
        return d.strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return base


def report(path: str) -> list:
    with open(path, encoding="utf-8") as f:
        rec = json.load(f)
    s = rec.get("summary", {})
    cmds = rec.get("commands", [])
    out = []
    gained = s.get("gained", {})
    out.append("%s  seed %s  %s (%s)  row %s/%s  %.0f m  %s  ore +%s gems +%s  fights won %s" % (
        stamp_of(path), rec.get("seed", "?"), s.get("result", "?"), s.get("cause", "-"),
        s.get("rows_reached", "?"), s.get("rows_total", "?"), float(s.get("depth_m", 0.0)),
        fmt_s(float(s.get("time_s", rec.get("ticks", 0) / TICK_HZ))), gained.get("ore", 0),
        gained.get("gems", 0), s.get("fights_won", 0)))
    counts = {}
    first = {}
    for c in cmds:
        k = str(c.get("type", "?"))
        counts[k] = counts.get(k, 0) + 1
        first.setdefault(k, int(c.get("t", 0)))
    line = ", ".join("%s %d (first %s)" % (k, counts[k], fmt_s(first[k] / TICK_HZ)) for k in sorted(counts))
    out.append("  commands: " + (line if line else "none"))
    never = [("%s [%s]" % (v, key)) for v, key in VERBS if v not in counts]
    if never:
        out.append("  never used: " + ", ".join(never))
    ticks = [int(c.get("t", 0)) for c in cmds] + [int(rec.get("ticks", 0))]
    prev = 0
    gaps = []
    for t in ticks:
        if (t - prev) / TICK_HZ >= GAP_S:
            gaps.append((t - prev, prev))
        prev = t
    gaps.sort(reverse=True)
    if gaps:
        out.append("  quiet stretches: " + ", ".join("%s from %s" % (fmt_s(g / TICK_HZ), fmt_s(at / TICK_HZ)) for g, at in gaps[:4]))
    ui = s.get("ui", [])
    if isinstance(ui, list) and ui:
        fs = [u for u in ui if u.get("in") == "F"]
        dc = [u for u in ui if u.get("in") == "click" and u.get("douse")]
        blocked = [u for u in dc if u.get("over")]
        out.append("  input diary: %d clicks, %d F presses (%d with a fire), %d clicks on a DOUSE button (%d under a UI control: %s)" % (
            len([u for u in ui if u.get("in") == "click"]), len(fs), len([u for u in fs if u.get("worst")]),
            len(dc), len(blocked), ", ".join(sorted(set(str(u.get("over")) for u in blocked)))[:160]))
    verbs = s.get("verbs", {})
    if isinstance(verbs, dict) and verbs:
        keep = ["blasts", "douses", "rockfalls", "structures_entered", "crates_opened", "sorties",
                "miner_backs", "miner_deaths", "haul_ore", "haul_gems"]
        shown = ["%s %s" % (k, verbs[k]) for k in keep if k in verbs]
        if shown:
            out.append("  dig: " + ", ".join(shown))
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(os.environ.get("APPDATA", ""), "InnerSun", "runs"))
    ap.add_argument("--last", type=int, default=5)
    ap.add_argument("--since", default="", help="YYYY-MM-DD: only runs from this date on")
    a = ap.parse_args(argv)
    files = sorted(glob.glob(os.path.join(a.dir, "*.json")))
    if a.since:
        key = a.since.replace("-", "")
        files = [f for f in files if os.path.basename(f)[:8] >= key]
    files = files[-a.last:] if a.last > 0 else files
    if not files:
        print("run_report: no runs in %s" % a.dir)
        return 1
    for f in files:
        try:
            for l in report(f):
                print(l)
        except (OSError, ValueError, KeyError) as e:
            print("%s: unreadable (%s)" % (os.path.basename(f), e))
        print("")
    return 0


if __name__ == "__main__":
    sys.exit(main())
