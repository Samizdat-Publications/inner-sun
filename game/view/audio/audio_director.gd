class_name AudioDirector
extends Node
## Turns sim state into sound. It only READS the sim (loops follow state, one-shots follow new events),
## never writes it, and never feeds anything back. Under the headless display server it creates no
## players and no buses, so tests and balance runs stay silent and fast.
##
## MOUNT (main.gd, one call, after the sim exists; the director is a child Node):
##     add_child(AudioDirector.new()); (get_child(-1) as AudioDirector).bind(sim)
## or, if main swaps the Sim object between runs:
##     var audio: AudioDirector = AudioDirector.new(); add_child(audio)
##     audio.setup(func() -> Sim: return sim)    # re-read every frame; a new Sim resets the director
## Other views can fire UI or radio sounds by event key: audio.play("store_opened").
##
## Buses (created at runtime if missing): Master (limiter, never above 0 dB), SFX -3 dB, Ambience -3 dB,
## Radio -2 dB (high-pass 300 Hz, low-pass 3000 Hz, light distortion). Loops sit near -12 dB at the
## player at full intensity. The director keeps running while the tree is paused: loops duck to 30
## percent and one-shots are cut.

const MAX_ONESHOTS: int = 12
const MAX_NEW_PER_FRAME: int = 6  ## Event burst cap, so a pile of events is not a wall of sound.
const SILENT_DB: float = -60.0
const FADE_PER_S: float = 5.0  ## Loop amount slew, so changes never click.
const PAUSE_DUCK: float = 0.3
const ALARM_FULL_S: float = 3.0
const ALARM_DUCKED: float = 0.35  ## Under 40 percent after the first seconds.
const PURSUER_RANGE_ROWS: float = 1.5
const FIRE_FULL: float = 0.6  ## Fire level that counts as full volume.
const WATER_FULL_M: float = 1.5
const DEEP_WATER_M: float = 1.0  ## Water this deep sets off the alarm.
const SOFT_H: float = 1.2  ## Hardness at or below: all soft grind.
const HARD_H: float = 1.8  ## Between these two: all hard grind.
const SQUEAL_H: float = 2.8  ## At or above: all squeal.

var _getter: Callable = Callable()
var _sim: Sim = null
var _enabled: bool = false
var _loops: Dictionary = {}  ## name -> AudioStreamPlayer
var _amount: Dictionary = {}  ## name -> current linear 0..1
var _pitch: Dictionary = {}  ## name -> pitch scale (default 1)
var _shots: Array[AudioStreamPlayer] = []
var _next_shot: int = 0
var _streams: Dictionary = {}  ## stem -> AudioStream
var _seen: int = 0
var _was_active: bool = false
var _have_state: bool = false
var _alarm_s: float = 0.0
var _duck: float = 1.0
var _rng_jitter: int = 1


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Number of audio players this director made (0 under the headless display server).
func player_count() -> int:
	return _loops.size() + _shots.size()


func bind(sim: Sim) -> void:
	setup(func() -> Sim: return sim)


func setup(sim_getter: Callable) -> void:
	_getter = sim_getter
	if is_headless() or _enabled:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	_enabled = true
	for name: String in SoundTable.LOOPS.keys():
		if name == "static":
			continue
		var d: Dictionary = SoundTable.LOOPS[name]
		var p := AudioStreamPlayer.new()
		p.bus = str(d["bus"])
		p.stream = _stream(str(d["sound"]), true)
		p.volume_db = SILENT_DB
		add_child(p)
		_loops[name] = p
		_amount[name] = 0.0
		_pitch[name] = 1.0
	for i: int in range(MAX_ONESHOTS):
		var s := AudioStreamPlayer.new()
		add_child(s)
		_shots.append(s)


## Creates Master limiter and the SFX, Ambience and Radio buses if they are missing.
static func ensure_buses() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, minf(AudioServer.get_bus_volume_db(master), 0.0))
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)
	for bus: String in SoundTable.BUSES:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, float(SoundTable.BUS_DB[bus]))
		if bus == "Radio":
			var hp := AudioEffectHighPassFilter.new()
			hp.cutoff_hz = 300.0
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 3000.0
			var dist := AudioEffectDistortion.new()
			dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
			dist.drive = 0.2
			dist.post_gain = -4.0
			AudioServer.add_bus_effect(idx, hp)
			AudioServer.add_bus_effect(idx, lp)
			AudioServer.add_bus_effect(idx, dist)


## Play a one-shot by event key (see SoundTable.EVENTS). Silent when headless, paused or unknown.
func play(key: String) -> void:
	if not _enabled or get_tree().paused or not SoundTable.EVENTS.has(key):
		return
	_shot(SoundTable.EVENTS[key])


func _process(delta: float) -> void:
	if not _enabled or not _getter.is_valid():
		return
	var sim: Sim = _getter.call() as Sim
	if sim == null:
		return
	if sim != _sim:
		_sim = sim
		_seen = sim.events.size()
		_have_state = false
		_alarm_s = 0.0
	var paused: bool = get_tree().paused
	_duck = move_toward(_duck, PAUSE_DUCK if paused else 1.0, delta * 8.0)
	if paused:
		for p: AudioStreamPlayer in _shots:
			p.stop()
		_seen = sim.events.size()
	else:
		_follow_events(sim)
	_update_targets(sim, delta)
	_apply(delta)


func _follow_events(sim: Sim) -> void:
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	var played: int = 0
	for i: int in range(_seen, n):
		var key: String = SoundTable.key_for(sim.events[i])
		if SoundTable.EVENTS.has(key) and played < MAX_NEW_PER_FRAME:
			_shot(SoundTable.EVENTS[key])
			played += 1
	_seen = n


func _shot(d: Dictionary) -> void:
	var stream: AudioStream = _stream(str(d["sound"]), false)
	if stream == null:
		return
	var p: AudioStreamPlayer = _shots[_next_shot]
	_next_shot = (_next_shot + 1) % _shots.size()
	p.stream = stream
	p.bus = str(d.get("bus", "SFX"))
	p.volume_db = minf(float(d.get("db", 0.0)), 6.0)
	# Pitch jitter is cosmetic and must not touch the sim streams: a tiny view-side cycle of offsets.
	_rng_jitter = (_rng_jitter * 75 + 74) % 65537
	var unit: float = float(_rng_jitter) / 65537.0 * 2.0 - 1.0
	p.pitch_scale = 1.0 + float(d.get("jitter", 0.0)) * unit
	p.play()


func _update_targets(sim: Sim, delta: float) -> void:
	var drill: DrillSim = sim.drill
	var active: bool = drill != null and drill.active
	var want: Dictionary = {}
	for k: String in _amount.keys():
		want[k] = 0.0
	if active:
		var bars: int = sim.systems.drill_bars(sim.player) if sim.systems != null else 0
		var sp: float = drill.speed_m_s
		want["motor"] = clampf(0.55 + 0.1 * float(bars), 0.0, 1.0)
		_pitch["motor"] = clampf(0.85 + 0.07 * float(bars) + 0.05 * sp, 0.8, 1.4)
		if drill.cutting:
			var w: Vector3 = grind_weights(_crown_hardness(drill))
			want["grind_soft"] = w.x
			want["grind_hard"] = w.y
			want["grind_squeal"] = w.z
			_pitch["grind_hard"] = clampf(0.9 + 0.06 * sp, 0.8, 1.3)
	if _have_state and active != _was_active:
		_shot(SoundTable.SPIN_UP if active else SoundTable.SPIN_DOWN)
	_was_active = active
	_have_state = true
	# Hazards follow the worst room.
	var fire: float = 0.0
	var water: float = 0.0
	var alarm: bool = false
	for r: Room in sim.player.ship.rooms:
		fire = maxf(fire, r.fire)
		var lvl: float = r.level_m()
		water = maxf(water, maxf(lvl / WATER_FULL_M, 0.5 if r.breach_m2 > 0.0 else 0.0))
		if r.fire > 0.05 or r.breach_m2 > 0.0 or lvl >= DEEP_WATER_M:
			alarm = true
	want["fire"] = clampf(fire / FIRE_FULL, 0.0, 1.0)
	want["water"] = clampf(water, 0.0, 1.0)
	if alarm:
		_alarm_s += delta
		want["alarm"] = 1.0 if _alarm_s < ALARM_FULL_S else ALARM_DUCKED
	else:
		_alarm_s = 0.0
	want["pursuer"] = pursuer_intensity(sim)
	for k: String in want.keys():
		if _amount.has(k):
			_amount[k] = move_toward(float(_amount[k]), float(want[k]), delta * FADE_PER_S)


func _apply(_delta: float) -> void:
	for k: String in _loops.keys():
		var p: AudioStreamPlayer = _loops[k]
		var a: float = float(_amount[k]) * _duck
		if a < 0.002:
			if p.playing:
				p.stop()
			continue
		var base: float = float((SoundTable.LOOPS[k] as Dictionary)["db"])
		p.volume_db = minf(base + linear_to_db(a), 6.0)
		p.pitch_scale = float(_pitch.get(k, 1.0))
		if not p.playing:
			p.play()


## Grind layer weights (soft, hard, squeal) for a hardness, crossfading and summing to 1 (or all 0 for
## air). Pure, so it is tested.
static func grind_weights(h: float) -> Vector3:
	if h <= 0.0:
		return Vector3.ZERO
	var soft: float = clampf((HARD_H - h) / (HARD_H - SOFT_H), 0.0, 1.0)
	var squeal: float = clampf((h - HARD_H) / (SQUEAL_H - HARD_H), 0.0, 1.0)
	if h <= HARD_H:
		squeal = 0.0
	var hard: float = clampf(1.0 - soft - squeal, 0.0, 1.0)
	return Vector3(soft, hard, squeal)


## 0 beyond 1.5 rows from the ship, rising to 1 when the front reaches it; 1 when caught. Run mode only.
static func pursuer_intensity(sim: Sim) -> float:
	var run: RunState = sim.run
	if run == null or run.mode != "run":
		return 0.0
	if run.caught:
		return 1.0
	return clampf(1.0 - ((run.ship_row_f(sim) - run.pursuer_row)) / PURSUER_RANGE_ROWS, 0.0, 1.0)


## Mean hardness of the rock cells just under the crown (the bottom edge of the ship).
func _crown_hardness(drill: DrillSim) -> float:
	if drill.cols <= 0 or drill.rows <= 0 or drill.grid.is_empty():
		return 0.0
	var y: int = int((drill.ship_pos.y + drill.ship_size.y) / drill.cell_m)
	var x0: int = int(drill.ship_pos.x / drill.cell_m)
	var x1: int = int((drill.ship_pos.x + drill.ship_size.x) / drill.cell_m)
	y = clampi(y, 0, drill.rows - 1)
	var sum: float = 0.0
	var n: int = 0
	for x: int in range(clampi(x0, 0, drill.cols - 1), clampi(x1, 0, drill.cols - 1) + 1):
		var code: int = drill.grid[y * drill.cols + x]
		if code < drill.hardness_of.size():
			sum += drill.hardness_of[code]
			n += 1
	return sum / float(n) if n > 0 else 0.0


func _stream(stem: String, loop: bool) -> AudioStream:
	var key: String = stem + (":loop" if loop else "")
	if _streams.has(key):
		return _streams[key] as AudioStream
	var path: String = SoundTable.path_of(stem)
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path) as AudioStream
	if loop and s is AudioStreamOggVorbis:
		s = s.duplicate() as AudioStream
		(s as AudioStreamOggVorbis).loop = true
	_streams[key] = s
	return s
