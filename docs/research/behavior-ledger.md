# Behavior ledger

The rows Inner Sun must satisfy to reach rough parity with FTL's feel on the systems Stewart picks
(D052, D053). Builders work from these rows alone. Every row is written in Inner Sun's own words and
names and carries an Inner Sun target; none holds a number taken from FTL. The evidence behind each
row is kept privately, under its evidence ID, in `research_private/ledger_evidence.md`.

**Builders:** read only the rows your spec assigns. Do not open `docs/research/ftl-*.md`,
`research_private/` or any FTL page. If a row is unclear, ask the lead; do not look it up.

## Row format

Each row is a level-3 heading followed by the same eight fields, in this order, so a parser
(`tools/ledger.py`, to be built in step P3) can read it (a strict format on purpose):

```
### L-<SYS>-<nn>: <one-line claim>
- Kind: number | shape | rule | feel
- Behavior: what a player could observe, in Inner Sun's terms.
- Target: the Inner Sun value or band that passes (our units, our numbers).
- Evidence: E-<SYS>-<nn> (documented | partly | observed | assumed), source kind (wiki, data, mod docs, observation O-xx)
- Test: the test that closes the row: scenario, replay, balance measure, critic still, or Stewart's A/B, with its file and function.
- Wrong value: a tuning change that must make the test fail.
- Core: yes | no (a failing core row blocks "parity" for its system)
- Status: open | passing | failing | waived (Dnnn)
```

- **Kinds.** *number*: one measured value in a band. *shape*: a ratio, an ordering, a curve or a
  distribution (most rows: Inner Sun's scale differs on purpose). *rule*: an if-then that is true
  or false. *feel*: something a viewer sees or a player reports, judged by the critic rubric or by
  Stewart.
- **Targets** are Inner Sun numbers chosen by the observer from the evidence's shape and anchored
  to something in Inner Sun (a current tuning value, another row, the dig's pacing); the target says
  what anchors it. A band, not a point: parity is rough by design. A band must not simply wrap the
  source's own value.
- **Evidence strength.** *documented*: two sources agree or one source quotes the game's data.
  *partly*: one secondary source, or a disputed value. *observed*: measured from FTL footage
  (`ftl-observation-plan.md`). *assumed*: the observer's reading of play experience; such rows are
  re-checked by observation before they turn core.
- **Closing a row.** Only a test of the row's own kind closes it: a scenario test cannot close a
  balance row, and a unit test cannot close a whole-run claim. Each test also runs the wrong value
  and must fail with it.
- **Changing a row.** Targets may move with Stewart's playtests; log the change and its reason in
  `docs/DECISIONS.md`. A deliberate departure from the evidence is `waived (Dnnn)`, not deleted.
- **Coverage.** Per system: passing rows over rows in scope (number, shape and rule rows), plus the
  feel rows' scores. A system is at rough parity at 80% with no failing core row
  (`ftl-difftest-plan.md`).

## Rows (P2, 2026-10-22)

**Scope (D056, 2026-10-22):** Stewart picked inventory 1 to 6, so the L-UPG, L-RWD, L-MAN, L-DOR, L-STO
and L-ENV rows are in scope; L-PUR, L-EVT and L-FIRE stay as format examples (L-FIRE-01 is a
yardstick for L-DOR-02). The economy rows (L-UPG, L-RWD, L-STO) were finalised by the parity session
on 2026-10-22; the rest are finalised before their build round.
Current Inner Sun values are quoted where they exist, so the gap is visible.

### L-UPG-01: Each further bar of a system costs more than the last
- Kind: shape
- Behavior: Buying the next bar of a system always costs more than the bar before it, so taking one system toward its top is a commitment that competes with gear, crew and repairs. Every main system has room for at least two more bars on the light drill, so there is a ladder to climb, not one purchase.
- Target: every system's price ladder except the reactor's (L-UPG-02) (one ore price per bar, in the system's own data) rises strictly bar by bar; on the light drill every system except the reactor can buy at least 2 bars past its starting bars; each step adds 0.4 to 0.9 times the price of the ship's first purchasable step of that system (a straight, steady climb); the first purchasable step costs 0.5 to 1.0 times today's flat price (anchor: helm 120, bracing 140, weapons 160, drill 150, coolant 120 ore). Today: one flat price per system and one bar to buy (bracing two).
- Evidence: E-UPG-01 (documented), game data
- Test: rule test `game/tests/test_ledger_economy.gd::test_l_upg_01` over every system's ladder and the light drill's purchasable steps.
- Wrong value: a flat ladder (every step equal) must fail.
- Core: yes
- Status: open

### L-UPG-02: Reactor bars get dearer in steps
- Kind: shape
- Behavior: The reactor's next bar costs the same for a short run of bars, then steps up, so early power is cheap and late power is a real expense. A reactor bar is cheaper than a system bar, because a bar of power is only worth something once a system can use it.
- Target: the light drill can buy at least 6 reactor bars; prices hold flat in pairs and each pair costs 20 to 50% more than the pair before; the first reactor bar costs 0.4 to 0.8 times the mean first purchasable step of the other systems. Today: 200 ore for one bar, one per store, dearer than any system bar.
- Evidence: E-UPG-02 (documented), wiki
- Test: rule test `test_ledger_economy.gd::test_l_upg_02`.
- Wrong value: every reactor bar at one price must fail.
- Core: no
- Status: open

### L-UPG-03: Upgrades are where most money goes
- Kind: shape
- Behavior: Over a run, buying bars takes the biggest share of the ore the player spends, ahead of gear and repairs, so every store visit is a trade-off between getting stronger and staying alive.
- Target: balanced bot, 300 runs: system and reactor bars take 40 to 65% of all ore spent; median 5 to 10 bars bought per run.
- Evidence: E-UPG-03 (assumed), to observe in O-10 (what Stewart buys in his recorded FTL runs)
- Test: balance measure `spend_share` in `python tools/balance.py` (needs the balance tooling, after M1d's split lands).
- Wrong value: every ladder price x3 must push the share out of band.
- Core: no
- Status: open

### L-UPG-04: The price is the only brake on upgrades
- Kind: rule
- Behavior: A store that offers a system sells as many of its bars as the player can pay for, each at the next price on the ladder, and always shows the price of the next bar; no per-visit cap.
- Target: an offered system line has no per-visit limit; buying n bars at once costs exactly the sum of the next n ladder prices; after a purchase the line shows the next bar's price; a system at the top of its ladder is refused with a reason. Today: one bar per visit (two for bracing).
- Evidence: E-UPG-01 (documented), game data
- Test: rule test `test_ledger_economy.gd::test_l_upg_04`.
- Wrong value: charging n x the first price for n bars must fail.
- Core: yes
- Status: open

### L-RWD-01: A won fight pays more the deeper it is
- Kind: shape
- Behavior: The haul from a won fight grows steadily row by row, so a fight late in the layer is worth taking even when it hurts. A harder difficulty would shift the whole line later, not flatten it.
- Target: mean medium-tier haul value (ore plus gems x 6, D025's exchange of about six ore to a gem) at row 13 is 3 to 5 times row 1, and the mean rises across every band of 3 rows. Today: flat at every row (3 to 8 ore, 5 to 12 gems; the gate fight x3).
- Evidence: E-RWD-01 (documented), wiki tables built on the game's code, a second guide agrees
- Test: rule test on 2,000 seeded loot rolls per row, `test_ledger_economy.gd::test_l_rwd_01` (the run-level balance measure is L-RWD-05).
- Wrong value: the per-row growth set to zero must fail.
- Core: yes
- Status: open

### L-RWD-02: Rewards roll in three overlapping tiers
- Kind: number
- Behavior: Every reward that pays ore or gems is low, medium or high, each a spread around the row's base, and a high roll at one row can beat a medium at the next. Events name a tier instead of a fixed amount.
- Target: over 10,000 seeded rolls per tier: low mean 0.6 to 0.75 of the row base, medium 0.95 to 1.05, high 1.35 to 1.6; the top of low reaches at least the bottom of medium and the top of medium at least the bottom of high.
- Evidence: E-RWD-02 (documented), wiki
- Test: rule test `test_ledger_economy.gd::test_l_rwd_02`.
- Wrong value: one spread for all three tiers must fail.
- Core: no
- Status: open

### L-RWD-03: The first fight is worth about what it is today
- Kind: number
- Behavior: A won fight near the top of the layer pays about what it pays now, so the opening of a run keeps its pace; the growth comes later.
- Target: mean medium-tier haul value (ore plus gems x 6) at row 1 is 45 to 70 (anchor: today's mean, about 56).
- Evidence: E-RWD-03 (assumed), Inner Sun's own anchor; the shape is from E-RWD-01
- Test: rule test `test_ledger_economy.gd::test_l_rwd_03`.
- Wrong value: the row-1 base halved must fail.
- Core: no
- Status: open

### L-RWD-04: Ore and gems from events and fights scale; supplies do not
- Kind: rule
- Behavior: Every event outcome or fight that pays ore or gems pays by tier and row; payouts of coolant, cells, bits and charges stay the same at every depth. Costs the player pays (negative amounts) stay fixed.
- Target: the data lint rejects a positive fixed ore or gems payout in an event outcome (it must be a tier reward); supply payouts are equal at rows 1 and 13 in the loot roll.
- Evidence: E-RWD-01 (documented), wiki
- Test: `DataDB.lint()` rule with `test_ledger_economy.gd::test_l_rwd_04`, and the loot-roll check.
- Wrong value: a fixed `res` payout of ore left in an event must fail the lint; cells scaled by row must fail the loot check.
- Core: yes
- Status: open

### L-RWD-05: Fights and events are a real share of income, the dig still the most
- Kind: shape
- Behavior: Over a run, what fights and events pay matters next to the dig, but digging stays the main income (D024).
- Target: balanced bot, 300 runs: fights plus events earn 15 to 35% of all ore-plus-gems value gained (gems x 6). Today: under 10%.
- Evidence: E-RWD-05 (assumed), Inner Sun's own design (D024) on the shape of E-RWD-01
- Test: balance measure `income_share` in `python tools/balance.py` (after M1d's split lands).
- Wrong value: every reward base halved must push the share out of band.
- Core: no
- Status: open

### L-STO-01: A store rolls a few sections of offers
- Kind: rule
- Behavior: Each store shows its supplies (always) and a few rolled sections (systems, gear, weapons, crew), each holding a few random offers from that category. Two visits to stores rarely look the same. The same seed rolls the same stock.
- Target: a crust trader shows 2 or 3 of its 4 sections; the systems section holds 3 offers (all eligible systems if fewer remain), gear 2, weapons 1 or 2, crew 1; no item twice in one store; systems shown in 55 to 90% of visits; over 1,000 seeded pairs of visits, at least 70% differ in their offers; the same seed and visit give the same stock. The hollow trader keeps its own short character list (supplies and a hire). Today: two fixed lists, the same every visit.
- Evidence: E-STO-01 (documented), wiki and reimplementation notes agree
- Test: rule test over 1,000 seeded store rolls, `test_ledger_store.gd::test_l_sto_01`; a replay check for the same stock.
- Wrong value: a fixed stock list (no roll) must fail.
- Core: yes
- Status: open

### L-STO-02: Rare offers are rarer near the surface
- Kind: shape
- Behavior: Each offer has a rarity; common things show up most visits, rare ones seldom, and rare ones get more common the deeper the store.
- Target: over 1,000 seeded stores per band: the rarest gear (rarity 4 or 5) appears at rows 10 to 13 at least 1.6 times as often as at rows 1 to 4 (a store shows only two gear offers, so frequencies saturate); a rarity-1 offer appears in at least half of the stores whose section rolled.
- Evidence: E-STO-02 (partly), wiki (rarity weights); the depth rise is the reimplementation notes' loot table by region
- Test: rule test `test_ledger_store.gd::test_l_sto_02`.
- Wrong value: rarity ignored (all weights equal) must fail.
- Core: no
- Status: open

### L-STO-03: Supplies are limited on the shelf
- Kind: rule
- Behavior: Coolant, cells, bits and charges are always on sale at a fixed price, but each store has only a few units of each; running short is a matter of what is on the shelf, not only of money.
- Target: each supply line rolls a stock of 2 to 6 units per visit (units as the line sells them); buying more than the stock is refused with a reason; prices stay today's. Today: unlimited.
- Evidence: E-STO-01 (documented), wiki
- Test: rule test `test_ledger_store.gd::test_l_sto_03`.
- Wrong value: an unlimited supply line must fail.
- Core: no
- Status: open

### L-STO-04: Hull repair costs more the deeper you are
- Kind: shape
- Behavior: Welding hull plate is cheap near the surface and dearer deep down, in steps.
- Target: per-point hull repair price at rows 10 to 13 is 1.5 to 2.0 times rows 1 to 4, in at most three steps, never falling. Today: 2 ore a point at every row.
- Evidence: E-STO-01 (documented), wiki
- Test: rule test `test_ledger_store.gd::test_l_sto_04`.
- Wrong value: one price at every row must fail.
- Core: no
- Status: open

### L-STO-05: Gear and weapons sell back for part of their price
- Kind: rule
- Behavior: At any store the player can sell a weapon or a piece of gear back for part of its list price. The last weapon aboard cannot be sold, and gear that was bolted on whole (hull plating) cannot come off.
- Target: sell-back pays 33 to 50% of the item's list price, rounded down, in the item's own currency; selling removes the item and its effect exactly (a sold drill head gives back the drill's old speed); selling the last weapon or hull plating is refused with a reason; a sale is a command in the replay. Today: no selling.
- Evidence: E-STO-01 (documented), wiki
- Test: rule test `test_ledger_store.gd::test_l_sto_05`.
- Wrong value: sell-back at the full price must fail.
- Core: no
- Status: open

### L-PUR-01: The pursuer leaves room for about one more route's worth of digging
- Kind: shape
- Behavior: A straight dive to the gate leaves a comfortable margin; a player can spend roughly as long again on detours and digging before the pursuer reaches the gate row; lingering longer means meeting it.
- Target: for a no-detour descent bot, the pursuer reaches the gate row at 1.6 to 2.4 times the bot's own arrival time (median over 100 seeds).
- Evidence: E-PUR-01 (partly), reimplementation notes and wiki; the ratio is derived from the map geometry
- Test: balance measure with a new straight-descent bot, `python tools/balance.py --bot straight`.
- Wrong value: pursuer speed x2 must fail.
- Core: yes
- Status: open

### L-PUR-02: Where the pursuer has been, nothing is worth taking
- Kind: rule
- Behavior: A node the pursuer has passed holds a fight against a strong rival that pays almost nothing, and heavy strikes from the dark land on a steady rhythm, each announced by a warning, until the ship leaves. Leaving at once is the right play.
- Target: the haul there is under 10% of a normal fight at that row; the first strike comes after a warning, then repeats at two to four times today's catch-strike interval (today: a strike every 10 s once caught, during the segment).
- Evidence: E-PUR-02 (documented), wiki and a guide agree
- Test: scenario `ledger_pursuit` (a node marked overtaken), `test_ledger_pursuit.gd::test_l_pur_02`.
- Wrong value: a normal haul at an overtaken node must fail.
- Core: no
- Status: open

### L-EVT-01: A requirement-gated choice is never worse than the plain ones
- Kind: rule
- Behavior: When a choice appears only because the ship has a system level, a crew skill or an item, it is at least as good as the best ordinary choice and never risks a crew member's life.
- Target: for every gated option in `game/data/events`, its worst outcome is no worse than the best plain option's expected outcome, and no outcome kills crew.
- Evidence: E-EVT-01 (documented), wiki
- Test: a rule in `DataDB.lint()` with a test in `test_data.gd`.
- Wrong value: a gated option with a crew death must fail the lint.
- Core: no
- Status: open

### L-MAN-01: A crewed station does more, and more again with skill
- Kind: shape
- Behavior: Every powered station works better with a crew member at it: the drill cuts faster, weapons charge faster, bracing recharges faster, the helm dodges more. The bonus is modest at a raw recruit's skill and roughly doubles at the top skill, so who stands where is a small constant decision.
- Target: at base skill, a manned station is 12 to 20% better than unmanned (anchored on today's drill and weapons bonus, which stays in band); a manned helm adds about half of one helm bar's dodge on top of what power gives; at the top skill the bonus is 1.5 to 2 times the base one (Inner Sun's skill multipliers span about two to one). Today: drill and weapons +15% flat, the helm needs a crew member but adds nothing, bracing and coolant ignore crew, skill does not count.
- Evidence: E-MAN-01 (documented), wiki
- Test: scenario `ledger_manning`: 600 ticks per station with and without crew, at two skills, `test_ledger_crew.gd::test_l_man_01`.
- Wrong value: every manned bonus at zero must fail.
- Core: yes
- Status: open

### L-DOR-01: Closed doors hold hazards back, and the player works them
- Kind: rule
- Behavior: The player opens or closes any door or hatch with one click, paused or not. A closed door stops water, slows heat, and fire crosses it far more slowly than an open one; a reinforced door (an upgrade) holds fire many times longer. Crew pass through closed doors as they walk.
- Target: a closed door passes fire at 30 to 50% of the open-door rate (between open and Inner Sun's wall rate, `fire.spread_wall_factor`), a reinforced door no faster than a wall; the toggle works paused. Today: the sim honours closed links for water, heat and fire, but nothing lets the player close one; a closed door already passes fire at exactly the wall rate, and every pair of neighbouring rooms also spreads fire through their shared wall in parallel (`HazardSim`, `Ship._find_walls`), so this row needs its own closed-door factor and a wall path that does not bypass a door (Gemini audit, checked).
- Evidence: E-DOR-01 (documented), wiki and reimplementation notes agree
- Test: scenario `ledger_doors` (`test_ledger_doors.gd::test_l_dor_01`) and the real-input self-test for the toggle.
- Wrong value: closed-door fire spread equal to open must fail.
- Core: yes
- Status: open

### L-DOR-02: Purging a room kills its fire, at a price
- Kind: rule
- Behavior: Inner Sun's take on venting (heat is our air). Opening a room's purge to the rock puts its fire out within seconds; while the purge stays open the room fills with rock heat (and, deeper down, gas), hurting any crew inside; closing it lets coolant win the room back. A fire with burning neighbours takes longer to die.
- Target: a full fire alone in a purged room is out in under half the time two crew need (L-FIRE-01), about twice that with burning neighbours; at a row where the rock is at least 8 C above crew-harm heat (`crew.heat_safe_c`; row 9 or deeper with today's layer data, since above about row 4 the rock is cooler than that threshold), the purged room reaches crew-harm heat in 10 to 20 s. Needs a design decision (a D-number) when picked.
- Evidence: E-DOR-02 (assumed), wiki for venting; the heat translation is Inner Sun's
- Test: scenario `ledger_purge`, `test_ledger_doors.gd::test_l_dor_02`.
- Wrong value: purge that leaves the fire burning must fail.
- Core: no
- Status: open

### L-FIRE-01: One pair of hands barely keeps up with a spreading fire
- Kind: shape
- Behavior: One crew member at base skill needs about as long to put out a fully burning room as the fire takes to cross an open door into the next room; each extra hand adds about the same again, so two crew comfortably beat it and closed doors buy the time a lone firefighter needs.
- Target: time for one base-skill crew to put out a full fire in a 4 x 3 m room, divided by the time fire takes to cross an open door: 0.7 to 1.5; two crew take 0.4 to 0.6 of one crew's time. Today (Gemini audit, checked): about 0.33 (one crew about 11 s, unfought spread across an open door about 33 s), so meeting it means slower firefighting or faster spread; two crew about 0.46.
- Evidence: E-FIRE-01 (documented), reimplementation notes cited by the wiki
- Test: scenario `ledger_fire` (`test_ledger_fire.gd::test_l_fire_01`).
- Wrong value: crew firefighting rate x3 must fail the first clause; letting only one crew member fight a room's fire must fail the second.
- Core: yes
- Status: open

### L-FIRE-F1: A new fire reads at a glance
- Kind: feel
- Behavior: Within two seconds of a fire starting, a viewer can tell which room is burning and roughly how badly from a still at normal zoom, without reading any text.
- Target: critic rubric 4 of 5 or better on three stills from `python tools/shots.py --names fire`; Stewart's A/B answer to "as readable?" 4 or better.
- Evidence: E-FIRE-F1 (assumed), to observe in O-01
- Test: critic still with the rubric; Stewart's A/B.
- Wrong value: fire visuals switched off must score under 3.
- Core: no
- Status: open

### L-ENV-01: Some nodes sit in an environment that changes everything there
- Kind: rule
- Behavior: Some fight and hazard nodes carry an environment shown on the map before the player chooses: a rockfall seam (random rooms take falling-rock hits that bracing soaks), magma heat (heat pours into both hulls), magnetite (the scanner goes blind: no survey, no view of the rival's rooms), a gas seam (fires start more easily). It acts on the segment into the node and on any fight there, for both ships alike.
- Target: 20 to 35% of fight and hazard nodes carry one; always visible on the map; each environment affects both sides in a scenario test.
- Evidence: E-ENV-01 (documented), wiki for the kinds, game data for how often
- Test: map rule test over 1,000 seeds and one scenario per environment, `test_ledger_env.gd`.
- Wrong value: an environment that hits only the player must fail.
- Core: no
- Status: open
