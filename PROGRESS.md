# Progress

Updated: 2026-10-16, M1b in progress (Stewart's first playtest, D024 "digging is the game").

## M1b status
- **Round 1, controls for a human: merged and pushed (970e5d1).** Hands-on check by the lead in a real
  window with real keys and mouse: help opens on a fresh profile, the map holds the world ("PAUSED:
  MAP"), power works inside dossiers (option requirements light up), scanner click-to-steer holds a
  course, HOSTILE AHEAD warns, the fight pauses with a banner, and a prepared fight was won. Open bug:
  the borer would not aim at the room the charge launcher already targets (in the round 3 spec).
- **Round 2, the digging economy (`docs/plans/specs/m1b_dig_sim.md`): a builder-opus agent is on it.**
- **Round 3, see the dig (`docs/plans/specs/m1b_dig_view.md`): starts when round 2 merges.**
- **Gemini baseline critic works again:** `review/critiques/004_gemini.md`, average 5.6 (world outside
  the hull 3, hazards 4: water looks like a placeholder box). Folded into the round 3 spec.
- Hands-on testing tool: `python tools/play.py [--exe] -- <game args>` (a normal focusable window in a
  job object, its own profile folder).

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

## In flight
Nothing. Everything is committed and pushed (check `git status`, `git log origin/main -1`).

## Known issues
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
- The Gemini critic and new Gemini art are blocked by the Gemini monthly spend cap
  (`docs/NEEDS_STEWART.md`). No PixelLab key.
- Capture windows flash on screen for about a second at startup; keep windowed runs batched.
- RAM on this PC was nearly full (leftover node processes from Claude sessions); git pushes failed
  intermittently until it freed up.
- Non-blocking polish and the balance report's weak spots: `docs/BACKLOG.md`.

## Exactly what is next
1. Stewart plays and writes notes at the top of `docs/STEWART_FEEDBACK.md`.
2. Start M1b with the prompt in `HANDOFF.md`: replay any runs he
   mentions, triage his notes plus the balance weak spots into `docs/plans/M1b.md`, iterate, new
   playtest builds, until he says the core loop is fun. Then plan M2.
