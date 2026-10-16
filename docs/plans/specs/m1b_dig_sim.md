# Spec: M1b round 2, the digging economy (sim, data, bots)

For a `builder-opus` in its own worktree. Read CLAUDE.md (hard rules: sim purity, one command chain,
determinism, exact integer resources, content is data, strict typing), HANDOFF.md gotchas,
docs/ARCHITECTURE.md, docs/DECISIONS.md D021 to D024, docs/plans/M1b.md, then game/sim/drill/*,
game/sim/run/*, game/sim/events/store.gd, game/sim/systems/systems.gd, game/bots/*, game/data/rock,
layers, stores, tuning. Godot API dump (git-ignored): read it from the main repo,
`C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`.

## Why (Stewart, D024)
"Each level is like 30 seconds and you get like one piece of coal." He chose "Digging is the game":
gathering ore and gems is the main loop, with the FTL systems, crew, events, upgrades and combat kept,
but fights now and then rather than encounter after encounter ("scanning planets and gaining
resources"). His favourite games are digging games: collect ore and gems, upgrade your gear.

## Owned files
game/sim/drill/**, game/sim/run/** (map_gen, run_state, run_lint), game/sim/events/store.gd,
game/sim/systems/systems.gd (only to read new gear modifiers), game/sim/ship/** (only for max hull),
game/bots/**, game/data/rock/**, game/data/layers/**, game/data/stores/**, game/data/tuning/**,
a new game/data/gear/ if you need it, game/tests/** for these, docs/research/m1-evidence/ (balance
report). NOT game/view/** (another agent owns it now) and not game/data/events, codex, radio.

## What to build

1. **Longer segments.** `row_depth_m` 28 to 60 (the rock grid grows to match; keep width 32 m unless
   the steerable band needs more). Keep 10 rows. Target per segment: 45 to 75 s at sensible power.
2. **Rich, tiered rock.** New materials with integer yields: coal (ore 1), iron (ore 2), copper (ore 3),
   silver (ore 6), gold (ore 12); quartz (gems 1), amethyst (gems 2), emerald (gems 5); gas pocket
   (hazard). Colours in data (coal near-black, iron rust, copper orange, silver pale, gold yellow, gems
   their colours, gas a sickly yellow-green). Generalize rock features with depth windows
   (`from_depth_m`, `to_depth_m`) and a richness scale, so richer ores appear deeper: coal and iron
   everywhere, copper from about 60 m, amethyst from 120 m, silver from 180 m, emerald from 300 m,
   gold from 360 m. Precious deposits sit in harder shells (more power, heat, noise to reach).
   Density target: 8 to 14 visible deposits within the steerable band per segment; driving straight
   down yields about 15 to 25 ore value, a greedy weaving path 60 to 150 at mid depth.
3. **Gas pockets.** Cutting one starts a fire in the drill room (level about 0.3) and a noise burst.
4. **Mining events for the view.** Emit `mined` events batched per yield flush, one per material:
   `{"material": id, "res": "ore"|"gems", "amount": n, "x_m": x, "y_m": y}` (positions at the crown).
   Keep event volume small (no per-cell events). `segment_done` should include per-material totals.
5. **Survey readings on the map ("scanning planets").** Each map node gets a survey of the rock on
   the segment that leads to it: a richness tier and flags (ore types, gems, gas, water), derived
   deterministically from the map seed and visible when the node is inside scanner range. Add a node
   type `deposit` (a known rich seam: the segment to it uses a higher richness and more gas/water).
   New node weights, mining-first: about deposit 25, event 25, cavern 15, store 12, hazard 8, fight 15;
   `min_fights_per_path` 1 (plus the gate fight); trading posts guaranteed twice on every path (one in
   rows 2 to 4, one in rows 6 to 8). Expose the survey in the node dictionary for the view.
6. **Ore buys gear, gems buy supplies and people.** Store stock: system upgrades and new gear priced in
   ore; coolant, cells, bits, charges, crew and the lance in gems. New gear (data-driven):
   drill heads in tiers (tungsten: cut speed x1.25, wear x0.6; diamond: speed x1.5, wear x0.35, hard
   rock costs half as much), hull plating (+5 max hull and +5 hull), better pumps (x2 pump rate).
   Prices so a balanced bot can afford 3 to 5 gear purchases a run. Hull repair stays 2 ore a point.
7. **Retune per metre.** Pursuer `rows_per_s` and `rows_per_noise` so pressure per row stays about the
   same as now; bit wear per metre so a bit lasts about 2 to 3 segments; coolant use per segment so a
   run that buys coolant once or twice is fine. Cells: still 1 per segment.
8. **Bots.** Steering goes for value (value per metre of detour within scanner range, avoiding gas and
   water unless greedy); node choice weighs surveys; store purchases buy gear. Keep the three
   policies distinct (cautious, balanced, greedy).

## Proof
- Tests: depth windows, yields are exact integers (conservation), gas pocket fire, survey determinism,
  store currency per line, each gear effect, map guarantees (stores, fights).
- `python tools/check.py` prints `check: ok`; `python tools/determinism.py` matches.
- Balance: `python tools/balance.py --full --runs 300 --procs 6 --pack` (or the closest working flags);
  report per policy: win rate (aim near the D021/D022 band, 12 to 25%), median run time (aim 15 to 25
  minutes of sim time), ore and gems gained and spent, gear bought, causes of death. Save the headline
  report to docs/research/m1-evidence/balance_m1b_dig.md.
- Log design choices in docs/DECISIONS.md as D025 onward (choice, why, how to revert).

## Limits
- No windowed Godot runs (headless only). At most 6 balance processes, below-normal priority.
- Strict typing, files under about 400 lines (split if needed), no em dashes, never sort StringNames,
  randomness only from `sim.rng.get_stream(...)`. Commit `.uid` files. Explicit `git add` paths.
- Commit on your branch. Do not merge, push or touch main.

## Report (under 350 words)
What changed per item, new data ids and event shapes (the view agent needs them), balance headline,
check and determinism lines, open problems, your branch name.
