# Spec: hazards that look like emergencies (ledger 25 and 33)

For a `builder` (Sonnet) in its own worktree. View only: nothing in game/sim changes.

## Why
Gemini critics 006 and 008 both put the hazards first: "the fire in the Drill Room is just a
pixelated flame overlay that doesn't cast light or interact with the room's visuals. I want dynamic
lighting from the flames and smoke filling the upper compartments" (008, "ruins it"); "fire and
flooding lack impact (a tint and sparks)" (006). Fire and flooding are the FTL half of the game: a
burning room must read as an emergency in one glance at 1080p.

## Read first
CLAUDE.md (hard rules), HANDOFF.md gotchas (about 15 lights per canvas item; glow and unshaded
drawings: modulate 0.9 to 1.1 for glow sprites, a x1.8 to x2.0 boost for unshaded drawings, filled
HDR shapes ignore alpha so translucent fills go on an additive layer with plain colours; light height
120 to 260 px), then game/view/ship_view.gd (`_build_flames`, the fire light per room around line
341, the per-room update around line 700, the z order in its header), game/view/ship/room_fx.gd,
room_water.gd, art_lib.gd, crew_sprite.gd (only to see what the light reaches). Room state comes
from the sim's Room: `fire` (0 to 1), `temp_c()`, `level_m()`, `breach_m2`. Godot API: the main
repo's `C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\` (git-ignored).

## Owned files
New `game/view/ship/room_fire.gd` (RoomFire: build and update the fire, smoke and scorch for every
room; move the existing flame and fire-light code out of ship_view.gd into it, so ship_view.gd
shrinks, it is over 400 lines), `game/view/ship_view.gd` (only the calls into RoomFire and removing
what moved), `game/view/ship/room_fx.gd`, `game/view/ship/room_water.gd`, `game/view/ship/art_lib.gd`
(texture generators), a new test `game/tests/test_room_fire.gd` (pure functions only: flame height
from the fire level, smoke amount, scorch decay), `docs/progress/`. Nothing else.

## What to build
1. **Flames that fill the room.** Replace the square particles with soft flame tongues: generated
   textures (a vertical teardrop gradient, white-yellow core to orange to transparent red), additive,
   in two or three layers (a bright core low along the floor, taller tongues, a few embers drifting
   up). Their height follows `fire`: a lick along the floor at 0.1, about 60% of the room's height at
   1.0. They spread along the floor across the room's width with the fire level, not as one blob.
2. **Light that matters.** The room's fire light flickers harder and reaches the room's painted art
   and its crew warmly (energy and radius up with `fire`; keep shadows as they are). Keep the light
   count per room as it is (one fire light per room): lights are scarce.
3. **Smoke.** Dark, soft, slow particles rise from the flames and a smoke haze collects under the
   ceiling: a band from the ceiling down that thickens with `fire` and with how long the room has
   burned (a view-side timer per room), thins out over about 8 s after the fire is out. Where a
   ladder or hatch joins the room above, a thinner haze shows in the room above too (cosmetic only).
   Smoke is drawn normally (not additive) so it darkens what is behind it.
4. **Scorch.** A burned room keeps a dark scorch along its floor and lower walls that fades over
   about 30 s after the fire is out (view memory; resets on a new run or segment rebind).
5. **Water that hides the machinery.** In `room_water.gd`, the water body gets more opaque with
   depth (murky, so the painted machinery below the surface is hard to see when deep), a bright
   surface line with small ripples, and the existing foam. Keep it readable through to the crew
   (crew stay visible: they draw above the water already, check the z order).
6. **Perf discipline.** At most about 200 live particles per burning room and nothing allocated per
   frame. Idle rooms cost nothing (emitting off, nodes hidden).

## Checks
Strict typing, no em dashes anywhere. `python tools/check.py` must print `check: ok`. Windowed runs
flash a window on Stewart's screen: at most 3 windowed jobs in total. Stills:
`python tools/shots.py --scenario fire_drill --seed 1 --names fire,flood,fire_out,t20 --out
harness/out/shots_fire --no-import`, and LOOK at them at full size: the fire must read as an
emergency, the light must reach the room, the smoke must be visible under the ceiling and in the room
above, the water must hide the machinery when deep, labels and crew must stay readable. One progress
picture: `python tools/progress.py <png> --label m1d-hazard-visuals --note "..."`.
Stage explicit paths only, commit on your branch with a message ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not push or merge.

## Report (under 25 lines)
Branch and commit, files changed and their line counts, what each still shows (paths), particle and
light counts per burning room, check result, anything not done.
