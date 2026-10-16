class_name DrillBot
extends Bot
## Drives drilling segments through commands only (steer, change_bit); it reads the rock grid and
## never changes the sim. Five times a second it scores the ship-wide lanes straight below (the next
## lookahead_m of rock), shifted sideways by up to max_detour_m: ore and gem cells pull by their
## value (yield units times value_ore or value_gem, only while the segment's noise is under the
## budget), hard rock, water and gas pockets push, straying from the corridor to the next node and
## every meter of detour cost.
## The best lane wins; with nothing better, it steers for the target. Deterministic, no randomness.
## It leaves power and the crew alone (crew keep their own judgement).

var noise_budget: float = 100.0  ## Detours for ore and gems only while noise_segment is below this.
var lookahead_m: float = 12.0
var max_detour_m: float = 6.0
var value_gem: float = 3.0  ## Per gem unit in the lane.
var value_ore: float = 1.0  ## Per ore unit in the lane.
var cost_hard: float = 1.5  ## Per hard rock cell in the lane.
var cost_water: float = 4.0  ## Per water pocket cell in the lane.
var cost_gas: float = 5.0  ## Per gas pocket cell in the lane.
var cost_lateral_per_m: float = 0.6
var cost_stray_per_m: float = 6.0  ## Per meter beyond stray_free_m from the corridor line.
var stray_free_m: float = 4.0
var hard_min: float = 3.0  ## Hardness counted as "hard rock".
var change_bit_at: float = 0.85

var _serial: int = -1
var _last_sent: float = 1000.0
var _col := PackedFloat64Array()
var _score_of := PackedFloat64Array()
var _greedy: bool = false
var _table_serial: int = -1


func act(sim: Sim) -> void:
	var d: DrillSim = sim.drill
	if not d.active or sim.run.phase != "drill" or sim.tick % 12 != 0:
		return
	if d.grid_serial != _serial:
		_serial = d.grid_serial
		_last_sent = 1000.0
	if d.bit_wear > change_bit_at and d.bit_change_left_s <= 0.0 and sim.run.get_res("bits") > 0:
		sim.push({"type": "change_bit"})
	var want: float = snappedf(_choose_heading(d), 1.0)
	if absf(want - _last_sent) >= 1.0:
		_last_sent = want
		sim.push({"type": "steer", "angle": want})


func _choose_heading(d: DrillSim) -> float:
	var cell: float = d.cell_m
	var cx: float = d.ship_pos.x + d.ship_size.x * 0.5
	var bottom: float = d.ship_pos.y + d.ship_size.y
	var to_target: float = rad_to_deg(atan2(d.target_x - cx, maxf(d.target_y - bottom, 1.0)))
	var lane_w: int = roundi(d.ship_size.x / cell)
	var r0: int = clampi(floori(bottom / cell), 0, d.rows - 1)
	var r1: int = clampi(r0 + roundi(lookahead_m / cell), 0, d.rows - 1)
	var greedy: bool = d.noise_segment < noise_budget
	if greedy != _greedy or d.grid_serial != _table_serial:
		_build_tables(d, greedy)
	# Per column score over the look-ahead rows (every other row: features are wider than a meter),
	# only for columns a lane can reach, then a sliding lane of the ship's width.
	var n: int = d.cols
	var base_c0: int = floori(d.ship_pos.x / cell + 0.000001)
	var max_off: int = roundi(max_detour_m / cell)
	_col.resize(n)
	var grid: PackedByteArray = d.grid
	var stride: int = n * 2
	for c: int in range(maxi(base_c0 - max_off, 0), mini(base_c0 + max_off + lane_w, n)):
		var v: float = 0.0
		var i: int = r0 * n + c
		for r: int in range(r0, r1 + 1, 2):
			v += _score_of[grid[i]]
			i += stride
		_col[c] = v * 2.0
	var mid_y: float = bottom + lookahead_m * 0.5
	var t: float = clampf((mid_y - (d.start_y + d.ship_size.y)) / maxf(d.depth_m, 1.0), 0.0, 1.0)
	var corridor_x: float = lerpf(d.start_center_x, d.target_x, t)
	var lo: int = maxi(base_c0 - max_off, 0)
	var hi: int = mini(base_c0 + max_off, n - lane_w)
	var lane: float = 0.0
	for c: int in range(lo, lo + lane_w):
		lane += _col[c]
	var best_off: int = 0
	var best_score: float = -INF
	var zero_score: float = -INF
	for c0: int in range(lo, hi + 1):
		if c0 > lo:
			lane += _col[c0 + lane_w - 1] - _col[c0 - 1]
		var off: int = c0 - base_c0
		var off_m: float = float(off) * cell
		var score: float = lane - absf(off_m) * cost_lateral_per_m
		score -= maxf(0.0, absf(cx + off_m - corridor_x) - stray_free_m) * cost_stray_per_m
		if off == 0:
			zero_score = score
		if score > best_score:
			best_score = score
			best_off = off
	if best_off == 0 or best_score <= zero_score + 0.5:
		return clampf(to_target, -45.0, 45.0)
	return clampf(rad_to_deg(atan2(float(best_off) * cell, lookahead_m * 0.5)), -45.0, 45.0)


## Score per material code: value for ore and gems (only while greedy), cost for hazards. Hardness
## is the effective one (a diamond head makes basalt ordinary rock, so it stops costing).
func _build_tables(d: DrillSim, greedy: bool) -> void:
	_greedy = greedy
	_table_serial = d.grid_serial
	_score_of.resize(DrillSim.MAX_CODES)
	for m: int in range(DrillSim.MAX_CODES):
		var v: float = 0.0
		var yr: int = d.yield_res_of[m]
		if yr >= 0 and greedy:
			v += float(d.yield_amount_of[m]) * (value_gem if RunState.RESOURCES[yr] == "gems" else value_ore)
		if d.water_of[m] == 1:
			v -= cost_water
		elif d.gas_of[m] == 1:
			v -= cost_gas
		elif d.hardness_of[m] >= hard_min:
			v -= cost_hard
		_score_of[m] = v
