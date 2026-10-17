class_name StructureLint
extends RefCounted
## Checks the buried structures (game/data/structures/*.json) and the rock tables' "structures"
## lists. Called from DrillLint (so from DataDB.lint). Em dashes are already rejected when the JSON
## loads. Each problem names its file.
##
## A structure: text in "id", "name", "label"; "codex" an existing codex entry; "legend" maps single
## chars (not " ") to material ids of the rock tables that list it (or the default rock table), or
## to {"material", "from_depth_m", "else"}; "stamp" a non-empty list of equal-length non-empty rows
## whose chars are all in the legend or " "; at least one interior cell (an "interior" or "loot"
## material); "mirror" a bool; "loot" rows {"weight" > 0, "res" a run resource other than hull,
## "amount" a whole number > 0} (needed when the stamp holds a loot material), "loot_by_material"
## {loot material id: rows}; two crates of different loot materials never touch (they would open as
## one); "event_chance" and "trader_chance" from 0 to 1; "trader" "" or an existing store (and a
## trader_chance above 0 needs one).

const MAX_STAMP_CELLS: Vector2i = Vector2i(48, 40)  ## Wider or taller stamps cannot fit a segment.


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var rock: Dictionary = db.table("rock")
	var structures: Dictionary = db.table("structures")
	var tables_of: Dictionary = {}  ## structure id -> rock table ids listing it (lookup only).
	for rid: String in _sorted_keys(rock):
		var table: Dictionary = rock[rid]
		var file: String = db.source_of("rock", rid)
		var list: Variant = table.get("structures", [])
		if not (list is Array):
			errs.append("%s: structures must be a list" % file)
			continue
		var arr: Array = list
		for i: int in range(arr.size()):
			var where: String = "%s: structures[%d]" % [file, i]
			if not (arr[i] is Dictionary):
				errs.append("%s: must be an object" % where)
				continue
			var e: Dictionary = arr[i]
			var sid: String = str(e.get("structure", ""))
			if not structures.has(sid):
				errs.append("%s: structure \"%s\" does not exist" % [where, sid])
			else:
				if not tables_of.has(sid):
					tables_of[sid] = []
				(tables_of[sid] as Array).append(rid)
			if not _num(e.get("weight", 1.0)) or float(e.get("weight", 1.0)) <= 0.0:
				errs.append("%s: weight must be a number above zero" % where)
			for key: String in ["from_depth_m", "to_depth_m"]:
				if e.has(key) and not _num(e[key]):
					errs.append("%s: \"%s\" must be a number" % [where, key])
			if float(e.get("from_depth_m", 0.0)) >= float(e.get("to_depth_m", 1.0e12)):
				errs.append("%s: from_depth_m must be below to_depth_m" % where)
	for sid: String in _sorted_keys(structures):
		var against: Array = tables_of.get(sid, [DrillSim.DEFAULT_ROCK])
		for rid: Variant in against:
			lint_one(db, structures[sid], rock.get(str(rid), {}), db.source_of("structures", sid), errs)


## One structure against one rock table (tests call this with hand-made data).
static func lint_one(db: DataDB, d: Dictionary, table: Dictionary, file: String, errs: PackedStringArray) -> void:
	for key: String in ["id", "name", "label"]:
		if not (d.get(key) is String) or str(d[key]).strip_edges().is_empty():
			errs.append("%s: needs text in \"%s\"" % [file, key])
	if not db.table("codex").has(str(d.get("codex", ""))):
		errs.append("%s: codex \"%s\" does not exist" % [file, str(d.get("codex", ""))])
	var mats: Dictionary = {}  ## material id -> its data in this rock table (lookup only).
	for m: Variant in table.get("materials", []):
		if m is Dictionary:
			mats[str((m as Dictionary).get("id", ""))] = m
	var legend_v: Variant = d.get("legend", {})
	if not (legend_v is Dictionary) or (legend_v as Dictionary).is_empty():
		errs.append("%s: needs a non-empty \"legend\" object" % file)
		return
	var legend: Dictionary = legend_v
	var loot_ids: Dictionary = {}  ## loot material ids the stamp can hold (lookup only).
	var interior_chars: Dictionary = {}
	var loot_char_mat: Dictionary = {}  ## char -> loot material ids it can be.
	for k: Variant in legend.keys():
		var ch: String = str(k)
		if ch.length() != 1 or ch == " ":
			errs.append("%s: legend key \"%s\" must be one character other than a space" % [file, ch])
		var options: Array[String] = []
		var entry: Variant = legend[k]
		if entry is String:
			options.append(str(entry))
		elif entry is Dictionary:
			var ed: Dictionary = entry
			options.append(str(ed.get("material", "")))
			options.append(str(ed.get("else", "")))
			if not _num(ed.get("from_depth_m")):
				errs.append("%s: legend \"%s\" needs a number \"from_depth_m\"" % [file, ch])
		else:
			errs.append("%s: legend \"%s\" must be a material id or {\"material\", \"from_depth_m\", \"else\"}" % [file, ch])
		for mid: String in options:
			if not mats.has(mid):
				errs.append("%s: legend \"%s\" names material \"%s\", which is not in the rock table" % [file, ch, mid])
				continue
			var md: Dictionary = mats[mid]
			if bool(md.get("interior", false)) or bool(md.get("loot", false)):
				interior_chars[ch] = true
			if bool(md.get("loot", false)):
				loot_ids[mid] = true
				if not loot_char_mat.has(ch):
					loot_char_mat[ch] = []
				(loot_char_mat[ch] as Array).append(mid)
	_lint_stamp(d, legend, interior_chars, loot_char_mat, file, errs)
	if d.has("mirror") and not (d["mirror"] is bool):
		errs.append("%s: mirror must be true or false" % file)
	for key: String in ["event_chance", "trader_chance"]:
		var v: Variant = d.get(key, 0.0)
		if not _num(v) or float(v) < 0.0 or float(v) > 1.0:
			errs.append("%s: %s must be a number from 0 to 1" % [file, key])
	var trader: String = str(d.get("trader", ""))
	if not trader.is_empty() and not db.table("stores").has(trader):
		errs.append("%s: trader store \"%s\" does not exist" % [file, trader])
	if trader.is_empty() and float(d.get("trader_chance", 0.0)) > 0.0:
		errs.append("%s: trader_chance above 0 needs a trader store" % file)
	var loot: Variant = d.get("loot", [])
	_lint_loot(loot, file + " loot", errs)
	var by_mat: Variant = d.get("loot_by_material", {})
	if not (by_mat is Dictionary):
		errs.append("%s: loot_by_material must be an object" % file)
		by_mat = {}
	for k: Variant in (by_mat as Dictionary).keys():
		if not loot_ids.has(str(k)):
			errs.append("%s: loot_by_material \"%s\" is not a loot material of this stamp" % [file, str(k)])
		_lint_loot((by_mat as Dictionary)[k], "%s loot_by_material %s" % [file, str(k)], errs)
	for mid: Variant in loot_ids.keys():
		if not (by_mat as Dictionary).has(mid) and (not (loot is Array) or (loot as Array).is_empty()):
			errs.append("%s: the stamp holds crates (\"%s\") but the loot table is empty" % [file, str(mid)])


static func _lint_stamp(d: Dictionary, legend: Dictionary, interior_chars: Dictionary, loot_char_mat: Dictionary,
		file: String, errs: PackedStringArray) -> void:
	var stamp_v: Variant = d.get("stamp", [])
	if not (stamp_v is Array) or (stamp_v as Array).is_empty():
		errs.append("%s: needs a non-empty \"stamp\" list of rows" % file)
		return
	var stamp: Array = stamp_v
	var w: int = str(stamp[0]).length()
	if w == 0:
		errs.append("%s: stamp rows must not be empty" % file)
		return
	if w > MAX_STAMP_CELLS.x or stamp.size() > MAX_STAMP_CELLS.y:
		errs.append("%s: stamp is %d x %d cells (at most %d x %d)" % [file, w, stamp.size(), MAX_STAMP_CELLS.x, MAX_STAMP_CELLS.y])
	var interior: int = 0
	for r: int in range(stamp.size()):
		if not (stamp[r] is String):
			errs.append("%s: stamp[%d] must be a string" % [file, r])
			return
		var line: String = stamp[r]
		if line.length() != w:
			errs.append("%s: stamp[%d] is %d cells wide, row 0 is %d (rows must be equal)" % [file, r, line.length(), w])
			return
		for c: int in range(w):
			var ch: String = line[c]
			if ch == " ":
				continue
			if not legend.has(ch):
				errs.append("%s: stamp[%d] col %d: char \"%s\" is not in the legend" % [file, r, c, ch])
			if interior_chars.has(ch):
				interior += 1
			# Crates of different loot materials must not touch (the flood would open them as one).
			if loot_char_mat.has(ch):
				for nb: Vector2i in [Vector2i(c + 1, r), Vector2i(c, r + 1)]:
					if nb.y < stamp.size() and nb.x < w:
						var other: String = str(stamp[nb.y])[nb.x] if str(stamp[nb.y]).length() == w else " "
						if other != ch and loot_char_mat.has(other):
							errs.append("%s: stamp[%d] col %d: crates \"%s\" and \"%s\" touch" % [file, r, c, ch, other])
	if interior == 0:
		errs.append("%s: the stamp has no interior cells (an \"interior\" or \"loot\" material)" % file)


static func _lint_loot(v: Variant, where: String, errs: PackedStringArray) -> void:
	if not (v is Array):
		errs.append("%s: must be a list" % where)
		return
	var arr: Array = v
	for i: int in range(arr.size()):
		if not (arr[i] is Dictionary):
			errs.append("%s[%d]: must be an object" % [where, i])
			continue
		var row: Dictionary = arr[i]
		if not _num(row.get("weight")) or float(row["weight"]) <= 0.0:
			errs.append("%s[%d]: weight must be a number above zero" % [where, i])
		var res: String = str(row.get("res", ""))
		if not RunState.RESOURCES.has(res) or res == "hull":
			errs.append("%s[%d]: res \"%s\" must be a run resource other than hull" % [where, i, res])
		var a: Variant = row.get("amount")
		if not _num(a) or float(a) != floorf(float(a)) or int(a) <= 0:
			errs.append("%s[%d]: amount must be a whole number above zero" % [where, i])


static func _num(v: Variant) -> bool:
	return v is int or v is float


## Plain String keys in sorted order (never iterate a Dictionary for output order).
static func _sorted_keys(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in d.keys():
		out.append(str(k))
	out.sort()
	return out
