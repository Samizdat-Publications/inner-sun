# Ship redesign proposal (draft for Stewart, 2026-10-22; nothing built)

His note after build 6: "I kind of almost think the entire ship design needs to be re-thought out into
a more FTL style situation... small with the doors and airlock etc controls, all that. The general
style of the ship should maybe even be changed to something less a giant rectangle."

Pictures (to scale, 1 m grid; drawn by `python pipeline/ship_redesign_sketch.py`): `all.png` side by
side, or `today.png`, `option_a.png`, `option_b.png`, `option_c.png`.

## What changes in every option
- **Smaller rooms, more of them:** 8 to 11 rooms instead of 6 big ones, so a fire or flood is one
  room's problem you can shut in, as in FTL.
- **Doors you control:** every room gets a door. The parity work already adds door and purge clicks
  and closed doors that slow fire (parity rounds 2 and 6a), so doors arrive working.
- **Airlocks (purge):** two outer doors vent a room to the rock: kills a fire, dumps heat or gas, at
  the cost of rock heat and air coming in. The away miner leaves through the dive lock instead of a
  hatch in the hull.
- **Corridors:** crew walk through halls or a spine, so where you station people matters.
- **Two new rooms:** a medbay (heals crew; FTL's medbay) and a dive lock (the miner's exit, an
  airlock). Both are data plus small sim rules.
- **Same six systems** (helm, bracing, reactor, weapons, drill, coolant), the same controls and keys.

## The options
**A. Spine tower (my pick).** A ladder spine down the middle with small pods off both sides; the hull
tapers: narrow bridge on top, widest at the reactor, narrowing again to the drill. It still reads as a
drilling tower (the game's identity), the spine makes crew walking a real choke point, and every pod
has its own door. 9 rooms, 2 airlocks. Footprint 11 x 13 m (today 8 x 9).

**B. Stacked decks.** Three decks of different widths, like an oil rig: a narrow bridge deck, a wide
middle deck with side sponsons (airlocks at the ends), a mid-size bottom deck. Hatches alternate
sides, so walks are longer. The most "industrial" silhouette and the easiest to paint deck by deck.
11 rooms, 2 airlocks, 13 x 11 m (wide and short: less rock on screen beside it).

**C. Compact grid.** The most FTL-like: 2 x 2 m rooms round a corridor ring inside a teardrop hull whose
tip is the drill. The best for fire and door play, but the small rooms shrink the painted art (crew
and machinery at half today's size) and the teardrop reads more like a submarine than a drill.
11 rooms, 2 airlocks, 12 x 12 m.

## Cost (any option)
- Data: a new ship file (rooms, doors, hatches, airlocks), the medbay and dive lock system files.
- Sim: a hull outline instead of a rectangle (the cut footprint and which walls touch the rock), the
  medbay heal, the dive lock as the miner's exit; the parity door and purge rules are reused.
- View: new painted room art at the new sizes (an art pass of about 10 to 15 USD; the Gemini credit
  needs a top-up first), the hull drawn as an outline, corridors and the spine.
- Bots and balance re-run. About three builder rounds plus the art pass: an M2 step, after the parity
  work merges (it brings the doors and purge this depends on).

## What I need from you
Pick A, B or C (or mix: for example A's spine with B's sponson airlocks). Nothing is built until you
pick; the pick becomes a decision and an M2 plan step.
