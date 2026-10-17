class_name PolicyChoices
extends RefCounted
## The decisions of PolicyBot that read data: which node next, which event option, what to buy.
## Static and read-only: the Sim and the bot are passed in, nothing is stored, nothing is random.
## Everything is generic over the data (node types, effect lists, stock lines), so new events and
## store lines are handled without code changes.

## Rough worth of one unit of each resource, in gems.
const RES_VALUE: Dictionary = {"ore": 0.3, "gems": 1.0, "coolant": 1.2, "cells": 6.0, "bits": 8.0, "charges": 3.0}
const LOOKAHEAD: float = 0.5  ## Share of the best next node's score added to a node's own.


# Map -------------------------------------------------------------------------------------------

## The best node linked from the current one ("" if none). Overtaken nodes only when nothing else.
static func choose_node(sim: Sim, bot: PolicyBot) -> String:
	var run: RunState = sim.run
	var best: String = ""
	var best_score: float = -INF
	for id: String in run.links_from_current():
		var n: Dictionary = run.node(id)
		var score: float = _node_score(sim, bot, n)
		var ahead: float = 0.0
		var first: bool = true
		for nid: String in (n["links"] as PackedStringArray):
			var s2: float = _node_score(sim, bot, run.node(nid))
			if first or s2 > ahead:
				ahead = s2
				first = false
		score += LOOKAHEAD * ahead
		if score > best_score:
			best_score = score
			best = id
	return best


static func _node_score(sim: Sim, bot: PolicyBot, n: Dictionary) -> float:
	var run: RunState = sim.run
	if run.is_overtaken(n):
		return -100.0
	if not run.is_revealed(n):
		return 0.5
	var kind: String = str(n["type"])
	var hull: float = _hull_frac(sim)
	var score: float = float(bot.node_scores.get(kind, 0.0))
	if kind == "store":
		if hull < bot.hurt_frac:
			score += 4.0
		if _needs_supplies(sim, bot):
			score += 2.0
	elif kind == "fight":
		if hull < bot.fight_ok_frac:
			score -= 3.0
	var sv: Dictionary = n.get("survey", {})
	if not sv.is_empty():
		score += bot.survey_weight * (float(sv.get("richness", 1.0)) - 1.0)
		if not (sv.get("gems", []) as Array).is_empty():
			score += bot.gem_bonus
		if bool(sv.get("gas", false)):
			score -= bot.gas_fear
		if bool(sv.get("water", false)):
			score -= bot.water_fear
		if not str(sv.get("structure", "")).is_empty():
			score += bot.structure_bonus
	return score


static func _hull_frac(sim: Sim) -> float:
	return float(sim.run.get_res("hull")) / maxf(1.0, float(sim.ship.hull_max))


static func _rows_left(sim: Sim) -> int:
	return maxi(0, sim.run.map.size() - 1 - sim.run.current_row())


static func _needs_supplies(sim: Sim, bot: PolicyBot) -> bool:
	var run: RunState = sim.run
	if run.get_res("gems") < 8:
		return false
	return run.get_res("coolant") < int(bot.keep.get("coolant", 0)) or run.get_res("cells") < _rows_left(sim) \
			or run.get_res("bits") < int(bot.keep.get("bits", 0))


# Events ----------------------------------------------------------------------------------------

## The option to take on the open page: the best scoring one that is allowed (0 on pages that only
## continue).
static func choose_option(sim: Sim, bot: PolicyBot) -> int:
	var options: Array = sim.encounter.current_page().get("options", [])
	var best: int = 0
	var best_score: float = -INF
	for i: int in range(options.size()):
		if not sim.encounter.option_block(sim, i).is_empty():
			continue
		var s: float = option_score(sim, bot, options[i] as Dictionary)
		if s > best_score:
			best_score = s
			best = i
	return best


## Mean outcome value, pulled toward the worst outcome by risk_down and the best by risk_up.
static func option_score(sim: Sim, bot: PolicyBot, opt: Dictionary) -> float:
	var outcomes: Array = opt.get("outcomes", [])
	if outcomes.is_empty():
		return 0.0
	var total_w: float = 0.0
	var mean: float = 0.0
	var worst: float = INF
	var best: float = -INF
	for o: Variant in outcomes:
		var od: Dictionary = o
		var w: float = maxf(0.0, float(od.get("weight", 1.0)))
		var v: float = 0.0
		for e: Variant in od.get("effects", []):
			v += effect_value(sim, bot, e as Dictionary)
		total_w += w
		mean += w * v
		worst = minf(worst, v)
		best = maxf(best, v)
	if total_w <= 0.0:
		return 0.0
	mean /= total_w
	return mean + bot.risk_down * (worst - mean) + bot.risk_up * (best - mean)


static func effect_value(sim: Sim, bot: PolicyBot, e: Dictionary) -> float:
	var hull_w: float = 3.0 * (1.0 + 2.0 * (1.0 - _hull_frac(sim))) * bot.loss_scale
	match str(e.get("type", "")):
		"res":
			return _res_value(bot, str(e.get("res", "")), float(e.get("amount", 0)))
		"res_range":
			return _res_value(bot, str(e.get("res", "")), 0.5 * float(int(e.get("min", 0)) + int(e.get("max", 0))))
		"hull":
			return float(e.get("amount", 0)) * hull_w
		"crew_damage":
			var n: int = PolicyBot._alive(sim.ship) if str(e.get("target", "picked")) == "all" else 1
			return -float(e.get("amount", 0.0)) * 0.3 * float(n) * bot.loss_scale
		"crew_lose":
			return -40.0 * bot.loss_scale
		"crew_join":
			return 15.0
		"fight":
			return bot.fight_value if _hull_frac(sim) >= bot.fight_ok_frac else minf(bot.fight_value, -10.0)
		"hazard":
			var level: float = float(e.get("level", 0.0))
			match str(e.get("kind", "")):
				"fire":
					return -10.0 * level * bot.loss_scale
				"breach":
					return -150.0 * level * bot.loss_scale
				"heat":
					return -0.01 * level * bot.loss_scale
			return 0.0
		"system_damage":
			return -4.0 * float(e.get("bars", 0)) * bot.loss_scale
		"codex":
			return 2.0
		"pursuer":
			return -15.0 * float(e.get("rows", 0.0)) * bot.loss_scale
		"reveal":
			return 1.5 * float(e.get("rows", 0))
		"store":
			return 5.0
	return 0.0


static func _res_value(bot: PolicyBot, res: String, amount: float) -> float:
	var v: float = float(RES_VALUE.get(res, 1.0)) * amount
	return v * (bot.gain_scale if amount > 0.0 else 1.0)


# Store -----------------------------------------------------------------------------------------

## The next purchase as [stock line, quantity], or [] to leave. Order: hull repairs, then stocking
## resources up to the policy's levels (cells cover the rows left), then extras (gear, upgrades,
## weapons) in policy order while the currency stays above the policy's gem or ore reserve.
static func next_purchase(sim: Sim, bot: PolicyBot) -> Array:
	var enc: Encounter = sim.encounter
	var run: RunState = sim.run
	var stock: Array = enc.current_store().get("stock", [])
	# Hull.
	var frac: float = bot.repair_to_frac if _rows_left(sim) > 2 else maxf(bot.repair_to_frac, bot.gate_repair_frac)
	var want_hull: int = mini(sim.ship.hull_max, ceili(frac * float(sim.ship.hull_max)))
	for i: int in range(stock.size()):
		var d: Dictionary = stock[i]
		if str(d.get("item", "")) != "hull" or run.get_res("hull") >= want_hull:
			continue
		var per: int = maxi(1, int(d.get("amount", 1)))
		var price: int = maxi(1, int(d.get("price", 1)))
		var qty: int = mini(ceili(float(want_hull - run.get_res("hull")) / float(per)),
				run.get_res(str(d.get("currency", "gems"))) / price)
		qty = mini(qty, (sim.ship.hull_max - run.get_res("hull")) / per)
		if qty > 0 and _ok(sim, enc, i, qty):
			return [i, qty]
	# Resources, in a fixed order.
	for res: String in ["cells", "coolant", "bits", "charges"]:
		var target: int = int(bot.keep.get(res, 0))
		if res == "cells":
			target += _rows_left(sim)
		elif res == "charges" and _rows_left(sim) <= 4:
			target += bot.gate_charges
		for i: int in range(stock.size()):
			var d: Dictionary = stock[i]
			if str(d.get("item", "")) != "res" or str(d.get("res", "")) != res or run.get_res(res) >= target:
				continue
			var per: int = maxi(1, int(d.get("amount", 1)))
			var qty: int = ceili(float(target - run.get_res(res)) / float(per))
			var price: int = maxi(1, int(d.get("price", 1)))
			qty = mini(qty, run.get_res(str(d.get("currency", "gems"))) / price)
			if qty > 0 and _ok(sim, enc, i, qty):
				return [i, qty]
	# Extras.
	for want: String in bot.upgrades:
		for i: int in range(stock.size()):
			var d: Dictionary = stock[i]
			if not _matches(d, want):
				continue
			var units: int = _units_worth_buying(sim, d)
			var cost: int = int(d.get("price", 0)) * units
			var cur: String = str(d.get("currency", "gems"))
			if run.get_res(cur) - cost < (bot.gem_reserve if cur == "gems" else bot.ore_reserve if cur == "ore" else 0):
				continue
			if want == "weapon" and not _can_power_weapon(sim, d):
				continue
			if _ok(sim, enc, i, units):
				return [i, units]
	return []


## Bracing bars only help in whole layers: buy as many units as complete the next layer.
static func _units_worth_buying(sim: Sim, d: Dictionary) -> int:
	if str(d.get("item", "")) != "upgrade" or str(d.get("system", "")) != "bracing":
		return 1
	var ri: int = sim.ship.room_with_system("bracing")
	if ri < 0:
		return 1
	var per: int = maxi(1, roundi(sim.db.tune("systems.bracing_bars_per_layer")))
	return per - sim.ship.rooms[ri].sys_max % per


static func _ok(sim: Sim, enc: Encounter, line: int, qty: int) -> bool:
	return EncounterStore.refusal(sim, enc, line, qty).is_empty()


static func _matches(d: Dictionary, want: String) -> bool:
	var item: String = str(d.get("item", ""))
	if want.begins_with("system:"):
		return item == "upgrade" and str(d.get("system", "")) == want.substr(7)
	if want.begins_with("gear:"):
		return item == "gear" and str(d.get("gear", "")) == want.substr(5)
	return item == want


## A bought weapon is only worth it if the weapons system can feed it beside the guns already
## mounted (counting a weapons upgrade still on sale this visit).
static func _can_power_weapon(sim: Sim, d: Dictionary) -> bool:
	var wd: Dictionary = sim.db.table("weapons").get(str(d.get("weapon", "")), {})
	var need: int = int(wd.get("power", 1))
	for wid: String in sim.ship.weapons:
		need += int((sim.db.table("weapons").get(wid, {}) as Dictionary).get("power", 1))
	var wr: int = sim.ship.room_with_system("weapons")
	return wr >= 0 and sim.ship.rooms[wr].sys_max + 1 >= need
