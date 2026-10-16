extends TestCase
## The store: purchases spend gems or ore exactly, respect limits and caps, refuse cleanly, and the
## crew hire is deterministic (docs/plans/specs/step5_events.md). M1b: ore buys upgrades, gear and
## repairs; gems buy supplies, crew and weapons (docs/plans/specs/m1b_dig_sim.md).

const COOLANT: int = 0
const CELLS: int = 1
const BITS: int = 2
const CHARGES: int = 3
const HULL: int = 4
const LANCE: int = 5
const HIRE: int = 6
const UP_HELM: int = 7
const UP_REACTOR: int = 9
const TUNGSTEN: int = 13
const DIAMOND: int = 14
const PLATING: int = 15
const PUMPS: int = 16


## A run with an open store; gems set to `gems`, ore to `ore` (-1 keeps the ship's starting ore).
func _store(p_seed: int = 7, gems: int = 500, ore: int = -1) -> Sim:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.run.add(s, "gems", gems - s.run.get_res("gems"))
	if ore >= 0:
		s.run.add(s, "ore", ore - s.run.get_res("ore"))
	s.encounter.open_store(s, "crust_trader")
	return s


func _buy(s: Sim, item: int, qty: int = 1) -> void:
	s.push({"type": "buy", "item": item, "qty": qty})
	s.step()


func _refused(s: Sim) -> bool:
	var last: Dictionary = s.events[s.events.size() - 1]
	return str(last["kind"]) == "bad_command" and str(last["type"]) == "buy"


func test_stock_lines_match_the_spec() -> void:
	var st: Dictionary = db().table("stores")["crust_trader"]
	var stock: Array = st["stock"]
	var want: Array = [["res", 6], ["res", 8], ["res", 10], ["res", 8], ["hull", 2], ["weapon", 70], ["crew", 45],
		["upgrade", 120], ["upgrade", 140], ["upgrade", 200], ["upgrade", 160], ["upgrade", 150], ["upgrade", 120],
		["gear", 180], ["gear", 450], ["gear", 200], ["gear", 120]]
	check_eq(stock.size(), want.size(), "seventeen stock lines")
	for i: int in range(mini(stock.size(), want.size())):
		var line: Dictionary = stock[i]
		check_eq(str(line["item"]), str(want[i][0]), "line %d item" % i)
		check_eq(int(line["price"]), int(want[i][1]), "line %d price" % i)


## Ore buys gear, upgrades and hull; gems buy supplies, crew and weapons (every line, from the data).
func test_store_currency_per_line() -> void:
	var stock: Array = (db().table("stores")["crust_trader"] as Dictionary)["stock"]
	for i: int in range(stock.size()):
		var line: Dictionary = stock[i]
		var item: String = str(line["item"])
		var want: String = "ore" if item == "gear" or item == "upgrade" or item == "hull" else "gems"
		check_eq(str(line.get("currency", "gems")), want, "line %d (%s) is paid in %s" % [i, item, want])
	var s: Sim = _store(7, 100, 400)
	_buy(s, TUNGSTEN)
	check_eq(s.run.get_res("ore"), 220, "the tungsten head costs 180 ore")
	check_eq(s.run.get_res("gems"), 100, "and no gems")
	_buy(s, COOLANT)
	check_eq(s.run.get_res("gems"), 94, "coolant costs 6 gems")
	check_eq(s.run.get_res("ore"), 220, "and no ore")


func test_gear_lines_fit_gear() -> void:
	var s: Sim = _store(7, 100, 1000)
	_buy(s, TUNGSTEN)
	check_eq(Array(s.run.gear), ["tungsten_head"], "the head is fitted")
	_buy(s, TUNGSTEN)
	check(_refused(s), "once per visit and already fitted")
	_buy(s, DIAMOND)
	check_eq(Array(s.run.gear), ["diamond_head"], "the diamond head replaces it")
	check_eq(s.run.get_res("ore"), 1000 - 180 - 450, "both paid exactly")
	var max0: int = s.ship.hull_max
	_buy(s, PLATING)
	check_eq(s.ship.hull_max, max0 + 5, "plating raises the maximum hull")
	_buy(s, PUMPS)
	check_eq(s.run.gear_x("pump_x"), 2.0, "the pumps are fitted")
	_buy(s, PUMPS, 2)
	check(_refused(s), "gear is fitted one at a time")
	var bought: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "gear_fitted":
			bought += 1
	check_eq(bought, 4, "four gear_fitted events")
	s.push({"type": "leave"})
	s.step()
	s.encounter.open_store(s, "crust_trader")
	_buy(s, TUNGSTEN)
	check(_refused(s), "a worse head is refused on the next visit too")


func test_resource_packs_spend_gems_exactly() -> void:
	var s: Sim = _store()
	var start: Dictionary = s.ship.source_def["start_resources"]
	_buy(s, COOLANT, 2)
	check_eq(s.run.get_res("gems"), 500 - 12, "two coolant packs cost 12 gems")
	check_eq(s.run.get_res("coolant"), int(start["coolant"]) + 10, "and give 10 coolant")
	_buy(s, CELLS, 3)
	_buy(s, BITS)
	_buy(s, CHARGES, 2)
	check_eq(s.run.get_res("cells"), int(start["cells"]) + 3, "three cells")
	check_eq(s.run.get_res("bits"), int(start["bits"]) + 1, "one bit")
	check_eq(s.run.get_res("charges"), int(start["charges"]) + 4, "four charges")
	var spent: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "bought":
			spent += int(e["cost"])
	check_eq(spent, 12 + 24 + 10 + 16, "every purchase is priced exactly")
	check_eq(s.run.get_res("gems"), 500 - spent, "and the gems match the receipts")


func test_refusals_change_nothing() -> void:
	var s: Sim = _store(7, 9)
	var run0: Array = s.run.state()
	var enc0: Array = s.encounter.state()
	_buy(s, BITS)
	check(_refused(s), "ten gems needed, nine held")
	_buy(s, 99)
	check(_refused(s), "no such line")
	_buy(s, COOLANT, 0)
	check(_refused(s), "zero quantity")
	_buy(s, COOLANT, -3)
	check(_refused(s), "negative quantity")
	check_eq(s.run.state(), run0, "the run did not change")
	check_eq(s.encounter.state(), enc0, "the store did not change")
	_buy(s, CELLS)
	check(not _refused(s), "eight gems are enough for a cell")
	check_eq(s.run.get_res("gems"), 1, "one gem left")
	var idle := Sim.new(db(), 7, "light_drill", {"mode": "run"})
	idle.push({"type": "buy", "item": COOLANT, "qty": 1})
	idle.step()
	check(_refused(idle), "nothing can be bought with no store open")
	idle.push({"type": "leave"})
	idle.step()
	check_eq(str(idle.events[idle.events.size() - 1]["kind"]), "bad_command", "nor left")


func test_hull_repair_paid_in_ore_up_to_max() -> void:
	var s: Sim = _store()
	s.run.add(s, "hull", -6)
	_buy(s, HULL, 5)
	check_eq(s.run.get_res("ore"), 0, "five hull cost all ten ore")
	check_eq(s.run.get_res("hull"), s.ship.hull_max - 1, "five hull back")
	check_eq(s.run.get_res("gems"), 500, "no gems spent")
	_buy(s, HULL)
	check(_refused(s), "no ore left")
	s.run.add(s, "ore", 10)
	_buy(s, HULL, 2)
	check(_refused(s), "never above the ship's maximum")
	_buy(s, HULL)
	check_eq(s.run.get_res("hull"), s.ship.hull_max, "full")
	check_eq(s.run.get_res("ore"), 8, "two ore for the last plate")
	_buy(s, HULL)
	check(_refused(s), "a full hull cannot be repaired")


func test_lance_once_per_visit() -> void:
	var s: Sim = _store()
	var start: int = s.ship.weapons.size()
	_buy(s, LANCE)
	check_eq(s.ship.weapons.size(), start + 1, "one weapon added")
	check_eq(s.ship.weapons[s.ship.weapons.size() - 1], "thermal_lance", "the lance is mounted in the next slot")
	check_eq(s.run.get_res("gems"), 430, "for 70 gems")
	_buy(s, LANCE)
	check(_refused(s), "one lance per visit")
	check_eq(s.ship.weapons.size(), start + 1, "still one more")
	s.push({"type": "leave"})
	s.step()
	check_eq(s.run.phase, "idle", "leave returns to idle")
	s.encounter.open_store(s, "crust_trader")
	check_eq(int(s.encounter.purchases[LANCE]), 0, "limits reset on the next visit")


func test_upgrades_capped_and_limited() -> void:
	var s: Sim = _store(7, 500, 500)
	_buy(s, UP_HELM)
	check_eq(room(s, "bridge").sys_max, 3, "helm 2 -> 3")
	check_eq(room(s, "bridge").sys_power, 1, "power is the player's to allocate")
	check_eq(s.run.get_res("ore"), 380, "120 ore")
	check_eq(s.run.get_res("gems"), 500, "no gems")
	_buy(s, UP_HELM)
	check(_refused(s), "once per visit (and helm is at its maximum of 3)")
	s.push({"type": "leave"})
	s.step()
	s.encounter.open_store(s, "crust_trader")
	_buy(s, UP_HELM)
	check(_refused(s), "the helm cannot pass 3 bars")
	check_eq(room(s, "bridge").sys_max, 3, "still 3")
	_buy(s, UP_REACTOR, 2)
	check(_refused(s), "one reactor bar per visit")
	_buy(s, UP_REACTOR)
	check_eq(room(s, "reactor").sys_max, 9, "reactor 8 -> 9")


func test_crew_hire() -> void:
	var s: Sim = _store()
	var member: String = s.encounter.hire_member
	check(not member.is_empty(), "the store rolls a candidate when it opens")
	var again: Sim = _store()
	check_eq(again.encounter.hire_member, member, "the same seed offers the same candidate")
	_buy(s, HIRE)
	check_eq(s.ship.crew.size(), 4, "hired")
	check(s.ship.crew[3].id.begins_with(member), "the candidate offered is the one hired")
	check_eq(s.run.get_res("gems"), 455, "for 45 gems")
	_buy(s, HIRE)
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
	_buy(a, COOLANT)
	_buy(b, COOLANT)
	check_eq(a.state_hash(), b.state_hash(), "same purchases, same hash")
	_buy(a, CELLS)
	_buy(b, BITS)
	check(a.state_hash() != b.state_hash(), "different purchases, different hash")
	check_eq(a.encounter.state()[7], "crust_trader", "the store id is in the state")
