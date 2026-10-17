class_name DrillBot
extends Bot
## Drives drilling segments through commands only (steer, change_bit); it reads the rock grid and
## never changes the sim. Five times a second it scores the ship-wide lanes straight below (the next
## lookahead_m of rock, and side_look_m above the crown, level with it), shifted sideways by up to
## max_detour_m: ore and gem cells pull by their value (yield units times value_ore or value_gem,
## only while the segment's noise is under the budget; a buried structure's unopened crates by
## value_crate and its interior, until entered, by value_interior, both per cell), hard rock, water
## and gas pockets and fault rock push, straying from the corridor to the next node and every meter of detour cost.
## The best lane wins; with nothing better, it steers for the target. With level_steer on, the
## heading toward a lane uses how far below the crown its value lies (a vein level with the crown
## means cutting sideways, up to max_steer_deg); off (the plain bot) it aims at the lane half the
## look-ahead down. It never sits at the segment wall: within wall_margin_m of it, it steers for the
## target. Deterministic, no randomness. It leaves power and the crew alone (crew keep their own
## judgement); fault_ahead() tells a policy bot when to brace.

var noise_budget: float = 100.0  ## Detours for ore and gems only while noise_segment is below this.
var lookahead_m: float = 12.0
var max_detour_m: float = 6.0
var max_steer_deg: float = 45.0  ## The steepest heading the bot asks for.
var level_steer: bool = false  ## Steer by the depth of the lane's value (sideways for a level vein).
var side_look_m: float = 0.0  ## Also score this much rock above the crown (beside the hull).
var wall_margin_m: float = 0.75
var value_gem: float = 3.0  ## Per gem unit in the lane.
var value_ore: float = 1.0  ## Per ore unit in the lane.
var cost_hard: float = 1.5  ## Per hard rock cell in the lane.
var cost_water: float = 4.0  ## Per water pocket cell in the lane.
var cost_gas: float = 5.0  ## Per gas pocket cell in the lane.
var cost_fault: float = 0.0  ## Per fault rock cell in the lane.
var value_crate: float = 4.0  ## Per crate cell while the structure still has unopened crates.
var value_interior: float = 0.3  ## Per structure interior cell until the structure is entered.
var cost_lateral_per_m: float = 0.6
var cost_stray_per_m: float = 6.0  ## Per meter beyond stray_free_m from the corridor line.
var stray_free_m: float = 4.0
var hard_min: float = 3.0  ## Hardness counted as "hard rock".
var change_bit_at: float = 0.85

var _serial: int = -1
var _last_sent: float = 1000.0
var _col := PackedFloat64Array()
var _colp := PackedFloat64Array()  ## Positive value per column.
var _coly := PackedFloat64Array()  ## Positive value times meters below the crown, per column.
var _score_of := PackedFloat64Array()
var _greedy: bool = false
var _table_serial: int = -1
var _table_struct: int = -1  ## Structure state the table was built for (entered, crates opened).


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


## Fault rock within `ahead_m` below the crown in the ship's columns (plus 1 m each side), or beside
## the hull on the side it is turning toward.
func fault_ahead(d: DrillSim, ahead_m: float) -> bool:
	var cell: float = d.cell_m
	var c0: int = maxi(0, floori((d.ship_pos.x - 1.0) / cell))
	var c1: int = mini(d.cols - 1, floori((d.ship_pos.x + d.ship_size.x + 1.0) / cell))
	var bottom: float = d.ship_pos.y + d.ship_size.y
	var r0: int = clampi(floori((bottom - d.ship_size.y * 0.5) / cell), 0, d.rows - 1)
	var r1: int = clampi(floori((bottom + ahead_m) / cell), 0, d.rows - 1)
	if d.heading_deg > 30.0:
		c1 = mini(d.cols - 1, c1 + roundi(ahead_m * 0.5 / cell))
	elif d.heading_deg < -30.0:
		c0 = maxi(0, c0 - roundi(ahead_m * 0.5 / cell))
	var grid: PackedByteArray = d.grid
	var flag: PackedByteArray = d.unstable_of
	for r: int in range(r0, r1 + 1):
		var row: int = r * d.cols
		for c: int in range(c0, c1 + 1):
			if flag[grid[row + c]] == 1:
				return true
	return false


func _choose_heading(d: DrillSim) -> float:
	var cell: float = d.cell_m
	var cx: float = d.ship_pos.x + d.ship_size.x * 0.5
	var bottom: float = d.ship_pos.y + d.ship_size.y
	var to_target: float = clampf(rad_to_deg(atan2(d.target_x - cx, maxf(d.target_y - bottom, 1.0))), -45.0, 45.0)
	var lane_w: int = roundi(d.ship_size.x / cell)
	var crown_r: int = clampi(floori(bottom / cell), 0, d.rows - 1)
	var r0: int = clampi(floori((bottom - side_look_m) / cell), 0, d.rows - 1)
	var r1: int = clampi(crown_r + roundi(lookahead_m / cell), 0, d.rows - 1)
	var greedy: bool = d.noise_segment < noise_budget
	if greedy != _greedy or d.grid_serial != _table_serial or _struct_key(d) != _table_struct:
		_build_tables(d, greedy)
	# Per column score over the look-ahead rows (every other row: features are wider than a meter),
	# only for columns a lane can reach, then a sliding lane of the ship's width.
	var n: int = d.cols
	var base_c0: int = floori(d.ship_pos.x / cell + 0.000001)
	var max_off: int = roundi(max_detour_m / cell)
	_col.resize(n)
	_colp.resize(n)
	_coly.resize(n)
	var grid: PackedByteArray = d.grid
	var stride: int = n * 2
	for c: int in range(maxi(base_c0 - max_off, 0), mini(base_c0 + max_off + lane_w, n)):
		var v: float = 0.0
		var vp: float = 0.0
		var vy: float = 0.0
		var i: int = r0 * n + c
		for r: int in range(r0, r1 + 1, 2):
			var sc: float = _score_of[grid[i]]
			v += sc
			if sc > 0.0:
				vp += sc
				vy += sc * maxf(0.0, (float(r) + 0.5) * cell - bottom)
			i += stride
		_col[c] = v * 2.0
		_colp[c] = vp
		_coly[c] = vy
	var mid_y: float = bottom + lookahead_m * 0.5
	var t: float = clampf((mid_y - (d.start_y + d.ship_size.y)) / maxf(d.depth_m, 1.0), 0.0, 1.0)
	var corridor_x: float = lerpf(d.start_center_x, d.target_x, t)
	var lo: int = maxi(base_c0 - max_off, 0)
	var hi: int = mini(base_c0 + max_off, n - lane_w)
	var lane: float = 0.0
	var lane_p: float = 0.0
	var lane_y: float = 0.0
	for c: int in range(lo, lo + lane_w):
		lane += _col[c]
		lane_p += _colp[c]
		lane_y += _coly[c]
	var best_off: int = 0
	var best_score: float = -INF
	var best_dy: float = lookahead_m * 0.5
	var zero_score: float = -INF
	for c0: int in range(lo, hi + 1):
		if c0 > lo:
			lane += _col[c0 + lane_w - 1] - _col[c0 - 1]
			lane_p += _colp[c0 + lane_w - 1] - _colp[c0 - 1]
			lane_y += _coly[c0 + lane_w - 1] - _coly[c0 - 1]
		var off: int = c0 - base_c0
		var off_m: float = float(off) * cell
		var score: float = lane - absf(off_m) * cost_lateral_per_m
		score -= maxf(0.0, absf(cx + off_m - corridor_x) - stray_free_m) * cost_stray_per_m
		if off == 0:
			zero_score = score
		if score > best_score:
			best_score = score
			best_off = off
			best_dy = lane_y / lane_p if lane_p > 0.0 else lookahead_m * 0.5
	var heading: float = to_target
	if best_off != 0 and best_score > zero_score + 0.5:
		var dy: float = maxf(best_dy, cell) if level_steer else lookahead_m * 0.5
		heading = clampf(rad_to_deg(atan2(float(best_off) * cell, dy)), -max_steer_deg, max_steer_deg)
	var width: float = float(d.cols) * cell
	if (heading > 0.0 and d.ship_pos.x + d.ship_size.x >= width - wall_margin_m) \
			or (heading < 0.0 and d.ship_pos.x <= wall_margin_m) or d.at_wall:
		heading = to_target
	return heading


## Score per material code: value for ore and gems (only while greedy), cost for hazards. Hardness
## is the effective one (a diamond head makes basalt ordinary rock, so it stops costing).
func _build_tables(d: DrillSim, greedy: bool) -> void:
	_greedy = greedy
	_table_serial = d.grid_serial
	_table_struct = _struct_key(d)
	var st: DrillStructures = d.structures
	var crate_v: float = value_crate if greedy and st.has_structure() and st.crates_opened < st.crates_total else 0.0
	var inside_v: float = value_interior if greedy and st.has_structure() and not st.entered else 0.0
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
		if d.unstable_of[m] == 1:
			v -= cost_fault
		if d.loot_of[m] == 1:
			v += crate_v
		elif d.interior_of[m] == 1:
			v += inside_v
		_score_of[m] = v


## Changes whenever the structure is entered or a crate opens (the lane values change then).
static func _struct_key(d: DrillSim) -> int:
	return (d.structures.crates_opened * 2 + (1 if d.structures.entered else 0)) if d.structures.has_structure() else -2
