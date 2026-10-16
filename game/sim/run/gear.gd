class_name Gear
extends RefCounted
## Gear: equipment bought at stores with ore (game/data/gear/<id>.json). The run keeps the ids it
## owns in RunState.gear (in the order fitted) and the product of their multipliers in
## RunState.gear_mult; modules read them through RunState.gear_x(key). Static helpers only.
##
## Format: {"id", "name", "text", "slot": optional (one item per slot: a new one replaces the old,
##   and only a higher "tier" may replace), "tier": whole number (slotted gear), "max_owned": how
##   many may be fitted at once (default 1), "effects": {key: number}}.
## Effects: multipliers (product over owned gear, read when they apply):
##   cut_speed_x (drill speed), wear_x (bit wear per meter), hard_rock_x (hardness of rock at or
##   above drill.hard_rock_min_hardness: speed, heat, wear and noise there), pump_x (pump rate);
## and whole-number adds applied once when fitted (never on slotted gear, so nothing is undone):
##   max_hull_add (the ship's maximum hull), hull_add (repairs the hull by this much).

const MULTIPLIERS: Array[String] = ["cut_speed_x", "wear_x", "hard_rock_x", "pump_x"]
const ADDS: Array[String] = ["max_hull_add", "hull_add"]


## Multipliers of a list of owned gear, keys in MULTIPLIERS order (all 1.0 for no gear).
static func multipliers(db: DataDB, owned: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for k: String in MULTIPLIERS:
		out[k] = 1.0
	var table: Dictionary = db.table("gear")
	for id: String in owned:
		var eff: Dictionary = (table.get(id, {}) as Dictionary).get("effects", {})
		for k: String in MULTIPLIERS:
			if eff.has(k):
				out[k] = float(out[k]) * float(eff[k])
	return out


## Why this gear cannot be fitted now ("" = it can).
static func refusal(sim: Sim, id: String) -> String:
	var def: Dictionary = sim.db.table("gear").get(id, {})
	if def.is_empty():
		return "no gear \"%s\"" % id
	var owned: int = 0
	for g: String in sim.run.gear:
		if g == id:
			owned += 1
	if owned >= int(def.get("max_owned", 1)):
		return "%s is already fitted" % str(def.get("name", id))
	var slot: String = str(def.get("slot", ""))
	if not slot.is_empty():
		var fitted: String = fitted_in(sim, slot)
		if not fitted.is_empty() and tier_of(sim.db, fitted) >= int(def.get("tier", 0)):
			return "a %s as good or better is fitted" % slot.replace("_", " ")
	return ""


## The gear id fitted in a slot ("" for none).
static func fitted_in(sim: Sim, slot: String) -> String:
	for g: String in sim.run.gear:
		if str((sim.db.table("gear").get(g, {}) as Dictionary).get("slot", "")) == slot:
			return g
	return ""


static func tier_of(db: DataDB, id: String) -> int:
	return int((db.table("gear").get(id, {}) as Dictionary).get("tier", 0))


## Fit gear (the caller checked refusal): replace the slot's old item, apply the one-time adds,
## recompute the multipliers, emit "gear_fitted" {"gear", "replaced"}.
static func fit(sim: Sim, id: String) -> void:
	var def: Dictionary = sim.db.table("gear").get(id, {})
	var slot: String = str(def.get("slot", ""))
	var replaced: String = ""
	var owned: PackedStringArray = sim.run.gear.duplicate()  # Packed arrays are values: build, then store.
	if not slot.is_empty():
		replaced = fitted_in(sim, slot)
		if not replaced.is_empty():
			owned.remove_at(owned.find(replaced))
	owned.append(id)
	sim.run.gear = owned
	var eff: Dictionary = def.get("effects", {})
	var more_hull: int = int(eff.get("max_hull_add", 0))
	if more_hull != 0:
		sim.ship.hull_max += more_hull
	var repair: int = int(eff.get("hull_add", 0))
	if repair != 0:
		sim.run.add(sim, "hull", repair)
	sim.run.gear_mult = multipliers(sim.db, sim.run.gear)
	sim.emit("gear_fitted", {"gear": id, "replaced": replaced})


## Checks data/gear and every store line that sells gear.
static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var table: Dictionary = db.table("gear")
	for id: String in table.keys():
		var d: Dictionary = table[id]
		var file: String = db.source_of("gear", id)
		if str(d.get("name", "")).is_empty() or str(d.get("text", "")).is_empty():
			errs.append("%s: gear needs a name and a text" % file)
		if int(d.get("max_owned", 1)) < 1:
			errs.append("%s: max_owned must be 1 or more" % file)
		var slotted: bool = not str(d.get("slot", "")).is_empty()
		if slotted and int(d.get("tier", 0)) < 1:
			errs.append("%s: slotted gear needs a tier of 1 or more" % file)
		var eff: Variant = d.get("effects", null)
		if not (eff is Dictionary) or (eff as Dictionary).is_empty():
			errs.append("%s: effects must be a non-empty object" % file)
			continue
		var ed: Dictionary = eff
		for k: Variant in ed.keys():
			var key: String = str(k)
			var v: Variant = ed[k]
			if MULTIPLIERS.has(key):
				if not (v is float or v is int) or float(v) <= 0.0:
					errs.append("%s: effect %s must be a number above zero" % [file, key])
			elif ADDS.has(key):
				if not (v is float or v is int) or float(v) != floorf(float(v)) or int(v) < 0:
					errs.append("%s: effect %s must be a whole number, zero or more" % [file, key])
				elif slotted:
					errs.append("%s: slotted gear cannot have %s (a replaced item could not undo it)" % [file, key])
			else:
				errs.append("%s: unknown effect \"%s\" (known: %s, %s)" % [file, key, ", ".join(MULTIPLIERS), ", ".join(ADDS)])
	var stores: Dictionary = db.table("stores")
	for sid: String in stores.keys():
		var stock: Array = (stores[sid] as Dictionary).get("stock", [])
		for i: int in range(stock.size()):
			if stock[i] is Dictionary and str((stock[i] as Dictionary).get("item", "")) == "gear":
				var g: String = str((stock[i] as Dictionary).get("gear", ""))
				if not table.has(g):
					errs.append("%s: stock[%d]: gear \"%s\" does not exist in data/gear" % [db.source_of("stores", sid), i, g])
