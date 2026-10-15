# Spec: M1 step 3, a thin full run (sim side)

For a builder-opus agent, after the drilling module (step 1) and systems (step 2) are merged.
Read CLAUDE.md, docs/ARCHITECTURE.md, game/sim/core/sim.gd, game/sim/run/run_state.gd,
game/sim/drill/drill_sim.gd, game/sim/systems/systems.gd, docs/STYLE_GUIDE.md (event format).

## Goal
A run plays from the first node to death or the layer gate: a vertical node map, travel between
nodes as drilling segments, a pursuer that advances with time and noise, arrival that hands the node
to the right module, a run summary for the death screen, a saved profile with the codex, and a run
record (seed, options, command log, summary) so any run can be replayed exactly.

## Files
Owns: game/sim/run/** (run_state.gd, map_gen.gd, pursuer.gd or inside run_state, full_run.gd),
game/data/layers/crust.json, game/bots/run_bot.gd, game/tests/test_run*.gd, test_map*.gd. Allowed small edits: game/sim/drill/drill_sim.gd (arrival calls run.arrive instead
of setting idle; a speed_scale field), game/sim/events/encounter.gd and
game/sim/combat/combat_sim.gd (only stub methods start_event, open_store, start_fight that return
to idle, documented as stubs), game/bots/bot.gd (register "run"), game/sim/data/data_db.gd
(KNOWN_BOTS).

## Map
- Layer data `game/data/layers/crust.json`: rows (10 total: row 0 start, rows 1 to 8 with 2 or 3
  nodes, row 9 the gate), node type weights (event 40, fight 20, cavern 15, hazard 10, store 15),
  store guarantee (at least one store in rows 3 to 5, never two stores in a row on one path), at
  least two fights on every path, row depth in meters (36), lateral spread (node x from -12 to +12
  m), rock table id, rock temperature base and gradient, enemy pool, gate enemy id, pursuer tuning,
  scanner base range.
- Generation from stream "map" only. Nodes `{id, row, col, x_m, type, links (next-row node ids)}`.
  Edges like Slay the Spire: every node has at least one way in and one way out, every node is
  reachable from the start and reaches the gate, edges never cross (sort by x, connect to the
  nearest, then fill gaps).
- Revealed: a node's type is visible when its row is within scanner range of the current row:
  range = layer scanner base (1) + helm effective bars (Systems) + permanent reveal bonus from events
  (`reveal(rows)`). Unrevealed nodes show as unknown.

## Travel
- Command `{"type": "choose_node", "node": id}`: only in phase `idle`, only a node linked from the
  current node. Spends one power cell. With no cells left the segment runs at half speed
  (`drill.speed_scale = 0.5`, "running on reserve"). Starts `drill.begin_segment(sim, "<from>-<to>",
  row depth, to.x_m - from.x_m)`.
- On arrival the drill calls `run.arrive(sim)`: the node becomes current and visited, then by type:
  event, cavern, hazard -> `encounter.start_event(sim, node)`; store -> `encounter.open_store(sim,
  node)`; fight -> `combat.start_fight(sim, enemy id from the layer pool)`; gate ->
  `combat.start_fight(sim, gate enemy, boss)`. Until those modules exist, the stubs emit an event and
  return to idle; the gate stub ends the run as won.

## Pursuer
- `pursuer_row` (float) starts at the layer's start row (about -1.5). Every tick of a world phase it
  advances by rate * dt plus noise_rows_per_unit * (new drill noise since last tick, from
  `drill.noise_total`). Events can move it (`pursuer(rows)`).
- Nodes in rows at or below floor(pursuer_row) that were not visited become overtaken (emit
  "overtaken"). Arriving at an overtaken node: its content is gone and the pursuer strikes instead.
- Caught: when pursuer_row reaches the ship's row, it strikes every N seconds (hull loss, a breach
  in a random room, sometimes a fire): emit "pursuer_strike". It never passes the ship (cap just
  below the ship's row plus one).
- Starting tuning: rate about 1 row per 70 s, noise adds about 0.2 to 0.4 rows per segment at 2 to
  4 drill bars. The balance step tunes it with bots.

## End and summary
- Death (hull 0, all crew dead, drill room flooded) and the gate win end the run (RunState.end_run).
- `run.summary()` for the death screen and balance: result, cause, rows reached, depth, time in
  seconds, resources gained per type (from resource events), fights won, codex learned (ids), crew
  lost, seed, ship.

## Profile and records (DONE by the lead: game/meta/profile.gd, game/meta/run_record.gd)
Use them: `Profile.load_from(dir).run_options()` gives the options for a new run;
`profile.merge_run(summary, run.learned)` and `save()` after it ends; `RunRecord.save(dir, sim,
summary, stamp)` writes the replayable record. Tests in game/tests/test_profile.gd. Make sure
`run.summary()` has the keys merge_run reads: result, cause, depth_m.

## Driver and bot
- `FullRun` (game/sim/run/full_run.gd): like ScenarioRun for whole runs: makes the Sim in run mode,
  steps a bot, `play_to_end()` with a hard tick cap (a stuck run ends as "stuck"), `summary()`.
- `RunBot` ("run"): picks the next node by a simple policy (prefer store when low on hull, fights
  when healthy, avoid overtaken nodes), drives drilling like DrillBot (reuse it), sets drill power
  to 2 bars, ends dialogs with the first available option and leaves stores.

## Tests
Map rules (connectivity, no crossings, store guarantee, gate last, deterministic per seed); travel
(only linked nodes, spends a cell, half speed without cells); the pursuer (time and noise, overtaken,
strikes when caught, never passes); a full run with RunBot finishes (dead or won) under the cap and
its replay matches; summary fields; profile round trip and corrupt-file fallback in a folder under
harness/out; run record replay.
