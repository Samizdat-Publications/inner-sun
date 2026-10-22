class_name StoreRoll
extends RefCounted
## Rolls one store visit's stock (parity L-STO-01 to L-STO-04, docs/plans/specs/m2p_economy.md).
## Static: the Sim is passed in. Randomness only from the "store" stream, and a FIXED number of draws
## per visit whatever is eligible (one per supply line, one for the section count, one per section
## for the section order, and per section one for its offer count plus one per pool line), all drawn
## first, so one chance never shifts another.
##
## Store data v2 (game/data/stores/<id>.json): "supplies" (always shown: "res" lines with a rolled
## "stock": [lo, hi] of units, "hull" lines with "price_by_row": [{"from_row", "price"}], unlimited),
## "sections_shown": [lo, hi], "sections": [{"id", "weight", "offers": [lo, hi], "pool": [lines with
## "rarity" 1 to 5]}]. Sections are picked weighted without replacement; a picked section with no
## eligible offer gives its place to the next one in the drawn order. Offers are picked weighted by
## rarity and depth without replacement: weight = economy.store_rarity_weight_<r> x
## (1 + economy.store_rarity_depth_gain_<r> x row / (rows - 1)).
##
## A visit line: {"section", "item", "res", "amount", "system", "gear", "weapon", "pool", "price",
## "currency", "text", "rarity", "stock"} ("stock": units left, -1 for unlimited; "price": the price
## of the next unit, for an upgrade the next bar on the system's ladder, 0 at its top).

const SECTION_IDS: Array[String] = ["systems", "gear", "weapons", "crew"]
const SECTION_ITEM: Dictionary = {"systems": "upgrade", "gear": "gear", "weapons": "weapon", "crew": "crew"}
const SUPPLY_ITEMS: Array[String] = ["res", "hull"]
const RARITY_MAX: int = 5


## The visit's lines: supplies first, then the shown sections in data order.
static func roll(sim: Sim, st: Dictionary, row: int, rows: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = sim.rng.get_stream("store")
	var supplies: Array = st.get("supplies", [])
	var sections: Array = st.get("sections", [])
	# Every draw first, in a fixed order and number.
	var u_supply := PackedFloat64Array()
	for i: int in range(supplies.size()):
		u_supply.append(rng.randf())
	var u_count: float = rng.randf()
	var u_order := PackedFloat64Array()
	for i: int in range(sections.size()):
		u_order.append(rng.randf())
	var u_offers := PackedFloat64Array()
	var u_picks: Array[PackedFloat64Array] = []
	for sv: Variant in sections:
		u_offers.append(rng.randf())
		var picks := PackedFloat64Array()
		for j: int in range(((sv as Dictionary).get("pool", []) as Array).size()):
			picks.append(rng.randf())
		u_picks.append(picks)
	var out: Array[Dictionary] = []
	for i: int in range(supplies.size()):
		var d: Dictionary = supplies[i]
		out.append(line(sim, d, "supplies", row, _span(d.get("stock", []), u_supply[i], -1)))
	# Which sections show.
	var shown_n: int = _span(st.get("sections_shown", []), u_count, 0)
	var weights := PackedFloat64Array()
	for sv: Variant in sections:
		weights.append(maxf(0.0, float((sv as Dictionary).get("weight", 0.0))))
	var order: PackedInt32Array = _order(weights, u_order)
	var chosen: Dictionary = {}  ## section index -> its picked pool indexes (lookup only).
	for si: int in order:
		if chosen.size() >= shown_n:
			break
		var picks: PackedInt32Array = _offers(sim, sections[si], row, rows, u_offers[si], u_picks[si])
		if not picks.is_empty():
			chosen[si] = picks
	for si: int in range(sections.size()):
		if not chosen.has(si):
			continue
		var sec: Dictionary = sections[si]
		var pool: Array = sec.get("pool", [])
		for pi: int in (chosen[si] as PackedInt32Array):
			out.append(line(sim, pool[pi], str(sec.get("id", "")), row, 1 if str((pool[pi] as Dictionary).get("item", "")) != "upgrade" else -1))
	return out


## The pool indexes a section offers this visit, in pick order (empty: nothing eligible).
static func _offers(sim: Sim, sec: Dictionary, row: int, rows: int, u_n: float, u: PackedFloat64Array) -> PackedInt32Array:
	var pool: Array = sec.get("pool", [])
	var cand := PackedInt32Array()
	var w := PackedFloat64Array()
	for i: int in range(pool.size()):
		var d: Dictionary = pool[i]
		if eligible(sim, d):
			cand.append(i)
			w.append(rarity_weight(sim.db, int(d.get("rarity", 1)), row, rows))
	var n: int = mini(_span(sec.get("offers", []), u_n, 1), cand.size())
	var out := PackedInt32Array()
	for k: int in range(n):
		var total: float = 0.0
		for x: float in w:
			total += x
		var pick: int = -1
		if total > 0.0:
			var r: float = u[k] * total
			for j: int in range(w.size()):
				if w[j] <= 0.0:
					continue
				r -= w[j]
				pick = j
				if r < 0.0:
					break
		if pick < 0:
			break
		out.append(cand[pick])
		w[pick] = 0.0  # Without replacement.
	return out


## A full weighted order without replacement: draw k picks among the indexes not yet placed.
static func _order(weights: PackedFloat64Array, u: PackedFloat64Array) -> PackedInt32Array:
	var w: PackedFloat64Array = weights.duplicate()
	var out := PackedInt32Array()
	for k: int in range(w.size()):
		var total: float = 0.0
		for x: float in w:
			total += x
		if total <= 0.0:
			break
		var r: float = u[k] * total
		var pick: int = -1
		for j: int in range(w.size()):
			if w[j] <= 0.0:
				continue
			r -= w[j]
			pick = j
			if r < 0.0:
				break
		out.append(pick)
		w[pick] = 0.0
	return out


## A whole number in [lo, hi] from one draw; `none` when the span is missing.
static func _span(v: Variant, u: float, none: int) -> int:
	if not (v is Array) or (v as Array).size() != 2:
		return none
	var lo: int = int((v as Array)[0])
	var hi: int = maxi(lo, int((v as Array)[1]))
	return mini(hi, lo + int(u * float(hi - lo + 1)))


## Rarity weight at a depth: weight_r x (1 + gain_r x row / (rows - 1)).
static func rarity_weight(db: DataDB, rarity: int, row: int, rows: int) -> float:
	var r: int = clampi(rarity, 1, RARITY_MAX)
	var depth: float = 0.0
	if rows > 1:
		depth = float(clampi(row, 0, rows - 1)) / float(rows - 1)
	return db.tune("economy.store_rarity_weight_%d" % r) * (1.0 + db.tune("economy.store_rarity_depth_gain_%d" % r) * depth)


## Whether a pool line may be offered to this ship now.
static func eligible(sim: Sim, d: Dictionary) -> bool:
	match str(d.get("item", "")):
		"upgrade":
			var sys: String = str(d.get("system", ""))
			var ri: int = sim.ship.room_with_system(sys)
			return ri >= 0 and sim.ship.rooms[ri].sys_max < ladder(sim.db, sys).size()
		"gear":
			return Gear.refusal(sim, str(d.get("gear", ""))).is_empty()
	return true


## A system's bar price ladder (entry i is the price of bar i + 1).
static func ladder(db: DataDB, system: String) -> Array:
	return (db.table("systems").get(system, {}) as Dictionary).get("bar_prices", [])


## The price of the next bar of a system on this ship (0 at its top or without the system).
static func next_bar_price(sim: Sim, system: String) -> int:
	var ri: int = sim.ship.room_with_system(system)
	var lad: Array = ladder(sim.db, system)
	if ri < 0 or sim.ship.rooms[ri].sys_max >= lad.size():
		return 0
	return int(lad[sim.ship.rooms[ri].sys_max])


## The per-unit hull price at a row: the last step whose from_row is at or below it.
static func hull_price(d: Dictionary, row: int) -> int:
	var price: int = int(d.get("price", 0))
	for step: Variant in d.get("price_by_row", []):
		var sd: Dictionary = step
		if row >= int(sd.get("from_row", 0)):
			price = int(sd.get("price", 0))
	return price


## A visit line built from a data line, its section and its stock.
static func line(sim: Sim, d: Dictionary, section: String, row: int, stock: int) -> Dictionary:
	var item: String = str(d.get("item", ""))
	var price: int = int(d.get("price", 0))
	var currency: String = str(d.get("currency", "gems"))
	match item:
		"upgrade":
			price = next_bar_price(sim, str(d.get("system", "")))
			currency = "ore"
		"hull":
			price = hull_price(d, row)
		"gear", "weapon":
			var table: String = "gear" if item == "gear" else "weapons"
			var def: Dictionary = sim.db.table(table).get(str(d.get(item, "")), {})
			if not d.has("price"):
				price = int(def.get("price", 0))
			if not d.has("currency"):
				currency = str(def.get("currency", "gems"))
	return {"section": section, "item": item, "res": str(d.get("res", "")), "amount": int(d.get("amount", 0)),
		"system": str(d.get("system", "")), "gear": str(d.get("gear", "")), "weapon": str(d.get("weapon", "")),
		"pool": str(d.get("pool", "")), "price": price, "currency": currency, "text": str(d.get("text", "")),
		"rarity": int(d.get("rarity", 0)), "stock": stock}


# Lint ------------------------------------------------------------------------------------------

## Stores (v2 format above), the system price ladders and the weapons' list prices.
static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var stores: Dictionary = db.table("stores")
	for id: Variant in stores.keys():
		_lint_store(db, stores[id], db.source_of("stores", str(id)), errs)
	_lint_ladders(db, errs)
	var weapons: Dictionary = db.table("weapons")
	for id: Variant in weapons.keys():
		var w: Dictionary = weapons[id]
		if not _whole_above_zero(w.get("price")) or not _spendable(str(w.get("currency", ""))):
			errs.append("%s: a weapon needs a \"price\" (whole, above zero) and a spendable \"currency\"" % db.source_of("weapons", str(id)))


## Ladders are whole numbers above zero; every ladder but the reactor's strictly rises (L-UPG-01),
## the reactor's never falls (L-UPG-02).
static func _lint_ladders(db: DataDB, errs: PackedStringArray) -> void:
	var table: Dictionary = db.table("systems")
	for id: Variant in table.keys():
		var file: String = db.source_of("systems", str(id))
		var lad: Variant = (table[id] as Dictionary).get("bar_prices", null)
		if not (lad is Array) or (lad as Array).is_empty():
			errs.append("%s: needs \"bar_prices\", a non-empty list of whole ore prices (entry i is bar i + 1)" % file)
			continue
		var arr: Array = lad
		for i: int in range(arr.size()):
			if not _whole_above_zero(arr[i]):
				errs.append("%s: bar_prices[%d] must be a whole number above zero" % [file, i])
				break
			if i == 0:
				continue
			if str(id) == "reactor" and float(arr[i]) < float(arr[i - 1]):
				errs.append("%s: the reactor's bar_prices never fall (bar %d)" % [file, i + 1])
				break
			if str(id) != "reactor" and float(arr[i]) <= float(arr[i - 1]):
				errs.append("%s: bar_prices must rise bar by bar (bar %d)" % [file, i + 1])
				break


static func _whole_above_zero(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v)) and float(v) > 0.0


static func _spendable(cur: String) -> bool:
	return RunState.RESOURCES.has(cur) and cur != "hull"


static func _span_ok(v: Variant, lo_min: int) -> bool:
	if not (v is Array) or (v as Array).size() != 2:
		return false
	var a: Array = v
	if not (a[0] is int or a[0] is float) or not (a[1] is int or a[1] is float):
		return false
	return float(a[0]) == floorf(float(a[0])) and float(a[1]) == floorf(float(a[1])) and int(a[0]) >= lo_min and int(a[0]) <= int(a[1])


static func _lint_store(db: DataDB, d: Dictionary, file: String, errs: PackedStringArray) -> void:
	if not (d.get("name") is String) or str(d["name"]).strip_edges().is_empty():
		errs.append("%s: store needs a name" % file)
	if d.has("stock"):
		errs.append("%s: \"stock\" is the old store format; use \"supplies\" and \"sections\"" % file)
	var seen: Dictionary = {}  ## item key -> true, lookup only.
	var supplies: Variant = d.get("supplies", [])
	if not (supplies is Array) or (supplies as Array).is_empty():
		errs.append("%s: store needs a non-empty \"supplies\" list" % file)
	else:
		var arr: Array = supplies
		for i: int in range(arr.size()):
			_lint_supply(arr[i], "%s: supplies[%d]" % [file, i], errs, seen)
	var sections: Variant = d.get("sections", [])
	if not (sections is Array):
		errs.append("%s: \"sections\" must be a list" % file)
		return
	var secs: Array = sections
	if not _span_ok(d.get("sections_shown", []), 0) or int((d["sections_shown"] as Array)[1]) > secs.size():
		errs.append("%s: sections_shown must be [lo, hi], whole, 0 <= lo <= hi <= the number of sections" % file)
	var ids: Dictionary = {}
	for si: int in range(secs.size()):
		var where: String = "%s: sections[%d]" % [file, si]
		if not (secs[si] is Dictionary):
			errs.append("%s: must be an object" % where)
			continue
		var sec: Dictionary = secs[si]
		var sid: String = str(sec.get("id", ""))
		if not SECTION_IDS.has(sid) or ids.has(sid):
			errs.append("%s: id \"%s\" must be one of %s, once each" % [where, sid, ", ".join(SECTION_IDS)])
		ids[sid] = true
		if not (sec.get("weight") is int or sec.get("weight") is float) or float(sec["weight"]) <= 0.0:
			errs.append("%s: weight must be a number above zero" % where)
		if not _span_ok(sec.get("offers", []), 1):
			errs.append("%s: offers must be [lo, hi], whole, 1 <= lo <= hi" % where)
		var pool: Variant = sec.get("pool", [])
		if not (pool is Array) or (pool as Array).is_empty():
			errs.append("%s: needs a non-empty \"pool\"" % where)
			continue
		for pi: int in range((pool as Array).size()):
			_lint_offer(db, (pool as Array)[pi], str(SECTION_ITEM.get(sid, "")), "%s pool[%d]" % [where, pi], errs, seen)


static func _lint_supply(v: Variant, where: String, errs: PackedStringArray, seen: Dictionary) -> void:
	if not (v is Dictionary):
		errs.append("%s: must be an object" % where)
		return
	var s: Dictionary = v
	var item: String = str(s.get("item", ""))
	if not SUPPLY_ITEMS.has(item):
		errs.append("%s: supplies sell %s only, not \"%s\"" % [where, ", ".join(SUPPLY_ITEMS), item])
		return
	if not (s.get("text") is String) or str(s["text"]).strip_edges().is_empty():
		errs.append("%s: needs a text" % where)
	var currency: String = str(s.get("currency", "gems"))
	if not _spendable(currency):
		errs.append("%s: currency \"%s\" is not a spendable resource" % [where, currency])
	if not _whole_above_zero(s.get("amount")):
		errs.append("%s: amount must be a whole number above zero" % where)
	var key: String = "%s:%s" % [item, str(s.get("res", ""))]
	if seen.has(key):
		errs.append("%s: %s is sold twice in this store" % [where, key])
	seen[key] = true
	if item == "res":
		var res: String = str(s.get("res", ""))
		if not RunState.RESOURCES.has(res) or res == "hull" or res == currency:
			errs.append("%s: res \"%s\" must be a resource other than hull and the currency" % [where, res])
		if not _whole_above_zero(s.get("price")):
			errs.append("%s: price must be a whole number above zero" % where)
		if not _span_ok(s.get("stock", []), 1):
			errs.append("%s: stock must be [lo, hi] units per visit, whole, 1 <= lo <= hi" % where)
		return
	var steps: Variant = s.get("price_by_row", [])
	if not (steps is Array) or (steps as Array).is_empty():
		errs.append("%s: a hull line needs \"price_by_row\": [{\"from_row\", \"price\"}]" % where)
		return
	var last_row: int = -1
	var last_price: int = 0
	for i: int in range((steps as Array).size()):
		var st: Variant = (steps as Array)[i]
		if not (st is Dictionary) or not _whole_above_zero((st as Dictionary).get("price")) \
				or not ((st as Dictionary).get("from_row") is int or (st as Dictionary).get("from_row") is float):
			errs.append("%s: price_by_row[%d] needs a whole from_row and a whole price above zero" % [where, i])
			return
		var fr: int = int((st as Dictionary)["from_row"])
		var pr: int = int((st as Dictionary)["price"])
		if (i == 0 and fr != 0) or fr <= last_row or pr < last_price:
			errs.append("%s: price_by_row starts at row 0, rows rise and prices never fall (step %d)" % [where, i])
		last_row = fr
		last_price = pr


static func _lint_offer(db: DataDB, v: Variant, want_item: String, where: String, errs: PackedStringArray, seen: Dictionary) -> void:
	if not (v is Dictionary):
		errs.append("%s: must be an object" % where)
		return
	var s: Dictionary = v
	var item: String = str(s.get("item", ""))
	if item != want_item:
		errs.append("%s: this section sells \"%s\", not \"%s\"" % [where, want_item, item])
		return
	if not (s.get("text") is String) or str(s["text"]).strip_edges().is_empty():
		errs.append("%s: needs a text" % where)
	var rarity: Variant = s.get("rarity")
	if not _whole_above_zero(rarity) or int(rarity) > RARITY_MAX:
		errs.append("%s: rarity must be a whole number 1 to %d" % [where, RARITY_MAX])
	for k: String in ["limit", "max_bars"]:
		if s.has(k):
			errs.append("%s: \"%s\" is gone (stock is rolled, the ladder sets the top)" % [where, k])
	if s.has("price") and not _whole_above_zero(s["price"]):
		errs.append("%s: price must be a whole number above zero" % where)
	if s.has("currency") and not _spendable(str(s["currency"])):
		errs.append("%s: currency \"%s\" is not a spendable resource" % [where, str(s["currency"])])
	var key: String = item
	match item:
		"upgrade":
			var sys: String = str(s.get("system", ""))
			key += ":" + sys
			if sys == "none" or not DataDB.KNOWN_SYSTEMS.has(sys) or not db.table("systems").has(sys):
				errs.append("%s: unknown system \"%s\"" % [where, sys])
			if s.has("price") or s.has("currency"):
				errs.append("%s: an upgrade's price is the system's bar_prices (ore); drop price and currency" % where)
		"gear":
			key += ":" + str(s.get("gear", ""))
			if not db.table("gear").has(str(s.get("gear", ""))):
				errs.append("%s: gear \"%s\" does not exist" % [where, str(s.get("gear", ""))])
		"weapon":
			key += ":" + str(s.get("weapon", ""))
			if not db.table("weapons").has(str(s.get("weapon", ""))):
				errs.append("%s: weapon \"%s\" does not exist" % [where, str(s.get("weapon", ""))])
		"crew":
			key += ":" + str(s.get("pool", ""))
			if not db.table("crew").has(str(s.get("pool", ""))):
				errs.append("%s: crew pool \"%s\" does not exist" % [where, str(s.get("pool", ""))])
			if not _whole_above_zero(s.get("price")):
				errs.append("%s: a crew hire needs a price, a whole number above zero" % where)
	if seen.has(key):
		errs.append("%s: %s is offered twice in this store (never the same item twice)" % [where, key])
	seen[key] = true
