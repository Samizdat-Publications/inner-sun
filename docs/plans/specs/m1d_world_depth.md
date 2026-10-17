# Spec: world depth (ledger 34; critics 005 to 008)

For a `builder` (Sonnet) in its own worktree. View only: nothing in game/sim changes.

## Why
Four critic reviews in a row score the world outside the hull lowest (3 to 6) for one reason:
"a flat, infinitely scrolling rock texture that feels like a treadmill, not a world ... I want to see
background layers, buried structures, or giant caverns passing behind the ship" (Gemini 008). Stewart
asked for "parallax layers behind the rock". The rock is the cut plane of a side cutaway: it fills
the view, so depth has to come through the openings (the shaft the tower leaves above itself,
tunnels, caverns, structure interiors), from things in front of the plane, and from the rock itself
changing as you descend.

## Read first
CLAUDE.md (hard rules), HANDOFF.md gotchas (about 15 lights per canvas item, so keep big sprites in
small chunks or unlit; glow and unshaded boosts; light height), game/view/rock_view.gd (header,
`_build_backdrop`, `_wall`: the present back wall is one plane with the rock, so it scrolls at the
same speed), game/view/ship/rock_tiles.gd (the rock shader `SHADER_CODE`), game/view/dig_camera.gd,
game/view/main.gd (how the drilling camera moves, how RockView is built and cleared per segment),
game/view/structure_layer.gd (another layer in segment space). Godot 4.7.2 API in the main repo's
`C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\` (git-ignored), in
particular Parallax2D.xml (scroll_scale, repeat_size, repeat_times).

## Owned files
New `game/view/depth_layers.gd` (DepthLayers: the far wall, the silhouettes and the dust),
`game/view/rock_view.gd` (only `_build_backdrop` and what the far wall replaces, plus passing the
depth uniform), `game/view/ship/rock_tiles.gd` (the shader: depth bands), `game/view/main.gd` (create
and bind DepthLayers; keep the edit small, it is over 400 lines), a test `game/tests/test_depth_layers.gd`
(pure functions: band index and tint by depth, silhouette placement by hash), `docs/progress/`.
Nothing else.

## What to build
1. **The far wall, with parallax.** Replace the static back wall behind air with a far rock wall that
   moves at about 0.45 of the camera's scroll (Parallax2D, or move it yourself from the camera
   position each frame), darker and cooler than the rock and a little blurred-looking (a larger tile
   scale, lower contrast), so the shaft above the tower, tunnels, caverns and hollows show rock that
   is clearly further away. It must still fill every opening (no black holes at segment edges or when
   the camera zooms out with the wheel). Lit only faintly by the hull floodlights, or unlit with a
   painted falloff: whichever keeps the light count safe.
2. **Silhouettes between.** Layers from far to near: the far wall (about 0.45 of the camera's
   scroll), then silhouettes (about 0.7), then the rock (1.0), then dust (1.25). The silhouettes are
   drawn over the far wall and behind the rock, so they too show only through openings: big, dark,
   soft shapes of a cavern in between, stone columns, stalactite curtains, a natural arch, each with a
   faint rim of light; on the far wall now and then a faint warm or green glow far off (heat, or
   something living). Placed by an integer hash of the segment and depth (the view may use its own
   hash randomness, never the sim's streams), sparse: one notable shape every screen or two of
   descent, so passing one is an event.
3. **Dust in front.** A few dozen slow motes in front of the rock and the ship's exterior, moving at
   about 1.25 of the camera's scroll (so they slide past faster than the rock), brighter inside the
   floodlights' reach and invisible outside it, tiny and soft. Only over the world area, never over
   the HUD. Off in combat if it fights the readability of the fight.
4. **Depth bands in the rock.** The rock shader gets the absolute depth of each pixel (a uniform for
   the segment's top in metres below the surface; derive it from DrillSim and check it against the
   depth readout in a still) and tints the rock in broad bands 25 to 60 m thick: each band's hue and
   value shift a little (iron red, pale limestone, grey-blue shale, dark basalt...), chosen by band
   index through a hash, blending over about 2 m at the boundary, with a thin darker seam line at the
   boundary. Ore, gems and their glints keep their own colours (do not tint them away). The point:
   the player sees that they are passing from one bed into another, and the descent has landmarks.
5. **Perf.** No per-frame allocation; at most a few hundred extra draw items; the rock's frame budget
   (BUDGET_USEC) unchanged. Measure nothing on this busy PC; just keep it light.

## Checks
Strict typing, no em dashes anywhere. `python tools/check.py` must print `check: ok`. Windowed runs
flash a window on Stewart's screen: at most 3 windowed jobs in total. Stills that must show it:
`python tools/shots.py --mode run --bot balanced --seed 7 --names t20,t70,t140 --out
harness/out/shots_depth --extra=--duration=150 --no-import` (the shaft above the tower and the bands
over a descent; add `--timeout 400`), and `python tools/shots.py --scenario structure_demo --seed 5
--names t44 --out harness/out/shots_depth2 --extra=--look=structure --no-import` (a big hollow showing
the far layers). LOOK at them at full size: the far wall must read as further away than the rock, the
bands must be visible but not garish, ore must still pop, the HUD must be untouched.
One progress picture: `python tools/progress.py <png> --label m1d-world-depth --note "..."`.
Stage explicit paths only, commit on your branch with a message ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not push or merge.

## Report (under 25 lines)
Branch and commit, files changed with line counts, what each still shows (paths), the parallax
factors and band thicknesses you chose, check result, anything not done or not seen.
