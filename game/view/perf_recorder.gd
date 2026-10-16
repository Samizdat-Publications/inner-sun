class_name PerfRecorder
extends Node
## Measures real frame times for --perf-seconds after a 3 s warm-up, plus GPU time, and writes them
## to --perf=<file> as JSON. Judge p99 frame time, not just the average.
## Also records where the CPU time of a frame went: view code calls PerfRecorder.span(id, usec) and
## the JSON gets per-span mean, p99, max and the mean over frames followed by a slow frame.

const WARMUP_S: float = 3.0
## Span ids for PerfRecorder.span() (microseconds, summed per frame).
const SPAN_SIM: int = 0
const SPAN_ROCK: int = 1
const SPAN_ROCK_UPLOAD: int = 2
const SPAN_SHIP: int = 3
const SPAN_COMBAT: int = 4
const SPAN_SCRIPTS: int = 5  ## main._process start to the end of this recorder's _process (all _process code).
const SPAN_DRAWS: int = 6  ## The deferred queue after _process: mostly the queued _draw callbacks.
const SPAN_OTHER: int = 7  ## The rest of the frame: render sync, physics steps, input.
const SPAN_NAMES: PackedStringArray = ["sim", "rock", "rock_upload", "ship", "combat", "scripts", "draws", "other"]
const SLOW_MS: float = 16.7

## Per-frame span accumulators; cheap enough to stay on in every build.
static var _acc: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0])
static var _frame_start_us: int = 0

var main: Node
var out_path: String = ""
var seconds: float = 10.0
var _elapsed: float = 0.0
var _last_us: int = 0
var _frames: PackedFloat64Array = PackedFloat64Array()
var _gpu: PackedFloat64Array = PackedFloat64Array()
var _done: bool = false
var _spans: Array[PackedFloat64Array] = []
var _proc: PackedFloat64Array = PackedFloat64Array()
var _phys: PackedFloat64Array = PackedFloat64Array()
var _proc_end_us: int = 0


static func span(id: int, usec: int) -> void:
	_acc[id] += usec



## Called by main at the start of its _process (the first _process of a frame).
static func frame_start() -> void:
	_frame_start_us = Time.get_ticks_usec()


func setup(p_main: Node, args: Args) -> void:
	main = p_main
	out_path = args.get_str("perf", "user://perf.json")
	seconds = args.get_float("perf-seconds", 10.0)


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last_us = Time.get_ticks_usec()
	for k: int in range(SPAN_NAMES.size()):
		_spans.append(PackedFloat64Array())


func _process(_delta: float) -> void:
	if _done:
		return
	_proc_end_us = Time.get_ticks_usec()
	# Runs after the redraws queued during _process (the deferred queue is first in, first out).
	_after_draws.call_deferred()


func _after_draws() -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	_elapsed += ms / 1000.0
	if _elapsed < WARMUP_S:
		_acc.fill(0)
		return
	_frames.append(ms)
	var scripts: int = _proc_end_us - _frame_start_us if _frame_start_us > 0 else 0
	_acc[SPAN_SCRIPTS] = scripts
	_acc[SPAN_DRAWS] = now - _proc_end_us
	_acc[SPAN_OTHER] = maxi(0, roundi(ms * 1000.0) - scripts - (now - _proc_end_us))
	for k: int in range(SPAN_NAMES.size()):
		_spans[k].append(float(_acc[k]) / 1000.0)
	_acc.fill(0)
	_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
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
		"slow_frames": _count_slow(),
		"spans": _span_stats(),
	}
	var text: String = JSON.stringify(data)
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	print("PERF " + text)


func _count_slow() -> int:
	var k: int = 0
	for v: float in _frames:
		if v > SLOW_MS:
			k += 1
	return k


## Per span (and the engine's per-second max process and physics times): mean, p99, max, and the
## mean over slow frames (a _process span lands in the same frame; _draw work lands in the next one).
func _span_stats() -> Dictionary:
	var out: Dictionary = {}
	var series: Array[PackedFloat64Array] = _spans.duplicate()
	var names: PackedStringArray = SPAN_NAMES.duplicate()
	series.append(_proc)
	names.append("engine_process_max_per_s")
	series.append(_phys)
	names.append("engine_physics_max_per_s")
	for k: int in range(series.size()):
		var a: PackedFloat64Array = series[k]
		var sorted_a: PackedFloat64Array = a.duplicate()
		sorted_a.sort()
		var tot: float = 0.0
		var slow_tot: float = 0.0
		var slow_n: int = 0
		for i: int in range(a.size()):
			tot += a[i]
			var nxt: int = mini(i, _frames.size() - 1)
			if _frames[nxt] > SLOW_MS:
				slow_tot += a[i]
				slow_n += 1
		out[names[k]] = {
			"mean": snappedf(tot / maxf(1.0, float(a.size())), 0.01),
			"p99": snappedf(_pct(sorted_a, 0.99), 0.01),
			"max": snappedf(sorted_a[sorted_a.size() - 1] if not sorted_a.is_empty() else 0.0, 0.01),
			"mean_slow": snappedf(slow_tot / maxf(1.0, float(slow_n)), 0.01),
		}
	return out


static func _pct(sorted_ms: PackedFloat64Array, q: float) -> float:
	if sorted_ms.is_empty():
		return 0.0
	return sorted_ms[clampi(roundi(q * float(sorted_ms.size() - 1)), 0, sorted_ms.size() - 1)]
