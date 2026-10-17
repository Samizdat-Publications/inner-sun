# The making of Inner Sun

Stewart asked (2026-10-15) for every project to keep labeled copies of its milestones, so a "making
of" page can show the whole journey from the first prototype to the finished game. This folder is
that record. Keep it current as you go; never prune it.

## What is kept, and where
| Kind | Where | Rule |
|---|---|---|
| Progress pictures | `docs/progress/NNN_<label>.jpg`, listed in `docs/progress/INDEX.md` | Whenever something visibly changes (`python tools/progress.py`). |
| Milestone clips | `docs/making-of/clips/NNN_<label>.mp4` | 10 to 30 s, 1280x720, H.264, under about 4 MB, at each milestone and big visual moment (cut from a `tools/capture.py` clip with ffmpeg). |
| Critic scores over time | `review/scores.csv`, reviews in `review/critiques/` | Every critic loop. The score curve is part of the story. |
| Milestone builds | `builds/milestones/<tag>/` (not in git; local copy) | Zip of the exported build at each milestone gate and playtest build. |
| Git tags | `m0-loop-proven`, `m1a-playtest`, ... | One annotated tag per milestone gate, pushed. |
| Decisions and turns | `docs/DECISIONS.md`, `docs/STEWART_FEEDBACK.md` | The why behind each change of direction. |
| Timeline | this file, below | One row per milestone or memorable moment, with links to the above. |

## The live page
Published as a private artifact: https://claude.ai/artifact/UJjDA4PJkSXMKjpg2zxQpc (source `docs/making-of/index.html`).
Republish it after each milestone or big visual moment: add an entry, update the "Right now" box and
the score chart, and map any new pictures in the publish `files`.

## Timeline
| When | Moment | Picture / clip | Commit or tag | The story in one line |
|---|---|---|---|---|
| 2026-10-15 | Kickoff and plan approved | - | `cb500b6` | Stewart pitches a drill ship boring into a hollow Earth; the tall tower ship is chosen. |
| 2026-10-15 | M0: the autonomous loop proven | `docs/progress/001` to `003` | `m0-loop-proven` (`24d0767`) | A node-free sim, a bot, off-screen frames, planted bugs caught, the same hash everywhere. |
| 2026-10-15 | M1 begins: the blind critic installed | `docs/progress/004`, `clips/001` | `e2dc572` | The critic's guard is live-tested; the first exposure lift so the critic can see anything. First review: 3.8 out of 10 ("a debug view, not a game yet"). |
| 2026-10-15 | The M1 skeleton | - | `de5e103` | The sim grows from one fire drill to a whole run: two ships, phases, modules. |
| 2026-10-15 | Art bake-off, style C | `stills/001` | `3f4b62f` | Blender pre-rendered sprites with real normal maps, lit in Godot; HDR glow finally blooms. |
| 2026-10-15 | The drill bites | `stills/003`, `docs/progress/008` | merge of the drill view | The tower grinds down a real shaft through layered rock: ore veins glint, a gem geode in a basalt shell, sparks at the crown. The critic's "no world outside" answered. |
| 2026-10-15 | Run screen pieces | `docs/progress/006`, `007` | UI merge | The HUD and the typewritten dossier with redaction bars and TOPSIDE's radio strip. |
| 2026-10-15 | The ship comes alive | `stills/004`, `docs/progress/011`, `012` | painted cutaway merge | Painted rooms, props, crew puppets and the glowing crown replace the grey boxes; hazards read at a glance. |
| 2026-10-15 | First fight on screen | `stills/005`, `docs/progress/010` | combat view merge | Two drill towers trade fire through the rock: tracers, a BLOCKED pop, weapon cards. |
| 2026-10-16 | M1a playtest build | `clips/002` (drilling), `stills/006` (combat in the rock, before the final framing fix), `docs/progress/018` to `020` | `m1a-playtest` | A whole run, painted, with fights in the rock, events, a store and a death report; the blind critic's score climbs 3.8, 5.8, 6.1; the bots win 12 to 19 percent. Handed to Stewart to play. |
| 2026-10-16 | Playtest build 2 | `docs/research/m1-evidence/perf_run_mode_after_fix.json` | `m1a-playtest-2` | The last audit catches stutter while drilling (frames up to 44 ms); repainting only the cut cells under a frame budget brings the 1% low from 31 to 78 fps. This is the build Stewart plays. |
| 2026-10-16 | M1b: digging is the game | `docs/progress/021`, `022` | `50a1c78`, `a8965a2` | Stewart's playtest: nothing to do but steer. Controls fixed and hand-tested, a zoomed-out drilling view, and a new economy of nine ores and gems. Gemini watches video for the first time: 5.6. |
| 2026-10-16 | M1b playtest build 3 | `docs/progress/023`, `024` | `m1b-playtest-3` (`88d916d`) | Ore you can see, pickups and a dig tally, surveys on the map, a 14-row Crust with 20-minute runs. Gemini: 6.8, up from 5.6; the rock texture is next. |
| 2026-10-16 | M1c playtest build 4 | `docs/progress/025` to `027` | `m1c-playtest-4` (`e1ffb36`), `m1c-playtest-4b` (the build Stewart plays) | Every system gets a job in the dig (side cutting, rockfalls, blasts, douse), buried structures to break into, research and requisitions, and the rock redrawn as fractured stone. Gemini: 4.5 on the first cut ("wavy sand"), 6.1 after the rock fix, the world outside the hull 3 to 6. |
| 2026-10-17 | M1d playtest build 6: Stewart's first notes on 5c | `harness/out/shots_m1d/hatch2` | `m1d-playtest-6` | He sent the miner six times in his first run and it brought home almost nothing, chewed the tower's own floor on the way out, and he asked how to pause. Now the miner climbs out a side hatch, the aim says what a click is worth, and TOPSIDE teaches each verb once, the first time it would pay off. |
| 2026-10-17 | M1c playtest build 5: the away miner | `docs/progress/028` to `030` | `m1c-playtest-5`, `m1c-playtest-5b` (adds fire, smoke and teal water), `m1c-playtest-5c` (adds world depth) | Park the drill and send one crew member into the rock with a pick and a headlamp to dig out a vein by hand; the haul pays only if they climb back in. Plus a requisitions toast, a crystal hollow lit blue, and the rock tile repeat broken. |
