"""Compare two full balance runs seed by seed: the oracle for refactors that must change nothing.

    python tools/balance_compare.py <baseline results.jsonl or folder> <new results.jsonl or folder>

Each line of results.jsonl (tools/balance_full.py) carries bot, seed and final_hash. Both runs must
come from the same command (same --runs, --procs and seed base): each part carries its own profile,
so a different split into parts can change what the bots know. Every (bot, seed) must match. Prints
how many match, the first mismatches, and `compare: ok` or `compare: FAIL`. Exit 0 or 1.
"""
import json
import os
import sys


def _load(path):
    if os.path.isdir(path):
        path = os.path.join(path, "results.jsonl")
    out = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                r = json.loads(line)
                out[(r.get("bot", ""), int(r.get("seed", -1)))] = r.get("final_hash")
    return out


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 1
    a, b = _load(argv[0]), _load(argv[1])
    keys = sorted(set(a) | set(b))
    bad = [k for k in keys if a.get(k) is None or a.get(k) != b.get(k)]
    print(f"pairs: {len(keys)}, matching: {len(keys) - len(bad)}")
    for k in bad[:10]:
        print(f"  {k[0]} seed {k[1]}: {a.get(k)} vs {b.get(k)}")
    if bad or not keys:
        print("compare: FAIL")
        return 1
    print("compare: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
