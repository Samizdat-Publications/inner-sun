extends SceneTree
## Headless test runner. Finds res://tests/**/test_*.gd, runs every test_* method on a fresh
## instance, and fails a test if it records a failed check OR if the engine logs an error while it
## runs. Prints TEST START before each test so a hang names the test.
## Run: godot_console --headless --path game --script res://tests/runner.gd [-- --only=<text>]
## The error logger is installed before any test script is loaded, so parse errors are caught too.

var _logger: TestLogger


func _initialize() -> void:
	_logger = TestLogger.new()
	OS.add_logger(_logger)
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var passed: int = 0
	var failed: int = 0
	for path: String in _find("res://tests"):
		var mark_load: int = _logger.count()
		var loaded: Variant = load(path)
		var gd: GDScript = loaded as GDScript
		if gd == null or not gd.can_instantiate():
			failed += 1
			print("TEST FAIL %s: does not load: %s" % [path, "; ".join(_logger.since(mark_load))])
			continue
		var names := PackedStringArray()
		for m: Dictionary in gd.get_script_method_list():
			var n: String = str(m["name"])
			if n.begins_with("test_") and not names.has(n):
				names.append(n)
		for n: String in names:
			var id: String = "%s::%s" % [path.get_file().get_basename(), n]
			if not only.is_empty() and not id.contains(only):
				continue
			print("TEST START %s" % id)
			var inst: Object = gd.new()
			var mark: int = _logger.count()
			var t0: int = Time.get_ticks_usec()
			inst.call(n)
			var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			var why: PackedStringArray = inst.get("failures")
			for e: String in _logger.since(mark):
				why.append("engine error: " + e)
			if why.is_empty():
				passed += 1
				print("TEST PASS %s (%.1f ms)" % [id, ms])
			else:
				failed += 1
				print("TEST FAIL %s: %s" % [id, " | ".join(why)])
	print("TESTS passed=%d failed=%d" % [passed, failed])
	OS.remove_logger(_logger)
	quit(0 if failed == 0 and passed > 0 else 1)


func _find(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for f: String in files:
		if f.begins_with("test_") and f.get_extension() == "gd" and f != "test_case.gd" and f != "test_logger.gd":
			out.append(dir.path_join(f))
	var dirs: PackedStringArray = DirAccess.get_directories_at(dir)
	dirs.sort()
	for d: String in dirs:
		if d != "fixtures":
			out.append_array(_find(dir.path_join(d)))
	return out
