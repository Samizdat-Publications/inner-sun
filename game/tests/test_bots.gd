extends TestCase
## The policy bots (cautious, greedy, balanced) play whole runs through commands only: each finishes
## (dead or won, never stuck) on several seeds, the same seed gives the same hash, and each fires its
## weapons in its first fight. To keep check fast the runs use a short copy of the crust layer (four
## rows of 14 m: start, two middle rows, the gate against the light rival); the full layer at scale is the
## balance tool's job (python tools/balance.py --full).

const BOTS: Array[String] = ["cautious", "greedy", "balanced"]
const SEEDS: Array[int] = [11, 12]
const CAP_S: float = 1200.0


func _db() -> DataDB:
	var d: DataDB = db()
	var short: Dictionary = (d.table("layers")["crust"] as Dictionary).duplicate(true)
	short["id"] = "bot_test"
	short["rows"] = 4
	short["row_depth_m"] = 14.0
	short["store_rows"] = [1, 2]
	short["min_fights_per_path"] = 1
	short["gate_enemy"] = "rival_light"
	d.table("layers")["bot_test"] = short
	return d


func _play(d: DataDB, bot: String, p_seed: int) -> FullRun:
	var fr: FullRun = FullRun.start(d, p_seed, bot, {"layer": "bot_test"}, "light_drill", CAP_S)
	fr.play_to_end()
	return fr


## Player volleys fired between the first fight_start and its fight_over.
func _shots_in_first_fight(s: Sim) -> int:
	var inside: bool = false
	var n: int = 0
	for e: Dictionary in s.events:
		var kind: String = str(e["kind"])
		if kind == "fight_start" and not inside:
			inside = true
		elif inside and kind == "weapon_fired" and not e.has("side"):
			n += 1
		elif inside and kind == "fight_over":
			break
	return n


func test_policy_bots_finish_deterministically_and_fight_back() -> void:
	var d: DataDB = _db()
	for bot: String in BOTS:
		check(Bot.make(bot) is PolicyBot, "Bot.make knows %s" % bot)
		check(DataDB.KNOWN_BOTS.has(bot), "the data lint knows %s" % bot)
		for p_seed: int in SEEDS:
			var fr: FullRun = _play(d, bot, p_seed)
			check(fr.outcome == "dead" or fr.outcome == "won", "%s seed %d ends dead or won, not %s (%s)" % [bot, p_seed, fr.outcome, fr.cause])
			check(has_event(fr.sim, "fight_start"), "%s seed %d meets a fight" % [bot, p_seed])
			check_gt(float(_shots_in_first_fight(fr.sim)), 0.0, "%s seed %d fires in its first fight" % [bot, p_seed])
			check_eq(fr.sim.state_hash(), fr.summary()["hash"], "the summary carries the final hash")
			if p_seed == SEEDS[0]:
				var again: FullRun = _play(d, bot, p_seed)
				check_eq(again.sim.state_hash(), fr.sim.state_hash(), "%s: the same seed gives the same run" % bot)
				check_eq(again.sim.command_log.size(), fr.sim.command_log.size(), "%s: and the same commands" % bot)


## Policies differ where they should: the greedy bot drills harder than the cautious one.
func test_policies_differ() -> void:
	var c: PolicyBot = PolicyBot.make_policy("cautious")
	var g: PolicyBot = PolicyBot.make_policy("greedy")
	check_gt(float(g.drill_bars), float(c.drill_bars), "greedy drills with more bars")
	check_gt(c.risk_down, g.risk_down, "cautious weighs the worst outcome more")
	check_gt(c.flee_hull_frac, g.flee_hull_frac, "cautious flees sooner")


## The bots only push commands: a run replayed from its seed and command log matches.
func test_policy_run_replays() -> void:
	var d: DataDB = _db()
	var fr: FullRun = _play(d, "balanced", SEEDS[1])
	var again: Sim = Sim.replay(d, SEEDS[1], "light_drill", fr.sim.command_log, fr.sim.tick, fr.sim.options)
	check_eq(again.state_hash(), fr.sim.state_hash(), "seed, options and command log rebuild the bot's run")
