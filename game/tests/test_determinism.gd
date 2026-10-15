extends TestCase
## Same seed and commands give the same world; a replay rebuilds a run exactly; nothing leaks; and
## simulation code never touches the engine's global random generator.

const BANNED_RANDOM: String = "(?<![\\w.])(randi|randf|randf_range|randi_range|randfn|randomize|seed)\\s*\\(|\\.(shuffle|pick_random)\\s*\\("


func _play(run_seed: int, bot_name: String, seconds: float) -> ScenarioRun:
	var r := ScenarioRun.generated(db(), run_seed, bot_name, seconds)
	while not r.done():
		r.step()
	return r


func test_same_seed_gives_same_state() -> void:
	var a: ScenarioRun = _play(42, "auto", 60.0)
	var b: ScenarioRun = _play(42, "auto", 60.0)
	check_eq(a.sim.state_hash(), b.sim.state_hash(), "two runs with seed 42 end in the same state")


func test_different_seed_gives_different_state() -> void:
	var a: ScenarioRun = _play(42, "auto", 30.0)
	var b: ScenarioRun = _play(43, "auto", 30.0)
	check(a.sim.state_hash() != b.sim.state_hash(), "seeds 42 and 43 differ")


func test_replay_rebuilds_the_run() -> void:
	var r := ScenarioRun.from_scenario(db(), "fire_drill", 7)
	while not r.done():
		r.step()
	check_gt(float(r.sim.command_log.size()), 3.0, "the run recorded its commands")
	var again: Sim = Sim.replay(db(), 7, r.sim.ship_id, r.sim.command_log, r.sim.tick)
	check_eq(again.state_hash(), r.sim.state_hash(), "replaying seed plus command log gives the same final state")


func test_no_leaks_over_many_runs() -> void:
	var d: DataDB = db()
	var warm := ScenarioRun.generated(d, 1, "auto", 2.0)
	while not warm.done():
		warm.step()
	warm = null
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i: int in range(200):
		var r := ScenarioRun.generated(d, i, "random", 3.0)
		while not r.done():
			r.step()
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	check_lt(float(after - before), 50.0, "objects return to the baseline after 200 runs (before %d, after %d)" % [before, after])


func test_sim_code_never_uses_global_randomness() -> void:
	var re := RegEx.new()
	re.compile(BANNED_RANDOM)
	for dir: String in ["res://sim", "res://bots"]:
		for path: String in _scripts(dir):
			var src: String = FileAccess.get_file_as_string(path)
			var lines: PackedStringArray = src.split("\n")
			for i: int in range(lines.size()):
				var line: String = lines[i].strip_edges()
				if line.begins_with("#") or line.begins_with("##"):
					continue
				if re.search(line) != null:
					failures.append("%s:%d uses the global random generator: %s" % [path, i + 1, line])


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
