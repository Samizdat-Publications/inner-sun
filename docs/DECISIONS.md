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
