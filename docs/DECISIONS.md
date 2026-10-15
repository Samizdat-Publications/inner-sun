# Decisions

Each entry: the choice, why, and how to undo it. Tags: S = Stewart, AI = decided by Claude.

## D001 (S): FTL-style, 2D side-view cutaway, roguelite runs, Godot 4 native Windows
From the kickoff (`docs/STEWART_FEEDBACK.md`). Not revisited without Stewart.

## D002 (S): The ship is a tall tower
Decks stacked, drill at the bottom, boring straight down. Chosen over a horizontal mole in the
planning session (2026-10-15). Hazards stack by deck: water pools low, heat and gas rise.

## D003 (S): Inner Sun and Black Diamond are the only Godot projects running for now
Cut & Fill is paused (2026-10-15). Both projects follow the side-by-side rules in
`C:\Users\stewa\Documents\Claude\GODOT-SIDE-BY-SIDE.md`.

## D004 (AI): Godot 4.7.2 Forward+ on Vulkan, strictly typed GDScript, no C#
Latest stable (4.8 not released). Vulkan is forced (`fallback_to_d3d12=false`) because new Windows
projects default to D3D12 and every capture on this PC is proven on Vulkan. No C#: needs the .NET
Godot build and nothing requires it. Revert: change `rendering_device/driver.windows`.

## D005 (AI): Rules in a node-free GDScript sim; Rust only for a measured hot spot
Benchmark (M1-shaped load): about 28,500 ticks/s single process against a 6,000 budget. GDScript
stays. Revert path: port the hot spot to Rust via gdext (Cut & Fill's proven toolchain).

## D006 (AI): Own event system in JSON, not ink or Dialogic
inkgd is dormant since 2024, GodotInk needs C#, Dialogic 2 is still alpha and needs the scene tree;
none runs inside headless balance runs. A friendlier writing format can compile to the same JSON.

## D007 (AI): Own crew job AI, not Beehave or LimboAI
Both need scene Nodes; the sim must run headless. Pathing uses Godot's AStar2D over rooms, doors and
ladders. Revert: LimboAI with stand-in nodes in the view layer only.

## D008 (AI): Room-level water and heat with exact integer conservation
Like Barotrauma's hulls and gaps, never per pixel. Water in mL, heat in J, moved in exact pairs;
tests assert equality. Hatches pass heat upward far better than downward (heat rises).

## D009 (AI): Custom headless test runner, no GUT or gdUnit4
Matches the sibling projects (Noclip, Cut & Fill); no add-on version coupling (Godot 4.7's typing
change broke GUT until it was patched). A Logger installed before tests load fails any test that
produces an engine error. Revert: GUT 9.7.1 (godot_4_7 branch) if doubles or parametrized tests are
needed.

## D010 (AI): No Godot MCP server
Evaluated on paper (2026-10-15): Coding-Solo/godot-mcp only duplicates what the command line already
does here (no screenshots, no input); the editor-connected servers (godot-ai, godot-mcp-pro, GDAI,
satelliteoflove) need a running editor and fixed ports, which would collide with Black Diamond.

## D011 (AI): Every Godot run inside a Windows job object; never kill by name
Processes start suspended, join a job with kill-on-close, then resume, so the real exe that the
console wrapper spawns is inside too. Proven: a timed-out run and a tool killed from outside both
left no process behind. A name-based "reap strays" helper was refused by the safety filter and is
not needed.

## D012 (AI): Windows are created unfocusable; normal play takes focus back
Measured: an off-screen Godot window still takes the foreground (65 of 71 samples). The project sets
`display/window/size/no_focus=true`; the Boot autoload restores focus for normal play only. Bot runs
never touch Stewart's keyboard (0 of 70 samples).

## D013 (AI): Split the cutaway into small canvas items
Godot lets one canvas item take only about 15 lights; one big drawing lost lights and went dark in
the first M0 captures. Per-room, per-crew and per-chunk nodes; idle lights disabled.

## D014 (AI): Playtest builds and the critic install
The blind critic's guard and agent file are staged in `docs/setup/critic/` because this planning
session inherited Cut & Fill's deny rule for those paths. The first build session installs them
(HANDOFF.md step 0). Revert: none needed.

## D015 (AI): Working title stays Inner Sun
Alternatives if wanted: Superdeep, Mohole. The folder and repo keep their names regardless.
