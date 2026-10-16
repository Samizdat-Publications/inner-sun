# Spec: M1b round 3, see the dig (view)

For a `builder` in its own worktree, after rounds 1 (controls) and 2 (dig economy) are merged. Read
CLAUDE.md, HANDOFF.md gotchas (15 lights per canvas item, glow and unshaded boosts, light heights),
docs/plans/M1b.md, docs/DECISIONS.md D024 onward, the round 2 report section in
docs/plans/M1b.md (data ids and event shapes), then game/view/main.gd, rock_view.gd, ship_view.gd,
hud/*.gd, overlay/map_view.gd, overlay/store_view.gd. Godot API dump (git-ignored): the main repo's
`harness\out\godot-api\doc\classes\`.

## Why
Stewart chose "Digging is the game" (D024). Today the drilling camera is filled by the ship's
cutaway, so the rock you are steering for is mostly off screen; the scanner is the only view of it.
Pickups are silent numbers in the top bar. The map does not say what the rock holds.

## Owned files
game/view/** (not boot.gd's parking logic), game/assets/audio only for a pickup sound if one exists
already, tests under game/tests for view helpers, README "How to play". Nothing in game/sim, bots, data.

## What to build
1. **Drilling camera.** Zoom out while drilling so roughly 20 m wide by 15 m tall of rock is visible
   around the tower, with more rock below than above (the crown in the upper third). Mouse wheel over
   the world area zooms between about 0.45 and 1.15 (remember the choice for the run). Keep the
   cutaway zoom when not drilling and the combat framing in fights. Make sure the ship interior stays
   readable at the default zoom (crew, fire, water); if not, pick the default closest to 20 m that is.
2. **Pickups you feel.** Floating "+2 IRON" / "+5 EMERALD" text at the crown from `mined` events,
   coloured by material, stacking and fading, larger for gold and gems; a short pickup sound if the
   audio director has a fitting one (no paid generation in this spec).
3. **Dig tally.** A small panel line while drilling: "THIS DIG  coal 4  iron 7  silver 1  = +29 ore
   +3 gems". On arrival, a short summary toast from `segment_done`.
4. **Ore colours on the scanner** (from the material colour hints in data), gas pockets and water
   pockets clearly distinct, with a tiny legend.
5. **Survey readings on the map.** Each surveyed node shows its richness (for example 1 to 3 pips) and
   small icons for ore tiers, gems, gas and water; the `deposit` node type has its own icon; nodes
   beyond scanner range stay "?". A hover tooltip says it in words.
6. **Store shows currencies and gear.** Each line shows its price with an ore or gem icon; gear lines
   (drill heads, plating, pumps) say what they do in one line; greyed lines say why.

7. **The rock must feel like rock (Gemini baseline critique 004, world 3/10: "an elevator riding past
   scrolling wallpaper").** Visible strata bands, hardness reading in the texture, ore and gems that
   glint, sparks, dust and debris at the crown while cutting, cut shaft walls rougher than solid rock.
8. **Water reads as water (004, "a bright blue placeholder box").** Murky groundwater colour, a surface
   line that sloshes with the tower's motion, darker with depth, foam where a breach pours in.
9. **Crew readability (004).** Crew pop out of the room art: rim light or outline, a brighter uniform
   accent, a selected-crew ring.
10. **Bug from the lead's hands-on test:** with the charge launcher aimed at the enemy weapons room,
    F1 then a click on that same room did not aim the borer turret (a click on the bridge did). Find
    and fix (both weapons may target the same room).

## Proof
- `python tools/check.py` prints `check: ok`; `python tools/determinism.py` matches.
- One batched windowed shot run (`python tools/shots.py --mode run --bot balanced ...`) showing:
  drilling with pickups, the tally, the map with surveys, the store. Look at the stills; report paths.
- At most 2 windowed runs in total.

## Limits
Strict typing, files under about 400 lines, no em dashes, commit `.uid` and `.import` files, explicit
`git add` paths, commit on your branch, do not merge or push.

## Report (under 300 words)
What changed per item, still paths, check and determinism lines, open problems, branch name.
