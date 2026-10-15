Build: e2dc572 | Date: 2026-10-15 | Critic: claude | Model: sonnet

# Player Review

## Gut reaction
This is a debug view, not a game yet. A tiny dark cutaway of six empty rooms sits in the middle of a mostly black 1080p screen. Three peg-people shuffle up ladders while a text log in the corner narrates everything. The fire and the leaking water are the only things that feel designed, and they are pretty good. Nothing here shows me the "hollow Earth, something burns at the center" pitch. I'd wishlist on the premise and not touch it until there is a real HUD and a world.

## Scores (1 to 10, or N/A)
| Category | Score | Why (one line) |
|---|---|---|
| First impression / screenshot-worthiness | 3 | frame_01 is a dark box with a debug printout and a flat yellow triangle; nobody screenshots it. |
| Readability: can I tell what is going on in the ship | 4 | Rooms are labelled, but Bridge, Quarters and Weapons look identical and empty (frame_01). I'm reading the top-left log to know what's happening. |
| Lighting and atmosphere | 4 | It's moody, but it's just dim all over. Only the fire throws any light (frame_02); the reactor glow is a single pixel. |
| Art and materials | 3 | Crew are rectangles with circle heads. Walls are a faint rust-dotted panel texture. The only props are one reactor tank and ladders. |
| Hazards: fire, water and heat read clearly | 6 | Fire is a convincing flame cluster with a red "FIRE 40%" tag (frame_02), and the thin blue leak streams down the ladders (frame_03). Heat is only a number. |
| Crew: do they look alive and purposeful | 3 | They slide in a stiff pose and get clipped by floors mid-ladder (frame_05, sheet_02). They have no work animations. Frames 08-12 show everyone idle. |
| The world outside the hull | 2 | A dark cracked texture and a yellow triangle (the drill?) that changes colour for no stated reason. No strata, no depth, no heat glow, no sense of going down. |
| UI and HUD | 2 | It's a dev console: "bot scripted_fire_drill running", seed, raw metres of water. The footer reads "M0 loop proof". It's orange monospace and tiny, and the ship only fills about a third of the screen. |
| Sound | N/A | Can't hear it. |
| Performance | 8 | About 237 fps average and 1% lows around 140 on a 5070 Ti laptop. The run was flagged contended and untrusted, and the scene is trivially simple. |
| Would I keep playing | 3 | I'm curious about the premise, but there's nothing to do yet. The bots are driving, and I can't see any tools, alerts or choices. |

## Top problems (ranked, max 7)
1. [ruins it] The screen is a debug overlay, not a UI. Top-left is a wall of orange monospace (room table, crew status, event log). Bottom reads "M0 loop proof". I can't tell what I'm allowed to do. I wanted per-room icons for fire, flood and heat, crew portraits with health bars, and an alert strip.
2. [ruins it] The ship is a small box in the middle of a huge black void, with no scale or composition (frame_01). Over 60% of the screen is empty or text. I wanted the cutaway to fill the frame, like FTL or Barotrauma, so every room reads at a glance.
3. [ruins it] The outside world is missing. The pitch is a drill descending toward a burning core, but I see a faint cracked wall and a flat triangle (all frames). I wanted strata scrolling past, glowing magma veins, and the hull lit by heat as you go deeper. The drill head's colour changes (yellow to orange) are never explained.
4. [hurts] Rooms are interchangeable. Bridge, Quarters and Weapons have no furniture, and only the Reactor has a prop. The Drill Room and Coolant rooms are empty (frame_09). I can't tell what a fire in Weapons would destroy, and there's nothing to fight for.
5. [hurts] The crew are placeholder dolls. They are rectangle bodies with circle heads and no limbs, and none of them look like they're doing anything. In frames 08-12 nobody has a job. They also clip through floors and ladders (Okafor half-sliced at the Reactor/Drill floor in frame_05, Lindqvist's head under his name tag in frame_03).
6. [hurts] Overlapping text and weak status feedback. Ladders cross room labels ("COOLANT AND PUMPS", "water 0.01 m" in frame_03). Okafor drops from 100 to 77 HP and I only see it in the text list, with no on-body feedback. The water is a thin 1-pixel line that doesn't match "0.25 m" (frame_08), so a flooded room reads as dry.
7. [nitpick] Lighting is uniformly dark and the palette is brown on brown. The fire flickers nicely, but nothing else is lit. A reactor that glows, flickering emergency lights and a red cast during a breach would sell the dread.

## Working, don't touch
- The fire effect (frame_02, sheet_01) has a hot white core, layered embers and a tag in red type. It is the one thing that looks like a finished asset. Keep it.
- The water leak streaming down the ladder shaft, plus the breach label, is a clear cause-and-effect read (frame_03).
- Room names are large and legible, and the ladder network gives a clear vertical structure like FTL's.
- The hazard chain works. The fire starts in the drill room, a breach opens in weapons, and crew are dispatched to each. It's a good sign for the systems underneath.
- Frame rate is solid with headroom for a lot more visual work.

## Compared to last build
Basically the same. prev_01, prev_03 and prev_05 (seed 1234) match frame_01 and frame_05 (seed 324137). That includes the layout, the crew rectangles and the yellow and orange triangle, plus the header now reading "M1 STARTER DRAFT". I see no visible improvement in art, HUD or outside world, and the scene is as dark and as empty as before. If there was work, it isn't on screen.

## Steam review one-liner
Not recommended yet: a promising "FTL in a hollow Earth" pitch, but right now it's three coloured pegs and a console log in a dark box, so wait for the actual game.

## What I want next
1. A real HUD and ship composition. The cutaway should be scaled up to fill the screen, with in-world icons, crew portraits and clickable controls in place of the log.
2. A world outside the hull. Show the drill pushing through glowing strata, with the heat and depth you can see change the lighting inside the ship.

Files reviewed are all in `C:\Users\stewa\Documents\Claude\Inner Sun\review\inbox\`. I did not open `video\clip.mp4` or `previous\prev_02`, `prev_04` and `prev_06`. The comparison above uses `prev_01`, `prev_03` and `prev_05`.
