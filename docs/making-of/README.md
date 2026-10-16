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
