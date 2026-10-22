class_name MinerDig
extends RefCounted
## The away miner's tunnel, vein and walk home, split out of DrillMiner (M1d): planning the route,
## stepping cell by cell (dig, vein, return) and climbing back in. Static: every function works on the
## DrillMiner and DrillSim passed in (the state stays on the DrillMiner, so its state() is unchanged)
## and holds no reference to either.


static func plan(m: DrillMiner, d: DrillSim) -> void:
	m._route = MinerRoute.plan(d, m.target)
	m._route_i = 0


static func next_dig(m: DrillMiner, d: DrillSim) -> void:
	if m._route_i < m._route.size():
		start_step(m, d, m._route[m._route_i], m._at)
		m._route_i += 1
		m._set_phase(d, "dig")
		return
	if not m._vein_ok or m._vein_max <= 0:
		turn_back(m, d)
		return
	m._set_phase(d, "vein")
	m._seen = PackedByteArray()
	m._seen.resize(d.grid.size())
	m._seen[m._cells[m._at]] = 1
	queue_around(m, d, m._at)
	next_vein(m, d)


static func next_vein(m: DrillMiner, d: DrillSim) -> void:
	while m._vq_i < m._vq.size() and m._vein_n < m._vein_max:
		var i: int = m._vq[m._vq_i]
		var par: int = m._vq_par[m._vq_i]
		m._vq_i += 1
		var mat: int = d.grid[i]
		if mat != 0 and d.yield_res_of[mat] >= 0:
			m._vein_n += 1
			start_step(m, d, i, par)
			return
	turn_back(m, d)


## Queue the unseen ore and gem neighbours of _cells[k], in cell index order (up, left, right, down).
static func queue_around(m: DrillMiner, d: DrillSim, k: int) -> void:
	var i: int = m._cells[k]
	var r: int = i / d.cols
	var c: int = i % d.cols
	var nbs := PackedInt32Array([i - d.cols if r > 0 else -1, i - 1 if c > 0 else -1,
			i + 1 if c < d.cols - 1 else -1, i + d.cols if r < d.rows - 1 else -1])
	for j: int in nbs:
		if j >= 0 and m._seen[j] == 0 and d.grid[j] != 0 and d.yield_res_of[d.grid[j]] >= 0:
			m._seen[j] = 1
			m._vq.append(j)
			m._vq_par.append(k)


static func start_step(m: DrillMiner, d: DrillSim, cell: int, parent: int) -> void:
	m.next_cell = cell
	m._step_par = parent
	var mat: int = d.grid[cell]
	if mat == 0:
		m._set_action(maxi(1, roundi(d.cell_m / m._walk * Sim.TICK_HZ)))
	else:
		var h: float = float(d.materials[mat].get("hardness", 1.0))
		m._set_action(maxi(1, roundi((m._dig_base + m._dig_hard * h) * Sim.TICK_HZ)))


## The walk or dig into next_cell is done: cut it if it is still rock, then stand in it.
static func finish_step(sim: Sim, m: DrillMiner, d: DrillSim) -> void:
	var cell: int = m.next_cell
	m.next_cell = -1
	var mat: int = d.grid[cell]
	if m.phase == "dig" and m._route_i >= m._route.size():
		m._vein_ok = mat != 0 and d.yield_res_of[mat] >= 0
	if mat != 0:
		d.cut(sim, cell, DrillMiner.CUT_MINER)
		if not m.active:
			return
	m._cells.append(cell)
	m._par.append(m._step_par)
	m._at = m._cells.size() - 1
	m.pos = feet(d, cell)
	if m.phase == "vein":
		queue_around(m, d, m._at)


static func turn_back(m: DrillMiner, d: DrillSim) -> void:
	m.next_cell = -1
	m._set_phase(d, "return")
	next_back(m, d)


static func next_back(m: DrillMiner, d: DrillSim) -> void:
	if m._at < 0:
		start_enter(m, d, m._hatch_ticks)
		return
	m.next_cell = m._cells[m._par[m._at]] if m._par[m._at] >= 0 else -1
	m._set_action(maxi(1, roundi(d.cell_m / m._walk * Sim.TICK_HZ)))


static func start_enter(m: DrillMiner, d: DrillSim, ticks: int) -> void:
	m.next_cell = -1
	m.pos = MinerRoute.hatch(d, m.target)
	m._set_phase(d, "enter")
	m._set_action(ticks)


static func feet(d: DrillSim, cell: int) -> Vector2:
	return Vector2((float(cell % d.cols) + 0.5) * d.cell_m, float(cell / d.cols + 1) * d.cell_m)
