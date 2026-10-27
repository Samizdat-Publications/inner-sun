"""Local shape check: Inner Sun's parity measures beside the private FTL reference (difftest layer 3).

    python tools/parity.py

LOCAL ONLY. Reads Inner Sun's own data (game/data) and the private reference
research_private/parity_reference.json in the main checkout (git-ignored; written by the observer,
never by a builder). Writes the side-by-side to research_private/parity_local.md. What it prints holds
Inner Sun values and pass or fail only, never a reference value, so a log of it is safe anywhere.
Never part of check.py: worktrees and fresh clones have no research_private/.
"""
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402

MAIN_CHECKOUT = os.path.abspath(os.path.join(paths.ROOT, "..", "..", "..")) if ".claude" in paths.ROOT else paths.ROOT
PRIVATE = os.path.join(MAIN_CHECKOUT, "research_private")
DATA = os.path.join(paths.ROOT, "game", "data")

# Inner Sun's bands, as in docs/research/behavior-ledger.md (Inner Sun values, public).
BANDS = {
    "upg_last_over_first": (1.4, 3.7),  # steps add 0.4 to 0.9 of the first over 1 to 4 steps
    "reactor_pair_step": (1.2, 1.5),
    "reactor_over_system": (0.4, 0.8),
    "reward_growth": (3.0, 5.0),
    "tier_low_mean": (0.6, 0.75),
    "tier_medium_mean": (0.95, 1.05),
    "tier_high_mean": (1.35, 1.6),
    "hull_deep_over_shallow": (1.5, 2.0),
    "sell_back_frac": (0.33, 0.5),
    "supply_stock_max": (2, 6),
    "closed_door_fire_ratio": (0.3, 0.5),
    "manning_top_over_base": (1.5, 2.0),
}


def _json(*parts):
    with open(os.path.join(*parts), encoding="utf-8") as f:
        return json.load(f)


def _tune(name):
    t = _json(DATA, "tuning", name + ".json")
    return t[next(iter(t))]  # The file's one section.


def measures() -> dict:
    ship = _json(DATA, "ships", "light_drill.json")
    start = {r["system"]: int(r["bars"]) for r in ship["rooms"] if r.get("system")}
    sold = {}
    for sysid, bars in start.items():
        ladder = _json(DATA, "systems", sysid + ".json").get("bar_prices", [])
        sold[sysid] = [int(p) for p in ladder[bars:]]
    m = {}
    ratios = [v[-1] / v[0] for k, v in sold.items() if k != "reactor" and len(v) >= 2]
    m["upg_last_over_first"] = statistics.median(ratios)
    rx = sold.get("reactor", [])
    pairs = [rx[i] for i in range(0, len(rx), 2)]
    m["reactor_pair_step"] = statistics.mean(pairs[i + 1] / pairs[i] for i in range(len(pairs) - 1))
    firsts = [v[0] for k, v in sold.items() if k != "reactor" and v]
    m["reactor_over_system"] = rx[0] / statistics.mean(firsts)
    eco = _tune("economy")
    gem = eco["gem_ore_value"]

    def value(row):
        r = max(1, row)
        return (eco["reward_ore_row1"] + eco["reward_ore_per_row"] * (r - 1)) + gem * (eco["reward_gems_row1"] + eco["reward_gems_per_row"] * (r - 1))
    m["reward_growth"] = value(13) / value(1)
    for t in ("low", "medium", "high"):
        m[f"tier_{t}_mean"] = (eco[f"tier_{t}_min"] + eco[f"tier_{t}_max"]) / 2.0
    store = _json(DATA, "stores", "crust_trader.json")
    hull = next(s for s in store["supplies"] if s["item"] == "hull")

    def hull_at(row):
        p = 0
        for step in hull["price_by_row"]:
            if row >= int(step["from_row"]):
                p = step["price"]
        return p
    m["hull_deep_over_shallow"] = hull_at(10) / hull_at(1)
    m["sell_back_frac"] = eco["sell_back_frac"]
    m["supply_stock_max"] = max(int(s["stock"][1]) for s in store["supplies"] if "stock" in s)
    m["closed_door_fire_ratio"] = _json(DATA, "tuning", "hazards.json")["fire"]["spread_closed_factor"]
    m["manning_top_over_base"] = 1.0 + _json(DATA, "tuning", "systems.json")["systems"]["station_skill_gain"]
    return m


def main() -> int:
    ref_path = os.path.join(PRIVATE, "parity_reference.json")
    if not os.path.isfile(ref_path):
        print("parity: no private reference (research_private/parity_reference.json); local only, skipped")
        return 0
    ref = _json(ref_path)
    m = measures()
    rows = []
    fails = 0
    for key, (lo, hi) in BANDS.items():
        v = m[key]
        ok = lo <= v <= hi
        fails += 0 if ok else 1
        print(f"parity: {key:<24} {v:7.3f}  band {lo}..{hi}  {'pass' if ok else 'FAIL'}")
        r = ref.get(key, {})
        f = r.get("ftl")
        wraps = f is not None and lo <= f <= hi
        rows.append(f"| {key} | {r.get('row', '')} | {v:.3f} | {lo} to {hi} | {'pass' if ok else 'FAIL'} | "
                    f"{f if f is not None else 'n/a'} | {(v / f) if f else float('nan'):.2f} | {'yes' if wraps else 'no'} |")
    out = os.path.join(PRIVATE, "parity_local.md")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Parity, local shape check (PRIVATE)\n\nInner Sun value, its band, the FTL reference and the ratio. "
                 "'Band wraps FTL' flags a band that simply contains the source value (the ledger says a band must not "
                 "just wrap it; such rows are fine only when the anchor is Inner Sun's own).\n\n"
                 "| measure | row | Inner Sun | band | in band | FTL | IS / FTL | band wraps FTL |\n|---|---|---|---|---|---|---|---|\n")
        fh.write("\n".join(rows) + "\n")
    print(f"parity: {len(BANDS) - fails}/{len(BANDS)} measures in band; side-by-side in research_private/parity_local.md")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
