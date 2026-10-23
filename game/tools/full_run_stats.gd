class_name FullRunStats
extends RefCounted
## Balance numbers for one finished full run, read back from the sim's event list (nothing in the sim
## changes for this). Adds to the run summary:
##   segments_s: drilling seconds per segment; rows: resources on arrival at each row
##   [row, t_s, hull, ore, gems, coolant, cells, bits, charges]; node_types: types visited in order;
##   events: event ids started; choices: "event/page/option"; outcomes: "event/page/option>next page"
##   (or ">end"); fights: [enemy, boss, result, seconds]; strikes_overtaken, strikes_caught, catches;
##   bit_breaks, coolant_outs, fires, shots_fired (player volleys), bought: "store item line" keys,
##   crew_deaths: "cause@phase" (phase "gate" for the boss fight); killer (see _killer).


static func add_to(sim: Sim, sum: Dictionary) -> void:
	# Row 0 is the run's start, requisitions included (it once read the end-of-run maximum hull).
	var res := {}
	for r: String in RunState.RESOURCES:
		res[r] = int(sim.run.start_resources.get(r, 0))
	var rows: Array = [_snap(0, 0.0, res)]
	var segs: Array = []
	var types: Array = []
	var evs: Array = []
	var choices: Array = []
	var outcomes: Array = []
	var fights: Array = []
	var bought: Array = []
	var deaths: Array = []
	var last_strike_t: int = -1000000
	var fight_strikes: int = 0  # Pursuer strikes since the last fight began.
	var where: String = "idle"  # Phase now, "gate" for the boss fight.
	var pending: String = ""  # The choice waiting for its outcome.
	var fight_t: int = 0
	var fight_enemy: String = ""
	var fight_boss: bool = false
	var counts := {"strikes_overtaken": 0, "strikes_caught": 0, "catches": 0, "bit_breaks": 0,
		"coolant_outs": 0, "fires": 0, "shots_fired": 0}
	for e: Dictionary in sim.events:
		var kind: String = str(e["kind"])
		match kind:
			"phase":
				where = str(e["to"])
				if where == "combat" and fight_boss:
					where = "gate"
			"resource":
				res[str(e["res"])] = int(e["now"])
			"arrived":
				rows.append(_snap(int(e["row"]), float(int(e["t"])) / Sim.TICK_HZ, res))
				types.append(str(e["type"]))
			"segment_done":
				segs.append(snappedf(float(e.get("time_s", e.get("seconds", 0.0))), 0.1))
			"event_started":
				evs.append(str(e["event"]))
			"event_choice":
				pending = "%s/%s/%d" % [str(e["event"]), str(e["page"]), int(e["option"])]
				choices.append(pending)
			"event_page":
				if not pending.is_empty():
					outcomes.append(pending + ">" + str(e["page"]))
					pending = ""
			"event_ended":
				if not pending.is_empty():
					outcomes.append(pending + ">end")
					pending = ""
			"fight_start":
				fight_t = int(e["t"])
				fight_strikes = 0
				fight_enemy = str(e["enemy"])
				fight_boss = bool(e.get("boss", false))
				if fight_boss:
					where = "gate"
			"fight_over":
				fights.append([fight_enemy, fight_boss, str(e["result"]), snappedf(float(int(e["t"]) - fight_t) / Sim.TICK_HZ, 0.1)])
			"pursuer_strike":
				last_strike_t = int(e["t"])
				fight_strikes += 1
				var why: String = str(e.get("why", ""))
				counts["strikes_" + why] = int(counts.get("strikes_" + why, 0)) + 1
			"pursuer_caught":
				counts["catches"] += 1
			"bit_broken":
				counts["bit_breaks"] += 1
			"coolant_empty":
				if not e.has("side"):
					counts["coolant_outs"] += 1
			"fire_started":
				if not e.has("side"):
					counts["fires"] += 1
			"weapon_fired":
				if not e.has("side"):
					counts["shots_fired"] += 1
			"bought":
				bought.append("%s %d" % [str(e["store"]), int(e["item"])])
			"crew_died":
				if not e.has("side"):
					deaths.append("%s@%s" % [str(e.get("cause", "")), where])
	# A fight still open at the end (the run ended in it) counts as lost.
	if sim.combat.active:
		fights.append([fight_enemy, fight_boss, "died", snappedf(float(sim.tick - fight_t) / Sim.TICK_HZ, 0.1)])
	sum["killer"] = _killer(sim, sum, last_strike_t, fight_boss, fight_strikes)
	sum["segments_s"] = segs
	sum["rows"] = rows
	sum["node_types"] = types
	sum["events"] = evs
	sum["choices"] = choices
	sum["outcomes"] = outcomes
	sum["fights"] = fights
	sum["bought"] = bought
	sum["crew_deaths"] = deaths
	for k: String in ["strikes_overtaken", "strikes_caught", "catches", "bit_breaks", "coolant_outs", "fires", "shots_fired"]:
		sum[k] = int(counts.get(k, 0))


## What ended a lost run, finer than the run's end cause: "gate" or "rival" (died in that fight;
## "_pursued" added when the pursuer struck three or more times during it),
## "pursuer" (a strike in the last 10 s), "event" (on a page), else the end cause while drilling
## ("drill_hull", "drill_crew_fire", "drill_flooded", ...). "" for a won run.
static func _killer(sim: Sim, sum: Dictionary, last_strike_t: int, boss: bool, fight_strikes: int) -> String:
	var result: String = str(sum.get("result", ""))
	if result == "won":
		return ""
	if result == "stuck":
		return "stuck"
	if sim.combat.active:
		return ("gate" if boss else "rival") + ("_pursued" if fight_strikes >= 3 else "")
	if sim.tick - last_strike_t <= roundi(10.0 * Sim.TICK_HZ):
		return "pursuer"
	for i: int in range(sim.events.size() - 1, -1, -1):
		var e: Dictionary = sim.events[i]
		if str(e["kind"]) == "phase" and str(e["to"]) == "dead":
			if str(e["from"]) == "dialog":
				return "event"
			break
	return "drill_" + str(sum.get("cause", ""))


static func _snap(row: int, t: float, res: Dictionary) -> Array:
	return [row, snappedf(t, 0.1), int(res["hull"]), int(res["ore"]), int(res["gems"]), int(res["coolant"]),
		int(res["cells"]), int(res["bits"]), int(res["charges"])]
