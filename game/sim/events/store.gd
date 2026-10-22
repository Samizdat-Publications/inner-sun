class_name EncounterStore
extends RefCounted
## The store's rules: {"type": "buy", "item": i, "qty": n} buys n units of visit line i, and
## {"type": "sell", "what": "weapon" | "gear", "id": id} sells one owned weapon or piece of gear back.
## A purchase or a sale is all or nothing: it is checked completely first, then paid with one exact
## run.add and delivered. A refused command emits bad_command and changes nothing. Static: the Sim
## and the Encounter are passed in.
##
## The visit's lines are rolled by StoreRoll when the store opens (format there). Per item: "res"
## (res, amount), "hull" (amount, never above the ship's maximum, priced by row), "weapon" (appended
## to ship.weapons), "crew" (hires the member rolled when the store opened), "upgrade" (system: +1 bar
## per unit, each unit priced at the next entry of the system's "bar_prices" ladder; no per-visit cap,
## refused past the ladder's top), "gear" (a data/gear id, one at a time, fitted with Gear.fit;
## refused when Gear.refusal says so). A line with "stock" >= 0 sells at most that many units.
## Currency by line (M1b, D025): ore buys system upgrades, gear and hull repairs; gems buy supplies
## (coolant, cells, bits, charges), crew and weapons.
## Selling (L-STO-05) pays floor(list price x economy.sell_back_frac) in the item's own currency.

const ITEMS: Array[String] = ["res", "hull", "weapon", "crew", "upgrade", "gear"]
const SELL_WHAT: Array[String] = ["weapon", "gear"]


static func buy(sim: Sim, enc: Encounter, line: int, qty: int) -> void:
	var why: String = refusal(sim, enc, line, qty)
	if not why.is_empty():
		sim.emit("bad_command", {"type": "buy", "why": why})
		return
	var d: Dictionary = stock_line(enc, line)
	var currency: String = str(d.get("currency", "gems"))
	var cost: int = cost_of(sim, d, qty)
	sim.run.add(sim, currency, -cost)
	enc.purchases[line] += qty
	if int(d.get("stock", -1)) >= 0:
		d["stock"] = int(d["stock"]) - qty
	match str(d.get("item", "")):
		"res":
			sim.run.add(sim, str(d.get("res", "")), int(d.get("amount", 0)) * qty)
		"hull":
			sim.run.add(sim, "hull", int(d.get("amount", 0)) * qty)
		"weapon":
			var w: PackedStringArray = sim.ship.weapons.duplicate()
			for i: int in range(qty):
				w.append(str(d.get("weapon", "")))
			sim.ship.weapons = w
		"crew":
			EventEffects.join(sim, enc, str(d.get("pool", "")), enc.hire_member)
			enc.hire_member = ""
		"upgrade":
			var r: Room = sim.ship.rooms[sim.ship.room_with_system(str(d.get("system", "")))]
			r.sys_max += qty
			d["price"] = StoreRoll.next_bar_price(sim, str(d.get("system", "")))
		"gear":
			Gear.fit(sim, str(d.get("gear", "")))
	sim.emit("bought", {"store": enc.store_id, "item": line, "qty": qty, "cost": cost, "currency": currency})


static func stock_line(enc: Encounter, line: int) -> Dictionary:
	if line < 0 or line >= enc.visit.size():
		return {}
	return enc.visit[line]


## What `qty` units of a line cost: price x qty, or for an upgrade the sum of the next qty ladder
## entries (entries past the top count as 0; refusal rules those out first).
static func cost_of(sim: Sim, d: Dictionary, qty: int) -> int:
	if str(d.get("item", "")) != "upgrade":
		return int(d.get("price", 0)) * qty
	var sys: String = str(d.get("system", ""))
	var ri: int = sim.ship.room_with_system(sys)
	if ri < 0:
		return 0
	var lad: Array = StoreRoll.ladder(sim.db, sys)
	var total: int = 0
	var start: int = sim.ship.rooms[ri].sys_max
	for i: int in range(start, mini(start + qty, lad.size())):
		total += int(lad[i])
	return total


## Why this purchase cannot happen right now ("" = it can).
static func refusal(sim: Sim, enc: Encounter, line: int, qty: int) -> String:
	if enc.store_id.is_empty() or sim.run.phase != "store":
		return "no store is open"
	var d: Dictionary = stock_line(enc, line)
	if d.is_empty():
		return "no stock line %d" % line
	if qty < 1:
		return "quantity must be at least 1"
	var left: int = int(d.get("stock", -1))
	if left >= 0 and qty > left:
		return "sold out" if left == 0 else "only %d left" % left
	match str(d.get("item", "")):
		"hull":
			if sim.run.get_res("hull") + int(d.get("amount", 0)) * qty > sim.ship.hull_max:
				return "the hull is not that damaged"
		"weapon":
			var slots: int = int(sim.ship.source_def.get("weapon_slots", 0))
			if slots > 0 and sim.ship.weapons.size() + qty > slots:
				return "no free weapon slot"
		"crew":
			if qty != 1 or enc.hire_member.is_empty():
				return "nobody left to hire"
		"upgrade":
			var sys: String = str(d.get("system", ""))
			var ri: int = sim.ship.room_with_system(sys)
			if ri < 0:
				return "this ship has no %s" % sys
			var top: int = StoreRoll.ladder(sim.db, sys).size()
			if sim.ship.rooms[ri].sys_max >= top:
				return "%s is at its top" % sys
			if sim.ship.rooms[ri].sys_max + qty > top:
				return "%s tops out at %d bars" % [sys, top]
		"gear":
			if qty != 1:
				return "gear is fitted one at a time"
			var g: String = Gear.refusal(sim, str(d.get("gear", "")))
			if not g.is_empty():
				return g
	var currency: String = str(d.get("currency", "gems"))
	var cost: int = cost_of(sim, d, qty)
	if sim.run.get_res(currency) < cost:
		return "needs %d %s" % [cost, currency]
	return ""


# Selling ---------------------------------------------------------------------------------------

## The item's list price and currency from its data ({} when it has none).
static func list_price(db: DataDB, what: String, id: String) -> Dictionary:
	var table: String = "weapons" if what == "weapon" else "gear"
	var def: Dictionary = db.table(table).get(id, {})
	if def.is_empty() or int(def.get("price", 0)) <= 0:
		return {}
	return {"price": int(def["price"]), "currency": str(def.get("currency", "gems"))}


## What a sale pays: floor(list price x economy.sell_back_frac), 0 without a list price.
static func sell_price(db: DataDB, what: String, id: String) -> int:
	var lp: Dictionary = list_price(db, what, id)
	if lp.is_empty():
		return 0
	return floori(float(int(lp["price"])) * db.tune("economy.sell_back_frac"))


## Why this sale cannot happen right now ("" = it can).
static func sell_refusal(sim: Sim, enc: Encounter, what: String, id: String) -> String:
	if enc.store_id.is_empty() or sim.run.phase != "store":
		return "no store is open"
	if not SELL_WHAT.has(what):
		return "only a weapon or gear can be sold"
	if list_price(sim.db, what, id).is_empty():
		return "nobody buys that"
	if what == "weapon":
		if not sim.ship.weapons.has(id):
			return "no %s aboard" % id
		if sim.ship.weapons.size() <= 1:
			return "the last weapon aboard stays"
		return ""
	return Gear.sale_refusal(sim, id)


static func sell(sim: Sim, enc: Encounter, what: String, id: String) -> void:
	var why: String = sell_refusal(sim, enc, what, id)
	if not why.is_empty():
		sim.emit("bad_command", {"type": "sell", "why": why})
		return
	var currency: String = str(list_price(sim.db, what, id)["currency"])
	var pay: int = sell_price(sim.db, what, id)
	if what == "weapon":
		var w: PackedStringArray = sim.ship.weapons.duplicate()
		w.remove_at(w.rfind(id))  # One such weapon: the last mounted, so the others keep their slots.
		sim.ship.weapons = w
	else:
		Gear.remove(sim, id)
	var got: int = sim.run.add(sim, currency, pay)
	sim.emit("sold", {"store": enc.store_id, "what": what, "id": id, "paid": got, "currency": currency})


## What the ship could sell here, in a fixed order (weapons by slot, then gear as fitted):
## [{"what", "id", "price", "currency", "why"}] ("why" empty when the sale is allowed now).
static func sellable(sim: Sim, enc: Encounter) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := PackedStringArray()
	for wid: String in sim.ship.weapons:
		if seen.has("weapon:" + wid):
			continue
		seen.append("weapon:" + wid)
		out.append(_sell_entry(sim, enc, "weapon", wid))
	for gid: String in sim.run.gear:
		if seen.has("gear:" + gid):
			continue
		seen.append("gear:" + gid)
		out.append(_sell_entry(sim, enc, "gear", gid))
	return out


static func _sell_entry(sim: Sim, enc: Encounter, what: String, id: String) -> Dictionary:
	var lp: Dictionary = list_price(sim.db, what, id)
	return {"what": what, "id": id, "price": sell_price(sim.db, what, id), "currency": str(lp.get("currency", "gems")),
		"why": sell_refusal(sim, enc, what, id)}
