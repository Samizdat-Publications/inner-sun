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
| `dialog` | frozen | Encounter (event pages) | the event ends (to idle, combat or death) |
| `store` | frozen | Encounter (store) | `leave` |
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
