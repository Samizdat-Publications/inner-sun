class_name BlastPlanner
extends RefCounted
## Where a policy bot aims the charge launcher while drilling. Static and read-only: it reads the
## rock grid, never changes the sim, no randomness; ties go to the first cell in row-major order.
## - gas_target: the first unburst gas pocket cell on the ship's lane (its columns, below the crown)
##   that lies beyond blast_fire_m of the ship (so burning it off lights nothing aboard) and within
##   range. Blasting it early means the drill never bursts it.
## - loot_target: the aim point (a valuable cell's centre, off the drill's own path) whose blast
##   circle holds the most ore and gems by value (ore units x value_ore, gem units x value_gem),
##   if that is at least min_value. A circle that would burn gas within blast_fire_m of the ship
##   is skipped.
## Both return {"x_m", "y_m", "value"} or {} when there is nothing worth a charge.


static func gas_target(sim: Sim, d: DrillSim, lookahead_m: float) -> Dictionary:
	var cell: float = d.cell_m
	var fire_m: float = sim.db.tune("drill.blast_fire_m")
	var range_m: float = sim.db.tune("drill.blast_range_m")
	var ship := Rect2(d.ship_pos, d.ship_size)
	var centre: Vector2 = ship.get_center()
	var c0: int = clampi(floori(d.ship_pos.x / cell + 0.000001), 0, d.cols - 1)
	var c1: int = clampi(ceili((d.ship_pos.x + d.ship_size.x) / cell - 0.000001) - 1, 0, d.cols - 1)
	var bottom: float = ship.end.y
	var r0: int = clampi(ceili((bottom + fire_m) / cell), 0, d.rows - 1)
	var r1: int = clampi(floori((bottom + lookahead_m) / cell), 0, d.rows - 1)
	for r: int in range(r0, r1 + 1):
		var row: int = r * d.cols
		for c: int in range(c0, c1 + 1):
			var i: int = row + c
			if d.gas_of[d.grid[i]] == 1 and d.burst_marks[i] == 0:
				var p := Vector2((float(c) + 0.5) * cell, (float(r) + 0.5) * cell)
				if p.distance_to(centre) <= range_m - cell:
					return {"x_m": p.x, "y_m": p.y, "value": 0.0}
	return {}


static func loot_target(sim: Sim, d: DrillSim, value_ore: float, value_gem: float, min_value: float) -> Dictionary:
	var cell: float = d.cell_m
	var range_m: float = sim.db.tune("drill.blast_range_m") - cell
	var radius: float = sim.db.tune("drill.blast_radius_m")
	var fire_m: float = sim.db.tune("drill.blast_fire_m")
	var ship := Rect2(d.ship_pos, d.ship_size)
	var centre: Vector2 = ship.get_center()
	var pc0: int = floori(d.ship_pos.x / cell + 0.000001)
	var pc1: int = ceili((d.ship_pos.x + d.ship_size.x) / cell - 0.000001) - 1
	var crown_r: int = floori(ship.end.y / cell)
	var value_of := PackedFloat64Array()
	value_of.resize(DrillSim.MAX_CODES)
	var ore_i: int = RunState.RESOURCES.find("ore")
	for m: int in range(DrillSim.MAX_CODES):
		var yr: int = d.yield_res_of[m]
		if yr >= 0:
			value_of[m] = float(d.yield_amount_of[m]) * (value_ore if yr == ore_i else value_gem)
	var c_lo: int = maxi(0, floori((centre.x - range_m) / cell))
	var c_hi: int = mini(d.cols - 1, floori((centre.x + range_m) / cell))
	var r_lo: int = maxi(0, floori((centre.y - range_m) / cell))
	var r_hi: int = mini(d.rows - 1, floori((centre.y + range_m) / cell))
	var rc: int = ceili(radius / cell)
	var r2: float = radius * radius
	var best: Dictionary = {}
	var best_v: float = min_value - 0.000001
	for r: int in range(r_lo, r_hi + 1):
		var row: int = r * d.cols
		for c: int in range(c_lo, c_hi + 1):
			if ((r + c) & 1) == 1 or value_of[d.grid[row + c]] <= 0.0:
				continue
			if r >= crown_r and c >= pc0 and c <= pc1:
				continue  # On the drill's own path: it gets these anyway.
			var p := Vector2((float(c) + 0.5) * cell, (float(r) + 0.5) * cell)
			if ship.has_point(p) or p.distance_to(centre) > range_m:
				continue
			var v: float = 0.0
			var gas: bool = false
			for rr: int in range(maxi(0, r - rc), mini(d.rows - 1, r + rc) + 1):
				var dy: float = (float(rr) + 0.5) * cell - p.y
				var row2: int = rr * d.cols
				for cc: int in range(maxi(0, c - rc), mini(d.cols - 1, c + rc) + 1):
					var dx: float = (float(cc) + 0.5) * cell - p.x
					if dx * dx + dy * dy <= r2:
						var m: int = d.grid[row2 + cc]
						v += value_of[m]
						if d.gas_of[m] == 1:
							gas = true
			if gas and _rect_distance(ship, p) <= fire_m + radius:
				continue
			if v > best_v:
				best_v = v
				best = {"x_m": p.x, "y_m": p.y, "value": v}
	return best


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)
