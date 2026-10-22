class_name SystemsLint
extends RefCounted
## Checks the system table (game/data/systems/*.json), the ships' references to it and the systems
## tuning, and the ships' crew skills (station included). Called through Systems.lint from DataDB.lint.

const STRING_KEYS: Array[String] = ["id", "name", "description"]
const NUMBER_KEYS: Array[String] = ["fail_c", "recover_c", "manned_bonus"]


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var table: Dictionary = db.table("systems")
	var ids: Array = table.keys()
	ids.sort()
	for id: Variant in ids:
		_lint_def(table[id], db.source_of("systems", str(id)), errs)
	var ship_ids: Array = db.ships.keys()
	ship_ids.sort()
	for sid: Variant in ship_ids:
		var ship: Dictionary = db.ships[sid]
		var file: String = db.source_of("ships", str(sid))
		var rooms: Array = ship.get("rooms", [])
		for i: int in range(rooms.size()):
			var rd: Dictionary = rooms[i]
			var system: String = str(rd.get("system", "none"))
			if system != "none" and not table.has(system):
				errs.append("%s: rooms[%d] \"%s\": system \"%s\" has no game/data/systems/%s.json" % [file, i, str(rd.get("id", "")), system, system])
		var crew: Array = ship.get("crew", [])
		for i: int in range(crew.size()):
			if crew[i] is Dictionary:
				var cd: Dictionary = crew[i]
				_lint_skills(cd.get("skills", {}), "%s: crew[%d] \"%s\"" % [file, i, str(cd.get("id", ""))], errs)
	for key: String in Systems.TUNING_KEYS:
		if not db.tuning.has(key):
			errs.append("%s/tuning: missing number \"%s\"" % [db.root, key])
	if db.tuning.has("systems.coolant_bars_full") and db.tuning["systems.coolant_bars_full"] <= 0.0:
		errs.append("%s/tuning: systems.coolant_bars_full must be above zero" % db.root)
	if db.tuning.has("systems.coolant_j_per_unit") and db.tuning["systems.coolant_j_per_unit"] < 1.0:
		errs.append("%s/tuning: systems.coolant_j_per_unit must be at least 1" % db.root)
	if db.tuning.has("systems.bracing_bars_per_layer") and db.tuning["systems.bracing_bars_per_layer"] < 1.0:
		errs.append("%s/tuning: systems.bracing_bars_per_layer must be at least 1" % db.root)
	if db.tuning.has("systems.station_skill_gain") and db.tuning["systems.station_skill_gain"] < 0.0:
		errs.append("%s/tuning: systems.station_skill_gain must be zero or more" % db.root)


## A crew member's skills: an object of known skills (EventEffects.SKILLS), each a number above zero.
static func _lint_skills(v: Variant, where: String, errs: PackedStringArray) -> void:
	if not (v is Dictionary):
		errs.append("%s: skills must be an object" % where)
		return
	var sk: Dictionary = v
	var keys: Array = sk.keys()
	keys.sort()
	for k: Variant in keys:
		var val: Variant = sk[k]
		if not EventEffects.SKILLS.has(str(k)):
			errs.append("%s: unknown skill \"%s\" (known: %s)" % [where, str(k), ", ".join(EventEffects.SKILLS)])
		elif not (val is float or val is int) or float(val) <= 0.0:
			errs.append("%s: skill \"%s\" must be a number above zero" % [where, str(k)])


static func _lint_def(def: Dictionary, file: String, errs: PackedStringArray) -> void:
	for k: String in STRING_KEYS:
		if not (def.get(k) is String) or str(def.get(k)).is_empty():
			errs.append("%s: \"%s\" must be a non-empty string" % [file, k])
	for k: String in NUMBER_KEYS:
		if not (def.get(k) is float or def.get(k) is int):
			errs.append("%s: \"%s\" must be a number" % [file, k])
	var prio: Variant = def.get("priority")
	if not (prio is float or prio is int) or float(prio) != floorf(float(prio)):
		errs.append("%s: \"priority\" must be a whole number" % file)
	if not (def.get("needs_crew") is bool):
		errs.append("%s: \"needs_crew\" must be true or false" % file)
	if not DataDB.KNOWN_SYSTEMS.has(str(def.get("id", ""))):
		errs.append("%s: system id \"%s\" is not one the sim knows (%s)" % [file, str(def.get("id", "")), ", ".join(DataDB.KNOWN_SYSTEMS)])
	var fail: float = float(def.get("fail_c", 0.0))
	var recover: float = float(def.get("recover_c", 0.0))
	if fail <= recover:
		errs.append("%s: fail_c (%.1f) must be above recover_c (%.1f)" % [file, fail, recover])
	if float(def.get("manned_bonus", 0.0)) < 0.0:
		errs.append("%s: manned_bonus must be zero or more" % file)
	if def.has("manned_dodge"):  # Optional: only the helm dodges.
		var dodge: Variant = def["manned_dodge"]
		if not (dodge is float or dodge is int) or float(dodge) < 0.0 or float(dodge) >= 1.0:
			errs.append("%s: manned_dodge must be a number from 0 to below 1" % file)
