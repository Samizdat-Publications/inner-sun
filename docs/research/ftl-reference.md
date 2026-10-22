# FTL as a reference: what is documented, and what to build first

Written 2026-10-22 by a planning session (D052 to D055). Purpose: get the systems Stewart cares about
to rough parity with FTL's feel quickly, from what the community already wrote down plus watching
the game, then make them Inner Sun's own. Nothing here is built yet; Stewart picks from the
inventory (section 4) first.

Companion files: `behavior-ledger.md` (row format and example rows), `ftl-observation-plan.md`,
`ftl-difftest-plan.md`, `PLAN.md` section 10, `docs/plans/M2_parity.md`.

## 1. Firewall (read before anything else)

- **Nothing from FTL enters the committed repo:** no code, text, art, audio, names, event writing,
  data files or exact numbers. This file links to sources and describes behavior in our own words;
  the numbers stay in `research_private/` (git-ignored).
- **Observers and builders are different people.** The lead (or an observer agent in the main
  checkout) reads FTL material and writes ledger rows with Inner Sun targets. Builders work in
  worktrees, where `research_private/` does not exist, from ledger rows only, and do not open this
  file's links.
- **Inner Sun's values are its own.** They come from the shapes and ratios (what rises, how fast,
  how it compares), set against Inner Sun's pacing; they are never copied.
- **The install is read only.** `tools/ftl_unpack.py` reads `ftl.dat` and writes only to
  `research_private/ftl_<version>_unpacked/`. The game is 1.6.14 on this PC (its log, 2026-10-22).

## 2. Sources, checked 2026-10-22

Survey agents fetched each source this session (reading pages only, installing nothing) and
checked it for currency against FTL 1.6.14 (Advanced Edition); exceptions are marked "not read".

### Wikis and written research
| Source | Status on 2026-10-22 | What it documents | Use |
|---|---|---|---|
| FTL Wiki on Fandom, https://ftl.fandom.com/wiki/ | Live, actively edited (mechanics pages revised 2024 to October 2026), Advanced Edition aware, CC-BY-SA. Automated fetches get HTTP 402; read it through its MediaWiki API (`/api.php`) or a browser. | Nearly every mechanic: `Ship`, `Systems`, `Crew_skills`, `Crew`, `Fires`, `Venting`, `Oxygen`, `Door_System`, `Engines`, `Shields`, `Piloting`, `Weapons`, `Boarding`, `Environmental_Hazards`, `Sectors`, `Beacons`, `Rebel_Fleet`, `Rewards`, `Scrap`, `Stores_and_resources`, `Blue_Options`, `Enemy_Ships`, `The_Rebel_Flagship`. No single page for dodge, breaches, combat or repair; those are spread across the pages above. | **Primary.** |
| ftlwiki.com | **Dead.** The domain now serves an unrelated company; wiki paths return 404 or 403. The Wayback Machine holds the real wiki up to 2022-05. | Older, base-game era; several numbers contradict Fandom and the game's code. | Historical only; Fandom wins any disagreement. |
| xftl reverse-engineering notes, https://gitlab.com/znixian/xftl/-/tree/master/doc | Static (docs last touched 2024-06, made against 1.6.9). Fandom cites them as its source for fire, air, damage, crew AI, map generation and stores. | Exact rules the wiki lacks: fire spread and burn-out, air drain and refill, sabotage pace, crew task priorities, rival targeting, region and stop generation, store rolls. | **Primary for engine rules.** Spot-check against 1.6.14 by observation where it matters. |
| "Calculated FTL" Steam guide, https://steamcommunity.com/sharedfiles/filedetails/?id=2127539536 | Withdrawn from public listing, no longer updated; its formula images are lost. | Reward formula, enemy generation, difficulty effects, pursuit tactics, from the game's code. | Second opinion for rewards and enemy scaling. |
| Mike Hopley's scrap calculators, https://mikehopley.github.io/ftl-scrap | Cited by Fandom's `Scrap` page; not read this session. | Expected scrap by route. | For run-level income in step P2. |
| Subset Games forum, https://subsetgames.com/forum/ (R&D thread `viewtopic.php?p=8135`, link index `t=17135`, XML elements `t=2270`) | Alive; the format threads date from 2012 to 2014 | Early ship-layout syntax, tag catalogues, an index of tools. No thread collects hard-coded values. | Thin; the tools below supersede it. |
| TASVideos research by keylie, https://tasvideos.org/Forum/Posts/496924 | 2020, against 1.5.13 | How the game seeds its randomness, generates maps and resolves events (all stops are decided when a region is generated; a fight keeps only a seed; stores roll on entry). | Useful for observation: it suggests a reloaded save may replay a fight the same way (to verify). |

### Modding tools and mods
| Source | Status on 2026-10-22 | What it documents | Use |
|---|---|---|---|
| FTL: Hyperspace, https://github.com/FTL-Hyperspace/FTL-Hyperspace (wiki, `reference` branch, `Mod Files/data/hyperspace.xml`) | Active: v1.23.2 (2026-09-25), pushed 2026-10-21; GPL-3.0. Hooks 1.6.9 on Windows (through a downgrader), 1.6.13 on Linux. | Generated headers naming every engine class, field and method (from Linux debug symbols), a Lua API, a list of engine events, the default values of many hard-coded numbers (in comments of its XML), and the original enemy-ship generator kept as pseudo-code in a comment. It names the fire and air functions but does not spell out their math. | **Primary for rival generation and seeds.** Read for rules only; GPL code is never copied, and builders never open it. |
| FTL: Multiverse, https://ftlmultiverse.miraheze.org | v5.5.1 (2025-05-28); a wiki of about 720 articles | How far the data model stretches: faction reputation, hidden run variables, custom systems, challenge levels, preparation before fights, all built on Hyperspace. Players praise its volume and writing and criticise its difficulty and sprawl; nobody ranks its mechanics by fun. | Ideas for later layers (factions in the Inner World); a warning about scope. |
| Slipstream Mod Manager, https://github.com/Vhati/Slipstream-Mod-Manager | v1.9.1 (2018), small fixes to 2025-08; GPL-2.0 | The archive formats (`PkgPack.java` for 1.6's single archive, `FTLPack.java` for the older pair) and the XML patching tags mods use. | Format reference for `tools/ftl_unpack.py` (rules only, no code taken). |
| ftlman, https://github.com/afishhh/ftlman, and silpkg, https://github.com/afishhh/silpkg | ftlman v0.7.4 (2026-08-20), GPL-2.0; silpkg (2025-05), Apache-2.0 | A maintained Rust replacement for Slipstream; a permissively licensed reader for the 1.6 archive. | Alternatives if the unpacker ever needs more; not needed now. |
| ftldat: Rust crate (0.1.1, 2023) and the older Python and C tools | The Python tool (2012 to 2017) reads only the pre-1.6 archives; the crate is a self-described learning project | Archive formats. | Skip: our own small reader (`tools/ftl_unpack.py`) handles 1.6.14. |
| Superluminal 2 ship editor, https://github.com/kartoFlane/superluminal2 (archived 2020) and a maintained fork (v2.4, 2025-11) | GPL-2.0 | Ship layouts: rooms, doors, airlocks, system rooms, weapon mounts, and the layout text format as working code. | Reference for layout rules if ship variants are picked (inventory 7). |
| Mike Hopley's layouts site, https://ftl-layouts.mikehopley.org | Live (hard difficulty only) | Rival system-level ranges by region. | Second source for rival scaling (inventory 13). |
| Old ftlwiki modding pages via the Wayback Machine (`Events_file_structure`, `Modding_ships`) | 2019 copies | Event tags, ship layout and blueprint tags. | Format reference; the 1.6.14 data itself is the final word. |

**What only research documents** (not the data, not the wikis): the enemy-ship generator (system
levels, install chances and upgrade budgets by region and difficulty, from Hyperspace), map
generation constants and pursuit advance (xftl, Hyperspace, TASVideos), fire and air math (xftl
only; Hyperspace has the function names), crew task priorities and rival targeting (xftl, plus
unverified community claims). **Undocumented anywhere:** how rival weapons pick rooms in detail,
event-list selection weights, store rarity formulas, and every feel and pacing measure. No
decompilation of FTL is public, and none is needed for this plan.

### The game's own data (FTL 1.6.14, unpacked privately)
`python tools/ftl_unpack.py` reads the installed `ftl.dat` (a "PKG" archive with a documented
layout) and writes its data files into `research_private/ftl_1.6.14_unpacked/data/`. Images
and audio stay packed. A survey agent mapped what the files expose (full notes, private:
`research_private/data_model.md`):
- **In the data:** system levels, purchase prices and upgrade price ladders; weapon, drone and crew
  stats and prices with a rarity weight; ship layouts (rooms come in a few small sizes) and which room holds which system; rival ship definitions with
  power ranges and depth gates; each region kind's mix of stop types (fights are the biggest single kind in
  hostile regions, stores a small share); every event, with requirement-gated
  choices (about a fifth of all choices) and the reward tier each names; surrender and escape
  thresholds for rivals; the three boss stages as three ship definitions.
- **Not in the data (engine rules, from the wikis and xftl, or observation):** reactor prices, the
  damage model, shield recharge, the dodge formula, all fire, air and breach rules, crew health,
  speed, repair and skill numbers, weapon timing and manning bonuses, map generation and pursuit,
  how rivals scale and allocate power, reward and store amounts, hazard strengths, boss phase logic.
- The data does not pass a strict lint (some lists name ids that do not exist): a reminder that
  Inner Sun's `DataDB.lint()` is worth keeping strict.

## 3. System by system: how well each is documented

Coverage: **DOCUMENTED** (rules and numbers written down, sources agree or quote the game's code or
data), **PARTLY** (rules described, some numbers missing or disputed), **OBSERVE** (nobody wrote it
down; watch the game, `ftl-observation-plan.md`). The shapes are in our own words; the numbers are in
`research_private/` (`wiki_ship_mechanics.md`, `wiki_run_structure.md`, `data_model.md`).
"Fandom" means pages under https://ftl.fandom.com/wiki/; "xftl" means
https://gitlab.com/znixian/xftl/-/tree/master/doc.

### Ship interior

| Mechanic | Coverage | Best sources | Shape, in our words |
|---|---|---|---|
| Reactor and power | DOCUMENTED | Fandom `Ship`, `Systems` | One pool of bars, moved between systems instantly at any time; each system accepts as many bars as its level; damage removes usable bars; a temporary battery adds bars for a while, then cools down. |
| Each system's effect per bar | DOCUMENTED | Fandom `Systems`, `Shields`, `Engines`, `Piloting`, `Sensors`, `Medbay`, `Door_System` | Shields: every second bar adds a layer that soaks one hit and recharges; engines: dodge per bar, only with a crewed helm; the air system refills every room at a rate rising steeply per level; sensors show more of both ships per level; doors resist more per level. |
| Damage and repair | PARTLY | Fandom `Systems` ("Damaged and destroyed systems"), `Crew_skills`; xftl `damage-notes` | Hits remove bars at once; fire and intruders wear a bar down over a fixed time instead; repair is bar by bar at a fixed pace per crew member, faster with skill; progress is lost if the repairer leaves; a system burned out completely also costs hull. Undocumented: whether two repairers stack, whether partial damage blocks manning (OBSERVE O-04). |
| Crew skills and kinds | DOCUMENTED | Fandom `Crew_skills`, `Crew` | Six skills with two levels above untrained, earned by doing the job (dodges while piloting, shots fired, bars repaired, kills); a manned station's bonus is modest at first and doubles or triples at the top; crew kinds differ in health, speed, repair and firefighting rate, and immunities. |
| Fire | DOCUMENTED | Fandom `Fires`, `Door_System`, `Venting`; xftl `fires` (the wiki quotes it) | Fire lives tile by tile and does not grow in place: it spreads to neighbouring tiles on a random countdown, slower through a closed door and far slower through a reinforced one, never through walls; it damages systems and crew at steady rates and burns the room's air; it dies within seconds once the air is gone; each crew member puts out a burning spot in a matter of seconds and hands add up. |
| Air (our heat) | DOCUMENTED | Fandom `Oxygen`, `Venting`; xftl `oxygen` | Air is a percentage per room; the air system refills every room at once; breaches and open airlocks drain it, less the farther a room is from the hole; low air hurts crew; venting a room empties it in a few seconds. |
| Breaches | PARTLY | Fandom `Ship` (Hull), `Oxygen`, `Weapons_(tables)`; xftl `oxygen` | A breach drains air and blocks manning and repair in its room until sealed; sealing takes about as long as repairing a bar; it adds no hull damage of its own. Undocumented: several breaches per room, where they appear. |
| Dodge | DOCUMENTED (the hit roll itself: OBSERVE) | Fandom `Engines`, `Piloting`, `Crew_skills` | Dodge adds up: engine level, plus manning, plus a skill step; it needs a live pilot (an autopilot gives a fraction); beams ignore it; the screen shows it as a number. |
| Weapons and shields in combat | PARTLY | Fandom `Weapons`, `Weapons_(tables)`, `Shields`, `Enemy_Ships` | Weapons charge only while powered and can be held and fired together; a shield layer stops one shot whatever its size and layers recharge one at a time; missiles pass layers, beams lose strength per layer; some hits start fires or breaches by chance; ion-type hits lock bars for seconds instead of breaking them; rivals surrender or flee by chance at low hull. Undocumented: projectile travel times, how multi-hit shots pick rooms. |
| Boarding and intruders | DOCUMENTED | Fandom `Boarding` | Intruders fight crew room to room and wear down the system they stand in; doors slow them by level. |
| Rival AI (targeting, power, crew) | PARTLY | xftl `combat-ai`, `crew-ai`; a Reddit study of hard-mode targeting (cited by Fandom) | Rivals pick system targets by a priority list with some randomness (smarter on hard); their crew work a task priority list (shields first, then weapons). How they move power is less documented: OBSERVE O-11. |

### Run structure and economy

| Mechanic | Coverage | Best sources | Shape, in our words |
|---|---|---|---|
| The region map (sectors) | DOCUMENTED | Fandom `Sectors`; xftl `sector-map` | A fixed number of regions; each middle column offers 2 to 4 choices, never the same width twice in a row; friendly regions most common, hostile less, nebulas least; special regions unlock only at depth. |
| Stops inside a region (beacons) | PARTLY | Fandom `Sectors`, `Beacons`; xftl `sector-map` | A loose grid with a cap on empty cells; neighbours link within a radius; the exit sits on the far side, a minimum number of jumps away; contents fill from an ordered list, guaranteed ones first; fights are a large minority. The beacon count is disputed between sources and the realised mix was never measured. |
| The pursuit | DOCUMENTED | xftl `sector-map`; Fandom `Rebel_Fleet` | The front moves a fixed step per jump, not per second; quiet places (nebulas) slow it; some events delay or hurry it; a region gives roughly the shortest route plus as many spare jumps again; a covered stop holds a hard fight that pays almost nothing under periodic heavy fire. |
| Rewards | DOCUMENTED (run totals: OBSERVE) | Fandom `Rewards`, `Scrap`; the "Calculated FTL" Steam guide | Payouts climb roughly linearly with region; difficulty shifts the climb later; three overlapping tiers; destroying the crew pays more on average than destroying the ship; supplies rewards do not scale. Nobody documents what a whole run earns. |
| Stores | DOCUMENTED | Fandom `Stores_and_resources`; xftl `stores` | A few sections, each with a few rarity-weighted offers; essentials forced in when the player lacks them; consumables at fixed prices with limited stock; hull repair pricier with depth; sell-back at a fraction. |
| Consumables | PARTLY | Fandom `Stores_and_resources`, `Rewards` | Fuel per jump, missiles and drone parts per use; scarce by availability more than by price; running dry turns into a slow, dangerous wait. Per-run budgets: OBSERVE. |
| Upgrade prices | DOCUMENTED | the game's data (`blueprints.xml`); Fandom `Ship` for the reactor | Each next level costs more; the top levels cost several times the first; reactor bars rise in steps. |
| Enemy scaling | PARTLY (the data has the ship definitions) | "Calculated FTL"; Fandom `Enemy_Ships`; the game's data (`autoBlueprints.xml`) | Each rival class has ranges of system levels and hull; deeper regions raise the floor and ceiling and add a random upgrade budget; easy lags a region, hard adds budget and smarter targeting. |
| Events | PARTLY (the data has every event) | Fandom `Blue_Options`, `Beacons`; the game's data (`events*.xml`) | Stops draw from region-specific lists (duplicates act as weights); events chain through choices and can start fights, add crew or delay the pursuit; requirement-gated choices usually pay best; quests mark another stop on the map. |
| Environments | PARTLY (kinds and frequency documented; strengths only as tooltip prose) | Fandom `Environmental_Hazards`; the game's data (`sector_data.xml`, events) | Debris fields, stellar heat, power-sapping pulses, sensor-blinding clouds and power-halving storms change a whole stop for both ships. |
| Difficulty | PARTLY | Fandom `Rewards`, `Enemy_Ships`, `Score` | Easier settings start richer and run the reward and enemy ramps early; harder ones the reverse plus smarter rivals. Whether it changes pursuit speed or prices is undocumented. |
| The final fight | DOCUMENTED | Fandom `The_Rebel_Flagship`, `Sectors` | The last region is a defence against a stalking boss; the fight has three stages, each shedding part of the ship and switching threat type. |

### Feel and pacing: nobody writes this down (OBSERVE)
How long a fight lasts, how often a crisis lands, how many decisions a minute the player makes, how
long a region takes in real time, how a fire reads in its first seconds. These come from Stewart's
recorded FTL runs (observation protocols O-06 to O-08 and O-01) and are compared with his Inner Sun
run records (`ftl-difftest-plan.md`, layer 5).

## 4. Scored inventory

Every FTL system or mechanic that could matter, scored for Inner Sun. The scores are the lead's
judgment from the survey, the game's data, the sim and data as of commit `df2eb8a`, and Stewart's
notes (`docs/STEWART_FEEDBACK.md`).

| Score | Meaning |
|---|---|
| **Fit** 1 to 5 | How naturally it belongs in a drill tower boring through layers (5: it would feel native) |
| **Fun** 1 to 5 | How much of FTL's fun it carries (5: a reason people love FTL) |
| **Close** 0 to 4 | How close Inner Sun already is to FTL's feel there (0: nothing, 4: at parity) |
| **Cost** 1 to 5 | Build cost (1: data and tuning in existing code, about a session; 3: a new rule set plus UI; 5: a new major subsystem) |
| **Docs** D, P, O | Documentation coverage (D: documented, P: partly, O: needs observation); worth 3, 2, 1 |

**Value** = Fit x Fun x (4 - Close) / 4 (0 to 25). **Effort** = Cost + (3 - Docs) (1 to 7).
**Rank** = value / effort, highest first. Ties inside the top 11 go to the bigger gap (lower Close),
then to systems Stewart's notes already mention; below that, tied rows are in no particular order.

| # | System (Inner Sun terms; FTL counterpart in brackets) | Inner Sun today | Fit | Fun | Close | Cost | Docs | Value / effort |
|---|---|---|---|---|---|---|---|---|
| 1 | **Rising upgrade prices** (system and reactor upgrade cost curves) | One flat ore price per system per store, 120 to 200, one or two buys | 5 | 4 | 1 | 1 | D | **15.0** |
| 2 | **Rewards that grow with depth, in tiers** (scrap by sector and difficulty, low/medium/high reward tiers) | Fight loot flat at every row (3 to 8 ore, 5 to 12 gems; the gate x3); event rewards fixed per event | 5 | 4 | 1 | 1 | D | **15.0** |
| 3 | **Manned stations and their bonuses** (manning bonuses on every station, growing with skill) | Drill and weapons +15% when manned, helm needs a crew member; bracing, coolant and reactor give nothing; skill does not count | 5 | 4 | 2 | 1 | D | **10.0** |
| 4 | **Doors, hatches and purging a room** (door control and venting) | The sim honours closed doors for water, heat and fire, but the player cannot open or close anything; no way to starve a fire | 4 | 5 | 1 | 2 | D | **7.5** |
| 5 | **Stores that roll their stock** (store sections, random offers by rarity, sell-back at half) | Two fixed stock lists, the same every visit | 5 | 4 | 1 | 2 | D | **7.5** |
| 6 | **Node environments** (environmental hazards that change a whole beacon: falling debris, heat, blinding, power loss) | Hazard nodes exist but hold only two events, often empty; nothing changes a fight's conditions | 5 | 4 | 1 | 2 | D (note 1) | **7.5** |
| 7 | **More ships, and layouts per ship** (unlockable ships with variant layouts) | One ship; requisitions carry over, ship unlocks are planned for M2 | 5 | 4 | 0 | 3 | D | **6.7** |
| 8 | **Pursuit shaped like FTL's** (fleet advance per jump, slack before the exit falls, overtaken beacons, delays) | The pursuer moves with time, noise and depth and strikes when it catches you; events can push it back | 5 | 5 | 2 | 2 | D | **6.25** |
| 9 | **Deeper events** (requirement-gated choices, quests marked on the map, reward tiers, pursuit delays) | 17 dossier events with choices gated by system, resource or skill; no map quests, no tiers | 5 | 5 | 2 | 2 | D | **6.25** |
| 10 | **Fire parity** (start, growth, spread, system and crew damage, putting it out) | Fire grows, spreads (up faster than down), damages systems, crew fight it, water and douse suppress it | 5 | 5 | 3 | 1 | D | **6.25** |
| 11 | Power allocation parity (reactor bars, priorities, damage limiting power) | Built: reactor bars, per-system caps, damage removes capacity, priority order for bots | 5 | 5 | 3 | 1 | D | 6.25 |
| 12 | Dodge that stacks (evasion from engines, piloting, manning, skill, shown as a number) | Dodge from helm bars only, when manned | 4 | 3 | 2 | 1 | D | 6.0 |
| 13 | Rivals that scale with depth (enemy system levels by sector and difficulty) | Three rival ships, picked by row band | 4 | 3 | 2 | 1 | D | 6.0 |
| 14 | Difficulty levels (easy, normal, hard shifting rewards and enemies) | None | 3 | 2 | 0 | 1 | D | 6.0 |
| 15 | Disruption weapons (ion: locks and drains bars instead of breaking them) | None (sonic emitters are planned for M2) | 4 | 4 | 0 | 3 | D | 5.3 |
| 16 | Silent running (cloaking; for us, also hiding from the pursuer) | None | 4 | 4 | 0 | 3 | D | 5.3 |
| 17 | Crew who get better at their jobs (skill growth per station) | Fixed fire and repair multipliers per crew member | 5 | 4 | 1 | 3 | D | 5.0 |
| 18 | Bracing as recharging layers (shields) | Built: two bars per layer, a layer soaks a hit, recharges | 4 | 5 | 3 | 1 | D | 5.0 |
| 19 | Scarce consumables (fuel, missiles, drone parts) | Built: cells per segment, charges, bits, coolant | 5 | 4 | 3 | 1 | D | 5.0 |
| 20 | Gear as passive modules (augmentations, slots, sell-back) | Drill heads, plating and pumps as owned gear | 5 | 4 | 2 | 2 | D | 5.0 |
| 21 | A gate boss in phases (the multi-phase final boss) | One gate fight against a heavy rival | 4 | 5 | 1 | 3 | D | 5.0 |
| 22 | Crew kinds with different abilities (races) | Crew differ only in fire and repair multipliers | 4 | 4 | 1 | 3 | D | 4.0 |
| 23 | Heat as the air (oxygen refill, drain, suffocation) | Built: heat in joules, coolant, crew harm above a threshold | 4 | 4 | 3 | 1 | D | 4.0 |
| 24 | A healing station (medbay) | Crew heal slowly anywhere | 4 | 2 | 2 | 1 | D | 4.0 |
| 25 | Map shape (beacon count, exits, distress, scanner reveal) | Built: 14 rows of 2 or 3 nodes, surveys, scanner rows | 4 | 4 | 3 | 1 | D | 4.0 |
| 26 | Helpers with a parts consumable (drones; for us, a mining or scout drone) | None | 4 | 4 | 0 | 4 | D | 4.0 |
| 27 | Boarding both ways (intruders, sending crew across) | The away miner; burrowers specced for M2 | 5 | 4 | 1 | 4 | D | 3.75 |
| 28 | Sensors (seeing inside the enemy, blind when damaged) | The scanner shows rock and the map, not the rival's interior | 3 | 3 | 1 | 2 | D | 3.4 |
| 29 | Rivals that surrender, flee, or lose their crew | Only the player can flee | 3 | 4 | 1 | 2 | P | 3.0 |
| 30 | Damage and repair pace (bars lost, partial repairs, skill speed) | Built: fractional damage, crew repair by skill | 5 | 4 | 3 | 1 | P | 2.5 |
| 31 | Breach parity (drain, patching) | Built: water breaches, crew patch them | 5 | 3 | 3 | 1 | P | 1.9 |
| 32 | How rivals pick targets and move power (enemy AI) | A simple enemy AI | 3 | 3 | 2 | 2 | P | 1.5 |
| 33 | Choosing the next region between layers (sector branching) | Fixed layer order by design (D001) | 2 | 3 | 1 | 3 | D | 1.5 |
| 34 | Hacking, mind control, teleporting, artillery | None | 2 | 3 | 0 | 4 | D | 1.5 |
| 35 | Weapon timing and targeting (charge, hold, volleys, aim at rooms) | Built: charge times, volleys, beams, piercing charges, room targets | 3 | 5 | 3 | 2 | P | 1.25 |

### The top 10 in a few lines each

1. **Rising upgrade prices.** In FTL each further level of a system costs more than the one before
   and the reactor's bars get dearer in steps, so every upgrade competes with weapons, crew and
   repairs for the same money. Inner Sun sells each upgrade at one flat price and caps how many a
   store sells. Parity is a data and pricing change in `game/sim/events/store.gd` plus price tables;
   the risk is only balance, which the bots measure.
2. **Rewards that grow with depth, in tiers.** FTL's payouts climb steadily from the first sector to
   the last, harder difficulties shift the climb later, and each reward rolls in one of three
   overlapping tiers, so a lucky early fight can feel like a jackpot. Inner Sun's fight loot is the
   same at row 1 and row 13. The dig already gets richer with depth (D025), so this is mostly fight
   loot and event payouts, data and a little code.
3. **Manned stations.** In FTL every main station does more when crewed, more again with skill, and
   which station a crew member stands at is a constant small decision. Inner Sun has the hook
   (`manned_bonus` in `game/data/systems/*.json`, used by the drill and weapons) but most stations
   ignore crew. Parity: every station gets a manned effect that grows with skill. Pairs with 17.
4. **Doors, hatches and purging.** FTL players open doors and airlocks to starve fires and choke
   boarders, and close them to slow spread: one of its most loved tactics. Inner Sun's sim already
   blocks water, heat and fire at closed links, so door control is mostly a view feature. The Inner
   Sun twist (heat is our air): purging a room to the rock kills its fire and lets rock heat (and,
   deeper, gas) in while it stays open. New rule, needs a ledger row and a DECISIONS entry.
5. **Stores that roll their stock.** FTL stores show two to four categories with three random offers
   each, weighted by rarity, plus fixed-price consumables and repairs whose price rises with depth;
   you can sell gear back at half. Every store visit is a small puzzle. Inner Sun's stock lists never
   change. Parity: pools and rarity in data, a roll from the run's seeded stream.
6. **Node environments.** Some FTL beacons sit in a hazard that changes the fight for both ships
   (debris that hits random rooms, heat that starts fires, a pulse that drains power, a cloud that
   blinds sensors). Inner Sun's dig has natural candidates (rockfall seams, magma heat, magnetite
   that blinds the scanner, gas seams) that would apply to the segment into the node and to any
   fight there. Fills Inner Sun's empty hazard nodes (a known gap).
7. **More ships and layouts.** FTL's long-term pull is unlocking ships, each with alternative
   layouts that change how it plays. Inner Sun plans the heavy borer for M2; parity adds the unlock
   rules and a second layout per ship. Costs more (art, balance per ship) but answers Stewart's
   "sense of progression" note.
8. **Pursuit shaped like FTL's.** FTL's fleet moves a fixed step per jump, so a sector gives you
   roughly the shortest route plus a similar number of spare jumps; quiet places slow it, some
   events delay or hurry it, and a beacon it covers becomes a hard fight that pays almost nothing
   under periodic heavy fire. Inner Sun's pursuer runs on time and noise (right for a dig game);
   parity is about the slack and the overtaken-node rules, not about switching to jumps.
9. **Deeper events.** FTL's events gate their best choices behind systems, crew or gear, mark quests
   on the map, pay in tiers, and sometimes delay the fleet. Inner Sun already gates choices and can
   push the pursuer back; parity adds map quests and tiered rewards. Writing stays ours (`writer`).
10. **Fire parity.** Fire is FTL's signature crisis. Inner Sun's fire is close in rules; the gaps are
    in tuning (how fast it grows and spreads, how many hands put it out how fast) and in reading it
    at a glance (critic items 25 and 33, Stewart's douse note). Cheap to tune; feel rows matter most.

Note 1: the parts Inner Sun needs from FTL (the kinds, how often they occur, the rule that both
ships suffer alike) are documented; the strengths are Inner Sun's own design anyway, so the missing
strength numbers do not count against it.

Just below the cut: power allocation (11, already close), stacking dodge (12), rivals that scale
(13), difficulty levels (14), and two new verbs that fit the dig well: disruption weapons (15) and
silent running that also hides you from the pursuer (16). Crew skill growth (17) ranks lower only
because it costs more; it makes 3 much better and Stewart may want them together.

## 5. REA ("Reverse Engineer Anything"): not worth installing here (D054)

Checked 2026-10-22 (an agent read the repo, the npm registry entry, the docs and the write-ups; no
install):
- **Real and popular.** https://github.com/morluto/rea (MIT, created 2026-04, pushed daily, very
  high star counts whose authenticity nobody can judge), site https://rea.tools, npm `rea-agents`
  6.7.0 (2026-10-18) from one pseudonymous maintainer, published with provenance. Look-alike repos
  and sites exist; one reportedly shipped a flagged installer.
- **What it is.** A local MCP server and CLI that wraps tools you install yourself: Ghidra (with JDK
  21; Windows support is marked experimental and read-only), IDA (commercial), Hopper (not on
  Windows), JADX, a Chrome-family browser for capture, HAR files. About 200 tools, several MB of
  tool descriptions in the agent's context. Setup edits Claude Code's own config. Its security notes
  say it is not a sandbox.
- **The showcases are single functions** in old binaries (a sound-pan routine checked against the
  original over a few thousand cases; a byte-for-byte match of one compiled section).
- **The method is the valuable part, and it does not need the tool.** The official
  "reconstruction obligation ledgers" doc (stable IDs, a rule for when each line closes) and
  third-party write-ups of the loop (observe, write a behavior-only spec, implement in a separate
  context, test differentially) are what `behavior-ledger.md` and `ftl-difftest-plan.md` adopt:
  tag how each fact was measured, close a row only with a test of the same kind, and prove each test
  can fail with a wrong value.

**Verdict: no.** FTL is a 2012 game whose data is plain XML in a documented archive and whose rules
are written up by the community (sections 2 and 3); it has no network traffic for the browser and
HAR tools to capture; and a disassembler session would put FTL's code in the same context that
writes our game, which is exactly what the firewall avoids. Inner Sun already has the verify half
(deterministic sim, seeded replays, bots, scenario tests, critics). If a single constant ever
proves impossible to watch, the fallback is a one-off, human-run, read-only look that writes down
only the number and the rule, not a standing install.

**Terms, at a high level (not legal advice):** Steam's subscriber agreement forbids reverse
engineering games unless the law allows it; observing play, reading public community docs and
copying no code, art or text is the low-exposure path this plan takes. Subset Games has long
supported data modding.
