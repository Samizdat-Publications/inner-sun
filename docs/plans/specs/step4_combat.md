# Spec: M1 step 4, combat (sim side)

For a builder-opus agent after step 3. Read CLAUDE.md, docs/ARCHITECTURE.md, the Systems module
(evasion, bracing layers, absorb_hit, damage_room, weapon_bars), ShipWorld, HazardSim, RunState.

## Shape
Real time with pause, FTL-like, in the rock: a rival drill tower appears beside yours (left or
right, from the combat stream) with about 14 m of rock between the hulls. Rounds bore through the
rock. The enemy ship is a ShipWorld built from ship data, so it has rooms, systems, crew on auto,
fires, breaches and heat like yours.

## Data
- `game/data/weapons/<id>.json`: id, name, blurb, kind (`projectile`, `beam`, `charge`), power
  (bars it needs), charge_s, shots, damage (hull), sys_damage (bars), crew_damage (hp), fire_chance,
  breach_chance, breach_m2, heat_kj, speed_m_s (projectiles), beam_len_m (beams), ammo resource for
  charges, pierces_bracing.
  - `borer_turret` (projectile, 1 power, about 9 s, 1 damage; stopped by a bracing layer)
  - `thermal_lance` (beam, 2 power, about 16 s; sweeps across rooms from the target; damage per
    room minus bracing layers, does not spend layers; heats rooms and starts fires)
  - `charge_launcher` (charge, 1 power, about 12 s; spends 1 "charges"; ignores bracing; 2 damage,
    likely breach)
- Ships list weapons in slot order (`"weapons": [...]`). The player's light drill starts with the
  borer turret and the charge launcher; the lance is bought or found.
- Enemy ships: `rival_light` (4 or 5 rooms, about 12 hull, a borer), `rival_heavy` (the gate boss:
  6 rooms, more hull, borer plus lance). Each with crew and an AI profile (power priorities).

## Rules
- `start_fight(sim, enemy_id, boss)`: build `sim.enemy`, set phase `combat`, emit "fight_start".
- Weapon power comes from the weapons system's effective bars, assigned to weapons in slot order;
  unpowered weapons lose their charge slowly. A powered weapon charges (manned bonus from Systems);
  when charged and targeted it fires.
- Command `{"type": "target", "weapon": slot, "room": "<enemy room id>"}` (empty room clears).
- Command `{"type": "flee"}`: dig out. Needs at least 2 drill bars and a manned helm; takes about
  15 s, during which the drill runs; then combat ends with no loot ("fled").
- Hits: evasion roll against the target's `evasion` (combat stream per side), then bracing
  (`absorb_hit` for projectiles; beams reduce by layers; charges ignore), then hull damage (the
  player's `run.resources.hull`; the enemy's hull kept in CombatSim), system damage
  (`damage_room`), crew damage to everyone in the room, fire chance (ignite), breach chance.
- Enemy AI at 4 Hz: power by priority, targets weighted toward weapons, bracing and helm rooms,
  retargets when a room's system is destroyed. Uses only the enemy's own streams.
- Victory: enemy hull 0 or all enemy crew dead: "fight_won", loot by the layer's loot table (ore,
  gems, sometimes cells, charges or a weapon), `sim.enemy = null`, phase idle; the boss win ends the
  run as won. Defeat is RunState's job (hull 0, crew dead).
- state(): weapons (charge, target, powered) per side, projectiles in flight (positions as exact as
  needed, deterministic), enemy hull, flee timer.

## Tests
Same seed same fight hash; bracing absorbs a projectile and recharges; charges ignore bracing and
spend ammo; the beam is reduced by layers and heats rooms; weapons need power; evasion lowers hits
over many shots with a fixed seed; the enemy crew repairs and fights fires; victory gives loot and
returns to idle; flee works only with drill power and a manned helm; replay matches.
