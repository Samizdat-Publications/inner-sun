# Spec m2p_bots_balance: bots that understand the new economy, and the balance measures (parity round 4)

Parity workstream P3, round 4 (PLAN.md section 10, D056, D081). Builder: `builder-opus`, in its own
worktree off the branch `claude/blissful-neumann-c52d9b` after it has merged main (M1d's split).

## Firewall (read first)
Work from this spec and the ledger rows it names in `docs/research/behavior-ledger.md` only. Do not
open `docs/research/ftl-*.md`, `research_private/`, or any page about another game.

## Rows this round closes
L-UPG-03 and L-RWD-05 (balance measures). Read both rows' Target and Wrong value.

## Background (what changed in rounds 1 to 3, on this branch)
Stores roll their stock (`EncounterStore`, `StoreRoll`): supply lines carry a `stock` (units left,
-1 unlimited) and refuse more than that; upgrade lines show the next bar's price in `"price"`, and
buying n bars costs the sum of the next n ladder prices (`bar_prices` in each system's data). Events
pay ore and gems through a new effect `{"type": "reward", "res", "tier"}` (`Rewards`, row-based, three
tiers); fights pay a medium-tier reward. Gear and weapons can be sold (`{"type": "sell", ...}`).
Crew have a station skill and stations a manned bonus (round 3).

## Lead's math check (the Gemini audit was skipped: its credits are used up, 2026-10-22)
From the last balance report (about 1,700 ore and 200 gems gained a run) and the round 1 bases, a
balanced run should now gain about 2,150 ore: fights about 3 x 56 and events about 5 x 56 at a mid
row. Fights plus events then come to about 790 of about 3,500 value (gems x 6), about 23%, inside
L-RWD-05's 15 to 35%; the halved bases give about 12%, out of band as the wrong value needs. For
L-UPG-03, maxing every system costs about 2,100 ore, so bars can plausibly take 40 to 65% of ore spent;
the wrong value (ladders x3) is not certain to leave the band (fewer bars, but gear spending stays),
so if it does not, report it and the lead will choose a stronger wrong value. Files after M1d's
split: `game/bots/policy_choices.gd` still holds `effect_value`, `next_purchase` and
`_can_power_weapon`; the per-run stats are `game/tools/full_run_stats.gd`.

## Files you own
- `game/bots/policy_choices.gd` and, only if needed, `game/bots/policy_bot.gd` (or the file the split
  moved the store or event logic into; read `git log` for the split)
- `game/tools/full_run_stats.gd` (the per-run balance numbers), `tools/balance_full.py` and
  `tools/balance.py` (report lines)
- `game/sim/events/store.gd` (only: add `kind` and `system` to the `"bought"` event, and a public
  cost helper if the bots need the exact cost of n units; emit a `"sold"` event if it is missing)
- `game/data/tuning/economy.json` and the `bar_prices` lines of `game/data/systems/*.json` (only if a
  band needs retuning; say so and why)
- tests: `game/tests/test_bots.gd`, new `game/tests/test_ledger_balance.gd` (unit checks of the new
  stats on a short seeded run), existing tests your change breaks
- `docs/research/behavior-ledger.md` (Status lines of the two rows), a new report
  `docs/research/m1-evidence/balance_parity_r4.md`

## What to build
1. **Bots value rewards.** In `PolicyChoices.effect_value`, a `reward` effect is worth the expected
   amount: `Rewards.base(db, res, sim.run.current_row())` times the tier's mean multiplier, through the
   same `_res_value` the `res` effect uses.
2. **Bots buy what is on the shelf.** In `next_purchase`, clamp every quantity to the line's `stock`
   when it is 0 or more (skip a line with 0), and price an upgrade of n units at the exact sum of the
   next n ladder entries (the cost helper), including in the reserve check. Bots do not sell.
3. **Stats per run** (in `FullRunStats.add_to`, from the event list only):
   - `ore_spent_by` and `gems_spent_by`: totals by line kind (`upgrade`, `gear`, `res`, `hull`,
     `weapon`, `crew`), from the `bought` events; `bars_bought`: upgrade units bought.
   - `gained_by`: ore and gems gained by source: `fight` (the ore and gems in `fight_won`'s loot),
     `event` (positive ore and gems changes while a dossier is open), `sale` (sell-back), and `dig`
     = all positive ore and gems changes minus those three, so nothing is counted twice (drilling,
     crates, the miner, blasts). Name the rule in the doc comment and test that the four add up to
     the total gained.
4. **Report lines** (`balance_full.py`), per bot: `spend_share` = upgrade ore over all ore spent
   (summed over runs), median `bars_bought`, `income_share` = (fight + event) value over all value
   gained, value = ore + 6 x gems (`economy.gem_ore_value`). Show the bands from the two rows beside
   them.
5. **Run it:** `python tools/balance.py --full --runs 900 --procs 6 --pack` (300 runs per bot). If a
   measure is out of band for the balanced bot, retune only `economy.reward_*` (for L-RWD-05) or the
   ladders (for L-UPG-03), re-run, and stop after three tries; then report the measured values.
6. **Wrong values:** each row names one. Run each once with `--runs 300 --bots balanced` and the
   override in a scratch copy of the data (never committed), and confirm the measure leaves its band;
   put both numbers in the report.

## Commands that must pass
`python tools/check.py` prints `check: ok` (full run); `python tools/determinism.py` passes (report the
new hash). Balance runs are headless; no windowed runs.

## Report (short)
The balance table (wins, median rows, the two measures with their bands, the wrong-value runs), any
retuning and why, bot changes, tests changed, the new determinism hash, branch and final commit.
Commit with explicit paths, messages without em dashes, ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not push or merge.
