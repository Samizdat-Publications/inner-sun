class_name RunLint
extends RefCounted
## Checks the run tuning and every layer in data/layers: numbers in range, the rock table and enemy
## ships exist, and maps generated from a few seeds keep the map rules (store, fights per path).

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
	var sr: Variant = def.get("store_rows")
	if not (sr is Array) or (sr as Array).size() != 2:
		errs.append("%s: store_rows must be [first, last]" % file)
	else:
		var a: int = int((sr as Array)[0])
		var b: int = int((sr as Array)[1])
		if a < 1 or b < a or b > rows - 2:
			errs.append("%s: store_rows must lie in the middle rows 1..%d, first <= last" % [file, rows - 2])
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
		if _num(p, "start_row") and float(p["start_row"]) >= 0.0:
			errs.append("%s: pursuer.start_row must be above the start row (below zero)" % file)
	if errs.size() > before:
		return
	# The rules hold on real generated maps.
	for s: int in range(1, LINT_SEEDS + 1):
		var m: Array = MapGen.generate(def, RngStreams.new(s).get_stream("map"))
		if MapGen.min_fights(m) < need:
			errs.append("%s: seed %d: a path has fewer than %d fights" % [file, s, need])
		var store: bool = false
		for r: int in range(int((sr as Array)[0]), int((sr as Array)[1]) + 1):
			for n: Dictionary in (m[r] as Array):
				store = store or str(n["type"]) == "store"
		if not store:
			errs.append("%s: seed %d: no store in the store rows" % [file, s])


static func _check_ship(db: DataDB, id: String, file: String, field: String, errs: PackedStringArray) -> void:
	if not db.ships.has(id) and not PENDING_SHIPS.has(id):
		errs.append("%s: %s: ship \"%s\" does not exist in data/ships" % [file, field, id])
