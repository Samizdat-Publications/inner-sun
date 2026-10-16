# Spec: M1c round B, dig verbs (every system has a job in the dig)

Part 1 (sim, data, bots, tests) is for a `builder-opus` in its own worktree. Part 2 (the view) is
for a `builder` after part 1 merges; it reads this spec plus part 1's report.

Read first: CLAUDE.md (hard rules: sim purity, one command chain, determinism, exact integer
resources, content is data, strict typing), HANDOFF.md gotchas, docs/ARCHITECTURE.md,
docs/DECISIONS.md D024 to D034, docs/plans/M1c.md, then game/sim/drill/*, game/sim/systems/*,
game/sim/hazards/hazard_sim.gd, game/sim/run/survey.gd and run_state.gd, game/bots/*, the data in
game/data/rock, tuning, layers, weapons, systems. Godot API dump (git-ignored): read it from the main
repo, `C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`.

## Why (Stewart, build 3, D034)
"Right now much of the game is just picking a spot based on the radar and going straight down."
"Giving more power to the drill bit (or helm or something) should allow the drill to move faster
horizontally, such that the player may elect to take from other systems to pivot more quickly to a
vein." "I can't seem to see what [helm and bracing] do." "I want more things to manage so it feels
less on rails." The answer: every powered system has a job while drilling, so each segment is a
power-split puzzle. The reactor never powers everything, so every verb below is paid for by another
system or a consumable.

## Part 1: sim, data, bots, tests (builder-opus)

### Owned files
game/sim/drill/** (split drill_sim.gd: put the new verbs in a new helper such as
`drill_verbs.gd`; drill_sim.gd is already 542 lines), game/sim/systems/**, game/sim/run/survey.gd,
game/sim/run/run_state.gd (summary counters only), game/sim/run/run_lint.gd, game/bots/**,
game/data/rock/**, game/data/tuning/**, game/data/layers/**, game/tests/** (new
`test_dig_verbs.gd`, plus the tuning-keys list in test_data.gd and any test the changes break),
tools/balance.py (report counters only), docs/research/m1-evidence/, docs/ARCHITECTURE.md (the new
commands and events), docs/DECISIONS.md (your entries, D035 onward). NOT game/view/**, not
game/meta/**, not game/data/events, codex, radio, stores, gear, ships (another agent may own them).

### 1. Steering: hold depth and helm-powered side cutting
- `drill.max_heading_deg` 45 -> 90. Heading 90 (or -90) cuts straight sideways: no downward progress
  ("hold depth"), for following a vein.
- Turn rate stays `turn_deg_s * systems.steer_rate_scale(player)`; retune so the helm matters:
  `drill.turn_deg_s` 25 -> 18 and `systems.steer_per_helm_bar` 0.25 -> 0.6 (manned: 18, 29, 40, 50
  deg/s at 0 to 3 helm bars; unmanned 18).
- New Systems effect `side_cut_scale(world) -> float`: `systems.side_cut_base` (0.35) plus
  `systems.side_cut_per_helm_bar` (0.3) times the helm's effective bars when the helm is manned, else
  the base. The sideways component of the drill's motion is multiplied by it; the downward component
  is not. So with the speed `v` from the existing rule (power, gear, bit, hardness of the leading
  band), the motion per second is `(v * sin(h) * side_scale, v * cos(h))`. The leading-band hardness
  weights use the same components (side share `|sin h| * side_scale`, down share `cos h`).
- A ship pressed against the segment wall with the heading past about 80 degrees makes no progress:
  expose a read-only `at_wall: bool` for the view (it will say "steer down"), and make sure the bots
  never sit there.
- Bars: the downward speed at any heading must not change from today for the same power and rock,
  except through the turn rate. Existing drill tests should keep passing or be updated with a reason.

### 2. Fault rock and rockfalls (bracing gets a dig job)
- New material in `data/rock/crust.json`: `fault_rock` ("Fractured shale"), hardness about 0.7 (soft,
  so it is tempting), colour a pale cracked brown (`#857257` or similar), new boolean flag
  `"unstable": true` (DrillMaterials loads it like `water` and `gas`; the lint accepts it).
- Generation: fault zones as wide slanted lenses (width 6 to 14 m, height 2 to 4 m), in a new feature
  group `"faults"` that appears only when the segment's survey says `faults` (like gas and water).
  Survey: a `faults` chance per segment from the layer data (start about 0.35, `per_row` +0.02, so
  most deep segments have some), shown in the survey dictionary the map reads (the view will draw it).
- Strain: every unstable cell cut (by the footprint) adds 1 to `strain`. When strain reaches
  `drill.rockfall_strain` (start 60 cells, about 2.5 m of straight descent through fault rock, less
  when cutting sideways because the side face is taller), a rockfall is scheduled
  `drill.rockfall_warn_s` (1.2 s) later and strain drops by the threshold. Event at scheduling:
  `"rockfall_warn" {"in_s"}`; at impact: `"rockfall" {"absorbed": bool, "room": id or "",
  "hull": n}`.
- Impact: `systems.absorb_hit(sim, sim.player)` first (a bracing layer soaks it, the existing
  "bracing_absorbed" event fires). Otherwise hull loses `drill.rockfall_hull` (1) through `run.add`,
  and one room on the top deck (rooms with the smallest rect y; pick with the stream
  `"drill/rockfall"`) takes `drill.rockfall_sys_damage` (0.5) bars through `systems.damage_room`.
  Rockfalls keep coming at the same rule while the ship stays in fault rock. In scenario mode (no run
  hull), apply the room damage only.
- A run that dies to a rockfall needs a cause for the death screen ("rockfall"); check RunState's
  cause handling.

### 3. Blast: the charge launcher works the rock (weapons get a dig job)
- New DrillSim command `{"type": "blast", "x_m": float, "y_m": float}` (segment meters, a point in
  the rock). Valid only while drilling (phase "drill", segment active) when: the run has at least one
  "charges" (scenario mode: free), the player ship carries a weapon of kind "charge" and
  `systems.weapon_bars(player)` is at least that weapon's `power`, no blast is in flight and
  `drill.blast_cooldown_s` (5 s) has passed since the last one, and the point lies inside the grid,
  outside the ship footprint and within `drill.blast_range_m` (14 m) of the footprint's centre.
  Otherwise emit "bad_command" with a `why` the view can show ("no charges", "power weapons",
  "reloading", "out of range").
- Firing spends one charge at once, emits `"blast_fired" {"x_m", "y_m", "from_x_m", "from_y_m",
  "fuse_s"}` and detonates after `drill.blast_fuse_s` (0.6 s) of world time (deterministic ticks).
- Detonation clears every non-air cell whose centre lies within `drill.blast_radius_m` (1.75 m) of the
  point: counted in `mined`, chunk changes bumped, ore and gems paid exactly through the existing
  yield path (pending yields, one flush, "mined" events at the blast point, not the crown). Water
  pocket cells in the circle drain the whole connected pocket (all its cells become air, marked
  burst, no water enters the ship, nothing counted as lost ship water). Gas pocket cells burn off the
  whole connected pocket (cells become air, marked burst); only when the blast point is within
  `drill.blast_fire_m` (3 m) of the footprint does it ignite the drill room like a gas burst. Noise
  `drill.blast_noise` (start 15) goes to `noise_segment` and `noise_total`. Blasts add no strain.
  Event `"blast" {"x_m", "y_m", "cells", "yield": {material id: units}, "drained": bool,
  "burned": bool}`.
- Expose for the view: `blast_ready() -> String` ("" when a blast may be fired now, else the reason),
  `blast_cooldown_left_s`, `blast_pending: bool` and its point.

### 4. Douse: coolant on a fire (coolant gets an active verb)
- New Systems command `{"type": "douse", "room": id}`: valid in world phases when the player's
  coolant system has at least one effective bar, the room is burning, the run holds at least one
  "coolant" unit (scenario mode: free) and `systems.douse_cooldown_s` (3 s) has passed since the last
  douse. Spends one coolant unit through `run.add`, lowers the room's fire by `systems.douse_fire`
  (0.6, floored at 0) and removes up to `systems.douse_j` (300 kJ) of the room's heat through
  `hazards.add_heat(room, -j)`, never cooling it below the ship's design temperature. Heat books
  must still balance exactly. Event `"doused" {"room", "fire_before", "fire_after"}`.
- Expose `douse_ready(world) -> String` for the view, like blast_ready.

### 5. Bots
- DrillBot: lanes further out are now reachable; steer with the full range when a rich lane is level
  with the crown, never sit at the wall, and keep the three policies distinct. Policy power while
  drilling: greedy (and balanced when detouring) put the helm at full bars; everyone powers bracing
  when fault rock is within about 6 m ahead (cautious steers around fault zones when it can).
- Blast: greedy and balanced blast a pocket or vein in range when the value in the circle is worth it
  (choose a threshold, say about 25 ore-equivalent, gems counting as in the drill bot), keeping the
  charge reserve they already keep for the gate. They also blast a gas pocket on their lane before
  reaching it when they have spare charges. Cautious never blasts for loot.
- Douse: all policies douse a fire above about 0.4 when they hold coolant above their low mark.

### 6. Balance and counters
- Add run summary counters the balance report prints per policy: rockfalls (hit and absorbed),
  blasts, douses, time spent at headings past 60 degrees.
- `python tools/balance.py --full --runs 300 --procs 6 --pack` (about 12 minutes per 1,000 runs).
  Compare with D033 (cautious 10%, greedy 12%, balanced 23% wins; medians 17 to 21 min). Aim: win
  rates in the same band (10 to 30%), medians 16 to 24 min, rockfalls a real cost (hull lost to them
  a few points a run, more for the bot that never braces), blasts paying for themselves for greedy.
  Tune the starting numbers above as needed and log the final ones. Report to
  `docs/research/m1-evidence/balance_m1c_verbs.md`.

### Proof
- `test_dig_verbs.gd`: heading 90 holds depth (bottom edge within a cell over 2 s) and moves
  sideways; side speed ratio manned 2 helm bars vs unmanned matches the tuning; turn rate scales;
  cutting fault cells schedules a rockfall, a bracing layer absorbs it with no hull loss, without a
  layer hull drops by exactly 1 and a top-deck room is damaged; blast preconditions (each `why`);
  a blast clears exactly the cells in the circle, `mined` and resources rise by exactly the yields,
  one charge is spent, noise rises; a gas pocket burned off far from the ship lights no fire, near it
  the drill room burns; a water pocket drains and no ship water appears; douse needs a coolant bar
  and a unit, lowers fire, spends one unit, heat books balance; all of it deterministic (same seed and
  commands, same hash).
- `python tools/check.py` prints `check: ok`; `python tools/determinism.py` matches.

### Limits
- No windowed Godot runs (headless only). At most 6 balance processes, below-normal priority.
- Strict typing, files under about 400 lines (split if needed), no em dashes, never sort StringNames,
  randomness only from `sim.rng.get_stream(...)`, integers for resources and joules. New tuning keys
  go in the module's TUNING_KEYS and test_data's list. Commit `.uid` files. Explicit `git add` paths.
- Commit on your branch. Do not merge, push or touch main.

### Report (under 400 words)
What changed per item; the exact commands, events and read-only fields the view will use (names and
shapes); the final tuning numbers; the balance headline per policy with the new counters; check and
determinism lines; open problems; your branch name.

## Part 2: the view (builder, after part 1 merges; details may follow part 1's report)
Owned: game/view/** and the view tests. Hand-test the result as in HANDOFF ("Hands-on testing").
- Steering keys (main.gd): A and D step the target heading by 15 degrees per press and repeat while
  held (about 8 steps a second); S or the down arrow sets straight down; Shift plus A or D sets hold
  depth (-90 or 90). The scanner click steers toward the point as now, over the full range.
- Scanner: the heading line over the full range, a HOLD DEPTH readout past 80 degrees, "AT THE WALL:
  steer down (S)" when `at_wall`, fault rock as hatched pale brown, the blast range ring and target
  circle while a blast is armed, the blast cooldown.
- Blast: the charge launcher's weapon card works while drilling ("BLAST: 1 charge", F2 arms it, Esc
  disarms); with it armed a left click on the rock in the world view or on the scanner pushes
  "blast"; the charge flies from the crown, then a flash, a light, debris and a camera kick; the
  reason from `blast_ready()` shows on the card when it cannot fire.
- Fault rock and rockfalls: a cracked texture for fault rock in the rock view; on "rockfall_warn" dust
  and cracks above the top deck and a "ROCKFALL" chip; on "rockfall" falling debris onto the top
  deck, a camera kick, a "BRACING HELD" or "ROCKFALL: HULL -1" popup; the alert "FAULT ROCK AHEAD:
  power bracing (W)" when the scanner sees fault rock within about 6 m ahead.
- Side cutting: sparks and debris along the leading side of the hull when the heading is past about
  30 degrees.
- Douse: a "DOUSE (F)" button on each burning room in the cutaway (one coolant), F douses the worst
  fire; a coolant spray effect; the reason from `douse_ready` when it cannot.
- Power panel: a short line under each row saying what it does now (helm "turn and side cut",
  bracing "soaks rockfalls and hits", weapons "guns and blast charges", drill "speed, heat, noise",
  coolant "cooling, pumps, douse").
- Help (help_view.gd): update the CONTROLS and SYSTEMS lines for the new keys and jobs.
- Sound: reuse existing sounds for the blast and the rockfall if nothing fits better.
- Map survey marks: show `faults` on a node's survey.
- Shots and captures: add story moments (a scenario or a bot flag) for "hold depth", "blast" and
  "rockfall" so `tools/shots.py` and `capture.py` can show them.
