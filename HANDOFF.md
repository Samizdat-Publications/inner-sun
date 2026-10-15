# Handoff

From the planning session (2026-10-15, which also ran Milestone 0) to the first build session (M1).

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
Continue Inner Sun. Read CLAUDE.md, PROGRESS.md and HANDOFF.md, then the M1 sections of PLAN.md and docs/plans/M1.md, then docs/STEWART_FEEDBACK.md. Start with M1 step 0 (install and live-test the blind critic). Then work autonomously through M1a in the order of docs/plans/M1.md, per CLAUDE.md, delegating as HANDOFF.md describes. Send me progress pictures as things become visible, show me the art style bake-off when it is ready, and stop when the M1a playtest build is ready for me. Stop earlier only for "checkpoint", a usage limit, or a decision that is genuinely mine.
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
This planning session could not write `.claude/hooks/critic_guard.mjs` or
`.claude/agents/player-critic.md`. It started in the Cut & Fill folder and inherited Cut & Fill's
deny rule for those exact paths. The new session, rooted here, does not have that rule.
1. Copy `docs/setup/critic/critic_guard.mjs` to `.claude/hooks/critic_guard.mjs`.
2. Copy `docs/setup/critic/player-critic.md` to `.claude/agents/player-critic.md`.
3. Run `python tools/test_guard.py`. It must print `guard: ok`.
4. Ask `player-critic` to read `CLAUDE.md`. It must be blocked. If the agent is not listed until
   the next session, record that and do the live test then.
5. Add `Edit(...)` and `Write(...)` deny rules for both files to `.claude/settings.json`, so no
   later session can make the critic nicer.

Critic loop:
1. Run `python tools/capture.py`.
2. Prompt `player-critic` with exactly: "A new build is in review/inbox. Play it."
3. Save its reply in `review/critiques/NNN_claude.md`.
4. Add its scores to `review/scores.csv`.
5. Triage every issue in `review/LEDGER.md` as FIX, DEFER or REJECT.

## Tools and paths
- Godot 4.7.2: `C:\Users\stewa\AppData\Local\Microsoft\WinGet\Links\godot_console.exe`. The tools
  find it and warn if WinGet ever upgrades it. The API reference of this exact build is in
  `harness/out/godot-api/doc/classes/`; regenerate it with `--doctool` if missing.
- Blender 5.1: `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`.
- API keys (Gemini, OpenAI, ElevenLabs, PixelLab, Meshy, Tripo): environment first, then
  `C:\Users\stewa\ClaudeProjects\Noclip\.env`. seked has no `.env`, despite the kickoff. Never read
  or print them.
- The reference Godot projects on this PC:
  - Noclip (`C:\Users\stewa\ClaudeProjects\Noclip`): the Gemini critic, capture director and
    autoplay bot to borrow from.
  - Cut & Fill (`C:\Users\stewa\Documents\Claude\Excavator Sim`): the gdext Rust bridge, if a hot
    spot ever needs it.

## Gotchas learned in M0
- **About 15 lights per canvas item.** Godot 2D lets one canvas item take only about 15 lights and
  silently drops the rest. Keep drawings split into small nodes (per room, per crew, per terrain
  chunk) and disable idle lights; never just set energy to 0.
- **Light height for normal maps.** Normal-mapped sprites need light `height` well above zero (we
  use 120 to 260 px), or they come out nearly black.
- **Focus.** Off-screen windows still steal the keyboard unless they are created unfocusable. The
  project sets `no_focus=true` and `game/view/boot.gd` restores focus for normal play. Any new bot
  flag must be added to `Boot.BOT_FLAGS`.
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
- **Disk.** C: has about 18 GB free. `capture.py` deletes raw movies and keeps two raw folders.
  Watch `builds/` and `harness/out/`.
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
- The blind critic is not installed and has never reviewed a build (step 0).
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
