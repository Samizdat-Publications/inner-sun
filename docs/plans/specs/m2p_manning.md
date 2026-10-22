# Spec m2p_manning: manned stations with a station skill (parity round 3)

Parity workstream P3, round 3 (PLAN.md section 10, D056). Builder: `builder-opus`, in its own
worktree off the branch `claude/blissful-neumann-c52d9b`. Sim and data only; the crew card that shows
the skill comes in a later view round.

## Firewall (read first)
Work from this spec and the ledger rows it names in `docs/research/behavior-ledger.md` only. Do not
open `docs/research/ftl-*.md`, `research_private/`, or any page about another game. If a row is unclear,
say so in your report; do not look it up.

## Rows this round closes
L-MAN-01, L-MAN-02, L-MAN-03 (its data clause; the crew-card clause waits for the view round, so set
its Status to `passing (data; card pending)`).

## Files you own (touch nothing else)
- `game/sim/systems/systems.gd` (the manning bonus: `_bonus`, `is_manned` or a new helper,
  `evasion`, the bracing recharge), `game/sim/systems/systems_lint.gd`
- `game/sim/crew/crew_member.gd` (a `skill_station` field), `game/sim/ship/ship.gd` (only the lines
  that read a crew member's `skills`)
- `game/sim/events/event_effects.gd`: ONLY the `SKILLS` constant (add `"station"`), nothing else in
  that file (another builder is editing the rest of it right now)
- data: `game/data/systems/*.json` (only the `manned_bonus` line and one new key for the helm; another
  builder is adding a `bar_prices` line to the same files, so keep your change to those lines),
  `game/data/ships/light_drill.json` (only the crew `skills`), `game/data/crew/survivors.json` (only
  `skills`), `game/data/tuning/systems.json` if a key is needed, `game/tests/test_data.gd` (its
  tuning-keys list only)
- new `game/data/scenarios/ledger_manning.json`, new `game/tests/test_ledger_crew.gd`; existing tests
  your change breaks (`test_systems.gd`, `test_crew.gd`, `test_combat*.gd`, `test_drill.gd`): update
  only what the new rules change
- `docs/research/behavior-ledger.md`: only the Status lines of the three rows.

**Do not touch:** `game/sim/drill/*`, `game/sim/run/run_state.gd`, `game/sim/ship/ship_world.gd`,
`game/bots/**`, `game/data/tuning/drill.json`, everything under `game/view/`, `tools/balance*.py`
(another session is splitting them on main); `game/sim/hazards/*`, `game/sim/core/sim.gd`,
`game/sim/events/*` except the one constant, `game/sim/combat/combat_loot.gd`, `game/sim/run/gear.gd`
and the store, gear, weapon, event and economy data (two other builders are on them now). Reading is
fine. If the drill or combat code reads the manning bonus in a way you cannot change from
`systems.gd`, stop and say so.

## Hard rules (CLAUDE.md)
Sim rules in `game/sim` only; every change through a command; randomness only from named streams;
strict typing; content is data, checked by the lint; no em dash in any text. Launch Godot only through
`tools/`. Stage explicit paths; never `git add -A`.

## What to build
- **Station skill.** `CrewMember.skill_station` (default 1.0), read from `skills.station` in ship and
  hire data (`ship.add_crew` already passes the `skills` dict for hires). Lint: above zero, like the
  other skills.
- **One operator (L-MAN-02).** A station's operator is the crew member in that room who counts as
  manning it today (`Systems.is_manned`: alive, not away, not climbing, standing with no other job, at
  the end of their path). With several, the one with the highest `skill_station` (ties: lowest crew
  index). Nothing adds up per crew member.
- **The bonus (L-MAN-01).** For drill, weapons and bracing: multiplier `1 + manned_bonus x
  skill_scale(skill)`, where `skill_scale(1.0) = 1` and `skill_scale(2.0)` is in 1.5 to 2.0. Start with
  `skill_scale(s) = 1 + systems.station_skill_gain x (s - 1)` clamped to at least 0, gain 0.75 (so 2.0
  gives 1.75). `manned_bonus`: drill 0.15 and weapons 0.15 (today), bracing 0.15 (new: the layer
  recharge time is divided by the multiplier). Keep the drill and weapons readers working as today
  (they read `drill_bonus` and `weapon_bonus`); find where the bracing recharge counts ticks and apply
  the multiplier there, in exact ticks.
- **The helm (L-MAN-01).** The helm still needs an operator to work at all (`needs_crew`). Its manned
  effect is extra dodge, a new key `manned_dodge` in `helm.json` (start 0.03), times the same
  `skill_scale`, added to `evasion()` on top of bars x `evasion_per_bar`. Coolant and reactor: no
  manned effect.
- **Content (L-MAN-03).** Starting crew: give each a `station` skill so the three differ (for example
  Vasquez 1.3, Okafor 1.0, Lindqvist 0.9). The hire pool (`survivors.json`): spread station skills from
  about 0.9 to 1.7, at least one at 1.5 or more; keep fire and repair as they are.

## Tests (each closes its row only with the wrong value failing)
- `game/tests/test_ledger_crew.gd`: `test_l_man_01` (scenario `ledger_manning`: for drill, weapons and
  bracing, the measured rate manned at skill 1.0 is 12 to 20% above unmanned, and the bonus at skill
  2.0 is 1.5 to 2.0 times the bonus at 1.0; the helm's dodge manned at 1.0 is 0.02 to 0.04 above its
  bars' value, and its 2.0 bonus 1.5 to 2.0 times that); `test_l_man_02` (two crew give the better
  one's bonus; a crew member with another job gives none; the bonus is on within 15 ticks of the
  operator arriving); `test_l_man_03` (the data spans 0.9 to 1.6 with a hire at 1.5 or more).
- Measure rates from sim behaviour over 600 ticks where you can (drill cut speed through
  `drill_bonus`, weapon charge through `weapon_bonus`, layer recharge in ticks, dodge from `evasion`).
- Wrong values, as in-memory overrides that must make the band check FAIL: every `manned_bonus` and
  `manned_dodge` at 0 (L-MAN-01 first clause); `station_skill_gain` 0 (its second clause); bonuses
  summed over the crew in the room (L-MAN-02: write the summing variant inside the test as the wrong
  rule); every station skill 1.0 (L-MAN-03).

## Commands that must pass
`python tools/check.py` prints `check: ok` (full run); `python tools/determinism.py` passes (report the
new hash; information only). No windowed runs.

## Done looks like
The three rows pass with their wrong values failing, `check: ok`, Status lines set. Commit on your
branch with explicit paths, messages without em dashes, ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not push or merge.

## Report (short)
Measured values for every band, final tuning values, tests changed, the new determinism hash, your
branch and final commit, and anything you could not do and why.
