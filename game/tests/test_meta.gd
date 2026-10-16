extends TestCase
## Research and requisitions (game/meta/research.gd, game/sim/run/requisitions.gd, the profile and the
## requisitions screen). Tests write under harness/out, never user://.

const ALL_IDS: Array = ["charge_crate", "coolant_tank", "field_plating", "fourth_hand", "spare_bits", "tungsten_start"]


func _scratch(p_name: String) -> String:
	var d: String = ProjectSettings.globalize_path("res://").path_join("../harness/out/test_meta").path_join(p_name).simplify_path()
	DirAccess.make_dir_recursive_absolute(d)
	for f: String in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	return d


func _run_sim(d: DataDB, ids: Array, mode: String = "run", run_seed: int = 31) -> Sim:
	return Sim.new(d, run_seed, "light_drill", {"mode": mode, "known_codex": [], "requisitions": ids})


# Research ---------------------------------------------------------------------------------------

func test_research_lines_and_rounding() -> void:
	check_eq(Research.earned({}), 0, "an empty summary earns nothing")
	check_eq(Research.earned({"rows_reached": 7}), 14, "2 per row reached")
	check_eq(Research.earned({"codex": ["a", "b", "c"]}), 15, "5 per codex entry")
	check_eq(Research.earned({"fights_won": 2}), 6, "3 per fight won")
	check_eq(Research.earned({"result": "won"}), 15, "15 for the gate")
	check_eq(Research.earned({"result": "dead"}), 0, "no gate bonus for a death")
	check_eq(Research.earned({"gained": {"ore": 39}}), 0, "ore rounds down (39)")
	check_eq(Research.earned({"gained": {"ore": 40}}), 1, "one per 40 ore")
	check_eq(Research.earned({"gained": {"ore": 119}}), 2, "ore rounds down (119)")
	var sum: Dictionary = {"result": "dead", "rows_reached": 8, "codex": ["a", "b"], "fights_won": 1, "gained": {"ore": 412, "gems": 90}}
	var r: Dictionary = Research.compute(sum)
	check_eq(int(r["total"]), 16 + 10 + 3 + 10, "a build 3 style death adds up")
	check_eq((r["lines"] as Array).size(), 4, "four lines (no gate)")
	var won: Dictionary = Research.compute({"result": "won", "rows_reached": 11})
	check_eq(int(won["total"]), 22 + 15, "a win lists the gate line")


func test_research_matches_the_real_summary() -> void:
	var fr: FullRun = FullRun.start(db(), 5, "run", {"known_codex": []}, "light_drill", 400.0)
	fr.play_to_end()
	var sum: Dictionary = fr.sim.run.summary(fr.sim)
	var want: int = 2 * int(sum["rows_reached"]) + 5 * (sum["codex"] as Array).size() + 3 * int(sum["fights_won"]) \
			+ (15 if str(sum["result"]) == "won" else 0) + int((sum["gained"] as Dictionary)["ore"]) / 40
	check_eq(Research.earned(sum), want, "the formula agrees with a played run's summary")


# Profile ----------------------------------------------------------------------------------------

func test_profile_round_trip_with_research() -> void:
	var d: String = _scratch("round")
	var p: Profile = Profile.load_from(d)
	p.merge_run({"result": "dead", "cause": "hull", "depth_m": 100.0, "rows_reached": 5, "fights_won": 1}, PackedStringArray())
	check_eq(p.research, 13, "merge_run banks the run's research")
	check_eq(p.last_research, 13, "and remembers what it was")
	p.requisitions = PackedStringArray(["spare_bits", "charge_crate"])
	check(p.save(), "saved")
	var q: Profile = Profile.load_from(d)
	check_eq(q.research, 13, "research survives a reload")
	check_eq(Array(q.requisitions), ["charge_crate", "spare_bits"], "owned requisitions survive, sorted")
	check_eq(Array(q.run_options()["requisitions"]), ["charge_crate", "spare_bits"], "run options carry the owned ids")


func test_old_profile_without_research_loads() -> void:
	var d: String = _scratch("old")
	var f: FileAccess = FileAccess.open(d.path_join(Profile.FILE_NAME), FileAccess.WRITE)
	f.store_string('{"version": 1, "known_codex": ["mohole"], "runs": 3, "wins": 0, "best_depth_m": 80.0, "deaths": {}, "unlocks": [], "history": []}')
	f.close()
	var p: Profile = Profile.load_from(d)
	check_eq(p.runs, 3, "the old fields load")
	check_eq(p.research, 0, "research is 0")
	check(p.requisitions.is_empty(), "no requisitions")
	check_eq((p.run_options()["requisitions"] as Array).size(), 0, "and the options list none")


func test_buy_deducts_and_refuses() -> void:
	var d: DataDB = db()
	var p := Profile.new()
	check(not p.buy("spare_bits", d).is_empty(), "short of research: refused")
	check_eq(p.research, 0, "nothing deducted on a refusal")
	check(p.requisitions.is_empty(), "nothing owned on a refusal")
	p.research = 50
	check_eq(p.buy("spare_bits", d), "", "bought with enough research")
	check_eq(p.research, 30, "the cost (20) is deducted")
	check(p.owns("spare_bits"), "owned")
	check(not p.buy("spare_bits", d).is_empty(), "owned: refused")
	check_eq(p.research, 30, "no second charge")
	check(not p.buy("field_plating", d).is_empty(), "40 against 30: refused")
	check(not p.buy("no_such_thing", d).is_empty(), "unknown id: refused")
	check_eq(p.buy("charge_crate", d), "", "a second item")
	check_eq(Array(p.requisitions), ["charge_crate", "spare_bits"], "kept sorted")


# The sim ----------------------------------------------------------------------------------------

func test_run_with_requisitions_starts_loaded() -> void:
	var d: DataDB = db()
	var base: Sim = _run_sim(d, [])
	var s: Sim = _run_sim(d, ALL_IDS)
	check_eq(s.run.get_res("bits"), base.run.get_res("bits") + 1, "+1 bit")
	check_eq(s.run.get_res("charges"), base.run.get_res("charges") + 3, "+3 charges")
	check_eq(s.run.get_res("coolant"), base.run.get_res("coolant") + 6, "+6 coolant")
	check_eq(s.ship.hull_max, base.ship.hull_max + 5, "+5 max hull")
	check_eq(s.run.get_res("hull"), s.ship.hull_max, "and the hull is full")
	check(s.run.gear.has("tungsten_head"), "the tungsten head is fitted")
	check_gt(s.run.gear_x("cut_speed_x"), 1.2, "and its multipliers apply")
	check_eq(s.ship.crew.size(), base.ship.crew.size() + 1, "a fourth crew member")
	check_eq(s.encounter.joined.size(), 1, "from the survivors pool")
	check(has_event(s, "requisitions"), "the load is an event")
	check_eq(int(base.run.summary(base)["gained"]["bits"]), 0, "the load is not counted as gained")
	check_eq(int(s.run.summary(s)["gained"]["bits"]), 0, "not even with requisitions")
	run_seconds(s, 2.0)
	run_seconds(base, 2.0)
	check(s.run.phase == "idle" and not s.run.is_over(), "the loaded run is alive")


func test_scenario_ignores_requisitions() -> void:
	var d: DataDB = db()
	var plain := Sim.new(d, 9, "light_drill", {})
	var loaded := Sim.new(d, 9, "light_drill", {"requisitions": ALL_IDS})
	check_eq(loaded.ship.crew.size(), plain.ship.crew.size(), "no extra crew in a scenario")
	check_eq(loaded.ship.hull_max, plain.ship.hull_max, "no extra hull in a scenario")
	run_seconds(plain, 3.0)
	run_seconds(loaded, 3.0)
	check(not has_event(loaded, "requisitions"), "nothing was loaded")


func test_requisition_run_replays_exactly() -> void:
	var d: DataDB = db()
	var s: Sim = _run_sim(d, ALL_IDS, "run", 77)
	var bot: Bot = Bot.make("run")
	for i: int in range(60 * 90):
		bot.act(s)
		s.step()
	var again: Sim = Sim.replay(d, 77, "light_drill", s.command_log, s.tick, s.options)
	check_eq(again.state_hash(), s.state_hash(), "a replay from seed, options and commands ends in the same hash")
	check_eq(Array(again.options["requisitions"]), ALL_IDS, "the owned ids are in the replay header")
	# Through a record on disk (JSON turns numbers into floats and arrays stay arrays).
	var dir: String = _scratch("record")
	var path: String = RunRecord.save(dir, s, s.run.summary(s), "20261016-000000")
	var rec: Dictionary = RunRecord.load_record(path)
	check_eq(Array((rec["options"] as Dictionary)["requisitions"]), ALL_IDS, "the record carries them")
	var from_file: Sim = RunRecord.replay(d, rec)
	check_eq(from_file.state_hash(), s.state_hash(), "and replays from the file")
	var without: Sim = _run_sim(d, [], "run", 77)
	check(without.state_hash() != _run_sim(d, ALL_IDS, "run", 77).state_hash(), "requisitions change the starting state")


# Data lint --------------------------------------------------------------------------------------

func test_shipped_requisitions_lint_clean() -> void:
	var d: DataDB = db()
	check_eq(d.table("requisitions").size(), 6, "six requisitions ship")
	var errs := PackedStringArray()
	RequisitionsLint.lint(d, errs)
	check(errs.is_empty(), "no lint errors: %s" % ("; ".join(errs)))
	check_eq(Array(Requisitions.ordered_ids(d)), ["spare_bits", "charge_crate", "coolant_tank", "field_plating", "tungsten_start", "fourth_hand"], "screen order")


func test_lint_catches_bad_requisitions() -> void:
	var d: DataDB = db()
	d.tables["requisitions"]["bad_cost"] = {"id": "bad_cost", "name": "x", "blurb": "y", "cost": 0, "order": 90, "effects": {"max_hull": 2}}
	d.tables["requisitions"]["bad_res"] = {"id": "bad_res", "name": "x", "blurb": "y", "cost": 5, "order": 91, "effects": {"start_resources": {"gold": 1}}}
	d.tables["requisitions"]["bad_gear"] = {"id": "bad_gear", "name": "x", "blurb": "y", "cost": 5, "order": 92, "effects": {"gear": ["nope"]}}
	d.tables["requisitions"]["bad_hull"] = {"id": "bad_hull", "name": "x", "blurb": "y", "cost": 5, "order": 93, "effects": {"start_resources": {"hull": 2}}}
	d.tables["requisitions"]["bad_effect"] = {"id": "bad_effect", "name": "x", "blurb": "y", "cost": 5, "order": 94, "effects": {"teleport": 1}}
	d.tables["requisitions"]["bad_empty"] = {"id": "bad_empty", "name": "", "blurb": "y", "cost": 5, "order": 6, "effects": {}}
	var errs := PackedStringArray()
	RequisitionsLint.lint(d, errs)
	var text: String = "\n".join(errs)
	for needle: String in ["cost must be", "\"gold\" is not a resource", "gear \"nope\"", "\"hull\" is not a resource", "unknown effect \"teleport\"",
			"needs a name", "order 6 is also used", "effects must be a non-empty"]:
		check(text.contains(needle), "lint reports: %s" % needle)


# The screens ------------------------------------------------------------------------------------

func test_requisitions_view_buys() -> void:
	var d: DataDB = db()
	var p := Profile.new()
	p.research = 35
	var host := Control.new()
	var v: RequisitionsView = RequisitionsView.build(host, d, p)
	v.save_on_buy = false
	check_eq(Array(v.row_ids()), Array(Requisitions.ordered_ids(d)), "one row per requisition, in order")
	check_eq(v.buy("field_plating"), "needs 5 more research", "a short balance is explained")
	check_eq(v.buy("coolant_tank"), "", "an affordable one is bought")
	check_eq(p.research, 10, "the view spent the research")
	check(p.owns("coolant_tank"), "and the profile owns it")
	check(not v.buy("coolant_tank").is_empty(), "no double purchase")
	host.free()


func test_death_screen_shows_research() -> void:
	var d: DataDB = db()
	var s: Sim = _run_sim(d, [])
	s.run.end_run(s, "dead", "hull")
	run_seconds(s, 0.1)
	var p := Profile.new()
	p.merge_run(s.run.summary(s), s.run.learned)
	var host := Control.new()
	var ds: DeathScreen = DeathScreen.build(host, s, p)
	check(ds.requisitions != null, "the death screen owns a requisitions screen")
	check_eq(ds.requisitions.profile, p, "bound to the profile")
	check(ds.requisitions.db != null, "and the data")
	host.free()
