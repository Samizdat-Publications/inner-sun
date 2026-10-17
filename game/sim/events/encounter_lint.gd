class_name EncounterLint
extends RefCounted
## Checks the encounter tables: events, codex, radio, stores and crew pools. Every reference must
## resolve (pages, codex ids, enemy ships, stores, pools, resources, systems, skills) and every
## effect must be a known type with valid fields. Em dashes are already rejected when the JSON loads.
## Each problem names its file.

## "structure": started by a buried structure's break-in mid-segment, never at a node. Such an event
## lists the structures it belongs to ("structures": [ids]), needs no "rows", and may not start a
## fight (the drilling segment is still under way; a fight there is ruled out, D042).
const KINDS: Array[String] = ["event", "cavern", "hazard", "recruit", "structure"]
const CREW_RULES: Array[String] = ["first", "random", "skill:fire", "skill:repair"]
const CODEX_CATEGORIES: Array[String] = ["history", "place", "creature", "tech", "topside"]
const RADIO_TRIGGERS: Array[String] = [
	"run_start", "first_segment", "fire", "flood", "low_hull", "fight_start", "fight_won",
	"crew_died", "codex", "pursuer_close", "gate", "store", "structure",
	"hint_power", "hint_steer", "hint_hold_depth", "hint_miner", "hint_blast", "hint_bracing",
	"hint_douse", "hint_bit", "hint_crew", "hint_weapons", "hint_requisitions", "hint_map",
	"hint_pause", "hint_structure",
]
const HAZARD_KINDS: Array[String] = ["fire", "breach", "heat"]
const CREW_TARGETS: Array[String] = ["picked", "random", "all"]
## Enemy ships and weapons named before their data exists (none now: combat landed in M1 step 4).
const PENDING_SHIPS: Array[String] = []
const PENDING_WEAPONS: Array[String] = []
const MAX_REDACTIONS_PER_PAGE: int = 2


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var codex: Dictionary = db.table("codex")
	for id: Variant in codex.keys():
		_lint_codex(codex[id], db.source_of("codex", str(id)), errs)
	var radio: Dictionary = db.table("radio")
	for id: Variant in radio.keys():
		_lint_radio(radio[id], db.source_of("radio", str(id)), errs)
	var pools: Dictionary = db.table("crew")
	for id: Variant in pools.keys():
		_lint_pool(pools[id], db.source_of("crew", str(id)), errs)
	var stores: Dictionary = db.table("stores")
	for id: Variant in stores.keys():
		_lint_store(db, stores[id], db.source_of("stores", str(id)), errs)
	var events: Dictionary = db.table("events")
	for id: Variant in events.keys():
		_lint_event(db, events[id], db.source_of("events", str(id)), errs)


static func _text(d: Dictionary, key: String) -> bool:
	return d.get(key) is String and not str(d[key]).strip_edges().is_empty()


static func _num(v: Variant) -> bool:
	return v is int or v is float


static func _lint_codex(d: Dictionary, file: String, errs: PackedStringArray) -> void:
	for key: String in ["title", "text", "teaser"]:
		if not _text(d, key):
			errs.append("%s: codex needs text in \"%s\"" % [file, key])
	if not CODEX_CATEGORIES.has(str(d.get("category", ""))):
		errs.append("%s: codex category \"%s\" is not one of %s" % [file, str(d.get("category", "")), ", ".join(CODEX_CATEGORIES)])


static func _lint_radio(d: Dictionary, file: String, errs: PackedStringArray) -> void:
	if not _text(d, "layer"):
		errs.append("%s: radio file needs a \"layer\"" % file)
	var lines: Variant = d.get("lines", [])
	if not (lines is Array) or (lines as Array).is_empty():
		errs.append("%s: radio file needs a non-empty \"lines\" list" % file)
		return
	var arr: Array = lines
	for i: int in range(arr.size()):
		if not (arr[i] is Dictionary):
			errs.append("%s: lines[%d] must be an object" % [file, i])
			continue
		var line: Dictionary = arr[i]
		if not RADIO_TRIGGERS.has(str(line.get("trigger", ""))):
			errs.append("%s: lines[%d]: unknown trigger \"%s\" (known: %s)" % [file, i, str(line.get("trigger", "")), ", ".join(RADIO_TRIGGERS)])
		if not _text(line, "text"):
			errs.append("%s: lines[%d] has no text" % [file, i])


static func _lint_skills(v: Variant, where: String, errs: PackedStringArray) -> void:
	if not (v is Dictionary):
		errs.append("%s: skills must be an object" % where)
		return
	var sk: Dictionary = v
	for k: Variant in sk.keys():
		if not EventEffects.SKILLS.has(str(k)):
			errs.append("%s: unknown skill \"%s\" (known: %s)" % [where, str(k), ", ".join(EventEffects.SKILLS)])
		elif not _num(sk[k]) or float(sk[k]) <= 0.0:
			errs.append("%s: skill \"%s\" must be a number above zero" % [where, str(k)])


static func _lint_pool(d: Dictionary, file: String, errs: PackedStringArray) -> void:
	var members: Variant = d.get("members", [])
	if not (members is Array) or (members as Array).is_empty():
		errs.append("%s: crew pool needs a non-empty \"members\" list" % file)
		return
	var seen: Dictionary = {}
	var arr: Array = members
	for i: int in range(arr.size()):
		if not (arr[i] is Dictionary):
			errs.append("%s: members[%d] must be an object" % [file, i])
			continue
		var m: Dictionary = arr[i]
		var mid: String = str(m.get("id", ""))
		var where: String = "%s: members[%d] \"%s\"" % [file, i, mid]
		if mid.is_empty() or seen.has(mid) or mid.contains("_"):
			errs.append("%s: member ids must be unique, non-empty and without \"_\" (joined crew get id_<n>)" % where)
		seen[mid] = true
		if not _text(m, "name"):
			errs.append("%s: needs a name" % where)
		_lint_skills(m.get("skills", {}), where, errs)


static func _lint_store(db: DataDB, d: Dictionary, file: String, errs: PackedStringArray) -> void:
	if not _text(d, "name"):
		errs.append("%s: store needs a name" % file)
	var stock: Variant = d.get("stock", [])
	if not (stock is Array) or (stock as Array).is_empty():
		errs.append("%s: store needs a non-empty \"stock\" list" % file)
		return
	var arr: Array = stock
	for i: int in range(arr.size()):
		if not (arr[i] is Dictionary):
			errs.append("%s: stock[%d] must be an object" % [file, i])
			continue
		var s: Dictionary = arr[i]
		var item: String = str(s.get("item", ""))
		var where: String = "%s: stock[%d] (%s)" % [file, i, item]
		if not EncounterStore.ITEMS.has(item):
			errs.append("%s: unknown item (known: %s)" % [where, ", ".join(EncounterStore.ITEMS)])
			continue
		if not (s.get("price") is int or (s.get("price") is float and float(s["price"]) == floorf(float(s["price"])))) or int(s.get("price", 0)) <= 0:
			errs.append("%s: price must be a whole number above zero" % where)
		var currency: String = str(s.get("currency", "gems"))
		if not RunState.RESOURCES.has(currency) or currency == "hull":
			errs.append("%s: currency \"%s\" is not a spendable resource" % [where, currency])
		if int(s.get("limit", 0)) < 0:
			errs.append("%s: limit must be zero (none) or more" % where)
		match item:
			"res":
				var res: String = str(s.get("res", ""))
				if not RunState.RESOURCES.has(res) or res == "hull" or res == currency:
					errs.append("%s: res \"%s\" must be a resource other than hull and the currency" % [where, res])
				if int(s.get("amount", 0)) <= 0:
					errs.append("%s: amount must be above zero" % where)
			"hull":
				if int(s.get("amount", 0)) <= 0:
					errs.append("%s: amount must be above zero" % where)
			"weapon":
				var w: String = str(s.get("weapon", ""))
				if not db.table("weapons").has(w) and not PENDING_WEAPONS.has(w):
					errs.append("%s: weapon \"%s\" does not exist" % [where, w])
			"crew":
				if not db.table("crew").has(str(s.get("pool", ""))):
					errs.append("%s: crew pool \"%s\" does not exist" % [where, str(s.get("pool", ""))])
				if int(s.get("limit", 0)) != 1:
					errs.append("%s: a crew hire needs \"limit\": 1 (one candidate is rolled per visit)" % where)
			"upgrade":
				var sys: String = str(s.get("system", ""))
				if sys == "none" or not DataDB.KNOWN_SYSTEMS.has(sys):
					errs.append("%s: unknown system \"%s\"" % [where, sys])
				if int(s.get("max_bars", 0)) < 1:
					errs.append("%s: max_bars must be 1 or more" % where)


static func _lint_event(db: DataDB, d: Dictionary, file: String, errs: PackedStringArray) -> void:
	if not KINDS.has(str(d.get("kind", ""))):
		errs.append("%s: kind \"%s\" is not one of %s" % [file, str(d.get("kind", "")), ", ".join(KINDS)])
	if not _text(d, "layer"):
		errs.append("%s: needs a \"layer\"" % file)
	elif not db.table("layers").is_empty() and not db.table("layers").has(str(d["layer"])):
		errs.append("%s: layer \"%s\" does not exist" % [file, str(d["layer"])])
	var structure_kind: bool = str(d.get("kind", "")) == "structure"
	if structure_kind:
		var sl: Variant = d.get("structures", [])
		if not (sl is Array) or (sl as Array).is_empty():
			errs.append("%s: a structure event needs a non-empty \"structures\" list" % file)
		else:
			for sid: Variant in (sl as Array):
				if not db.table("structures").has(str(sid)):
					errs.append("%s: structure \"%s\" does not exist" % [file, str(sid)])
		if _has_effect(d.get("pages", {}), "fight"):
			errs.append("%s: a structure event cannot start a fight (it opens mid-segment)" % file)
	elif d.has("structures"):
		errs.append("%s: only events of kind \"structure\" list structures" % file)
	var rows: Variant = d.get("rows", [0, 0] if structure_kind else [])
	if not (rows is Array) or (rows as Array).size() != 2 or not _num((rows as Array)[0]) or not _num((rows as Array)[1]) \
			or int((rows as Array)[0]) < 0 or int((rows as Array)[0]) > int((rows as Array)[1]):
		errs.append("%s: rows must be [first, last] with 0 <= first <= last" % file)
	if d.has("weight") and (not _num(d["weight"]) or float(d["weight"]) <= 0.0):
		errs.append("%s: weight must be a number above zero" % file)
	if d.has("once_per_run") and not (d["once_per_run"] is bool):
		errs.append("%s: once_per_run must be true or false" % file)
	if d.has("crew") and not CREW_RULES.has(str(d["crew"])):
		errs.append("%s: crew rule \"%s\" is not one of %s" % [file, str(d["crew"]), ", ".join(CREW_RULES)])
	for key: String in ["title", "file"]:
		if not _text(d, key):
			errs.append("%s: needs text in \"%s\"" % [file, key])
	if not (d.get("pages") is Dictionary) or (d["pages"] as Dictionary).is_empty():
		errs.append("%s: needs a non-empty \"pages\" object" % file)
		return
	var pages: Dictionary = d["pages"]
	var start: String = str(d.get("start", ""))
	if not pages.has(start):
		errs.append("%s: start page \"%s\" does not exist" % [file, start])
	var reached: Dictionary = {start: true}
	for pid: Variant in pages.keys():
		var where: String = "%s: page \"%s\"" % [file, str(pid)]
		if not (pages[pid] is Dictionary):
			errs.append("%s: must be an object" % where)
			continue
		var pg: Dictionary = pages[pid]
		if not _text(pg, "text"):
			errs.append("%s: has no text" % where)
		else:
			_lint_text(db, str(pg["text"]), where, errs, true)
		if pg.has("radio") and not _text(pg, "radio"):
			errs.append("%s: radio must be non-empty text" % where)
		var options: Variant = pg.get("options", [])
		if not (options is Array):
			errs.append("%s: options must be a list" % where)
			continue
		var opts: Array = options
		for oi: int in range(opts.size()):
			_lint_option(db, opts[oi], pages, "%s option %d" % [where, oi], errs, reached)
	for pid: Variant in pages.keys():
		if not reached.has(str(pid)):
			errs.append("%s: page \"%s\" is never reached" % [file, str(pid)])


## True if any outcome on any page has an effect of this type.
static func _has_effect(pages: Variant, kind: String) -> bool:
	if not (pages is Dictionary):
		return false
	for pg: Variant in (pages as Dictionary).values():
		if not (pg is Dictionary):
			continue
		for opt: Variant in ((pg as Dictionary).get("options", []) as Array):
			if not (opt is Dictionary):
				continue
			for o: Variant in ((opt as Dictionary).get("outcomes", []) as Array):
				if not (o is Dictionary):
					continue
				for e: Variant in ((o as Dictionary).get("effects", []) as Array):
					if e is Dictionary and str((e as Dictionary).get("type", "")) == kind:
						return true
	return false


static func _lint_option(db: DataDB, v: Variant, pages: Dictionary, where: String, errs: PackedStringArray, reached: Dictionary) -> void:
	if not (v is Dictionary):
		errs.append("%s: must be an object" % where)
		return
	var opt: Dictionary = v
	if not _text(opt, "text"):
		errs.append("%s: has no text" % where)
	else:
		_lint_text(db, str(opt["text"]), where, errs, false)
	if opt.has("requires"):
		_lint_requires(db, opt["requires"], where, errs)
	var outcomes: Variant = opt.get("outcomes", [])
	if not (outcomes is Array) or (outcomes as Array).is_empty():
		errs.append("%s: needs at least one outcome" % where)
		return
	var arr: Array = outcomes
	for i: int in range(arr.size()):
		var ow: String = "%s outcome %d" % [where, i]
		if not (arr[i] is Dictionary):
			errs.append("%s: must be an object" % ow)
			continue
		var o: Dictionary = arr[i]
		if not _num(o.get("weight")) or float(o["weight"]) <= 0.0:
			errs.append("%s: weight must be a number above zero" % ow)
		if o.has("page"):
			if not pages.has(str(o["page"])):
				errs.append("%s: page \"%s\" does not exist" % [ow, str(o["page"])])
			reached[str(o["page"])] = true
		var effects: Variant = o.get("effects", [])
		if not (effects is Array):
			errs.append("%s: effects must be a list" % ow)
			continue
		var eff: Array = effects
		for ei: int in range(eff.size()):
			_lint_effect(db, eff[ei], "%s effect %d" % [ow, ei], errs)


static func _lint_requires(db: DataDB, v: Variant, where: String, errs: PackedStringArray) -> void:
	if not (v is Dictionary):
		errs.append("%s: requires must be an object" % where)
		return
	var req: Dictionary = v
	for k: Variant in req.keys():
		var key: String = str(k)
		match key:
			"res":
				var res: Dictionary = req[k] if req[k] is Dictionary else {}
				for r: Variant in res.keys():
					if not RunState.RESOURCES.has(str(r)) or not _num(res[r]) or int(res[r]) < 1:
						errs.append("%s: requires res \"%s\" must be a known resource and a count of 1 or more" % [where, str(r)])
			"system":
				var sys: Dictionary = req[k] if req[k] is Dictionary else {}
				for s: Variant in sys.keys():
					if str(s) == "none" or not DataDB.KNOWN_SYSTEMS.has(str(s)) or not _num(sys[s]) or int(sys[s]) < 1:
						errs.append("%s: requires system \"%s\" must be a known system and 1 or more bars" % [where, str(s)])
			"skill":
				_lint_skills(req[k], where + " requires", errs)
			"codex":
				if not db.table("codex").has(str(req[k])):
					errs.append("%s: requires codex \"%s\" does not exist" % [where, str(req[k])])
			_:
				errs.append("%s: unknown requirement \"%s\" (known: res, system, skill, codex)" % [where, key])


static func _lint_effect(db: DataDB, v: Variant, where: String, errs: PackedStringArray) -> void:
	if not (v is Dictionary):
		errs.append("%s: must be an object" % where)
		return
	var e: Dictionary = v
	var kind: String = str(e.get("type", ""))
	match kind:
		"res":
			_need_res(e, where, errs)
			if not (e.get("amount") is int or e.get("amount") is float) or int(e["amount"]) == 0:
				errs.append("%s: res needs a non-zero whole \"amount\"" % where)
		"res_range":
			_need_res(e, where, errs)
			if not _num(e.get("min")) or not _num(e.get("max")) or int(e["min"]) > int(e["max"]):
				errs.append("%s: res_range needs numbers min <= max" % where)
		"hull":
			if not _num(e.get("amount")) or int(e["amount"]) == 0:
				errs.append("%s: hull needs a non-zero \"amount\"" % where)
		"crew_damage":
			if not CREW_TARGETS.has(str(e.get("target", ""))):
				errs.append("%s: target must be one of %s" % [where, ", ".join(CREW_TARGETS)])
			if not _num(e.get("amount")) or float(e["amount"]) <= 0.0:
				errs.append("%s: crew_damage needs an amount above zero" % where)
		"crew_join":
			if not db.table("crew").has(str(e.get("pool", ""))):
				errs.append("%s: crew pool \"%s\" does not exist" % [where, str(e.get("pool", ""))])
		"crew_lose":
			var t: String = str(e.get("target", ""))
			if t != "picked" and t != "random":
				errs.append("%s: crew_lose target must be picked or random" % where)
		"fight":
			var enemy: String = str(e.get("enemy", ""))
			if not db.ships.has(enemy) and not PENDING_SHIPS.has(enemy):
				errs.append("%s: enemy ship \"%s\" does not exist" % [where, enemy])
			if e.has("boss") and not (e["boss"] is bool):
				errs.append("%s: boss must be true or false" % where)
		"hazard":
			var hk: String = str(e.get("kind", ""))
			if not HAZARD_KINDS.has(hk):
				errs.append("%s: hazard kind must be one of %s" % [where, ", ".join(HAZARD_KINDS)])
			var room: String = str(e.get("room", ""))
			if room != "random" and not (room.begins_with("system:") and DataDB.KNOWN_SYSTEMS.has(room.substr(7)) and room != "system:none"):
				errs.append("%s: room must be \"random\" or \"system:<system>\", not \"%s\"" % [where, room])
			if not _num(e.get("level")) or float(e["level"]) <= 0.0 or (hk == "fire" and float(e["level"]) > 1.0):
				errs.append("%s: level must be above zero (fire at most 1)" % where)
		"system_damage":
			var sys: String = str(e.get("system", ""))
			if sys == "none" or not DataDB.KNOWN_SYSTEMS.has(sys):
				errs.append("%s: unknown system \"%s\"" % [where, sys])
			if not _num(e.get("bars")) or int(e["bars"]) < 1:
				errs.append("%s: system_damage needs bars of 1 or more" % where)
		"codex":
			if not db.table("codex").has(str(e.get("id", ""))):
				errs.append("%s: codex \"%s\" does not exist" % [where, str(e.get("id", ""))])
		"pursuer":
			if not _num(e.get("rows")):
				errs.append("%s: pursuer needs a number of rows" % where)
		"reveal":
			if not _num(e.get("rows")) or int(e["rows"]) < 1:
				errs.append("%s: reveal needs rows of 1 or more" % where)
		"store":
			if not db.table("stores").has(str(e.get("store", ""))):
				errs.append("%s: store \"%s\" does not exist" % [where, str(e.get("store", ""))])
		_:
			errs.append("%s: unknown effect type \"%s\" (known: %s)" % [where, kind, ", ".join(EventEffects.TYPES)])


static func _need_res(e: Dictionary, where: String, errs: PackedStringArray) -> void:
	var res: String = str(e.get("res", ""))
	if not RunState.RESOURCES.has(res):
		errs.append("%s: unknown resource \"%s\" (known: %s)" % [where, res, ", ".join(RunState.RESOURCES)])


## {crew} is the only placeholder; [[codex:words]] redactions must name real codex entries.
static func _lint_text(db: DataDB, text: String, where: String, errs: PackedStringArray, is_page: bool) -> void:
	var stripped: String = text.replace("{crew}", "")
	if stripped.contains("{") or stripped.contains("}"):
		errs.append("%s: unknown placeholder (only {crew} is allowed)" % where)
	var count: int = 0
	var at: int = text.find("[[")
	while at >= 0:
		var close: int = text.find("]]", at)
		if close < 0:
			errs.append("%s: redaction \"[[\" is never closed" % where)
			return
		var body: String = text.substr(at + 2, close - at - 2)
		var colon: int = body.find(":")
		if colon <= 0 or colon == body.length() - 1:
			errs.append("%s: redaction must be [[codex_id:words]]" % where)
		elif not db.table("codex").has(body.substr(0, colon)):
			errs.append("%s: redaction names codex \"%s\", which does not exist" % [where, body.substr(0, colon)])
		count += 1
		at = text.find("[[", close)
	if text.count("]]") != count:
		errs.append("%s: stray \"]]\"" % where)
	if is_page and count > MAX_REDACTIONS_PER_PAGE:
		errs.append("%s: %d redactions (at most %d per page)" % [where, count, MAX_REDACTIONS_PER_PAGE])
