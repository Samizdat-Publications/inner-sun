extends SceneTree
## Headless full runs: plays whole runs (map, drilling, nodes, fights) with one bot and writes one
## JSON line per run: the run summary plus what the balance report needs, all read back from the
## sim's event list after the run (FullRunStats). tools/balance.py --full starts several of these.
## Run through tools/ only, for example:
##   godot_console --headless --path game --script res://tools/full_runs.gd -- --runs=10 --seed-base=1000
##     --bot=balanced [--out=<file.jsonl>] [--profile-dir=<dir>] [--cap-s=3600] [--trace]
## With --profile-dir the runs share a profile in that folder (codex learned carries over, as for a
## player); without it every run starts from a fresh profile, so a seed always plays the same.
## --trace prints every phase change (debugging a stuck bot).


func _initialize() -> void:
	var a: Args = Args.from_cmdline()
	var db: DataDB = DataDB.load_all()
	var problems: PackedStringArray = db.lint()
	if not problems.is_empty():
		for p: String in problems:
			printerr("data: " + p)
		quit(1)
		return
	var runs: int = a.get_int("runs", 10)
	var seed_base: int = a.get_int("seed-base", 1000)
	var bot_name: String = a.get_str("bot", "balanced")
	var out_path: String = a.get_str("out", "")
	var prof_dir: String = a.get_str("profile-dir", "")
	var cap_s: float = a.get_float("cap-s", FullRun.DEFAULT_CAP_S)
	var trace: bool = a.has("trace")
	var f: FileAccess = null
	if not out_path.is_empty():
		f = FileAccess.open(out_path, FileAccess.WRITE)
		if f == null:
			printerr("cannot write " + out_path)
			quit(1)
			return
	var prof: Profile = null
	if not prof_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(prof_dir)
		prof = Profile.load_from(prof_dir)
	var t0: int = Time.get_ticks_usec()
	var ticks: int = 0
	for i: int in range(runs):
		var opts: Dictionary = prof.run_options() if prof != null else {}
		var fr: FullRun = FullRun.start(db, seed_base + i, bot_name, opts, "light_drill", cap_s)
		fr.play_to_end()
		ticks += fr.sim.tick
		var sum: Dictionary = fr.summary()
		FullRunStats.add_to(fr.sim, sum)
		if trace:
			for e: Dictionary in fr.sim.events:
				if str(e["kind"]) == "phase" or str(e["kind"]) == "bad_command":
					print("TRACE %d %s" % [int(e["t"]), JSON.stringify(e)])
		if prof != null:
			prof.merge_run(sum, fr.sim.run.learned)
			prof.save()
		var line: String = JSON.stringify(sum)
		if f != null:
			f.store_line(line)
		else:
			print(line)
	if f != null:
		f.close()
	var secs: float = float(Time.get_ticks_usec() - t0) / 1_000_000.0
	print("FULLRUNS done runs=%d ticks=%d secs=%.2f ticks_per_sec=%.0f" % [runs, ticks, secs, float(ticks) / maxf(secs, 0.001)])
	quit(0)
