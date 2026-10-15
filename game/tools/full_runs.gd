extends SceneTree
## Headless full runs: plays whole runs (map, drilling, nodes) with one bot and writes one JSON line
## per run: the run summary plus segment times. The base for full-run balance (M1 step 7).
## Run through tools/ only, for example:
##   python -c "import sys; sys.path.insert(0,'tools'); import proc; ..."  (see tools/balance.py)
##   godot_console --headless --path game --script res://tools/full_runs.gd -- --runs=10 --seed-base=1000
##     --bot=run [--out=<file.jsonl>] [--profile-dir=<dir>]


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
	var bot_name: String = a.get_str("bot", "run")
	var out_path: String = a.get_str("out", "")
	var f: FileAccess = null
	if not out_path.is_empty():
		f = FileAccess.open(out_path, FileAccess.WRITE)
	for i: int in range(runs):
		var fr: FullRun = FullRun.start(db, seed_base + i, bot_name, {})
		fr.play_to_end()
		var sum: Dictionary = fr.summary()
		var seg: Array = []
		for e: Dictionary in fr.sim.events:
			if str(e["kind"]) == "segment_done":
				seg.append(snappedf(float(e.get("time_s", e.get("seconds", 0.0))), 0.1))
		sum["segments_s"] = seg
		var line: String = JSON.stringify(sum)
		print(line)
		if f != null:
			f.store_line(line)
	if f != null:
		f.close()
	quit(0)
