class_name CaptureDirector
extends Node
## Saves frames from the game camera while a bot plays.
##   --shots=<a,b> --out=<dir>: named shots at story moments (start, fire, flood, arrive, fire_out, end;
##     drilling: drill_start, ore, burst, segment_done; whole runs: event, store, map, fight, death)
##     dig verbs: rockwarn, rockfall, blast_fired, blast, douse; buried structures: structure (the
##     break-in banner), crate (a crate opening; store holds the mid-segment trader); and tN (N whole seconds) for a still at a
##     fixed time, e.g. t12, for a scenario timeline that shows a state rather than an event; hN is the
##     same but opens the help page first
##   --capture=<dir> --stills=<n> --sheets=<m>: evenly spaced stills, plus m bursts of 9 frames
##     0.4 s apart for 3x3 motion sheets, for the blind review inbox.
## Moments come from the sim's own events, so the frames follow the story, not wall-clock time.
## Screens a bot would close at once (an event page, the store, the map, the death report) are held:
## the director pauses the sim for HOLD_FRAMES so the frame and the video show them (pausing never
## changes the result). In capture mode the first of each such moment also gets an extra still.
## Prints SHOT / CAPTURE lines for the tools, then asks Main to finish (prints FINAL and quits).

const MOMENT_DELAY_S: Dictionary = {"fire": 4.0, "flood": 8.0, "arrive": 0.6, "fire_out": 0.6,
	"drill_start": 2.5, "ore": 0.35, "burst": 0.35, "segment_done": 0.4,
	"event": 0.0, "store": 0.0, "map": 0.0, "fight": 5.0, "death": 0.5,
	"volley": 0.7, "impact": 0.12, "block": 0.15, "miss": 0.2,
	"rockwarn": 0.5, "rockfall": 0.2, "blast_fired": 0.3, "blast": 0.1, "douse": 0.35,
	"structure": 0.45, "crate": 0.3}
const HOLD_MOMENTS: Array[String] = ["event", "store", "map", "death"]
const HOLD_FRAMES: int = 150  ## About 2.5 s at 60 fps.
const HOLD_SHOT_AT: int = 45  ## Frames into a hold when its shot is taken (overlays fade in first).
const MOMENT_STILLS_MAX: int = 2  ## Extra stills per moment kind in capture mode.
const PAINT_WAIT_FRAMES: int = 240  ## Frames a capture waits for the rock chunks to finish painting.
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
var _paint_waited: int = 0
var _hold: int = 0
var _hold_age: int = 0
var _hold_shots: Array[String] = []  # captures taken HOLD_SHOT_AT frames into the current hold
var _moment_stills: Dictionary = {}  # moment -> extra stills taken


func setup(p_main: Node, args: Args) -> void:
	main = p_main
	shots = args.get_list("shots")
	out_dir = args.get_str("out", "user://shots")
	capture_dir = args.get_str("capture", "")
	stills = args.get_int("stills", 12)
	sheets = args.get_int("sheets", 3)
	process_priority = 100


func _ready() -> void:
	var run: Driver = main.get("run")
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
	for shot_name: String in shots:
		if shot_name.length() > 1 and (shot_name.begins_with("t") or shot_name.begins_with("h")) and shot_name.substr(1).is_valid_int():
			_due[shot_name] = int(shot_name.substr(1)) * Sim.TICK_HZ


func _physics_process(_delta: float) -> void:
	var run: Driver = main.get("run")
	var sim: Sim = run.sim
	_watch_events(sim)
	var t: int = sim.tick
	for shot_name: String in _due.keys():
		if not _taken.has(shot_name) and t >= int(_due[shot_name]):
			_taken[shot_name] = true
			if shot_name.begins_with("h") and shot_name.length() > 1 and shot_name.substr(1).is_valid_int():
				var scr: RunScreen = main.get("screen")
				scr.help.open()  # hN: the help page opens at N seconds and stays (put it last)
			if shot_name.begins_with("shot:"):
				_taken[shot_name.substr(5)] = true
			_queue.append(shot_name if shot_name.contains(":") else "shot:" + shot_name)
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
		elif kind == "segment_begin":
			moment = "drill_start"
		elif kind == "resource" and str(e.get("res", "")) == "ore" and int(e.get("amount", 0)) > 0 and sim.drill.active:
			moment = "ore"
		elif kind == "pocket_burst":
			moment = "burst"
		elif kind == "segment_done":
			moment = "segment_done"
		elif kind == "phase":
			var to: String = str(e.get("to", ""))
			if to == "dialog":
				moment = "event"
			elif to == "store":
				moment = "store"
			elif to == "idle" and sim.run.mode == "run":
				moment = "map"
		elif kind == "fight_start":
			moment = "fight"
		elif kind == "weapon_fired" and not e.has("side"):
			moment = "volley"
		elif kind == "room_hit":
			moment = "impact"
		elif kind == "bracing_absorbed" or kind == "beam_blocked":
			moment = "block"
		elif kind == "shot_missed":
			moment = "miss"
		elif kind == "run_over":
			moment = "death"
		elif kind == "rockfall_warn":
			moment = "rockwarn"
		elif kind == "rockfall":
			moment = "rockfall"
		elif kind == "blast_fired":
			moment = "blast_fired"
		elif kind == "blast":
			moment = "blast"
		elif kind == "doused":
			moment = "douse"
		elif kind == "structure_entered":
			moment = "structure"
		elif kind == "loot":
			moment = "crate"
		if moment.is_empty():
			continue
		var hold: bool = HOLD_MOMENTS.has(moment)
		var names: Array[String] = []
		if shots.has(moment) and not _due.has("shot:" + moment) and not _taken.has(moment):
			names.append("shot:" + moment)
			_taken[moment] = true
		if not capture_dir.is_empty() and (hold or moment == "fight"):
			var n: int = int(_moment_stills.get(moment, 0))
			if n < MOMENT_STILLS_MAX:
				_moment_stills[moment] = n + 1
				names.append("still:m_%s_%d" % [moment, n])
		if names.is_empty():
			continue
		if hold:
			# Held screens: pause the sim and capture once the overlay has faded in (frame based, so it
			# also works after the run has ended and the sim no longer steps).
			_hold = HOLD_FRAMES
			_hold_age = 0
			_hold_shots.append_array(names)
			main.set("paused", true)
		else:
			var at: int = int(e["t"]) + roundi(float(MOMENT_DELAY_S[moment]) * Sim.TICK_HZ)
			for nm: String in names:
				_due[nm] = at


func _process(_delta: float) -> void:
	if _hold > 0:
		_hold -= 1
		_hold_age += 1
		if _hold_age == HOLD_SHOT_AT:
			_queue.append_array(_hold_shots)
			_hold_shots.clear()
		if _hold == 0:
			main.set("paused", false)
	if _busy:
		return
	var rv: RockView = main.get("rock_view")
	if rv != null and rv.pending() > 0 and _paint_waited < PAINT_WAIT_FRAMES:
		_paint_waited += 1
		return
	_paint_waited = 0
	if not _queue.is_empty():
		_capture(_queue.pop_front())
	elif _all_queued and _hold <= 0 and _hold_shots.is_empty():
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
