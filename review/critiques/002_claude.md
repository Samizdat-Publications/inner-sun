Build: 20261015-211550-4e6f253 | Date: 2026-10-15 | Critic: claude | Model: sonnet

# Player Review

## Gut reaction
The painted cutaway ship is the first thing that has made me stop scrolling in this genre in a while. The rooms are dense, dirty, and each one has its own color: teal coolant room, amber weapons bay, rust-orange drill room. Then I looked at what the ship was actually doing. Across a whole dive I saw almost no fire, and flooding was a 4% blue pinstripe. The crew stood in the same spots for minutes, and the alert bar read "ALL SYSTEMS NOMINAL" in most of the stills. It looks like a poster for a tense game, but in these frames it plays like a screensaver with a nice HUD. The salvage-log and trader cards are well written, and they might carry the game while the simulation catches up.

## Scores (1 to 10, or N/A)
| Category | Score | Why (one line) |
|---|---|---|
| First impression / screenshot-worthiness | 7 | frame_01 and frame_05 are genuinely attractive: warm painted rooms, glowing drill, sparks, a lit rock face. |
| Readability: can I tell what is going on in the ship | 5 | Rooms are distinct by color and name, but the labels are tiny, the crew are small, and nothing is going wrong to read. |
| Lighting and atmosphere | 6 | Good pools of amber and teal light and a dark void. The pink-white blown-out patches on the rock (frame_02, frame_08) look like a bug. |
| Art and materials | 7 | Rich painted metal, pipes, hazard stripes and gauges. The rooms look like places. The rock is repetitive hex-scale texture. |
| Hazards: fire, water and heat read clearly | 3 | I saw zero fire in 20 stills. Flooding is a thin cyan line at the bottom of the hull (frame_03, frame_04). Heat is a 6-pixel "35 C" label. |
| Crew: do they look alive and purposeful | 4 | Three small figures, planted at their stations across sheet_01, sheet_02 and sheet_03. I could not see a walk or work animation. |
| The world outside the hull | 6 | Strata change, there are blue crystal veins, and the drill throws embers. But it is mostly dark rock around a floating box, and combat deletes the world entirely. |
| UI and HUD | 6 | Coherent orange-and-green industrial style with good information. But the type is tiny, the bottom alert bar is a huge empty strip, and the top resource labels are almost unreadable. |
| Sound | N/A | Can't hear audio. |
| Performance | 9 | 147 fps average at 1080p, 1% low 78.8, p99 12.7 ms. No complaints. |
| Would I keep playing | 5 | The dossiers and the shop pull me in. The moment-to-moment loop on screen has nothing pushing back. |

## Top problems (ranked, max 7)
1. [ruins it] Fire does not appear anywhere. The pitch is "fires break out two rooms from the reactor", but across frame_01 through frame_21 and all three sheets I never see a flame, and the alert bar is green nearly the whole time. This is the core fantasy of an FTL/Barotrauma-style game, and it is invisible. I want flames licking up a room, smoke, a room visibly going red, and crew sprinting to it.
2. [ruins it] The ship is a stage set with nothing happening on it. In sheet_01, sheet_02 and sheet_03 (about 3.2 s each), the crew barely shift pixels. They are standing at their consoles, and there is no walking, repairing, or panic. Even during the flood in frame_03 and frame_04, nobody reacts. I need to see people run, carry, patch and die.
3. [hurts] Flooding is a pinstripe. "FLOODING: DRILL ROOM 4%" shows up as a thin wavy line on the floor of the hull (frame_03, frame_04, sheet_01). Water is Barotrauma's whole appeal. I want it to rise, darken the room, tint the lighting, and make me choose which door to seal.
4. [hurts] Combat throws away the setting. In frame_10 through frame_14 and frame_16 through frame_18, the drilled-rock world goes to near-black. The scanner says "NO SIGNAL", and two identical copies of my ship face off across a void. The rival rig is a mirrored duplicate of my own layout, so I read it as a test dummy and not as an enemy. I want the enemy to look different, and I want rock and glow behind both ships.
5. [hurts] The HUD is too small for 1080p. Room names and temperatures (frame_01 "24 C"), the resource labels (ORE, GEMS, COOLANT) and the repair/fire stats are all in microscopic type. The bottom alert bar takes a full-width strip and shows one sentence. Shrink that strip and give the type to the ship.
6. [hurts] Some rock lighting looks wrong. The big pink-white patches beside the hull (frame_02, frame_05, frame_08, frame_21) read as overexposed texture or a leftover light bug. They are bright enough to pull my eye away from the ship, and they make the rock look like wet plaster.
7. [nitpick] The ship is a clean rectangle on top of a tray with a hard dark halo. The drill and its glow are the best-looking part, but the cutaway box above it feels pasted on. A few pipes, cables or scorch marks bleeding between the box and the drill would sell it as one machine.

## Working, don't touch
- The painted room interiors: teal coolant room, amber weapons bay, drill room with warm lamps. Each room has its own color and props (frame_01, frame_05).
- The drill base with its glowing teeth and embers (frame_05, frame_11 and others). It sells the heat.
- The dossier and trader cards (frame_15, frame_16, frame_21). They have strong copy ("The air smells like rain", "ALL SALES FINAL", a man who takes gems and asks nothing), clear choices and good paper-and-stamp styling. The trader screen is very readable, with greyed-out unaffordable items.
- The seismic scanner with heading, target and node distance. It is an actual navigation decision and it looks great in green phosphor (frame_01, frame_06).
- The pursuer bar along the top, which gives the dive a clock.
- Combat target selection with crosshairs, per-weapon timers, "BLOCKED" feedback and room outlines in red and blue (frame_11, frame_12, frame_14).
- Performance.

## Compared to last build
Same, with new content.
- The ship art, HUD and combat layout are essentially unchanged from prev_01 through prev_06.
- New in this build: dossier events (frame_15, frame_16), the trader (frame_21), flooding alerts, bit-wear warnings and fitting-bit status (frame_06, frame_07), and combat room-damage outlines on the enemy (frame_11).
- Combat in prev_04 through prev_06 showed my crew taking damage, dropping to 13 HP, and a crossed-out weapon slot. This build's combat stills (frame_10 through frame_18) show my ship barely touched. That is not necessarily worse, but it is calmer.
- The exploration side now has more going on. The fight-for-your-life side is no more visible than before.

## Steam review one-liner
Gorgeous painted submarine-in-a-mountain that I am not yet scared of: where is the fire?

## What I want next
- Make the hazards the star. I want fire that spreads between rooms, water that visibly rises and darkens a room, and heat that reddens the lighting. Then show the crew running, carrying and reacting to all of it.
- Fix combat so it happens in the world, not in a black void. Give the rival rig its own silhouette and a bit of rock and glow behind both ships.

Files reviewed (all under `C:\Users\stewa\Documents\Claude\Inner Sun\review\inbox\`): `store_page.md`, `perf.json`, `meta.json`, `frames\frame_01.png` through `frame_21.png`, `sheets\sheet_01.png` through `sheet_03.png`, and `previous\prev_01.png` through `prev_06.png`. I did not review `video\clip.mp4` because I can't watch video.
