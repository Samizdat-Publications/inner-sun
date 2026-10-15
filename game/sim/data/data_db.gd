class_name DataDB
extends RefCounted
## All game content, loaded from JSON under res://data. Every folder is a table (tables["<folder>"]
## maps id to definition; ships and scenarios are kept as aliases); tuning files merge into tune().
## Adding content means adding data. lint() checks every cross-reference (each sim module lints its
## own tables) and reports each problem with the file it came from, so a broken reference is caught
## by the tests before anyone plays it.

const ROOT: String = "res://data"
const KNOWN_SYSTEMS: Array[String] = ["none", "helm", "bracing", "reactor", "weapons", "drill", "coolant"]
const KNOWN_BOTS: Array[String] = ["auto", "idle", "random", "scripted_fire_drill", "drill", "run"]
const EM_DASH_CODE: int = 0x2014  ## Built at runtime so no source file contains the character.
const EPS: float = 0.01

var root: String = ROOT
var tables: Dictionary = {}  ## folder name -> {id -> definition}
var ships: Dictionary = {}
var scenarios: Dictionary = {}
var tuning: Dictionary = {}
var sources: Dictionary = {}
var load_errors: PackedStringArray = PackedStringArray()


static func load_all(p_root: String = ROOT) -> DataDB:
	var db := DataDB.new()
	db.root = p_root
	db.tables["ships"] = db.ships
	db.tables["scenarios"] = db.scenarios
	var folders: PackedStringArray = DirAccess.get_directories_at(p_root) if DirAccess.dir_exists_absolute(p_root) else PackedStringArray()
	folders.sort()
	for folder: String in folders:
		if folder == "tuning":
			continue
		if not db.tables.has(folder):
			db.tables[folder] = {}
		var table: Dictionary = db.tables[folder]
		db._load_table(p_root.path_join(folder), DataDB.kind_of(folder), table)
	db._load_tuning(p_root.path_join("tuning"))
	return db


## The source key prefix for a table: "ship" for ships and "scenario" for scenarios (kept from M0),
## the folder name for every other table.
static func kind_of(folder: String) -> String:
	if folder == "ships":
		return "ship"
	if folder == "scenarios":
		return "scenario"
	return folder


## A table by folder name (empty if the folder does not exist).
func table(folder: String) -> Dictionary:
	if not tables.has(folder):
		return {}
	return tables[folder]


## The file a definition came from, for error messages.
func source_of(folder: String, id: String) -> String:
	return str(sources.get("%s:%s" % [DataDB.kind_of(folder), id], "%s/%s" % [root, folder]))


func tune(key: String) -> float:
	if not tuning.has(key):
		push_error("Missing tuning value \"%s\" (add it under data/tuning/)" % key)
		return 0.0
	return float(tuning[key])


# Loading ---------------------------------------------------------------------------------------

func _load_table(dir: String, kind: String, table: Dictionary) -> void:
	for file: String in _json_files(dir):
		var parsed: Variant = _read_json(file)
		if parsed == null:
			continue
		if not (parsed is Dictionary):
			load_errors.append("%s: the top level must be an object" % file)
			continue
		var d: Dictionary = parsed
		var id: String = str(d.get("id", ""))
		if id.is_empty():
			load_errors.append("%s: missing \"id\"" % file)
			continue
		var key: String = "%s:%s" % [kind, id]
		if table.has(id):
			load_errors.append("%s: duplicate %s id \"%s\" (first defined in %s)" % [file, kind, id, sources[key]])
			continue
		table[id] = d
		sources[key] = file


func _load_tuning(dir: String) -> void:
	for file: String in _json_files(dir):
		var parsed: Variant = _read_json(file)
		if not (parsed is Dictionary):
			continue
		var d: Dictionary = parsed
		for section: String in d.keys():
			var body: Variant = d[section]
			if not (body is Dictionary):
				load_errors.append("%s: section \"%s\" must be an object" % [file, section])
				continue
			var sec: Dictionary = body
			for k: String in sec.keys():
				var v: Variant = sec[k]
				if not (v is float or v is int):
					load_errors.append("%s: %s.%s must be a number" % [file, section, k])
					continue
				tuning["%s.%s" % [section, k]] = float(v)
				sources["tuning:%s.%s" % [section, k]] = file


func _read_json(file: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(file)
	if text.is_empty():
		load_errors.append("%s: cannot read file (or it is empty)" % file)
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		load_errors.append("%s:%d: JSON error: %s" % [file, json.get_error_line(), json.get_error_message()])
		return null
	if _has_em_dash(json.data):
		load_errors.append("%s: contains an em dash (house rule: never use one; use a comma, colon or spaced hyphen)" % file)
	return json.data


static func _has_em_dash(v: Variant) -> bool:
	if v is String:
		return (v as String).contains(char(EM_DASH_CODE))
	if v is Dictionary:
		var d: Dictionary = v
		for k: Variant in d.keys():
			if _has_em_dash(k) or _has_em_dash(d[k]):
				return true
	if v is Array:
		for item: Variant in (v as Array):
			if _has_em_dash(item):
				return true
	return false


static func _json_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names: PackedStringArray = DirAccess.get_files_at(dir)
	names.sort()
	for n: String in names:
		if n.get_extension() == "json":
			out.append(dir.path_join(n))
	return out


# Lint ------------------------------------------------------------------------------------------

func lint() -> PackedStringArray:
	var errs := PackedStringArray(load_errors)
	for id: String in ships.keys():
		_lint_ship(ships[id], str(sources["ship:" + id]), errs)
	for id: String in scenarios.keys():
		_lint_scenario(scenarios[id], str(sources["scenario:" + id]), errs)
	var needed: Array[String] = []
	needed.append_array(HazardSim.TUNING_KEYS)
	needed.append_array(CrewAI.TUNING_KEYS)
	for key: String in needed:
		if not tuning.has(key):
			errs.append("%s/tuning: missing number \"%s\"" % [root, key])
	# Each sim module checks its own tables and tuning (see docs/ARCHITECTURE.md).
	RunState.lint(self, errs)
	Systems.lint(self, errs)
	DrillSim.lint(self, errs)
	CombatSim.lint(self, errs)
	Encounter.lint(self, errs)
	return errs


func _lint_ship(def: Dictionary, file: String, errs: PackedStringArray) -> void:
	var rects: Dictionary = {}
	var rooms: Array = def.get("rooms", [])
	if rooms.is_empty():
		errs.append("%s: ship has no rooms" % file)
	for i: int in range(rooms.size()):
		var rd: Dictionary = rooms[i]
		var rid: String = str(rd.get("id", ""))
		var where: String = "%s: rooms[%d] \"%s\"" % [file, i, rid]
		if rid.is_empty() or rects.has(rid):
			errs.append("%s: missing or duplicate room id" % where)
			continue
		for f: String in ["x", "y", "w", "h"]:
			if not (rd.get(f) is float or rd.get(f) is int):
				errs.append("%s: \"%s\" must be a number" % [where, f])
		var w: float = float(rd.get("w", 0.0))
		var h: float = float(rd.get("h", 0.0))
		if w <= 0.0 or h <= 0.0:
			errs.append("%s: width and height must be above zero" % where)
		var system: String = str(rd.get("system", "none"))
		if not KNOWN_SYSTEMS.has(system):
			errs.append("%s: unknown system \"%s\" (known: %s)" % [where, system, ", ".join(KNOWN_SYSTEMS)])
		var bars: int = int(rd.get("bars", 0))
		if bars < 0 or int(rd.get("power", bars)) > bars or int(rd.get("power", 0)) < 0:
			errs.append("%s: bars must be zero or more and power between 0 and bars" % where)
		rects[rid] = Rect2(float(rd.get("x", 0.0)), float(rd.get("y", 0.0)), w, h)
	var links: Array = def.get("links", [])
	for i: int in range(links.size()):
		var ld: Dictionary = links[i]
		var where: String = "%s: links[%d] \"%s\"" % [file, i, str(ld.get("id", ""))]
		var kind: String = str(ld.get("kind", ""))
		var a: String = str(ld.get("a", ""))
		var b: String = str(ld.get("b", ""))
		if kind != "door" and kind != "hatch":
			errs.append("%s: kind must be \"door\" or \"hatch\", not \"%s\"" % [where, kind])
			continue
		var missing: bool = false
		for end: String in [a, b]:
			if not rects.has(end):
				errs.append("%s: room \"%s\" does not exist in this ship" % [where, end])
				missing = true
		if missing:
			continue
		if a == b:
			errs.append("%s: a link must join two different rooms" % where)
			continue
		var ra: Rect2 = rects[a]
		var rb: Rect2 = rects[b]
		var x: float = float(ld.get("x", -1.0))
		if kind == "door":
			var touching: bool = absf(ra.end.x - rb.position.x) < EPS or absf(rb.end.x - ra.position.x) < EPS
			if not touching or absf(ra.end.y - rb.end.y) > EPS:
				errs.append("%s: a door needs two side-by-side rooms with the same floor" % where)
			elif absf(x - ra.end.x) > EPS and absf(x - ra.position.x) > EPS:
				errs.append("%s: door x %.2f is not on the shared wall" % [where, x])
			if float(ld.get("height_m", 2.0)) > minf(ra.size.y, rb.size.y) + EPS:
				errs.append("%s: door is taller than the rooms" % where)
		else:
			if absf(ra.end.y - rb.position.y) > EPS:
				errs.append("%s: a hatch needs room \"%s\" directly above room \"%s\"" % [where, a, b])
			var half: float = float(ld.get("span_m", 0.8)) * 0.5
			for r: Rect2 in [ra, rb]:
				if x - half < r.position.x - EPS or x + half > r.end.x + EPS:
					errs.append("%s: hatch at x %.2f does not fit inside both rooms" % [where, x])
					break
	var crew_ids: Dictionary = {}
	var crew: Array = def.get("crew", [])
	for i: int in range(crew.size()):
		var cd: Dictionary = crew[i]
		var cid: String = str(cd.get("id", ""))
		if cid.is_empty() or crew_ids.has(cid):
			errs.append("%s: crew[%d]: missing or duplicate crew id" % [file, i])
		crew_ids[cid] = true
		if not rects.has(str(cd.get("room", ""))):
			errs.append("%s: crew[%d] \"%s\": start room \"%s\" does not exist" % [file, i, cid, str(cd.get("room", ""))])


func _lint_scenario(def: Dictionary, file: String, errs: PackedStringArray) -> void:
	var ship_id: String = str(def.get("ship", ""))
	if not ships.has(ship_id):
		errs.append("%s: ship \"%s\" does not exist" % [file, ship_id])
		return
	var ship: Dictionary = ships[ship_id]
	var room_ids: Dictionary = {}
	for rd: Dictionary in ship.get("rooms", []):
		room_ids[str(rd.get("id", ""))] = true
	var crew_ids: Dictionary = {}
	for cd: Dictionary in ship.get("crew", []):
		crew_ids[str(cd.get("id", ""))] = true
	var bot: String = str(def.get("bot", "auto"))
	if not KNOWN_BOTS.has(bot):
		errs.append("%s: unknown bot \"%s\" (known: %s)" % [file, bot, ", ".join(KNOWN_BOTS)])
	if float(def.get("duration_s", 0.0)) <= 0.0:
		errs.append("%s: duration_s must be above zero" % file)
	var timeline: Array = def.get("timeline", [])
	for i: int in range(timeline.size()):
		var e: Dictionary = timeline[i]
		var where: String = "%s: timeline[%d]" % [file, i]
		if float(e.get("at_s", -1.0)) < 0.0:
			errs.append("%s: at_s must be zero or more" % where)
		var cmd: Dictionary = e.get("cmd", {})
		var kind: String = str(cmd.get("type", ""))
		if not Sim.known_commands().has(kind):
			errs.append("%s: unknown command type \"%s\"" % [where, kind])
		if cmd.has("room") and not room_ids.has(str(cmd["room"])):
			errs.append("%s: room \"%s\" is not in ship \"%s\"" % [where, str(cmd["room"]), ship_id])
		if cmd.has("crew") and not crew_ids.has(str(cmd["crew"])):
			errs.append("%s: crew \"%s\" is not in ship \"%s\"" % [where, str(cmd["crew"]), ship_id])
