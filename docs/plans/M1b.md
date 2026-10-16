# M1b: make it a digging game (Stewart's first playtest, D024)

Source: `docs/STEWART_FEEDBACK.md` (2026-10-16). Goal: a run where gathering ore and gems is what you
spend most of your time doing and deciding about, with FTL-style systems, crew, events and occasional
fights around it. Done when Stewart says the loop is fun.

## Round 1: controls that work for a human (spec `specs/m1b_controls.md`, view only)
- [ ] Map holds the world; power in dossiers; paused power feedback; pause and banner at fight start;
      hostile-ahead warning; scanner steering; B changes the bit; H help; death text; flood hint.
- [ ] Real-input test through the viewport; hands-on check by the lead in the exported build.

## Round 2: the digging economy (spec `specs/m1b_dig_sim.md`, sim, data, bots)
- [ ] Segments 60 m (about 45 to 75 s); rock 3 to 4 times denser in reachable deposits.
- [ ] Ore types by depth: coal, iron, copper, silver, gold; gems: quartz, amethyst, emerald. Gas pockets.
- [ ] Survey readings: each map node shows what the rock on the way holds (rich, gems, gas, water);
      "deposit" nodes with rich rock; fights rarer (min 1 per path plus the gate).
- [ ] Ore buys gear (drill heads, hull plating, pumps, system upgrades); gems buy supplies and people.
- [ ] Pursuer, wear and coolant retuned per metre; bots steer for value; 300-run balance check.

## Round 3: see the dig (spec `specs/m1b_dig_view.md`, view, after rounds 1 and 2 merge)
- [ ] Drilling camera zoomed out (rock ahead visible), mouse-wheel zoom.
- [ ] Pickup popups, a dig tally, an arrival summary; ore colours on the scanner and map readings.
- [ ] Store shows ore and gem prices and the new gear.

## Then
New playtest build, Gemini video critic and the blind critic, Stewart plays.

## Later (Stewart, 2026-10-16; plan into M2)
- Break-through openings: now and then the drill breaks into an Agartha-style hollow (a cavern
  world), where something happens (an event, maybe a trading post), then you drill on.
- Each layer below is a dramatically different hollow-earth world (look, rock, light, life, music),
  so breaking into the next layer is a big moment. Fits PLAN's fixed layer order (Crust, Deep Crust,
  Abyssal Sea, Mantle Wilds, Inner World, Foundry).
