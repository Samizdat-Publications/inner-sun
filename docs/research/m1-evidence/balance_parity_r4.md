# Balance, parity round 4: bots in the new economy, L-UPG-03 and L-RWD-05

Spec: `docs/plans/specs/m2p_bots_balance.md`. All runs are headless, from frozen packs, seeds
1000..1299 per bot (`python tools/balance.py --full ... --pack`). Another Godot was running during
every batch, so wall times are untrusted; results are not affected (the balanced bot gave identical
numbers in two separate batches on the same data).

## The measures

- `spend_share` (L-UPG-03): upgrade ore over all ore spent in stores, summed over the runs. Band 40
  to 65%, median bars bought 5 to 10.
- `income_share` (L-RWD-05): fight plus event value over all ore-plus-gems value gained, value =
  ore + 6 x gems (`economy.gem_ore_value`), summed over the runs. Band 15 to 35%.
- Sources of gains (`FullRunStats.gained_by`): fight = the loot in `fight_won`; event = positive ore
  and gems changes applied by a dossier choice; sale = `sold` payments; dig = everything else
  (drilling, crates, the miner, blasts). The four add up to all ore and gems gained, exactly
  (`test_ledger_balance.gd`).

## Final table (ladders x0.8, 900 runs, 300 per bot)

| bot | won % | median rows | fights/run | gate won % | spend_share % | median bars | income_share % |
|---|---|---|---|---|---|---|---|
| cautious | 42.7 | 13 | 2.84 | 62 | 57.5 | 6 | 25.5 |
| greedy | 9.0 | 10 | 2.07 | 60 | 62.9 | 6 | 13.4 |
| balanced | 51.7 | 13 | 2.86 | 81 | 63.7 | 8 | 24.2 |

Per balanced run: ore spent on upgrades 682, gear 368, hull 21 (no ore on supplies, weapons or crew,
which cost gems); value gained from fights 671, events 136, sales 0 (bots never sell), dig 2524.
The bands apply to the balanced bot; the greedy bot's low income share comes from taking fewer
fights and digging harder.

## Retuning (L-UPG-03)

| try | ladders | balanced spend_share % | median bars | income_share % | won % |
|---|---|---|---|---|---|
| 0 | round 1 ladders | 65.8 (out) | 7 | 24.3 | 52.7 |
| 1 | every bar_prices entry x0.8, whole ore | 63.7 (in) | 8 | 24.2 | 51.7 |

Why the ladders and why down: the balanced bot ends runs with a median of about 600 ore unspent, so
its upgrade spending is limited by what stores offer, not by money; cheaper bars therefore lower
the upgrade share (the bot buys a bar more, median 7 to 8). An exact x0.8 keeps every ladder's
shape, so L-UPG-01, L-UPG-02 (reactor pairs 20 to 50% apart) and L-UPG-04 still pass; rounding to 5
broke the reactor pairs and was dropped. The margin is thin (1.3 points under the band's top): watch
it when stores or bot priorities change. No reward tuning was needed (L-RWD-05 was in band at
try 0).

New ladders: bracing 16, 40, 72, 104, 136, 168; coolant 16, 32, 48, 64, 104; drill 16, 32, 48, 64,
80, 136; helm 24, 48, 72, 120; reactor 12, 12, 16, 16, 24, 24, 36, 36, 48, 48, 64, 64, 88, 88;
weapons 24, 48, 72, 88, 144.

## Wrong values (balanced bot, 300 runs, scratch packs, never committed)

| row | wrong value | spend_share % | median bars | income_share % | won % | verdict |
|---|---|---|---|---|---|---|
| L-UPG-03 | every ladder price x3 | 63.7 (in) | 3 (out) | 23.1 | 44.7 | share stays in band; only the bars part fails |
| L-RWD-05 | every reward base halved | 63.5 | 7 | 12.9 (out) | 51.3 | out of band, as required |

L-UPG-03's wrong value does not move the share out of band, as the lead's math check warned: dearer
bars mean fewer bars, but gear spending falls too, so the share barely changes. It does break the
row's second number (median bars 3, under 5). The lead chooses whether that counts or picks a
stronger wrong value.

## Determinism

`python tools/determinism.py`: ok, hash 84b72d0b949b6d7b at tick 1200 (headless and Movie Maker).
