extends TestCase
## Parity round 1, store rows (docs/research/behavior-ledger.md: L-STO-01 to L-STO-05; spec
## docs/plans/specs/m2p_economy.md). Each test measures the row's Target with a judge function that
## returns "" for a pass or the reason it fails, then applies the row's Wrong value in memory and
## asserts the same judge now fails. Measured values print as LEDGER lines.

const LIGHT: String = "light_drill"
const ROWS: int = 14  ## The crust map's rows.


## `n` crust trader visits rolled on one fresh light drill (the "store" stream runs on), at rows
## cycling from `row0` through `row1`.
func _visits(d: DataDB, n: int, row0: int = 0, row1: int = 13, store: String = "crust_trader") -> Array:
	var s := Sim.new(d, 17, LIGHT, {"mode": "run"})
	var st: Dictionary = d.table("stores")[store]
	var out: Array = []
	for i: int in range(n):
		out.append(StoreRoll.roll(s, st, row0 + i % (row1 - row0 + 1), ROWS))
	return out


func _sections_of(v: Array) -> Dictionary:
	var out: Dictionary = {}
	for line: Variant in v:
		var sec: String = str((line as Dictionary)["section"])
		out[sec] = int(out.get(sec, 0)) + 1
	return out


func _offer_keys(v: Array) -> String:
	var keys := PackedStringArray()
	for line: Variant in v:
		var d: Dictionary = line
		if str(d["section"]) != "supplies":
			keys.append("%s:%s%s%s%s" % [str(d["item"]), str(d["system"]), str(d["gear"]), str(d["weapon"]), str(d["pool"])])
	return ",".join(keys)


# L-STO-01 ----------------------------------------------------------------------------------------

func _judge_sto_01(visits: Array) -> String:
	var with_systems: int = 0
	var differ: int = 0
	for vi: int in range(visits.size()):
		var v: Array = visits[vi]
		var secs: Dictionary = _sections_of(v)
		var shown: int = secs.size() - (1 if secs.has("supplies") else 0)
		if not secs.has("supplies") or shown < 2 or shown > 3:
			return "visit %d shows %d sections (%s)" % [vi, shown, str(secs)]
		var want: Dictionary = {"systems": [3, 3], "gear": [2, 2], "weapons": [1, 2], "crew": [1, 1]}
		for sec: Variant in secs.keys():
			if str(sec) == "supplies":
				continue
			var span: Array = want[str(sec)]
			if int(secs[sec]) < int(span[0]) or int(secs[sec]) > int(span[1]):
				return "visit %d: %s holds %d offers" % [vi, str(sec), int(secs[sec])]
		var keys: PackedStringArray = _offer_keys(v).split(",")
		for k: String in keys:
			if keys.count(k) > 1:
				return "visit %d offers %s twice" % [vi, k]
		if secs.has("systems"):
			with_systems += 1
		if vi > 0 and _offer_keys(v) != _offer_keys(visits[vi - 1]):
			differ += 1
	var sys_frac: float = float(with_systems) / float(visits.size())
	var diff_frac: float = float(differ) / float(visits.size() - 1)
	print("LEDGER L-STO-01 systems shown in %.1f%% of %d visits; %.1f%% of consecutive pairs differ" % [sys_frac * 100.0, visits.size(), diff_frac * 100.0])
	if sys_frac < 0.55 or sys_frac > 0.9:
		return "systems shown in %.2f of visits" % sys_frac
	if diff_frac < 0.7:
		return "only %.2f of pairs of visits differ" % diff_frac
	return ""


func test_l_sto_01() -> void:
	var d: DataDB = db()
	var why: String = _judge_sto_01(_visits(d, 1001))
	check(why.is_empty(), "L-STO-01 target: " + why)
	# The hollow trader keeps its short list: supplies and a hire, every visit.
	for v: Variant in _visits(d, 50, 0, 13, "hollow_trader"):
		var secs: Dictionary = _sections_of(v as Array)
		check_eq(secs.keys().size(), 2, "the hollow trader shows supplies and crew")
		check(secs.has("crew") and int(secs["crew"]) == 1, "with one hire")
	# The same seed and visit give the same stock (a replay of the open).
	var a := Sim.new(db(), 23, LIGHT, {"mode": "run"})
	var b := Sim.new(db(), 23, LIGHT, {"mode": "run"})
	a.encounter.open_store(a, "crust_trader")
	b.encounter.open_store(b, "crust_trader")
	check_eq(a.encounter.state(), b.encounter.state(), "the same seed opens the same store")
	check_eq(a.state_hash(), b.state_hash(), "and the same hash")
	# Wrong value: a fixed stock list (every section, every offer, every visit).
	var fixed: DataDB = db()
	var st: Dictionary = fixed.table("stores")["crust_trader"]
	st["sections_shown"] = [4, 4]
	for sec: Variant in (st["sections"] as Array):
		var n: int = ((sec as Dictionary)["pool"] as Array).size()
		(sec as Dictionary)["offers"] = [n, n]
	check(not _judge_sto_01(_visits(fixed, 1001)).is_empty(), "L-STO-01 wrong value (a fixed stock list) must fail")


# L-STO-02 ----------------------------------------------------------------------------------------

func _judge_sto_02(d: DataDB) -> String:
	var rare: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
	var bands: Array = [[1, 4], [10, 13]]
	for b: int in range(2):
		var visits: Array = _visits(d, 1000, int(bands[b][0]), int(bands[b][1]))
		var rolled: Dictionary = {}
		var common: Dictionary = {}
		for v: Variant in visits:
			var seen: Dictionary = {}
			for line: Variant in (v as Array):
				var ld: Dictionary = line
				var sec: String = str(ld["section"])
				if sec == "supplies":
					continue
				if not seen.has(sec):
					seen[sec] = false
				if int(ld["rarity"]) == 1:
					seen[sec] = true
				if sec == "gear" and int(ld["rarity"]) >= 4:
					rare[b] += 1.0
			for sec: Variant in seen.keys():
				rolled[sec] = int(rolled.get(sec, 0)) + 1
				if bool(seen[sec]):
					common[sec] = int(common.get(sec, 0)) + 1
		for sec: Variant in rolled.keys():
			var frac: float = float(int(common.get(sec, 0))) / float(int(rolled[sec]))
			print("LEDGER L-STO-02 rows %d-%d: a rarity-1 %s offer in %.1f%% of %d stores showing it" % [
				int(bands[b][0]), int(bands[b][1]), str(sec), frac * 100.0, int(rolled[sec])])
			if frac < 0.5:
				return "rows %d-%d: a rarity-1 %s offer in only %.2f of stores" % [int(bands[b][0]), int(bands[b][1]), str(sec), frac]
	var ratio: float = rare[1] / maxf(1.0, rare[0])
	print("LEDGER L-STO-02 rarest gear in %d stores at rows 1-4, %d at rows 10-13: %.2f x" % [int(rare[0]), int(rare[1]), ratio])
	if ratio < 1.6:
		return "the rarest gear is only %.2f x as common deep down" % ratio
	return ""


func test_l_sto_02() -> void:
	var why: String = _judge_sto_02(db())
	check(why.is_empty(), "L-STO-02 target: " + why)
	var flat: Dictionary = {}  # Wrong value: rarity ignored (every weight equal, no depth gain).
	for r: int in range(1, 6):
		flat["economy.store_rarity_weight_%d" % r] = 1.0
		flat["economy.store_rarity_depth_gain_%d" % r] = 0.0
	check(not _judge_sto_02(db(flat)).is_empty(), "L-STO-02 wrong value (rarity ignored) must fail")


# L-STO-03 ----------------------------------------------------------------------------------------

func _judge_sto_03(visits: Array, prices: Dictionary) -> String:
	var lo: int = 99
	var hi: int = -99
	for v: Variant in visits:
		for line: Variant in (v as Array):
			var ld: Dictionary = line
			if str(ld["item"]) != "res":
				continue
			var n: int = int(ld["stock"])
			if n < 2 or n > 6:
				return "%s rolled a stock of %d" % [str(ld["res"]), n]
			if int(ld["price"]) != int(prices[str(ld["res"])]):
				return "%s costs %d, not today's %d" % [str(ld["res"]), int(ld["price"]), int(prices[str(ld["res"])])]
			lo = mini(lo, n)
			hi = maxi(hi, n)
	print("LEDGER L-STO-03 supply stocks rolled %d to %d" % [lo, hi])
	return ""


func test_l_sto_03() -> void:
	var prices: Dictionary = {"coolant": 6, "cells": 8, "bits": 10, "charges": 8}
	var why: String = _judge_sto_03(_visits(db(), 300), prices)
	check(why.is_empty(), "L-STO-03 target: " + why)
	# Buying more than the shelf holds is refused with a reason.
	var s := Sim.new(db(), 29, LIGHT, {"mode": "run"})
	s.run.add(s, "gems", 500)
	s.encounter.open_store(s, "crust_trader")
	var n: int = int(s.encounter.visit[0]["stock"])
	check_eq(EncounterStore.refusal(s, s.encounter, 0, n + 1), "only %d left" % n, "more than the stock is refused")
	s.push({"type": "buy", "item": 0, "qty": n})
	s.step()
	check_eq(int(s.encounter.visit[0]["stock"]), 0, "the shelf empties")
	check_eq(EncounterStore.refusal(s, s.encounter, 0, 1), "sold out", "then it is sold out")
	# Wrong value: an unlimited supply line.
	var bad: DataDB = db()
	((bad.table("stores")["crust_trader"] as Dictionary)["supplies"] as Array)[0].erase("stock")
	check(not _judge_sto_03(_visits(bad, 300), prices).is_empty(), "L-STO-03 wrong value (unlimited supplies) must fail")


# L-STO-04 ----------------------------------------------------------------------------------------

## Per-point hull prices by row 0..13, read from rolled visits.
func _hull_prices(d: DataDB) -> PackedFloat64Array:
	var s := Sim.new(d, 31, LIGHT, {"mode": "run"})
	var st: Dictionary = d.table("stores")["crust_trader"]
	var out := PackedFloat64Array()
	for row: int in range(ROWS):
		for line: Dictionary in StoreRoll.roll(s, st, row, ROWS):
			if str(line["item"]) == "hull":
				out.append(float(int(line["price"])) / float(int(line["amount"])))
	return out


func _judge_sto_04(p: PackedFloat64Array) -> String:
	var shallow: float = (p[1] + p[2] + p[3] + p[4]) / 4.0
	var deep: float = (p[10] + p[11] + p[12] + p[13]) / 4.0
	var steps: int = 0
	for r: int in range(1, p.size()):
		if p[r] < p[r - 1]:
			return "the hull price falls at row %d" % r
		if p[r] > p[r - 1]:
			steps += 1
	var ratio: float = deep / shallow
	print("LEDGER L-STO-04 hull %.2f ore a point at rows 1-4, %.2f at rows 10-13 (%.2f x, %d steps)" % [shallow, deep, ratio, steps])
	if ratio < 1.5 or ratio > 2.0:
		return "deep hull costs %.2f x shallow" % ratio
	if steps > 3:
		return "%d price steps" % steps
	return ""


func test_l_sto_04() -> void:
	var why: String = _judge_sto_04(_hull_prices(db()))
	check(why.is_empty(), "L-STO-04 target: " + why)
	var flat: DataDB = db()
	(((flat.table("stores")["crust_trader"] as Dictionary)["supplies"] as Array)[4] as Dictionary)["price_by_row"] = [{"from_row": 0, "price": 2}]
	check(not _judge_sto_04(_hull_prices(flat)).is_empty(), "L-STO-04 wrong value (one price at every row) must fail")


# L-STO-05 ----------------------------------------------------------------------------------------

func _full_store(d: DataDB) -> void:
	var st: Dictionary = d.table("stores")["crust_trader"]
	st["sections_shown"] = [4, 4]
	for sec: Variant in (st["sections"] as Array):
		var n: int = ((sec as Dictionary)["pool"] as Array).size()
		(sec as Dictionary)["offers"] = [n, n]


func _line(s: Sim, key: String, id: String) -> int:
	for i: int in range(s.encounter.visit.size()):
		if str(s.encounter.visit[i][key]) == id:
			return i
	return -1


## Judges a sale: the list price, what the sale paid and in which currency.
func _judge_sto_05(list: int, paid: int, currency: String, want_currency: String) -> String:
	var frac: float = float(paid) / float(list)
	if frac < 0.33 or frac > 0.5:
		return "a sale pays %.2f of the list price" % frac
	if currency != want_currency:
		return "paid in %s, not the item's %s" % [currency, want_currency]
	return ""


func test_l_sto_05() -> void:
	var d: DataDB = db()
	_full_store(d)
	var s := Sim.new(d, 37, LIGHT, {"mode": "run"})
	s.run.add(s, "ore", 2000)
	s.run.add(s, "gems", 100)
	s.encounter.open_store(s, "crust_trader")
	var opened: int = s.tick
	# A weapon: half its 45-gem list price, rounded down, in gems; the slot is freed.
	var gems0: int = s.run.get_res("gems")
	s.push({"type": "sell", "what": "weapon", "id": "borer_turret"})
	s.step()
	var paid: int = s.run.get_res("gems") - gems0
	print("LEDGER L-STO-05 borer turret (45 gems) sold for %d gems" % paid)
	var why: String = _judge_sto_05(45, paid, "gems", "gems")
	check(why.is_empty(), "L-STO-05 target: " + why)
	check_eq(paid, floori(45.0 * d.tune("economy.sell_back_frac")), "floor of the list price x sell_back_frac")
	check_eq(Array(s.ship.weapons), ["charge_launcher"], "the turret is gone, the launcher keeps its place")
	check_eq(EncounterStore.sell_refusal(s, s.encounter, "weapon", "charge_launcher"), "the last weapon aboard stays", "the last weapon stays")
	check_eq(EncounterStore.sell_refusal(s, s.encounter, "weapon", "thermal_lance"), "no thermal_lance aboard", "a weapon not aboard")
	# Gear: the diamond head comes off and the drill's old speed comes back.
	s.push({"type": "buy", "item": _line(s, "gear", "diamond_head"), "qty": 1})
	s.step()
	check_eq(s.run.gear_x("cut_speed_x"), 1.5, "the head is fitted")
	var ore0: int = s.run.get_res("ore")
	s.push({"type": "sell", "what": "gear", "id": "diamond_head"})
	s.step()
	var ore_paid: int = s.run.get_res("ore") - ore0
	print("LEDGER L-STO-05 diamond head (450 ore) sold for %d ore" % ore_paid)
	check(_judge_sto_05(450, ore_paid, "ore", "ore").is_empty(), "gear sells in its own currency")
	check_eq(Array(s.run.gear), [], "the head is gone")
	check_eq(s.run.gear_mult, Gear.multipliers(d, PackedStringArray()), "and every multiplier is back to none")
	s.push({"type": "buy", "item": _line(s, "gear", "hull_plating"), "qty": 1})
	s.step()
	check_eq(EncounterStore.sell_refusal(s, s.encounter, "gear", "hull_plating"), "Hull plating is bolted on whole", "plating cannot come off")
	s.push({"type": "sell", "what": "gear", "id": "hull_plating"})
	s.step()
	check_eq(str(s.events[s.events.size() - 1]["kind"]), "bad_command", "a refused sale is a bad command")
	check_eq(Array(s.run.gear), ["hull_plating"], "and changes nothing")
	# A sale is a command in the replay.
	var r := Sim.new(d, 37, LIGHT, {"mode": "run"})
	r.run.add(r, "ore", 2000)
	r.run.add(r, "gems", 100)
	var ci: int = 0
	while r.tick < s.tick:
		if r.tick == opened:
			r.encounter.open_store(r, "crust_trader")
		while ci < s.command_log.size() and int(s.command_log[ci]["t"]) == r.tick:
			var cmd: Dictionary = s.command_log[ci].duplicate()
			cmd.erase("t")
			r.push(cmd)
			ci += 1
		r.step()
	check_eq(r.state_hash(), s.state_hash(), "the replay of the sales ends in the same hash")
	# A fight after a sale arms only what is aboard (nothing keyed by slot points at a sold gun).
	s.push({"type": "leave"})
	s.step()
	s.combat.start_fight(s, "rival_light", false)
	check_eq(s.combat.player_side.defs.size(), s.ship.weapons.size(), "the fight arms the weapons still aboard")
	# Wrong value: sell-back at the full price.
	var full: int = EncounterStore.sell_price(db({"economy.sell_back_frac": 1.0}), "weapon", "borer_turret")
	check(not _judge_sto_05(45, full, "gems", "gems").is_empty(), "L-STO-05 wrong value (full price) must fail")


## The drill reads gear when a segment begins: a head sold before a segment gives exactly the speed
## of a ship that never had it; a segment begun with the head runs faster; mid-dig it cannot be sold.
func test_l_sto_05_drill_undo() -> void:
	var with_head: Sim = _dig_sim(41, "keep")
	var sold: Sim = _dig_sim(41, "sell")
	var never: Sim = _dig_sim(41, "none")
	check_eq(with_head.drill._cut_x, 1.5, "a segment begun with the head reads it")
	check_eq(sold.drill._cut_x, 1.0, "a segment begun after the sale does not")
	check_eq(sold.drill.speed_m_s, never.drill.speed_m_s, "the old speed exactly")
	check_gt(with_head.drill.speed_m_s, never.drill.speed_m_s, "the head was faster")
	# Mid-dig: a trader opens over the live drill (as a structure's does).
	with_head.encounter.open_store(with_head, "hollow_trader")
	check(with_head.drill.active and with_head.run.phase == "store", "a mid-dig store is open")
	check_eq(EncounterStore.sell_refusal(with_head, with_head.encounter, "gear", "diamond_head"), "not while the drill is cutting",
			"drill gear cannot come off mid-segment")


## A light drill that visits a full store (buying the diamond head and keeping it, buying and selling
## it, or buying nothing), leaves, and digs 1 s of a segment.
func _dig_sim(p_seed: int, plan: String) -> Sim:
	var d: DataDB = db()
	_full_store(d)
	var s := Sim.new(d, p_seed, LIGHT, {"mode": "run"})
	s.run.add(s, "ore", 2000)
	s.encounter.open_store(s, "crust_trader")
	if plan != "none":
		s.push({"type": "buy", "item": _line(s, "gear", "diamond_head"), "qty": 1})
	s.step()
	if plan == "sell":
		s.push({"type": "sell", "what": "gear", "id": "diamond_head"})
	s.step()
	s.push({"type": "leave"})
	s.step()
	s.push({"type": "begin_segment", "segment": "sale", "depth_m": 60.0, "lateral_m": 0.0})
	run_seconds(s, 1.0)
	check(s.drill.active, "%s: the segment is under way" % plan)
	return s
