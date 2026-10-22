# Spec m2p_economy: upgrade ladders, tiered rewards, rolled stores (parity round 1)

Parity workstream P3, round 1 (PLAN.md section 10, D056). Builder: `builder-opus` (sim rules plus a
store view), in its own worktree off the branch `claude/blissful-neumann-c52d9b`.

## Firewall (read first)
Work from this spec and the ledger rows it names in `docs/research/behavior-ledger.md` only. Do not
open `docs/research/ftl-*.md`, `research_private/` (it does not exist in your worktree anyway), or any
page about another game. If a row is unclear, stop and ask the lead in your report; do not look it up.
No names, text or numbers from any other game go into code, data or comments.

## Rows this round closes
L-UPG-01, L-UPG-02, L-UPG-04, L-RWD-01, L-RWD-02, L-RWD-03, L-RWD-04, L-STO-01, L-STO-02, L-STO-03,
L-STO-04, L-STO-05. Read each row's Behavior, Target, Test and Wrong value in the ledger; the Target
line is the pass band. Not this round (they need the balance tooling and the bots, which another
session is editing): L-UPG-03 and L-RWD-05. Leave their Status as open.

## Files you own (touch nothing else)
- `game/sim/events/store.gd`, `game/sim/events/encounter.gd`, `game/sim/events/event_effects.gd`,
  `game/sim/events/encounter_lint.gd`
- new `game/sim/events/store_roll.gd` (rolling a visit's stock), new `game/sim/run/rewards.gd` (tiers)
- `game/sim/combat/combat_loot.gd`, `game/sim/combat/combat_sim.gd` (only its required-tuning-keys list)
- `game/sim/run/gear.gd` (taking gear off for a sale)
- `game/sim/data/data_db.gd` only if a new table or lint hook needs registering
- data: `game/data/stores/*.json`, `game/data/systems/*.json`, `game/data/gear/*.json`,
  `game/data/weapons/*.json`, `game/data/events/*.json` (payout effects only, never the text),
  `game/data/tuning/combat.json`, new `game/data/tuning/economy.json`
- view: `game/view/overlay/store_view.gd` (and a new helper file under `game/view/overlay/` if it would
  pass 400 lines)
- tests: new `game/tests/test_ledger_economy.gd`, new `game/tests/test_ledger_store.gd`, and the
  existing tests your change breaks: `test_store.gd`, `test_events.gd`, `test_events_effects.gd`,
  `test_data.gd` (tuning-keys list), `test_ui.gd` (store parts), `test_run.gd`, `test_combat*.gd`
- `docs/research/behavior-ledger.md`: only the Status lines of the rows above.

**Do not touch** (another session is splitting or fixing them on main right now):
`game/sim/drill/*`, `game/sim/run/run_state.gd`, `game/sim/ship/ship_world.gd`, `game/bots/**`,
`game/data/tuning/drill.json`, `game/view/main.gd`, `game/view/**/scanner_panel.gd`,
`game/view/**/ship_view.gd`, `game/view/**/crew_sprite.gd`, `game/view/ship/room_fire.gd`,
`game/view/hud/run_screen.gd`, `game/view/hud/alerts_strip.gd`, `tools/balance*.py`. Reading them is
fine. If the work cannot be done without changing one, stop and say why in your report.

## Hard rules (CLAUDE.md)
Sim rules stay in `game/sim` (RefCounted, no Nodes, no Time, no frame delta). Every change to the
world goes through a command (`sim.push`). Randomness only from `sim.rng.get_stream(...)`; stores use
the existing "store" stream, rewards a new "reward" stream; draw a fixed number of values per roll so
one chance never shifts another. Resources move only through `run.add` in exact integers. Strict
typing. Content is data, checked by the lint. No em dash in any data or UI text. Launch Godot only
through `tools/`. Stage explicit paths; never `git add -A`.

## What to build

### 1. Upgrade ladders (L-UPG-01, L-UPG-02, L-UPG-04)
- Each system's data file gets `"bar_prices"`: an array of whole ore prices, where entry i is the
  price of bar i + 1. Its length is the system's top bar count for upgrades (a ship may start above
  it; then the store simply never offers that system). Starting values, chosen to meet the rows
  (change them only if a row's band demands it, and say so):
  - helm `[30, 60, 90, 150]`, bracing `[20, 50, 90, 130, 170, 210]`, weapons `[30, 60, 90, 110, 180]`,
    drill `[20, 40, 60, 80, 100, 170]`, coolant `[20, 40, 60, 80, 130]`,
    reactor `[15, 15, 20, 20, 30, 30, 45, 45, 60, 60, 80, 80, 110, 110]`.
- A store's upgrade line no longer carries `price`, `limit` or `max_bars`: the price of the next unit
  is the ladder entry for the system's current `sys_max` + 1; buying `qty` units costs the sum of the
  next `qty` entries; buying past the ladder's end is refused with a reason ("<system> is at its
  top"). The line the store exposes (see 3) always shows the next unit's price in `"price"`, updated
  after every purchase, so existing readers of `"price"` keep working.
- Lint: ladders are whole numbers above zero; every ladder except the reactor's strictly rises; the
  reactor's never falls.

### 2. Tiered rewards (L-RWD-01 to L-RWD-04)
- New `Rewards` (static, `game/sim/run/rewards.gd`): `base(db, res, row) -> float` and
  `roll(sim, res, tier, row) -> int` (draws from the "reward" stream, a fixed number of draws).
  Tuning in `game/data/tuning/economy.json`, starting values:
  `reward_ore_row1 20`, `reward_ore_per_row 6`, `reward_gems_row1 6`, `reward_gems_per_row 1.5`
  (base = row1 + per_row x (row - 1), with row clamped to at least 1); tier spreads as uniform
  multipliers `tier_low_min 0.55`, `tier_low_max 0.8`, `tier_medium_min 0.8`, `tier_medium_max 1.2`,
  `tier_high_min 1.2`, `tier_high_max 1.7`. Tuning files accept only plain numbers
  (`DataDB._load_tuning`), so every key here is a scalar. Amount = `roundi(base x multiplier)`.
  The row is always `sim.run.current_row()` (0 to 13 on the crust), never the `row` argument of
  `Encounter.start_node`, which is the event-content row (`RunState.event_row`, squeezed onto 10 rows).
  The same holds for the store roll and the hull price steps.
- Fights (`CombatLoot.roll`): one tier draw per fight (medium for a normal won fight), and that one
  multiplier applies to both the ore and the gems base; the gate boss keeps `combat.loot_boss_scale`
  on top. Cells, charges and the weapon roll are unchanged (supplies do not scale). Move the loot
  ore and gems keys out of `combat.json` (delete `loot_ore_*` and `loot_gems_*`) and update the
  required-keys list.
- Events: a new effect `{"type": "reward", "res": "ore" | "gems", "tier": "low" | "medium" | "high"}`
  (in `EventEffects`, the encounter lint, and anything that lists effect types). Convert every
  POSITIVE ore or gems payout in `game/data/events/*.json` (`res` or `res_range` with ore or gems) to
  a `reward`, choosing the tier from the old mean payout against today's fight mean (5.5 ore, 8.5
  gems): under 0.8 of it low, 0.8 to 1.25 medium, above 1.25 high. Negative amounts (costs) stay as
  they are. Leave every other effect and all text untouched.
- Lint rule (L-RWD-04): a positive fixed `res` or `res_range` payout of ore or gems in an event is an
  error ("use a reward tier"). Bots: `game/bots/policy_choices.gd` does not know `reward` yet and you
  must not edit it; the lead adds it after the other session's split lands. The bots will also, until
  then, under-price a two-bar bracing buy (they multiply the shown price) and skip a supply line whose
  stock is below what they want; the sim must refuse such buys cleanly (it does, through
  `EncounterStore.refusal`), nothing more. Note in your report which bot tests, if any, changed outcome.

### 3. Rolled stores (L-STO-01 to L-STO-05)
- Store data v2 (`game/data/stores/<id>.json`): keep `id`, `name`, `blurb`; replace `stock` with
  - `"supplies"`: lines as today (`res` and `hull` items) plus, for `res` lines, `"stock": [lo, hi]`
    (units rolled per visit, L-STO-03: 2 to 6); `hull` lines take `"price_by_row"`:
    `[{"from_row": 0, "price": 2}, {"from_row": 5, "price": 3}, {"from_row": 10, "price": 4}]`
    (L-STO-04: 1.5 to 2.0 times by rows 10 to 13, at most three steps), and no stock limit.
  - `"sections_shown": [lo, hi]` and `"sections"`: `[{"id": "systems" | "gear" | "weapons" | "crew",
    "weight": w, "offers": [lo, hi], "pool": [lines]}]`. Pool lines carry `"rarity"` 1 to 5 and the
    item fields as today (`upgrade` with `system`; `gear` with `gear`; `weapon` with `weapon`; `crew`
    with `pool` and `price`). Gear and weapon prices come from their own data (below) unless the line
    overrides `price`.
  - Crust trader: supplies (coolant, cells, bits, charges, hull); sections systems (weight 3, 3 offers,
    all six systems, rarity 1), gear (weight 2, 2 offers: pumps rarity 1, tungsten head 2, hull plating
    3, diamond head 4), weapons (weight 1, offers [1, 2]: borer turret rarity 1, charge launcher 2,
    thermal lance 2), crew (weight 1, 1 offer); `sections_shown [2, 3]`. Keep the existing line texts;
    write a short plain line for the two new weapon offers in the store's voice.
  - Hollow trader: supplies (coolant, bits, charges, at its higher prices) and a crew section shown
    every time (`sections_shown [1, 1]`).
- Gear data gets `"price"` and `"currency"` (today's store prices: tungsten head 180, diamond head 450,
  hull plating 200, pumps 120, all ore); weapon data gets `"price"` and `"currency"` (thermal lance 70
  gems; borer turret 45 gems; charge launcher 55 gems).
- `StoreRoll` (static, `game/sim/events/store_roll.gd`), called from `Encounter.open_store`: rolls the
  supply stocks, picks the sections (weighted, without replacement; a picked section with no eligible
  offer is replaced by another while any remain), and picks each section's offers weighted by rarity
  and depth, without replacement, never the same item twice in one store. Eligible: an upgrade whose
  system the ship has and is below its ladder top; gear that `Gear.refusal` would allow now; any
  weapon (slots are checked at purchase); the crew hire as today. Rarity weight, scalar tuning keys in
  `economy.json`: `store_rarity_weight_1` to `_5` = 10, 6, 3, 1, 0.5, times
  `1 + store_rarity_depth_gain_<r> x row / (rows - 1)` with `store_rarity_depth_gain_1` to `_5` = 0, 0,
  1, 4, 6 (rows: the layer's row count); tune these only as far as L-STO-02 needs and report the final
  values. (The lead's check: these give the diamond head about 1.86 times as often at rows 10 to 13 as
  at rows 1 to 4, and the systems section, at weight 3, about 83% of visits.)
- The rolled visit is stored on the `Encounter` (lines with their section id, rolled stock and current
  price) and `current_store()` returns `{"id", "name", "blurb", "stock": [those lines]}`, so the
  existing readers of `current_store()["stock"]` (the bots, the view, tests) keep working. Each line
  keeps the fields they read: `item`, `res`, `amount`, `system`, `gear`, `weapon`, `pool`, `price`,
  `currency`, `text`, plus `section`, `stock` (units left, `-1` for unlimited). Include the rolled
  visit in `Encounter.state()` so the state hash covers it.
- Selling (L-STO-05): a new command `{"type": "sell", "what": "weapon" | "gear", "id": <id>}`, valid
  only while a store is open: pays `floor(list price x economy.sell_back_frac)` (start 0.5) through
  `run.add` in the item's currency, removes one such weapon from `ship.weapons` or the gear from
  `run.gear` (recomputing the gear multipliers so the effect is undone exactly). Refused with a reason:
  the last weapon aboard; gear with one-time adds (`max_hull_add`, `hull_add`); an item not owned; gear
  with a drill multiplier (`cut_speed_x`, `wear_x`, `hard_rock_x`) while `sim.drill.active` (a
  mid-dig trader: `DrillSim` reads gear only when a segment begins, and you must not edit it).
  Test the undo across segments: drill speed in a segment begun before the sale and one begun after.
  Check that nothing keyed by weapon index (combat state, power per weapon) is left pointing at a
  removed weapon; a store is never open during a fight.
- Store view (`store_view.gd`): group lines under their section names (Supplies, Systems, Gear,
  Weapons, Crew), show units left on stocked lines and the next-bar price on system lines ("Drill bar
  5 of 6: 100 ore"), and a Sell list of what the ship owns that can be sold, with the sale price and
  a sell button that pushes the `sell` command. Keep the existing look; check it in one gallery still
  (`python tools/gallery.py`, at most two windowed runs in total) and look at the still yourself.

## Tests (each closes its row only with the wrong value failing)
- `game/tests/test_ledger_economy.gd`: `test_l_upg_01`, `test_l_upg_02`, `test_l_upg_04`,
  `test_l_rwd_01`, `test_l_rwd_02`, `test_l_rwd_03`, `test_l_rwd_04`.
- `game/tests/test_ledger_store.gd`: `test_l_sto_01` to `test_l_sto_05`.
- Each test checks the row's Target band, then repeats the check with the row's Wrong value applied
  (an override of the data or tuning in memory, never a file edit) and asserts the check now FAILS.
  Write the band check as a function that returns pass or fail, so the same function judges both.
- The value used for gems in a haul: 6 ore per gem (`economy.gem_ore_value`, so the tests read one key).
- A replay test: the same seed opens the same store twice with identical stock.
- Existing tests: update only what the new rules change (prices, stock format, loot amounts), and say
  which in the report.

## Commands that must pass
- `python tools/check.py` prints `check: ok`.
- `python tools/determinism.py` passes (the hash changes; report the new one; it is re-recorded after a
  rebase, so it is information only).

## Done looks like
Every row above passes its test, each wrong value fails it, `check: ok`, one gallery still of the new
store looked at, and the ledger Status lines of the closed rows set to `passing`. Commit on your branch
with explicit paths and a message without em dashes.

## Report (short)
Rows closed and their measured values (the band check's numbers); final tuning values that differ from
this spec and why; tests changed; bot tests whose outcome moved; the new determinism hash; the still's
path; anything you could not do and why.
