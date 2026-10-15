extends TestCase
## A thin full run (game/sim/run): travel by choose_node, power cells and reserve speed, arrival, the
## pursuer (time, noise, overtaken nodes, strikes when caught, never passing the ship), a full run
## with RunBot to the end, its replay, the summary, and the profile and run record round trip.


func _sim(p_seed: int = 7) -> Sim:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.step()
	return s


func _first_link(s: Sim) -> String:
	return s.run.links_from_current()[0]


func _count(s: Sim, kind: String) -> int:
	var n: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind:
			n += 1
	return n


func _last(s: Sim, kind: String) -> Dictionary:
	for i: int in range(s.events.size() - 1, -1, -1):
		if str(s.events[i]["kind"]) == kind:
			return s.events[i]
	return {}


## Drive the drill with DrillBot until the segment ends (or a cap).
func _drive(s: Sim, cap_s: float = 200.0) -> void:
	var bot: Bot = Bot.make("drill")
	var cap: int = roundi(cap_s * Sim.TICK_HZ)
	while s.run.phase == "drill" and cap > 0:
		bot.act(s)
		s.step()
		cap -= 1


func test_choose_only_linked_nodes_and_spend_a_cell() -> void:
	var s: Sim = _sim()
	var far: String = str(((s.run.map[2] as Array)[0] as Dictionary)["id"])
	s.push({"type": "choose_node", "node": far})
	s.step()
	check_eq(s.run.phase, "idle", "a node two rows down is refused")
	check_eq(str(_last(s, "bad_command").get("type", "")), "choose_node", "with a bad_command event")
	var to: String = _first_link(s)
	s.push({"type": "choose_node", "node": to})
	s.step()
	check_eq(s.run.phase, "drill", "a linked node starts a segment")
	check_eq(s.run.target_node, to, "the target is set")
	check_eq(s.run.get_res("cells"), 7, "one power cell spent")
	check_eq(s.drill.speed_scale, 1.0, "full speed with cells")
	check_eq(s.drill.segment_id, "r0c0-" + to, "the segment is named from-to")
	check_eq(s.drill.depth_m, float(s.run.layer["row_depth_m"]), "one row is the layer row depth of rock")
	s.push({"type": "choose_node", "node": to})
	s.step()
	check_eq(s.run.get_res("cells"), 7, "no second cell while drilling")
	check_eq(_count(s, "bad_command"), 2, "choosing while drilling is refused")


func test_no_cells_runs_at_half_speed() -> void:
	var a: Sim = _sim(4)
	var b: Sim = _sim(4)
	b.run.add(b, "cells", -100)
	var to: String = _first_link(a)
	a.push({"type": "choose_node", "node": to})
	b.push({"type": "choose_node", "node": to})
	a.step()
	b.step()
	check_eq(b.run.phase, "drill", "travel still works on reserve")
	check_eq(b.run.get_res("cells"), 0, "cells stay at zero")
	check_eq(b.drill.speed_scale, 0.5, "running on reserve")
	check(bool(_last(b, "travel").get("reserve", false)), "the travel event says reserve")
	# The segment's first drive tick ran in the same step (later ticks differ: bit wear follows distance).
	check_gt(a.drill.speed_m_s, 0.0, "the drill moves")
	check_eq(b.drill.speed_m_s, a.drill.speed_m_s * 0.5, "exactly half the speed on the same rock")


func test_arrival_makes_the_node_current_and_hands_it_on() -> void:
	var s: Sim = _sim(12)
	var to: String = _first_link(s)
	var kind: String = str(s.run.node(to)["type"])
	s.push({"type": "choose_node", "node": to})
	s.step()
	_drive(s)
	var want_phase: Dictionary = {"store": "store", "event": "dialog", "cavern": "dialog", "hazard": "dialog", "fight": "idle"}
	check_eq(s.run.phase, str(want_phase.get(kind, "idle")), "the node's module took over (%s)" % kind)
	check_eq(s.run.current_node, to, "the node is current")
	check(s.run.is_visited(s.run.node(to)), "and visited")
	check_eq(s.run.depth_m, float(s.run.layer["row_depth_m"]), "depth is the row's depth exactly")
	check_eq(str(_last(s, "arrived").get("node", "")), to, "an arrived event")
	if kind == "fight":
		check_eq(_count(s, "fight_skipped"), 1, "the fight went to combat (stub until step 4)")
	elif kind == "store":
		check(not s.encounter.current_store().is_empty(), "the store is open")
	else:
		check(not s.encounter.current_event().is_empty(), "an event page is open")


func test_pursuer_advances_with_time_and_noise() -> void:
	var s: Sim = _sim()
	var rate: float = float((s.run.layer["pursuer"] as Dictionary)["rows_per_s"])
	var per_noise: float = float((s.run.layer["pursuer"] as Dictionary)["rows_per_noise"])
	var p0: float = s.run.pursuer_row
	run_seconds(s, 30.0)
	check(absf(s.run.pursuer_row - p0 - rate * 30.0) < 0.000001, "time alone: rows_per_s * 30 s (got %.6f)" % (s.run.pursuer_row - p0))
	var p1: float = s.run.pursuer_row
	s.drill.noise_total += 100.0
	s.step()
	check(absf(s.run.pursuer_row - p1 - (rate / 60.0 + per_noise * 100.0)) < 0.000001, "noise adds rows_per_noise per unit")
	s.run.set_phase(s, "dialog")
	var p2: float = s.run.pursuer_row
	run_seconds(s, 10.0)
	check_eq(s.run.pursuer_row, p2, "frozen while a dialog is open")


func test_caught_strikes_and_never_passes() -> void:
	var s: Sim = _sim()
	s.run.move_pursuer(s, 10.0)
	var cap: float = 1.0 - s.db.tune("run.pursuer_cap_gap_rows")
	check_eq(s.run.pursuer_row, cap, "capped just below the ship's row plus one")
	check(not s.run.is_overtaken((s.run.map[1] as Array)[0]), "it never swallows the next row while the ship waits")
	var hull: int = s.run.get_res("hull")
	s.step()
	check(s.run.caught, "caught")
	check_eq(_count(s, "pursuer_caught"), 1, "a caught event")
	run_seconds(s, 7.9)
	check_eq(s.run.strikes, 0, "no strike before strike_every_s")
	run_seconds(s, 0.2)
	check_eq(s.run.strikes, 1, "the first strike after strike_every_s")
	check_eq(s.run.get_res("hull"), hull - 2, "a strike costs hull")
	var strike: Dictionary = _last(s, "pursuer_strike")
	check_eq(str(_last(s, "breach").get("room", "")), str(strike["room"]), "a breach in the struck room")
	check_eq(str(strike["why"]), "caught", "struck because caught")
	run_seconds(s, 16.0)
	check_eq(s.run.strikes, 3, "and again every strike_every_s")
	check(s.run.pursuer_row <= cap, "still never past the cap")


func test_overtaken_node_is_lost_on_arrival() -> void:
	var s: Sim = _sim(3)
	var to: String = _first_link(s)
	s.push({"type": "choose_node", "node": to})
	s.step()
	var bot: Bot = Bot.make("drill")
	while s.drill.progress() < 0.5 and s.run.phase == "drill":
		bot.act(s)
		s.step()
	s.run.move_pursuer(s, 10.0)
	check(s.run.pursuer_row < s.run.ship_row_f(s) + 1.0, "the cap follows the drilling ship")
	check(s.run.is_overtaken(s.run.node(to)), "the row ahead is swallowed")
	check_gt(float(_count(s, "overtaken")), 0.0, "overtaken events")
	var hull: int = s.run.get_res("hull")
	_drive(s)
	check_eq(s.run.current_node, to, "the ship still arrives")
	check_eq(str(_last(s, "node_lost").get("node", "")), to, "its content is gone")
	check_eq(str(_last(s, "pursuer_strike").get("why", "")), "overtaken", "the pursuer strikes instead")
	check(s.run.get_res("hull") < hull, "hull lost")
	check_eq(s.run.phase, "idle", "back to idle")
	check_eq(_count(s, "node_skipped") + _count(s, "fight_skipped"), 0, "the node's module never ran")


func test_scenario_mode_drilling_unchanged() -> void:
	var s := Sim.new(db(), 2, "light_drill")
	s.push({"type": "begin_segment", "segment": "x", "depth_m": 6.0, "lateral_m": 0.0})
	s.step()
	_drive(s, 60.0)
	check_eq(s.run.phase, "scenario", "a scenario segment returns to scenario")
	var r: Sim = _sim(2)
	r.push({"type": "begin_segment", "segment": "x", "depth_m": 6.0, "lateral_m": 0.0})
	r.step()
	_drive(r, 60.0)
	check_eq(r.run.phase, "idle", "a bare segment in a run returns to idle")
	check_eq(r.run.current_node, "r0c0", "without moving on the map")


func test_full_run_ends_replays_and_saves() -> void:
	var fr: FullRun = FullRun.start(db(), 31, "run", {"known_codex": ["mohole"]})
	fr.play_to_end()
	check(fr.outcome == "dead" or fr.outcome == "won", "the run ends dead or won, not %s (%s)" % [fr.outcome, fr.cause])
	var sum: Dictionary = fr.summary()
	for key: String in ["result", "cause", "depth_m", "rows_reached", "time_s", "gained", "spent", "fights_won",
			"codex", "crew_lost", "seed", "ship", "strikes", "hash"]:
		check(sum.has(key), "summary has " + key)
	check_eq(str(sum["result"]), fr.outcome, "summary result")
	check_eq(int(sum["seed"]), 31, "summary seed")
	if fr.outcome == "won":
		check_eq(int(sum["rows_reached"]), 9, "a win reached the gate row")
		check_eq(float(sum["depth_m"]), 9.0 * float(fr.sim.run.layer["row_depth_m"]), "nine rows of the layer row depth")
	check_gt(float((sum["gained"] as Dictionary)["ore"]), 0.0, "ore mined on the way")
	var again: Sim = Sim.replay(db(), 31, "light_drill", fr.sim.command_log, fr.sim.tick, fr.sim.options)
	check_eq(again.state_hash(), fr.sim.state_hash(), "seed, options and command log rebuild the whole run")
	# Profile and record round trip, in a folder under harness/out (never user://).
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../harness/out/test_run/full").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var prof: Profile = Profile.load_from(dir)
	prof.merge_run(sum, fr.sim.run.learned)
	check(prof.save(), "profile saved")
	var back: Profile = Profile.load_from(dir)
	check_eq(back.runs, 1, "the run is counted")
	check_eq(back.best_depth_m, float(sum["depth_m"]), "best depth from the summary")
	var path: String = RunRecord.save(dir, fr.sim, sum, "20261015-000000")
	var rec_sim: Sim = RunRecord.replay(db(), RunRecord.load_record(path))
	check_eq(rec_sim.state_hash(), fr.sim.state_hash(), "the run record replays the whole run")


func test_no_leaks_over_many_full_runs() -> void:
	var d: DataDB = db()
	var warm: FullRun = FullRun.start(d, 1, "run", {}, "light_drill", 5.0)
	warm.play_to_end()
	warm = null
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i: int in range(40):
		var fr: FullRun = FullRun.start(d, 100 + i, "run", {}, "light_drill", 5.0)
		fr.play_to_end()
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	check_lt(float(after - before), 50.0, "objects return to the baseline after 40 full runs (before %d, after %d)" % [before, after])


func test_full_run_stuck_bot_hits_the_cap() -> void:
	var fr: FullRun = FullRun.start(db(), 5, "idle", {}, "light_drill", 20.0)
	fr.play_to_end()
	check_eq(fr.outcome, "stuck", "a bot that never travels ends as stuck at the cap")
	check_eq(fr.sim.tick, 1200, "exactly at the cap")
	check_eq(str(fr.summary()["result"]), "stuck", "the summary says stuck")
