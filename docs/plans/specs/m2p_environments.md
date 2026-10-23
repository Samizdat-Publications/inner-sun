# Spec m2p_environments: node environments (parity round 5)

Parity workstream P3, round 5 (PLAN.md section 10, D056). Builder: `builder-opus`, in its own
worktree off `claude/blissful-neumann-c52d9b` (which contains main's file split). Sim and data only;
the map icon, the blind scanner and the hidden rival rooms are drawn in a later view round.

## Firewall (read first)
Work from this spec and the ledger rows it names in `docs/research/behavior-ledger.md` only. Do not
open `docs/research/ftl-*.md`, `research_private/`, or any page about another game.

## Rows this round closes
L-ENV-01 and L-ENV-02 (sim parts: for L-ENV-01 "shown on the map" means the node data the map view
reads carries the environment; set its Status to `passing (sim; view pending)`).

## Lead's math check (the Gemini audit was skipped: its credits are used up, 2026-10-22)
The crust map has 14 rows of 2 or 3 nodes with fight weight 7 and hazard weight 9 of 93, plus
`min_fights_per_path` 2 forced fights: roughly 4 to 7 fight and hazard nodes a map. A per-node chance
of 0.27 gives 20 to 35% over 1,000 maps with a wide margin (the spread of the mean over 1,000 maps is
well under a percentage point). Rockfall every 8 to 15 s: in a fight of 30 to 90 s that is 2 to 10
falls per ship, about one bracing layer's recharge (6 s, 5.2 manned); in a segment of about 80 s,
5 to 10 falls, which the drill's own fault-rock rockfalls already show the hull can take only with
bracing. Magma +20 to 35 C: at row 1 (rock about 42 C) that is 62 to 77 C, above crew-harm heat
(48 C), so coolant must work; at row 13 (about 66 C) up to about 100 C, the autoignition threshold,
so magma also starts fires deep down as the row says. Pursuer x0.5 to x0.75 in magnetite.

## Files you own (touch nothing else)
- new `game/sim/run/environments.gd` (static: definitions, lint, the effect keys below),
  `game/sim/run/map_gen.gd` (assign environments), `game/sim/run/run_state.gd` and
  `game/sim/run/run_map_moves.gd` (which environment is in force; the pursuer factor; the scanner
  rows), `game/sim/run/survey.gd` if the blind rule lives there
- `game/sim/drill/drill_sim.gd` (rock heat), `game/sim/drill/drill_verbs.gd` (rockfalls on a rhythm
  while a rockfall seam is in force), `game/sim/combat/combat_sim.gd` and
  `game/sim/combat/combat_hits.gd` (rockfall hits on both ships, fire chance, rock heat for both
  ships), `game/sim/hazards/hazard_sim.gd` (autoignition chance), `game/sim/run/run_state.gd`'s
  strike fire chance
- `game/sim/data/data_db.gd` (register the `environments` table and its lint)
- data: new `game/data/environments/*.json` (four files), `game/data/layers/crust.json` (an
  `environments` block), tuning keys if needed, `game/tests/test_data.gd` (tuning-keys list only)
- new `game/data/scenarios/ledger_env_*.json`, new `game/tests/test_ledger_env.gd`; existing tests
  your change breaks (map, run, drill, combat, determinism): update only what the rules change
- `docs/research/behavior-ledger.md`: only the Status lines of the two rows.
Another builder is changing `game/bots/**`, `game/tools/full_run_stats.gd`, `tools/balance*.py` and
`game/sim/events/store.gd` at the same time: do not touch those. Do not touch `game/view/**`.

## Hard rules (CLAUDE.md)
Sim only in `game/sim`; randomness only from named streams; strict typing; content is data, checked
by the lint; exact integer conservation; no em dash in any text. Launch Godot only through `tools/`.
Stage explicit paths; never `git add -A`.

## What to build
1. **Data.** `game/data/environments/<id>.json`: `id`, `name`, `blurb` (one short line in the game's
   voice, our own words), `weight`, optional `from_row`, and `effects` with these keys (absent = no
   effect): `rockfall_every_s` [lo, hi], `rock_temp_add_c`, `fire_chance_x`, `pursuer_x`,
   `scanner_blind` (true). Four files, starting values: `rockfall_seam` (rockfall 8 to 15 s),
   `magma_heat` (rock +25 C, fire chance x1.3), `magnetite` (scanner blind, pursuer x0.6, from row 3),
   `gas_seam` (fire chance x2.0, from row 2). Lint: known keys, bands as in L-ENV-02, ids unique.
2. **Map.** The layer's `environments` block: `{"chance": 0.27, "node_types": ["fight", "hazard"]}`.
   `MapGen` gives each fight or hazard node an `env` (an environment id or "") from its OWN stream
   ("map/env"), drawn after the map is complete, so every map stays exactly the same as before apart
   from the new field. Never on the start, a store or the gate.
3. **In force.** `RunState.env_id` (and the definition): the target node's environment while the ship
   drills toward it, then the current node's while it is there (events, a fight, a store never has
   one); "" otherwise. Read by modules through `RunState.env_x(key, default)`. Include `env_id` in
   `RunState.state()`.
4. **Effects, for both ships alike:**
   - `rock_temp_add_c`: added to the rock temperature wherever it is set (`DrillSim` while drilling;
     the run and combat code for the player and the rival in a fight).
   - `fire_chance_x`: multiplies every fire chance: weapon hit fire chances (`CombatHits`), the
     pursuer strike's fire chance, autoignition (`HazardSim`), clamped to at most 1.
   - `rockfall_every_s`: while drilling, a rockfall on a rhythm through DrillVerbs' existing rockfall
     (warning, then the hit, bracing soaks it), next interval drawn from the stream "env/rockfall";
     in a fight, the same rhythm per ship ("env/rockfall" per side), each a light hit on a random room
     of that ship (`combat.rockfall_hull_pts`-like: reuse the drill's `rockfall_hull_pts` and
     `rockfall_sys_bars`), soaked by a bracing layer like a shot.
   - `pursuer_x`: multiplies the pursuer's advance per tick while in force.
   - `scanner_blind`: while in force, no node beyond the current row counts as revealed
     (`RunState.is_revealed`) and the survey of the next nodes is not shown; the view hides the
     rival's rooms (later round). Store the flag where the view can read it.
   - Events: emit `"env_entered"` {"env", "node"} and `"env_left"` {"env"}.

## Tests (each closes its row only with the wrong value failing)
- `test_l_env_01`: over 1,000 seeded maps, 20 to 35% of fight and hazard nodes carry one, none on the
  start, a store or the gate; a map with environments equals the same seed's map without the `env`
  field node for node. Then, per environment, a scenario that shows the effect on the player AND on
  the rival in a fight. Wrong value: an environment applied only to the player must fail (write that
  variant as an in-test override of the "both sides" switch, or as a wrong rule inside the test).
- `test_l_env_02`: each environment's strength in its band (rockfall interval mean 8 to 15 s, magma
  +20 to 35 C, magnetite pursuer x0.5 to 0.75 and no reveal, gas x1.5 to 2.5), and each strength at
  zero (or 1.0 for a multiplier) makes its scenario fail.
- Determinism: same seed, same hash; the new streams do not move any existing stream.

## Commands that must pass
`python tools/check.py` prints `check: ok` (full run with import; run it first); `python
tools/determinism.py` passes (report the new hash). No other windowed runs.

## Report (short)
Measured values for every band, final values, tests changed, the new determinism hash, branch and
final commit, anything you could not do. Commit with explicit paths, messages without em dashes,
ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not push or merge.
