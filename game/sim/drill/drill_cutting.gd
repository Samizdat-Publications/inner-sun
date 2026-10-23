class_name DrillCutting
extends RefCounted
## The drill's motion and cutting, split out of DrillSim (M1d): one tick of driving through the
## rock, the footprint's newly overlapped cells, booking a cut cell, paying pending yields, and the
## leading band's hardness. Static: every function works on the DrillSim passed in (its state stays
## there, so DrillSim.state() is unchanged) and holds no reference to it or to the Sim.


static func drive(sim: Sim, d: DrillSim, bars: int, pf: float) -> void:
	if d._band_dirty:
		compute_band(d)
	var rad: float = deg_to_rad(d.heading_deg)
	var s: float = sin(rad)
	var co: float = cos(rad)
	var a: float = absf(s) * d.side_scale
	# Leading band: bottom cells weighted by the downward share of the motion, side cells by the
	# sideways share (cells entered per second). Air counts as hardness 0.
	var num: float = d._bb_sum * co
	var den: float = float(d._bb_n) * co
	if s > DrillSim.EPS and d._br_n > 0:
		num += d._br_sum * a
		den += float(d._br_n) * a
	elif s < -DrillSim.EPS and d._bl_n > 0:
		num += d._bl_sum * a
		den += float(d._bl_n) * a
	var h_cut: float = num / den if den > DrillSim.EPS else 0.0
	var bit_factor: float = d._broken_factor if d.bit_broken else 1.0 - d._bit_slow * d.bit_wear
	d.speed_m_s = minf(d._max_speed, d._base_speed * d._cut_x * pf * bit_factor / maxf(h_cut, d._air_floor)) * d.speed_scale
	var width: float = float(d.cols) * d.cell_m
	var px: float = d._px
	var py: float = d._py
	var nx: float = clampf(px + d.speed_m_s * s * d.side_scale * Sim.DT, 0.0, width - d.ship_size.x)
	var ny: float = py + d.speed_m_s * co * Sim.DT
	d.at_wall = absf(d.heading_deg) > d._wall_deg and ((s > 0.0 and nx >= width - d.ship_size.x - DrillSim.EPS) or (s < 0.0 and nx <= DrillSim.EPS))
	var moved: float = sqrt((nx - px) * (nx - px) + (ny - py) * (ny - py))
	d._px = nx
	d._py = ny
	d.ship_pos = Vector2(nx, ny)
	d.distance_m += moved
	advance_footprint(sim, d)
	d.cutting = h_cut > 0.0
	if not d.cutting:
		return
	var joules: int = roundi(d._heat_kw_per_bar * float(bars) * h_cut * 1000.0 * Sim.DT)
	if joules > 0 and d.drill_room >= 0:
		sim.hazards.add_heat(sim.ship.rooms[d.drill_room], joules)
		d.heat_added_j += joules
	var noise: float = d._noise_k * moved * pf * pf * h_cut  # Grinding through hard rock is louder.
	d.noise_segment += noise
	d.noise_total += noise
	if not d.bit_broken:
		d.bit_wear = minf(1.0, d.bit_wear + d._wear_k * d._wear_x * moved * h_cut)
		if d.bit_wear >= 1.0:
			d.bit_broken = true
			if not d._bit_broken_said:
				d._bit_broken_said = true
				sim.emit("bit_broken", {"segment": d.segment_id})


## Cut every cell the footprint newly overlaps (only when the covered cell rectangle changes).
static func advance_footprint(sim: Sim, d: DrillSim) -> void:
	var oc0: int = d._c0
	var oc1: int = d._c1
	var or0: int = d._r0
	var or1: int = d._r1
	d._set_footprint()
	if d._c0 == oc0 and d._c1 == oc1 and d._r0 == or0 and d._r1 == or1:
		return
	var cols: int = d.cols
	for r: int in range(d._r0, d._r1 + 1):
		var row: int = r * cols
		var in_old_row: bool = r >= or0 and r <= or1
		for c: int in range(d._c0, d._c1 + 1):
			if in_old_row and c >= oc0 and c <= oc1:
				continue
			if d.grid[row + c] != 0:
				cut(sim, d, row + c, DrillMiner.CUT_DRILL)
	flush_yields(sim, d, snappedf(d._px + d.ship_size.x * 0.5, 0.01), snappedf(d._py + d.ship_size.y, 0.01))
	d._band_dirty = true


## Cut cell i (not air) by a cutter: the drill's crown (DrillMiner.CUT_DRILL) or the away miner
## (CUT_MINER). Both book the cell the same way (take_cell); the miner's pocket, strain and noise
## effects are its own (DrillMiner.on_cut). Blasts call take_cell directly.
static func cut(sim: Sim, d: DrillSim, i: int, cutter: int) -> void:
	var m: int = take_cell(d, i, cutter)
	if cutter == DrillMiner.CUT_MINER:
		d.miner.on_cut(sim, d, i, m)
		return
	if d.unstable_of[m] == 1:
		d.verbs.strain += 1
	if d.water_of[m] == 1:
		if d.burst_marks[i] == 0:
			d.verbs.burst_pocket(sim, d, i, d.drill_room)
		if d.drill_room >= 0:
			var put: int = sim.hazards.add_water(sim.ship.rooms[d.drill_room], d.water_cell_ml)
			d.water_in_ml += put
			d.lost_water_ml += d.water_cell_ml - put
		else:
			d.lost_water_ml += d.water_cell_ml
	elif d.gas_of[m] == 1 and d.burst_marks[i] == 0:
		d.verbs.burst_gas(sim, d, i, d.drill_room, Vector2(d._px + d.ship_size.x * 0.5, d._py + d.ship_size.y))


## Turn cell i into air and book it: mined, its chunk's change counter, and its yield (pending until
## the next flush_yields; for the miner, into its haul). Returns the material code it had. Pocket and
## strain effects are the caller's (cut, or a blast).
static func take_cell(d: DrillSim, i: int, cutter: int) -> int:
	var m: int = d.grid[i]
	if d.structure_marks[i] == StructureStamp.MARK_INTERIOR:
		d.structures.note(d, i, m, cutter == DrillMiner.CUT_MINER)
	d.grid[i] = 0
	d.mined[m] += 1
	var cols: int = d.cols
	d.chunk_changes[((i / cols) / DrillSim.CHUNK_CELLS) * d.chunk_cols + (i % cols) / DrillSim.CHUNK_CELLS] += 1
	if cutter == DrillMiner.CUT_MINER:
		d.miner.book(d, m)
	elif d.yield_res_of[m] >= 0:
		if d._pend_amt[m] == 0:
			d._pend_codes[d._pend_n] = m
			d._pend_n += 1
		d._pend_amt[m] += d.yield_amount_of[m]
	d._band_dirty = true
	return m


## Pay what was cut since the last flush: one exact run.add and one "mined" event per material, at
## (x, y) in segment meters (the crown, or a blast point).
static func flush_yields(sim: Sim, d: DrillSim, x: float, y: float) -> void:
	if d._pend_n == 0:
		return
	for k: int in range(d._pend_n):
		var m: int = d._pend_codes[k]
		var ri: int = d.yield_res_of[m]
		if d._pend_amt[m] <= 0:  # A blast's shattered share can round a small yield down to nothing.
			continue
		var got: int = sim.run.add(sim, RunState.RESOURCES[ri], d._pend_amt[m])
		d._pend_amt[m] = 0
		d.yielded[ri] += got
		d.yield_mat[m] += got
		sim.emit("mined", {"material": str(d.materials[m].get("id", "")), "res": RunState.RESOURCES[ri], "amount": got,
				"x_m": x, "y_m": y})
	d._pend_n = 0


## Keep pct percent of every pending yield, per material, rounded down (a blast shatters the rest).
static func scale_pending(d: DrillSim, pct: int) -> void:
	for k: int in range(d._pend_n):
		var m: int = d._pend_codes[k]
		d._pend_amt[m] = d._pend_amt[m] * pct / 100


## Sum the hardness of the cells just beyond the footprint: below it and on each side.
static func compute_band(d: DrillSim) -> void:
	d._band_dirty = false
	var grid: PackedByteArray = d.grid  # Read only here: locals for the loops.
	var hardness_of: PackedFloat64Array = d.hardness_of
	var cols: int = d.cols
	var band: int = d._band
	var c0: int = d._c0
	var c1: int = d._c1
	var r0: int = d._r0
	var r1: int = d._r1
	var bb_sum: float = 0.0
	var bb_n: int = 0
	var bl_sum: float = 0.0
	var bl_n: int = 0
	var br_sum: float = 0.0
	var br_n: int = 0
	for r: int in range(r1 + 1, mini(d.rows, r1 + 1 + band)):
		var row: int = r * cols
		for c: int in range(c0, c1 + 1):
			bb_sum += hardness_of[grid[row + c]]
			bb_n += 1
	for r: int in range(r0, r1 + 1):
		var row2: int = r * cols
		for c: int in range(maxi(0, c0 - band), c0):
			bl_sum += hardness_of[grid[row2 + c]]
			bl_n += 1
		for c: int in range(c1 + 1, mini(cols, c1 + 1 + band)):
			br_sum += hardness_of[grid[row2 + c]]
			br_n += 1
	d._bb_sum = bb_sum
	d._bb_n = bb_n
	d._bl_sum = bl_sum
	d._bl_n = bl_n
	d._br_sum = br_sum
	d._br_n = br_n
