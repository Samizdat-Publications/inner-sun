extends SceneTree
## Headless replay of a saved run record: rebuilds the run from its seed, options and command log and
## prints whether the final state hash matches the one stored. Run through tools/replay.py.
##   godot_console --headless --path game --script res://tools/replay_run.gd -- --record=<path.json>


func _initialize() -> void:
	var a: Args = Args.from_cmdline()
	var path: String = a.get_str("record", "")
	var rec: Dictionary = RunRecord.load_record(path)
	if rec.is_empty():
		printerr("replay: cannot read %s" % path)
		quit(1)
		return
	var db: DataDB = DataDB.load_all()
	var rd: ReplayDriver = ReplayDriver.from_record(db, rec)
	var guard: int = rd.duration_ticks + 10
	while not rd.done() and guard > 0:
		rd.step()
		guard -= 1
	var summary: Dictionary = rec.get("summary", {})
	print("REPLAY ticks=%d stored=%s replayed=%s %s result=%s cause=%s" % [rd.sim.tick, rd.expect_hash, rd.sim.state_hash(),
			rd.cause, str(summary.get("result", "")), str(summary.get("cause", ""))])
	quit(0 if rd.cause == "match" else 2)
