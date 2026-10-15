# Tooling brief (researched 2026-10-15)

Findings from the planning session's research. Verify version-sensitive details again before
relying on them (the scout agent does this).

## Engine
- Godot 4.7.2 stable (2026-08-18) is the latest stable; 4.8 is in feature freeze, no beta yet.
  Installed via WinGet: `C:\Users\stewa\AppData\Local\Microsoft\WinGet\Links\godot_console.exe`
  (use the console exe: `godot.exe` prints nothing to a pipe). Export templates for 4.7.2 Windows are
  installed. The full class reference of this exact build is dumped at
  `harness/out/godot-api/doc/classes/` (signatures only).
- 4.6: new Windows projects default to D3D12 (we force Vulkan); glow blends before tonemapping with
  Screen as the default blend mode and a lower default intensity. 4.7: HDR display output; overrides
  of methods with typed returns need an explicit return; setting a packed-array element no longer
  calls a property setter; new projects default to `canvas_items`/`expand` stretch.
- `--headless` never starts the GPU: anything that renders needs a real (off-screen) window.
  Movie Maker: `--write-movie <file> --fixed-fps 30 --disable-vsync --quit-after <frames>`, frame-exact.
- Godot 2D lighting: one canvas item takes only about 15 to 16 lights; extra lights are silently
  dropped. Split big drawings into small nodes, disable idle lights. Sources:
  https://forum.godotengine.org/t/working-around-godots-2d-light-limitations-for-a-dark-game/81311 ,
  https://godotforums.org/d/36044-after-15-pointlight2d-nodes-new-ones-dont-light-up-the-viewport
- Normal-mapped sprites need a light `height` well above zero or they look nearly black (the shading
  term goes to zero for lights in the sprite's plane).

## Tests
- GUT 9.7.1 (godot_4_7 branch, MIT): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`.
- gdUnit4 6.2.2 (MIT): headless needs `--ignoreHeadlessMode`; exit codes 0, 100, 101, 103, 105.
- We use a small custom runner (D009).

## Narrative and AI libraries
- inkgd: dormant (last release 2023, godot4 branch last touched 2024). GodotInk: needs the .NET build.
  Dialogic 2: still alpha (2.0-alpha-20, 2026-07-21), needs the scene tree.
- LimboAI 1.8.1 and Beehave 2.9.3 support 4.7 but both need scene Nodes.
- Decision: own event system and own crew AI in the headless sim (D006, D007).

## Godot MCP servers (2025 to 2026)
Coding-Solo/godot-mcp (runs Godot itself, captures output, no screenshots or input), hi-godot/godot-ai
(needs a running editor, ports 8000 and 9500), godot-mcp-pro (editor plugin, port 6505, paid server),
GDAI MCP (paid plugin), satelliteoflove/godot-mcp (editor port 6550), tugcantopaloglu/godot-mcp
(fixed port 9090 for live game tools), Erodenn/godot-mcp-runtime (free port). None needed (D010).

## Destructible terrain (for the drilling segment)
- Keep the rock as a CPU grid (works headless; the sim owns it). Draw it as chunk textures of 128 to
  256 px and update only changed chunks (`ImageTexture.update` replaces a whole texture; there is no
  partial update). Use `fill_rect`, `blit_rect` and friends instead of per-pixel loops where possible.
- Collision and light occluders per changed chunk: `BitMap.create_from_image_alpha()` then
  `opaque_to_polygons()` (marching squares in C++).
- `DrawableTexture2D` (4.7, experimental) draws on the GPU and does nothing headless: view-only effects.
- Compute shaders: unavailable headless; only worth it at falling-sand scale.

## Barotrauma (reference only; do not copy code)
The source is on GitHub (FakeFishGames/Barotrauma) under a source-available license: read it for
ideas only. Its hulls and gaps model water by room and opening, which is the approach used here.
