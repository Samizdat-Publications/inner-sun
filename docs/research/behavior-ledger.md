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

## Example rows (2026-10-22, proposed, for the top of the inventory)

These show the format on the systems that rank highest in `ftl-reference.md`. They are proposals:
none is in scope until Stewart picks its system, and targets get their final values in step P2.
Current Inner Sun values are quoted where they exist, so the gap is visible.

### L-UPG-01: Each further bar of a system costs more than the last
- Kind: shape
- Behavior: Buying the next bar of a system always costs more than the bar before it, so taking one system toward its top is an expensive commitment that competes with gear, crew and repairs. Short systems roughly double from their first upgrade to their last; longer ones climb steadily to several times their first price.
- Target: for every upgradeable system, price(next bar) is greater than price(previous bar); the top bar costs 3 to 6 times the first upgrade on systems of 4 or more bars, 1.6 to 2.2 times on 3-bar systems. Today: one flat price per system (helm 120, bracing 140, weapons 160, drill 150, coolant 120 ore).
- Evidence: E-UPG-01 (documented), game data
- Test: rule test `game/tests/test_ledger_economy.gd::test_l_upg_01` over every system's price table.
- Wrong value: a flat price table (every step equal) must fail.
- Core: yes
- Status: open

### L-UPG-02: Reactor bars get dearer in steps
- Kind: shape
- Behavior: The reactor's next bar costs the same for a short run of bars, then steps up, so early power is cheap and late power is a real expense.
- Target: reactor bar prices hold flat for 2 bars, then rise by a third to a half per step (steeper than a long reactor would need, because Inner Sun's reactor grows by only four bars). Today: 200 ore for one bar, one per store.
- Evidence: E-UPG-02 (documented), wiki
- Test: rule test `test_ledger_economy.gd::test_l_upg_02`.
- Wrong value: every reactor bar at one price must fail.
- Core: no
- Status: open

### L-UPG-03: Upgrades are where most money goes
- Kind: shape
- Behavior: Over a run, buying bars takes the biggest share of what the player spends, ahead of gear, supplies and repairs, so every store visit is a trade-off between getting stronger and staying alive.
- Target: balanced bot, 300 runs: upgrades 40 to 60% of all ore and gems spent by the gate row; median 6 to 10 bars bought per run.
- Evidence: E-UPG-03 (assumed), to observe in O-10 (what Stewart buys in his recorded FTL runs)
- Test: balance measure `spend_share` in `python tools/balance.py`.
- Wrong value: upgrade prices x3 must push the share out of band.
- Core: no
- Status: open

### L-RWD-01: A won fight pays more the deeper it is
- Kind: shape
- Behavior: The haul from a won fight grows steadily row by row, so a fight late in the layer is worth taking even when it hurts. A harder difficulty would shift the whole line later, not flatten it.
- Target: mean fight haul (ore plus gems at store value) at row 13 is 3 to 5 times row 1, and rises with every 3-row band. Today: flat at every row (3 to 8 ore, 5 to 12 gems; the gate fight x3).
- Evidence: E-RWD-01 (documented), wiki tables built on the game's code, a second guide agrees
- Test: balance measure `fight_haul_by_row` (300 balanced runs) and a rule test on the loot roll per row.
- Wrong value: loot ranges equal at every row must fail.
- Core: yes
- Status: open

### L-RWD-02: Rewards roll in three overlapping tiers
- Kind: number
- Behavior: Every reward (a fight, an event outcome, a crate) is low, medium or high, each a spread around the row's base, and a high roll at one row can beat a medium at the next. Events name a tier instead of a fixed amount.
- Target: low about two thirds of the row base (mean 0.6 to 0.75), medium at the base (0.95 to 1.05), high about one and a half times (1.4 to 1.6); each tier's spread is wide enough that its top reaches the bottom of the next.
- Evidence: E-RWD-02 (documented), wiki
- Test: rule test on 10,000 seeded rolls per tier, `test_ledger_economy.gd::test_l_rwd_02`.
- Wrong value: a single tier for everything must fail.
- Core: no
- Status: open

### L-STO-01: A store rolls a few sections of offers
- Kind: rule
- Behavior: Each store shows a few sections (gear, weapons, systems, crew), each with a few random offers from that category, weighted by rarity and depth, never the same item twice in one store. Supplies and hull repair are always sold; the price of hull repair rises with depth in steps. Gear can be sold back for part of its price.
- Target: 2 or 3 sections of 3 or 4 offers (Inner Sun has fewer item kinds, so fewer, fuller sections); no duplicates; supplies and repair always present; hull repair per point at rows 10 to 14 costs as many times rows 1 to 4 as the rock there is richer (D025's depth richness, about 1.5 to 2); sell-back a third to a half of the price. The same seed rolls the same stock.
- Evidence: E-STO-01 (documented), wiki and reimplementation notes agree
- Test: rule test over 1,000 seeded store rolls, `test_ledger_store.gd::test_l_sto_01`; a replay check for the same stock.
- Wrong value: a fixed stock list must fail.
- Core: yes
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
- Target: a closed door passes fire at 30 to 50% of the open-door rate (between open and Inner Sun's wall rate, `fire.spread_wall_factor`), a reinforced door no faster than a wall; the toggle works paused. Today: the sim honours closed links for water, heat and fire, but nothing lets the player close one.
- Evidence: E-DOR-01 (documented), wiki and reimplementation notes agree
- Test: scenario `ledger_doors` (`test_ledger_doors.gd::test_l_dor_01`) and the real-input self-test for the toggle.
- Wrong value: closed-door fire spread equal to open must fail.
- Core: yes
- Status: open

### L-DOR-02: Purging a room kills its fire, at a price
- Kind: rule
- Behavior: Inner Sun's take on venting (heat is our air). Opening a room's purge to the rock puts its fire out within seconds; while the purge stays open the room fills with rock heat (and, deeper down, gas), hurting any crew inside; closing it lets coolant win the room back. A fire with burning neighbours takes longer to die.
- Target: a full fire alone in a purged room is out in under half the time two crew need (L-FIRE-01), about twice that with burning neighbours; at row 7 rock temperature the purged room reaches crew-harm heat (`crew.heat_safe_c`) in 10 to 20 s. Needs a design decision (a D-number) when picked.
- Evidence: E-DOR-02 (assumed), wiki for venting; the heat translation is Inner Sun's
- Test: scenario `ledger_purge`, `test_ledger_doors.gd::test_l_dor_02`.
- Wrong value: purge that leaves the fire burning must fail.
- Core: no
- Status: open

### L-FIRE-01: One pair of hands barely keeps up with a spreading fire
- Kind: shape
- Behavior: One crew member at base skill needs about as long to put out a fully burning room as the fire takes to cross an open door into the next room; each extra hand adds about the same again, so two crew comfortably beat it and closed doors buy the time a lone firefighter needs.
- Target: time for one base-skill crew to put out a full fire in a 4 x 3 m room, divided by the time fire takes to cross an open door: 0.7 to 1.5; two crew take 0.4 to 0.6 of one crew's time.
- Evidence: E-FIRE-01 (documented), reimplementation notes cited by the wiki
- Test: scenario `ledger_fire` (`test_ledger_fire.gd::test_l_fire_01`).
- Wrong value: crew firefighting rate x3 must fail.
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
