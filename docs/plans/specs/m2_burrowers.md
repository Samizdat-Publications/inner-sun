# Spec: burrowers (the first M2 creature; design ready, dispatch after M1d triage agrees)

Part 1 (sim, data, bots, tests) for a `builder-opus`; part 2 (view) for a `builder` after it merges.
Design by the lead, 2026-10-17, from PLAN.md M2 ("burrowers that latch onto the hull") and Stewart's
"more things to manage so it feels less on rails" during the dig.

## The fantasy
Something in the rock hears the drill. A burrower is a pale, eyeless thing the size of a dog that
tunnels to the tower, clamps onto the hull outside one room and starts chewing through. You hear it
before you see it (the scanner shows it coming), and you have choices: send crew to that room to beat
it off through the wall ports, let bracing take the bites while you finish the dig, or run the drill
hot so the shaking throws it off. Each answer costs something else, so it is a power and crew puzzle
inside the dig, not a fight screen.

## Rules (sim)
- **Data** `game/data/creatures/burrower.json` (a new table, linted): hp, chew rate, approach speed,
  what attracts it (noise weight, depth range, rock kinds it lives in: fault rock and near hollows),
  loot (a burrower sac: research, and a codex entry `creature` on the first kill).
- **Spawning** while drilling: a per-segment chance from the layer data plus the segment's noise,
  rolled on a stream `"creature/burrower"`; at most two latched at once. A spawn starts as a contact
  on the scanner `approach_s` (about 8 s) out, moving toward the hull: blasting it in the rock kills
  it before it arrives (the blast verb gets a second job).
- **Latched**: on arrival it picks the hull room nearest its approach side (outer rooms only), emits
  "burrower_latched" {room}, and chews: every `chew_s` it takes one bracing layer if any
  (Systems.absorb_hit, the existing event), otherwise `chew_bars` of system damage to that room
  (Systems.damage_room); after `breach_after` unblocked chews it opens a small breach (water) in that
  room.
- **Repel**: each crew member in that room (not away, alive) deals `repel_dps` scaled by
  skill_repair; when its hp reaches 0 it drops off dead (loot, codex). Crew already handle fires
  there, so it competes for the same hands.
- **Shake off**: while the drill runs at its top power bar and speed above `shake_speed`, each latched
  burrower has `shake_chance_s` per second of falling off (alive, it may come back), at the cost of
  the drill's heat and noise.
- **Miner**: a burrower near an away miner attacks the miner instead (hp hits); the miner flees home.
- Determinism, integers where resources move, everything through commands (the player's only new
  command is none: crew assign, power and blasts already exist).

## Bots
Repel with the crew member nearest the latched room when no fire needs them; otherwise shake off if
heat allows. Balance: 300 runs per bot before and after; deaths from burrowers should be rare (they
grind systems and drain bracing; they rarely kill on their own); report wins and medians.

## View (part 2)
On the scanner: approaching contacts as pale ticks with a range ring. In the world: a burrower
sprite (asset-smith: a painted sprite with a 4-frame chew loop, CC0 or generated and logged) clamped
to the hull outside the room, chips flying, the room's wall shaking; inside the room a crack glow
where it chews. Crew in the room play a "strike" pose at the wall. Alerts: "BURROWER ON THE <ROOM>:
send crew, or run the drill hot". Help paragraph. Radio lines (writer): first contact, first kill.

## Done means
Check ok, determinism ok, balance report, stills of an approach, a latched chew with crew repelling,
and a shake-off; a scenario `burrower_demo`. Stewart plays it.
