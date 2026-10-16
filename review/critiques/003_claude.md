Build: 20261015-231813-930fa47 | Date: 2026-10-15 | Critic: claude | Model: opus

# Player Review

## Gut reaction
The ship cutaway is gorgeous up close: grimy pipes, hazard stripes, a teal coolant room against warm amber lamps. Then I zoom out to the actual screen and it shrinks to a postage-stamp box floating in a dark brown void, with a UI frame hogging the rest. The systems read like proper FTL-meets-Barotrauma, with power bars, crew assignments, flooding, a rival rig and a trader. But nothing in this capture is on fire, and the crew stand at their consoles like mannequins. I'd wishlist it for the vibe and the writing, but I don't yet feel the ship is alive or the dive is dangerous.

## Scores (1 to 10, or N/A)
| Category | Score | Why (one line) |
|---|---|---|
| First impression / screenshot-worthiness | 6 | The room art would make a good crop (frame_01), but the full screen is a small box in a dark void, so the full screenshot doesn't sell it. |
| Readability: can I tell what is going on in the ship | 6 | Rooms are distinct by palette, but labels and temperatures are about 8px and the nameplates are tiny. I had to read the right-hand roster to know who was where. |
| Lighting and atmosphere | 6 | The warm drill glow and sparks are good (frame_16). Everything outside the hull is murky brown-black, and the ship sits in a hard-edged dark rectangle halo (frame_01, frame_13). |
| Art and materials | 7 | The room kits are dense, with stencil text, valves and gauges. Rock is a flat cobble texture, and the hostile rig is the same ship tinted blue. |
| Hazards: fire, water and heat read clearly | 5 | Flooding is great: blue water, surf line, breach spray (sheet_02, frame_09). I saw zero fire. Heat is only a tiny "36 C" next to a room name, with no visual shift. |
| Crew: do they look alive and purposeful | 5 | They are well-drawn silhouettes, but at their stations in sheet_01/sheet_03 they barely change pose. They are very small, and there are only three of them. |
| The world outside the hull | 5 | The terrain is dark and sparse, with a few glinting ore veins (frame_01, frame_08). In combat (frame_05, frame_12) a tiled cobble backdrop sits in a visible rectangle with a hard edge. |
| UI and HUD | 7 | Cohesive industrial-terminal look, and the seismic survey map (frame_20) and dossier cards are excellent. Text is larger than before. The power panel and the alert strip still eat a lot of screen. |
| Sound | N/A | I can't hear audio. |
| Performance | 8 | 112 avg fps at 1080p with the machine contended, and a 58 fps 1% low. No complaints. |
| Would I keep playing | 6 | The loop is promising: pursuit front, trade-offs at the shop, branching map. It still needs hazard variety and crew behavior before I feel pressure. |

## Top problems (ranked, max 7)
1. [hurts] The ship is tiny on screen and surrounded by dead space. In frames 01-03 and 14-16 it fills about 30% of the width, with huge empty dark margins left and right. The room art is the best thing here, and I have to squint at it. I want the cutaway much larger, with the HUD hugging the edges.
2. [hurts] No fire anywhere. The store page promises "fires break out two rooms from the reactor" and the roster shows "FIRE 1.0" stats. Across 22 frames and 3 sheets I saw flooding but never a flame, and heat is only a small number. Hot rooms should glow, shimmer and look dangerous (frame_13: 37 C looks identical to 22 C).
3. [hurts] Crew read as static. In sheet_01 and sheet_03 they stand in place at consoles. In frame_09 two crew are in the flooded room, but I can't tell if they are swimming, panicking or fixing. I want visible reactions: hurrying, hauling, flinching at hits, waist-deep wading.
4. [hurts] Combat framing is awkward. The player ship is clipped by the left HUD panel (frame_05, frame_12), so the bottom of the rig is hidden behind UI. The rival is the same layout recolored blue, so it doesn't feel like a different enemy. The cobble backdrop is a repeating tile with a hard-edged dark patch (frame_12, x~1140).
5. [hurts] Information is too small and too samey. Room name and temperature, crew nameplates and the hostile room labels are all about 8px in a 1080p capture. Meanwhile giant labels like "ALL SYSTEMS NOMINAL" and the REACTOR block take up space. Scale the important numbers (heat, flooding %, who is where) onto the ship, not the sidebar.
6. [nitpick] The weapons room is always empty at "0/3" while drilling, and the helm, bracing and drill bars are static (frames 01-16). I never see a reason to rebalance power during the quiet phase, so the ship feels solved until combat.
7. [nitpick] The world outside the hull is dark, brown and sparse compared with the older build. The ore veins and the blue-grey rock with highlights are gone. I want strata, glowing ore, bones, ruins or pockets of magma that tell me the depth is changing (28 m looks like 140 m).

## Working, don't touch
- The cutaway room art and its per-room palettes: amber weapons, teal coolant, mechanical reactor. Rooms are identifiable at a glance (frame_01).
- Flooding: the waterline, the surf and the blue wash read instantly, in both my ship and the rival's (frame_09, frame_13, sheet_02).
- The seismic survey map (frame_20): clean, readable, with legend and pursuit front.
- The dossier and trader cards (frame_17, frame_21, frame_22): parchment, stamps, voice and good copy ("a man who takes gems and asks nothing"). Gated options show their requirement.
- The pursuit bar along the top, the drill glow, and the sparks under the hull.
- The weapon and target UI in combat: clear charge timers, target lock reticles, and a "FLEE / NOT ALLOWED / NEEDS 2 DRILL BARS" explanation.

## Compared to last build
Mixed, leaning slightly better.
- Better: HUD type is larger and the alert strip is slimmer (prev_01 versus frame_01), so the screen is more readable. Combat now has a rock backdrop where prev_04/prev_05 had a black void. Flooding on the rival rig is clearer (frame_13 versus prev_05).
- Worse: the outside world is much darker and flatter. prev_02/prev_03 had bright blue-grey rock with highlights and lit walls. Now it's a dim brown gloom (frame_08, frame_16).
- Same: the ship is still small, crew are still static, and there is still no fire.

## Steam review one-liner
Gorgeous ship interior and a great dossier voice, trapped in a tiny box in the dark. Show me fire, make the crew sweat, and I'm in.

## What I want next
1. Blow the ship up on screen and make heat and fire visible. Rooms should glow orange, warp and smoke at depth, and crew should visibly react to fire, water and incoming fire.
2. Make the outside world change with depth. Give the strata, ore and hazards different colors and shapes, so each dive feels like going somewhere new, not drilling the same brown tile.
