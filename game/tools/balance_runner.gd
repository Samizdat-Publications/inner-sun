extends SceneTree
## Headless balance runs (no window, no scene): plays generated situations with one bot and writes
## one JSON line per run. tools/balance.py starts several of these in parallel and merges them.
## With --bench it runs the M1-shaped speed benchmark instead.
## Run: godot_console --headless --path game --script res://tools/balance_runner.gd --
##        --runs=100 --seed-base=1000 --bot=auto [--seconds=120] --out=<file.jsonl>
##      or: ... -- --bench [--ticks=20000] --out=<file.json>


func _initialize() -> void:
	var a: Args = Args.from_cmdline()
	var db: DataDB = DataDB.load_all()
	var problems: PackedStringArray = db.lint()
	if not problems.is_empty():
		for p: String in problems:
			printerr("data: " + p)
		quit(1)
		return
	if a.has("bench"):
		_bench(db, a)
		return
	var runs: int = a.get_int("runs", 100)
	var seed_base: int = a.get_int("seed-base", 1000)
	var bot_name: String = a.get_str("bot", "auto")
	var seconds: float = a.get_float("seconds", 120.0)
	var out_path: String = a.get_str("out", "")
	var f: FileAccess = null
	if not out_path.is_empty():
		f = FileAccess.open(out_path, FileAccess.WRITE)
		if f == null:
			printerr("cannot write " + out_path)
			quit(1)
			return
	var t0: int = Time.get_ticks_usec()
	var ticks: int = 0
	for i: int in range(runs):
		var r := ScenarioRun.generated(db, seed_base + i, bot_name, seconds)
		r.play_to_end()
		ticks += r.sim.tick
		var line: String = JSON.stringify(r.summary())
		if f != null:
			f.store_line(line)
		else:
			print(line)
	if f != null:
		f.close()
	var secs: float = float(Time.get_ticks_usec() - t0) / 1_000_000.0
	print("BALANCE done runs=%d ticks=%d secs=%.2f ticks_per_sec=%.0f" % [runs, ticks, secs, float(ticks) / maxf(secs, 0.001)])
	quit(0)


func _bench(db: DataDB, a: Args) -> void:
	var res: Dictionary = BenchM1.run(db, a.get_int("ticks", 20000))
	var line: String = JSON.stringify(res)
	print("BENCH " + line)
	var out_path: String = a.get_str("out", "")
	if not out_path.is_empty():
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(line + "\n")
			f.close()
	quit(0)
