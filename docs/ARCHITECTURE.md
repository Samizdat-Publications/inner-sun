# Architecture (M1)

The reference every builder spec points to. Hard rules live in `CLAUDE.md`; this file says where
things go and how the pieces talk. Change it when the code changes.

## The sim is the whole run

`Sim` (`game/sim/core/sim.gd`) is the root of determinism: one tick counter, one command log, one
set of seeded streams, one state hash, for an entire run (map, drilling, fights, events, death).
A replay is the seed, the run options (ship, mode, the codex the profile already knew) and the
command log.

```
Sim
  tick, run_seed, db, rng (RngStreams), events, command_log
  player: ShipWorld              the player's ship, hazards, crew AI and systems
  enemy: ShipWorld               null outside combat
  run: RunState                  phase, resources, depth, map, pursuer, discoveries
  modules: Array[SimModule]      run, systems, drill, combat, encounter (fixed order)
  ship, hazards, crew_ai         aliases of player.* (old code and the view use them)
```

### ShipWorld (`game/sim/ship/ship_world.gd`)
A ship plus everything that runs on it: `ship` (Ship), `hazards` (HazardSim), `crew_ai` (CrewAI),
`side` ("player" or "enemy"). HazardSim and CrewAI take the ShipWorld they act on, never
`sim.ship`, so the same code runs the enemy ship. Random streams are per side:
`world.stream("fire")` is `"fire"` for the player and `"enemy/fire"` for the enemy. Events from the
enemy side carry `"side": "enemy"`.

### Systems live on rooms
One system per room (`Room.system`). The system state sits on the room so crew AI, hazards, combat
and the view all read one place:
- `sys_max: int` bars of capacity (from ship data, upgradeable),
- `sys_damage: float` bars lost (combat hits, fire); repaired by crew,
- `sys_power: int` bars allocated by the player or AI (`power` command),
- `effective_bars()` = min(power, max - ceil(damage)), and 0 while the room is hotter than the
  system's fail temperature.
The `Systems` module owns the rules (reactor output, allocation limits, damage from fire and heat,
what each system does). Other modules only read `effective_bars()`.

Systems in M1 (rooms of `light_drill`): `helm` (bridge: evasion in combat, needs a crew member at
the station; also the seismic scanner range), `bracing` (shield layers), `reactor` (bars to split),
`weapons`, `drill`, `coolant` (cooling and pumps).

### Phases
`run.phase` decides what steps each tick. `Sim.step()` always advances the tick and applies queued
commands, whatever the phase.

| Phase | World (crew, systems, hazards) | Also runs | Ends when |
|---|---|---|---|
| `scenario` | yes | timeline (ScenarioRun) | the scenario ends (tests, captures, M0 drills) |
| `idle` | yes | pursuer | `choose_node` starts a segment |
| `drill` | yes | DrillSim, pursuer | the ship reaches the node: arrival |
| `dialog` | frozen | Encounter (event pages) | the event ends (to idle, combat or death; to drill when a structure opened it mid-segment) |
| `store` | frozen | Encounter (store) | `leave` (to idle; to drill when a structure opened it mid-segment) |
| `combat` | yes, both ships | CombatSim, enemy AI, pursuer | a ship dies |
| `dead`, `won` | frozen | nothing | terminal |

Pause is the view not calling `step()`. Commands made while paused are applied on the next step,
so replays stay exact.

### Modules and commands
Every module extends `SimModule` (`game/sim/core/sim_module.gd`):
- `commands() -> PackedStringArray`: the command types it handles,
- `apply(sim, cmd)`: apply one command,
- `step(sim)`: called every tick, in module order; it checks the phase itself,
- `state() -> Array`: everything it owns, in a fixed order, for the state hash.
`Sim._apply` dispatches a command to the module that declared its type (crew and hazard commands
stay in Sim). Builders add behavior in their module file; they never edit `sim.gd` dispatch.

Step order per tick: commands, then modules in order (run, systems, drill, combat, encounter), then
the player world (crew think at 4 Hz, crew move, hazards at 10 Hz), then the enemy world the same
way when it exists.

### Dig verbs (M1c)
Every powered system has a job while drilling. Commands, events and read-only fields:
- Steering (DrillSim): `{"type": "steer", "angle": deg}` up to +-`drill.max_heading_deg` (90 = hold
  depth). Turn rate `drill.turn_deg_s * Systems.steer_rate_scale`; the sideways motion times
  `Systems.side_cut_scale` (both from manned helm bars). Read `drill.side_scale`, `drill.at_wall`
  (pressed against the segment wall past `drill.at_wall_heading_deg`), `drill.steep_ticks`.
- Fault rock (DrillVerbs, `drill.verbs`): unstable cells cut add to `verbs.strain`; at
  `drill.rockfall_strain_cells` a rockfall is scheduled (`"rockfall_warn" {"in_s"}`,
  `verbs.rockfall_ticks`), then `"rockfall" {"absorbed", "room", "hull"}`: a bracing layer soaks it,
  else hull and a top-deck room take damage. Death cause `"rockfall"`.
- Blast (DrillVerbs): `{"type": "blast", "x_m", "y_m"}` (segment meters) while drilling, with the
  charge launcher powered and a charge. `drill.blast_ready(sim)` says why not; `verbs.aim_ok(d, p)`
  checks the point. Events `"blast_fired" {"x_m", "y_m", "from_x_m", "from_y_m", "fuse_s"}` then
  `"blast" {"x_m", "y_m", "cells", "yield", "ore", "gems", "drained", "burned"}`. Read
  `verbs.blast_pending`, `verbs.blast_point`, `verbs.blast_from`, `verbs.blast_cooldown_left_s`.
- Douse (Systems, SystemsDouse): `{"type": "douse", "room": id}`; `systems.douse_ready(sim, room)`
  says why not; `"doused" {"room", "fire_before", "fire_after", "heat_j"}`; heat leaves through
  `hazards.add_heat` so the books stay exact. Read `systems.douse_cooldown_ticks`.

### Buried structures (M1c round C)
Data: `game/data/structures/<id>.json` (`id`, `name`, `label`, `codex`, `legend` {char: material id
or {"material", "from_depth_m", "else"}}, `stamp` rows of 0.5 m cells, " " keeps the rock, `mirror`,
`loot` [{"weight", "res", "amount"}], optional `loot_by_material`, `event_chance`, `trader`,
`trader_chance`), linted by StructureLint (from DrillLint). The rock table lists them
(`structures`: [{"structure", "weight", "from_depth_m", "to_depth_m"}]); the survey rolls at most one
per segment (`survey.structure`, layer `structure_chance`, stream `survey/structure`).
- Placement (StructureStamp, from the segment stream after the features): `drill.structures` holds
  `id`, `label`, `def`, `rect` and `interior` (segment meters), `cell_rect`, `mirrored`;
  `drill.structure_marks` per cell (2 interior: `interior` or `loot` materials, 1 the rest).
- Crates (`loot` materials): the first cut cell opens the connected crate (`drill.burst_marks`) and
  pays one roll from `drill/<segment>/loot` through `run.add`: `"loot" {"structure", "res",
  "amount", "x_m", "y_m"}`. Read `structures.crates_total`, `crates_opened`, `loot_res`.
- Break-in: the first interior cut (footprint or blast): `"structure_entered" {"structure",
  "label"}`, the codex entry learned, then from `drill/<segment>/structure` a trader store or a
  `"kind": "structure"` event mid-segment: `"structure_outcome" {"structure", "outcome", "id"}`.
  The drill stays active and pauses; Encounter returns to `drill`; arrival waits for it.
- `"structure_placed" {"structure", "x_m", "y_m", "w_m", "h_m", "mirror"}` at segment begin;
  `segment_done` carries `structure`, `entered`, `crates`.

### The away miner (M1c round E, D046)
DrillMiner (`game/sim/drill/drill_miner.gd`, `drill.miner`; where it may go and its tunnel:
MinerRoute, `miner_route.gd`). Tuning `miner.*` in `game/data/tuning/miner.json`.
- `{"type": "send_miner", "crew": id, "x_m", "y_m"}` (segment meters) while a segment is drilling
  (run phase `drill`): refused with `"bad_command" {"type": "send_miner", "why"}`, why one of
  `"no_segment"`, `"miner_out"`, `"no_crew"`, `"outside"` (off the grid, above the ship's top edge, in
  its footprint), `"range"` (beyond `miner.range_m` of the drill head). `{"type": "recall_miner"}`
  turns the miner back (`"bad_command"` why `"no_miner"` when none is out). The view's aim check:
  `DrillMiner.target_ok(drill, sim, crew_id, point) -> String` ("" or the why); `DrillMiner.head(d)`.
- Phases (`miner.phase`): `board` (crew job `"sortie"`, the drill keeps going), `exit` (the drill
  parks: `drill.parked`; the crew member is `away`), `dig`, `vein`, `return`, `enter`. Read
  `miner.active`, `crew_id`, `pos` (feet, segment meters), `target`, `haul` (PackedInt32Array by
  `RunState.RESOURCES`), `cells_dug`, `strain`, `rockfall_ticks`, `range_m`, `next_cell`,
  `action_ticks` / `action_total` (progress of the current walk, dig or hatch), `is_out()`.
- Cells the miner digs go through `drill.cut(sim, i, DrillMiner.CUT_MINER)`, the drill's own cut
  path (`take_cell`): mined, chunk changes, structures and crates stay consistent; their yield goes to
  `miner.haul` (a crate's roll too) and is paid with `run.add` only on return.
- Events: `"miner_out" {"crew", "x_m", "y_m"}` (the target, as they climb out), `"miner_hurt"
  {"crew", "cause", "hp" (damage), "left"}`, `"miner_rockfall_warn" {"in_s"}`, `"miner_back" {"crew",
  "haul": {res: n}}` (plus `"called_off": true` when they never left), `"miner_lost" {"crew", "cause",
  "haul"}` with `"crew_died"`. Causes: `miner_gas`, `miner_water`, `miner_rockfall`, `miner_strike`.
  `"loot"` carries `"miner": true` for a crate the miner opened.
- Away crew (`CrewMember.away`): CrewAI skips them, `Systems.is_manned` and HazardSim room harm ignore
  them, `room` stays the drill room. A fight starting while one is out pulls them aboard at once.

### Conservation APIs
Anything that adds or removes heat or water goes through HazardSim so the books balance:
`hazards.add_heat(room, joules)` (positive in, negative out; counted in `energy_in_j` or
`energy_out_j`), `hazards.add_water(room, ml)` (clamped to capacity; returns what moved; counted in
`water_in_ml`). Breaches stay `room.breach_m2`. Resources (ore, gems, coolant, power cells, drill
bits, charges, hull) are integers in `run.resources`, changed only through `run.add(res, amount)`
which emits a `resource` event.

### Content
Every folder under `game/data/` is a table: `db.tables["<folder>"]` maps id to definition
(`db.ships` and `db.scenarios` stay as aliases). Tuning files under `game/data/tuning/` merge into
`db.tune("section.key")`. Each module owns a linter, `static func lint(db, errs)` in
`<module>_lint.gd` next to its code, which `DataDB.lint()` calls; it checks every reference and
rejects em dashes in text.

## View
`game/view/` reads the sim and never changes it. Input becomes commands (`sim.push`). Small canvas
items, at most about 15 lights each. The view for each phase is its own scene node: the cutaway
(ShipView, also used for the enemy), the rock (RockView, chunked textures), the map overlay, the
dossier (events), the store, the HUD, the death and codex screens.

## Profile (meta progression)
`user://profile.json` by default, `--profile-dir=<path>` for bots and tests (all worktrees share
the Godot user folder, so tests must never write bare `user://`). It holds the codex the player
knows, run history and unlocks. The known codex is passed into `Sim` at the start of a run (it
lifts redactions and can unlock event options), so it is part of the replay header.

Research and requisitions (M1c round D). Every run pays out research, a pure function of the run
summary (`game/meta/research.gd`: 2 per map row, 5 per new codex entry, 3 per fight won, 15 for the
gate, 1 per 40 ore). `Profile.merge_run` banks it in `research` (saved; an old file loads as 0).
Research buys requisitions (`game/data/requisitions/*.json`: id, name, blurb, cost, order, effects of
`start_resources`, `max_hull`, `gear`, `crew`), owned ids in `Profile.requisitions` (saved, sorted),
bought with `Profile.buy(id, db)` ("" on success, else the reason). `Profile.run_options()` carries
the owned ids as `"requisitions": [ids]`, so they are in the replay header and the RunRecord options.
`Requisitions.apply` (`game/sim/run/requisitions.gd`) runs once at the end of `Sim._init`, in run
mode only (a scenario ignores them): resources change directly (no resource events, so the summary
counts only what the dive gained), gear goes through `Gear.fit`, extra crew join from the survivors
pool using the `meta/crew` stream. The death screen lists the research block and opens the
requisitions screen (`view/overlay/requisitions_view.gd`) with R.
