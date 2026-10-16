class_name RunLint
extends RefCounted
## Checks the run tuning and every layer in data/layers: numbers in range, the rock table and enemy
## ships exist, the survey block is sane, and maps generated from a few seeds keep the map rules (a
## store in every store window on every path, no two stores in a row, fights per path). Also the
## gear table and the store lines that sell gear (Gear.lint).

## Enemy ship ids the layer data may name before the ships exist. The combat step (M1 step 4) adds
## "rival_light" and "rival_heavy" to data/ships; remove them from here then.
const PENDING_SHIPS: Array[String] = ["rival_light", "rival_heavy"]
const LINT_SEEDS: int = 12


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	for key: String in RunState.TUNING_KEYS:
		if not db.tuning.has(key):
			errs.append("%s/tuning: missing number \"%s\"" % [db.root, key])
	var layers: Dictionary = db.table("layers")
	for id: String in layers.keys():
		_lint_layer(db, layers[id], db.source_of("layers", id), errs)
	Gear.lint(db, errs)


static func _num(d: Dictionary, key: String) -> bool:
	return d.get(key) is float or d.get(key) is int


static func _lint_layer(db: DataDB, def: Dictionary, file: String, errs: PackedStringArray) -> void:
	var before: int = errs.size()
	for key: String in ["rows", "row_depth_m", "min_nodes_per_row", "max_nodes_per_row", "x_min_m", "x_max_m",
			"x_jitter_frac", "link_jitter_m", "min_fights_per_path", "rock_temp_base_c", "rock_temp_c_per_m",
			"scanner_base_rows"]:
		if not _num(def, key):
			errs.append("%s: \"%s\" must be a number" % [file, key])
	if errs.size() > before:
		return
	var rows: int = int(def["rows"])
	if rows < 3:
		errs.append("%s: rows must be 3 or more (start, at least one middle row, gate)" % file)
	if float(def["row_depth_m"]) <= 0.0:
		errs.append("%s: row_depth_m must be above zero" % file)
	var lo: int = int(def["min_nodes_per_row"])
	var hi: int = int(def["max_nodes_per_row"])
	if lo < 1 or hi < lo or hi > 6:
		errs.append("%s: nodes per row must satisfy 1 <= min <= max <= 6" % file)
	if float(def["x_min_m"]) >= float(def["x_max_m"]):
		errs.append("%s: x_min_m must be below x_max_m" % file)
	var jit: float = float(def["x_jitter_frac"])
	if jit < 0.0 or jit >= 0.5:
		errs.append("%s: x_jitter_frac must be in [0, 0.5) so nodes stay in x order" % file)
	if float(def["link_jitter_m"]) < 0.0:
		errs.append("%s: link_jitter_m must be zero or more" % file)
	if int(def["scanner_base_rows"]) < 0:
		errs.append("%s: scanner_base_rows must be zero or more" % file)
	var w: Variant = def.get("node_weights")
	var total: float = 0.0
	if not (w is Dictionary):
		errs.append("%s: node_weights must be an object" % file)
	else:
		var wd: Dictionary = w
		for t: Variant in wd.keys():
			if not MapGen.NODE_TYPES.has(str(t)):
				errs.append("%s: node_weights: unknown node type \"%s\" (known: %s)" % [file, str(t), ", ".join(MapGen.NODE_TYPES)])
			elif not (wd[t] is float or wd[t] is int) or float(wd[t]) < 0.0:
				errs.append("%s: node_weights.%s must be a number, zero or more" % [file, str(t)])
			else:
				total += float(wd[t])
		if total <= 0.0:
			errs.append("%s: node_weights must add up to more than zero" % file)
	var sw: Variant = def.get("store_windows")
	if not (sw is Array):
		errs.append("%s: store_windows must be a list of [first, last] row pairs" % file)
	else:
		for win: Variant in (sw as Array):
			if not (win is Array) or (win as Array).size() != 2:
				errs.append("%s: store_windows entries must be [first, last]" % file)
				continue
			var a: int = int((win as Array)[0])
			var b: int = int((win as Array)[1])
			if a < 1 or b < a or b > rows - 2:
				errs.append("%s: store_windows must lie in the middle rows 1..%d, first <= last" % [file, rows - 2])
	Survey.lint(def.get("survey"), file, errs)
	var need: int = int(def["min_fights_per_path"])
	if need < 0 or need > rows - 2:
		errs.append("%s: min_fights_per_path must be between 0 and the number of middle rows" % file)
	var rock: String = str(def.get("rock", ""))
	if not db.table("rock").has(rock):
		errs.append("%s: rock table \"%s\" does not exist in data/rock" % [file, rock])
	var enemies: Variant = def.get("enemies")
	if not (enemies is Array) or (enemies as Array).is_empty():
		errs.append("%s: enemies must be a list of ship ids" % file)
	else:
		for e: Variant in (enemies as Array):
			_check_ship(db, str(e), file, "enemies", errs)
	var tiers: Variant = def.get("enemy_tiers", [])
	if not (tiers is Array):
		errs.append("%s: enemy_tiers must be a list of {from_row, ships}" % file)
	else:
		var last_from: int = -1
		for t: Variant in (tiers as Array):
			if not (t is Dictionary) or not _num(t as Dictionary, "from_row") or not ((t as Dictionary).get("ships") is Array) \
					or ((t as Dictionary)["ships"] as Array).is_empty():
				errs.append("%s: enemy_tiers entries need a from_row and a non-empty ships list" % file)
				continue
			var from: int = int((t as Dictionary)["from_row"])
			if from <= last_from:
				errs.append("%s: enemy_tiers must be in ascending from_row" % file)
			last_from = from
			for e: Variant in ((t as Dictionary)["ships"] as Array):
				_check_ship(db, str(e), file, "enemy_tiers", errs)
	if def.has("event_rows_of") and (not _num(def, "event_rows_of") or int(def["event_rows_of"]) < 3):
		errs.append("%s: event_rows_of must be a number, 3 or more" % file)
	_check_ship(db, str(def.get("gate_enemy", "")), file, "gate_enemy", errs)
	var pd: Variant = def.get("pursuer")
	if not (pd is Dictionary):
		errs.append("%s: pursuer must be an object" % file)
	else:
		var p: Dictionary = pd
		for key: String in ["start_row", "rows_per_s", "rows_per_noise"]:
			if not _num(p, key):
				errs.append("%s: pursuer.%s must be a number" % [file, key])
			elif key != "start_row" and float(p[key]) < 0.0:
				errs.append("%s: pursuer.%s must be zero or more" % [file, key])
		if p.has("rows_per_s_per_row") and (not _num(p, "rows_per_s_per_row") or float(p["rows_per_s_per_row"]) < 0.0):
			errs.append("%s: pursuer.rows_per_s_per_row must be a number, zero or more" % file)
		if _num(p, "start_row") and float(p["start_row"]) >= 0.0:
			errs.append("%s: pursuer.start_row must be above the start row (below zero)" % file)
	if errs.size() > before:
		return
	# The rules hold on real generated maps.
	for s: int in range(1, LINT_SEEDS + 1):
		var m: Array = MapGen.generate(def, RngStreams.new(s).get_stream("map"))
		if MapGen.min_fights(m) < need:
			errs.append("%s: seed %d: a path has fewer than %d fights" % [file, s, need])
		for win: Variant in (sw as Array):
			if MapGen.min_on_paths(m, "store", int((win as Array)[0]), int((win as Array)[1])) < 1:
				errs.append("%s: seed %d: a path meets no store in rows %s" % [file, s, str(win)])
		if MapGen.has_store_pair(m):
			errs.append("%s: seed %d: a path has two stores in a row" % [file, s])


static func _check_ship(db: DataDB, id: String, file: String, field: String, errs: PackedStringArray) -> void:
	if not db.ships.has(id) and not PENDING_SHIPS.has(id):
		errs.append("%s: %s: ship \"%s\" does not exist in data/ships" % [file, field, id])
