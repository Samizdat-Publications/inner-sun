# Critic ledger

Every issue a critic raises: FIX (then fix it), DEFER (to which milestone) or REJECT (with a real reason).
A rejected issue that returns in 2 later critiques becomes FIX or goes to docs/NEEDS_STEWART.md.

| # | Build | Critic | Issue | Verdict | Commit or reason |
|---|---|---|---|---|---|
| 1 | 20261015-183051-e2dc572 | claude 001 | Debug overlay instead of a UI; cannot tell what I may do | FIX | M1 step 3 to 5: real HUD (power bars, crew cards, alerts) replaces the M0 readout |
| 2 | 20261015-183051-e2dc572 | claude 001 | Ship is a small box in a black void; cutaway should fill the frame | FIX | M1 step 1: camera framing for drilling and idle; tower plus rock fills the screen |
| 3 | 20261015-183051-e2dc572 | claude 001 | No world outside the hull: no strata, depth or heat | FIX | M1 step 1: drilling segment, chunked rock with strata, ore, water pockets, drill face glow |
| 4 | 20261015-183051-e2dc572 | claude 001 | Rooms interchangeable, no props or system identity | FIX | M1 step 2: system props per room in the chosen art style, plus system icons in the HUD |
| 5 | 20261015-183051-e2dc572 | claude 001 | Crew are placeholder dolls and clip through floors on ladders | FIX | Draw order bug: crew must draw above floor frames while climbing; crew sprites from the art bake-off |
| 6 | 20261015-183051-e2dc572 | claude 001 | Overlapping labels, water line too thin to read, HP loss invisible on the body | FIX | View pass with the HUD: labels clear of ladders, filled water body, damage flash and HP pips |
| 7 | 20261015-183051-e2dc572 | claude 001 | Uniformly dark, brown on brown; only the fire is lit | FIX | Art bake-off and lighting pass (reactor glow, alarm cast, HDR glow) |
| 8 | 20261015-211550-4e6f253 | claude 002 | No fire anywhere in a whole dive; the alert bar is green most of the time | FIX | Hazard pressure tuning: more fire from hits and pursuer strikes, hotter drilling at high power; re-check balance |
| 9 | 20261015-211550-4e6f253 | claude 002 | Crew stand still at stations for minutes; no visible walking or working | FIX | Idle life in the view (breathing, glances, small shuffles at the station) plus more hazards for them to answer |
| 10 | 20261015-211550-4e6f253 | claude 002 | Flooding reads as a thin pinstripe at low levels | FIX | Breach spray at the leak, a blue tint and darker floor in a flooding room, a deeper-looking water body |
| 11 | 20261015-211550-4e6f253 | claude 002 | Combat drops the world to a black void; the rival looks like a mirrored copy of my ship | FIX | Rock behind and between both towers in combat; enemy towers get their own hull tint, cold lighting and red markings |
| 12 | 20261015-211550-4e6f253 | claude 002 | HUD type too small at 1080p; the bottom alert strip is a huge empty band | FIX | Larger type for room labels, resources and stats; a slimmer alert strip |
| 13 | 20261015-211550-4e6f253 | claude 002 | Pink-white blown-out patches on the rock beside the hull | FIX | Tame and warm the hull floodlights on the rock |
| 14 | 20261015-211550-4e6f253 | claude 002 | The ship reads as a box pasted on the drill tray | DEFER | M2 art pass: pipes and cables joining the cutaway to the crown |
| 15 | 20261015-231813-930fa47 | claude 003 (opus, gate) | The ship is tiny on screen with dead space around it | FIX | Zoom in: drilling 1.0 (was 0.85), cutaway 1.15 (was 1.0) |
| 16 | 20261015-231813-930fa47 | claude 003 (opus, gate) | No fire in this capture; 37 C looks like 22 C | FIX | Heat warmth shows from 30 C (was 50 C); fire frequency was raised in D022 (this run's fires were put out between stills) |
| 17 | 20261015-231813-930fa47 | claude 003 (opus, gate) | Crew read as static | DEFER | M1b: louder reactions (hurrying, flinching at hits, wading); the larger zoom makes the idle life visible |
| 18 | 20261015-231813-930fa47 | claude 003 (opus, gate) | Combat: the player's ship clipped by the left panel; the rival is a recolor; the backdrop has a hard edge | FIX (framing) / DEFER (rest) | Combat framing follows the new world rect; distinct enemy layouts and a seamless backdrop go to M1b |
| 19 | 20261015-231813-930fa47 | claude 003 (opus, gate) | Room and crew labels about 8 px | FIX | Room chips 15/14 px, crew tags 13 px |
| 20 | 20261015-231813-930fa47 | claude 003 (opus, gate) | Weapons sit at 0/3 while drilling; nothing to rebalance between fights | REJECT | By design for now (the drill and coolant need the bars); M1b may add quiet-phase reasons to move power |
| 21 | 20261015-231813-930fa47 | claude 003 (opus, gate) | The world outside is dark and sparse; depth does not show | DEFER | M1b/M2: strata variety, landmarks (bones, ruins, wrecks), depth cues |
| 22 | 20261016-213119-eb64f36 | gemini 006 | The rock looks like a scrolling screen saver of wavy sand (also 005) | FIX | D045: fractured blocks with fading cracks instead of wavy beds |
| 23 | 20261016-213119-eb64f36 | gemini 006 | Break-in banner never drew (script error in the capture log) | FIX | StructureBanner.wrap collided with the wrap() utility; renamed wrap_lines |
| 24 | 20261016-213119-eb64f36 | gemini 006 | The UI is a wall of tiny dense text in one colour scheme | DEFER | M2 UI pass: icons for the power job lines and the blast card, larger critical numbers; the job lines stay for now (Stewart asked what helm and bracing do) |
| 25 | 20261016-213119-eb64f36 | gemini 006 | Fire and flooding lack impact (a tint and sparks) | DEFER | M2 art pass: flames that fill the room, water that hides machinery |
| 26 | 20261016-213119-eb64f36 | gemini 006 | Crew are stiff sprites that slide | DEFER | M2: work and panic animations |
| 27 | 20261016-213119-eb64f36 | gemini 006 | Rooms are hard to tell apart without labels | DEFER | M2 art pass: a key colour and silhouette per system |
| 28 | 20261016-213119-eb64f36 | gemini 006 | Fights across an empty void of rock look disconnected | DEFER | M2: closing in, boring toward each other, debris between the towers |
| 29 | 20261016-222207-e1ffb36 | gemini 007 | The giant DRILL HAS NO POWER box blocks the drill head (00:00 to 00:04) | FIX | The notice waits 1.5 s (bots power the drill a moment after a segment starts), sits at the top of the world, smaller; the full-reactor hint only when the reactor is full |
| 30 | 20261016-222207-e1ffb36 | gemini 007 | Dense small text; the store reads like a spreadsheet | DEFER | M2 UI pass (with 24) |
| 31 | 20261016-222207-e1ffb36 | gemini 007 | Rooms visually noisy; crew blend in | DEFER | M2 art pass (with 26, 27) |
| 32 | 20261016-222207-e1ffb36 | gemini 007 | The rock still reads as a repeating tile (world 6, up from 3) | FIX | 1be191c: a second sample of the tile, larger by the golden ratio and turned 90 degrees, blended in by slow noise |
