class_name DrillSim
extends SimModule
## The drilling segment between map nodes. The sim owns a rock grid (square cells, one material code
## each, generated from a rock table, the segment's survey and the stream "drill/<segment id>"). The
## whole ship footprint moves through it; its bottom edge is the cutting crown. Each tick: turn toward
## the steered heading, read the leading band (cells about to be entered), move, cut every newly
## overlapped cell. Cut cells are counted exactly (mined per material); ore and gems go to run
## resources (one "mined" event per material per footprint step), water pockets pour into the drill
## room, gas pockets set it on fire, cutting heats the drill room, wears the bit and makes noise.
## Arrival is depth only: the ship's bottom edge reaching target_y. Steering is for detours.
## Gear (RunState.gear_x) scales cut speed, bit wear and the hardness of hard rock, read when the
## segment begins. Segment space: meters, +x right, +y down, like ship space. See ARCHITECTURE.md.
##
## Events: "segment_begin", "mined" {"material", "res", "amount", "x_m", "y_m"} (crown position),
## "pocket_burst" {"room", "cells"}, "gas_burst" {"room", "cells", "x_m", "y_m"}, "bit_broken",
## "segment_done" {"segment", "time_s", "distance_m", "mined" (cells by material id), "yield"
## (resource units by material id), "ore", "gems", "noise", "lost_water_ml", "gas_bursts"}.

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
	"drill.rock_temp_base_c", "drill.rock_temp_c_per_m", "drill.gas_fire_level", "drill.gas_noise",
	"drill.hard_rock_min_hardness",
]

# Read by the view (never written outside this class and DrillMaterials).
var active: bool = false
var segment_id: String = ""
var rock_id: String = ""
var survey: Dictionary = {}  ## The options this segment was generated with (RockGen.options_of).
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
var yield_mat: PackedInt32Array = PackedInt32Array()  ## Given to run resources this segment, by material code.
var water_in_ml: int = 0  ## Pocket water that went into the drill room this segment.
var lost_water_ml: int = 0  ## Pocket water that did not fit (lost to the rock).
var water_cell_ml: int = 0
var heat_added_j: int = 0
var pockets_burst: int = 0
var gas_bursts: int = 0
var chunk_cols: int = 0
var chunk_rows: int = 0
var chunk_changes: PackedInt32Array = PackedInt32Array()  ## +1 whenever a cell in that chunk changes.
var materials: Array[Dictionary] = []  ## By code: {"id", "name", "hardness", "color", "res", "amount"} or {}.
var hardness_of: PackedFloat64Array = PackedFloat64Array()  ## By code, effective (after gear).
var yield_res_of: PackedInt32Array = PackedInt32Array()  ## By code: RunState.RESOURCES index or -1.
var yield_amount_of: PackedInt32Array = PackedInt32Array()
var water_of: PackedByteArray = PackedByteArray()  ## By code: 1 for water pockets.
var gas_of: PackedByteArray = PackedByteArray()  ## By code: 1 for gas pockets.

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
var _pend_amt: PackedInt32Array = PackedInt32Array()  ## Yield waiting for the flush, by material code.
var _pend_codes: PackedInt32Array = PackedInt32Array()  ## Codes with a pending yield, in first-cut order.
var _pend_n: int = 0
var _bit_change_ticks: int = 0
var _bit_broken_said: bool = false
var _return_phase: String = "idle"
var _drill_room: int = -1
var _power: PackedFloat64Array = PackedFloat64Array()
var _cut_x: float = 1.0  ## Gear multipliers, read when the segment begins.
var _wear_x: float = 1.0
var _hard_x: float = 1.0
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
var _gas_fire: float = 0.3
var _gas_noise: float = 0.0
var _hard_min: float = 3.0


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
	_gas_fire = db.tune("drill.gas_fire_level")
	_gas_noise = db.tune("drill.gas_noise")
	_hard_min = db.tune("drill.hard_rock_min_hardness")
	yielded.resize(RunState.RESOURCES.size())
	yield_mat.resize(MAX_CODES)
	_pend_amt.resize(MAX_CODES)
	_pend_codes.resize(MAX_CODES)


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


## {"type": "steer", "angle": deg} | {"type": "change_bit"} |
## {"type": "begin_segment", "segment": id, "depth_m": d, "lateral_m": x, "rock": table id (optional),
##  "survey": a node survey (optional, see RockGen.options_of)}
func apply(sim: Sim, cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"steer":
			target_heading_deg = clampf(float(cmd.get("angle", 0.0)), -_max_heading, _max_heading)
		"change_bit":
			change_bit(sim)
		"begin_segment":
			var sv: Variant = cmd.get("survey", {})
			begin_segment(sim, str(cmd.get("segment", "")), float(cmd.get("depth_m", 36.0)),
					float(cmd.get("lateral_m", 0.0)), str(cmd.get("rock", DEFAULT_ROCK)), sv if sv is Dictionary else {})


## Start a segment: generate the rock and switch the run to the "drill" phase. Allowed from "idle"
## (a run between nodes) or "scenario" (tests and captures). On arrival a scenario returns to
## "scenario" and a run calls RunState.arrive (which goes back to idle when no node was chosen).
func begin_segment(sim: Sim, p_segment_id: String, p_depth_m: float, lateral_m: float,
		p_rock_id: String = DEFAULT_ROCK, p_survey: Dictionary = {}) -> bool:
	var phase: String = sim.run.phase
	if active or (phase != "idle" and phase != "scenario"):
		sim.emit("bad_command", {"type": "begin_segment", "why": "not idle (phase %s)" % phase})
		return false
	var table: Dictionary = _db.table("rock").get(p_rock_id, {})
	if table.is_empty() or p_segment_id.is_empty():
		sim.emit("bad_command", {"type": "begin_segment", "why": "no rock table \"%s\" or no segment id" % p_rock_id})
		return false
	_cut_x = sim.run.gear_x("cut_speed_x")
	_wear_x = sim.run.gear_x("wear_x")
	_hard_x = sim.run.gear_x("hard_rock_x")
	DrillMaterials.load_into(self, table, _hard_x, _hard_min)
	segment_id = p_segment_id
	rock_id = p_rock_id
	survey = RockGen.options_of(p_survey)
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
			depth_m, sim.run.depth_m, _db.tune("drill.shaft_margin_m"), _db.tune("drill.top_air_m"), survey)
	generated = PackedInt32Array()
	generated.resize(MAX_CODES)
	for i: int in range(grid.size()):
		generated[grid[i]] += 1
	mined = PackedInt32Array()
	mined.resize(MAX_CODES)
	yielded.fill(0)
	yield_mat.fill(0)
	_pend_amt.fill(0)
	_pend_n = 0
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
	gas_bursts = 0
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


## Material lookup by code for the view and bots: {"id", "name", "hardness", "color", "res", "amount"} or {}.
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
	# Systems: a manned helm turns faster; a manned drill room cuts faster (drill_bonus is a multiplier).
	heading_deg = move_toward(heading_deg, target_heading_deg, _turn_per_tick * sim.systems.steer_rate_scale(sim.player))
	var bars: int = sim.systems.drill_bars(sim.player)
	var pf: float = power_factor(bars) * sim.systems.drill_bonus(sim.player)
	speed_m_s = 0.0
	cutting = false
	if pf > 0.0 and _bit_change_ticks == 0:
		_drive(sim, bars, pf)
	sim.run.depth_m = start_depth_m + (_py - start_y)
	var base_c: float = _rock_base_c
	var per_m: float = _rock_c_per_m
	if not sim.run.layer.is_empty():  # In a run the layer owns rock heat; drill tuning is the scenario fallback.
		base_c = float(sim.run.layer.get("rock_temp_base_c", base_c))
		per_m = float(sim.run.layer.get("rock_temp_c_per_m", per_m))
	sim.ship.rock_temp_c = base_c + per_m * sim.run.depth_m
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
	speed_m_s = minf(_max_speed, _base_speed * _cut_x * pf * bit_factor / maxf(h_cut, _air_floor)) * speed_scale
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
	var noise: float = _noise_k * moved * pf * pf * h_cut  # Grinding through hard rock is louder.
	noise_segment += noise
	noise_total += noise
	if not bit_broken:
		bit_wear = minf(1.0, bit_wear + _wear_k * _wear_x * moved * h_cut)
		if bit_wear >= 1.0:
			bit_broken = true
			if not _bit_broken_said:
				_bit_broken_said = true
				sim.emit("bit_broken", {"segment": segment_id})


func _arrive(sim: Sim) -> void:
	var counts: Dictionary = {}
	var yields: Dictionary = {}
	for code: int in range(1, materials.size()):
		var mid: String = str(materials[code].get("id", ""))
		if mined[code] > 0:
			counts[mid] = mined[code]
		if yield_mat[code] > 0:
			yields[mid] = yield_mat[code]
	sim.emit("segment_done", {
		"segment": segment_id,
		"time_s": snappedf(float(segment_ticks) / Sim.TICK_HZ, 0.01),
		"distance_m": snappedf(distance_m, 0.01),
		"mined": counts,
		"yield": yields,
		"ore": yielded[RunState.RESOURCES.find("ore")],
		"gems": yielded[RunState.RESOURCES.find("gems")],
		"noise": snappedf(noise_segment, 0.01),
		"lost_water_ml": lost_water_ml,
		"gas_bursts": gas_bursts,
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
	if yield_res_of[m] >= 0:
		if _pend_amt[m] == 0:
			_pend_codes[_pend_n] = m
			_pend_n += 1
		_pend_amt[m] += yield_amount_of[m]
	if water_of[m] == 1:
		if _burst[i] == 0:
			_burst_pocket(sim, i)
		if _drill_room >= 0:
			var put: int = sim.hazards.add_water(sim.ship.rooms[_drill_room], water_cell_ml)
			water_in_ml += put
			lost_water_ml += water_cell_ml - put
		else:
			lost_water_ml += water_cell_ml
	elif gas_of[m] == 1 and _burst[i] == 0:
		_burst_gas(sim, i)


## The first cut cell of a water pocket bursts it: a small breach in the drill room, and the whole
## connected pocket is marked so it bursts only once.
func _burst_pocket(sim: Sim, start: int) -> void:
	var cells: int = DrillMaterials.flood(grid, cols, rows, start, water_of, _burst)
	pockets_burst += 1
	var room_id: String = ""
	if _drill_room >= 0:
		var room: Room = sim.ship.rooms[_drill_room]
		room.breach_m2 += _db.tune("drill.pocket_breach_m2")
		room_id = room.id
	sim.emit("pocket_burst", {"room": room_id, "cells": cells})


## The first cut cell of a gas pocket ignites it: a fire in the drill room (or a hotter one), a burst
## of noise, and the whole connected pocket is marked so it ignites only once.
func _burst_gas(sim: Sim, start: int) -> void:
	var cells: int = DrillMaterials.flood(grid, cols, rows, start, gas_of, _burst)
	gas_bursts += 1
	noise_segment += _gas_noise
	noise_total += _gas_noise
	var room_id: String = ""
	if _drill_room >= 0:
		var room: Room = sim.ship.rooms[_drill_room]
		sim.hazards.ignite(sim, sim.player, room, _gas_fire)
		room_id = room.id
	sim.emit("gas_burst", {"room": room_id, "cells": cells, "x_m": snappedf(_px + ship_size.x * 0.5, 0.01),
			"y_m": snappedf(_py + ship_size.y, 0.01)})


## Pay what the last footprint step cut: one exact run.add and one "mined" event per material.
func _flush_yields(sim: Sim) -> void:
	if _pend_n == 0:
		return
	var x: float = snappedf(_px + ship_size.x * 0.5, 0.01)
	var y: float = snappedf(_py + ship_size.y, 0.01)
	for k: int in range(_pend_n):
		var m: int = _pend_codes[k]
		var ri: int = yield_res_of[m]
		var got: int = sim.run.add(sim, RunState.RESOURCES[ri], _pend_amt[m])
		_pend_amt[m] = 0
		yielded[ri] += got
		yield_mat[m] += got
		sim.emit("mined", {"material": str(materials[m].get("id", "")), "res": RunState.RESOURCES[ri], "amount": got,
				"x_m": x, "y_m": y})
	_pend_n = 0


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
		noise_segment, noise_total, mined, yielded, yield_mat, water_in_ml, lost_water_ml, heat_added_j,
		pockets_burst, gas_bursts, _return_phase, grid, _burst, speed_scale, survey.values(), _cut_x, _wear_x, _hard_x]


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	DrillLint.lint(db, errs)
