# Handoff

From the planning session (2026-10-15, which also ran Milestone 0) to the M1 build sessions.

## Restart note (first M1 session, 2026-10-15)
The first M1 session ran only briefly. It was restarted because a Claude Code mod ("blast-radius")
was still loaded in it and held commands it thought risky (every `git commit` included) until
someone clicked Proceed. Stewart has removed that mod and the "reflect" mod; a fresh session has
neither. What that session did, what it held, and what it stopped: PROGRESS.md, "M1 so far". Its
architecture decisions and the two agent briefs to re-dispatch: `docs/plans/M1_dispatch.md`. Step 0
is done except the exposure lift, the first critic review and the Gemini critic port.

## State in one paragraph
The plan is approved (`PLAN.md`) and Milestone 0 proved the autonomous Godot loop on this PC:
headless tests, bot-driven runs, off-screen frames from the game camera, planted bugs caught and
named, thousands of balance runs, identical results headless, under Movie Maker and in the exported
build, and safe coexistence with Black Diamond (`docs/research/godot-loop.md`). The code is a small
but real slice of the final architecture: a node-free sim with exact water and heat, crew AI, a
six-room tower ship in data, and a lit cutaway. M1 builds the playable slice and stops for
Stewart's playtest.

## Start the next session
In the Claude app, open the Code tab and start a new session with these settings:
- **Folder:** `C:\Users\stewa\Documents\Claude\Inner Sun`
- **Model:** Opus 5.5
- **Effort:** xhigh
- **Permission mode:** Auto

Or paste this into Windows PowerShell:
```powershell
cd "C:\Users\stewa\Documents\Claude\Inner Sun"; claude --model claude-opus-5-5 --effort xhigh --permission-mode auto
```
Then paste this as the first message:
```
Continue Inner Sun. Read CLAUDE.md, PROGRESS.md and HANDOFF.md, then the M1 sections of PLAN.md, docs/plans/M1.md and docs/plans/M1_dispatch.md, then docs/STEWART_FEEDBACK.md. Follow "Exactly what is next" in PROGRESS.md: re-dispatch the two stopped agents, finish step 0, then build the M1 architecture skeleton. Then work autonomously through M1a in the order of docs/plans/M1.md, per CLAUDE.md, delegating as HANDOFF.md describes. Send me progress pictures as things become visible, show me the art style bake-off when it is ready, and stop when the M1a playtest build is ready for me. Stop earlier only for "checkpoint", a usage limit, or a decision that is genuinely mine.
```

**Why xhigh for M1:**
- M1 lays the foundation every later layer builds on: the drilling terrain, power and systems, the
  run structure, combat, events and the meta save.
- "Find the fun" is judgment-heavy, so mistakes there are expensive.
- The lead mostly writes specs, reviews diffs, integrates and reads screenshots. Medium-effort
  subagents write most of the code, so the extra thinking goes where it pays.

**After M1:** use high for content-heavy milestones (M2 on), xhigh again for a system-heavy one
(for example the sea crossing in M4), and max only for a stubborn bug. This matches Noclip.

## Delegation

| Who | Model, effort | Does |
|---|---|---|
| Lead (the session) | Opus 5.5, xhigh in M1 | Architecture, integration, game feel, taste, reviews every diff, reads screenshots |
| `builder` | Sonnet, medium | UI, view scenes, content data, tooling and tests, from written specs |
| `builder-opus` | Opus, medium | Sim algorithms: terrain grid, power, combat, crew AI, map generation, determinism |
| `writer` | Opus, medium | Event, codex and radio text into data, after the lead sets the voice with examples |
| `asset-smith` | Sonnet, medium | PixelLab, Gemini or OpenAI, ElevenLabs, Blender, normal maps, texture processing |
| `scout` | Sonnet, medium | Godot 4.7 API and library checks (local API dump first) |
| `runner` | Haiku, low | Long commands and log summaries, keeps logs out of the lead's context |
| `qa-auditor` | Sonnet, high | Adversarial check of PROGRESS and HANDOFF claims before every handoff and gate |
| `player-critic` | Sonnet, high (Opus at gates) | Blind player review of `review/inbox` (installed in step 0) |
| Background scripts | no agent | `balance.py`, `capture.py`, `perf.py`, asset processing: run in the background, never poll |

**Every spec states:**
- the goal
- the files the agent owns
- the interfaces to keep
- the constraints (the hard rules in CLAUDE.md)
- the exact commands that must pass (`python tools/check.py`)
- what done looks like
- the report format

**Running agents in parallel:**
- Run agents in parallel only when their files do not overlap.
- Read every diff before integrating.
- Never edit `game/` or `tools/` while a capture or balance run that loads the live tree is
  starting. Use `python tools/snapshot.py` and `balance.py --pack` for long runs.

## Step 0 details (the critic install)
DONE in the first M1 session (items 1 to 5 below; evidence in
`docs/research/m1-evidence/critic_live_test.txt`). Kept for reference. Item 6 and the first critic
loop are still to do. The guard blocks for real: the hook command with `$CLAUDE_PROJECT_DIR` works.
If `player-critic` is not listed in a session, run it through a headless `claude -p` process
(`tools/critic.py`, see `docs/plans/M1_dispatch.md`).
1. Create `.claude/hooks/` if it is missing (a fresh clone does not have it), then copy
   `docs/setup/critic/critic_guard.mjs` to `.claude/hooks/critic_guard.mjs`.
2. Copy `docs/setup/critic/player-critic.md` to `.claude/agents/player-critic.md`.
3. Run `python tools/test_guard.py`. It must print `guard: ok`.
4. Ask `player-critic` to read `CLAUDE.md`. It must be blocked. If the agent is not listed until
   the next session, record that and do the live test then.
   - The hook command is `node "$CLAUDE_PROJECT_DIR/.claude/hooks/critic_guard.mjs"`, so it does not
     depend on the working folder.
   - If the live test shows the read was NOT blocked (for example the variable was not expanded and
     node exited 1, which counts as non-blocking), switch the command to
     `node .claude/hooks/critic_guard.mjs` and test again. Never run a critic review until the live
     test blocks.
5. Add these four deny rules to `.claude/settings.json`, so no later session can make the critic
   nicer:
   - `"Edit(./.claude/hooks/critic_guard.mjs)"`
   - `"Write(./.claude/hooks/critic_guard.mjs)"`
   - `"Edit(./.claude/agents/player-critic.md)"`
   - `"Write(./.claude/agents/player-critic.md)"`
6. `review/inbox` still holds a stale M0 build, and its perf was contended. Refill it with
   `python tools/capture.py` when the GPU is idle before the first review.

Critic loop:
1. Run `python tools/capture.py`.
2. Prompt `player-critic` with exactly: "A new build is in review/inbox. Play it." (or run
   `python tools/critic.py`, which does steps 2 to 4 through a headless process once it works).
3. Save its reply in `review/critiques/NNN_claude.md`.
4. Add its scores to `review/scores.csv`.
5. Triage every issue in `review/LEDGER.md` as FIX, DEFER or REJECT.

## Tools and paths
- Godot 4.7.2: `C:\Users\stewa\AppData\Local\Microsoft\WinGet\Links\godot_console.exe`. The tools
  find it and warn if WinGet ever upgrades it. The API reference of this exact build is in
  `harness/out/godot-api/doc/classes/`; regenerate it with `--doctool` if missing.
- Blender 5.1: `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`.
- API keys (Gemini, OpenAI, ElevenLabs, PixelLab, Meshy, Tripo): environment first, then
  `C:\Users\stewa\ClaudeProjects\Noclip\.env`. The kickoff also names Stewart's seked project
  (`C:\Users\stewa\ClaudeProjects\seked`), but it has no `.env`. Never read or print them.
- The reference Godot projects on this PC:
  - Noclip (`C:\Users\stewa\ClaudeProjects\Noclip`): the Gemini critic, capture director and
    autoplay bot to borrow from.
  - Cut & Fill (`C:\Users\stewa\Documents\Claude\Excavator Sim`): the gdext Rust bridge, if a hot
    spot ever needs it.

## Gotchas learned in M0
- **About 15 lights per canvas item.** Godot 2D lets one canvas item take only about 15 lights and
  silently drops the rest. Keep drawings split into small nodes (per room, per crew, per terrain
  chunk) and disable idle lights; never just set energy to 0.
- **Glow needs emission above 1.0 after CanvasModulate.** HDR 2D glow works with the M0 settings
  (`hdr_2d=true`, glow threshold 1.0), but CanvasModulate multiplies every canvas item, unshaded and
  additive ones included. An emission sprite must use `modulate = target / CanvasModulate.color`
  (target about 1.0 to 1.4; 1.6 and up blows out to a white disc). The M0 drill polygon and flames
  do not bloom for this reason. Found in the M1 art bake-off. `Environment.set_glow_level` is
  0-based (0 to 6).
- **Correction to the glow rule, measured in the art pass:** for items drawn UNSHADED, dividing by the
  CanvasModulate color blows them out to white; they come out about 2x too dim at plain colors.
  Empirical values that work: glow sprite modulate 0.9 to 1.1 flat, unshaded drawings boosted x1.8
  to x2.0 (`boost` argument of `ShipView._fn`). Filled shapes with HDR colors (components above 1)
  ignore alpha and draw opaque: draw translucent fills on an additive layer with plain colors.
- **Light height for normal maps.** Normal-mapped sprites need light `height` well above zero (we
  use 120 to 260 px), or they come out nearly black.
- **Windows on Stewart's screen.** Rendering needs a window, and Stewart works on this laptop while
  you build. Measured in M0:
  - `--position -32000,-32000` alone does not work. Godot pulls the window back to the top-left
    corner and keeps it there.
  - A focusable window takes his keyboard.
  - Now: windows are created unfocusable (`no_focus=true`; `game/view/boot.gd` restores focus for
    normal play only). Boot re-parks bot-run windows off-screen for the first frames, and
    `tools/proc.py` moves them off-screen the moment they appear.
  - What is left: about one second on screen at startup. Run windowed jobs (shots, capture, perf,
    determinism, export) only when the visuals changed, batch them, and never in a loop.
    Everything else is headless.
  - Any new bot flag must be added to `Boot.BOT_FLAGS`.
  - If Stewart still minds the flash, try starting the window on a hidden desktop (CreateDesktop)
    or minimized (both untested).
- **Agent worktrees lack git-ignored files.** Builders in `.claude/worktrees/` do not have
  `harness/out/` (so no Godot API dump: point them at the main repo's
  `C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`) and only see
  committed files: commit a spec before dispatching the agent that needs it.
- **`check.py --no-import` is only for repeat runs.** Right after a merge that adds scripts with new
  class names or new assets, run the full `python tools/check.py` (the import registers them), or
  you get dozens of false errors.
- **Use the console exe.** `godot.exe` prints nothing to a pipe. The console wrapper starts the
  real exe as a child process, and job objects catch both.
- **Hangs.** A script that fails to compile makes the sim stop advancing. Play runs with
  `ScenarioRun.play_to_end()`, never a bare `while not done()` loop. The test runner times out after
  240 s and names the hung test.
- **Strict typing:**
  - Untyped declarations are compile errors.
  - `var x := dict["k"]` is an error too (inference on Variant); write `var x: float = dict["k"]`.
  - JSON numbers are all floats: cast with `int()`.
  - GDScript arrays accept index -1, so validate references.
- **Commit the generated files.** Godot 4.4+ writes `.uid` files next to scripts, and `.import`
  files sit next to assets: commit both.
- **Export:**
  - `export_presets.cfg` includes `*.json` and excludes `tests/`.
  - The release build writes logs to `user://logs`, and the console wrapper
    `InnerSun.console.exe` gives stdout.
- **Perf readings:**
  - Windowed fps is capped at the 240 Hz refresh, so judge p99 and GPU ms.
  - Perf taken while Black Diamond renders is marked untrusted. Re-measure later instead of tuning
    on it.
- **Disk.** C: had about 15 GB free at the end of M0 and about 275 GB free on 2026-10-15 (first M1
  session); still keep outputs pruned.
  `capture.py` deletes raw movies and keeps two raw folders. Watch `builds/` (about 110 MB per
  export) and `harness/out/`.
- **Dark frames.** The M0 cutaway is very dark: mean luminance is about 6 out of 255, with roughly
  93% of pixels near black. Lift the exposure (CanvasModulate, lamp energy) before the first critic
  review, or the critic will only see darkness. Real lighting comes with the art bake-off.
- **Balance reading.** The `auto` crew survives 99.4% of M0's generated situations, so these
  hazards do not yet threaten a competent crew. The M1-scale cost in balance reports is an assumed
  4x tick cost, not a measurement: re-run `--bench` once M1's systems exist.
- **Not verified in M0:** normal interactive play (`Play Inner Sun.bat`, click a room). Launching it
  would have taken over Stewart's screen while he was working. Check it with him at the first
  playtest.
- **Blocked helper.** A PID-based "kill strays" helper was refused by the safety filter. Do not
  re-add it. Job objects make it unnecessary.
- **Escape sequences.** The Write tool and Bash commands turn a backslash-u escape into the real
  character. That is how an em dash slipped into two files in M0. To put an escape in a file,
  build it from parts in Python (`"\\" + "u2014"`). In GDScript, use `char(0x2014)` at runtime.
  The em dash scan in `qa-auditor` catches slips.

## Side by side with Black Diamond
Black Diamond (first-person 3D steam-train survival, `C:\Users\stewa\Documents\Claude\Black Diamond`)
builds in Godot on this PC at the same time. Shared rules: `C:\Users\stewa\Documents\Claude\GODOT-SIDE-BY-SIDE.md`.
Its Movie Maker captures were seen taking the foreground during M0. If perf keeps coming back
contended, check `tasklist` for its processes before blaming Inner Sun.

## Not done
- The blind critic is installed and live-tested, but has never reviewed a build.
- The Gemini video critic is not ported.
- HDR glow bloom is unverified.
- The art style is not chosen yet (M1 step 2 bake-off).

## Session protocols
- **Checkpoint** (Stewart types it):
  1. Finish or safely stop the current step.
  2. Update PROGRESS and HANDOFF.
  3. Commit with explicit paths and push.
  4. Stop with a two-line summary.
- **End of session:**
  1. Run `qa-auditor` on the PROGRESS and HANDOFF claims and fix what it finds.
  2. Confirm `python tools/check.py` passes from a clean tree.
  3. Update PROGRESS, HANDOFF and DECISIONS.
  4. Commit with explicit paths and push.
  5. Give Stewart a plain-English summary with the next session's launch settings and prompt.
