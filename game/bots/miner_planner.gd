class_name MinerPlanner
extends RefCounted
## When and where a policy bot sends the away miner (DrillMiner), and whom. Static and read-only: it
## reads the rock grid and the crew, never changes the sim, no randomness; ties go to the first cell in
## row-major order and the first crew member in ship order.
## - target: the best cluster of ore and gem cells within the miner's range of the drill head, at least
##   off_line_m sideways of the ship's centre line and not on the drill's own lane below the crown
##   (the drill gets those anyway), worth at least min_value (ore units x value_ore, gem units x
##   value_gem, the cluster counted up to vein_max_cells). Its tunnel (MinerRoute.plan) must cross no
##   water or gas pocket and fewer fault cells than one rockfall takes. The aim point is the cluster
##   cell nearest the head. Returns {"x_m", "y_m", "value"} or {}.
## - decide: what a policy bot does about its miner this decision ({} nothing, or the command): with
##   a miner out (boarding, climbing out, digging), recall when the pursuer's front is within
##   miner_recall_rows of the ship or the miner is below miner_recall_hp; with none out (once a second),
##   send one when the front is at least miner_rows behind, the hull above half, no fire aboard, and a
##   crew member and a target qualify.
## - crew: the crew member whose absence costs least: alive, aboard, not fighting a fire, patching or
##   repairing; not the one stationed at the helm while another is free; then the shortest walk to the
##   drill room. "" when nobody fits or fewer than two are alive.


static func decide(sim: Sim, b: PolicyBot) -> Dictionary:
	var d: DrillSim = sim.drill
	var m: DrillMiner = d.miner
	var run: RunState = sim.run
	var gap: float = run.ship_row_f(sim) - run.pursuer_row
	if m.active:
		if m.phase == "board" or m.phase == "exit" or m.phase == "dig" or m.phase == "vein":
			var c: CrewMember = sim.ship.crew_by_id(m.crew_id)
			if gap < b.miner_recall_rows or (c != null and c.hp < b.miner_recall_hp):
				return {"type": "recall_miner"}
		return {}
	if not b.miner_on or sim.tick < b.miner_next_tick or not d.active or run.phase != "drill":
		return {}
	b.miner_next_tick = sim.tick + Sim.TICK_HZ
	if gap < b.miner_rows or run.get_res("hull") * 2 <= sim.ship.hull_max:
		return {}
	for r: Room in sim.ship.rooms:
		if r.fire > 0.0:
			return {}
	var who: String = crew(sim, d)
	if who.is_empty():
		return {}
	var t: Dictionary = target(sim, d, b.miner_value_ore, b.miner_value_gem, b.miner_min_value, b.miner_off_line_m)
	if t.is_empty():
		return {}
	return {"type": "send_miner", "crew": who, "x_m": float(t["x_m"]), "y_m": float(t["y_m"])}


static func target(sim: Sim, d: DrillSim, value_ore: float, value_gem: float, min_value: float,
		off_line_m: float) -> Dictionary:
	var cell: float = d.cell_m
	var range_m: float = d.miner.range_m - cell
	var head: Vector2 = MinerRoute.head(d)
	var fp: PackedInt32Array = MinerRoute.footprint(d)
	var centre_x: float = d.ship_pos.x + d.ship_size.x * 0.5
	var vein_max: int = maxi(1, roundi(sim.db.tune("miner.vein_max_cells")))
	var strain_max: int = maxi(1, roundi(sim.db.tune("miner.strain_cells")))
	var ore_i: int = RunState.RESOURCES.find("ore")
	var c_lo: int = maxi(0, floori((head.x - range_m) / cell))
	var c_hi: int = mini(d.cols - 1, floori((head.x + range_m) / cell))
	var r_lo: int = maxi(fp[2], floori((head.y - range_m) / cell))
	var r_hi: int = mini(d.rows - 1, floori((head.y + range_m) / cell))
	var seen := PackedByteArray()
	seen.resize(d.grid.size())
	var best: Dictionary = {}
	var best_v: float = min_value - 0.000001
	for r: int in range(r_lo, r_hi + 1):
		for c: int in range(c_lo, c_hi + 1):
			var i: int = r * d.cols + c
			if seen[i] == 1 or d.grid[i] == 0 or d.yield_res_of[d.grid[i]] < 0:
				continue
			# One cluster: breadth first over ore and gem cells (the miner's own vein rule), capped.
			var queue := PackedInt32Array([i])
			seen[i] = 1
			var k: int = 0
			var v: float = 0.0
			var aim: int = -1
			var aim_d: float = INF
			while k < queue.size():
				var j: int = queue[k]
				k += 1
				var m: int = d.grid[j]
				if k <= vein_max:
					v += float(d.yield_amount_of[m]) * (value_ore if d.yield_res_of[m] == ore_i else value_gem)
				var jr: int = j / d.cols
				var jc: int = j % d.cols
				var p := Vector2((float(jc) + 0.5) * cell, (float(jr) + 0.5) * cell)
				var on_lane: bool = jc >= fp[0] and jc <= fp[1] and jr > fp[3]
				if not on_lane and absf(p.x - centre_x) >= off_line_m and p.distance_to(head) <= range_m \
						and MinerRoute.geometry_ok(d, p) and p.distance_to(head) < aim_d:
					aim_d = p.distance_to(head)
					aim = j
				var nbs := PackedInt32Array([j - d.cols if jr > 0 else -1, j - 1 if jc > 0 else -1,
						j + 1 if jc < d.cols - 1 else -1, j + d.cols if jr < d.rows - 1 else -1])
				for n: int in nbs:
					if n >= 0 and seen[n] == 0 and d.grid[n] != 0 and d.yield_res_of[d.grid[n]] >= 0:
						seen[n] = 1
						queue.append(n)
			if aim < 0 or v <= best_v:
				continue
			var at := Vector2((float(aim % d.cols) + 0.5) * cell, (float(aim / d.cols) + 0.5) * cell)
			if not _route_safe(d, at, strain_max):
				continue
			best_v = v
			best = {"x_m": at.x, "y_m": at.y, "value": v}
	return best


## The tunnel to p crosses no water or gas pocket and fewer fault cells than one rockfall takes.
static func _route_safe(d: DrillSim, p: Vector2, strain_max: int) -> bool:
	var faults: int = 0
	for i: int in MinerRoute.plan(d, p):
		var m: int = d.grid[i]
		if d.water_of[m] == 1 or d.gas_of[m] == 1:
			return false
		faults += d.unstable_of[m]
	return faults < strain_max


static func crew(sim: Sim, d: DrillSim) -> String:
	var ship: Ship = sim.ship
	var helm: int = ship.room_with_system("helm")
	var alive: int = 0
	var free := PackedInt32Array()
	for c: CrewMember in ship.crew:
		if not c.alive:
			continue
		alive += 1
		if c.away or c.job_kind == "extinguish" or c.job_kind == "patch" or c.job_kind == "repair":
			continue
		if MinerRoute.why_not(d, sim, c.id, MinerRoute.head(d) + Vector2(0.0, 1.0)) == "no_crew":
			continue
		free.append(c.index)
	if alive < 2 or free.is_empty():
		return ""
	var pick: int = -1
	var pick_t: float = INF
	for pass_i: int in range(2):
		for ci: int in free:
			var c: CrewMember = ship.crew[ci]
			if pass_i == 0 and helm >= 0 and c.start_room == helm:
				continue
			var t: float = sim.crew_ai.travel_time(ship, c, d.drill_room)
			if t >= 0.0 and t < pick_t:
				pick_t = t
				pick = ci
		if pick >= 0:
			break
	return ship.crew[pick].id if pick >= 0 else ""
