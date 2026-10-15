extends TestCase
## The meta profile and run records (game/meta). Tests write under harness/out, never user://.


func _scratch(p_name: String) -> String:
	var d: String = ProjectSettings.globalize_path("res://").path_join("../harness/out/test_profile").path_join(p_name).simplify_path()
	DirAccess.make_dir_recursive_absolute(d)
	for f: String in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	return d


func test_fresh_profile_when_missing() -> void:
	var p: Profile = Profile.load_from(_scratch("missing"))
	check_eq(p.runs, 0, "a missing file gives a fresh profile")
	check(p.known_codex.is_empty(), "with no codex")
	check_eq(str(p.run_options()["mode"]), "run", "run options start a run")


func test_round_trip_and_merge() -> void:
	var d: String = _scratch("round")
	var p: Profile = Profile.load_from(d)
	p.merge_run({"result": "dead", "cause": "hull", "depth_m": 140.0}, PackedStringArray(["mohole", "kola_well"]))
	p.merge_run({"result": "won", "cause": "gate", "depth_m": 330.0}, PackedStringArray(["kola_well", "byrd_1947"]))
	check(p.save(), "saved")
	var q: Profile = Profile.load_from(d)
	check_eq(q.runs, 2, "runs counted")
	check_eq(q.wins, 1, "wins counted")
	check_eq(int(q.deaths.get("hull", 0)), 1, "deaths by cause")
	check_eq(Array(q.known_codex), ["byrd_1947", "kola_well", "mohole"], "codex merged without duplicates, sorted")
	check_eq(q.best_depth_m, 330.0, "best depth kept")
	check_eq(q.history.size(), 2, "history kept")


func test_corrupt_file_falls_back() -> void:
	var d: String = _scratch("corrupt")
	var f: FileAccess = FileAccess.open(d.path_join(Profile.FILE_NAME), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var p: Profile = Profile.load_from(d)
	check_eq(p.runs, 0, "a corrupt file gives a fresh profile")
	check(FileAccess.file_exists(d.path_join(Profile.FILE_NAME + ".bad")), "the corrupt file is kept as .bad")


func test_run_record_replays_exactly() -> void:
	var d: String = _scratch("record")
	var opts: Dictionary = {"mode": "run", "known_codex": ["mohole"]}
	var s := Sim.new(db(), 21, "light_drill", opts)
	s.push({"type": "ignite", "room": "drill", "level": 0.35})
	run_seconds(s, 3.0)
	s.push({"type": "power", "room": "coolant", "bars": 3})
	s.push({"type": "assign", "crew": "lindqvist", "room": "drill"})
	run_seconds(s, 5.0)
	var path: String = RunRecord.save(d, s, {"result": "test"}, "20261015-000000")
	check(not path.is_empty(), "record saved")
	var rec: Dictionary = RunRecord.load_record(path)
	check_eq(int(rec.get("seed", 0)), 21, "seed stored")
	var again: Sim = RunRecord.replay(db(), rec)
	check_eq(again.state_hash(), s.state_hash(), "the record replays to the same state")
	check_eq(again.state_hash(), str(rec.get("hash", "")), "and matches the stored hash")
