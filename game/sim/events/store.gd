class_name EncounterStore
extends RefCounted
## The store's rules: {"type": "buy", "item": i, "qty": n} buys n units of stock line i. A purchase
## is all or nothing: it is checked completely first (open store, line, limit, price, room to use
## what is bought), then paid with one exact run.add and delivered. A refused purchase emits
## bad_command and changes nothing. Static: the Sim and the Encounter are passed in.
##
## Stock lines (game/data/stores/<id>.json, "stock"): {"item": ..., "price": gems per unit,
## "currency": optional resource (default "gems"), "limit": optional units per visit (0 = none)}
## with, per item: "res" (res, amount), "hull" (amount, never above the ship's maximum),
## "weapon" (weapon: appended to ship.weapons), "crew" (pool: hires the member rolled when the store
## opened), "upgrade" (system, max_bars: +1 bar of capacity per unit), "gear" (gear: a data/gear id,
## one unit at a time, fitted with Gear.fit; refused when Gear.refusal says so).
## Currency by line (M1b, D025): ore buys system upgrades, gear and hull repairs; gems buy supplies
## (coolant, cells, bits, charges), crew and weapons.

const ITEMS: Array[String] = ["res", "hull", "weapon", "crew", "upgrade", "gear"]


static func buy(sim: Sim, enc: Encounter, line: int, qty: int) -> void:
	var why: String = refusal(sim, enc, line, qty)
	if not why.is_empty():
		sim.emit("bad_command", {"type": "buy", "why": why})
		return
	var d: Dictionary = stock_line(enc, line)
	var currency: String = str(d.get("currency", "gems"))
	var cost: int = int(d.get("price", 0)) * qty
	sim.run.add(sim, currency, -cost)
	enc.purchases[line] += qty
	match str(d.get("item", "")):
		"res":
			sim.run.add(sim, str(d.get("res", "")), int(d.get("amount", 0)) * qty)
		"hull":
			sim.run.add(sim, "hull", int(d.get("amount", 0)) * qty)
		"weapon":
			for i: int in range(qty):
				sim.ship.weapons.append(str(d.get("weapon", "")))
		"crew":
			EventEffects.join(sim, enc, str(d.get("pool", "")), enc.hire_member)
			enc.hire_member = ""
		"upgrade":
			var r: Room = sim.ship.rooms[sim.ship.room_with_system(str(d.get("system", "")))]
			r.sys_max += qty
		"gear":
			Gear.fit(sim, str(d.get("gear", "")))
	sim.emit("bought", {"store": enc.store_id, "item": line, "qty": qty, "cost": cost, "currency": currency})


static func stock_line(enc: Encounter, line: int) -> Dictionary:
	var stock: Array = enc.current_store().get("stock", [])
	if line < 0 or line >= stock.size():
		return {}
	return stock[line]


## Why this purchase cannot happen right now ("" = it can).
static func refusal(sim: Sim, enc: Encounter, line: int, qty: int) -> String:
	if enc.store_id.is_empty() or sim.run.phase != "store":
		return "no store is open"
	var d: Dictionary = stock_line(enc, line)
	if d.is_empty():
		return "no stock line %d" % line
	if qty < 1:
		return "quantity must be at least 1"
	var limit: int = int(d.get("limit", 0))
	if limit > 0 and enc.purchases[line] + qty > limit:
		return "only %d per visit" % limit
	var currency: String = str(d.get("currency", "gems"))
	var cost: int = int(d.get("price", 0)) * qty
	if sim.run.get_res(currency) < cost:
		return "needs %d %s" % [cost, currency]
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
			var ri: int = sim.ship.room_with_system(str(d.get("system", "")))
			if ri < 0:
				return "this ship has no %s" % str(d.get("system", ""))
			if sim.ship.rooms[ri].sys_max + qty > int(d.get("max_bars", 0)):
				return "%s is at its maximum" % str(d.get("system", ""))
		"gear":
			if qty != 1:
				return "gear is fitted one at a time"
			return Gear.refusal(sim, str(d.get("gear", "")))
	return ""
