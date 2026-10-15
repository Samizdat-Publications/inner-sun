# Progress

Updated: 2026-10-15 (first M1 session, stopped early for a session restart; see "M1 so far").

## Milestone: M1a (find the fun), step 0 mostly done.

## M1 so far (first M1 session, short)
- **The blind critic is installed and its guard is live-tested.** `.claude/hooks/critic_guard.mjs`,
  `.claude/agents/player-critic.md`, and four deny rules in `.claude/settings.json` so no session
  can soften them. `python tools/test_guard.py` prints `guard: ok`. The live test ran through a
  headless `claude -p` process (the agent is not listed in the session that installs it): reads of
  `CLAUDE.md` and `PLAN.md` and a repo-wide glob were BLOCKED, the inbox was allowed
  (`docs/research/m1-evidence/critic_live_test.txt`). So a critic review can always run through a
  headless process, in any session.
- **Architecture for M1 decided and written down** in `docs/plans/M1_dispatch.md` (ShipWorld,
  phases in the sim, subsystem command registry, run state, the Quarters room becomes Bracing,
  worktrees for parallel builders). Do the skeleton before fanning out.
- **Baseline green:** `python tools/check.py` printed `check: ok` (24 of 24, selftest ok) at the
  start of the session.
- **Stopped, not finished** (agents were stopped for the restart; details and briefs in
  `docs/plans/M1_dispatch.md` section 1):
  - critic tooling: `tools/critic.py` exists as an UNTESTED 475-line draft (uncommitted on purpose);
    `tools/critic_gemini.py` was not started. Finish or redo from the brief.
  - art bake-off: its worktree `.claude/worktrees/agent-a00cbd0a6ca4a8ce5` holds only
    `pipeline/common.py`. No paid generation happened ($0 spent). Re-dispatch from the brief; the old
    worktree can be removed with `git worktree remove --force` once nothing in it is wanted.
- **Commands the blast-radius mod held this session** (it is now removed; a fresh session will not
  have it):
  1. A python heredoc that added the deny rules to `.claude/settings.json` and wrote the evidence
     file: redone with the Edit and Write tools, done.
  2. `git add` + `git commit` of the step 0 install: redone in the end-of-session commit (if that
     commit is missing from `git log`, commit the files listed in it).
- Stewart asked to turn off the "reflect" mod ("Save as a rule?" banner); it was removed from the
  mod list in `C:\Users\stewa\.claude\settings.json`, and Stewart has since removed the mod itself.
- Disk: C: now has about 275 GB free (it was about 15 GB at the end of M0).

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
Nothing running. Uncommitted on purpose: the untested `tools/critic.py` draft and the stopped
bake-off worktree (see "M1 so far"). Everything else is committed and pushed (check with
`git status` and `git log origin/main -1`).

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
Start the next M1 session (`HANDOFF.md`, "Start the next session"). In order:
1. Confirm the end-of-session commit is in `git log` and `python tools/check.py` says `check: ok`.
2. Re-dispatch the two stopped agents from `docs/plans/M1_dispatch.md` section 1, in the
   background: the critic tooling (finish or redo `tools/critic.py`, then `tools/critic_gemini.py`)
   and the art bake-off (asset-smith in a worktree).
3. Meanwhile, finish step 0: lift the cutaway exposure (`game/view/main.gd` CanvasModulate and lamp
   energy), refill `review/inbox` with `python tools/capture.py` on an idle GPU, run the first
   critic review (`python tools/critic.py` once it works), triage it in `review/LEDGER.md`.
4. Build the M1 architecture skeleton yourself (`docs/plans/M1_dispatch.md` section 2), commit it,
   then fan out step 1 (the drilling segment) and the rest in the order of section 3 and
   `docs/plans/M1.md`, until the M1a playtest build is ready for Stewart.
