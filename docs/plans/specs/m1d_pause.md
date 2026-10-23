# Spec: a pause you can see (Stewart, build 6)

His note: "pausing does not stop the animations of everything on ship etc, I did not realize it was
paused at first." The sim stops on pause (`Main.paused`), but the view keeps animating on frame time:
crew idle and work frames, flames, smoke, embers, sparks, dust, lamp flicker, fire light flicker,
spray particles.

## Build
1. One switch: `Main.paused` (and a held world: the map or help open) freezes the whole world view.
   Use per-node process modes or an explicit freeze call down the view classes, whichever is simpler
   and safer here: the world view nodes (ShipView, RockView, combat view, dig fx, miner layer,
   structure layer, depth layers) stop their `_process` and their CPUParticles2D (`speed_scale = 0`)
   while the HUD and overlays keep working. Do not use `get_tree().paused` if it stops input or the
   HUD. Read `game/view/main.gd`, `main_world.gd` and `main_input.gd` first.
2. Make paused obvious: dim and slightly desaturate the world area only (a translucent dark overlay
   over the world rect, not the HUD), keep the PAUSED label in the top bar, and add a large centred
   "PAUSED: SPACE TO RESUME" in the world area in amber (`UiTheme.AMBER`). The fight banner and the
   help or map hold labels keep their own text but get the same dim.
3. Unpausing resumes every animation where it stopped (no jump).
4. Bots and replays are never paused by this; pausing never changes the sim (view only).

## Tests
- A unit test that toggling pause freezes the world view nodes (particles' speed scale, process
  state) and clears it again, and that the HUD keeps processing (headless, built the way the existing
  view tests build RunScreen or ShipView).
- One still of the paused world: add a capture flag that pauses at a fixed time (for example
  `--pause-at=5`, listed in `Boot.BOT_FLAGS`) and take `python tools/shots.py --scenario fire_drill
  --names t7 --out harness/out/shots_pause` with it, then look at the still yourself. One windowed
  batch at most.

## Must pass
`python tools/check.py` prints `check: ok`. Determinism is untouched (view only); run `python
tools/determinism.py` only if you touched anything under `game/sim`. Never export or touch `builds/`.

## Owned files
`game/view/main.gd`, `main_world.gd`, `main_input.gd`, `ship_view*.gd`, `game/view/ship/room_fire.gd`,
`crew_sprite.gd`, `crew_work_fx.gd`, `game/view/dig_fx.gd`, `rock_view.gd`, `miner_layer.gd`,
`structure_layer.gd`, `depth_layers.gd`, `combat_view.gd`, `game/view/capture_director.gd` and
`game/view/boot.gd` (only for the flag), new files you create, and the test you add. Do not touch
`game/view/run_screen.gd`, `game/view/hud/**` or `douse_layer.gd` (the lead owns them this round); if
you need the PAUSED text there, add it in a new node you own and mount it from main.

## Report (under 200 words)
How the freeze works, what dims, the still you looked at, the check result.
