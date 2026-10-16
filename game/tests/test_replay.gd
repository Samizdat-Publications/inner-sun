extends TestCase
## ReplayDriver plays a saved run record back exactly (the --replay mode and tools/replay.py).


func _scratch() -> String:
	var d: String = ProjectSettings.globalize_path("res://").path_join("../harness/out/test_replay").simplify_path()
	DirAccess.make_dir_recursive_absolute(d.path_join("runs"))
	for f: String in DirAccess.get_files_at(d.path_join("runs")):
		DirAccess.remove_absolute(d.path_join("runs").path_join(f))
	return d


func test_replay_driver_matches_a_saved_run() -> void:
	var fr: FullRun = FullRun.start(db(), 41, "run", {"known_codex": ["kola_well"]})
	for i: int in range(60 * 90):
		fr.step()
		if fr.done():
			break
	var path: String = RunRecord.save(_scratch(), fr.sim, fr.summary(), "20261015-000001")
	check(not path.is_empty(), "record saved")
	var rd: ReplayDriver = ReplayDriver.from_record(db(), RunRecord.load_record(path))
	var guard: int = rd.duration_ticks + 10
	while not rd.done() and guard > 0:
		rd.step()
		guard -= 1
	check_eq(rd.outcome, "replayed", "the replay ran to the recorded tick")
	check_eq(rd.cause, "match", "and ended in the recorded state hash")
	check_eq(rd.sim.tick, fr.sim.tick, "at the same tick")
