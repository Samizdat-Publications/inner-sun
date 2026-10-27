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

## D029 (AI): A 14-row Crust: longer runs, slower cut, more cells
Stewart wants runs "way longer" and mining first. `rows` 10 -> 14 (gate at 780 m), `store_windows`
[[2,4],[6,8],[10,12]], `min_fights_per_path` 1 -> 2. Node weights deposit 28, event 27, cavern 16,
store 6, hazard 9, fight 7 (the guarantees already make about 8 stores and 6 fights per map of
about 30 middle nodes; with the old 12 and 15 stores ate the events and fights reached 22% of
nodes; now 19% of nodes and about 2 rival fights on a bot's path of 12). `drill.base_speed_m_s`
0.85 -> 0.64 and `power_factor_bar_4` 1.65 -> 1.55: a 60 m segment takes about 80 s at 3 bars
(was 60), so median runs are 17 to 21 min (they were 13.3 to 17 min with the old speed on 14
rows); the 4-bar edge shrank so greedy is not 4 min shorter than the rest. The time bands in
test_drill and test_dig_economy scale with the tuned base speed. `light_drill` start cells 8 -> 12
(13 segments now; with 8 the bots spent their gems on cells and broke bits). Rock heat
`rock_temp_c_per_m` 0.04 -> 0.033 (66 C at the 780 m gate; 0.04 would make it 71 C, the old gate was 62 C). NOT DONE, outside this
round's files: `data/scenarios/drill_segment.json` still lasts 60 s, which a 36 m segment no longer
fits at 2 bars; test_drill gives it the scaled time in memory; set its `duration_s` to 90 for
`play.py --scenario=drill_segment`. Revert: `data/layers/crust.json`, `data/tuning/drill.json`,
`data/ships/light_drill.json`, the test edits.

## D030 (AI): The descent bites: pursuer per row, deeper gas and water, tougher rivals
General, data-driven levers instead of one wall at the gate:
- Pursuer `rows_per_s_per_row` (new, RunState): the front's time rate grows by this much per map
  row of the ship's current node. Crust: `rows_per_s` 0.0100 -> 0.0041, `rows_per_s_per_row`
  0.00028 (0.0075 at the gate row), `rows_per_noise` 0.0028 -> 0.0038 (loud play is chased harder,
  quiet slow play less: at the 10-row rates the pursuer killed 93% of cautious runs on 14 rows).
- Survey `per_row` (new, Survey): chances added per row below the first segment. Crust: gas +0.015,
  water +0.01 per row (gas 0.3 at the top, 0.47 in the last segment).
- Layer `enemy_tiers` (new, MapGen.enemies_for_row): `[{"from_row", "ships"}]` picks the fight's
  rival by row. Crust: rival_light to row 6, mixed from row 7, only the new `rival_raider` ("Seam
  Raider": hull 15, two borers, four crew) from row 10.
- The gate is never overtaken (RunState._sweep_overtaken): before, a ship caught on the last segment
  arrived at an overtaken gate, could not fight or move and was struck to death while idle. Now it
  fights the gate with the pursuer striking.
Revert: the four fields in `data/layers/crust.json`, `data/ships/rival_raider.json`, the code in
`sim/run/run_state.gd`, `survey.gd`, `map_gen.gd`, `run_lint.gd`.

## D031 (AI): Event rows keep their place in a longer layer
Event `rows` windows in `data/events` were written for the 10-row map; on 14 rows rows 9 to 12 had
no events. New optional layer field `event_rows_of` (Crust: 10): RunState.event_row spreads the
middle rows 1..rows-2 evenly over 1..event_rows_of-2 before Encounter picks, so each event keeps its
place in the descent without editing event data. Remove the field when the events are re-windowed
for 14 rows. Revert: the field and `RunState.event_row`.

## D032 (AI): The cautious bot buys a better drill head first
With 14 rows the cautious bot's worn bits and plating-first shopping left it too slow for the
pursuer (4% wins, bits at 0 from row 5). Its upgrade list now starts with the tungsten head (a
faster cut and a longer-lasting bit), then plating. Revert: `game/bots/policy_bot.gd`.

## D033 (AI): Balance after the longer Crust (300 runs, 4 passes)
Final: cautious 10% wins, 21.0 min median; greedy 12%, 17.2 min; balanced 23%, 21.4 min. Gate hull
stays 13 (probes at 14 to 16 moved deaths back to the gate). Gate share of deaths: balanced 58%
(was 73%), greedy 38%, cautious 34%; the rest are rivals, drill heat and fire, and the pursuer.
Evidence and the pass history: `docs/research/m1-evidence/balance_m1b_tuned.md`.

## D034 (AI): M1c direction: every system has a job in the dig
Stewart's build 3 notes: the dig is "picking a spot based on the radar and going straight down", he
could not see what helm and bracing do, and he wants "more things to manage". Answer: give every
powered system a job while drilling, so each segment is a power-split puzzle like an FTL fight: helm
sets the turn rate and the sideways cutting speed (heading to +-90, "hold depth"), bracing soaks
rockfalls in a new fault rock, coolant can douse a fire for a unit, and the charge launcher blasts
rock at range for a charge. Then buried structures to break into and a requisition meta. The away
miner (his "up to you") comes last and only if the budget allows: charges and sideways cutting cover
most of "reach the vein", and the meta answers his "reason to come back", which he stated as a need.
Plan: `docs/plans/M1c.md`. Revert: the M1c merges.

## D035 (AI): Hold depth and helm-powered side cutting
`drill.max_heading_deg` 45 to 90 (90 = hold depth, straight sideways). Turn rate 18 deg/s times
(1 + 0.6 per manned helm bar); the sideways motion times `systems.side_cut_base` 0.35 plus
`systems.side_cut_per_helm_bar` 0.3 per manned bar (0.95 at the light drill's 2 bars). Leading-band
side cells are weighted |sin h| times that scale, so straight down is unchanged. `drill.at_wall`
past 80 degrees against the wall (the bots steer for the node within 0.75 m of a wall). Why:
Stewart wants the helm to matter and to pivot to veins by taking power from other systems. Policy
bots steer by how deep a lane's value lies (a level vein means cutting sideways), capped at 50
(cautious), 60 (balanced), 80 (greedy) degrees; with steeper caps the blasting policies spent up
to 90 s a run past 60 degrees and fed the pursuer. Revert: the tuning keys and `DrillBot.level_steer`.

## D036 (AI): Fault rock, strain and rockfalls
New material `fault_rock` (Fractured shale, hardness 0.7, `unstable`) in slanted lenses (1 to 3,
6 to 14 m by 2 to 4 m, -30 to 30 degrees) in a `faults` feature group the survey switches on
(`faults_chance` 0.35 plus 0.02 per row, deposits 0.45). Every cut unstable cell adds 1 strain; at
`drill.rockfall_strain_cells` 50 (the spec's 60 was "about 2.5 m"; 80 made rockfalls too rare to
cost anything) a rockfall lands 1.2 s after a warning: a bracing layer soaks it, else 1 hull and
0.5 bars on a top-deck room (stream "drill/rockfall"). Death cause "rockfall". A rockfall still
pending at arrival is dropped. Result: 0.3 (cautious, always braced) to 4.4 (greedy) hull a run.
Revert: the material, the feature and the tuning keys; the `DrillVerbs` rockfall code.

## D037 (AI): Blast: the charge launcher works the rock
`blast` command while drilling (charge launcher mounted and powered, one charge, 5 s cooldown,
point within 14 m of the ship's centre, outside the ship). 0.6 s fuse, then every cell within
1.75 m is cut and paid exactly; a water pocket cell drains its whole pocket (no ship water, counted
in `mined` and `verbs.drained_cells`), a gas cell burns its whole pocket (lights the drill room only
within 3 m). `drill.blast_noise` 4 (spec 15; at 15 and 6 the two blasting policies were run down by
the pursuer). Bots: gas pockets on the lane (all policies), loot circles worth 50 (balanced) or 40
(greedy) ore-equivalent, never below `blast_keep` 3 charges; cautious never blasts for loot. A
blast still in flight at arrival goes off then. Revert: the `DrillVerbs` blast code, the `blast_*`
tuning keys and `BlastPlanner`.

## D038 (AI): Douse and the M1c verb balance
`douse` (Systems, `SystemsDouse`): one coolant unit, coolant powered, a burning room: fire down
0.3, up to 150 kJ removed through `hazards.add_heat` (never below the room's start temperature),
6 s cooldown. Softer than the spec's 0.6 / 300 kJ / 3 s (it barely moved the win rates either way,
since the bots douse young fires over 0.4). Final balance (300 runs per bot): cautious 26%, greedy
12%, balanced 40% wins, medians 18 to 22 min (`docs/research/m1-evidence/balance_m1c_verbs.md`).
Balanced sits above the 10 to 30% band because blasts add about 230 ore and 30 gems a run that
become upgrades and a 51% gate win; left for the lead (gate, prices or blast yields are the
levers). Store `keep` charges: greedy 6 (was 4). Revert: the `douse_*` keys and the bot fields.

## D040 (AI): Research and requisitions, the numbers
Every run pays research (`game/meta/research.gd`), a pure function of the run summary: 2 per map row
reached, 5 per codex entry learned that run, 3 per fight won, 15 for beating the gate, 1 per 40 ore
gained (rounded down). It is banked in the profile and buys requisitions (`game/data/requisitions`),
permanent starting equipment loaded onto every later dive: spare bit crate (+1 bit, 20), charge crate
(+3 charges, 20), second coolant tank (+6 coolant, 25), field plating (+5 max hull, 40), tungsten head
fitted at the start (60), a fourth hand (a fourth crew member from the survivors pool, 80). The whole
shop costs 245. The owned ids are a run option (`"requisitions"`), so they are in the replay header.
Evidence (3 bots x 8 seeds on the 14-row Crust, from the played summaries): cautious earned 50 to 76
(median 63), greedy 50 to 107 (83), balanced 69 to 95 (73); ore is the biggest line for bots
(25 to 60 of the total, they gather 800 to 2500). Stewart's build 3 death (row 7 or 8, one fight, a
few hundred ore, a couple of codex entries) works out at about 35 to 50, so his first death buys one
or two of the cheap items and the shop empties in about six to ten runs. Start-resource requisitions
are added directly (no resource events) so the "gained" counters and the ore line stay honest. Tune
by editing the constants in `research.gd` and `cost` in the requisition files. Not done: a loadout
choice (every owned item always applies), a toast in the first seconds of a dive.
Revert: delete `research.gd`, `requisitions*.gd`, the data folder and the one `Requisitions.apply`
line in `Sim._init`; old profiles keep two harmless fields.

## D039 (AI): A blast shatters half the ore it frees
After D035 to D038 the balanced bot won 40% (target 10 to 30%): blasts paid about 230 ore and 30 gems
a run at full yield for a charge that costs 4 gems, so blasting beat cutting everywhere. Now a blast
pays `drill.blast_yield_pct` (50) of each material's yield, rounded down per material per blast; the
rest shatters. That makes it a real choice: a blast is quick and reaches 14 m without a detour, but
cutting a vein with the drill pays all of it. Revert: set `blast_yield_pct` to 100.
Result (100 runs per bot, `docs/research/m1-evidence/balance_m1c_d039.md`): blast ore per run halved
(greedy 122, balanced 115) but wins barely moved: cautious 16%, greedy 9%, balanced 39% (gate won
49%). So blasts were not what made the balanced bot strong; douse and bracing against rockfalls give
a careful player more tools, which is the point of D034. Kept as is for build 4: the spread between
policies is healthy and Stewart's runs are the real test. If build 4 proves too easy for a human, the
levers are the gate (hull 13), charge prices (2 for 8 gems) and `douse_fire_level`.

## D041 (AI): Buried structures are data stamps, placed from the segment stream
Structures (`game/data/structures/<id>.json`) are ASCII stamps of 0.5 m cells with a legend of rock
materials (" " keeps the rock; a legend entry may switch material by depth, used for the hollow's
emerald below 450 m). The rock table lists them with weights and depth windows; the survey rolls
at most one per segment (`structure_chance` 0.3, +0.02 per row, deposits 0.5) and picks among those
whose window holds the segment's middle depth. Its two draws per node come from a new stream
`survey/structure`, not `survey`, so every other reading of an existing seed stayed exactly as it was
(old balance runs stay comparable). The stamp is placed after the rock features with four draws from
the segment stream (depth fraction 0.25 to 0.75, offset 3 to 9 m to a side, side, mirror), clamped
inside the grid and a cell below the start shaft; a segment without a structure draws nothing new,
so its rock is unchanged. Interior = cells of an `interior` material (`relic_air`) or a `loot`
material (crates). New materials: timber, steel (6.0, hard rock for gear), crate, rubble, relic_air,
tape_case. Placement numbers are `drill.structure_*` tuning keys. Revert: drop the survey key and the
rock table's `structures` list (the code then never places anything).

## D042 (AI): Crates, break-in, and the mid-segment store and event
A crate's first cut cell (footprint or blast) floods-and-marks the whole crate in `burst_marks` and
pays one roll of the structure's loot table (or `loot_by_material`) from `drill/<segment>/loot`
through `run.add`; a blast pays a crate in full (the 50% shatter of D039 is for rock yields). The
rig's sealed tape is its own material (`tape_case`) paying 3 power cells, so tables stay resources
only (no codex rows; the codex comes from the break-in). The first interior cut emits
`structure_entered`, learns the codex entry (`run.learn`) and rolls `drill/<segment>/structure`:
trader (store) first, then a `"kind": "structure"` event (once per run each), else nothing. The
drill stays active and pauses (the world is frozen in dialog and store as at nodes); Encounter's
`_to_idle` returns to "drill" whenever the drill is active, arrival is checked only in "drill", and
`RunState.ship_row_f` counts progress while the drill is active (not only in phase "drill"), so the
pursuer cap does not jump during the page. Structure events may not start a fight (lint): a fight
mid-segment would need CombatSim to hand back to a live segment, not worth it now. Store effects,
deaths, pursuer and reveal effects work mid-segment. Revert: the DrillStructures calls in DrillSim
and the one-line `_to_idle` change.

## D043 (AI): Bots and structures
DrillBot scores unopened crate cells (`value_crate`, per cell) and interior cells until entered
(`value_interior`) on its lanes: cautious 2 / 0.1, balanced 4 / 0.3, greedy 6 / 0.5, so cautious
takes them only when they are on its way (its 4 m detour). Loot blasts count unopened crate cells at
`blast_crate_value` 12 (cautious never loot-blasts). Node choice adds `structure_bonus` (0.3, 0.8,
1.2) for a survey with a structure. Structure events use the existing option scoring. Revert: zero
the fields.

## D044 (AI): Structure balance, kept as is
300 runs per bot (`docs/research/m1-evidence/balance_m1c_structures.md`, seeds 1000..1299): about 6
structures lie on a run's path; cautious enters 4.1 and opens 5 crates (26 loot units), balanced
5.3 and 8 (45), greedy 5.7 and 12 (71); hollow traders met 0.4 to 0.5 a run, structure events 1.4
to 1.8. Wins: cautious 25.7%, greedy 15.0%, balanced 37.7% (D039 at 100 runs: 16, 9, 39; D038 at 300:
26, 12, 40); medians 18 to 22 min as before. So structures lifted the greedy bot most (it reached
the gate more often) and left balanced where it was: still above the 10 to 30% band for the reason
D038/D039 gave (gate, charge prices). No structure tuning was changed for it; if the lead wants
fewer, the levers are `structure_chance` (0.3 + 0.02 per row is about 6 a run) and the loot tables.

## D045 (AI): The rock is fractured blocks, not wavy beds
Gemini critics 005 and 006 both scored the world outside the hull 3/10 for the same reason: the rock
read as "a scrolling screen saver of wavy sand". The cause was the rock shader in
`game/view/ship/rock_tiles.gd`: horizontal wavy beds every 1.7 m with strong light and dark swings and
fine sine lines. Now a cellular split makes blocks about 1.7 by 0.8 m (smaller in hard rock), each a
little lighter or darker and tinted, with dark crack seams that fade in and out along their length
(full cracks closed the blocks into paving stones); only a faint broad layering is left. Seen in
stills at seed 21 (greedy run). Revert: the shader block in `RockTiles.SHADER_CODE`.

## D046 (AI): The away miner: park, send one crew member, carry the haul home
Stewart (build 3): "explore a park and disembark to allow a single miner to mine out the veins? Up to
you", and "more things to manage so it feels less on rails". Design: G plus a click sends the
selected crew member to a point in the rock within 12 m of the drill head. Sending parks the drill
(no separate park key) and it resumes on its own once the miner is back, so there is one thing to
learn. The miner walks to the drill room, climbs out, digs a one-cell tunnel by hand, mines out the
connected vein at the target, and walks home. Costs and risks: the drill stands still while the front
keeps coming, the crew member mans nothing and fights no fires while out, gas, water and fault rock
hurt the miner instead of the ship, and the haul pays only on return (lost if they die). Advantages:
full yield, quiet, and veins beside the path without steering the whole tower there. Spec:
`docs/plans/specs/m1d_away_miner.md`. Revert: drop the two commands and `DrillMiner`; nothing else
depends on them.

## D047 (AI): Away miner, the details the spec left open
Choices made while building D046 (part 1: sim, bots, tests). Each is small and local to
`game/sim/drill/drill_miner.gd` / `miner_route.gd` unless named.
- The tunnel is a fixed 4-connected staircase line from the cell under the drill head to the target
  cell (ties step down), with no pathfinding around hard rock or pockets; a target level with the hull
  goes along the row under the ship first, then straight up beside it, so it never crosses the hull.
  The bots read the same route (`MinerRoute.plan`) to refuse tunnels through pockets.
- A point inside the ship's footprint is refused as "outside" (it is not rock).
- The drill keeps going while the miner boards. If the target is no longer rock beside the ship when
  they reach the hatch (cut by the drill or now above the hull), or the segment ends first, or a
  recall comes, the sortie is called off: "miner_back" with an empty haul and "called_off": true, no
  sortie counted. Range is checked when sent, not again at the hatch.
- In the vein the short walks between cells are folded into each cell's dig time; the way home follows
  parent links (the cell each one was dug from), not the order they were dug in.
- A pocket cell drains or burns its whole connected pocket even if the drill already burst it (like a
  blast), and the miner is hurt every time. Miner noise is per cut solid cell only (0.006, measured at
  about 0.10 of the drill's per-cell noise at 3 bars in granite; test_miner prints the ratio).
- An away miner gets no rest healing outside. Event effects (crew_damage, crew_lose) can still reach
  them (they are still "the crew"); a miner killed that way is lost with that cause. A dead miner keeps
  `away = true` (they died outside).
- "miner_out" carries the target point; "miner_hurt" carries the damage as "hp" (like "crew_hit") plus
  "left". segment_done's "mined" counts the miner's cells; its "yield", "ore" and "gems" stay the
  drill's own (the haul is paid as plain "resource" events on return).
- A fight starting while a miner is out (only an event or a break-in could queue one) pulls them aboard
  at once with the haul paid. CombatSim is not touched: DrillSim.step calls `miner.watch` every tick
  and the drill steps before combat, so no shot lands first.
- To keep drill_sim.gd from growing, the segment_done payload moved to `drill_report.gd`; the aim and
  route rules live in `miner_route.gd`. The full-run report's counters are in `tools/balance_full.py`
  (where `balance.py --full` writes its report), not balance.py itself.
Revert: as D046 (drop the two commands, DrillMiner, MinerRoute, MinerPlanner); `drill_report.gd` can
stay or fold back into `_arrive`.

## D048 (AI): Away miner numbers and bot thresholds
Tuning (`game/data/tuning/miner.json`) kept at the spec's start values: range 12 m, walk 1.4 m/s,
hatch 2 s, dig 0.25 s + 0.9 s x hardness, yield 100%, vein up to 30 cells, water 20 hp, gas 45 hp,
rockfall 35 hp after 12 fault cells (1.2 s warning), strike 30 hp; noise 0.006 per cell (about a
tenth of the drill's per-cell noise at 3 bars). A typical sortie takes 40 to 50 s. With these the
balanced bot stays at 38.3% wins (37.7% before; cap about 45%), so nothing was tuned down.
Bots (`PolicyBot.miner_*`, `MinerPlanner`): send when the front is at least miner_rows behind
(cautious 3, balanced 2, greedy 2, not the spec's 1.5), the hull above half, no fire aboard, a vein
worth miner_min_value (cautious 30, balanced 20, greedy 14 ore-equivalent, gems x3) at least 3 m off
the centre line and off the drill's own lane, through a tunnel with no pocket and fewer than 12 fault
cells; recall with the front within 1.2 rows or the miner under 40 hp. Greedy at 1.5 rows dropped
from 15.0% to 5.3% wins (pursuer deaths 35% to 58%), at 1.75 to 11.3%; at 2 it is 13.7%.
Evidence: `docs/research/m1-evidence/balance_m1c_miner.md`. Revert: greedy `miner_rows = 1.5` in
`PolicyBot.make_policy`, or `miner_on = false` to take the bots off the miner.

## D049 (AI): Hazards read as emergencies; water is teal, smoke is grey
Gemini 006 and 008 both put the hazards first ("a pixelated flame overlay"). A builder moved the fire
into `game/view/ship/room_fire.gd` with soft flame tongues, a stronger flickering light, smoke, a
ceiling haze that climbs hatches, and scorch; the lead fixed what the stills showed: the flame sprites
were centred on the floor (half of each hung into the hull below), and a near-black haze and scorch
vanished into the dark painted rooms (a debug colour proved they drew). The haze is now grey and
milky. The water's old olive silt read as mustard once it was opaque in warm room light, so it is a
dark teal-green murk, matching the HUD's blue water icons. The scorch stays dark and is still faint on
dark floors (known gap). `game/data/scenarios/hazard_demo.json` (crew automation off, a reactor fire
and a deep flood) gives repeatable stills. Revert: the colour constants in `room_water.gd` and the
haze colours in `room_fire.gd`.

## D050 (AI): World depth through the openings, and beds you pass through
Four critic reviews scored the world outside the hull lowest ("a treadmill"). The rock is the cut
plane and fills the view, so depth comes from three places (a Sonnet builder, `game/view/
depth_layers.gd`, then the lead's fixes from stills): a far wall behind every opening at 0.45 of the
camera's scroll and silhouettes of a cavern in between at 0.7 (seen in blast craters, side tunnels,
the miner's tunnel, caverns), dim dust motes in front at 1.25, and colour beds in the rock 25 to 59 m
thick (iron red, limestone, shale, basalt, ochre, green-grey; ore and gems keep their colours). The
lead's fixes: the far wall's averaged texture went flat, so its contrast is pushed back around the
tile's own mean; silhouettes sat within 6 m of the ship's own column, mostly behind the tower, so they
spread to 16 m either side and appear in 80% of 13 m slots (a debug draw on top proved they render);
dust was 32 bright specks that read as static, now 22 soft dim motes. Known: the hollow's dark room
(StructureLayer, z -25) still covers the far layers inside a structure. Revert: the constants at the
top of `depth_layers.gd`, or drop DepthLayers from main.gd and restore RockView._build_backdrop.

## D051 (AI): The miner climbs out a side hatch; a playtest input diary
Stewart (build 5c): "The miner mines the floor of the craft, he should fully exit first." The tunnel
started in the cell under the drill head, so the figure stood on the crown and dug beneath the tower.
Now the miner climbs out a hatch on the side of the hull facing the target and digs from the cell
beside the hull at its bottom row; a target below the ship goes one row down first, so the tunnel
never enters the footprint. Range is still measured from the drill head. Revert: `MinerRoute.plan`,
`MinerRoute.hatch` and the three `pos =` lines in `DrillMiner`.
Douse: his 15-minute run logged no douse command although he tried, yet the real-input self-test
(now also covering a top-deck fire, F and the button) passes. So the game now keeps a view-only
input diary in the run record (`summary.ui`: each raw left click with the UI control under the mouse
and whether it hit a DOUSE button, each F press with the worst fire), and `tools/run_report.py`
prints it, so the next run shows where the input died. F also accepts the physical key.

## D052 (S brief, AI details): FTL is a reference behind a firewall
Stewart (2026-10-22, side track): use FTL, which he owns, as a reference so chosen systems reach rough
parity of feel without working each one out from scratch; no one else's code, art, text or names in
Inner Sun; mechanics, systems, pacing and tuning shapes are fair game. How: `research_private/` is
git-ignored and holds everything taken from FTL (the unpacked data folder, exact numbers, recordings,
frames, evidence notes). `tools/ftl_unpack.py` reads the installed `ftl.dat` read-only and writes
only there. Committed files describe behavior in our own words with Inner Sun's names, and carry
Inner Sun's own target values, set from shapes and ratios, never copied numbers. The install folder
is never written to or modded. Revert: nothing to undo in the game; delete `research_private/` to
drop the material.

## D053 (AI): A behavior ledger, with observers and builders kept apart
Parity work runs through `docs/research/behavior-ledger.md`: numbered rows (ID, kind, behavior,
Inner Sun target band, evidence ID, test, a wrong value that must fail the test, status). The exact
FTL evidence behind each row sits in `research_private/ledger_evidence.md` under the row's evidence
ID. Observers (the lead, or an observer agent in the main checkout) read FTL material and write rows;
builders work in worktrees, where the git-ignored folder does not exist, from the rows alone, and
never open `docs/research/ftl-*.md` or its links. A row closes only when a test of its own kind
passes (scenario, replay, balance measure, critic still or Stewart's A/B); coverage per system is
passing rows over rows in scope (`ftl-difftest-plan.md`). The method is borrowed from the REA
reconstruction ledgers, without the tool. Revert: plain specs as before.

## D054 (AI): No REA install
REA (github.com/morluto/rea, npm `rea-agents`) is real and popular, but it is a wrapper around
disassemblers we would have to install (Ghidra with JDK 21, Windows support marked experimental),
adds about 200 tools to the agent's context, puts decompiled FTL code in the same context that
writes our game, and its browser and HAR tools have nothing to capture in FTL. The community docs,
the game's own data and watching the game cover the systems in the inventory. Revisit only for one
constant that cannot be watched, and then as a one-off, human-run, read-only look that writes down
the number and the rule. Revert: install it in a separate folder for that one look.

## D055 (AI, Stewart picks the systems): FTL parity is an M2 workstream, gated on his pick
The inventory in `docs/research/ftl-reference.md` scores each FTL system on fit with the dig, how
much of FTL's fun it carries, how close Inner Sun already is, build cost and documentation, as
value over effort: value = fit x fun x (4 - closeness) / 4, effort = cost + (3 - docs). Stewart picks
the systems he cares about from the top 10; nothing is built before that. The workstream starts
when M1d closes (it touches `game/sim`, which M1d is still changing), observes with his recorded
FTL runs first and computer use second, and runs as builder rounds from ledger rows (`PLAN.md`
section 10, `docs/plans/M2_parity.md`). Revert: drop section 10; the research files stay as notes.

## D056 (S): FTL parity scope is inventory 1 to 6
Stewart (2026-10-22): "Pick the top 6 from the inventory as ranked." In scope: rising upgrade
prices, rewards that grow with depth in tiers, manned stations, doors and purging, stores that roll
their stock, node environments. Ledger rows L-UPG, L-RWD, L-MAN, L-DOR, L-STO and L-ENV are in scope;
L-PUR, L-EVT and L-FIRE stay as format examples (L-FIRE-01 is still used as a yardstick by
L-DOR-02). Purging (L-DOR-02) is a new Inner Sun rule and gets its own decision in step P2. Revert:
Stewart widens or narrows the pick; update the inventory marks and the ledger scope line.

## D057 (S asked, AI decided): Gemini 4 Argon is kept as a long-context numeric auditor
Stewart (2026-10-22) asked for one exploratory consult of Google's new `gemini-4-argon` on the whole
project. It got 298k tokens of committed state (`review/consults/2026-10-22_gemini-4-argon.md`) and
was asked where it adds value and to prove its number-checking. Of 11 findings, 8 held up when the
lead checked them against the code, including real bugs the build sessions missed (the blast
planner ignores the 50% blast yield, the greedy bot buys a weapon it cannot power, a balance-report
anomaly, the state hash leaving out max hull and weapons) and real errors in this session's ledger
rows; 2 were overstated; 1 was false and stated with high confidence; one had a 10x unit slip. Kept,
in three places only, always as leads that the lead verifies before acting: (1) a math audit of
ledger rows and builder specs before dispatch (parity step P2 to P3), (2) a whole-repo cross-layer
audit before a milestone gate, (3) an anomaly read of balance reports. Not for code, writing, taste
or design. Tool: `python tools/gemini_audit.py` (about 1 USD a run, logged in `docs/SPEND.md`).
Revert: stop running it; nothing depends on it.

## D058 (S asked, AI decided): the parity workstream starts now, on its own branch
Stewart (2026-10-22) cannot playtest build 6 until the evening and wants the most done meanwhile,
with the next session opening the parity work as a child session. Build 6 is already exported
(`m1d-playtest-6`), so his playtest is unaffected by anything on a branch. So the next session starts
the parity session at once (a separate session in its own worktree and branch) instead of waiting
for M1d to close (amends D055). Rules: parity merges into main only after M1d has triaged and
replayed his build 6 runs; nobody exports over `builds/InnerSun.exe` before he has played it; the
files M1d splits (`docs/plans/M1d.md`, "Ready to dispatch") are left alone by the parity session
until the split is on main. Revert: the parity session stops and its branch waits.

## D059 (AI): Gemini audit fixes, and two M1d view items before build 6 is played
The verified Gemini audit bugs (D057) are fixed on main, each with a test (`docs/BACKLOG.md`, "Gemini
audit"): the bots' blast planner now scores what a blast pays (half of each material, rounded
down); the greedy bot counts a weapons upgrade toward a new gun only if it can buy it; balance
reports take row 0 from the run's real start (`RunState.start_resources`, set after requisitions)
instead of the end-of-run maximum hull; `ShipWorld.state()` hashes `hull_max` and the weapon list;
scenario rock heat matches the Crust (0.033 C per m). The rival power finding was tested and is not
a bug. The determinism hash changes (state shape and scenario heat); balance moves because the bots
blast less and buy fewer dead guns; both are re-recorded. Two view items from the M1d plan: the
PARKED notice draws in amber (a choice, not an emergency), and the scorch after a fire uses a
multiply blend so it darkens dark floors instead of fading into them. Balance runs now record each
run's final hash, and `tools/balance_compare.py` compares two runs seed by seed (the oracle for the
file split). Build 6 is untouched: nothing here is exported before Stewart plays it (D058). Revert:
`git revert` the commit; the bot fixes are independent of each other.

## D060 (S asked, AI details): a short scanner and capped steering until the helm is upgraded
Stewart (build 6, 2026-10-22): "slightly higher ore density but the scanner shows much less (it can be
upgraded later)... I don't know that the horizontal maintain depth should even be possible until an
upgrade is unlocked. It's too powerfull from the start." He swept whole segments sideways at hold
depth because the scanner showed all 30 m ahead and the full 32 m width. Now: the seismic scanner
shows rock only within a range of the drill head that grows with the helm's installed bars
(`drill.scanner_range_m_by_helm`, start about 10 m, 16 m at 3 bars); beyond it the screen is static.
The heading is capped at 45 degrees until the helm has 3 installed bars (the existing helm upgrade,
120 ore), then reaches 90 (hold depth) as before (`drill.max_heading_deg_by_helm`). Ore richness rises
about 20% so a shorter, choosier dig still pays. Bots keep reading the whole grid (they are not
judged on what they can see) but obey the heading cap; balance is re-run. Revert: set both tables to
their old single values (30 m and 90 degrees) and the richness factor to 1.

## D061 (S): the light drill becomes a spine tower in M2
Stewart (2026-10-22, after build 6, verbatim): "Go with A, the spine tower, for the M2 ship redesign. Log
it as a decision and plan it; don't build it yet." Option A of `docs/plans/ship_redesign/README.md`: a
ladder spine down the middle with small pods off both sides in a tapered hull (narrow bridge, widest at
the reactor, narrowing to the drill); a door on every pod, two airlocks that vent a room to the rock, a
medbay and a dive lock (the miner's exit); the same six systems and controls. Planned as M2 workstream
S (`PLAN.md` section 11, `docs/plans/M2_ship.md`), after the parity merge (doors, purge) and a Gemini
credit top-up (art). Revert: keep today's 2 x 3 layout; the schematics stay as notes.

## Parity branch numbering
The FTL parity branch (`claude/blissful-neumann-c52d9b`) numbers its decisions from D080, so they
never collide with the decisions M1d adds on main at the same time (D059 onward).

## D080 (AI): Purging a room is Inner Sun's venting (L-DOR-02)
Every room gets a purge vent to the bore, a player command like doors (`{"type": "purge", "room",
"open"}`). An open purge dumps the room's air: its fire dies in a few seconds (slower while a linked
neighbour burns) and no fire can start or spread into it; the rock's heat pours in at a breach-like
rate, so near the surface (rock cooler than crew-harm heat) purging is free and from about row 9 a
purged room hurts crew within 10 to 20 s. Heat stays our air: the cost of the tactic is heat, not
suffocation. Gas from the rock was left out (it would need the drill module). Purge state lives in
`HazardSim` so the world hash covers it. Built in round 2 with one addition by the builder, kept by
the lead: the vent's conductance grows with the room's open doors and hatches
(`heat.purge_draught_factor`, bore gas drawn in as fast as they let air out), because a fixed
conductance cannot put every room in the 10 to 20 s band with doors open and closed; so closing the
doors around a purge still matters. Revert: drop the command and the hazard term (or set the
draught factor to 0).

## D081 (AI): Parity round 1 economy, the design choices behind the rows
Upgrade ladders replace flat prices, with room to climb: helm 4 bars, bracing 6, weapons 5, drill 6,
coolant 5, reactor 14 (from 3, 4, 4, 5, 4 and 12), first purchasable bars at about two thirds of the
old flat price and each step adding about half the first step again; reactor bars cheaper than
system bars and flat in pairs. No per-visit cap: the price is the brake. Ore and gems rewards come in
three tiers on a base that grows by row (a row-1 fight pays about what it did, row 13 about 4 times);
supplies do not scale. Stores roll 2 or 3 of 4 sections (systems, gear, weapons, crew) by weight,
offers by rarity that rises with depth, supplies always on sale but in limited stock, hull repair 2,
3 and 4 ore a point by depth band, gear and weapons sell back at half. Bots adapt after M1d's split
(reward values, stock clamps, ladder sums). Revert: the store, systems, gear, weapon, event and
tuning data of round 1.

## D082 (AI): The parity build ships easier than the band; Stewart's playtest decides the tuning
After all six parity systems and main's build 6 changes, the balanced bot wins 58% (38% before;
the band is 10 to 30%), the greedy bot 19%, the cautious 48%. Most of the rise came with round 4
(fight rewards that grow with depth, bots that value them) and manning bonuses; environments and
D060's richer ore added a little. Tuning it down now would be guessing at what a human finds easy,
and D039 and D044 already kept the bots above the band until Stewart had played. Levers, all data:
`economy.reward_*` (L-RWD-05 has room down to 15%), the gate fight, `combat.loot_boss_scale`,
`systems.station_skill_gain`, environment chance. Revert: lower the reward bases first.

## D083 (AI): Some parity ratios match the reference on purpose
`python tools/parity.py` (local only; it compares Inner Sun's measures with the private reference and
writes the side-by-side to `research_private/`) finds all 12 measures in their ledger bands, and eight
bands that also contain the reference's own ratio: the reward growth over the layer, the three tier
means, the hull repair rise with depth, the sell-back fraction, the reactor price step and the top
skill's manning gain. D052 allows matching shapes and ratios (never exact values, names or text), and
each of these rows is anchored on Inner Sun's own numbers (today's fight haul, D025's depth
richness, Inner Sun's skill spread), so the values stay. The ones that differ on purpose: upgrade
ladders climb much more gently, reactor bars cost a larger share of a system bar, closed doors hold
fire back harder, shelf stocks are smaller. Revert: move a band off the reference ratio and retune.

