class_name MainSelftest
extends RefCounted
## The --selftest mode, moved out of Main to keep that file short: a data lint check, a fire drill, a full
## run and the real-input UI selftest, then SELFTEST ok or SELFTEST FAIL and quit.

static func run(m: Main, problems: PackedStringArray) -> void:
	var why: String = "" if problems.is_empty() else "data lint: " + problems[0]
	if why.is_empty():
		var r := ScenarioRun.from_scenario(m.db, "fire_drill", 1)
		for i: int in range(600):
			r.step()
		if r.sim.state_hash().length() != 16 or r.sim.events.is_empty():
			why = "the fire drill did not run"
	if why.is_empty():
		var fr: FullRun = FullRun.start(m.db, 1, "run", {})
		for i: int in range(600):
			fr.step()
		if fr.sim.run.phase == "scenario" or fr.sim.tick != 600:
			why = "a full run did not start"
	if why.is_empty():
		# Real input against the run screen (tests/ is not in the export: skipped there).
		var ui: GDScript = load("res://tests/ui_selftest.gd") as GDScript
		if ui != null:
			var ui_why: Variant = await ui.call("run", m)
			why = str(ui_why)
	print("SELFTEST ok" if why.is_empty() else "SELFTEST FAIL: " + why)
	m.get_tree().quit(0 if why.is_empty() else 1)
