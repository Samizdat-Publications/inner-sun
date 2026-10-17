# Progress

Updated: 2026-10-17, M1c playtest build 5 ready (the away miner, D046), Stewart has not played build 4 yet.

## M1c status: playtest build 5 ready for Stewart
- **Build:** `builds/InnerSun.exe`, launched by `Play Inner Sun.bat`: `m1c-playtest-5` (milestone zip
  `builds/milestones/m1c-playtest-5/`). Build 4 was never played, so build 5 replaces it: everything
  in build 4 below, plus this session's work. Interim build `m1c-playtest-4c` (7cd11ea) is the polish
  without the miner.
- **The away miner (D046 to D048; sim 3be827f, view a1337c1):** G arms the order for the crew member
  selected on the crew cards; a click on the rock or the scanner within 12 m of the drill head sends
  them. The drill parks; they walk to the drill room, climb out, dig a tunnel by hand, mine out the
  vein at the target and walk home. While out they man nothing; gas, water and fault rock hurt them;
  the haul pays only on return (lost if they die); G recalls. Card, figure with headlamp, haul tag,
  OUTSIDE crew card, alert and PARKED notice, scanner dot, help paragraph. Seen in stills
  (`docs/progress/030`, and `harness/out/shots_m1d/miner/t20.png`).
- **Polish (1be191c):** a requisitions toast lists what the owned requisitions put aboard at the
  start of the first dive (`docs/progress/028`); the rock tile repeat is broken by a second, turned
  sample blended by noise (critic 007); structures take an optional "light" block, so the crystal
  hollow is a blue-lit cave instead of a black blob (`029`); the blast range ring draws only inside
  the world view; the map's front shadow no longer makes the "triangulation failed" error; the map's
  pursuit label moves away from the player's node. The map's structure marks were seen in the
  gallery's `map_mid` still.
- **Checks:** `check: ok` (339 tests); determinism ok, hash e4c82e3d6d55a625 at tick 1200 (headless and
  Movie Maker, `python tools/determinism.py`) and the same hash in the exported build's own check; the
  exported build plays a whole bot run to its end (FINAL tick 36000).
- **Balance with the miner (300 runs per bot, `docs/research/m1-evidence/balance_m1c_miner.md`):**
  balanced 38.3% wins, cautious 27.0%, greedy 13.7%; balanced sends 1.2 miners a run (62% of runs);
  no miner deaths; the haul is about 2% of all ore.
- **Not judged by a person yet:** no hands-on play by the lead (Stewart away, computer use needs his
  click), no critic run on the miner. Stewart's run of build 5 is the first real test of G.

## M1c build 4 (exported, never played: build 5 contains it)
- **Build:** `builds/InnerSun.exe`, launched by `Play Inner Sun.bat`. The build Stewart plays is
  `m1c-playtest-4b` (exported from 1b4b202, milestone zip `builds/milestones/m1c-playtest-4b/`); the
  Gemini-reviewed build is `m1c-playtest-4` (e1ffb36), the same game without the stop-notice fix.
- **Round A, the drill says why it stopped (4d8a318):** "DRILL HAS NO POWER: press R", "BIT BROKEN:
  press B (n spare)" or no spares, fitting, overheated, wrecked, at the wall; the notice waits 1.5 s
  and sits at the top of the world (seen in a still). Help lists what every system does.
- **Round B, dig verbs (02a5d7c, 3764711, D035 to D039):** heading to +-90 (hold depth), turn rate and
  side cutting scale with manned helm bars; fault rock and rockfalls that bracing layers soak; blast
  (F2, click the rock: 14 m range, half the ore shatters); douse (F, one coolant); steering keys A, D
  (15 degree steps), S, Shift+A or D; the blast card, scanner range ring, rockfall and douse effects,
  power-row job lines.
- **Round C, buried structures (7683edf, 8699be6, eb64f36, D041 to D044):** old mine works, a Soviet
  rig module, a crystal hollow (sometimes a trader), as data stamps; crates of loot, break-in banner
  with a TOPSIDE line, a codex entry, five structure events, a mid-segment store and event; scanner
  outlines and map marks.
- **Round D, research and requisitions (c3bc966, D040):** every run earns research (rows, new codex,
  fights, the gate, ore); the TOPSIDE SUPPLY screen buys six permanent starting upgrades; they ride
  in the replay header.
- **Rock (0ec9d6a, D045):** fractured blocks with fading cracks instead of wavy beds.
- **Checks:** `check: ok` (306 tests); determinism ok, hash e56bb4f3272aeb65 at tick 1200, both in
  `python tools/determinism.py` (`docs/research/m1-evidence/determinism_m1c.txt`) and in the exported
  build's own check; the exported build plays a bot run to its end.
- **Perf (UNTRUSTED, contended):** two captures gave a 1% low of 60.9 and 59.3 fps (the second from only
  2 perf samples), GPU 0.9 ms. That is at or just under the 60 fps floor, measured while other work ran
  on this PC: re-measure with `python tools/perf.py --mode run` on an idle machine before tuning.
- **Balance (300 runs per bot, `docs/research/m1-evidence/balance_m1c_structures.md`):** cautious 26%,
  greedy 15%, balanced 38% wins; medians 18 to 22 min; about 4 to 6 structures entered a run.
- **Critics:** Gemini 006 4.5 (before the rock fix), 007 6.1 (world outside the hull 3 to 6). Triage in
  `review/LEDGER.md` 22 to 32.

## Known gaps (M1c)
- **No hands-on play by the lead in M1c:** computer-use access was declined (build 4) and Stewart was
  away (build 5), so the new keys were checked by tests (`ui_selftest`, `test_dig_verbs_view`,
  `test_miner_view`) and stills, not by a person. Stewart's run of build 5 is the first real test.
- The balanced bot wins about 38% (the band is 10 to 30%): kept on purpose until Stewart has played
  (D039, D044). Levers: the gate, charge prices, `douse_fire_level`, `structure_chance`.
- About 5 structures a run may be too many to feel special (lever: `structure_chance`).
- Not built: fights from structure events (ruled out by the lint, D042). After a mid-segment fight,
  CombatSim returns the run to "idle", not "drill" (found by the miner builder; older).
- Critic M2 items: dense small text and a spreadsheet store, hazards and crew that need more life,
  rooms hard to tell apart (ledger 24 to 31); the rock tile repeat (32) is fixed in build 5, not yet
  re-judged by a critic.
- `ship_view.gd`, `main.gd`, `scanner_panel.gd`, `drill_sim.gd`, `run_state.gd` and some new files are
  over 400 lines, now also `drill_miner.gd` (497) and `policy_bot.gd` (467).

## Exactly what is next
1. Stewart plays build 5 and writes notes at the top of `docs/STEWART_FEEDBACK.md`.
2. Next session (M1d, prompt in `HANDOFF.md`): replay his runs, triage, iterate, new playtest build.

## M1b (built, playtested by Stewart 2026-10-16: build 3)
- **Build:** `builds\InnerSun.exe` (exported from 88d916d, launched by `Play Inner Sun.bat`), milestone
  zip `builds\milestones\m1b-playtest-3\`, tag `m1b-playtest-3`.
- **Round 1, controls for a human (970e5d1):** hand-tested in a real window: help on the first run (H),
  the map holds the world, power works in dossiers, scanner click-to-steer holds a course, B fits a
  new bit, HOSTILE AHEAD, the fight pauses with a banner, death text names the killer, flood hint.
- **Round 2, the digging economy (a8965a2):** longer segments, coal, iron, copper, silver, gold,
  quartz, amethyst, emerald by depth, gas pockets (fire), surveys on every map node, `deposit` nodes,
  ore buys gear (tungsten and diamond heads, plating, pumps) and upgrades, gems buy supplies and crew,
  value-seeking bots.
- **Round 3, see the dig (50a1c78, 5742da5):** zoomed-out drilling camera with wheel zoom, rock with
  strata, ore visible in the main view, murky water, crew with bright harnesses, pickup text, the THIS
  DIG tally, ore colours on the scanner, survey marks on the map, gear lines in the store.
- **Tuning (d5f60a4, D029 to D033):** 14 rows, three trading posts and two fights per path, depth
  pressure (pursuer, gas, water, rival_raider from row 7), segments about 80 s. 300 runs per bot:
  wins cautious 10%, greedy 12%, balanced 23%; median runs 17 to 21 minutes; deaths over rows 7 to 13
  (`docs/research/m1-evidence/balance_m1b_tuned.md`).
- **Checks:** `check: ok` (231 tests), determinism ok, perf 1% low about 85 to 100 fps (contended).
- **Critics:** Gemini 5.6 before M1b (`review/critiques/004_gemini.md`), 6.8 on build 3
  (`005_gemini.md`: readability 8, crew 7, UI 8; the world outside the hull still 3).
- **Making-of page:** https://claude.ai/artifact/UJjDA4PJkSXMKjpg2zxQpc (source `docs/making-of/index.html`).
- **Hands-on tool:** `python tools/play.py [--exe] -- <game args>` (a normal focusable window in a job
  object, its own profile folder).

### Known gaps after M1b
- Critic 005's top problem: the rock texture's horizontal wavy bands read as "scrolling wallpaper";
  it wants chunky, jagged, varied rock, a less rectangular ship silhouette, and darker surroundings
  lit by the ship's own lights. Taste note: keep ore visible within the floodlights (Stewart wants to
  see the dig), so darken only beyond them.
- Only two hazard events exist, so hazard nodes are often empty; the gate boss is still the top killer
  for the balanced bot (a bracing-piercing gate weapon is one option).
- Wheel zoom and the brightened pickup text were never seen in a still. `ship_view.gd`, `main.gd`,
  `scanner_panel.gd`, `drill_sim.gd`, `run_state.gd` are over 400 lines.
- One "triangulation failed" polygon error at startup in windowed runs (probably older).

## M1a (built, playtested by Stewart 2026-10-16)

Exit criteria met, with one exception: the Gemini video critic could not run at the gate (Gemini
spend cap). Perf meets the 60 fps floor after D023 (whole run: p99 12.7 ms, 1% low 78.5 fps), measured
with light background GPU use, so the tool's strict "trusted" flag is off.

## The playtest build
- `builds\InnerSun.exe`: playtest build 2 (exported 2026-10-16 from commit 04b5a77, the first
  build plus the drilling perf fix D023), launched by `Play Inner Sun.bat` (`builds\PLAYTEST`
  marker written 01:53). Labeled copies for the making-of record: `builds\milestones\m1a-playtest\`
  (tag `m1a-playtest`) and `builds\milestones\m1a-playtest-2\` (tag `m1a-playtest-2`).
- How to play: README.md ("How to play"). Every run Stewart plays is saved for replay in
  `%APPDATA%\InnerSun\runs\` (`python tools/replay.py --latest`, or `--watch` to see it).

## What M1a delivers
- **A whole run:** a 10-row node map of the Crust (event, cavern, hazard, store, fight, gate), travel
  by drilling segments (steering, drill power, heat, bit wear, noise, ore and gems, water pockets,
  about 25 to 35 s each), a pursuer that advances with time and noise and strikes when it catches
  you, death (hull, crew, flooding) or the layer gate, a death report, the codex, a saved profile.
- **The ship:** six painted rooms with systems and power (reactor bars, damage, overheating, coolant
  billed in units, manning, bracing layers); fire, water and heat spread room to room; three crew with
  job AI, recruitment and permadeath; power returns after repairs (D018).
- **Combat:** real time with pause against rival rigs and the gate boss; borer turret, charge launcher,
  thermal lance; bracing, evasion, system damage, fire and breach chances; enemy AI; loot; flee.
- **Events and store:** 12 dossier events with redactions that lift with the codex, 9 codex entries,
  24 TOPSIDE lines, a store (supplies, repairs, upgrades, the lance, a hire).
- **Presentation:** the painted pulp art style (D017), a readable HUD, node map, dossier, store,
  death and codex screens, the combat view with weapon cards, placeholder sound (ElevenLabs) and an
  audio director.
- **Proof:**
  - `python tools/check.py`: 188 tests pass, selftest ok.
  - Determinism: the scenario, and a whole run under Movie Maker matching a headless run
    (`docs/research/m1-evidence/determinism_m1a.txt`). Run records replay exactly.
  - Balance: three policy bots; 1,002 full runs in about 12 minutes after D021 (balanced 25%,
    cautious 21%, greedy 13%), then a 300-run check after D022's hazard pressure (balanced 19%,
    cautious 16%, greedy 12%; fires in 97 to 100% of runs; top killer 42%). The post-D022 sample is
    small; re-run 1,000 before tuning further (`docs/research/m1-evidence/`).
  - The blind critic (category means): 3.8/10 (M0 view), then 5.8, then 6.1 at the gate (Opus).
    The code changes for its FIX items are in; the critic-003 fixes (zoom, combat framing, labels)
    were checked in shots (`docs/progress/019`, `020`) but not re-reviewed by a critic. Fires are
    frequent in balance runs (D022) but no captured still of the final build shows one. DEFER items:
    `review/LEDGER.md`.
  - The exported build plays a whole bot run to its end.

## Known issues (M1a, kept as history)
- **Perf:** after D023 the whole-run frame time is p99 12.7 ms, 1% low 78.5 fps, average 196 fps
  (`docs/research/m1-evidence/perf_run_mode_after_fix.json`). Draw-step spikes of 11 to 13 ms remain
  occasionally (cause not found); a new segment's rock fills in over about a second. The perf tool
  marks every reading on this busy PC as contended (headless Chrome, Claude); a reading on an idle
  machine would make it formally trusted.
- **Interactive play was not tested with real mouse and keys** (it would take over Stewart's screen).
  Every control is covered by code paths and tests, and bots drive the same commands, but Stewart's
  playtest is the first real hands-on test. Keyboard focus: tool windows are created unfocusable;
  exported builds override that (`no_focus.template=false`, verified in the exported game with
  `--print-window-settings`: `no_focus=false template=true`) and boot pulls the window to the
  front. If keys still do nothing, clicking the window gives it the keyboard (README says so).
- The Gemini critic and new Gemini art were blocked by the Gemini monthly spend cap in M1a (it worked
  again from M1b). No PixelLab key.
- Capture windows flash on screen for about a second at startup; keep windowed runs batched.
- RAM on this PC was nearly full (leftover node processes from Claude sessions); git pushes failed
  intermittently until it freed up.
- Non-blocking polish and the balance report's weak spots: `docs/BACKLOG.md`.

