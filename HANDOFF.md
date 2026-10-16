# Handoff

From the M1b session (2026-10-16) to the next round, which starts after Stewart plays build 3.

## M1b in one paragraph (newest)
Stewart's first playtest (2.5 minutes, steering only) said there was nothing to do and runs were
too short with too little loot. The lead then played it by hand with real keys and mouse and found
eight control defects, all fixed and re-tested by hand. Stewart chose "digging is the game" (D024):
mining first, FTL systems, events, upgrades and occasional fights around it ("scanning planets and
gaining resources"). Built since: a nine-material ore and gem economy by depth, gas pockets, surveys
on map nodes, ore-bought gear, a zoomed-out drilling view with visible ore, pickups and a dig tally,
a 14-row Crust with about 20-minute runs. Playtest build 3 is exported. A live making-of page tracks
progress (https://claude.ai/artifact/UJjDA4PJkSXMKjpg2zxQpc); republish it when something visible
lands. Hands-on testing: `python tools/play.py`, then computer-use `request_access` with the window's
exe basename (`InnerSun.exe` for `--exe` builds, `Godot_v4.7.2-stable_win64.exe` for the project).
For the next session, use the prompt below but say "build 3" and effort high (Stewart's quota is
tight; delegate implementation to Sonnet builders, Opus builders only for sim-heavy work).

## State in one paragraph (M1a)
M1a is built: a whole run plays from the first node to death or the layer gate. A painted drill
tower bores down a node map through layered rock (steering, power, heat, bit wear, noise, ore, gems,
water pockets). FTL-style systems and power, fire, water and heat spread room to room, and the crew
handle emergencies. A pursuer advances with time and noise. The run has real-time fights with pause
against rival rigs and a gate boss, 12 dossier events with redactions that lift with the codex, a
store, recruitment and permadeath, a death report, a codex and a saved profile. Every run is saved
as a replayable record. Three policy bots play 1,000 full runs in about 12 minutes; the first tuning
passes are D021 and D022. The blind critic scored the M0 build 3.8 and the M1 run screen 5.8 before
its fixes (`review/scores.csv`). Details: `PROGRESS.md`. Architecture: `docs/ARCHITECTURE.md`.

## What Stewart does now
Play the build (`Play Inner Sun.bat`, or the README's PowerShell line), as many runs as he likes, and
write notes at the top of `docs/STEWART_FEEDBACK.md` under a dated heading: what was fun, what was
boring or confusing, what he wanted to do and could not. His runs are saved in
`%APPDATA%\InnerSun\runs\`, so any problem can be replayed exactly (`python tools/replay.py --latest`).

## Start the next session (M1b)
In the Claude app, open the Code tab and start a new session with these settings:
- **Folder:** `C:\Users\stewa\Documents\Claude\Inner Sun`
- **Model:** Opus 5.5
- **Effort:** xhigh (M1b is judgment about fun: what to change and what to leave alone)
- **Permission mode:** Auto

Or paste this into Windows PowerShell:
```powershell
cd "C:\Users\stewa\Documents\Claude\Inner Sun"; claude --model claude-opus-5-5 --effort xhigh --permission-mode auto
```
Then paste this as the first message:
```
Continue Inner Sun: M1b. Read CLAUDE.md, PROGRESS.md and HANDOFF.md, then docs/STEWART_FEEDBACK.md (my playtest notes are at the top), docs/plans/M1.md (M1b) and docs/BACKLOG.md. First re-measure trusted perf on an idle machine and run the Gemini gate critic if its cap has lifted (PROGRESS, Known issues). Replay any runs I mention from %APPDATA%\InnerSun\runs\. Triage my notes into docs/plans/M1b.md (with the balance report's known weak spots), then iterate on the core loop autonomously per CLAUDE.md, delegating as HANDOFF.md describes. Send me progress pictures, and stop with a new playtest build when the changes are ready for me to try. Stop earlier only for "checkpoint", a usage limit, or a decision that is genuinely mine.
```

## Delegation (what worked in M1a)

| Who | Model, effort | Does |
|---|---|---|
| Lead (the session) | Opus 5.5, xhigh | Architecture, specs, integration (main.gd, merges), game feel, taste, every diff and screenshot |
| `builder` | Sonnet, medium | UI, view scenes, content data, tooling and tests, from written specs |
| `builder-opus` | Opus, medium | Sim modules: drilling, systems, run and map, combat, events, policy bots |
| `writer` | Opus, medium | Events, codex, radio, in the style guide's voice |
| `asset-smith` | Sonnet, medium | Gemini art, ElevenLabs sound, Blender, normal maps |
| `qa-auditor` | Sonnet, high | Adversarial check of PROGRESS and HANDOFF before every handoff |
| `player-critic` | Sonnet, high (Opus at gates) | Blind review of `review/inbox` (run by `python tools/critic.py`) |

- **Every code agent gets its own worktree** (`isolation: worktree`) and a list of files it owns,
  disjoint from every other running agent. Agents commit on their branch; the lead reads the diff,
  merges with `git merge --no-ff`, runs the full `python tools/check.py`, pushes, and removes the
  worktree (`git worktree remove --force`, then `git branch -d`).
- **Expect three small merge conflicts** and resolve them by keeping both sides: the
  tuning-keys list in `game/tests/test_data.gd`, `docs/SPEND.md`, and `docs/progress/INDEX.md`.
  Progress picture numbers collide when two agents add one: renumber the later one with `git mv`.
- **Agents cannot see git-ignored files** in their worktree: point them at the main repo's Godot API
  dump, and commit a spec before dispatching the agent that reads it.
- **Agents overspend windowed runs** (each flashes a window on Stewart's screen for a second): give a
  limit and check it in the report. Two or three agents at once is plenty when RAM is tight.
- **Specs live in `docs/plans/specs/`.** Each states the goal, owned files, interfaces to keep, hard
  rules, the commands that must pass, what done looks like, and the report format.

## The review loop
1. `python tools/capture.py --mode run --bot balanced --seed <n> --duration 240 --stills 16 --label <label>`
   (a whole run; event, store, map and death screens are held long enough to see them).
2. `python tools/critic.py` (headless player-critic with a tool-call audit; `--model opus` at gates).
   `python tools/critic_gemini.py` watches the video (blocked while the Gemini spend cap is reached).
3. Triage every issue in `review/LEDGER.md` as FIX, DEFER or REJECT; fix the FIX items.
4. Balance: `python tools/balance.py --full --runs 1000 --procs 6 --pack` (about 12 minutes), report in
   `harness/out/balance/full_report.md`; copy the headline report to `docs/research/` when it matters.

## Tools and paths
- Godot 4.7.2: `C:\Users\stewa\AppData\Local\Microsoft\WinGet\Links\godot_console.exe` (the tools find
  it). API reference of this exact build: `harness/out/godot-api/doc/classes/`.
- Blender 5.1: `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`.
- API keys: environment first, then `C:\Users\stewa\ClaudeProjects\Noclip\.env`, loaded inside scripts.
  Gemini works (but its monthly spend cap is reached, see `docs/NEEDS_STEWART.md`); ElevenLabs works;
  no PixelLab key. Never read or print keys.
- Everyday tools (all launch Godot through job objects): `check.py`, `shots.py` (`--mode run --bot`),
  `capture.py`, `perf.py` (`--mode run`), `determinism.py`, `export.py` (`--playtest --label`),
  `balance.py` (`--full`, `--bench`), `gallery.py` (every UI state), `bakeoff.py`, `replay.py`,
  `critic.py`, `critic_gemini.py`, `makingof.py` (labeled clips), `progress.py`.
- Game flags: no flags is normal play; `--mode=run --bot=balanced`, `--scenario=<id>`,
  `--replay=<record>`, `--profile-dir=<dir>`, `--debug-hud`; capture and test flags in `main.gd`.

## Gotchas
- **About 15 lights per canvas item.** Godot 2D lets one canvas item take only about 15 lights and
  silently drops the rest. Keep drawings in small nodes and disable idle lights. Lights reach only the
  items whose rectangle contains them: the rock is one mosaic item for that reason.
- **Glow and unshaded drawings (measured in the art pass).** HDR glow works (`hdr_2d=true`, threshold
  1.0). Glow sprites want modulate 0.9 to 1.1 flat; unshaded drawings need a x1.8 to x2.0 boost
  (`ShipView._fn` boost); dividing by the CanvasModulate color blows them out to white. Filled
  shapes with HDR colors ignore alpha: draw translucent fills on an additive layer with plain colors.
  `Environment.set_glow_level` is 0-based (0 to 6).
- **Light height for normal maps:** 120 to 260 px, or sprites come out nearly black.
- **Windows on Stewart's screen.** Capture windows are unfocusable and parked off-screen
  (`game/view/boot.gd`, `tools/proc.py`) but flash for about a second at startup. Batch windowed
  runs, never loop them. Any new bot or capture flag must go into `Boot.BOT_FLAGS`.
- **`check.py --no-import` lies right after a merge** that adds classes or assets: run the full check.
- **`JSON.parse_string` logs an engine error on bad input** (and fails a test): use `JSON.new().parse()`.
- **Shell quoting.** Bash heredocs and the Write tool can mangle backslashes (`\U`, `\u`): write Windows
  paths into files with the Edit tool, and build an em dash only at runtime (`char(0x2014)`).
- **Strict typing:** untyped declarations are errors; `var x := dict["k"]` is too; JSON numbers are
  floats (cast with `int()`); arrays accept index -1, so validate references; a subclass cannot
  redeclare a member of its base (see `Driver`).
- **Commit the generated files:** `.uid` next to scripts, `.import` next to assets.
- **Determinism:** all randomness from `sim.rng.get_stream(...)`, per side for the enemy
  (`world.stream(sim, name)`); the view may use its own hash-based randomness (it never feeds the sim).
- **Perf:** windowed fps is capped at 240 Hz; judge p99 and GPU ms. Perf taken while Black Diamond
  renders is marked untrusted.
- **RAM on this PC** fills up with leftover `node` processes from Claude sessions (about 15 GB was
  seen); git then fails with "getaddrinfo() thread failed to start". Retry later; Stewart restarts the
  Claude app when his sessions are done. Never kill processes by name.
- **Blocked helper:** a PID-based "kill strays" helper was refused by the safety filter. Do not re-add it.

## Side by side with Black Diamond
Black Diamond (`C:\Users\stewa\Documents\Claude\Black Diamond`) builds in Godot on this PC at the same
time. Shared rules: `C:\Users\stewa\Documents\Claude\GODOT-SIDE-BY-SIDE.md`.

## Known gaps going into M1b
See `docs/BACKLOG.md` (non-blocking polish) and `PROGRESS.md` (known issues). The balance report's
weak spots are the first M1b candidates: the middle rows rarely threaten the hull, rivals feel
scripted, gems pile up unspent, ore makes repairs nearly free, the lance is never bought, bits never
break.

## Session protocols
- **Checkpoint** (Stewart types it): finish or safely stop the current step, update PROGRESS and
  HANDOFF, commit with explicit paths and push, stop with a two-line summary.
- **End of session:** run `qa-auditor` on PROGRESS and HANDOFF and fix what it finds; confirm
  `python tools/check.py` passes from a clean tree; update PROGRESS, HANDOFF and DECISIONS; commit and
  push; give Stewart a plain-English summary with the next session's launch settings and prompt.
