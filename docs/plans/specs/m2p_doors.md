# Spec m2p_doors: door control and purging in the sim (parity round 2)

Parity workstream P3, round 2 (PLAN.md section 10, D056, D080). Builder: `builder-opus` (hazard rules
with exact heat conservation), in its own worktree off the branch `claude/blissful-neumann-c52d9b`.
Sim only: the click-on-a-door view comes in a later round (the view files are being split on main).

## Firewall (read first)
Work from this spec and the ledger rows it names in `docs/research/behavior-ledger.md` only. Do not
open `docs/research/ftl-*.md`, `research_private/`, or any page about another game. If a row is unclear,
say so in your report; do not look it up.

## Rows this round closes
L-DOR-01 (sim part: everything except the view toggle and its real-input self-test) and L-DOR-02.
Not this round: L-DOR-03 (pressure doors, needs the store round's gear changes) and L-DOR-F1 (view).

## Files you own (touch nothing else)
- `game/sim/hazards/hazard_sim.gd` (fire paths through closed links and walls, the purge term, purge
  state in its `state()`), `game/sim/core/sim.gd` (only the existing core `door` command and a new core
  `purge` command next to it), `game/sim/ship/link.gd` if a field is needed
- `game/data/tuning/hazards.json` (new keys), `game/tests/test_data.gd` (its tuning-keys list only)
- new `game/data/scenarios/ledger_doors.json`, `game/data/scenarios/ledger_purge.json`
- new `game/tests/test_ledger_doors.gd`; existing tests your change breaks (`test_fire.gd`,
  `test_heat.gd`, `test_systems.gd`, `test_determinism.gd`): update only what the new rules change
- `docs/research/behavior-ledger.md`: only the Status lines of L-DOR-01 and L-DOR-02.

**Do not touch** (another session is editing them on main): `game/sim/drill/*`,
`game/sim/run/run_state.gd`, `game/sim/ship/ship_world.gd`, `game/sim/ship/ship.gd`, `game/sim/systems/*`, `game/bots/**`,
`game/data/tuning/drill.json`, everything under `game/view/`, `tools/balance*.py`. Another builder is
working at the same time on `game/sim/events/*`, `game/sim/combat/combat_loot.gd`,
`game/sim/combat/combat_sim.gd`, `game/sim/run/gear.gd`, `game/sim/data/data_db.gd` and the store,
systems, gear, weapons and event data: do not touch those either. Reading anything is fine.

## Hard rules (CLAUDE.md)
Sim rules in `game/sim` only; every change through a command; randomness only from named streams;
heat in exact integer joules moved in plus/minus pairs (the conservation tests must still assert
equality); strict typing; no em dash in any text. Launch Godot only through `tools/`. Stage explicit
paths; never `git add -A`.

## What to build

### 1. Door commands (L-DOR-01)
- A bare core command already exists: `Sim.CORE_COMMANDS` has `"door"` and `Sim._apply` sets
  `l.open` for `{"type": "door", "link", "open"}` with no checks. Keep it a core command (do not
  register it in a module: the sim refuses a command declared twice) and give it rules: refused with
  a reason (`bad_command` {"type": "door", "why"}) for no such link or a link already in that state;
  emits `"door"` {"link", "open"} on a change. Like today, it applies in any phase: pause is the view
  not calling `step()`, and commands pushed while paused apply on the next step, so it works paused
  and in a dossier (do not copy `world_running()` from `systems_douse.gd`).
- Crew keep pathing through closed links (they already do: `NavGraph` ignores `open`; keep it so, and
  add a test that a crew member crosses a closed door while the door stays closed for hazards).
- Fire through a closed link: `fire.spread_closed_factor` (new key, start 0.4) times that link's own
  open factor (doors 1, hatches `spread_up_factor` or `spread_down_factor`), replacing today's use of
  `spread_wall_factor` for a closed link.
- The wall path: two rooms joined by a link no longer also spread fire through their shared wall
  (`Ship.walls` still carries heat between them; only the fire adjacency for that pair is dropped).
  Rooms that touch without a link keep the wall path at `spread_wall_factor`.
- Target check (the row): closed rate / open rate for the same link in 0.30 to 0.50.

### 2. Purge (L-DOR-02, D080)
- A new core command `{"type": "purge", "room": <room id>, "open": true | false}` next to `door` in
  `sim.gd`, same validity, handing the state to `HazardSim`. Emits
  `"purge"` {"room", "open"}. Purge state per room is held by `HazardSim` (for example a
  `PackedByteArray`) and included in `HazardSim.state()` so the world hash covers it.
- While a room's purge is open:
  - Its fire falls by `fire.purge_out_per_s` (start about 0.25, net of growth; tune to the band),
    reduced by `fire.purge_neighbour_factor` (start 0.5) while any room linked to it burns, and never
    grows. A fire cannot start there (autoignition, a hit or strike, spread from a neighbour).
  - Rock heat pours in: add `heat.purge_kw_per_k` (a conductance in kW per kelvin, start about 3.3:
    the audit's integration puts 10 to 20 s at about 2.4 to 4.5 depending on the room and its doors;
    tune) times (`ship.rock_temp_c` minus the room's temperature) to that room's exchange with the
    rock, exactly like the existing hull term, so the joules stay exact. When the rock is cooler than
    the room, the purge cools it the same way. Simplest exact form: add the purge conductance to the
    room's `hull_k` before `q_rock` is computed, so the one rounded `q_rock` is booked as today.
  - While a room is purged, hold the spread counters into it at zero, so a neighbour cannot pre-charge
    it and ignite it the instant the purge closes. A fire put out by a purge emits `"fire_out"` with
    `"by": "purge"`.
- Bands to meet in scenarios (`ledger_purge.json`, one 4 x 3 m room at design temperature, fire at
  1.0; set `sim.ship.rock_temp_c` directly in the test, because a scenario keeps the ship's own
  42 C and nothing in a scenario sets it from a layer): out in 3 to 6 s alone; 6 to 12 s with a burning linked neighbour; at a rock temperature 8 C
  above `crew.heat_safe_c` (56 C with today's 48 C) the purged room reaches 48 C in 10 to 20 s with
  the coolant system at its normal two bars, for every room of the light drill with its doors open and
  with them closed; with the rock at 46 C the room never reaches 48 C. "Linked neighbour" means a room
  joined by a door or hatch (`ship.links`, open or closed), not merely by a wall.
  State the final tuning values in your report.

## Tests (each closes its row only with the wrong value failing)
- `game/tests/test_ledger_doors.gd`: `test_l_dor_01` (closed/open ratio in band; no parallel wall path
  past a door; crew cross a closed door; the command refuses bad links; it works paused; a replay of a
  door command gives the same hash) and `test_l_dor_02` (the three purge bands, energy conservation
  equality, no fire start or spread into a purged room).
- Each test checks the row's band, then repeats the check with the row's Wrong value applied (an
  in-memory override of the tuning, never a file edit) and asserts the check now FAILS: closed factor
  1.0 for L-DOR-01; `purge_out_per_s` 0 for the first clause of L-DOR-02 and `purge_kw_per_k` 0 for
  its heat clause. Write each band check as a function returning pass or fail, used for both.

## Commands that must pass
`python tools/check.py` prints `check: ok` (full run, not `--no-import`); `python tools/determinism.py`
passes (report the new hash; it is information only). No windowed runs are needed for this round.

## Done looks like
Both rows pass with their wrong values failing, `check: ok`, the ledger Status of L-DOR-01 set to
`passing (sim; view pending)` and L-DOR-02 to `passing`. Commit on your branch with explicit paths,
messages without em dashes, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
Do not push or merge.

## Report (short)
Measured values for every band, final tuning values, tests changed, the new determinism hash, your
branch and final commit, and anything you could not do and why.
