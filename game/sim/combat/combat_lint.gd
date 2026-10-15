class_name CombatLint
extends RefCounted
## Checks the weapons table, every ship's weapon loadout and enemy "ai" block, and the combat tuning.
## Each problem names its file. Em dashes are already rejected when the JSON loads.

const NUMBERS: Array[String] = [
	"charge_s", "damage", "sys_damage", "crew_damage", "fire_chance", "breach_chance", "breach_m2",
	"heat_kj", "speed_m_s", "beam_len_m",
]


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var weapons: Dictionary = db.table("weapons")
	for id: Variant in weapons.keys():
		_lint_weapon(weapons[id], db.source_of("weapons", str(id)), errs)
	for id: Variant in db.ships.keys():
		_lint_ship(db, db.ships[id], db.source_of("ships", str(id)), errs)
	for key: String in CombatSim.TUNING_KEYS:
		if not db.tuning.has(key):
			errs.append("%s/tuning: missing number \"%s\"" % [db.root, key])


static func _num(v: Variant) -> bool:
	return v is int or v is float


static func _lint_weapon(d: Dictionary, file: String, errs: PackedStringArray) -> void:
	for key: String in ["name", "blurb"]:
		if not (d.get(key) is String) or str(d[key]).strip_edges().is_empty():
			errs.append("%s: weapon needs text in \"%s\"" % [file, key])
	var kind: String = str(d.get("kind", ""))
	if not WeaponDef.KINDS.has(kind):
		errs.append("%s: weapon kind \"%s\" is not one of %s" % [file, kind, ", ".join(WeaponDef.KINDS)])
	for key: String in NUMBERS:
		if not _num(d.get(key)) or float(d[key]) < 0.0:
			errs.append("%s: \"%s\" must be a number, zero or more" % [file, key])
	for key: String in ["power", "shots"]:
		if not _num(d.get(key)) or int(d[key]) < 1:
			errs.append("%s: \"%s\" must be a whole number, 1 or more" % [file, key])
	if _num(d.get("charge_s")) and float(d["charge_s"]) <= 0.0:
		errs.append("%s: charge_s must be above zero" % file)
	for key: String in ["fire_chance", "breach_chance"]:
		if _num(d.get(key)) and float(d[key]) > 1.0:
			errs.append("%s: \"%s\" is a chance, 0 to 1" % [file, key])
	if (kind == "projectile" or kind == "charge") and float(d.get("speed_m_s", 0.0)) <= 0.0:
		errs.append("%s: a %s needs speed_m_s above zero" % [file, kind])
	if kind == "beam" and float(d.get("beam_len_m", 0.0)) <= 0.0:
		errs.append("%s: a beam needs beam_len_m above zero" % file)
	var ammo: String = str(d.get("ammo", ""))
	if not ammo.is_empty() and not RunState.RESOURCES.has(ammo):
		errs.append("%s: ammo \"%s\" is not a resource (%s)" % [file, ammo, ", ".join(RunState.RESOURCES)])
	if kind == "charge" and ammo.is_empty():
		errs.append("%s: a charge weapon needs an \"ammo\" resource" % file)
	if not (d.get("pierces_bracing") is bool):
		errs.append("%s: pierces_bracing must be true or false" % file)


static func _lint_ship(db: DataDB, def: Dictionary, file: String, errs: PackedStringArray) -> void:
	var weapons: Dictionary = db.table("weapons")
	var rooms: Dictionary = {}  ## room id -> system
	var weapon_bars: int = 0
	for rd: Variant in def.get("rooms", []):
		if rd is Dictionary:
			var r: Dictionary = rd
			rooms[str(r.get("id", ""))] = str(r.get("system", "none"))
			if str(r.get("system", "none")) == "weapons":
				weapon_bars = maxi(weapon_bars, int(r.get("bars", 0)))
	var list: Variant = def.get("weapons", [])
	if not (list is Array):
		errs.append("%s: \"weapons\" must be a list of weapon ids" % file)
		return
	var need: int = 0
	for w: Variant in list:
		var wid: String = str(w)
		if not weapons.has(wid):
			errs.append("%s: weapon \"%s\" does not exist" % [file, wid])
			continue
		need += int((weapons[wid] as Dictionary).get("power", 1))
	var mounted: int = (list as Array).size()
	if mounted > 0 and weapon_bars <= 0:
		errs.append("%s: ship mounts weapons but has no weapons room with bars" % file)
	if need > weapon_bars and mounted > 0:
		errs.append("%s: the starting weapons need %d bars but the weapons room has %d" % [file, need, weapon_bars])
	var slots: int = int(def.get("weapon_slots", 0))
	if slots > 0 and mounted > slots:
		errs.append("%s: %d weapons mounted in %d slots" % [file, mounted, slots])
	if not def.has("ai"):
		return
	if not (def["ai"] is Dictionary):
		errs.append("%s: \"ai\" must be an object" % file)
		return
	var ai: Dictionary = def["ai"]
	if not (ai.get("power", []) is Array):
		errs.append("%s: ai.power must be a list" % file)
		return
	for i: int in range((ai.get("power", []) as Array).size()):
		var step: Variant = (ai["power"] as Array)[i]
		if not (step is Dictionary):
			errs.append("%s: ai.power[%d] must be {\"room\", \"bars\"}" % [file, i])
			continue
		var rid: String = str((step as Dictionary).get("room", ""))
		var sys: String = str(rooms.get(rid, ""))
		if sys.is_empty():
			errs.append("%s: ai.power[%d]: room \"%s\" does not exist" % [file, i, rid])
		elif sys == "none" or sys == "reactor":
			errs.append("%s: ai.power[%d]: room \"%s\" takes no power" % [file, i, rid])
		if not _num((step as Dictionary).get("bars")) or int((step as Dictionary)["bars"]) < 0:
			errs.append("%s: ai.power[%d]: bars must be a whole number, zero or more" % [file, i])
	var tw: Variant = ai.get("target_weights", {})
	if not (tw is Dictionary):
		errs.append("%s: ai.target_weights must be an object" % file)
		return
	for k: Variant in (tw as Dictionary).keys():
		if not DataDB.KNOWN_SYSTEMS.has(str(k)):
			errs.append("%s: ai.target_weights: unknown system \"%s\"" % [file, str(k)])
		if not _num((tw as Dictionary)[k]) or float((tw as Dictionary)[k]) < 0.0:
			errs.append("%s: ai.target_weights.%s must be a number, zero or more" % [file, str(k)])
	if (def.get("crew", []) as Array).is_empty():
		errs.append("%s: an enemy ship with an ai needs crew" % file)
