extends TestCase
## The store: purchases spend gems or ore exactly, respect stock and the upgrade ladders, refuse
## cleanly, and the crew hire is deterministic (docs/plans/specs/step5_events.md). M1b: ore buys
## upgrades, gear and repairs; gems buy supplies, crew and weapons (docs/plans/specs/m1b_dig_sim.md).
## Parity round 1 (m2p_economy.md): the stock is rolled per visit, so most tests here open a "full"
## crust trader (every section shown with every offer, an in-memory data change) and find lines by
## what they sell. The rolling itself is tested in test_ledger_store.gd.


## The real data with the crust trader showing every section and every offer.
func _full_db() -> DataDB:
	var d: DataDB = db()
	var st: Dictionary = d.table("stores")["crust_trader"]
	st["sections_shown"] = [4, 4]
	for sec: Variant in (st["sections"] as Array):
		var n: int = ((sec as Dictionary)["pool"] as Array).size()
		(sec as Dictionary)["offers"] = [n, n]
	return d


## A run with an open full store; gems set to `gems`, ore to `ore` (-1 keeps the ship's starting ore).
func _store(p_seed: int = 7, gems: int = 500, ore: int = -1) -> Sim:
	var s := Sim.new(_full_db(), p_seed, "light_drill", {"mode": "run"})
	s.run.add(s, "gems", gems - s.run.get_res("gems"))
	if ore >= 0:
		s.run.add(s, "ore", ore - s.run.get_res("ore"))
	s.encounter.open_store(s, "crust_trader")
	return s


## The visit line selling this (item "res" with res, "upgrade" with system, "gear", "weapon",
## "crew", "hull"), or -1.
func _line(s: Sim, item: String, what: String = "") -> int:
	var stock: Array = s.encounter.current_store().get("stock", [])
	for i: int in range(stock.size()):
		var d: Dictionary = stock[i]
		if str(d["item"]) != item:
			continue
		if what.is_empty() or str(d["res"]) == what or str(d["system"]) == what or str(d["gear"]) == what or str(d["weapon"]) == what:
			return i
	return -1


func _buy(s: Sim, item: int, qty: int = 1) -> void:
	s.push({"type": "buy", "item": item, "qty": qty})
	s.step()


func _reopen(s: Sim) -> void:
	s.push({"type": "leave"})
	s.step()
	s.encounter.open_store(s, "crust_trader")


func _refused(s: Sim) -> bool:
	var last: Dictionary = s.events[s.events.size() - 1]
	return str(last["kind"]) == "bad_command" and str(last["type"]) == "buy"


func test_store_data_matches_the_spec() -> void:
	var st: Dictionary = db().table("stores")["crust_trader"]
	var sup: Array = st["supplies"]
	var want: Array = [["res", "coolant", 6], ["res", "cells", 8], ["res", "bits", 10], ["res", "charges", 8]]
	for i: int in range(want.size()):
		var line: Dictionary = sup[i]
		check_eq(str(line["res"]), str(want[i][1]), "supply %d" % i)
		check_eq(int(line["price"]), int(want[i][2]), "supply %d price stays today's" % i)
		check_eq([int(line["stock"][0]), int(line["stock"][1])], [2, 6], "supply %d stock 2 to 6" % i)
	check_eq(str((sup[4] as Dictionary)["item"]), "hull", "hull plate last")
	check_eq([int(st["sections_shown"][0]), int(st["sections_shown"][1])], [2, 3], "two or three sections")
	var ids: Array = []
	for sec: Variant in (st["sections"] as Array):
		ids.append(str((sec as Dictionary)["id"]))
	check_eq(ids, ["systems", "gear", "weapons", "crew"], "four sections")
	var s := Sim.new(db(), 7, "light_drill", {"mode": "run"})
	check_eq(StoreRoll.line(s, {"item": "gear", "gear": "diamond_head"}, "gear", 0, 1)["price"], 450, "gear priced from its data")
	check_eq(StoreRoll.line(s, {"item": "weapon", "weapon": "borer_turret"}, "weapons", 0, 1)["price"], 45, "weapons too")
	check_eq(StoreRoll.line(s, {"item": "weapon", "weapon": "borer_turret"}, "weapons", 0, 1)["currency"], "gems", "in gems")


## Ore buys gear, upgrades and hull; gems buy supplies, crew and weapons (every visit line).
func test_store_currency_per_line() -> void:
	var s: Sim = _store(7, 100, 400)
	var stock: Array = s.encounter.current_store()["stock"]
	for i: int in range(stock.size()):
		var line: Dictionary = stock[i]
		var item: String = str(line["item"])
		var want: String = "ore" if item == "gear" or item == "upgrade" or item == "hull" else "gems"
		check_eq(str(line["currency"]), want, "line %d (%s) is paid in %s" % [i, item, want])
	_buy(s, _line(s, "gear", "tungsten_head"))
	check_eq(s.run.get_res("ore"), 220, "the tungsten head costs 180 ore")
	check_eq(s.run.get_res("gems"), 100, "and no gems")
	_buy(s, _line(s, "res", "coolant"))
	check_eq(s.run.get_res("gems"), 94, "coolant costs 6 gems")
	check_eq(s.run.get_res("ore"), 220, "and no ore")


func test_gear_lines_fit_gear() -> void:
	var s: Sim = _store(7, 100, 1000)
	_buy(s, _line(s, "gear", "tungsten_head"))
	check_eq(Array(s.run.gear), ["tungsten_head"], "the head is fitted")
	_buy(s, _line(s, "gear", "tungsten_head"))
	check(_refused(s), "one on the shelf, and already fitted")
	_buy(s, _line(s, "gear", "diamond_head"))
	check_eq(Array(s.run.gear), ["diamond_head"], "the diamond head replaces it")
	check_eq(s.run.get_res("ore"), 1000 - 180 - 450, "both paid exactly")
	var max0: int = s.ship.hull_max
	_buy(s, _line(s, "gear", "hull_plating"))
	check_eq(s.ship.hull_max, max0 + 5, "plating raises the maximum hull")
	_buy(s, _line(s, "gear", "pumps"))
	check_eq(s.run.gear_x("pump_x"), 2.0, "the pumps are fitted")
	var bought: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "gear_fitted":
			bought += 1
	check_eq(bought, 4, "four gear_fitted events")
	_reopen(s)
	check_eq(_line(s, "gear", "tungsten_head"), -1, "a worse head is not offered on the next visit")
	check_eq(_line(s, "gear", "pumps"), -1, "nor gear already fitted")
	check(_line(s, "gear", "hull_plating") >= 0, "a second plate is (two may be fitted)")


func test_resource_packs_spend_gems_exactly() -> void:
	var s: Sim = _store()
	var start: Dictionary = s.ship.source_def["start_resources"]
	_buy(s, _line(s, "res", "coolant"), 2)
	check_eq(s.run.get_res("gems"), 500 - 12, "two coolant packs cost 12 gems")
	check_eq(s.run.get_res("coolant"), int(start["coolant"]) + 10, "and give 10 coolant")
	_buy(s, _line(s, "res", "cells"), 2)
	_buy(s, _line(s, "res", "bits"))
	_buy(s, _line(s, "res", "charges"), 2)
	check_eq(s.run.get_res("cells"), int(start["cells"]) + 2, "two cells")
	check_eq(s.run.get_res("bits"), int(start["bits"]) + 1, "one bit")
	check_eq(s.run.get_res("charges"), int(start["charges"]) + 4, "four charges")
	var spent: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "bought":
			spent += int(e["cost"])
	check_eq(spent, 12 + 16 + 10 + 16, "every purchase is priced exactly")
	check_eq(s.run.get_res("gems"), 500 - spent, "and the gems match the receipts")


func test_refusals_change_nothing() -> void:
	var s: Sim = _store(7, 9)
	var run0: Array = s.run.state()
	var enc0: Array = s.encounter.state()
	_buy(s, _line(s, "res", "bits"))
	check(_refused(s), "ten gems needed, nine held")
	_buy(s, 99)
	check(_refused(s), "no such line")
	_buy(s, _line(s, "res", "coolant"), 0)
	check(_refused(s), "zero quantity")
	_buy(s, _line(s, "res", "coolant"), -3)
	check(_refused(s), "negative quantity")
	_buy(s, _line(s, "res", "coolant"), 7)
	check(_refused(s), "more than the shelf holds")
	check_eq(s.run.state(), run0, "the run did not change")
	check_eq(s.encounter.state(), enc0, "the store did not change")
	_buy(s, _line(s, "res", "cells"))
	check(not _refused(s), "eight gems are enough for a cell")
	check_eq(s.run.get_res("gems"), 1, "one gem left")
	var idle := Sim.new(db(), 7, "light_drill", {"mode": "run"})
	idle.push({"type": "buy", "item": 0, "qty": 1})
	idle.step()
	check(_refused(idle), "nothing can be bought with no store open")
	idle.push({"type": "leave"})
	idle.step()
	check_eq(str(idle.events[idle.events.size() - 1]["kind"]), "bad_command", "nor left")


func test_hull_repair_paid_in_ore_up_to_max() -> void:
	var s: Sim = _store()
	var hull: int = _line(s, "hull")
	check_eq(int(s.encounter.visit[hull]["price"]), 2, "two ore a point near the surface")
	s.run.add(s, "hull", -6)
	_buy(s, hull, 5)
	check_eq(s.run.get_res("ore"), 0, "five hull cost all ten ore")
	check_eq(s.run.get_res("hull"), s.ship.hull_max - 1, "five hull back")
	check_eq(s.run.get_res("gems"), 500, "no gems spent")
	_buy(s, hull)
	check(_refused(s), "no ore left")
	s.run.add(s, "ore", 10)
	_buy(s, hull, 2)
	check(_refused(s), "never above the ship's maximum")
	_buy(s, hull)
	check_eq(s.run.get_res("hull"), s.ship.hull_max, "full")
	check_eq(s.run.get_res("ore"), 8, "two ore for the last plate")
	_buy(s, hull)
	check(_refused(s), "a full hull cannot be repaired")


func test_weapon_once_per_visit() -> void:
	var s: Sim = _store()
	var start: int = s.ship.weapons.size()
	var lance: int = _line(s, "weapon", "thermal_lance")
	_buy(s, lance)
	check_eq(s.ship.weapons.size(), start + 1, "one weapon added")
	check_eq(s.ship.weapons[s.ship.weapons.size() - 1], "thermal_lance", "the lance is mounted in the next slot")
	check_eq(s.run.get_res("gems"), 430, "for 70 gems")
	check_eq(int(s.encounter.visit[lance]["stock"]), 0, "the shelf is empty")
	_buy(s, lance)
	check(_refused(s), "one lance on the shelf")
	check_eq(s.ship.weapons.size(), start + 1, "still one more")
	s.push({"type": "leave"})
	s.step()
	check_eq(s.run.phase, "idle", "leave returns to idle")
	s.encounter.open_store(s, "crust_trader")
	check_eq(int(s.encounter.visit[_line(s, "weapon", "thermal_lance")]["stock"]), 1, "a new visit, a new shelf")


func test_upgrades_follow_the_ladder() -> void:
	var s: Sim = _store(7, 500, 1000)
	var helm: int = _line(s, "upgrade", "helm")
	check_eq(int(s.encounter.visit[helm]["price"]), 90, "the helm's third bar costs 90")
	_buy(s, helm)
	check_eq(room(s, "bridge").sys_max, 3, "helm 2 -> 3")
	check_eq(room(s, "bridge").sys_power, 1, "power is the player's to allocate")
	check_eq(s.run.get_res("ore"), 910, "90 ore")
	check_eq(s.run.get_res("gems"), 500, "no gems")
	check_eq(int(s.encounter.visit[helm]["price"]), 150, "the line now shows the fourth bar's price")
	_buy(s, helm)
	check_eq(room(s, "bridge").sys_max, 4, "no per-visit cap: helm 3 -> 4")
	check_eq(s.run.get_res("ore"), 760, "150 ore")
	_buy(s, helm)
	check(_refused(s), "the helm is at its top")
	check_eq(EncounterStore.refusal(s, s.encounter, helm, 1), "helm is at its top", "with that reason")
	_buy(s, _line(s, "upgrade", "reactor"), 2)
	check_eq(room(s, "reactor").sys_max, 10, "two reactor bars at once, 8 -> 10")
	check_eq(s.run.get_res("ore"), 760 - 60 - 60, "at 60 each")
	_reopen(s)
	check_eq(_line(s, "upgrade", "helm"), -1, "a system at its top is not offered again")


func test_crew_hire() -> void:
	var s: Sim = _store()
	var member: String = s.encounter.hire_member
	check(not member.is_empty(), "the store rolls a candidate when it opens")
	var again: Sim = _store()
	check_eq(again.encounter.hire_member, member, "the same seed offers the same candidate")
	_buy(s, _line(s, "crew"))
	check_eq(s.ship.crew.size(), 4, "hired")
	check(s.ship.crew[3].id.begins_with(member), "the candidate offered is the one hired")
	check_eq(s.run.get_res("gems"), 455, "for 45 gems")
	_buy(s, _line(s, "crew"))
	check(_refused(s), "one hire per visit")
	s.push({"type": "leave"})
	s.step()
	run_seconds(s, 30.0)
	check_eq(s.ship.rooms[s.ship.crew[3].room].id, "weapons", "the hire walks to their station")
	s.encounter.open_store(s, "crust_trader")
	check(s.encounter.hire_member != member, "someone already aboard is not offered again")


func test_store_state_is_hashed_and_replayable() -> void:
	var a: Sim = _store(9)
	var b: Sim = _store(9)
	_buy(a, _line(a, "res", "coolant"))
	_buy(b, _line(b, "res", "coolant"))
	check_eq(a.state_hash(), b.state_hash(), "same purchases, same hash")
	_buy(a, _line(a, "res", "cells"))
	_buy(b, _line(b, "res", "bits"))
	check(a.state_hash() != b.state_hash(), "different purchases, different hash")
	check_eq(a.encounter.state()[7], "crust_trader", "the store id is in the state")
	check_eq((a.encounter.state()[11] as Array).size(), a.encounter.visit.size(), "and so is every visit line")
