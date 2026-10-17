# Spec: the away miner (M1c round E, D046)

Part 1 (sim, data, bots, tests) is for a `builder-opus` in its own worktree. Part 2 (the view) comes
after part 1 merges and reads this spec plus part 1's report.

Read first: CLAUDE.md (hard rules: sim purity, one command chain, determinism, exact integer
resources, content is data, strict typing), HANDOFF.md gotchas, docs/ARCHITECTURE.md,
docs/DECISIONS.md D034 to D045, docs/plans/M1c.md (round E), docs/plans/specs/m1c_dig_verbs.md (the
pattern this follows), then game/sim/drill/* (drill_sim.gd, drill_verbs.gd, drill_structures.gd),
game/sim/crew/*, game/sim/ship/*, game/sim/systems/*, game/sim/hazards/hazard_sim.gd,
game/sim/run/run_state.gd and the pursuer, game/sim/core/sim.gd (commands, state_hash), game/bots/*,
game/data/tuning/*. Godot API dump (git-ignored): read it from the main repo,
`C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`.

## Why (Stewart, build 3)
"Potentially we should explore a park and disembark to allow a single miner to mine out the veins?"
and "I want more things to manage so it feels less on rails." The miner reaches a vein beside the
path without steering the whole tower there, quietly and at full yield, but the drill stands still
while the front keeps coming, the crew member is not aboard to man a station or fight a fire, the rock
can hurt them, and what they carry is lost if they die. Time and a crew member against ore.

## Part 1: sim, data, bots, tests (builder-opus)

### Owned files
game/sim/drill/** (a new `drill_miner.gd`; keep drill_sim.gd from growing: it is already over 400
lines, move code out if you add to it), game/sim/crew/**, game/sim/ship/** (only what away crew
need), game/sim/systems/** (manning must ignore away crew), game/sim/hazards/** (same),
game/sim/run/run_state.gd (summary counters, death cause), game/sim/core/sim.gd (state hash, command
list only), game/bots/**, game/data/tuning/**, game/data/scenarios/miner_demo.json (new),
game/tests/** (new `test_miner.gd`, the tuning-keys list in test_data.gd, any test the change breaks),
tools/balance.py (report counters only), docs/research/m1-evidence/, docs/ARCHITECTURE.md (commands
and events), docs/DECISIONS.md (D046 is this design; your own entries from D047). NOT game/view/**,
not game/meta/**, not other game/data folders.

### 1. Commands
- `{"type": "send_miner", "crew": "<crew id>", "x_m": float, "y_m": float}`: the target is a point in
  the rock, segment meters. Valid only while a drilling segment is active (run phase "drill" in run
  mode; any active segment in scenario mode), no miner is out, the crew member is alive and aboard,
  and the target lies inside the grid, below the ship's top edge, within `miner.range_m` of the exit
  point (the drill head: ship bottom centre). Otherwise `"bad_command" {"type": "send_miner", "why"}`
  with why one of "no_segment", "miner_out", "no_crew", "range", "outside".
- `{"type": "recall_miner"}`: the miner turns back now (valid while one is out; else bad_command
  "no_miner").
- Both go through `sim.push` like every command, so replays and bots work unchanged.

### 2. The sortie (a new `DrillMiner`, owned by DrillSim as `drill.miner`, like `verbs`)
Phases, all on the fixed tick (no frame time):
1. **board** - the crew member drops whatever job they had and walks to the drill room with the
   existing pathing (a new crew job kind, for example "sortie"). The drill keeps going meanwhile.
2. **exit** - on reaching the drill room the drill parks (below) and the crew member leaves the ship:
   `away = true` on the CrewMember. `miner.hatch_s` (2.0 s) later they stand at the exit point.
3. **dig** - they work toward the target along a 4-connected cell path (so the tunnel is walkable),
   taking one cell at a time: an air cell costs `cell_m / miner.walk_m_s` seconds, a solid cell
   `miner.dig_base_s + miner.dig_hard_s * hardness` seconds (effective hardness after gear does NOT
   apply: hands, not the drill head). Each dug cell becomes air through the SAME cell-cutting path
   the drill uses (refactor it to take a cutter, drill or miner), so mined counts, chunk changes,
   structures, crates, pockets and loot all stay consistent. What differs for the miner is routing:
   - yield: `miner.yield_pct` (100) of the material's amount, rounded down, goes into the miner's
     `haul` (by RunState.RESOURCES index), NOT into the run yet;
   - a water pocket cell: the connected pocket drains into the tunnel (cells become air, marked
     burst, no water enters the ship), the miner takes `miner.water_hp` damage;
   - a gas pocket cell: the pocket burns off (cells become air, marked burst), the miner takes
     `miner.gas_hp` damage; no fire aboard;
   - an unstable (fault) cell: +1 to the miner's own strain; at `miner.strain_cells` a rockfall hits
     the miner `miner.rockfall_warn_s` later for `miner.rockfall_hp` (bracing does not help outside),
     strain drops by the threshold;
   - a crate: opens and pays into the haul (not the run);
   - noise: `miner.noise_per_cell` per solid cell (calibrate: a whole sortie should make about a tenth
     of the noise of drilling the same cells).
4. **vein** - at the target, if the target cell (or the cell they stand in) was a yielding material
   (ore or gem), they keep digging the 4-connected cells of yielding materials around the tunnel end
   (breadth first from the target, ties broken by cell index, never by StringName), up to
   `miner.vein_max_cells`, each cell reachable from air already dug. Then they turn back on their own.
   A target in barren rock: they turn back on arrival.
5. **return** - back along the tunnel at walk speed, `miner.hatch_s` to climb in, then aboard in the
   drill room: `away = false`, the haul is paid into the run with the usual "resource" events (the run
   summary counts it), event "miner_back" {"crew", "haul": {res: n}}. The drill unparks.

While out the miner keeps their hp; anything that hits them clamps at 0. At 0 hp they die where they
are: `alive = false`, cause "miner_gas", "miner_water", "miner_rockfall" or "miner_strike", the haul is
lost, event "miner_lost" {"crew", "cause", "haul"}, and the drill unparks. A pursuer strike while the
miner is out also deals `miner.strike_hp` to them.

### 3. Parked drill and away crew
- Parked: speed 0, no cutting, no drill heat, no drilling noise, no bit wear; the pursuer, hazards,
  systems and crew all keep running. The run's clock keeps going (that is the cost). Read-only
  `drill.parked: bool`. The segment cannot end while parked (the ship does not move). If the run ends
  (death) with a miner out, they die with the ship (no extra event needed beyond the run's own).
- Away crew are aboard nowhere: they man no station, take no job, take no room hazard damage
  (fire, heat, smoke, water), are not counted by anything that counts crew in a room, and CrewAI skips
  them (audit every loop over ship.crew; keep `room` valid, for example the drill room, so no code
  indexes room -1). Crew counts for "crew dead" defeat still count them as alive.
- Combat: a fight cannot start mid-segment today; if any path can start one while a miner is out, the
  miner is recalled at once (say so in the report).

### 4. Read-only state for the view
`drill.miner`: `active`, `crew_id`, `phase` ("board", "exit", "dig", "vein", "return", "enter"),
`pos` (segment meters, the miner's feet), `target` (segment meters), `haul` (PackedInt32Array by
RunState.RESOURCES), `cells_dug`, `strain`, `rockfall_ticks`, `range_m`, plus a static
`DrillMiner.target_ok(drill, sim, crew_id, point) -> String` ("" or the why) that the view calls for
its aim circle, like `verbs.aim_ok`.
Events: "miner_out" {"crew", "x_m", "y_m"} (at exit), "miner_hurt" {"crew", "cause", "hp"},
"miner_rockfall_warn" {"in_s"}, "miner_back", "miner_lost", "bad_command".

### 5. Tuning (game/data/tuning, start values; tune in step 7)
`miner.range_m` 12, `miner.walk_m_s` 1.4, `miner.hatch_s` 2.0, `miner.dig_base_s` 0.25,
`miner.dig_hard_s` 0.9, `miner.yield_pct` 100, `miner.vein_max_cells` 30, `miner.noise_per_cell`
(calibrate), `miner.water_hp` 20, `miner.gas_hp` 45, `miner.strain_cells` 12,
`miner.rockfall_warn_s` 1.2, `miner.rockfall_hp` 35, `miner.strike_hp` 30. All in the tuning lint.

### 6. Bots
The policy bots use the miner when it pays: a cluster of yielding cells (bots read the grid like they
already do for value-seeking) within range and at least about 3 m off the ship's line, the pursuer at
least 2 rows behind (cautious: 3, greedy: 1.5), the hull above half, no fire aboard. They send the
crew member whose absence costs least (not the helm pilot if another is free), and recall when the
front comes within 1.2 rows or the miner drops below 40 hp. Bots must never leave a miner out forever.

### 7. Tests and balance
- `test_miner.gd`: refusals (each why); the full sortie in a scripted segment (board, exit, dig,
  vein, return), haul paid only on return and exactly equal to the cells' yields (integers, no
  tolerance); the drill parked and unparked; away crew not manning and not hurt by a room fire; gas,
  water and fault damage; death loses the haul and records the cause; recall mid-dig; determinism (a
  sortie run twice gives the same `state_hash`, and the miner's state is in the hash); a replay of
  a run with a sortie ends in the same hash.
- `game/data/scenarios/miner_demo.json`: a segment with a rich vein about 6 to 8 m to the side and a
  little ahead, the miner sent at about 2 s (for the view's stills).
- `python tools/check.py` must say `check: ok`; `python tools/determinism.py` ok.
- Balance: `python tools/balance.py --runs 300 --procs 6 --pack` per bot (or `--full --runs 300`):
  report wins, medians, sorties per run, miner deaths, the haul share of all ore. The balanced bot
  sits at about 38% wins today (kept on purpose, D039, D044): do not let it climb past about 45%; if
  it does, tune the miner (range, dig times, hp hits), not the rest of the game.

### Done means
Committed on your branch, check ok, determinism ok, balance report in
docs/research/m1-evidence/balance_m1c_miner.md. Report (under 40 lines): what you built and where,
the commands and events as built, the read-only fields, tuning values chosen and why, balance
numbers, anything you could not do or changed from this spec, files over 400 lines.

## Part 2: the view (after part 1 merges; for a `builder`, Sonnet)

Part 1 is merged (3be827f, merge c2237be). As built: `send_miner {crew, x_m, y_m}` and `recall_miner`
(refusals: "no_segment", "miner_out", "no_crew", "outside", "range", "no_miner"). Read-only:
`sim.drill.parked`; `sim.drill.miner` has active, crew_id, phase ("board", "exit", "dig", "vein",
"return", "enter"), pos (feet, segment meters), target, haul (PackedInt32Array by
RunState.RESOURCES), cells_dug, strain, rockfall_ticks, range_m, next_cell, action_ticks,
action_total, sorties, is_out(); `DrillMiner.target_ok(d, sim, crew_id, point) -> String` ("" or the
why) and `DrillMiner.head(d) -> Vector2` (the exit point). Events: "miner_out" {crew, x_m, y_m},
"miner_hurt" {crew, cause, hp (the damage), left}, "miner_rockfall_warn" {in_s}, "miner_back"
{crew, haul, called_off?}, "miner_lost" {crew, cause, haul}, "loot" with miner: true. Causes:
"miner_gas", "miner_water", "miner_rockfall", "miner_strike". Scenario `miner_demo` (seed 1): Okafor is
sent at 2 s to (23.0, 14.15) and comes back with 22 ore at about 50 s.

### Owned files
New: game/view/hud/miner_card.gd (MinerCard), game/view/miner_layer.gd (MinerLayer), a test
game/tests/test_miner_view.gd. Edit: game/view/main.gd (create, bind, clicks, the G key: keep the
edit small, main.gd is over 400 lines), game/view/run_screen.gd (build and bind the card, keys
enabled like the blast card), game/view/hud/scanner_panel.gd and hud/scanner_extras.gd (click to send,
the miner dot), game/view/hud/crew_cards.gd (OUTSIDE), game/view/hud/alerts_strip.gd (alert and
notice), game/view/overlay/help_view.gd (a paragraph), game/view/overlay/death_screen.gd (cause text),
game/view/boot.gd (only if you add a dev flag: every bot or capture flag goes into Boot.BOT_FLAGS),
game/tests/ui_selftest.gd and test_ui.gd if needed, README.md (keys table), docs/progress/.
Not game/sim/**, game/bots/**, game/data/** (except nothing), not the rock or structure views.

### What to build
- **The order (MinerCard)**: a card like the BlastCard (`game/view/hud/blast_card.gd`: copy its
  look, flash text and arming), placed to the right of the blast card in the same row, only while
  drilling. Title "G  SEND MINER: <CREW NAME>" (the crew member selected on the crew cards; 1 to 3
  select). G arms it (aim mode: like F2), a left click on the rock or the scanner sends
  `send_miner` with the selected crew and the clicked point (meters), right click or Escape disarms.
  While a miner is out the card reads "<NAME> OUTSIDE: <phase word>, haul +N ore +M gems" with an hp
  bar, and G (or a click on the card) recalls (`recall_miner`). Refusals are flashed in words (reuse
  BlastCard.reason_text's style: "TOO FAR (12 M)", "A MINER IS ALREADY OUT", ...). Arming the miner
  disarms the blast and the reverse.
- **The aim (in MinerLayer)**: the range ring around `DrillMiner.head(d)` of radius range_m, drawn
  ONLY where it falls inside RunScreen.WORLD_RECT (copy the clipping in `DigFx._draw_aim`), a circle
  under the mouse, green when `target_ok` is "" else red, and a dashed line from the head to it.
- **The miner in the world (MinerLayer, a Node2D in segment space at the rock's origin like
  StructureLayer; ppm 80)**: hidden in "board"; from "exit" on a small figure about 1.6 m tall
  (draw it: legs, body, helmet, a harness band in that crew member's colour from the crew cards) at
  `pos`, facing `target`; one PointLight2D headlamp (texture from `RockView.light_texture`, height
  about 120, `range_item_cull_mask = RockView.LIGHT_MASK`, energy about 0.9, warm white) switched off
  when not out (the rock is one canvas item: keep exactly one light here); in "dig" and "vein" a
  pick swing (a short line rotating on a sine) and a few chips (`CrownDebris.make_chips` is used by
  StructureLayer: reuse it) at `next_cell`; the haul as a small tag above the head ("+12 ore +2 gems",
  only when nonzero); a red flash and a floating "-45" on "miner_hurt"; a pulsing "!" over the head
  while rockfall_ticks > 0. Unshaded, additive drawings need the x1.8 to x2.0 boost (HANDOFF gotchas).
- **Crew card**: an away crew member's card says OUTSIDE (in the card's status corner) instead of
  IDLE or a job, and their "go to" button is hidden while out.
- **Alerts and notice**: an alert chip "MINER OUTSIDE: <NAME> <hp>" (severity like the bit alerts),
  and while `drill.parked` the drill-stop notice says "PARKED: <NAME> IS OUTSIDE. G recalls." (check
  `AlertsStrip.drill_stop` order so a parked drill does not also say "no power").
- **Scanner**: the miner as a bright dot at pos with a short trail to the head; a click while the
  card is armed sends (like the blast's `scanner.blast` hook).
- **Help**: a paragraph: G sends the selected crew member to dig a vein by hand within 12 m; the drill
  parks until they are back; they are not aboard to man stations or fight fires; gas, water and
  fault rock hurt them; the haul pays only when they climb back in, and is lost if they die; G
  recalls. The dig tally and pickups: check that the haul paid on return shows in THIS DIG (it is
  paid with "resource" events); if not, add it.
- **Death screen**: causes "miner_gas" and friends read as "lost outside: gas burst" etc. if a run
  ends showing them (crew deaths list).

### Rules and checks
Strict typing, no em dashes, view only reads the sim and pushes commands. `python tools/check.py` must
say `check: ok`. Windowed runs flash a window on Stewart's screen: at most 3 windowed jobs in total.
Take stills with `python tools/shots.py --scenario miner_demo --seed 1 --names t4,t12,t30,t52
--out harness/out/shots_miner --no-import` (add `--extra=--look=...` style flags only if you add
them) and LOOK at them: the figure, the light, the tunnel, the tag and the card must read at 1080p.
Add one progress picture with `python tools/progress.py <png> --label m1c-away-miner --note "..."`.
Stage explicit paths only, commit on your branch ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; do not push or merge.

### Report (under 30 lines)
Branch and commit, files changed, how to drive it (keys), what the stills show (and their paths),
anything not done, files over 400 lines.
