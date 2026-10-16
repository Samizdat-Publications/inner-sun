# Decisions

Each entry: the choice, why, and how to undo it. Tags: S = Stewart, AI = decided by Claude.

## D001 (S): FTL-style, 2D side-view cutaway, roguelite runs, Godot 4 native Windows
From the kickoff (`docs/STEWART_FEEDBACK.md`). Not revisited without Stewart.

## D002 (S): The ship is a tall tower
Decks stacked, drill at the bottom, boring straight down. Chosen over a horizontal mole in the
planning session (2026-10-15). Hazards stack by deck: water pools low, heat and gas rise.

## D003 (S): Inner Sun and Black Diamond are the only Godot projects running for now
Cut & Fill is paused (2026-10-15). Both projects follow the side-by-side rules in
`C:\Users\stewa\Documents\Claude\GODOT-SIDE-BY-SIDE.md`.

## D004 (AI): Godot 4.7.2 Forward+ on Vulkan, strictly typed GDScript, no C#
Latest stable (4.8 not released). Vulkan is forced (`fallback_to_d3d12=false`) because new Windows
projects default to D3D12 and every capture on this PC is proven on Vulkan. No C#: needs the .NET
Godot build and nothing requires it. Revert: change `rendering_device/driver.windows`.

## D005 (AI): Rules in a node-free GDScript sim; Rust only for a measured hot spot
Benchmark (M1-shaped load): about 28,500 ticks/s single process against a 6,000 budget. GDScript
stays. Revert path: port the hot spot to Rust via gdext (Cut & Fill's proven toolchain).

## D006 (AI): Own event system in JSON, not ink or Dialogic
inkgd is dormant since 2024, GodotInk needs C#, Dialogic 2 is still alpha and needs the scene tree;
none runs inside headless balance runs. A friendlier writing format can compile to the same JSON.

## D007 (AI): Own crew job AI, not Beehave or LimboAI
Both need scene Nodes; the sim must run headless. Pathing uses Godot's AStar2D over rooms, doors and
ladders. Revert: LimboAI with stand-in nodes in the view layer only.

## D008 (AI): Room-level water and heat with exact integer conservation
Like Barotrauma's hulls and gaps, never per pixel. Water in mL, heat in J, moved in exact pairs;
tests assert equality. Hatches pass heat upward far better than downward (heat rises).

## D009 (AI): Custom headless test runner, no GUT or gdUnit4
Matches the sibling projects (Noclip, Cut & Fill); no add-on version coupling (Godot 4.7's typing
change broke GUT until it was patched). A Logger installed before tests load fails any test that
produces an engine error. Revert: GUT 9.7.1 (godot_4_7 branch) if doubles or parametrized tests are
needed.

## D010 (AI): No Godot MCP server
Evaluated on paper (2026-10-15): Coding-Solo/godot-mcp only duplicates what the command line already
does here (no screenshots, no input); the editor-connected servers (godot-ai, godot-mcp-pro, GDAI,
satelliteoflove) need a running editor and fixed ports, which would collide with Black Diamond.

## D011 (AI): Every Godot run inside a Windows job object; never kill by name
Processes start suspended, join a job with kill-on-close, then resume, so the real exe that the
console wrapper spawns is inside too. Proven: a timed-out run and a tool killed from outside both
left no process behind. A name-based "reap strays" helper was refused by the safety filter and is
not needed.

## D012 (AI): Windows are created unfocusable; normal play takes focus back
Measured: an off-screen Godot window still takes the foreground (65 of 71 samples). The project sets
`display/window/size/no_focus=true`; the Boot autoload restores focus for normal play only. Bot runs
never touch Stewart's keyboard (0 of 70 samples).

## D016 (AI): Park bot-run windows off-screen from inside the game and from the launcher
Measured: Godot pulls a window started at --position -32000,-32000 back to the top-left corner of the
screen and keeps it there. The Boot autoload re-parks it every frame for half a second and
`tools/proc.py` moves the job's own windows off-screen as soon as they appear. Left: about one second
on screen at startup. Next options if needed: a hidden desktop or a minimized start. Revert: remove the
parking code in `boot.gd` and `proc.py`.

## D013 (AI): Split the cutaway into small canvas items
Godot lets one canvas item take only about 15 lights; one big drawing lost lights and went dark in
the first M0 captures. Per-room, per-crew and per-chunk nodes; idle lights disabled.

## D014 (AI): Playtest builds and the critic install
The blind critic's guard and agent file are staged in `docs/setup/critic/` because this planning
session inherited Cut & Fill's deny rule for those paths. The first build session installs them
(HANDOFF.md step 0). Revert: none needed.

## D015 (AI): Working title stays Inner Sun
Alternatives if wanted: Superdeep, Mohole. The folder and repo keep their names regardless.

## D017 (AI, provisional until Stewart sees it): Art style is painted pulp illustration
The M1 bake-off made the same reactor room and engineer as painted pulp (Gemini) and Blender
pre-rendered sprites, lit identically in Godot (`docs/progress/005_m1-art-bakeoff.jpg`). Painted
reads as a real, lived-in place at game scale and its engineer is a character; Blender is more
predictable under moving light but its crew is a faceless block. Pixel art was not tried: no
PixelLab key. Risks taken on: animation (answered with cut-out puppets on a 2D skeleton) and
consistency across many generated assets (one shared prompt, variants, a lead pick, manifests).
Revert: switch the pipeline to `pipeline/blender/` (already working) or add a PixelLab key and run
`pipeline/pixel_gen.py`; the game code is style-agnostic (albedo, normal and emission sprites).

## D018 (AI): Power returns after repairs; an overheated reactor limps
Rooms remember the last allocation chosen (`Room.sys_want`). Damage and reactor shortfalls cut
power by priority; repairs and reactor recovery bring it back, highest priority first, while bars are
free. A heat-failed reactor gives half its bars instead of none: zero cut the coolant too and made
every reactor overheat an instant death spiral. Revert: drop `_restore` in `systems.gd` and return 0
from `_output` when failed.

## D019 (AI): Story canon from the crust writing: TOPSIDE is not quite human
The crust events commit to an uncanny handler: TOPSIDE's voice is on a 1963 reel at a Cold War
listening post, already calling the crew "Auger", and never breathes on any recording. Invented
lore also signed off: Rig Zarya (a found Soviet rig; the real Saatly, Uralskaya and Tyumenskaya
superdeep wells are mentioned without dates or depths), Listening Post 4, the Calder Deep mine, the
K-7 coolant spec, "the Subject" (the thing that follows). This fits the pitch (a handler who knows
more than they say) and gives the story spine a question to pay off in later layers. Revert: edit
`game/data/events/listening_post.json` and `game/data/codex/topside_voice.json`.

## D020 (AI): Pacing and economy, first pass
Rows are 28 m (segments about 25 to 30 s at 2 bars instead of about 45 s), ore veins are sparser
and sit 5.5 to 10 m off the straight line (runs mined 300 to 570 ore against store prices in the
tens), rock heat rises 0.08 C per meter (the layer owns it). The balance step tunes further with bots.

## D021 (AI): First balance pass
Measured with the policy bots (`game/bots/policy_bot.gd`: cautious, greedy, balanced) over whole runs
(`python tools/balance.py --full`). Before: every bot reached the gate and about 90% died there; the
pursuer never struck; coolant and bits never ran short; upgrades were almost never bought. Changes,
each with its reason (revert by restoring the old value):
- `weapons/thermal_lance.json` heat_kj 350 -> 200: crew dying of heat at the gate was the top single
  cause of losing it (the beam cooks every room it crosses, through bracing).
- `ships/rival_heavy.json` hull 16 -> 13: the gate still won 85%+ of the time against every policy.
- `layers/crust.json` pursuer rows_per_s 0.0143 -> 0.02, rows_per_noise 0.0045 -> 0.0035: the pursuer
  never reached anyone. Time now matters more than noise, so slow, careful play gets caught late.
- `tuning/run.json` strike_every_s 8 -> 10: once caught during a fight, strikes on top of enemy fire
  killed in seconds; still lethal, a little more time to dig out.
- `stores/crust_trader.json` bracing upgrade 40 gems for one bar -> 20 gems, limit 2 per visit: one
  bar never made a layer (2 bars per layer), so the line was a trap.
- `tuning/combat.json` loot gems 4-10 -> 5-12: gems were the binding limit; stores went unused.
- `ships/light_drill.json` start coolant 20 -> 14, bits 3 -> 2; `tuning/systems.json`
  coolant_j_per_unit 1.5 MJ -> 1.0 MJ: runs ended with most of the coolant and bits unused, so the
  supply side of the store never mattered.
Result (1,002 runs from a frozen pack, harness/out/balance/full_report.md): balanced wins 25%,
cautious 21% (its losses are all late: the gate, or the pursuer catching a slow ship), greedy 13% but
richest when it wins (103 gems gained against 92 to 93); the top killer is the gate at 38 to 44%;
every event fires; most runs fight 3 times (2 to 4 in 93% of runs). The tests that hard-coded the old numbers now read them from the data.

## D022 (AI): Hazard pressure (critic 002: "no fire anywhere in a whole dive")
Borer rounds start fires 22 percent of the time (was 10) and breach 25 (was 15); charges start fires
30 percent (was 20); pursuer strikes ignite 45 percent (was 25); rooms autoignite at 100 C (was 140);
drilling heat is 5.5 kW per bar (was 4). Result on 300 runs: fires in 99 percent of runs (about 5.5 per
run), crew lost in 61 percent, win rates balanced 19, cautious 16, greedy 12 percent (was 25, 21, 13),
still inside the target band. Hull damage still lands mostly at the gate: the middle of a run threatens
crew and systems, not the hull. Evidence: `docs/research/m1-evidence/balance_after_d022_300_runs.md`.
Revert: the six numbers in game/data/weapons, tuning/run.json, tuning/hazards.json, tuning/drill.json.

## D023 (AI): Frame-time budget for the rock and the HUD
Drilling stuttered: p99 32 to 44 ms (1% lows near 25 fps) while the GPU used under 1 ms. The rock
view repainted a whole 16 x 16-cell chunk (about 30 ms of GDScript) whenever any cell in it was cut,
and every HUD panel redrew every frame. Now the rock view diffs its own copy of the grid and repaints
only the changed cells plus one cell of padding (exact: a pixel reads only cells within one cell),
in small strips under a 3.5 ms per-frame budget, nearest the ship first; the mosaic uploads at most
every 3 frames; the scanner patches its image instead of rebuilding it; HUD panels redraw at most
60 times a second on staggered frames. A test proves the budgeted mosaic is byte-identical to a fresh
paint. Result: whole-run p99 12.7 ms, 1% low 78.5 fps, average 196 fps
(`docs/research/m1-evidence/perf_run_mode_after_fix.json`, measured with headless Chrome and Claude
on the GPU, so the tool's strict "trusted" flag stays off). Revert: the merge of the perf fix.

## D024 (Stewart): Digging is the game (M1b direction)
His first playtest: nothing to do but steer, segments of about 25 s that yield "one piece of coal",
runs too short. He picked "Digging is the game": drilling becomes the main activity (longer segments,
rock packed with ore and gems that get richer with depth, a view that shows the rock ahead, ore buys
gear upgrades), while FTL-style systems, combat, events and upgrades stay. His framing: the "scanning
planets and gaining resources" loop, where gathering is the focus and hostile forces turn up now and
then, not encounter after encounter. This reverses the kickoff's "keep drilling segments short so runs
stay paced like FTL". Plan: `docs/plans/M1b.md`. Revert: the M1b merges.

## D025 (AI): The dig economy: tiered rock, ore for gear, gems for supplies (M1b round 2)
Rock (`data/rock/crust.json`): coal (ore 1), iron (2), copper (3, from 60 m), silver (6, from 180 m,
in basalt shells), gold (12, from 360 m, shells); quartz (gems 1, the old "gem" id kept for the view),
amethyst (2, from 120 m), emerald (5, from 300 m); water and gas pockets. Features take depth windows
(`from_depth_m`, `to_depth_m`, a segment overlapping a window in part gets the same density per
meter) and a group ("ore" and "gems" scale with the survey richness; "gems", "gas" and "water" only
when the survey found them). Deposits sit 3.5 to 11 m off the line to the next node (centres kept in
the steerable band), so a straight drive collects about 18 ore at 240 m and a greedy weave about
100 (test_dig_economy). Currency by line: ore buys system upgrades (120 to 200), gear (tungsten head
180, diamond head 450, plating 200, pumps 120) and hull repair (2 a point, as before); gems buy
coolant, cells, bits, charges, crew and the lance (prices unchanged). Ore prices are about 6 times
D021's gem prices because runs now mine about 700 to 1200 ore (D021: about 110): the first try at
half these prices let the bots buy 4 to 6 items and the greedy and balanced bots win 40 to 65%. Gear is data
(`data/gear/*.json`, `sim/run/gear.gd`): multipliers (cut speed, bit wear, hard rock hardness, pump
rate) read through `RunState.gear_x`, one-time adds (max hull, hull); a slot keeps one item and only a
higher tier replaces it. Revert: the rock, store and gear data and `gear.gd`.

## D026 (AI): Retuned per meter for 60 m segments
`row_depth_m` 28 -> 60 (10 rows kept, the gate at 540 m). `base_speed_m_s` 1.3 -> 0.85: a 60 m
segment takes about 60 s at 3 bars on a fresh bit, 65 to 75 s in real runs with worn bits.
`wear_per_m_hardness` 0.008 -> 0.0055: a bit lasts about 2.7 greedy segments. Noise per meter is
now times the hardness cut (basalt shells are loud), and gas pockets add `gas_noise` 8. Pursuer
`rows_per_s` 0.02 -> 0.0100 and `rows_per_noise` 0.0035 -> 0.0028, measured so the pursuer is about
one row behind the balanced bot at the gate (it was 0.0095 / 0.0026: balanced 46%; 0.0105 / 0.0030:
cautious 4%); loud play is chased harder than before. `coolant_j_per_unit` 1.0 -> 1.8 MJ: segments
twice as long doubled the drilling heat per segment and coolant ran out in about 45% of runs (now 0
in 300). Layer `rock_temp_c_per_m` 0.08 -> 0.04 so the rock at the gate is as hot as before
(about 62 C). Gas pockets (`drill.gas_fire_level` 0.3) set the drill room on fire once per connected
pocket. Revert: the numbers in `data/layers/crust.json`, `data/tuning/drill.json`,
`data/tuning/systems.json`.

## D027 (AI): Policy bots give power by priority; cautious drills at 3 bars
`PolicyBot._apply_power` treats its wanted list as a priority order over the reactor's output. Before,
bars held by helm and bracing were never released, so every policy drilled at about 1.6 to 2 bars
whatever it wanted (the three policies drilled alike), and in a fight the guns got only what the
drill released. Side effect: the bots now fight with fully powered guns, which made the gate easier
for them (balanced wins the gate 57%, D022: 29%; see the balance report). With the fix the cautious
bot at 2 bars and 15 s waits was caught by the pursuer in 80 to 88% of runs, so it now drills at 3
bars (quieter weaving, 10 s waits) and stays distinct by avoiding gas, water, fights and noise.
Revert: `game/bots/policy_bot.gd`.

## D028 (AI): Surveys are the rock; deposits; fights now and then; stores on every path
Each node's survey (tier and richness, ore types, gems, gas, water; `sim/run/survey.gd`, stream
"survey") is rolled once per run and the segment to that node is generated FROM it, so a reading is
never wrong. "deposit" nodes (weight 25) roll at least the "rich" tier with more gas and water and
hold no encounter: the rock on the way is the reward. Node weights mining first (deposit 25, event 25,
cavern 15, store 12, hazard 8, fight 15), `min_fights_per_path` 2 -> 1 (plus the gate), and the map
guarantees a store on every path in rows 2 to 4 and again in rows 6 to 8 (`store_windows`); the
guarantees convert deposits only when no other plain node will do. Revert: `data/layers/crust.json`,
`sim/run/map_gen.gd`, `sim/run/survey.gd`.
