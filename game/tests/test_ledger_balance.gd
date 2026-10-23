extends TestCase
## Parity round 4, the balance measures behind L-UPG-03 (spend_share) and L-RWD-05 (income_share)
## (docs/research/behavior-ledger.md; spec docs/plans/specs/m2p_bots_balance.md). The measures
## themselves are run-level and live in python tools/balance.py --full; these are unit checks of the
## per-run numbers FullRunStats reads from the event list: spending by line kind, bars bought, and
## ore and gems gained by source, where the four sources add up to everything gained, exactly.

const SRC: Array[String] = ["fight", "event", "sale", "dig"]


func _gained(sum: Dictionary, src: String, res: String) -> int:
	return int(((sum["gained_by"] as Dictionary)[src] as Dictionary)[res])


func _sources_total(sum: Dictionary, res: String) -> int:
	var t: int = 0
	for src: String in SRC:
		t += _gained(sum, src, res)
	return t


func _stats(s: Sim) -> Dictionary:
	var sum: Dictionary = s.run.summary(s)
	FullRunStats.add_to(s, sum)
	return sum


## Every source on one hand-built run: digging, a dossier's outcome, a fight's loot, a sale, and
## purchases of an upgrade, gear and a supply. Each bucket gets exactly its own amounts.
func test_gains_and_spending_by_source() -> void:
	var s := Sim.new(full_store(db()), 7, "light_drill", {"mode": "run"})
	s.run.add(s, "ore", 10)  # dig
	s.emit("event_choice", {"event": "t", "page": "a", "option": 0})
	s.run.add(s, "ore", 7)  # event
	s.run.add(s, "gems", 2)  # event
	s.run.add(s, "ore", -1)  # a cost: not a gain
	s.emit("event_page", {"event": "t", "page": "b"})
	s.run.add(s, "ore", 3)  # dig: the page is open but no choice is being applied
	s.emit("event_choice", {"event": "t", "page": "b", "option": 0})
	s.run.add(s, "gems", 1)  # event
	s.emit("event_ended", {"event": "t"})
	var loot: Dictionary = CombatLoot.roll(s, s.db, false)
	s.emit("fight_won", {"enemy": "x", "boss": false, "loot": loot})
	check_gt(float(int(loot["ore"])), 0.0, "the fight paid ore")
	# Store: a spare lance to sell back, then an upgrade, gear and coolant.
	var w: PackedStringArray = s.ship.weapons.duplicate()
	w.append("thermal_lance")
	s.ship.weapons = w
	s.run.add(s, "ore", 2000)
	s.run.add(s, "gems", 500)
	var ore_before_store: int = s.run.get_res("ore")
	s.encounter.open_store(s, "crust_trader")
	s.push({"type": "sell", "what": "weapon", "id": "thermal_lance"})
	s.step()
	check(has_event(s, "sold"), "the lance sold")
	var paid: int = EncounterStore.sell_price(s.db, "weapon", "thermal_lance")
	var br: int = store_line(s, "system", "bracing")
	var br_cost: int = EncounterStore.cost_of(s, (s.encounter.current_store()["stock"] as Array)[br], 2)
	s.push({"type": "buy", "item": br, "qty": 2})
	s.step()
	var gi: int = store_line(s, "gear", "hull_plating")
	s.push({"type": "buy", "item": gi, "qty": 1})
	s.step()
	var ci: int = store_line(s, "res", "coolant")
	s.push({"type": "buy", "item": ci, "qty": 1})
	s.step()
	var sum: Dictionary = _stats(s)
	check_eq(_gained(sum, "event", "ore"), 7, "event ore: only what the choices applied")
	check_eq(_gained(sum, "event", "gems"), 3, "event gems")
	check_eq(_gained(sum, "fight", "ore"), int(loot["ore"]), "fight ore is the loot")
	check_eq(_gained(sum, "fight", "gems"), int(loot["gems"]), "fight gems are the loot")
	check_eq(_gained(sum, "sale", "gems"), paid, "the sale's gems")
	check_eq(_gained(sum, "sale", "ore"), 0, "no ore from the sale")
	check_eq(_gained(sum, "dig", "ore"), 10 + 3 + 2000, "dig ore: everything else (the test's 2000 grant included)")
	check_eq(_gained(sum, "dig", "gems"), 500, "dig gems: the grant")
	for res: String in ["ore", "gems"]:
		check_eq(_sources_total(sum, res), int((sum["gained"] as Dictionary)[res]), "the four sources add up to all %s gained" % res)
	var ore_by: Dictionary = sum["ore_spent_by"]
	var gems_by: Dictionary = sum["gems_spent_by"]
	check_eq(int(ore_by["upgrade"]), br_cost, "upgrade ore: the two bracing bars on the ladder")
	check_eq(int(ore_by["gear"]), ore_before_store - s.run.get_res("ore") - br_cost, "gear ore: the plating")
	check_gt(float(int(gems_by["res"])), 0.0, "the coolant was paid in gems")
	check_eq(int(sum["bars_bought"]), 2, "two bars bought")
	for k: String in FullRunStats.SPEND_KINDS:
		check(ore_by.has(k) and gems_by.has(k), "every kind is reported: %s" % k)
	var spent_ore: int = 0
	for k: String in FullRunStats.SPEND_KINDS:
		spent_ore += int(ore_by[k])
	check_eq(spent_ore, ore_before_store - s.run.get_res("ore"), "store ore spending adds up to the ore that left")


## Short seeded runs by each bot: the sources add up exactly, none is negative, store spending never
## exceeds all spending, and bars bought match the bars the ship gained.
func test_short_runs_add_up() -> void:
	var d: DataDB = db()
	var short: Dictionary = (d.table("layers")["crust"] as Dictionary).duplicate(true)
	short["id"] = "bal_test"
	short["rows"] = 4
	short["row_depth_m"] = 14.0
	short["store_rows"] = [1, 2]
	short["min_fights_per_path"] = 1
	short["gate_enemy"] = "rival_light"
	d.table("layers")["bal_test"] = short
	for bot: String in ["balanced", "greedy"]:
		var fr: FullRun = FullRun.start(d, 12, bot, {"layer": "bal_test"}, "light_drill", 1200.0)
		var bars0: int = 0
		for r: Room in fr.sim.ship.rooms:
			bars0 += r.sys_max
		fr.play_to_end()
		var sum: Dictionary = fr.summary()
		FullRunStats.add_to(fr.sim, sum)
		for res: String in ["ore", "gems"]:
			check_eq(_sources_total(sum, res), int((sum["gained"] as Dictionary)[res]), "%s: sources add up to all %s gained" % [bot, res])
			for src: String in SRC:
				check(_gained(sum, src, res) >= 0, "%s: %s %s is not negative" % [bot, src, res])
		var by_ore: int = 0
		for k: String in FullRunStats.SPEND_KINDS:
			by_ore += int((sum["ore_spent_by"] as Dictionary)[k])
		check(by_ore <= int((sum["spent"] as Dictionary)["ore"]), "%s: store ore spending is part of all ore spent" % bot)
		var bars1: int = 0
		for r: Room in fr.sim.ship.rooms:
			bars1 += r.sys_max
		check_eq(int(sum["bars_bought"]), bars1 - bars0, "%s: bars bought are the bars the ship gained" % bot)
		check_gt(float(_gained(sum, "dig", "ore")), 0.0, "%s: the dig paid ore" % bot)
		print("LEDGER balance_short %s: gained_by %s, ore_spent_by %s, bars %d" % [bot, JSON.stringify(sum["gained_by"]),
				JSON.stringify(sum["ore_spent_by"]), int(sum["bars_bought"])])
