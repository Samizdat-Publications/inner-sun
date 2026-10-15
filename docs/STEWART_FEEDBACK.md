# Stewart's feedback and decisions

His words outrank everything except CLAUDE.md's hard rules. Newest first. Playtest notes go at the
top under a dated heading.

## 2026-10-15: first M1 session
- **The making of:** "As with all my projects, keep copies of relevant milestones etc and label them
  so that we can build a 'The making of' page afterwards that shows our progression from start to
  finish." Kept in `docs/making-of/README.md` (timeline, clips, tags, milestone builds) and
  `docs/progress/`.

## 2026-10-15: planning session decisions
- **Ship shape: the tall tower** (decks stacked, drill at the bottom, boring straight down), chosen
  over a horizontal mole.
- **Godot projects on this PC:** "I'm having cut and fill find a stopping point and then pausing. I
  want this project and the black diamond project I just started to be the only two running godot."
- **Session style:** plan in plan mode, run Milestone 0 in the planning session, then hand off to a
  fresh build session at the effort level Claude recommends ("we tend to have one on higher thinking
  that uses subagents to delegate").

## 2026-10-15: the original kickoff (verbatim)

I want to build an FTL-style roguelite where the ship is a drilling vessel descending into a hollow Earth. Working name: Inner Sun (rename it if something better comes up). New repo in my Samizdat-Publications GitHub org. You have full latitude on architecture and design; everything below is direction and recommendation, not a requirement, except where I say a decision is made. Pivot whenever you find a better path.

THE PITCH
Near future. A black-budget expedition follows a trail of old anomalies (Admiral Byrd's 1947 polar flight claims, abandoned Soviet superdeep boreholes, seismic signals nobody can explain) and finds that the hollow Earth legends are true. You command a drill ship and its crew, boring down through layer after layer of an underworld that gets stranger the deeper you go: fossil caves and old mine works, giant crystal caverns, an underground sea, fungal forests, the ruins and cities of Agartha, and an inner sun. At the very bottom is the answer to a modern mystery: the facility where the UAPs (the Tic Tacs the Navy keeps chasing) are fabricated, launching out through vents in the ocean floor. That's why nobody ever catches them.
Tone: pulp. Journey to the Center of the Earth meets The X-Files. Wonder, danger, conspiracy, humor, redacted documents, crackling radio from a handler topside who knows more than they say.

DECISIONS ALREADY MADE
- Genre: FTL-style. A cutaway ship of rooms and systems, a limited power supply split across systems, crew who staff stations and repair damage, hazards that spread room to room, a node map you choose your route through, text events with choices, stores, and real-time combat with pause.
- View: 2D side-view cutaway (like Barotrauma, not FTL's top-down), because depth is the whole game: you see heat and water rising in rooms, the drill biting into rock below, caverns opening underneath. Atmospheric 2D lighting is essential: flashlights, emergency lights, the glow of the drill face and magma.
- Structure: roguelite runs. A run is one descent. The order of layers is fixed so every run follows the same story spine, but each layer's contents are procedurally generated. The story is revealed across runs through events and a persistent codex of discoveries (Hades-style: dying teaches you something). A scripted campaign may come later; don't build for it now beyond keeping it possible.
- Engine: Godot 4 (latest stable), native Windows build. Graphics, performance, and depth matter more than shareability.
- Era: unnamed near future. Real history (Byrd, the Soviet Kola Superdeep Borehole and its "well to hell" legend, Cold War drilling programs) shows up as discoverable lore and wrecks in the layers, not as the setting.

THE THING THAT MAKES THIS DIFFERENT: DRILLING
My favorite games are digging games where you collect ore and gems and upgrade your gear. Choosing a route toward resources on the node map should scratch that itch, and I'd like the drilling itself to be hands-on. Suggested approach (test it, change it if it doesn't work): travel between map nodes is a short, active drilling segment in the side view. You steer the drill through destructible, procedurally generated rock, choosing whether to detour for ore veins and gem pockets, while managing drill heat, bit wear, and hazards (gas pockets, water and magma breaches, unstable rock). Then you arrive at the node: an encounter, a cavern, a store, a fight, or an event. Keep the drilling segments short enough that runs stay paced like FTL.

HOW FTL'S SYSTEMS TRANSLATE (my suggestions)
- Reactor power: a power plant with limited output split across systems.
- Oxygen: heat. Deeper rock is hotter. Coolant keeps rooms survivable; heat spreads between rooms and builds when systems are damaged.
- Hull breaches and fire: cave-ins, water or magma breaches (fire and flood together), gas explosions, structural stress at depth.
- Shields: hull bracing and pressure systems.
- Sensors: a seismic scanner that reveals the map ahead, including hidden ore, caverns, and threats.
- Weapons: borer turrets, thermal lances, sonic emitters, mining charges.
- Boarding and away teams: send crew out through the airlock into caverns for salvage and events, and repel things that dig in.
- The pursuing rebel fleet: something enormous is following your vibrations. Your drilling is noise, and it is coming. This forces you onward and makes loud, greedy detours a risk.

LAYERS (fixed order, procedural contents; adjust as needed)
1. The Crust: caves, fossils, old mine works, wrecked Soviet drill rigs.
2. The Deep Crust: heat, magma channels, giant crystal caverns.
3. The Abyssal Sea: an underground ocean. The submarine is an unlockable vessel built for this layer.
4. The Mantle Wilds: fungal forests, strange fauna, Agartha's outskirts.
5. The Inner World: the inner sun, Agarthan cities, factions you can trade with or fight.
6. The Foundry: the UAP fabrication facility. The finale.

RESOURCES AND PROGRESSION
- Run economy: ores (hull, parts, repairs), gems (currency and upgrades), coolant, power cells, drill bits, and rare exotic materials (Agarthan crystal, foundry alloy) for top-tier upgrades.
- Crew: recruited from events (lost expedition survivors, Agarthan guides, salvaged robots, defectors), each with skills per station. They can die permanently within a run.
- Meta progression across runs: unlockable ships and layout variants (a starting light drill, a heavy borer, a thermal lance ship, the submarine, an Agarthan vessel, and as a final secret a captured craft from the Foundry), the codex, and lore that changes what you know on later runs.
- Combat enemies: rival drill crews, burrowing creatures that latch onto the hull, Agarthan guardians, and the Foundry's drones.

REFERENCES
FTL (the core structure, my favorite game), Barotrauma (side-view cutaway, flooding, crew AI), Dome Keeper, Motherload, and SteamWorld Dig (the digging and upgrade itch), Slay the Spire (the node map), Hades (story told across runs).
Barotrauma's source code is public on GitHub (C# on MonoGame). Don't copy its code, but read it as needed to learn how they solved the hard problems: water and pressure flowing between rooms, hull damage, crew AI choosing jobs, and lessons they learned. Use it as context if it's worth your time.

RECOMMENDED BUILDING BLOCKS (evaluate, verify licenses, use what helps)
- ink (inkle's narrative scripting language, with a Godot integration) or Dialogic for FTL-style events and branching text.
- Beehave or LimboAI for crew behavior.
- Godot's built-in pathfinding for crew movement between rooms.
- GDScript for most of the game. If profiling shows a hot spot (for example the heat and fluid simulation between rooms, or the destructible terrain), move just that piece to C++ through GDExtension, or C#.

ART AND SOUND
2D side-view art with dynamic lighting (normal-mapped sprites so lights and shadows play across rooms). Pick one consistent style early and test it: crisp high-resolution pixel art (PixelLab is available) or a painted pulp-illustration look (Gemini concept art). Pulp touches: dossier-style event text with redactions, retro-futurist instrument panels, radio chatter. Sound: drill roar that changes with rock hardness, groaning hull under pressure, alarms, distant things moving in the rock, voiced radio lines (ElevenLabs).

MILESTONE 0: PROVE THE AUTONOMOUS LOOP IN GODOT (GATE)
Before any real game work, prove you can work on this Godot project autonomously: run the game headless or scripted, drive it with a test bot, capture screenshots from the game camera, run automated tests, read errors and logs, and fix what you see without me. Evaluate Godot's command line and headless mode, frame capture, test frameworks such as GUT or gdUnit4, and community Godot MCP servers. My other Godot game in progress (repo black-diamond in the same org) is proving this same loop; if it has already solved it, reuse that approach. If the loop does not hold up, STOP and present me my options with your honest recommendation. Do not silently switch engines.

MILESTONE 1: FIND THE FUN
A vertical slice: one starting drill ship with about six rooms, three crew, power allocation, the heat system plus at least fire and one kind of breach, one layer with a node map of about eight nodes, the drilling segment between nodes, one combat enemy, one store, a few events, and a full run from start to death to codex. I will playtest it. Iterate on the core loop here before building out content.

HOW I'LL KNOW IT'S RIGHT
- Automated harness: bot playthroughs, systems tests (heat and hazards spreading as designed, crew AI handling emergencies), and screenshots you inspect yourself.
- Balance by simulation: a headless mode that plays thousands of runs with simple bot strategies and reports win rates, death causes, resource curves, and how often each event fires, so balance is tuned with data.
- Performance smooth on my RTX 5070.

ARCHITECTURE FOR GROWTH
Data-driven everything: ships and layouts, rooms and systems, weapons, crew traits, enemies, events, layers, and node types. Adding content should mean adding data, not rewriting systems.

MY TOOLS
Godot (find it on my machine), Blender 5.1 (C:\Program Files\Blender Foundation\Blender 5.1\blender.exe) if pre-rendered elements help, plus API keys for Gemini, OpenAI, ElevenLabs, Meshy, Tripo, PixelLab, and Sketchfab access. Keys live in the .env files of my seked and Noclip projects. Use whatever helps; none of it is required. Final docs: a README a non-programmer can follow.

HOW TO RUN THIS
I'm not a programmer and want this to run as autonomously as possible.
- Plan first in plan mode (I'm starting this session on max effort). Research what you need, then show me a plan with the major decisions, risks, milestones, and the content roadmap.
- After I approve the plan, run Milestone 0. Then write HANDOFF.md alongside PLAN.md and PROGRESS.md: the exact prompt I should paste to start the build in a fresh session, the effort level it should run at and why, the delegation approach, and anything a fresh session needs that isn't obvious from the files. This planning session ends there.
- During the build, the main thread stays on architecture, integration, game feel, and judgment calls. Delegate well-specified implementation work to subagents on a cheaper model (Opus or Sonnet at medium effort is the sweet spot), and push CPU-bound or repetitive work (balance simulations, asset processing, test runs, screenshot passes) to background scripts or the cheapest capable agent.
- Ask me only about decisions that can't be undone or that change what the final product is.
- Never use em dashes in any text you write.

CHECKPOINTS
- Keep PROGRESS.md current: milestone, done, in flight, known issues, exactly what's next.
- Commit and update PROGRESS.md after every milestone or meaningful chunk of work so a sudden cutoff never loses much.
- If I type "checkpoint," finish or safely stop the current step, update PROGRESS.md and HANDOFF.md, commit everything, and stop.
- A fresh session should be able to resume from the files alone.
