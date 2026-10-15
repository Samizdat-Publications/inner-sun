# Inner Sun: the plan

Approved by Stewart on 2026-10-15 (planning session). This file expands that plan with what
Milestone 0 measured. Change it freely when a better path appears; log why in `docs/DECISIONS.md`.
Stewart's original kickoff is preserved in `docs/STEWART_FEEDBACK.md`.

## 1. The game

Near future. A black-budget expedition follows a trail of anomalies (Byrd's 1947 polar flight
claims, the abandoned Kola Superdeep Borehole, unexplained seismic signals) and finds the hollow
Earth legends are true. You command a drill ship and its crew, boring down layer after layer:
fossil caves and old mine works, crystal caverns, an underground sea, fungal forests, the cities of
Agartha, an inner sun, and at the bottom the Foundry where the UAPs are built, launching through
vents in the ocean floor. Tone: pulp. Journey to the Center of the Earth meets The X-Files.

**Fixed by Stewart:** FTL-style systems and real-time combat with pause; 2D side-view cutaway with
atmospheric lighting; roguelite runs with a fixed layer order and procedural contents; story told
across runs through a persistent codex; Godot 4 native Windows; real history as lore, not setting.
**Chosen by Stewart in planning:** the ship is a **tall tower** (decks stacked, drill at the bottom,
boring straight down).

## 2. Core loop (M1 tests all of this; pivot where the fun is not)

- **Ship:** a tall drill tower in side cutaway. The starter (`light_drill`, drafted in M0) has six
  rooms on three decks: bridge and quarters on top, reactor and weapons in the middle, drill room and
  coolant/pumps at the bottom, joined by doors, ladders and hatches, plus an airlock (M1). Because it
  stands upright, water pools in the bottom deck (where the drill is) while heat and gas rise to the
  top: hazards stack by deck. Caverns open below the drill; fights come from the sides.
- **Power:** the reactor's limited bars split across systems, as in FTL; damage removes capacity.
- **Heat replaces oxygen:** deeper rock is hotter; heat leaks in through the hull and breaches and
  comes off systems, the drill and fires; it spreads between rooms (strongly upward through hatches);
  coolant removes it. Crew suffer above one threshold; above higher ones systems fail and fires start.
- **Hazards:** heat, fire and water breaches in M1; gas, magma and cave-ins later.
- **Crew:** three in M1, skills per station, permadeath within a run, recruited from events. They go
  where ordered and handle emergencies on their own when idle (jobs scored by urgency, skill and
  travel time).
- **Drilling between nodes:** 20 to 45 seconds of hands-on travel in the side view, pausable: steer
  the drill angle, set drill power (speed against heat and noise), detour for ore veins and gem
  pockets, manage heat and bit wear, dodge water pockets, hard rock and falling debris, while the
  interior keeps running.
- **Node map:** vertical, Slay the Spire-style, reading top to bottom like the descent; about eight
  stops to the layer gate, 2 or 3 branches per row; event, cavern salvage, store, fight, hazard and
  gate nodes; the seismic scanner reveals node types and hidden ore further ahead.
- **The pursuer:** drilling makes noise (longer, greedier, hotter drilling and mining charges make
  more); noise moves a shadow down the map and nodes it overtakes turn deadly.
- **Combat:** real time with pause. M1: one enemy, a rival drill crew whose ship is built from the
  same data as yours and run by an AI. Weapons: borer turret (projectile), thermal lance (beam),
  mining charges (limited ammo that ignores bracing); bracing absorbs hits and recharges. Sonic
  emitters (system disruption) arrive in M2.
- **Events:** dossier style, typewritten, with redacted words that lift across runs as the codex
  learns them. TOPSIDE, the handler, talks on the radio (voiced from M2).
- **Codex and meta:** discoveries persist; the death screen shows what you learned; unlockable ships
  and layout variants come from M2 on.
- **Resources:** ore (hull and repairs), gems (currency and upgrades), coolant, power cells (fuel per
  drilling segment), drill bits; exotic materials in later layers.

## 3. Architecture (built in M0, see `docs/research/godot-loop.md`)

| Piece | Where | Rule |
|---|---|---|
| Simulation | `game/sim/` | Plain RefCounted classes, fixed 60 Hz tick, no Nodes, no clock. Hazards at 10 Hz, crew decisions at 4 Hz. |
| Commands | `Sim.push`, `Sim.command_log`, `Sim.replay` | Player input, bots and scenario timelines all go through it. |
| Determinism | `RngStreams`, `StateHash` | Seeded named streams; hash proven equal headless, under Movie Maker and in the exported build. |
| Conservation | `HazardSim` | Water in mL and heat in J as integers; equality tests. |
| Content | `game/data/**/*.json`, `DataDB.lint()` | Every reference checked; em dashes rejected. |
| View | `game/view/` | Reads the sim; small per-room nodes (Godot caps about 15 lights per canvas item). |
| Bots | `game/bots/` | Same command chain as the player. |
| Tests | `game/tests/` | Custom runner; any engine error fails the test that caused it. |
| Tools | `tools/*.py` | Every Godot launch in a job object; check, shots, capture, perf, balance, determinism, export, snapshot, coexist. |

**Language decision with numbers (M0):** the M1-shaped benchmark (6-room tower, 3 crew, hazards, a
drilled rock grid and 24 projectiles) runs about 28,500 ticks per second in one GDScript process;
the budget is 6,000 (1,000 full M1 runs in under 15 minutes on 6 processes). GDScript stays. Re-run
`python tools/balance.py --bench` after the real terrain and combat land; below 6,000, move that
hot spot to Rust through gdext (Cut & Fill proved that toolchain on this PC).

## 4. Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | Prove the loop | Done 2026-10-15. Evidence in `docs/research/godot-loop.md`. |
| M1a | Find the fun: autonomous slice | Stewart can play start to death to codex in an exported build; bots run 1,000+ runs with a report; systems tests pass; a blind critic loop has run; 60 fps on the 5070 Ti. **Then stop for Stewart's playtest.** |
| M1b | Find the fun: iterate | Iterate on Stewart's playtest notes until he says the core loop is fun. |
| M2 | The Crust, complete | Art pass in the chosen style; burrowers that latch onto the hull and Soviet automata; away teams through the airlock; gas; sonic emitters; about 30 events; 2 store types; a layer-gate boss; codex and meta v1 with the heavy borer unlock and layout variants; mid-run save; settings; audio pass; voiced radio. |
| M3 | The Deep Crust | Magma breaches (fire and flood together), crystal caverns, extreme heat, the thermal lance ship. |
| M4 | The Abyssal Sea | The submarine, a design for how drill ships cross the sea, pressure and flooding. |
| M5 | The Mantle Wilds | Fungal forests, fauna that board, first Agarthan contact, Agarthan guides as crew. |
| M6 | The Inner World | The inner sun (the first time the dark lifts), cities, factions, the Agarthan vessel. |
| M7 | The Foundry | The UAP facility, drones, the finale, the captured craft as the secret ship, endings. |
| M8 | Ship it | Full-run balance by simulation for every ship, difficulty levels, accessibility, performance, installer and README. |

The story spine, codex and TOPSIDE's radio grow in every layer milestone. A scripted campaign stays
possible but is not built.

## 5. M1 build order (biggest fun risk first; checklist in `docs/plans/M1.md`)

1. Step 0: install the blind critic (`HANDOFF.md`).
2. Drilling segment in greybox with the ship interior running (the biggest fun risk).
3. Power and systems on the six-room tower; the art style bake-off in parallel.
4. A thin full run: node map, travel by drilling, pursuer, death, codex, meta save.
5. Combat with one weapon, then the other two; pause and targeting.
6. A few events, one store, the dossier UI with redactions, TOPSIDE text, crew recruitment.
7. Placeholder audio: drill roar by rock hardness, alarms.
8. Bots for every node type, balance at scale, report.
9. Exported playtest build that saves seed, command log and a summary per run (Stewart's runs become
   bug reproductions); critic loop; qa-auditor; stop for the playtest.

## 6. Content roadmap (fixed layer order, procedural contents)

| Layer | New hazards | Enemies | Special nodes and loot | Lore threads | Unlock |
|---|---|---|---|---|---|
| 1 Crust | Fire, water breach, cave-ins, gas | Rival drill crews, burrowers, Soviet automata | Old mine works, fossil caves, wrecked Soviet rigs; iron, quartz, coolant caches | Byrd 1947, Kola "well to hell" tapes, Project Mohole | Heavy borer |
| 2 Deep Crust | Magma breach, extreme heat, crystal resonance | Magma worms, crystal guardians, thermal-lance crews | Giant crystal caverns, lava tubes; gold, cobalt, giant gems | A lost 1970s expedition, the first impossible signals | Thermal lance ship |
| 3 Abyssal Sea | Pressure, flooding, currents | Sea creatures, ghost subs | Islands, wrecks of earlier expeditions | Byrd's "land beyond the pole" | Submarine |
| 4 Mantle Wilds | Spores (crew effects), growth on the hull | Fauna that board, fungal hives, Agarthan scouts | Agarthan waystations; luminous resin, Agarthan crystal | First contact, who the Agarthans are | (Agarthan guides) |
| 5 Inner World | Inner-sun heat and glare, politics | Faction fleets, guardians | Cities, faction quests; foundry alloy, exotics | Who built the Foundry | Agarthan vessel |
| 6 Foundry | Fabrication hazards, energy weapons | Tic Tac drones, foundry security, the final boss | Assembly halls, the sea-floor vents | Why nobody ever catches the UAPs | Captured craft (secret) |

## 7. Art and sound

- **Art: one consistent style, chosen by a bake-off early in M1.** The same room and crew member
  made three ways, all normal-mapped and lit in Godot: pixel art (PixelLab), painted pulp
  illustration (Gemini or OpenAI), and Blender pre-rendered sprites with real normal passes. Lean:
  crisp high-resolution pixel art. The dossier and codex get document styling (typewriter text,
  stamps, redaction bars) on top of the same style. Stewart sees the bake-off before the pipeline
  scales up. Write `docs/STYLE_GUIDE.md` from the winner.
- **Lighting:** dark by default (CanvasModulate), warm ceiling lamps, red alarm lights, fire glow,
  the drill face, hull floodlights on the rock. HDR 2D glow is configured but its bloom was not yet
  visible in M0 captures: verify in the bake-off.
- **Sound:** drill roar that changes with rock hardness, hull groans under pressure, alarms, distant
  things moving in the rock, TOPSIDE's voice (ElevenLabs) through a radio filter.

## 8. Budgets and targets

- Performance: 60 fps floor on the RTX 5070 Ti at 1080p and 1440p; judge p99 frame time (Windows
  caps windowed fps at the 240 Hz refresh). M0: p95 4.7 ms, GPU 0.7 ms.
- Balance runs: 1,000 full M1 runs in under 15 minutes on 6 processes; bench at least 6,000 ticks/s.
- Spend: soft cap about $40 per session, every paid call in `docs/SPEND.md`.
- Disk: C: has about 18 GB free; no raw movies kept, outputs pruned.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Drilling between nodes feels like a chore | Short segments, real choices (ore against noise against heat), surprises along the way, early tests; fallback auto-drill with interruptions. |
| Too much at once | Pause anywhere, crew handle emergencies, clear alerts, the critic loop. |
| GDScript too slow | Measured: 4.7x headroom. Re-measure in M1; Rust hot spot if needed. |
| Inconsistent generated art | One bake-off, one style guide, one pipeline, scripted normal maps. |
| Scope | Milestone gates, content as data, balance by simulation. |
| Older Godot knowledge in models | Local 4.7.2 API dump, scout agent, strict typing, every script compiled in tests. |
| Two Godot projects on one PC | Side-by-side rules; contention flagged; job objects; no fixed ports. |
| Godot's 2D light cap (about 15 per canvas item) | Small per-room nodes, idle lights disabled; watch it as rooms and lights grow. |
