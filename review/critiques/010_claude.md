Build: 20261022-202935-298989b | Date: 2026-10-22 | Critic: claude | Model: sonnet

# Player Review

## Gut reaction
The painted ship cutaway is gorgeous. Each room has its own palette and clutter, and the drill's glowing teeth are a good hero shot (frame_01, frame_12). But the rock around it is a murky dark void, and the miner who walks out into it is a flat, low-res sprite that looks pasted in from another game (frame_08, frame_10). I saw no fire in any capture, and flooding showed up as a thin blue line plus an alert-bar entry. That's my biggest worry, since the pitch is about hazards. Right now it's a very nice-looking mining dashboard with a lot of screen taken up by orange HUD. I'd play more to see if the crisis side shows up. I haven't seen it yet.

## Scores (1 to 10, or N/A)
| Category | Score | Why (one line) |
|---|---|---|
| First impression / screenshot-worthiness | 6 | The ship and drill are striking, but the ship is a small box in a dark void and HUD panels eat most of the frame (frame_01). |
| Readability: can I tell what is going on in the ship | 6 | Rooms have clear labels and distinct colours. As heat rises, everything turns red-brown and reactor, weapons and drill room blur together (frame_07, frame_12). |
| Lighting and atmosphere | 6 | The hot drill glow and sparks are good. The bright beige light patches on the rock walls look like static spotlights, and the ship has a black halo around it (frame_01, frame_03). |
| Art and materials | 7 | The painted rooms are rich and consistent, with rivets, pipes and hazard stripes. The rock is nicely textured. The sprite-style miner and the blocky orange mine-works tiles clash with all of it. |
| Hazards: fire, water and heat read clearly | 4 | Heat is only a room tint and a temperature number. Flooding is a hairline of blue at the bottom of the drill room (frame_16) plus a text alert (frame_18). I saw no fire anywhere, and "HAZARD AHEAD" sat in the alert bar for minutes without telling me what it meant. |
| Crew: do they look alive and purposeful | 5 | The painted crew are good-looking and in sheet_03 they walk and climb. In sheet_01 they mostly stand at consoles, and Vasquez is at the helm in nearly every frame. The outside miner is a flat sprite. |
| The world outside the hull | 5 | The rock texture is good, and the sparkling ore veins and old mine works give it some life. It's mostly a dark vignette, and there are odd red blobs and red cell pillars that look like debug fills (frame_01, frame_16). |
| UI and HUD | 7 | The orange-on-black look is consistent, with a clear bar at the top and a good seismic scanner. The survey map (frame_20), the trader and the dossier are all well designed. The side panels are dense and use small text. |
| Sound | N/A | I can't hear anything from stills. |
| Performance | N/A | There was no perf.json, and I can't judge frame rate from stills. |
| Would I keep playing | 6 | The loop is readable: dig, send a miner, buy upgrades, pick a route. But I haven't seen anything go wrong yet, so I don't know if the tension is there. |

## Top problems (ranked, max 7)
1. [hurts] The miner outside is a flat, pixel-style sprite with a stick for a pickaxe and a black blob shadow (frame_08, frame_10, frame_16). It looks nothing like the painted crew inside. It's the one thing you actively control outside the ship, so it has to feel like part of this world.
2. [hurts] I never saw fire, and I barely saw water. The only flood evidence is a 0.1 m line in the drill room and an alert-bar entry (frame_16, frame_18). I wanted flames licking the room, water visibly rising against a bulkhead, and a room that looks like it is in trouble at a glance.
3. [hurts] The alert bar is vague. "HAZARD AHEAD" and "ALERTS 1" sit there permanently in frame_01 through frame_08. If a warning never says what or where, I'll learn to ignore it.
4. [hurts] The ship is a small box in a big dark field. The side panels and the bottom bar take up about two thirds of the screen. The painted art deserves more space, or a cleaner frame (frame_01).
5. [hurts] The space outside the hull looks unfinished. It has a black halo around the ship and hard-edged bright patches on the right wall (frame_01, frame_03). There's a big blurry red shape on the left (frame_01, frame_02) and stacks of glowing red squares at 6 m (frame_16, frame_17). The orange old-mine tiles look like stamped placeholder blocks (frame_05, frame_14).
6. [nitpick] When the ship heats up, every room goes red-brown (frame_07 onward) and the reactor, weapons and drill rooms lose their identity. The coolant room stays teal and still reads fine. I'd like heat to read as a glow or shimmer on top of each room's own colour.
7. [nitpick] The trader and dossier overlays are good parchment art, but the text is dim and long, and the greyed-out buy buttons are hard to read (frame_18). The "NO SIGNAL" scanner behind the dossier is a nice touch, though.

## Working, don't touch
- The painted room interiors. Each has its own colour and props, with readable labels and temperatures (frame_01).
- The drill rig underneath, with its glowing red teeth, sparks and falling rubble (frame_01, sheet_01).
- The seismic scanner and the survey map with its symbol legend (frame_20).
- The parchment-and-stamp style of the dossier and trader screens, and the writing in them ("Auger, those tags are not your concern. Count them anyway.").
- The consistent orange HUD language, and the crew cards showing fire and repair stats.
- The ore-pickup floaters ("+17 ore") and the white sparkle on ore veins.

## Compared to last build
Same, as far as I can tell. The previous stills (prev_01, prev_04, prev_06) show the same HUD, the same painted rooms and the same flat miner sprite. The red cell pillars and red blobs outside the hull are also still there. The new build adds screens I could check: the survey map, the trader, the dossier and "OLD MINE WORKS" scanner tags. The miner and the world outside didn't visibly improve, which is where the work is still needed.

## Steam review one-liner
The ship cutaway looks like a painting, but there's a clip-art miner in the dark outside and I never saw a single fire.

## What I want next
1. A hazard that shows. I want a room on fire, or filling with water, that I can read from across the screen. Then I'll feel the FTL-style crisis the pitch promises.
2. Make the outside match the inside. That means a miner painted in the same style as the crew, and a rock face with real lighting instead of a black halo, hard-edged light blobs and debug-looking red squares.
