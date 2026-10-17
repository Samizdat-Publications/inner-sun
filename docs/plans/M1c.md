# M1c: every system has a job in the dig (Stewart's build 3 notes, D034)

Source: `docs/STEWART_FEEDBACK.md` (2026-10-16, build 3). He reached row 8, called it "amazing so
far" and the combat "very FTL", but: the dig is "picking a spot based on the radar and going straight
down", he could not see what helm and bracing do, and he wants "more things to manage so it feels
less on rails", things to find in the rock (Terraria-like underground places) and something to keep
when he dies.

Goal: every drilling segment asks for decisions made with the ship's systems: where to cut (down or
sideways), what to risk (fault rock, gas, water), what to spend (charges, coolant, bits) and what to
break into. Plus a reason to come back after a death. Done when Stewart plays build 4 and says the
dig has more going on.

## The design principle: every powered system matters while drilling
| System | In the dig (new in bold) | In a fight |
|---|---|---|
| Drill | speed, heat, noise, bit wear | nothing |
| Helm (manned) | turn rate, **sideways cutting speed** | evasion |
| Bracing | **layers soak rockfalls in fault rock** | layers soak hits |
| Coolant and pumps | cools rooms, pumps water, **douses a fire on order (1 coolant)** | the same |
| Weapons | **the charge launcher blasts rock at range (1 charge)** | guns |

The reactor never powers everything, so a pivot to a vein (helm and drill up) or a push through fault
rock (bracing up) is paid for by another system. That is the "take from other systems" choice
Stewart asked for.

## Round A: quick fixes (view only, the lead)
- [x] A loud notice and alert when the drill has no power ("DRILL HAS NO POWER: press R"), when the
      bit is broken ("BIT BROKEN: press B", or no spares), while a bit is fitted, when the drill
      overheated or is wrecked.
- [x] Help says what each system does in the dig and in a fight, what coolant is, and that repairs
      do not speed up when the drill slows.

## Round B: dig verbs (spec `specs/m1c_dig_verbs.md`: sim and bots by builder-opus, then the view)
- [x] Heading to +-90 degrees (90 = hold depth, cutting sideways along a vein). Turn rate and the
      sideways share of the speed scale with helm bars when the helm is manned.
- [x] Fault rock (a new unstable material): cutting it builds strain; rockfalls hit the ship; a
      bracing layer soaks each one, otherwise hull and the top room take damage.
- [x] Blast: the charge launcher fires a charge into the rock while drilling (weapons powered, one
      charge): clears a radius, pays the ore and gems, ignites gas away from the ship, drains water
      pockets, very loud.
- [x] Douse: vent coolant into a burning room (one coolant unit, the coolant system powered).
- [x] Policy bots use the verbs; 300 runs per bot; tune (D035 to D039: balanced still about 38%, kept).
- [x] View: A and D step the heading, S straight down, a HOLD DEPTH readout, side sparks, fault rock
      and rockfalls drawn, blast aiming (F2 while drilling, then click the rock or the scanner), a
      douse button on burning rooms (F douses the worst fire), power-row hints.
- [~] Judged with stills and the Gemini critic (006: 4.5, noisy; the rock fixed in D045). Hands-on play
      was not possible (computer-use access declined): Stewart's build 4 run is the hands-on test.

## Round D: something to keep (spec `specs/m1c_meta.md`, builder, in parallel with round B)
- [x] Requisition points earned per run (rows reached, new codex entries, fights won, the gate, ore
      mined), banked in the profile, shown on the death screen.
- [x] A requisitions screen buying permanent starting upgrades (spare bits, charges, coolant,
      plating, the tungsten head, a fourth crew member). Unlocks go into the replay header.

## Round C: things in the rock (spec `specs/m1c_structures.md`, after round B merges)
- [x] Buried structures with interiors: old mine works (timber, fault rock, crates), a Soviet rig
      wreck (steel plates, salvage, a tape), a crystal hollow (a cavern lined with gems, now and then
      a hermit trader). Agartha-style hollows and towns grow from this in M2.
- [x] Breaking in: a banner, a TOPSIDE line, a codex entry; loot cells pay resources; a trader hollow
      opens the store mid-segment.
- [x] Surveys and the map show structures; the scanner and the rock view draw them.

## Round E: the away miner (spec `specs/m1d_away_miner.md`, D046 to D048)
- [x] G sends the selected crew member to dig a vein by hand within 12 m (sim 3be827f, view a1337c1):
      the drill parks until they are back (no separate park key), full yield, quiet; gas, water and
      fault rock hurt them; the haul pays only on return and is lost if they die; G recalls. Bots use
      it (balanced 1.2 sorties a run, wins 38%, no miner deaths in 900 runs).

## Then
- [x] Playtest build 5 (`m1c-playtest-5`): the away miner, the requisitions toast, the rock tile
      repeat broken, the crystal hollow lit, the blast ring and map fixes.
- [x] Playtest build 4 exported (`m1c-playtest-4`, from e1ffb36, the one the critics saw); Stewart plays
      `m1c-playtest-4b` (the same plus the stop-notice fix of e110a40). Not done: the requisitions toast at the
      start of a dive; the map structure marks were never seen in a still.

Playtest build 4, the Gemini critic, a hands-on run by the lead, the making-of page, Stewart plays.

## Answers to Stewart's questions (for the summary and the help page)
- Helm: needs a crew member at the bridge station. While drilling it sets how fast the drill turns
  (and from round B how fast it cuts sideways); in a fight it gives evasion (each bar about 6%).
- Bracing: every two bars hold one layer that soaks a hit, recharging in 6 s. Until round B it did
  nothing while drilling, which is why he could not see it.
- Coolant: the fluid the COOLANT AND PUMPS system spends to chill rooms (one unit per 1.8 MJ of heat
  removed); with power it also runs the bilge pumps. It does not put fires out (crew do), but it
  keeps rooms from getting hot enough to catch fire. Pumps (store gear) drain water faster. Round B
  adds douse: spend a unit to knock a fire down.
- Repairs: crew repair at their own speed whatever the drill does; slowing the drill only cuts heat
  (fewer fires) and noise.
