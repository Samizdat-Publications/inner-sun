class_name DrillSim
extends SimModule
## The drilling segment between map nodes. The sim owns a rock grid (square cells, one material code
## each, generated from a rock table and the stream "drill/<segment id>"). The whole ship footprint
## moves through it; its bottom edge is the cutting crown. Each tick: turn toward the steered
## heading, read the leading band (cells about to be entered), move, cut every newly overlapped cell.
## Cut cells are counted exactly (mined per material); ore and gems go to run resources, water
## pockets pour into the drill room, cutting heats the drill room, wears the bit and makes noise.
## Arrival is depth only: the ship's bottom edge reaching target_y. Steering is for detours.
## Segment space: meters, +x right, +y down, like ship space. See docs/ARCHITECTURE.md.

const COMMANDS: Array[String] = ["steer", "change_bit", "begin_segment"]
const CHUNK_CELLS: int = 16  ## The view redraws the rock in chunks of 16 x 16 cells.
const DEFAULT_ROCK: String = "crust"
const MAX_CODES: int = 256
const MAX_POWER_BAR: int = 4  ## Highest bar with its own power factor; more bars use this one.
const EPS: float = 0.000001
const TUNING_KEYS: Array[String] = [
	"drill.cell_m", "drill.width_m", "drill.top_air_m", "drill.shaft_margin_m", "drill.bottom_margin_m",
	"drill.max_lateral_m", "drill.band_cells", "drill.base_speed_m_s", "drill.max_speed_m_s",
	"drill.air_hardness_floor", "drill.turn_deg_s", "drill.max_heading_deg",
	"drill.power_factor_bar_0", "drill.power_factor_bar_1", "drill.power_factor_bar_2",
	"drill.power_factor_bar_3", "drill.power_factor_bar_4",
	"drill.heat_kw_per_bar", "drill.wear_per_m_hardness", "drill.bit_slow_at_full_wear",
	"drill.broken_bit_factor", "drill.bit_change_s", "drill.noise_per_m", "drill.pocket_breach_m2",
	"drill.rock_temp_base_c", "drill.rock_temp_c_per_m",
]

# Read by the view (never written outside this class).
var active: bool = false
var segment_id: String = ""
var rock_id: String = ""
var grid: PackedByteArray = PackedByteArray()  ## Material code per cell, row-major (cols x rows).
var grid_serial: int = 0  ## Bumped by every begin_segment: the view rebuilds everything.
var cols: int = 0
var rows: int = 0
var cell_m: float = 0.5
var ship_size: Vector2 = Vector2.ZERO
var ship_pos: Vector2 = Vector2.ZERO  ## Top-left of the ship footprint, segment meters.
var heading_deg: float = 0.0  ## 0 = straight down, positive = toward +x.
var target_heading_deg: float = 0.0
var speed_m_s: float = 0.0
var speed_scale: float = 1.0  ## Set by the run per segment (reserve power: below 1). Multiplies the speed.
var bit_wear: float = 0.0  ## 0 (new) to 1 (broken).
var bit_broken: bool = false
var bit_change_left_s: float = 0.0
var cutting: bool = false
var start_center_x: float = 0.0
var start_y: float = 0.0  ## Ship top at the start.
var target_x: float = 0.0  ## Where the next node sits (centre x at target_y): a hint, not a condition.
var target_y: float = 0.0  ## Arrival when the ship's bottom edge reaches this.
var depth_m: float = 0.0
var start_depth_m: float = 0.0
var distance_m: float = 0.0
var segment_ticks: int = 0
var noise_segment: float = 0.0
var noise_total: float = 0.0  ## Whole run; the pursuer reads it.
var mined: PackedInt32Array = PackedInt32Array()  ## Cells cut this segment, by material code.
var generated: PackedInt32Array = PackedInt32Array()  ## Cells at generation, by material code.
var yielded: PackedInt32Array = PackedInt32Array()  ## Given to run resources this segment, by RunState.RESOURCES index.
var water_in_ml: int = 0  ## Pocket water that went into the drill room this segment.
var lost_water_ml: int = 0  ## Pocket water that did not fit (lost to the rock).
var water_cell_ml: int = 0
var heat_added_j: int = 0
var pockets_burst: int = 0
var chunk_cols: int = 0
var chunk_rows: int = 0
var chunk_changes: PackedInt32Array = PackedInt32Array()  ## +1 whenever a cell in that chunk changes.
var materials: Array[Dictionary] = []  ## By code: {"id", "name", "hardness", "color"} or {} if unused.
var hardness_of: PackedFloat64Array = PackedFloat64Array()  ## By code.
var yield_res_of: PackedInt32Array = PackedInt32Array()  ## By code: RunState.RESOURCES index or -1.
var yield_amount_of: PackedInt32Array = PackedInt32Array()
var water_of: PackedByteArray = PackedByteArray()  ## By code: 1 for water pockets.

var _db: DataDB
var _px: float = 0.0
var _py: float = 0.0
var _burst: PackedByteArray = PackedByteArray()
var _c0: int = 0
var _c1: int = -1
var _r0: int = 0
var _r1: int = -1
var _band_dirty: bool = true
var _bb_sum: float = 0.0
var _bb_n: int = 0
var _bl_sum: float = 0.0
var _bl_n: int = 0
var _br_sum: float = 0.0
var _br_n: int = 0
var _pending: PackedInt32Array = PackedInt32Array()
var _bit_change_ticks: int = 0
var _bit_broken_said: bool = false
var _return_phase: String = "idle"
var _drill_room: int = -1
var _power: PackedFloat64Array = PackedFloat64Array()
# Tuning, read once.
var _base_speed: float = 1.0
var _max_speed: float = 3.0
var _air_floor: float = 0.3
var _turn_per_tick: float = 0.0
var _max_heading: float = 45.0
var _band: int = 2
var _heat_kw_per_bar: float = 0.0
var _wear_k: float = 0.0
var _bit_slow: float = 0.5
var _broken_factor: float = 0.2
var _noise_k: float = 0.0
var _rock_base_c: float = 40.0
var _rock_c_per_m: float = 0.0


func _init(db: DataDB) -> void:
	_db = db
	for i: int in range(MAX_POWER_BAR + 1):
		_power.append(db.tune("drill.power_factor_bar_%d" % i))
	cell_m = db.tune("drill.cell_m")
	_base_speed = db.tune("drill.base_speed_m_s")
	_max_speed = db.tune("drill.max_speed_m_s")
	_air_floor = maxf(0.01, db.tune("drill.air_hardness_floor"))
	_turn_per_tick = db.tune("drill.turn_deg_s") * Sim.DT
	_max_heading = db.tune("drill.max_heading_deg")
	_band = maxi(1, roundi(db.tune("drill.band_cells")))
	_heat_kw_per_bar = db.tune("drill.heat_kw_per_bar")
	_wear_k = db.tune("drill.wear_per_m_hardness")
	_bit_slow = db.tune("drill.bit_slow_at_full_wear")
	_broken_factor = db.tune("drill.broken_bit_factor")
	_noise_k = db.tune("drill.noise_per_m")
	_rock_base_c = db.tune("drill.rock_temp_base_c")
	_rock_c_per_m = db.tune("drill.rock_temp_c_per_m")
	_pending.resize(RunState.RESOURCES.size())
	yielded.resize(RunState.RESOURCES.size())


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


## {"type": "steer", "angle": deg} | {"type": "change_bit"} |
## {"type": "begin_segment", "segment": id, "depth_m": d, "lateral_m": x, "rock": table id (optional)}
func apply(sim: Sim, cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"steer":
			target_heading_deg = clampf(float(cmd.get("angle", 0.0)), -_max_heading, _max_heading)
		"change_bit":
			change_bit(sim)
		"begin_segment":
			begin_segment(sim, str(cmd.get("segment", "")), float(cmd.get("depth_m", 36.0)),
					float(cmd.get("lateral_m", 0.0)), str(cmd.get("rock", DEFAULT_ROCK)))


## Start a segment: generate the rock and switch the run to the "drill" phase. Allowed from "idle"
## (a run between nodes) or "scenario" (tests and captures). On arrival a scenario returns to
## "scenario" and a run calls RunState.arrive (which goes back to idle when no node was chosen).
func begin_segment(sim: Sim, p_segment_id: String, p_depth_m: float, lateral_m: float, p_rock_id: String = DEFAULT_ROCK) -> bool:
	var phase: String = sim.run.phase
	if active or (phase != "idle" and phase != "scenario"):
		sim.emit("bad_command", {"type": "begin_segment", "why": "not idle (phase %s)" % phase})
		return false
	var table: Dictionary = _db.table("rock").get(p_rock_id, {})
	if table.is_empty() or p_segment_id.is_empty():
		sim.emit("bad_command", {"type": "begin_segment", "why": "no rock table \"%s\" or no segment id" % p_rock_id})
		return false
	_load_materials(table)
	segment_id = p_segment_id
	rock_id = p_rock_id
	ship_size = _ship_footprint(sim.ship)
	cols = roundi(_db.tune("drill.width_m") / cell_m)
	var width: float = float(cols) * cell_m
	depth_m = maxf(cell_m, p_depth_m)
	var max_lat: float = minf(_db.tune("drill.max_lateral_m"), maxf(0.0, width - ship_size.x))
	var lat: float = clampf(lateral_m, -max_lat, max_lat)
	var x0: float = clampf(snappedf(width * 0.5 - lat * 0.5 - ship_size.x * 0.5, cell_m), 0.0, width - ship_size.x)
	var y0: float = snappedf(_db.tune("drill.top_air_m"), cell_m)
	start_center_x = x0 + ship_size.x * 0.5
	start_y = y0
	target_y = y0 + ship_size.y + depth_m
	target_x = clampf(start_center_x + lat, ship_size.x * 0.5, width - ship_size.x * 0.5)
	rows = ceili((target_y + _db.tune("drill.bottom_margin_m")) / cell_m)
	var rng: RandomNumberGenerator = sim.rng.get_stream("drill/" + p_segment_id)
	grid = RockGen.generate(table, rng, cols, rows, cell_m, Rect2(x0, y0, ship_size.x, ship_size.y), target_x,
			depth_m, sim.run.depth_m, _db.tune("drill.shaft_margin_m"), _db.tune("drill.top_air_m"))
	generated = PackedInt32Array()
	generated.resize(MAX_CODES)
	for i: int in range(grid.size()):
		generated[grid[i]] += 1
	mined = PackedInt32Array()
	mined.resize(MAX_CODES)
	yielded.fill(0)
	_pending.fill(0)
	_burst = PackedByteArray()
	_burst.resize(grid.size())
	chunk_cols = ceili(float(cols) / CHUNK_CELLS)
	chunk_rows = ceili(float(rows) / CHUNK_CELLS)
	chunk_changes = PackedInt32Array()
	chunk_changes.resize(chunk_cols * chunk_rows)
	_px = x0
	_py = y0
	ship_pos = Vector2(_px, _py)
	heading_deg = 0.0
	target_heading_deg = 0.0
	speed_m_s = 0.0
	cutting = false
	distance_m = 0.0
	segment_ticks = 0
	noise_segment = 0.0
	water_in_ml = 0
	lost_water_ml = 0
	heat_added_j = 0
	pockets_burst = 0
	start_depth_m = sim.run.depth_m
	_return_phase = phase
	_drill_room = sim.ship.room_with_system("drill")
	water_cell_ml = 0
	if _drill_room >= 0:
		water_cell_ml = roundi(cell_m * cell_m * sim.ship.rooms[_drill_room].depth_m * Room.ML_PER_M3)
	_set_footprint()
	_band_dirty = true
	active = true
	grid_serial += 1
	sim.emit("segment_begin", {"segment": segment_id, "depth_m": depth_m, "lateral_m": lat, "rock": rock_id})
	sim.run.set_phase(sim, "drill")
	return true


## Spend a drill bit (run resource "bits") and stop drilling while it is fitted.
func change_bit(sim: Sim) -> bool:
	if _bit_change_ticks > 0 or sim.run.get_res("bits") <= 0:
		sim.emit("bad_command", {"type": "change_bit", "why": "already changing" if _bit_change_ticks > 0 else "no bits left"})
		return false
	sim.run.add(sim, "bits", -1)
	_bit_change_ticks = maxi(1, roundi(_db.tune("drill.bit_change_s") * Sim.TICK_HZ))
	bit_change_left_s = float(_bit_change_ticks) / Sim.TICK_HZ
	sim.emit("bit_change_started", {"bits_left": sim.run.get_res("bits")})
	return true


## 0 at the start of the segment, 1 on arrival.
func progress() -> float:
	if depth_m <= 0.0:
		return 0.0
	return clampf((_py - start_y) / depth_m, 0.0, 1.0)


func power_factor(bars: int) -> float:
	return _power[clampi(bars, 0, MAX_POWER_BAR)]


## Material lookup by code for the view and bots: {"id", "name", "hardness", "color"} or {}.
func material(code: int) -> Dictionary:
	if code < 0 or code >= materials.size():
		return {}
	return materials[code]


func step(sim: Sim) -> void:
	if _bit_change_ticks > 0 and sim.run.world_running():
		_bit_change_ticks -= 1
		bit_change_left_s = float(_bit_change_ticks) / Sim.TICK_HZ
		if _bit_change_ticks == 0:
			bit_wear = 0.0
			bit_broken = false
			_bit_broken_said = false
			sim.emit("bit_changed", {})
	if not active or sim.run.phase != "drill":
		return
	segment_ticks += 1
	heading_deg = move_toward(heading_deg, target_heading_deg, _turn_per_tick)
	var bars: int = sim.ship.rooms[_drill_room].effective_bars() if _drill_room >= 0 else 0
	var pf: float = power_factor(bars)
	speed_m_s = 0.0
	cutting = false
	if pf > 0.0 and _bit_change_ticks == 0:
		_drive(sim, bars, pf)
	sim.run.depth_m = start_depth_m + (_py - start_y)
	sim.ship.rock_temp_c = _rock_base_c + _rock_c_per_m * sim.run.depth_m
	if _py + ship_size.y >= target_y - EPS:
		_arrive(sim)


func _drive(sim: Sim, bars: int, pf: float) -> void:
	if _band_dirty:
		_compute_band()
	var rad: float = deg_to_rad(heading_deg)
	var s: float = sin(rad)
	var co: float = cos(rad)
	var a: float = absf(s)
	# Leading band: bottom cells weighted by the downward share of the motion, side cells by the
	# sideways share (cells entered per second). Air counts as hardness 0.
	var num: float = _bb_sum * co
	var den: float = float(_bb_n) * co
	if s > EPS and _br_n > 0:
		num += _br_sum * a
		den += float(_br_n) * a
	elif s < -EPS and _bl_n > 0:
		num += _bl_sum * a
		den += float(_bl_n) * a
	var h_cut: float = num / den if den > 0.0 else 0.0
	var bit_factor: float = _broken_factor if bit_broken else 1.0 - _bit_slow * bit_wear
	speed_m_s = minf(_max_speed, _base_speed * pf * bit_factor / maxf(h_cut, _air_floor)) * speed_scale
	var width: float = float(cols) * cell_m
	var nx: float = clampf(_px + speed_m_s * s * Sim.DT, 0.0, width - ship_size.x)
	var ny: float = _py + speed_m_s * co * Sim.DT
	var moved: float = sqrt((nx - _px) * (nx - _px) + (ny - _py) * (ny - _py))
	_px = nx
	_py = ny
	ship_pos = Vector2(_px, _py)
	distance_m += moved
	_advance_footprint(sim)
	cutting = h_cut > 0.0
	if not cutting:
		return
	var joules: int = roundi(_heat_kw_per_bar * float(bars) * h_cut * 1000.0 * Sim.DT)
	if joules > 0 and _drill_room >= 0:
		sim.hazards.add_heat(sim.ship.rooms[_drill_room], joules)
		heat_added_j += joules
	var noise: float = _noise_k * moved * pf * pf
	noise_segment += noise
	noise_total += noise
	if not bit_broken:
		bit_wear = minf(1.0, bit_wear + _wear_k * moved * h_cut)
		if bit_wear >= 1.0:
			bit_broken = true
			if not _bit_broken_said:
				_bit_broken_said = true
				sim.emit("bit_broken", {"segment": segment_id})


func _arrive(sim: Sim) -> void:
	var counts: Dictionary = {}
	for code: int in range(materials.size()):
		if code > 0 and mined[code] > 0:
			counts[str(materials[code].get("id", ""))] = mined[code]
	sim.emit("segment_done", {
		"segment": segment_id,
		"time_s": snappedf(float(segment_ticks) / Sim.TICK_HZ, 0.01),
		"distance_m": snappedf(distance_m, 0.01),
		"mined": counts,
		"noise": snappedf(noise_segment, 0.01),
		"lost_water_ml": lost_water_ml,
	})
	active = false
	speed_m_s = 0.0
	cutting = false
	if _return_phase == "scenario":
		sim.run.set_phase(sim, "scenario")
	elif sim.run.mode == "run":
		sim.run.arrive(sim)  # The run hands the node to its module (or back to idle).
	else:
		sim.run.set_phase(sim, "idle")


# Footprint and cutting ---------------------------------------------------------------------------

func _set_footprint() -> void:
	_c0 = clampi(floori(_px / cell_m + EPS), 0, cols - 1)
	_c1 = clampi(ceili((_px + ship_size.x) / cell_m - EPS) - 1, 0, cols - 1)
	_r0 = clampi(floori(_py / cell_m + EPS), 0, rows - 1)
	_r1 = clampi(ceili((_py + ship_size.y) / cell_m - EPS) - 1, 0, rows - 1)


## Cut every cell the footprint newly overlaps (only when the covered cell rectangle changes).
func _advance_footprint(sim: Sim) -> void:
	var oc0: int = _c0
	var oc1: int = _c1
	var or0: int = _r0
	var or1: int = _r1
	_set_footprint()
	if _c0 == oc0 and _c1 == oc1 and _r0 == or0 and _r1 == or1:
		return
	for r: int in range(_r0, _r1 + 1):
		var row: int = r * cols
		var in_old_row: bool = r >= or0 and r <= or1
		for c: int in range(_c0, _c1 + 1):
			if in_old_row and c >= oc0 and c <= oc1:
				continue
			if grid[row + c] != 0:
				_cut(sim, row + c, r, c)
	_flush_yields(sim)
	_band_dirty = true


func _cut(sim: Sim, i: int, r: int, c: int) -> void:
	var m: int = grid[i]
	grid[i] = 0
	mined[m] += 1
	chunk_changes[(r / CHUNK_CELLS) * chunk_cols + c / CHUNK_CELLS] += 1
	var yr: int = yield_res_of[m]
	if yr >= 0:
		_pending[yr] += yield_amount_of[m]
	if water_of[m] == 1:
		if _burst[i] == 0:
			_burst_pocket(sim, i)
		if _drill_room >= 0:
			var put: int = sim.hazards.add_water(sim.ship.rooms[_drill_room], water_cell_ml)
			water_in_ml += put
			lost_water_ml += water_cell_ml - put
		else:
			lost_water_ml += water_cell_ml


## The first cut cell of a water pocket bursts it: a small breach in the drill room, and the whole
## connected pocket is marked so it bursts only once.
func _burst_pocket(sim: Sim, start: int) -> void:
	var stack := PackedInt32Array([start])
	_burst[start] = 1
	var cells: int = 0
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		cells += 1
		var r: int = i / cols
		var c: int = i % cols
		var nbs := PackedInt32Array([i - cols if r > 0 else -1, i + cols if r < rows - 1 else -1,
				i - 1 if c > 0 else -1, i + 1 if c < cols - 1 else -1])
		for j: int in nbs:
			if j >= 0 and _burst[j] == 0 and water_of[grid[j]] == 1:
				_burst[j] = 1
				stack.append(j)
	pockets_burst += 1
	var room_id: String = ""
	if _drill_room >= 0:
		var room: Room = sim.ship.rooms[_drill_room]
		room.breach_m2 += _db.tune("drill.pocket_breach_m2")
		room_id = room.id
	sim.emit("pocket_burst", {"room": room_id, "cells": cells})


func _flush_yields(sim: Sim) -> void:
	for k: int in range(_pending.size()):
		if _pending[k] != 0:
			var got: int = sim.run.add(sim, RunState.RESOURCES[k], _pending[k])
			yielded[k] += got
			_pending[k] = 0


## Sum the hardness of the cells just beyond the footprint: below it and on each side.
func _compute_band() -> void:
	_band_dirty = false
	_bb_sum = 0.0
	_bb_n = 0
	_bl_sum = 0.0
	_bl_n = 0
	_br_sum = 0.0
	_br_n = 0
	for r: int in range(_r1 + 1, mini(rows, _r1 + 1 + _band)):
		var row: int = r * cols
		for c: int in range(_c0, _c1 + 1):
			_bb_sum += hardness_of[grid[row + c]]
			_bb_n += 1
	for r: int in range(_r0, _r1 + 1):
		var row2: int = r * cols
		for c: int in range(maxi(0, _c0 - _band), _c0):
			_bl_sum += hardness_of[grid[row2 + c]]
			_bl_n += 1
		for c: int in range(_c1 + 1, mini(cols, _c1 + 1 + _band)):
			_br_sum += hardness_of[grid[row2 + c]]
			_br_n += 1


func _load_materials(table: Dictionary) -> void:
	materials = []
	materials.resize(MAX_CODES)
	hardness_of = PackedFloat64Array()
	hardness_of.resize(MAX_CODES)
	yield_res_of = PackedInt32Array()
	yield_res_of.resize(MAX_CODES)
	yield_res_of.fill(-1)
	yield_amount_of = PackedInt32Array()
	yield_amount_of.resize(MAX_CODES)
	water_of = PackedByteArray()
	water_of.resize(MAX_CODES)
	for i: int in range(MAX_CODES):
		materials[i] = {}
	for m: Variant in table.get("materials", []):
		var md: Dictionary = m
		var code: int = clampi(int(md.get("code", 0)), 0, MAX_CODES - 1)
		materials[code] = {"id": str(md.get("id", "")), "name": str(md.get("name", "")),
				"hardness": float(md.get("hardness", 1.0)), "color": str(md.get("color", "#808080"))}
		hardness_of[code] = float(md.get("hardness", 1.0))
		water_of[code] = 1 if bool(md.get("water", false)) else 0
		var y: Variant = md.get("yield", null)
		if y is Dictionary:
			var yd: Dictionary = y
			yield_res_of[code] = RunState.RESOURCES.find(str(yd.get("res", "")))
			yield_amount_of[code] = int(yd.get("amount", 0))


static func _ship_footprint(ship: Ship) -> Vector2:
	var box := Rect2()
	for i: int in range(ship.rooms.size()):
		box = ship.rooms[i].rect if i == 0 else box.merge(ship.rooms[i].rect)
	return box.end


## Everything this module owns, in a fixed order, for the state hash (the grid bytes included).
func state() -> Array:
	return [active, segment_id, rock_id, grid_serial, cols, rows, cell_m, _px, _py, heading_deg,
		target_heading_deg, speed_m_s, bit_wear, bit_broken, _bit_broken_said, _bit_change_ticks, cutting,
		start_center_x, start_y, target_x, target_y, depth_m, start_depth_m, distance_m, segment_ticks,
		noise_segment, noise_total, mined, yielded, water_in_ml, lost_water_ml, heat_added_j, pockets_burst,
		_return_phase, grid, _burst, speed_scale]


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	DrillLint.lint(db, errs)
