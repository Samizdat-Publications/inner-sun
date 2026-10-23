# Spec: short scanner, capped steering, richer rock (D060)

Read `docs/DECISIONS.md` D060 and Stewart's build 6 notes (top of `docs/STEWART_FEEDBACK.md`).

## Goal
Stop the full-width hold-depth sweep: the scanner shows only near the drill head and the heading is
capped at 45 degrees until the helm is upgraded to 3 installed bars; ore is about 20% richer.

## Build
1. Data (`game/data/tuning/drill.json`, linted keys, the tuning-keys list in `game/tests/test_data.gd`):
   - `max_heading_deg_by_helm`: installed helm bars to cap, for example {"0": 45, "2": 45, "3": 90}
     (an object or an array indexed by bars; pick one, keep it data, lint it). The highest key at or
     below the helm's `sys_max` wins. Keep reading the single `max_heading_deg` as the fallback if the
     table is absent.
   - `scanner_range_m_by_helm`: same shape, about {"0": 10, "3": 16, "4": 22}.
   - An ore richness factor of 1.2 applied where ore and gem deposits are generated (find the right
     lever in the drill materials or layer code; a layer key such as `ore_richness_mult` in
     `game/data/layers/crust.json` is fine). Water, gas and fault rock are unchanged.
2. Sim (`game/sim/drill/`): the steer clamp uses the cap for the player's helm `sys_max` when the
   command applies. Expose read-only `max_heading_deg(sim)` and `scanner_range_m(sim)` for the view and
   bots. Deterministic; no frame time; if you add a field, add it to `state()`.
3. Bots (`game/bots/`): anything that steers to +-90 (hold depth, side cutting, lanes, miner and blast
   approaches) uses `max_heading_deg(sim)`. Bots may still read the whole grid.
4. View (`game/view/hud/scanner_panel.gd`, `scanner_draw.gd`, and the scanner extras script if one
   exists): rock, ore glints, water, gas, faults and structures are drawn only inside a circle of
   `scanner_range_m` around the drill head; outside it, dim static noise and a range ring; a small
   "RANGE 10 m" label. Clicks outside the range still steer (direction only); a blast or miner click
   outside it is refused with the existing reasons. The help page gets one line: "The scanner sees
   about 10 m; the helm upgrade (scanner coils) extends it to 16 m and unlocks hold depth (90
   degrees)." The heading readout shows the cap ("HDG +45 MAX") when at it.
5. Store text (`game/data/stores/crust_trader.json`, the helm upgrade line's text only): "Scanner coils
   for the helm: a longer scanner and hold depth." No other store change (another workstream owns
   stores).

## Tests (each with a wrong value that must fail it)
- The cap: with helm at 2 bars a steer to 90 ends at 45; after the helm upgrade to 3 bars it reaches 90.
- The range: `scanner_range_m` is 10 at 2 bars and 16 at 3.
- Richness: over a fixed set of seeds, ore and gem units in generated segments rise 15 to 25%.
- Bots: a policy bot segment never sets a heading beyond the cap (scan the command log).
- The data lint accepts the new keys and rejects a missing or non-numeric entry.

## Must pass
`python tools/check.py` prints `check: ok`; `python tools/determinism.py` ok (the hash will change:
report the new one); `python tools/shots.py --scenario miner_demo --names t5,t20 --out
harness/out/shots_d060`, and look at the scanner in both stills yourself (one windowed batch only).
Do not run balance (the lead does). Never export or touch `builds/`.

## Owned files
`game/sim/drill/**`, `game/bots/**`, `game/data/tuning/drill.json`, `game/data/layers/crust.json`,
the helm line of `game/data/stores/crust_trader.json`, `game/view/hud/scanner_*.gd`, the help page
script, tests you add, `game/tests/test_data.gd` (tuning-keys list). Nothing else.

## Report (under 250 words)
What changed per file, the cap and range tables, the measured richness change, test names, the new
determinism hash, what the stills show.
