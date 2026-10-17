# Inner Sun: project rules

An FTL-style roguelite in a 2D side-view cutaway: a near-future black-budget drill ship (a tall
tower, drill at the bottom) bores down through a hollow Earth, layer by layer, toward the facility
where the UAPs are built. Godot 4.7.2 Forward+, strictly typed GDScript, native Windows build.
Owner: Stewart, who is not a programmer and has delegated all technical judgment. Working title
"Inner Sun" (rename later if something better comes up; the folder and repo keep their names).

## Read order, every session

1. `PROGRESS.md`: where the build is and exactly what to do next.
2. `HANDOFF.md`: how to work here (delegation, tools, gotchas, the next-session prompt).
3. `PLAN.md`: the approved plan. Read the sections for the current milestone and its checklist in
   `docs/plans/Mx.md` (write the checklist first if it does not exist yet).
4. `docs/STEWART_FEEDBACK.md`: his words outrank everything except the hard rules below.

Reference: `docs/research/` (the loop proof and evidence, the tooling brief), `docs/DECISIONS.md`.

## Working mode

- **Autonomous through the plan.** Stop only for "checkpoint", a usage limit, a milestone gate that
  says to wait for Stewart, or a decision that is genuinely his (irreversible or product-defining).
  Decide everything else, log it in `docs/DECISIONS.md` (choice, why, how to revert) and keep going.
- The lead keeps architecture, integration, game feel, taste, and reading screenshots.
  Well-specified implementation goes to subagents (`HANDOFF.md`, delegation).
- Finish and verify a step rather than half-starting the next. Commit and update `PROGRESS.md`
  after every meaningful chunk; push when a step is done.

## Hard rules

1. **Rules live in `game/sim/`.** Plain `RefCounted` classes: no Nodes, no rendering, no `Time`, no
   frame delta, no autoloads. The view only reads sim state. The same sim runs in the game, in tests
   and in headless balance runs.
2. **One command chain.** The player's input, bots and scenario timelines all push commands into
   the sim (`sim.push`). Nothing changes the world any other way. A replay is a seed plus the
   command log (`Sim.replay`).
3. **Fixed 60 Hz tick.** The sim steps in `_physics_process` and never reads frame time; a slow frame
   means slow motion, never a different result.
4. **Deterministic.** Randomness only from `sim.rng.get_stream("<name>")`. No `randi`, `randf`,
   `shuffle`, `pick_random` or `randomize` in `game/sim` or `game/bots` (a test scans for them).
   Never sort StringNames. The same seed and commands give the same `FINAL` hash headless, under
   Movie Maker and in the exported build (`python tools/determinism.py`, `python tools/export.py`).
5. **Exact conservation.** Water (millilitres), heat (joules) and resources are integers, moved in
   exact plus/minus pairs; conservation tests assert equality, never a tolerance.
6. **Content is data.** Ships, rooms, systems, weapons, crew, enemies, events, layers, node types,
   codex and radio lines live in `game/data/**/*.json`, checked by the data lint. Adding content
   means adding data, not rewriting systems. If a new kind of content would need a core change,
   generalize the system first and log why.
7. **Strict typing.** Untyped declarations are compile errors. Check exact 4.7.2 signatures in
   `harness/out/godot-api/doc/classes/` (regenerate with
   `godot_console --headless --doctool harness/out/godot-api`).
8. **Nothing is done until verified:** `python tools/check.py` prints `check: ok`, and screenshots
   or frames were actually looked at. Otherwise say UNVERIFIED.
9. **Godot processes.** Launch Godot only through `tools/` (every run sits in a Windows job object, so
   nothing outlives the tool). Never kill processes by name. No Godot MCP server, no editor left open
   on this project. Capture windows are unfocusable and parked off-screen (still visible for about a
   second at startup), so run windowed jobs only when visuals changed, batch them, never in a loop;
   everything else runs headless. Black Diamond runs Godot on this PC at the same time: see "Side by
   side" below.
10. **Keys.** Never read, print or commit API keys or `.env` files. Scripts load keys at run time
    (environment first, then `C:\Users\stewa\ClaudeProjects\Noclip\.env`) and never print them.
11. **Git.** Stage explicit paths only; never `git add -A` or `git add .`. Never force-push or
    rewrite pushed history.
12. **Original work.** Assets CC0 or CC-BY only (fonts: SIL OFL or Apache 2.0), each with a line in `docs/CREDITS.md`; paid
    generation logged in `docs/SPEND.md` (soft cap about $40 per session). No names, code, art or
    text from FTL, Barotrauma or any other game. Real history (Byrd, Kola, Project Mohole) appears
    only as discoverable lore.
13. **Writing.** No em dash in anything a player or reader sees: UI and game text (the data lint
    rejects them in game data), docs, the making-of page, commit messages, chat. Use a comma, colon,
    period or spaced hyphen. Code and code comments are fine (Stewart, 2026-10-17).

## Everyday commands (from the repo root)

| Command | What it does |
|---|---|
| `python tools/check.py` | Import, 24+ headless tests, selftest, error scrape. Must say `check: ok`. |
| `python tools/shots.py --names start,fire,arrive,flood,fire_out,end` | Off-screen stills at story moments, to `harness/out/shots/`. |
| `python tools/capture.py` | Movie Maker clip, stills, motion sheets, perf, blind-critic inbox, progress picture. |
| `python tools/perf.py` | Realtime frame times on the NVIDIA GPU; flags contention. |
| `python tools/balance.py --runs 700 --procs 6` | Thousands of headless runs per bot, then a report. `--bench` = M1-shaped speed test. |
| `python tools/determinism.py` | Headless and Movie Maker runs must end in the same hash. |
| `python tools/export.py` | Windows release build in `builds/`, then runs it with a bot. |
| `python tools/snapshot.py` | Frozen `.pck` of the project for long background runs (`balance.py --pack`). |
| `python tools/coexist.py` | Side-by-side checks: concurrent imports, focus, GPU contention. |

## Side by side with Black Diamond

Two Godot games are built on this PC at once. Never kill Godot by name; kill only your own process
tree. Keep every output inside this repo. No fixed ports (no editor, no MCP). Capture windows are
unfocusable and parked off-screen by `game/view/boot.gd` and `tools/proc.py` (`--position` alone is not
enough: Godot pulls the window back onto the screen). Perf numbers taken while another Godot renders are marked untrusted;
re-measure later instead of tuning on them. Batch jobs run at most 6 processes at below-normal
priority. C: is tight on space: no raw movie files kept, outputs pruned. Shared rules:
`C:\Users\stewa\Documents\Claude\GODOT-SIDE-BY-SIDE.md`.

## Talking to Stewart

- Short plain-English bullets: what shipped, what needs him, what is next. Details live in the repo.
- Commands for him: Windows PowerShell 5.1, one line, chained with `;` (never `&&`), starting with
  `cd "C:\Users\stewa\Documents\Claude\Inner Sun";`, full absolute paths, fenced as `powershell`.
- Send progress pictures as they land (`docs/progress/`, via `python tools/progress.py`); keep
  working without waiting for a reply.

## Checkpoint protocol

When Stewart types "checkpoint": finish or safely stop the current step (never leave the tree
broken), update `PROGRESS.md` and `HANDOFF.md`, commit with explicit paths, push, and stop with a
two-line summary of where things stand.

## Conventions

- Units: SI inside (m, kg, s, kW, kJ); temperatures in C. Ship space: meters, +x right, +y down
  (like Godot 2D), origin at the ship's top-left; the cutaway draws at 80 px per meter for now.
- Sim tick 60 Hz; hazards update at 10 Hz and crew decide at 4 Hz inside it.
- Files under about 400 lines where practical. Godot 4.4+ writes `.uid` files next to scripts:
  commit them. Commit `.import` files; never commit `game/.godot/`.
- Progress pictures go to `docs/progress/` whenever something visibly changes (Stewart keeps the
  build history). At every milestone and big visual moment, also add a row, a clip and a git tag
  to the making-of record (`docs/making-of/README.md`); never prune it.
