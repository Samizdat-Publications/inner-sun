# Specs: M1 step 6 (placeholder sound) and step 7 (bots and balance at scale)

## Step 6: placeholder sound (asset-smith for sounds, builder for the audio code)
- Sounds (OGG, `game/assets/audio/`), every one with a credits line: drill roar loop (a motor plus
  grinding noise), rock grind layers (soft, hard, hard-rock squeal), pocket burst, alarm klaxon, fire
  crackle loop, water rush loop, hull hit, weapon fire per weapon kind, bracing absorb, radio static
  and a squelch, UI clicks, a low rumble for the pursuer. Source: ElevenLabs sound effects if its key
  is available (log the spend), otherwise synthesize procedurally in Python (numpy: filtered noise,
  harmonics, envelopes), which is fine for placeholders. CC0 downloads are allowed with credits.
- Audio code (`game/view/audio/*.gd`): buses Master, SFX, Ambience, Radio (the Radio bus has a
  band-pass and light distortion for TOPSIDE). The drill roar's pitch and the grind layer volumes
  follow the sim (drill bars, speed, mean hardness of what it is cutting, cutting or not); alarms
  follow room hazards; fire and water loops follow the worst room; one-shots follow sim events. The
  view reads the sim only. Headless runs never create audio players.
- The blind critic cannot hear: note sound as N/A in reviews; Stewart judges it at the playtest.

## Step 7: bots and balance at scale (builder-opus for bots, builder for the tooling)
- Bot policies over a full run (all through commands): `cautious` (keeps hull high, buys repairs,
  avoids fights when it can, drills at 2 bars, small detours), `greedy` (detours for every vein,
  drills at 4 bars, takes risky event options), `balanced` (the reasonable middle). Each handles
  every phase: map choice, power allocation per phase (combat: weapons and bracing up, drill down),
  drilling, crew orders in emergencies (or auto), event choices by a policy, store purchases,
  combat targeting and flee.
- `python tools/balance.py --full --runs 1000 --procs 6 --pack` plays whole runs headless from a
  frozen pack (`tools/snapshot.py`), then writes a report to `harness/out/balance/`: win rate per
  bot, death causes, rows and depth reached, run length, resource curves per row (median and
  spread), how often each event, option and outcome fires, fights won and lost, pursuer catches,
  bit breaks, coolant outs. Under 15 minutes for 1,000 runs.
- First tuning pass: aim for `balanced` winning about 15 to 30 percent, `cautious` losing mostly
  late to the pursuer, `greedy` dying more often but richer when it lives, no single death cause
  above about half, every event seen. Log what changed and why in docs/DECISIONS.md.
