# Spec: M1c round C, things in the rock (buried structures)

Part 1 (sim, data, bots, tests) is for a `builder-opus` in its own worktree, after round B part 1
has merged. Part 2 (text) is for a `writer`, part 3 (the view) for a `builder`; both start after
part 1 merges and read its report.

Read first: CLAUDE.md, HANDOFF.md gotchas, docs/ARCHITECTURE.md, docs/DECISIONS.md D024 onward,
docs/plans/M1c.md, docs/plans/specs/m1c_dig_verbs.md (round B: fault rock, strain, blast, the
burst flood-and-mark), then game/sim/drill/*, game/sim/run/survey.gd, map_gen.gd, run_state.gd,
game/sim/events/encounter.gd and event_effects.gd, game/bots/*, game/data/rock, layers, events,
stores, codex. Godot API dump (git-ignored): read it from the main repo,
`C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`.

## Why (Stewart, build 3)
"I would like the various levels to have almost terraria style underground cities ... we have to
think up some way to make the map and mining more interesting." Earlier: "a hallmark of the world
... is that you occasionally drill into an agartha style opening where some event happens (shop
maybe?)". Structures give the dig places to aim for, each with its own risk and reward, and give the
map a reason to pick one path over another. Agartha-style hollows and towns grow from this in M2.

## Part 1: sim, data, bots, tests (builder-opus)

### Structures are data: stamps
- New table `game/data/structures/<id>.json`:
  `{"id", "name", "label" (map and banner text, e.g. "OLD MINE WORKS"), "codex": codex id
  discovered on break-in, "legend": {char: material id}, "stamp": [strings, one per cell row, 0.5 m
  cells], "mirror": bool (may be flipped left to right), "loot": [{"weight", "res", "amount"}] (one
  roll per crate), "event_chance": 0..1, "trader": store id or "", "trader_chance": 0..1}`.
  A lint checks every char is in the legend, every material id exists in the rock table, rows have
  equal length, loot resources exist, ids resolve, and rejects em dashes in text.
- The rock table gains a `structures` list: `[{"structure": id, "weight", "from_depth_m",
  "to_depth_m"}]`. The survey (Survey.roll) rolls at most one structure per segment from the layer's
  `structure_chance` (start 0.3, `per_row` +0.02, higher for deposit nodes, say 0.5) and the depth
  windows; the reading gains `"structure": id` ("" for none). Add the draw so readings stay a pure
  function of the seed.
- RockGen places the stamp (mirrored by the segment stream when allowed) with its centre at a depth
  fraction 0.25 to 0.75 and offset 3 to 9 m to either side of the corridor line, clamped so the stamp
  sits inside the grid and at least one cell clear of the start shaft. The stamp overwrites the
  rock (a legend char " " leaves the rock as it was). DrillSim keeps the placed structure's id and
  rectangles (the stamp rect and its interior: the cells marked with an interior char) for the view
  and for break-in.

### New materials (crust rock table; flags loaded by DrillMaterials like water, gas, unstable)
- `timber` (mine props; hardness 0.6, `unstable`), `steel` (Soviet hull plate; hardness 6.0, so
  drilling it is slow, loud and wears the bit; a blast is the clean way in), `crate` (hardness 0.4,
  new flag `loot`), `rubble` (a loose fill; hardness 0.5, `unstable`), `relic_air` (air inside a
  structure: hardness 0, cut like air, marks the interior). Give each a colour in data.
- Crates: the first cut cell of a crate (by the footprint or a blast) opens the whole connected
  crate (the round B flood-and-mark) and pays ONE roll of the structure's loot table from the stream
  `"drill/<segment>/loot"`, through `run.add`, event `"loot" {"structure", "res", "amount", "x_m",
  "y_m"}`. Exact integers, conservation tests.

### Break-in
- The first time the footprint overlaps a structure's interior (or a blast opens an interior cell),
  emit `"structure_entered" {"structure": id, "label"}` once, discover its codex entry through the
  run's usual discovery path, and then, rolled from `"drill/<segment>/structure"`:
  - with `trader_chance` and a `trader` store: open that store mid-segment;
  - else with `event_chance`: start an event drawn from events with `"kind": "structure"` whose
    `"structures"` list holds this id (once per run each, like the other events);
  - else nothing more (the loot and the codex are the reward).
- Mid-segment store and events: the drill stays active; the run goes to "store" or "dialog" and,
  when the store is left or the event ends, back to "drill" (not "idle"), with the segment exactly
  where it was. Events whose outcomes would end the run, start a fight or move the ship keep
  working (a fight mid-segment may simply be ruled out for structure events by the lint if it is
  hard; say so).

### First three structures (the writer polishes the text; write placeholders with ids)
- `mine_works` (0 to 420 m): a timber-propped gallery about 12 to 16 m long and 2 m tall, rails,
  2 or 3 crates, fault rock and rubble above it (rockfalls when you cut along it). Loot: bits,
  charges, coolant, ore. Codex: a new entry `old_workings`. event_chance 0.4.
- `soviet_rig` (180 m to the gate): a steel-plated drill module about 8 by 5 m, an interior with
  crates of cells and coolant and a sealed tape (a crate whose loot is a codex entry or a big cell
  payout; pick one shape and lint it). Codex: `zarya_rig` exists; reuse it or add `rig_module`.
  event_chance 0.6.
- `crystal_hollow` (300 m to the gate): an oval cavern about 7 by 4 m, the interior lined with quartz
  and amethyst (and emerald below 450 m) on its walls, a pool of water at the bottom. trader
  `hollow_trader` (a new small store: coolant, bits, charges, a hire, priced a little high) with
  chance 0.35, else event_chance 0.5. Codex: a new entry `the_hollows`. This is the first taste of
  the Agartha openings.

### Bots
- The drill bot values a structure's crates and interior on its lanes (they are worth detouring
  for); greedy and balanced aim for them, cautious only when on its way. Policy node choice weighs
  a survey's structure like a richness bonus. Structure events use the existing choice policies.

### Proof
- Tests: stamp parsing and the lint (bad char, ragged rows, unknown material); placement is
  deterministic and inside the grid, mirrored by seed; a crate pays exactly one roll once (resources
  delta == the roll); break-in fires once and discovers the codex; a mid-segment store and a
  mid-segment event both return to "drill" with the ship where it was; survey determinism.
- A 300-runs-per-bot balance check: report per policy how many structures were entered, crates
  opened, traders met, and the effect on wins and run length (aim: wins stay in the 10 to 30% band).
  Report to `docs/research/m1-evidence/balance_m1c_structures.md`.
- `python tools/check.py` prints `check: ok`; `python tools/determinism.py` matches.

### Limits and report
As in round B: headless only, at most 6 balance processes, strict typing, files under about 400
lines, no em dashes, stream randomness only, exact integers, explicit `git add`, commit on your
branch, no merge or push. Log choices as D041 onward. Report (under 400 words): what changed; data
shapes; the events and read-only fields the view needs (structure rects, ids, loot and break-in
events); the event schema for writers ("kind": "structure", "structures"); balance headline; check
and determinism; open problems; branch name.

## Part 2: text (writer)
In the voice of docs/STYLE_GUIDE.md: structure names and blurbs, the codex entries
(`old_workings`, `the_hollows`, and the rig one), the hollow trader's store blurb and item lines,
three to five structure events (one or two per structure, two or three options each, with real
risk: a cage, a sealed hatch, something knocking), and two or three TOPSIDE radio lines for
break-ins. Real history only as discoverable lore.

## Part 3: the view (builder)
Owned: game/view/**. Draw the new materials (timber props and rails, riveted steel plates, wooden
crates with stencils, rubble, the dark interior with a faint glow; crystals glinting in the hollow);
a crate opening pop with the loot text; on break-in a banner with the label, a TOPSIDE line if one
exists, a light change; the scanner draws a structure's outline and a small label once it is in
range; the map's survey marks show the structure label; the mid-segment store and dossier open over
the drilling view and the dig resumes after. Story moments for shots and captures ("structure").
