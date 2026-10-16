# Progress

Updated: 2026-10-16, end of the M1a build session.

## Milestone: M1a done. STOPPED for Stewart's playtest. Next: M1b (iterate on his notes).

## The playtest build
- `builds\InnerSun.exe` (exported 2026-10-16 00:08), launched by `Play Inner Sun.bat` (the
  `builds\PLAYTEST` marker is present). A labeled copy for the making-of record:
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
  - Balance: 1,000 full runs by three policy bots in about 12 minutes; after D021 and D022,
    balanced wins 19%, cautious 16%, greedy 12%; fires in 99% of runs; no killer above 44%
    (`docs/research/m1-evidence/`).
  - The blind critic: 3.8/10 (M0 view), then 5.8, then 6.1 at the gate (Opus). Its FIX items
    are done; DEFER items are in `review/LEDGER.md`.
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
  playtest is the first real hands-on test.
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
