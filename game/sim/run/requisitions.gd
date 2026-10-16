class_name Requisitions
extends RefCounted
## Requisitions: permanent equipment the player buys between runs with research (Research) and that
## is loaded onto every later dive. One file each in game/data/requisitions/<id>.json:
##   {"id", "name", "blurb", "cost": whole number above zero, "order": sort key for the screen,
##    "effects": {...}}
## Effects (all optional, at least one):
##   "start_resources": {resource: amount}  added to the ship's start (never hull; see max_hull),
##   "max_hull": n                          the ship's maximum hull and its hull, both raised by n,
##   "gear": [gear id]                      fitted at the start through Gear.fit,
##   "crew": n                              n extra crew from the "survivors" pool (stream "meta/crew").
## The owned ids travel in the run options ("requisitions": sorted ids), so they are part of the replay
## header. The sim applies them once when a run begins (Sim._init, run mode only). Static helpers only.

const EFFECTS: Array[String] = ["start_resources", "max_hull", "gear", "crew"]
const CREW_POOL: String = "survivors"
const CREW_STREAM: String = "meta/crew"


## The owned ids a Sim was given, sorted.
static func owned_from(options: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for r: Variant in options.get("requisitions", []):
		if not out.has(str(r)):
			out.append(str(r))
	out.sort()
	return out


## Load the owned requisitions onto a fresh run. Resources change directly (no "resource" events: the
## run summary then only counts what the dive itself gained). Emits "requisitions" {"ids", "lines"}.
static func apply(sim: Sim) -> void:
	if sim.run.mode != "run":
		return
	var ids: PackedStringArray = owned_from(sim.options)
	if ids.is_empty():
		return
	var table: Dictionary = sim.db.table("requisitions")
	var loaded := PackedStringArray()
	var lines := PackedStringArray()
	for id: String in ids:
		if not table.has(id):
			sim.emit("bad_requisition", {"id": id})
			continue
		loaded.append(id)
		var eff: Dictionary = (table[id] as Dictionary).get("effects", {})
		var start: Dictionary = eff.get("start_resources", {})
		for res: String in RunState.RESOURCES:
			if start.has(res):
				sim.run.resources[res] = int(sim.run.resources[res]) + int(start[res])
		var hull: int = int(eff.get("max_hull", 0))
		if hull != 0:
			sim.ship.hull_max += hull
			sim.run.resources["hull"] = int(sim.run.resources["hull"]) + hull
		for g: Variant in eff.get("gear", []):
			if Gear.refusal(sim, str(g)).is_empty():
				Gear.fit(sim, str(g))
		for i: int in range(int(eff.get("crew", 0))):
			var member: String = EventEffects.roll_member(sim, sim.encounter, CREW_POOL, CREW_STREAM)
			if not member.is_empty():
				EventEffects.join(sim, sim.encounter, CREW_POOL, member)
		lines.append(effect_line(table[id], sim.db))
	sim.emit("requisitions", {"ids": Array(loaded), "lines": Array(lines)})


## A short line for what a requisition does, e.g. "+1 bits" or "tungsten drill head fitted".
static func effect_line(def: Dictionary, db: DataDB = null) -> String:
	var eff: Dictionary = def.get("effects", {})
	var parts := PackedStringArray()
	var start: Dictionary = eff.get("start_resources", {})
	for res: String in RunState.RESOURCES:
		if start.has(res):
			parts.append("+%d %s" % [int(start[res]), res])
	if int(eff.get("max_hull", 0)) != 0:
		parts.append("+%d max hull" % int(eff["max_hull"]))
	for g: Variant in eff.get("gear", []):
		var gname: String = str(g).replace("_", " ")
		if db != null:
			gname = str((db.table("gear").get(str(g), {}) as Dictionary).get("name", gname)).to_lower()
		parts.append("%s fitted" % gname)
	var crew: int = int(eff.get("crew", 0))
	if crew > 0:
		parts.append("+%d crew" % crew)
	return ", ".join(parts)


## The requisition ids in screen order ("order", then id).
static func ordered_ids(db: DataDB) -> PackedStringArray:
	var table: Dictionary = db.table("requisitions")
	var ids: Array = table.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var oa: int = int((table[a] as Dictionary).get("order", 0))
		var ob: int = int((table[b] as Dictionary).get("order", 0))
		return oa < ob if oa != ob else str(a) < str(b))
	var out := PackedStringArray()
	for i: Variant in ids:
		out.append(str(i))
	return out
