# Progress

Updated: 2026-10-15 (planning session, end of Milestone 0).

## Milestone: M0 done. Next: M1a (find the fun), step 0.

## Done
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
Nothing. Everything is committed and pushed to `origin/main` (check with `git status` and
`git log origin/main -1`).

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
- The blind critic is not installed yet (a deny rule inherited from Cut & Fill blocked this session);
  M1 step 0 installs it and runs the live guard test.
- HDR 2D glow bloom is not visible yet (configured, unverified); check in the art bake-off.
- Movie Maker and perf runs are slowed or flagged when Black Diamond renders at the same time; that
  is expected, re-measure perf when the GPU is idle.
- Everything you see is placeholder art.

## Exactly what is next
Start the M1 build session (`HANDOFF.md`, "Start the next session"), then follow `docs/plans/M1.md`:
step 0 (install the critic), step 1 (the drilling segment in greybox), and onward to the playtest
build, where the session stops for Stewart.
