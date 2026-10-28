# Progress

Updated: 2026-10-27 on the parity branch (parity playtest build `m2p-parity-2`); main's latest build is
playtest build 7 (`m1d-playtest-7`) from Stewart's build 6 notes.

## Build 7 (2026-10-22 night): Stewart's build 6 notes
- **His run** (seed 721713, 8:11, dead at row 2 to the first rival) replays exactly from the
  `m1d-playtest-6` tag; notes and triage: top of `docs/STEWART_FEEDBACK.md`, `docs/plans/M1d.md`.
- **Refused power says why:** his eleven T presses asked a wrecked reactor for bars it did not have.
  Now a refused power change is a `bad_command` with a reason, the power board flashes the reactor and
  the row, a callout says what fixes it, and the DOUSE button says "NO FREE POWER" when T cannot help.
- **In-fight crew hint:** the crew hint could never fire in a fight; `crew_fight` does, 8 s in.
- **A pause you can see:** the world freezes (crew, flames, particles) and dims under "PAUSED: SPACE
  TO RESUME" (seen in a still, `docs/progress/041`).
- **D060:** the scanner sees about 10 m around the drill head (16 m after the helm upgrade); steering
  is capped at 45 degrees until the helm upgrade unlocks hold depth; Crust ore about 19% richer
  (`ore_richness_mult` 1.3). Scanner seen in a still, `docs/progress/040`.
- **Also in build 7 from today:** the repaired drill crown (lower, under the hull), the dead DOUSE
  button fix, the amber PARKED notice, the multiply scorch, the Gemini audit fixes.
- **Balance (100 per bot, `docs/research/m1-evidence/balance_m1d_d060.md`):** balanced 50%, cautious
  29%, greedy 26% wins. The bots find it easy; Stewart died at row 2 of his only run. Tuning stays on
  hold until his build 7 run (D039, D044).
- **Checks:** `check: ok` (396 tests); determinism `e30883214e637d19` at tick 1200 (the D060 builder's run and the exported build's own check); the exported
  build plays a whole bot run to its end (FINAL tick 36000, hash ebb9e7283ae600d2).
- **Critics:** Gemini 011 on build 7 (seed 721713): 6.5 (keep playing 8, UI 4); top items: the HUD
  border crowds the ship, the font, faint fires, square rock chunks, weak hits (`review/LEDGER.md`
  46 to 50). Claude 010 on the interim build: 5.8; the flat miner sprite (39), vague HAZARD AHEAD (41).
- **Not in build 7:** crew click and drag-select (the parity session's round 6a), the spine tower ship
  (D061, M2 workstream S).

## M1d interim round (2026-10-22), before build 6 is played
- **Build 6 untouched:** `builds/InnerSun.exe` is still `m1d-playtest-6`; nothing exported (D058).
- **Gemini audit fixes, each with a test (D059, `docs/BACKLOG.md` "Gemini audit"):** the bots' blast
  planner scores what a blast pays; the greedy bot no longer buys a gun it cannot power; balance row 0
  is the run's real start; the state hash covers max hull and weapons; scenario rock heat matches the
  Crust. Rival power vs restore was tested and is not a bug.
- **View:** the PARKED notice is amber (seen in a still, `harness/out/shots_d059_miner/t20.png`); the
  scorch uses a multiply blend (a loud-colour debug still shows it draws where it should; on the
  darkest room art it still reads subtly); a dead DOUSE button could stay on screen after a fire
  dropped under the douse floor, so clicks and F did nothing: fixed (likely part of Stewart's "douse
  isn't doing anything"; build 6's input diary will tell).
- **Oversized files split, zero behaviour change** (spec `docs/plans/specs/m1d_split.md`): drill_sim,
  run_state, drill_miner, policy_bot, ship_view, main, scanner_panel, crew_sprite are all under 400
  lines. Oracle: check ok, same determinism hash, and 60 of 60 balance seeds end in the same final
  hash (`python tools/balance_compare.py`; balance runs now record `final_hash` per run).
- **Hashes:** determinism `e30883214e637d19` at tick 1200 (headless and Movie Maker); changed from
  e4c82e3d6d55a625 because the state now hashes max hull and weapons and scenario rock heat changed.
- **Balance after the fixes (100 per bot, `docs/research/m1-evidence/balance_m1d_audit.md`):**
  balanced 47%, cautious 24%, greedy 12% wins (balanced was 38%: the band is 10 to 30%, held high on
  purpose until Stewart has played, D039, D044). Balanced sends a miner in 58% of runs.
- **Drill crown art (Stewart's note):** round 1 (8 fresh candidates) all had the same defect; round 2
  repaired the original's cutter row only (`harness/out/crown_candidates/round2/pick_round2.png`).
  Waiting for his pick between Repair A (R2-01) and B (R2-03); not fitted yet. About 3.36 USD spent.
- **Checks:** `check: ok` (377 tests).
- **FTL parity** runs as its own session on branch `claude/blissful-neumann-c52d9b` (rounds 1 to 3
  merged there, 388 tests); it merges into main only after the build 6 triage.

## Parity branch status (2026-10-27, branch `claude/blissful-neumann-c52d9b`, not on main)
- **All six picks built (D056):** 23 ledger rows for the six picks, every number, shape and rule row
  passing with its wrong value failing (the ledger holds 28; the 5 L-PUR, L-EVT and L-FIRE rows are
  format examples outside the pick, still open) (`python tools/ledger.py`, `docs/research/parity_report.md`): upgrade ladders
  4/4, tiered rewards 5/5, manned stations 3/3, doors and purging 3/3, rolled stores 5/5, node
  environments 2/2. Open: the feel row L-DOR-F1 (critic rubric and Stewart's A/B).
- **Rounds:** 1 economy (D081), 2 doors and purge (D080), 3 manned stations, 4 bots and the spend and
  income measures, 5 environments, 6a views (door, hatch and vent clicks, crew click and box select,
  station skill on the cards, environment marker, blind scanner, hidden rival); plus pressure doors.
  Gemini audited the specs of rounds 1 to 3 before dispatch; rounds 4 and 5 were checked by hand
  before dispatch (credits out) and audited by Gemini after the merge on 2026-10-27 (one bot bug fixed,
  one wrong value replaced). Every finding was checked before acting.
- **Checks:** main merged in up to build 7 and D060 (`5b98b6f`); `check: ok` (432 tests); determinism ok, hash
  d0016abef9fd11fe at tick 1200.
- **Balance (900 runs, `docs/research/m1-evidence/balance_parity_final.md`):** wins cautious 48%,
  greedy 19%, balanced 58% (38% before parity; band 10 to 30%). Easier, mostly from fight rewards and
  manning; left for Stewart's playtest to judge (D082). Spend share 64%, income share 22% (the balanced bot, in band; the greedy bot's income share is 14%).
  Re-run on the shipped build m2p-parity-2 (2026-10-27): identical.
- **Perf (UNTRUSTED, contended):** whole run on the NVIDIA GPU, average 126.8 fps, 1% low 56.3, p95 12.2 ms,
  GPU 1.2 ms (build 6 measured 144 and 56 the same way); re-measure on an idle PC before the merge.
- **Playtest build:** `m2p-parity-2` (2026-10-27: framed shut doors, bigger map icons, the bot reserve fix; `m2p-parity-1` kept as a milestone zip), exported into this worktree's own `builds\` (main's
  `builds\InnerSun.exe` untouched). Merge into main waits for M1d to close (D058).

## Side track (2026-10-22): FTL parity planned (history; superseded by the section above)
- FTL (1.6.14, owned on Steam) is now a reference behind a firewall (D052 to D055): community survey
  and a scored inventory of 35 systems (`docs/research/ftl-reference.md`), a behavior-ledger format
  with 15 example rows (`docs/research/behavior-ledger.md`), observation and differential-test plans,
  `PLAN.md` section 10 (an M2 workstream) and its checklist `docs/plans/M2_parity.md`. No REA install.
- FTL's data folder is unpacked privately in `research_private/` (git-ignored;
  `python tools/ftl_unpack.py` regenerates it). Nothing from it is committed.
- **Stewart's pick (D056):** inventory 1 to 6 (rising upgrade prices, rewards by depth in tiers,
  manned stations, doors and purging, rolling stores, node environments). Per D058 the next session
  starts it at once as a separate session in its own worktree; it merges into main only after M1d has
  triaged build 6. Prompts: `HANDOFF.md` (the newest "Next session" and "Side track: FTL parity").
- **Gemini 4 Argon consult (D057):** one whole-repo audit; 8 of 11 findings held up when checked, among
  them real bot and report bugs (`docs/BACKLOG.md`, "Gemini audit"), one was false. Kept as a verified
  numeric auditor (`python tools/gemini_audit.py`); record in `review/consults/`.
- `game/sim`, `game/view` and the M1d plan were not touched; `check: ok` (368 tests).

## M1d status: playtest build 6 ready (Stewart's first build 5c notes)
- **Build:** `builds/InnerSun.exe`, launched by `Play Inner Sun.bat`: `m1d-playtest-6` (milestone zip
  `builds/milestones/m1d-playtest-6/`): build 5c plus the fixes below.
- **His build 5c run** (seed 258521, 15 minutes, row 2 of 14, abandoned when his PC froze) and his
  live notes are at the top of `docs/STEWART_FEEDBACK.md`, with what the run record shows.
- **Fixed from his notes:** the miner climbs out a side hatch onto the rock instead of digging the
  cell under the tower (D051); the away miner is no longer also drawn inside the drill room; the
  miner's aim says what a click would bring home ("~12 ORE +2 GEMS", "BARREN: STRAIGHT BACK", "GAS ON
  THE WAY"; unit-tested, not yet seen in a still); one-time TOPSIDE hints for 14 verbs including
  pause, parking ("the drill parks itself"), buried structures ("cut in for crates", also a second
  line on the scanner label) and douse, each with a glow on its control, once per profile, never in
  bot or replay runs (`game/view/hud/hint_director.gd`).
- **Douse not found:** none of his douse presses reached the game, yet the real-input self-test
  passes for his exact case. Build 6 records an input diary in each run record (`summary.ui`: raw
  clicks with the control under the mouse, F presses); `python tools/run_report.py` prints it. Read it
  first after his next run.
- **The freeze:** the game measured 144 fps average, 1% low 56 in a miner sortie. Three stray
  `python -` processes from 15 October were each spinning a CPU core, and the 5c export's bot run was
  still playing during his first minutes. Stewart was given the command to stop the strays.
- **Checks:** `check: ok` (368 tests); determinism ok (e4c82e3d6d55a625 at tick 1200, unchanged); the
  exported build plays a whole bot run to its end (FINAL tick 36000, hash 430099885b028e6e: changed from
  5c because the bots' miner now uses the side hatch).

## M1c status: playtest build 5c ready for Stewart
- **Build:** `builds/InnerSun.exe`, launched by `Play Inner Sun.bat`: `m1c-playtest-5c` (milestone zip
  `builds/milestones/m1c-playtest-5c/`): build 5b plus world depth (below). `m1c-playtest-5b`
  (55ddd95) is build 5 plus the hazard visuals and the scanner fix.
  `m1c-playtest-5` (bc3c571, `builds/milestones/m1c-playtest-5/`) is the same without them. Build 4 was never played, so build 5 replaces it: everything
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
  exported build plays a whole bot run to its end (FINAL tick 36000). Build 5b (55ddd95, view-only
  changes) gives the same hashes: e4c82e3d6d55a625 at tick 1200 and fab7ad14f1e5eb9c for the full run;
  so does build 5c (d2319b2).
- **Balance with the miner (300 runs per bot, `docs/research/m1-evidence/balance_m1c_miner.md`):**
  balanced 38.3% wins, cautious 27.0%, greedy 13.7%; balanced sends 1.2 miners a run (62% of runs);
  no miner deaths; the haul is about 2% of all ore.
- **Build 5c addition, world depth (D050, ledger 34; a Sonnet builder, then the lead's fixes):** a
  far wall that scrolls at 0.45 of the camera behind every opening (blast craters, side tunnels, the
  miner's tunnel, caverns), cavern silhouettes at 0.7 between, soft dust in front at 1.25, and colour
  beds 25 to 59 m thick in the rock (ore and gems keep their colours). Seen in `docs/progress/035`.
  The far layers only show through openings by design; a structure's dark room still covers them.
- **Critic:** Gemini 008 on build 5 (seed 41, a 4-minute bot run; the critique never mentions the miner): 5.6
  (007 was 6.1; scores swing a point). Top items: fire and flood look cheap (second review in a row),
  the world outside is a treadmill (fourth), art styles fight, crew stand mid-room, tiny typewriter
  text. Triage in `review/LEDGER.md` 33 to 38; fire visuals and parallax rock lead the next visual pass.
- **Build 5b additions:** the scanner's blast word is shortened ("BLAST NOT READY" instead of the
  clipped "BLAST: POWER WEAPO", found by the QA audit). Hazard visuals (D049, ledger 25 and 33; a
  Sonnet builder, then the lead's fixes from stills): soft flame tongues that grow with the fire and
  sit on the floor, a stronger flickering fire light, rising smoke and a grey ceiling haze that climbs
  hatches to the room above, deeper water that hides the machinery in a dark teal murk (was olive,
  which read as mustard). Seen in `docs/progress/033` and `harness/out/shots_m1d/haz4/`. The scorch
  after a fire is still faint on dark floors (known gap). `hazard_demo` scenario for repeatable stills.
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

