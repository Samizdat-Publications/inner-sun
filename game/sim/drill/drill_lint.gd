class_name DrillLint
extends RefCounted
## Checks the rock tables (game/data/rock/*.json) and the drill tuning: unique material codes and
## ids, code 0 is air, numeric hardness, yields naming real run resources, strata and features
## naming real materials, feature groups and depth windows, a yield and a hazard flag (water, gas)
## never on one material, flags (water, gas, unstable) are booleans, every tuning key present.

const FEATURE_KINDS: Array[String] = ["vein", "lens", "pocket", "blob"]


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	for key: String in DrillSim.TUNING_KEYS:
		if not db.tuning.has(key):
			errs.append("%s/tuning: missing number \"%s\"" % [db.root, key])
	var rock: Dictionary = db.table("rock")
	if not rock.has(DrillSim.DEFAULT_ROCK) and not db.ships.is_empty() and db.tables.has("rock"):
		errs.append("%s/rock: the default rock table \"%s\" is missing" % [db.root, DrillSim.DEFAULT_ROCK])
	for id: String in rock.keys():
		_lint_table(rock[id], db.source_of("rock", id), errs)


static func _lint_table(table: Dictionary, file: String, errs: PackedStringArray) -> void:
	var ids: Dictionary = {}
	var codes: Dictionary = {}
	var mats: Array = table.get("materials", [])
	if mats.is_empty():
		errs.append("%s: no materials" % file)
	for i: int in range(mats.size()):
		if not (mats[i] is Dictionary):
			errs.append("%s: materials[%d] must be an object" % [file, i])
			continue
		var md: Dictionary = mats[i]
		var mid: String = str(md.get("id", ""))
		var where: String = "%s: materials[%d] \"%s\"" % [file, i, mid]
		if mid.is_empty() or ids.has(mid):
			errs.append("%s: missing or duplicate material id" % where)
		ids[mid] = true
		var code_v: Variant = md.get("code", null)
		if not (code_v is float or code_v is int) or float(code_v) != floorf(float(code_v)) or int(code_v) < 0 or int(code_v) >= DrillSim.MAX_CODES:
			errs.append("%s: code must be a whole number from 0 to %d" % [where, DrillSim.MAX_CODES - 1])
		elif codes.has(int(code_v)):
			errs.append("%s: duplicate code %d (also \"%s\")" % [where, int(code_v), str(codes[int(code_v)])])
		else:
			codes[int(code_v)] = mid
		var h: Variant = md.get("hardness", null)
		if not (h is float or h is int) or float(h) < 0.0:
			errs.append("%s: hardness must be a number, zero or more" % where)
		var color: String = str(md.get("color", ""))
		if not Color.html_is_valid(color):
			errs.append("%s: color \"%s\" is not a hex color" % [where, color])
		for flag: String in ["water", "gas", "unstable"]:
			if md.has(flag) and not (md[flag] is bool):
				errs.append("%s: \"%s\" must be true or false" % [where, flag])
		if bool(md.get("water", false)) and bool(md.get("gas", false)):
			errs.append("%s: a material is a water pocket or a gas pocket, not both" % where)
		if md.has("yield") and (bool(md.get("water", false)) or bool(md.get("gas", false))):
			errs.append("%s: a pocket (water or gas) cannot also yield a resource" % where)
		if md.has("yield"):
			var y: Variant = md["yield"]
			if not (y is Dictionary):
				errs.append("%s: yield must be an object {\"res\", \"amount\"}" % where)
			else:
				var yd: Dictionary = y
				if not RunState.RESOURCES.has(str(yd.get("res", ""))):
					errs.append("%s: yield names unknown resource \"%s\" (known: %s)" % [where, str(yd.get("res", "")), ", ".join(RunState.RESOURCES)])
				if int(yd.get("amount", 0)) <= 0:
					errs.append("%s: yield amount must be a whole number above zero" % where)
	if not codes.has(0):
		errs.append("%s: code 0 must be a material (air, hardness 0)" % file)
	else:
		for md2: Variant in mats:
			if md2 is Dictionary and int((md2 as Dictionary).get("code", -1)) == 0 and float((md2 as Dictionary).get("hardness", 1.0)) != 0.0:
				errs.append("%s: code 0 (air) must have hardness 0" % file)
	var strata: Array = table.get("strata", [])
	if strata.is_empty():
		errs.append("%s: no strata" % file)
	for i: int in range(strata.size()):
		var sd: Dictionary = strata[i] if strata[i] is Dictionary else {}
		var where: String = "%s: strata[%d]" % [file, i]
		if not ids.has(str(sd.get("material", ""))):
			errs.append("%s: material \"%s\" does not exist" % [where, str(sd.get("material", ""))])
		if float(sd.get("min_m", 0.0)) <= 0.0 or float(sd.get("max_m", 0.0)) < float(sd.get("min_m", 0.0)):
			errs.append("%s: needs 0 < min_m <= max_m" % where)
		if float(sd.get("weight", 1.0)) <= 0.0:
			errs.append("%s: weight must be above zero" % where)
	var features: Array = table.get("features", [])
	for i: int in range(features.size()):
		var fd: Dictionary = features[i] if features[i] is Dictionary else {}
		var where: String = "%s: features[%d]" % [file, i]
		var kind: String = str(fd.get("kind", ""))
		if not FEATURE_KINDS.has(kind):
			errs.append("%s: unknown kind \"%s\" (known: %s)" % [where, kind, ", ".join(FEATURE_KINDS)])
		if not ids.has(str(fd.get("material", ""))):
			errs.append("%s: material \"%s\" does not exist" % [where, str(fd.get("material", ""))])
		if fd.has("shell") and not ids.has(str(fd["shell"])):
			errs.append("%s: shell material \"%s\" does not exist" % [where, str(fd["shell"])])
		var count: Variant = fd.get("count", [1, 1])
		if not (count is Array) or (count as Array).size() != 2 or int((count as Array)[0]) < 0 or int((count as Array)[1]) < int((count as Array)[0]):
			errs.append("%s: count must be [min, max] with 0 <= min <= max" % where)
		var group: String = str(fd.get("group", ""))
		if not RockGen.GROUPS.has(group):
			errs.append("%s: unknown group \"%s\" (known: %s)" % [where, group, ", ".join(RockGen.GROUPS.slice(1))])
		for key: String in ["from_depth_m", "to_depth_m"]:
			if fd.has(key) and not (fd[key] is float or fd[key] is int):
				errs.append("%s: \"%s\" must be a number" % [where, key])
		if float(fd.get("from_depth_m", 0.0)) >= float(fd.get("to_depth_m", 1.0e12)):
			errs.append("%s: from_depth_m must be below to_depth_m" % where)
		for key: String in ["at", "offset_m", "length_m", "thickness_m", "angle_deg", "width_m", "height_m", "radius_m"]:
			if fd.has(key):
				var v: Variant = fd[key]
				if not ((v is Array and (v as Array).size() == 2) or v is float or v is int):
					errs.append("%s: \"%s\" must be a number or [min, max]" % [where, key])
