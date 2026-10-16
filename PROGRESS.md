# Progress

Updated: 2026-10-16, end of the M1a build session.

## Milestone: M1a built and handed to Stewart for the playtest. Next: M1b (iterate on his notes).

Exit criteria met except two: trusted whole-run perf is UNVERIFIED (another Godot project was
rendering during every run-mode measurement) and the Gemini video critic could not run at the gate
(Gemini spend cap). Both are first items for M1b.

## The playtest build
- `builds\InnerSun.exe` (exported 2026-10-16 00:36 from commit e51d43a; the `builds\PLAYTEST`
  marker was written 00:45), launched by `Play Inner Sun.bat`. A labeled copy for the making-of record:
  `builds\milestones\m1a-playtest\` (git tag `m1a-playtest`).
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
  - `python tools/check.py`: 186 tests pass, selftest ok.
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
- **Perf is UNVERIFIED as trusted for whole runs.** Black Diamond had several Godot processes
  running during every run-mode measurement. The fire drill was trusted at p99 12.8 ms (78 fps
  floor). A contended whole run read 90 fps average with 1% lows of 22 fps; the rock repaint at a
  segment start is a known hitch source. Re-measure on an idle machine first thing in M1b:
  `python tools/perf.py --mode run --seconds 30 --runs 3`.
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
2. Start M1b with the prompt in `HANDOFF.md`: re-measure perf on an idle machine, replay any runs he
   mentions, triage his notes plus the balance weak spots into `docs/plans/M1b.md`, iterate, new
   playtest builds, until he says the core loop is fun. Then plan M2.
