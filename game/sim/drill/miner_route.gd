class_name MinerRoute
extends RefCounted
## Where the away miner (DrillMiner) may go and the tunnel it digs there. Static and read-only: the
## sim, the view's aim circle and the bots all use the same rules.

## "" when crew_id may be sent to point (segment meters) now, else why not: "no_segment" (no drilling
## segment under way, or no drill room), "miner_out", "no_crew" (unknown, dead, away or unable to
## reach the drill room), "outside" (off the grid, above the ship's top edge, inside the ship's
## footprint, or no rock under the ship), "range" (beyond range_m of the drill head).
static func why_not(d: DrillSim, sim: Sim, p_crew_id: String, point: Vector2) -> String:
	if not d.active or sim.run.phase != "drill" or d.drill_room < 0:
		return "no_segment"
	if d.miner.active:
		return "miner_out"
	var c: CrewMember = sim.ship.crew_by_id(p_crew_id)
	if c == null or not c.alive or c.away:
		return "no_crew"
	if c.room != d.drill_room and sim.ship.nav.route(sim.ship, c.room, d.drill_room, 0.0).is_empty():
		return "no_crew"
	if not geometry_ok(d, point):
		return "outside"
	if point.distance_to(head(d)) > d.miner.range_m:
		return "range"
	return ""


## The drill head: the ship's bottom centre, segment meters.
static func head(d: DrillSim) -> Vector2:
	return Vector2(d.ship_pos.x + d.ship_size.x * 0.5, d.ship_pos.y + d.ship_size.y)


## [c0, c1, r0, r1] of the cells the ship footprint overlaps (DrillSim's own rule).
static func footprint(d: DrillSim) -> PackedInt32Array:
	var e: float = DrillSim.EPS
	return PackedInt32Array([clampi(floori(d.ship_pos.x / d.cell_m + e), 0, d.cols - 1),
		clampi(ceili((d.ship_pos.x + d.ship_size.x) / d.cell_m - e) - 1, 0, d.cols - 1),
		clampi(floori(d.ship_pos.y / d.cell_m + e), 0, d.rows - 1),
		clampi(ceili((d.ship_pos.y + d.ship_size.y) / d.cell_m - e) - 1, 0, d.rows - 1)])


## Inside the grid, below the ship's top edge, not in the ship's footprint, with rock under the ship.
static func geometry_ok(d: DrillSim, p: Vector2) -> bool:
	var w: float = float(d.cols) * d.cell_m
	var h: float = float(d.rows) * d.cell_m
	if p.x < 0.0 or p.y < 0.0 or p.x >= w or p.y >= h or p.y <= d.ship_pos.y:
		return false
	var fp: PackedInt32Array = footprint(d)
	if fp[3] + 1 >= d.rows:
		return false
	var c: int = floori(p.x / d.cell_m)
	var r: int = floori(p.y / d.cell_m)
	return not (c >= fp[0] and c <= fp[1] and r >= fp[2] and r <= fp[3])


## The tunnel to point p from where the ship stands now: a 4-connected line of cells from the cell
## under the head to p's cell. Ties step down first. A target level with the hull goes along the row
## under the ship, then straight up beside it.
static func plan(d: DrillSim, p: Vector2) -> PackedInt32Array:
	var fp: PackedInt32Array = footprint(d)
	var hp: Vector2 = head(d)
	var c: int = clampi(floori(hp.x / d.cell_m), 0, d.cols - 1)
	var r: int = mini(fp[3] + 1, d.rows - 1)
	var tc: int = clampi(floori(p.x / d.cell_m), 0, d.cols - 1)
	var tr: int = clampi(floori(p.y / d.cell_m), 0, d.rows - 1)
	var route := PackedInt32Array([r * d.cols + c])
	var sx: int = signi(tc - c)
	var sy: int = signi(tr - r)
	if tr <= fp[3]:
		while c != tc:
			c += sx
			route.append(r * d.cols + c)
		while r != tr:
			r += sy
			route.append(r * d.cols + c)
		return route
	var dc: int = absi(tc - c)
	var dr: int = absi(tr - r)
	var ix: int = 0
	var iy: int = 0
	while ix < dc or iy < dr:
		if iy >= dr or (ix < dc and (1 + 2 * ix) * dr < (1 + 2 * iy) * dc):
			ix += 1
			c += sx
		else:
			iy += 1
			r += sy
		route.append(r * d.cols + c)
	return route
