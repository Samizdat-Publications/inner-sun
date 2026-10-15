class_name CombatLoot
extends RefCounted
## What a beaten rival leaves behind: ore and gems always, sometimes power cells and charges, rarely a
## weapon (one the ship does not carry yet, if a slot is free). The boss scales every amount by
## combat.loot_boss_scale. Every roll is drawn every time (a fixed number of draws from the "loot"
## stream), so a change to one chance never shifts the others. Resources go through run.add.


static func roll(sim: Sim, db: DataDB, boss: bool) -> Dictionary:
	var rng: RandomNumberGenerator = sim.rng.get_stream("loot")
	var scale: float = db.tune("combat.loot_boss_scale") if boss else 1.0
	var ore: int = rng.randi_range(roundi(db.tune("combat.loot_ore_min_units")), roundi(db.tune("combat.loot_ore_max_units")))
	var gems: int = rng.randi_range(roundi(db.tune("combat.loot_gems_min_units")), roundi(db.tune("combat.loot_gems_max_units")))
	var cells_roll: float = rng.randf()
	var cells: int = rng.randi_range(1, maxi(1, roundi(db.tune("combat.loot_cells_max_units"))))
	var charges_roll: float = rng.randf()
	var charges: int = rng.randi_range(1, maxi(1, roundi(db.tune("combat.loot_charges_max_units"))))
	var weapon_roll: float = rng.randf()
	var weapon_pick: float = rng.randf()
	if cells_roll >= db.tune("combat.loot_cells_chance"):
		cells = 0
	if charges_roll >= db.tune("combat.loot_charges_chance"):
		charges = 0
	var got: Dictionary = {}
	got["ore"] = sim.run.add(sim, "ore", roundi(float(ore) * scale))
	got["gems"] = sim.run.add(sim, "gems", roundi(float(gems) * scale))
	got["cells"] = sim.run.add(sim, "cells", roundi(float(cells) * scale))
	got["charges"] = sim.run.add(sim, "charges", roundi(float(charges) * scale))
	got["weapon"] = ""
	if weapon_roll < db.tune("combat.loot_weapon_chance"):
		got["weapon"] = _weapon(sim, db, weapon_pick)
	return got


## A weapon the ship does not carry, picked by `pick` (0 to 1) from the weapon ids in name order, if
## a slot is free. Returns its id, or "".
static func _weapon(sim: Sim, db: DataDB, pick: float) -> String:
	var slots: int = int(sim.ship.source_def.get("weapon_slots", 0))
	if slots > 0 and sim.ship.weapons.size() >= slots:
		return ""
	var ids := PackedStringArray()
	for k: Variant in db.table("weapons").keys():
		if not sim.ship.weapons.has(str(k)):
			ids.append(str(k))
	if ids.is_empty():
		return ""
	ids.sort()  # Plain Strings, never StringNames.
	var wid: String = ids[mini(ids.size() - 1, int(pick * ids.size()))]
	sim.ship.weapons.append(wid)
	sim.emit("weapon_found", {"weapon": wid})
	return wid
