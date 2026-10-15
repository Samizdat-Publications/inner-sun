class_name CaptureDirector
extends Node
## Saves frames from the game camera while a bot plays.
##   --shots=<a,b> --out=<dir>: named shots at story moments (start, fire, flood, arrive, fire_out, end)
##   --capture=<dir> --stills=<n> --sheets=<m>: evenly spaced stills, plus m bursts of 9 frames
##     0.4 s apart for 3x3 motion sheets, for the blind review inbox.
## Moments come from the sim's own events, so the frames follow the story, not wall-clock time.
## Prints SHOT / CAPTURE lines for the tools, then asks Main to finish (prints FINAL and quits).

const MOMENT_DELAY_S: Dictionary = {"fire": 4.0, "flood": 8.0, "arrive": 0.6, "fire_out": 0.6}
const BURST_FRAMES: int = 9
const BURST_GAP_TICKS: int = 24

var main: Node
var shots: PackedStringArray = PackedStringArray()
var out_dir: String = ""
var capture_dir: String = ""
var stills: int = 12
var sheets: int = 3
var _due: Dictionary = {}  # name -> tick when the shot is due
var _taken: Dictionary = {}
var _still_ticks: PackedInt32Array = PackedInt32Array()
var _burst_starts: PackedInt32Array = PackedInt32Array()
var _queue: Array[String] = []
var _busy: bool = false
var _seen: int = 0
var _all_queued: bool = false


func setup(p_main: Node, args: Args) -> void:
	main = p_main
	shots = args.get_list("shots")
	out_dir = args.get_str("out", "user://shots")
	capture_dir = args.get_str("capture", "")
	stills = args.get_int("stills", 12)
	sheets = args.get_int("sheets", 3)
	process_priority = 100


func _ready() -> void:
	var run: ScenarioRun = main.get("run")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("stills"))
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("sheets"))
		for i: int in range(stills):
			_still_ticks.append(roundi((float(i) + 0.5) / float(stills) * float(run.duration_ticks)))
		var spacing: float = float(run.duration_ticks) / float(sheets + 1)
		for k: int in range(sheets):
			_burst_starts.append(roundi(spacing * float(k + 1)))
	else:
		DirAccess.make_dir_recursive_absolute(out_dir)
	if shots.has("start"):
		_due["start"] = 30


func _physics_process(_delta: float) -> void:
	var run: ScenarioRun = main.get("run")
	var sim: Sim = run.sim
	_watch_events(sim)
	var t: int = sim.tick
	for shot_name: String in _due.keys():
		if not _taken.has(shot_name) and t >= int(_due[shot_name]):
			_taken[shot_name] = true
			_queue.append("shot:" + shot_name)
	if not capture_dir.is_empty():
		for i: int in range(_still_ticks.size()):
			if _still_ticks[i] == t:
				_queue.append("still:%02d" % (i + 1))
		for k: int in range(_burst_starts.size()):
			var rel: int = t - _burst_starts[k]
			if rel >= 0 and rel % BURST_GAP_TICKS == 0 and rel / BURST_GAP_TICKS < BURST_FRAMES:
				_queue.append("burst:%02d:%02d" % [k + 1, rel / BURST_GAP_TICKS + 1])
	if run.done() or t >= run.duration_ticks - 1:
		if shots.has("end") and not _taken.has("end"):
			_taken["end"] = true
			_queue.append("shot:end")
		_all_queued = true


func _watch_events(sim: Sim) -> void:
	while _seen < sim.events.size():
		var e: Dictionary = sim.events[_seen]
		_seen += 1
		var kind: String = str(e["kind"])
		var moment: String = ""
		if kind == "fire_started":
			moment = "fire"
		elif kind == "breach":
			moment = "flood"
		elif kind == "arrive" and str(e.get("job", "")) != "go":
			moment = "arrive"
		elif kind == "fire_out":
			moment = "fire_out"
		if not moment.is_empty() and shots.has(moment) and not _due.has(moment):
			_due[moment] = int(e["t"]) + roundi(float(MOMENT_DELAY_S[moment]) * Sim.TICK_HZ)


func _process(_delta: float) -> void:
	if _busy:
		return
	if not _queue.is_empty():
		_capture(_queue.pop_front())
	elif _all_queued:
		_finish()


func _capture(what: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var parts: PackedStringArray = what.split(":")
	var path: String = ""
	if parts[0] == "shot":
		path = out_dir.path_join(parts[1] + ".png")
	elif parts[0] == "still":
		path = capture_dir.path_join("stills/s_%s.png" % parts[1])
	else:
		path = capture_dir.path_join("sheets/k%s_f%s.png" % [parts[1], parts[2]])
	var err: Error = img.save_png(path)
	if parts[0] == "shot":
		print("SHOT %s %s" % [parts[1], ProjectSettings.globalize_path(path) if err == OK else "FAILED"])
	_busy = false


func _finish() -> void:
	set_process(false)
	var adapter: String = RenderingServer.get_video_adapter_name()
	if not shots.is_empty():
		for shot_name: String in shots:
			if not _taken.has(shot_name):
				print("SHOT %s MISSING (the moment never happened)" % shot_name)
		print("SHOTS done renderer %s" % adapter)
	if not capture_dir.is_empty():
		print("CAPTURE done stills=%d sheets=%d renderer %s" % [_still_ticks.size(), _burst_starts.size(), adapter])
	main.call("finish")
