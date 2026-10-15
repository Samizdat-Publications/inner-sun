# M1 dispatch notes (written 2026-10-15, first M1 session, before a session restart)

The first M1 session was restarted early because a since-removed Claude Code mod ("blast-radius",
still loaded in that session's memory) held every `git commit` as a false alarm. Nothing from that
session is committed. This file keeps its decisions and agent briefs so the next session does not
re-derive them.

## 1. Agents that were running when the session restarted (they die with it)

Check each, then finish or re-dispatch with the brief below.

### a) Critic tooling (builder, main tree)
Files it owned: `tools/critic.py`, `tools/critic_gemini.py`, `review/critiques/`. Check with
`git status` whether they exist and work (`python tools/critic.py --selftest`, `--dry-run`).
Brief, in short:
- `tools/critic.py` runs the blind player-critic through a headless Claude Code process (the agent
  is not listed in the session that installs it, and a headless run always loads it from disk):
  `claude -p "<invoke player-critic with exactly: A new build is in review/inbox. Play it. Then output
  its review verbatim>" --model sonnet --output-format stream-json --verbose --allowedTools Agent`.
  The review arrives in the subagent's `SubagentHandback` tool_use input field `message` (fallback:
  the final `result` event). Record every critic tool call; fail loudly if any call outside
  `review/inbox` succeeded. Save `review/critiques/NNN_claude.md`; append parsed scores to
  `review/scores.csv` (critic = claude). Flags: `--dry-run`, `--selftest`, `--timeout`, `--model`.
- `tools/critic_gemini.py`: port of `C:\Users\stewa\ClaudeProjects\Noclip\tools\critic_gemini\critic.py`
  for milestone gates; same persona, output format and score columns as player-critic; newest Gemini
  model that takes video; key from env then parsed in code from the Noclip `.env`; `--dry-run`;
  paid calls logged in `docs/SPEND.md`.
- One real smoke run of each was allowed against the stale inbox, then its rows and files removed
  so the first real review is 001.

### b) Art style bake-off (asset-smith, in its own git worktree)
Find it with `git worktree list` (Claude Code agent worktrees). Its files: `game/assets/bakeoff/{pixel,painted,blender}/`,
`pipeline/` scripts and `pipeline/manifests/`, `game/view/bakeoff/bakeoff.gd` + `.tscn`,
`tools/bakeoff.py`, one line in `game/view/boot.gd` (`"--bakeoff"` added to `Boot.BOT_FLAGS`),
`docs/SPEND.md`, `docs/CREDITS.md`. Output: `harness/out/bakeoff/` frames and `compare.jpg`.
Paid generations may already have happened: reuse whatever assets exist, do not regenerate them.
Brief, in short:
- Same subject three ways: (A) PixelLab pixel art, native 40 px/m shown at exactly 2x nearest;
  (B) Gemini or OpenAI painted pulp, 160 px/m shown at 0.5; (C) Blender 5.1 pre-rendered with real
  normal passes, 160 px/m shown at 0.5.
- Subject: the 4 m x 3 m Reactor room (back wall, reactor core about 1.7 m with glowing window,
  ceiling lamp, floor grating; albedo + normal each; emission sprites separate) and one crew member
  (engineer, jumpsuit, hard hat with headlamp, tool belt, facing right, 1.8 m).
- Look: dark, warm amber lamps, cold blue-grey rock light, red alarms, fire glow; 1970s black-budget
  retro-futurist hardware; pulp X-Files.
- Scene: three rooms side by side, identical game light rig (CanvasModulate 0.30/0.30/0.34; lamp
  (1.0, 0.86, 0.66) energy 1.25 height 220 with shadows; occluders; glow like `game/view/main.gd`).
- Frames: 01_lamp, 02_alarm (lamp 0.4, red alarm, orange fire glow), 03_sweep_a/b/c (orbiting
  white light, height 180), 04_zoom06, 05_closeup (zoom 2.5); then a labeled `compare.jpg`.
- Required finding: is HDR glow bloom visible on the emission sprites, and which settings made it
  work.
- Budget about $12. `python tools/check.py` must pass in the worktree.
- Then the LEAD picks one style, writes `docs/STYLE_GUIDE.md`, and sends Stewart the comparison
  picture (he can veto).

## 2. Architecture decided for M1 (do this before fanning out the sim work)

The lead does this skeleton itself, commits it, then builders fill in subsystems in parallel.

- **ShipWorld.** A bundle of `ship`, `hazards` (HazardSim), `crew_ai` (CrewAI) and `systems`
  (power and system damage), with `side` = "player" or "enemy". `Sim.player` is the player's;
  combat holds `enemy`. Keep `Sim.ship` and `Sim.hazards` as aliases of the player's, so the view
  keeps working. Refactor `HazardSim.step`, `CrewAI.think/replan/move` to take the ShipWorld instead
  of reading `sim.ship`. Random streams per side (`"fire"` for the player, `"enemy/fire"` for the
  enemy). Events carry `"side"` when not the player.
- **Phases in the sim.** `Sim.step()` always advances the tick and applies commands; a phase decides
  what else runs: `map` (choose a node; world frozen), `drill` (drilling segment; world runs),
  `node` (arrival: event, store, cavern, hazard; dialogs freeze the world, hazards resolve with the
  world running), `combat` (world and enemy run), `dead`, `won`. Pause is the view not calling
  `step()`; commands made while paused apply on the next step, so replays stay exact.
- **Subsystem interface**, so builders never edit `sim.gd`: each subsystem declares the command
  types it handles, applies them, steps when its phase is active, and returns a `state()` array for
  the hash. `Sim._apply` dispatches by command type through that registry.
- **Run state**: resources as integers (hull, ore, gems, coolant, power cells, drill bits), the node
  map, current row and node, the pursuer front, discoveries this run. Death: hull at 0, all crew
  dead, or the drill room flooded 10 s. In M1 the layer gate is a final fight against a tougher
  rival; winning it ends the run as a win.
- **Ship layout change for systems:** six rooms stay. Bridge = helm (manned: steering response and
  combat evasion) + seismic scanner. Quarters becomes **Bracing** (the shield analog, layers by
  power). Reactor, Weapons, Drill, Coolant and Pumps stay. Crew heal slowly when idle in a safe room
  (a medbay can come in M2).
- **Parallel builders get worktrees** (`isolation: worktree`): two agents running `check.py` in one
  tree see each other's half-written tests. Agents never commit to main; the lead reviews and
  merges. Note: all worktrees share the Godot user folder `%APPDATA%\InnerSun`, so tests and bots
  must write profiles and runs under a repo path (`--profile-dir`), never bare `user://`.

## 3. Fan-out order after the skeleton lands
1. builder-opus: DrillSim (`game/sim/drill/`, rock grid, drill head, steer and power commands, ore
   and gems as exact integers, heat, wear, noise; water pockets breach the drill room), its tests
   and a drill bot.
2. builder-opus: Systems and power (`game/sim/systems/`), reactor bars, capacity and damage, repair
   jobs for crew, coolant and pumps gated by power.
3. Then: drill view (builder), map generation + pursuer + run phases (builder-opus), death and codex
   UI (builder), combat (builder-opus sim, builder UI), events runner + store + dossier (lead writes
   the voice and 3 examples first, then the writer agent), sound (asset-smith + builder), bots and
   balance (builder), export (lead).
