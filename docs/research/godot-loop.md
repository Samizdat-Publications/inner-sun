# Milestone 0: the autonomous Godot loop, proven

Date: 2026-10-15. Machine: Core Ultra 9 285H, RTX 5070 Ti Laptop GPU (plus Intel iGPU), Godot 4.7.2
stable (WinGet). Gate question from the kickoff: can Claude run the game headless or scripted, drive
it with a test bot, capture frames from the game camera, run automated tests, read errors and logs,
and fix what it sees without Stewart? **Answer: yes.** Each capability below has a command and saved
evidence (`docs/research/m0-evidence/`).

## 1. Headless and scripted runs
- `python tools/check.py`: headless import, then the test runner, then a `--selftest` boot of the real
  main scene. Result: `TESTS passed=24 failed=0`, `SELFTEST ok`, `check: ok`.
- `--run-ticks=<n>` runs the real game for exactly n ticks (headless or windowed) and prints
  `FINAL tick=<n> hash=<h>`.

## 2. A bot drives the game through the player's command chain
- `FireDrillBot` turns the crew's own judgement off and gives every order as commands: nearest free
  crew member to each fire, then each breach, everyone else back to station. Timeline from the
  `fire_drill` scenario: fire at T+2.0 s, breach at T+6.0 s, Okafor climbs down and arrives at
  T+6.8 s, Lindqvist reaches the breach at T+10.8 s, fire out at T+11.7 s, breach patched at T+17.6 s.
- Balance bots: `auto` (crew judgement on), `idle` (nobody responds), `random` (random orders).
- The player's mouse click sends the same `assign` command the bots use.

## 3. Frames from the game camera, with no window on screen
- `python tools/shots.py --names start,fire,arrive,flood,fire_out,end`: the real game in a window parked
  at -32000,-32000; shots at story moments taken from the sim's own events. `SHOTS done renderer
  NVIDIA GeForce RTX 5070 Ti Laptop GPU`. Pictures: `docs/progress/002_*.jpg`, `003_*.jpg`.
- `python tools/capture.py`: Movie Maker at 30 fps in the off-screen window: 12 stills, 3 motion
  sheets (9 frames 0.4 s apart), an H.264 clip (raw AVI deleted at once), frame counts checked with
  ffprobe, black-frame check, the blind-critic inbox refilled, a contact sheet saved as
  `docs/progress/001_*.jpg`.

## 4. Automated tests with real exit codes
24 headless tests: heat rises through hatches, exact energy conservation, coolant works, fire spreads
if ignored and dies if fought, water puts fire out, water runs down hatches into the lowest room,
exact water conservation, full rooms stay full, crew climb ladders, crew pick the nearer fire, crew
obey orders, crew handle fire plus breach, same seed same state, different seeds differ, replay
rebuilds a run, no leaks over 200 runs, no global randomness in sim code, every script compiles,
strict typing on, loop settings in place, data lints clean, the lint names broken references, every
tuning number is used. Any engine error during a test fails that test (a Logger installed first).

## 5. Errors and logs, read and fixed without Stewart
Three planted bugs (`m0-evidence/planted_bugs.txt`), each caught, named and reverted:
1. A design rule broken in data (hatches no better upward than downward):
   `TEST FAIL test_heat::test_heat_rises_through_the_hatch ... (up 231092 J, down 231090 J)`.
2. A broken data reference: `res://data/ships/light_drill.json: links[4] "hatch_reactor_drill": room
   "cellar" does not exist in this ship`, and the selftest refused to run.
3. A script type error: `Parse Error: Variable "reach" has no static type. (Warning treated as
   error.) at: res://sim/crew/crew_ai.gd:47`, plus every dependent failure.

Real problems the loop found during M0 and fixed on its own:
- **Dark captures:** Godot lets one canvas item take only about 15 lights; the first cutaway drew
  everything as one item under 24 lights and lost some. Fixed by splitting into per-room, per-crew
  and per-chunk nodes and disabling idle lights.
- **Focus stealing:** an off-screen Godot window still took the foreground (65 of 71 samples).
  Fixed: windows are created unfocusable; the Boot autoload gives focus back for normal play only.
  After the fix: 0 of 70.
- **A hang:** with a script that fails to compile, tests waiting for a run to finish spun forever.
  Fixed: `ScenarioRun.play_to_end()` caps every run, `Sim.replay` stops if the sim stops advancing,
  and the test runner times out after 240 s naming the test that hung.
- **Silent wrap-around:** a broken link reference became index -1, which GDScript arrays accept.
  Fixed: the ship builder refuses such links (the lint already reported them).

## 6. Balance by simulation
`python tools/balance.py --runs 700 --procs 6`: 2,100 generated runs in 71 s.

| Bot | Survival | Main causes of death |
|---|---|---|
| auto (crew judgement) | 99.4% | fire 0.6% |
| idle (nobody responds) | 50.6% | fire 31.0%, heat 18.4% |
| random orders | 40.6% | fire 45.0%, heat 11.3%, drowned 3.1% |

About 40,000 ticks/s per process with 6 busy. The M1-shaped benchmark (`--bench`: 6-room tower,
3 crew, hazards, a drilled rock grid, 24 projectiles) runs 28,491 ticks/s in one process (sim
15.5 us, terrain 5.6 us, projectiles 13.9 us per tick), 4.7 times the 6,000 budget. GDScript stays.

## 7. Determinism across processes and binaries
- `python tools/determinism.py`: headless and Movie Maker runs both end at `hash 85cbc093e13e52e5`
  at tick 1200.
- `python tools/export.py`: the exported release build (`builds/InnerSun.exe`, 109 MB, plus a
  1.1 MB pck) ran off-screen with the bot and ended on the same hash.
- `python tools/snapshot.py` plus `balance.py --pack`: 60 of 60 runs from a frozen pack matched the
  live runs seed for seed.

## 8. Performance
`python tools/perf.py`: average 240 fps (Windows caps windowed fps at the 240 Hz refresh), 1% low
152 fps, p95 4.68 ms, GPU 0.71 ms, NVIDIA adapter, uncontended. Runs taken while another Godot
project rendered are flagged untrusted (`m0-evidence/perf_contended_example.json`).

## 9. Living beside Black Diamond
`python tools/coexist.py`: two Godot projects importing at the same time showed no port clash (with
or without explicit ports); the focus check passed after the fix; with Black Diamond rendering, perf
named its processes and marked the numbers untrusted, and shots still succeeded.

## 10. The blind critic
The guard is unit-tested (`python tools/test_guard.py --staged`: 21 of 21, from any working folder,
and it fails closed on bad input). It is staged in `docs/setup/critic/` and installed by the first
build session (HANDOFF step 0), which then runs the live test and the first critic loop.

## 11. Evaluated and not used
- Test frameworks: GUT 9.7.1 and gdUnit4 6.2.2 support 4.7, but a small custom runner matches the
  sibling projects, needs no add-on, and attributes engine errors to tests. See D009.
- Godot MCP servers: none adds a capability the command line lacks here, and the editor-connected
  ones need fixed ports that would clash with Black Diamond. See D010.
- Process clean-up by name: never. A PID-based "reap strays" helper was refused by the safety filter
  and proved unnecessary: job objects cleaned up even when the tool itself was killed.

## Limits found
- HDR 2D glow is configured but its bloom halo is not visible yet (M1 look-dev).
- The Gemini video-and-audio critic from Noclip (`C:\Users\stewa\ClaudeProjects\Noclip\tools\critic_gemini\critic.py`)
  is not ported yet; port it for milestone gates.
