class_name PerfRecorder
extends Node
## Measures real frame times for --perf-seconds after a 3 s warm-up, plus GPU time, and writes them
## to --perf=<file> as JSON. Judge p99 frame time, not just the average.

const WARMUP_S: float = 3.0

var main: Node
var out_path: String = ""
var seconds: float = 10.0
var _elapsed: float = 0.0
var _last_us: int = 0
var _frames: PackedFloat64Array = PackedFloat64Array()
var _gpu: PackedFloat64Array = PackedFloat64Array()
var _done: bool = false


func setup(p_main: Node, args: Args) -> void:
	main = p_main
	out_path = args.get_str("perf", "user://perf.json")
	seconds = args.get_float("perf-seconds", 10.0)


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if _done:
		return
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	_elapsed += ms / 1000.0
	if _elapsed < WARMUP_S:
		return
	_frames.append(ms)
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	if _elapsed >= WARMUP_S + seconds:
		_done = true
		_write()
		main.call("finish")


func _write() -> void:
	var sorted_ms: PackedFloat64Array = _frames.duplicate()
	sorted_ms.sort()
	var n: int = sorted_ms.size()
	var total: float = 0.0
	for v: float in sorted_ms:
		total += v
	var gpu_total: float = 0.0
	for g: float in _gpu:
		gpu_total += g
	var mean: float = total / maxf(1.0, float(n))
	var res: Vector2i = DisplayServer.window_get_size()
	var data: Dictionary = {
		"avg_fps": snappedf(1000.0 / maxf(mean, 0.001), 0.1),
		"low_1pct_fps": snappedf(1000.0 / maxf(_pct(sorted_ms, 0.99), 0.001), 0.1),
		"p50_ms": snappedf(_pct(sorted_ms, 0.5), 0.01),
		"p95_ms": snappedf(_pct(sorted_ms, 0.95), 0.01),
		"p99_ms": snappedf(_pct(sorted_ms, 0.99), 0.01),
		"gpu_ms": snappedf(gpu_total / maxf(1.0, float(_gpu.size())), 0.01),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"resolution": "%dx%d" % [res.x, res.y],
		"frames": n,
		"vsync": DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
	}
	var text: String = JSON.stringify(data)
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	print("PERF " + text)


static func _pct(sorted_ms: PackedFloat64Array, q: float) -> float:
	if sorted_ms.is_empty():
		return 0.0
	return sorted_ms[clampi(roundi(q * float(sorted_ms.size() - 1)), 0, sorted_ms.size() - 1)]
