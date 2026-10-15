# Progress

Updated: 2026-10-15, M1 session (continued after the restart).

## Milestone: M1a (find the fun). Steps 0, 1, 2 and 5 (sim) merged; 3, 4, views, writing and sound in flight.

## M1 so far
- **Step 0 done.** Blind critic installed and live-tested (`docs/research/m1-evidence/critic_live_test.txt`);
  `tools/critic.py` (headless run with a tool-call audit) and `tools/critic_gemini.py` (milestone
  gates) work; first review `review/critiques/001_claude.md` scored 3.8/10 and is triaged in
  `review/LEDGER.md` (7 FIX items, all mapped to M1 steps). Exposure lifted.
- **M1 skeleton done** (`docs/ARCHITECTURE.md`): ShipWorld (player and enemy run the same hazard and
  crew code), RunState with phases and integer resources, a module registry (systems, drill, combat,
  encounter own their commands, state and lint), crew repair jobs, HazardSim add_heat/add_water and
  power-driven cooling and pump scales, every data folder loads as a table. 33 tests pass.
- **Writing voice set** (`docs/STYLE_GUIDE.md`), event file format, three example events, codex
  entries, a TOPSIDE radio file.
- **Specs written** for steps 3 (run, map, pursuer, profile), 4 (combat), 5 (events, store) and the
  run screen (`docs/plans/specs/`).
- **Drilling segment sim merged** (step 1): rock grid from data, steering, power, heat into the drill
  room, bit wear, noise, water pockets, exact conservation; 2-bar segments 30 to 38 s on 20 of 20
  seeds, 4 bars about 20 s.
- **Power and systems merged** (step 2): reactor, allocation by priority, fire damage, heat failure,
  coolant billed in units, manning, evasion, bracing layers. Lead changes: power returns after
  repairs (remembered allocation), an overheated reactor limps at half (D018); the drill uses the
  helm and manned-drill bonuses.
- **Events, store and crew merged** (step 5 sim): the event runner with every effect, the store,
  recruitment, permadeath, the lint. 108 tests pass.
- **Art bake-off done: painted pulp chosen, provisional** (D017, `docs/progress/005_m1-art-bakeoff.jpg`,
  sent to Stewart); pixel art not tried (no PixelLab key).
- **Making-of record** started (`docs/making-of/README.md`, tag `m0-loop-proven`), at Stewart's request.

## Done (M0)
- **Plan approved** by Stewart (`PLAN.md`); he chose the tall tower ship.
- **M0, the autonomous loop, proven** (`docs/research/godot-loop.md`, evidence in
  `docs/research/m0-evidence/`):
  - headless tests (24) and selftest; a bot that plays through the command chain;
  - off-screen frames from the game camera (shots, Movie Maker clip, motion sheets, review inbox);
  - three planted bugs caught and named;
  - balance: 2,100 runs in 71 s;
  - the bench says GDScript is fast enough (28,491 ticks/s against a 6,000 budget);
  - the same hash headless, under Movie Maker and in the exported build;
  - perf on the NVIDIA GPU (p95 4.7 ms, GPU 0.7 ms);
  - side-by-side checks with Black Diamond.
- **Small but real architecture in place:**
  - sim core: tick, commands, replay, seeded streams, state hash;
  - room-level heat, fire and water with exact conservation;
  - crew job AI on ladders;
  - data and lint; the six-room tower (`light_drill`, the M1 starter draft);
  - a lit cutaway view.
- **Agent team definitions** in `.claude/agents/`. The blind critic is staged in `docs/setup/critic/`.
- **Private repo** `Samizdat-Publications/inner-sun` created and pushed. A fresh clone from GitHub
  passes `python tools/check.py` (24 of 24, selftest ok), so a new session can resume from the repo
  alone.

## In flight
Background agents, each in its own worktree under `.claude/worktrees/` (`git worktree list`); if the
session stops, check each branch, merge what passes, re-dispatch the rest from its spec:
- step 3, run: map, travel, pursuer, FullRun, RunBot (builder-opus; `docs/plans/specs/step3_run.md`),
- step 4, combat: weapons, enemy ships and AI, flee (builder-opus; `docs/plans/specs/step4_combat.md`),
- drilling view: rock chunks, crown, camera (builder; `docs/plans/specs/drill_view.md`),
- HUD panels, dossier and store UI with a UI gallery (builder; `docs/plans/specs/view_m1.md`),
- nine more crust events, codex, TOPSIDE lines (writer),
- placeholder sound assets (asset-smith; step 6 in `docs/plans/specs/step6_7_sound_balance.md`).

## Known issues
- **Capture windows flash on screen for about one second** at the start of each windowed run (shots,
  capture, perf, determinism, export). Before the fix they sat in the top-left corner for the whole
  run and took the keyboard. They never take focus now. Keep windowed runs rare and batched
  (HANDOFF, "Windows on Stewart's screen").
- **The M0 cutaway is very dark** (mean luminance about 6 out of 255): lift the exposure before the
  first critic review.
- **The audit (qa-auditor, end of M0)** passed the core claims: a fresh clone passes check, the
  conservation tests caught 7 of 7 planted mutations, determinism and the export hash match, and
  hygiene is clean. Its fixes are applied: critic guard hole, hook path, timeline, disk figure, and
  `--help` safety.
- HDR 2D glow bloom is not visible yet (configured, unverified); check in the art bake-off.
- Movie Maker and perf runs are slowed or flagged when Black Diamond renders at the same time; that
  is expected, re-measure perf when the GPU is idle.
- Everything you see is placeholder art.

## Exactly what is next
1. Merge each finished agent branch after reading its diff; run `python tools/check.py`.
2. Then step 3 (`docs/plans/specs/step3_run.md`), the drill view and run screen
   (`docs/plans/specs/view_m1.md`), combat (`docs/plans/specs/step4_combat.md`), the writer, sound,
   bots and balance, and the playtest build (`docs/plans/M1.md`).
3. Pick the art style when the bake-off is complete, write the Look section of the style guide, and
   show Stewart the comparison.
