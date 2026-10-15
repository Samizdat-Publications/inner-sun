# Spec: the drilling view (greybox, M1 step 1 view)

For a builder after the DrillSim merge. Read CLAUDE.md, docs/ARCHITECTURE.md (view rules),
game/sim/drill/** (the API: grid, cols, rows, cell_m, ship_pos, heading_deg, speed_m_s, bit_wear,
cutting, progress(), target_y, chunk change counters, material lookup with color hints),
game/view/main.gd, game/view/ship_view.gd, game/view/capture_director.gd, tools/shots.py, and the
HANDOFF gotchas (15 lights per canvas item, light height for normal maps, glow needs emission above
1.0 after CanvasModulate).

## Goal
Watching a drilling segment should already feel good in greybox: the tall tower grinding down
through layered rock, the shaft above it, ore veins and gem pockets glinting in the floodlights,
the crown glowing and throwing sparks while it cuts, water pockets dark and wet, the interior still
alive. Readable first, pretty second.

## Pieces
- `game/view/rock_view.gd` (new): draws the grid in chunk sprites (16 x 16 cells), each a
  CanvasTexture (albedo + normal) built from an Image at 8 px per cell (scaled to 80 px per meter):
  per-material base color from the data's color hint, per-cell value noise for texture, darker
  rims where solid meets air, strata tint by depth. The normal map comes from a blurred solid/air
  height field so shaft walls and pockets catch the floodlights. Only chunks whose change counter
  moved are rebuilt. A dim back-wall layer behind air cells so the shaft is not pure black. A
  separate additive, unshaded glint layer for gem and ore cells (modulate divided by the
  CanvasModulate color so gems bloom). Rock chunks use light mask layer 2; only rock lights (hull
  floodlights, the crown glow) reach them. One LightOccluder2D per chunk from merged solid runs,
  rebuilt when the chunk changes.
- `game/view/ship_view.gd`: the static M0 rock becomes optional (off when a RockView is present);
  the drill polygon becomes the crown under the tower, glowing (HDR, compensated) and pulsing while
  cutting; sparks (CPUParticles2D) and dust at the crown while cutting; 2 to 4 hull floodlights on
  light layer 2 aimed at the rock below and beside the hull. The ship node moves with
  `ship_pos * ppm` in segment space.
- `game/view/main.gd`: when a drill segment is active, build the RockView and frame the camera on
  the tower with about 4 m of rock visible below the crown; follow smoothly. In normal play, A and
  D (or arrow keys) push `steer` commands (-30, 0, +30 degrees), W and S add or remove drill power.
- `game/view/capture_director.gd`: drilling moments for shots: `drill_start`, `ore` (first ore
  mined), `burst` (pocket_burst), `segment_done`.

## Verify
`python tools/check.py` passes; `python tools/shots.py --scenario drill_segment --names
drill_start,ore,burst,segment_done` produces frames; look at them; fix what looks wrong; a
`python tools/capture.py --scenario drill_segment` fills the review inbox.
