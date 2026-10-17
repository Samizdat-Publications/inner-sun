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


## The drill head: the ship's bottom centre, segment meters (range is measured from here).
static func head(d: DrillSim) -> Vector2:
	return Vector2(d.ship_pos.x + d.ship_size.x * 0.5, d.ship_pos.y + d.ship_size.y)


## Which side hatch the miner uses for a target: -1 left, +1 right (the side the target lies on; a
## target straight below goes out the left). Stewart, build 5c: "he should fully exit first", not dig
## the cell under the drill head as if chewing the tower's floor.
static func side_of(d: DrillSim, p: Vector2) -> int:
	return 1 if p.x > head(d).x else -1


## Where the miner stands on climbing out: beside the hull on the target's side, at the bottom deck.
static func hatch(d: DrillSim, p: Vector2) -> Vector2:
	var x: float = d.ship_pos.x - d.cell_m * 0.5 if side_of(d, p) < 0 else d.ship_pos.x + d.ship_size.x + d.cell_m * 0.5
	return Vector2(x, d.ship_pos.y + d.ship_size.y)


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


## The tunnel to point p from where the ship stands now: a 4-connected line of cells that starts in
## the cell beside the hull at its bottom row, on the target's side (the side hatch), and runs to p's
## cell. A target below the ship goes one row down first, so the tunnel never enters the footprint.
## Ties step down first. Off the grid's edge (no room beside the hull), it starts under the head.
static func plan(d: DrillSim, p: Vector2) -> PackedInt32Array:
	var fp: PackedInt32Array = footprint(d)
	var side: int = side_of(d, p)
	var c: int = fp[0] - 1 if side < 0 else fp[1] + 1
	var r: int = fp[3]
	if c < 0 or c >= d.cols:
		c = clampi(floori(head(d).x / d.cell_m), 0, d.cols - 1)
		r = mini(fp[3] + 1, d.rows - 1)
	var tc: int = clampi(floori(p.x / d.cell_m), 0, d.cols - 1)
	var tr: int = clampi(floori(p.y / d.cell_m), 0, d.rows - 1)
	var route := PackedInt32Array([r * d.cols + c])
	if tr > fp[3] and r <= fp[3] and r + 1 < d.rows:
		r += 1
		route.append(r * d.cols + c)
	var sx: int = signi(tc - c)
	var sy: int = signi(tr - r)
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


## What a miner sent to p would bring home, for the view's aim readout (read-only, no state):
## {"ore": n, "gems": n, "hazard": "gas" | "water" | ""}. The vein is DrillMiner's own rule from p's
## cell (yielding cells breadth first, neighbours in index order, up to vein_max cells, yield_pct of
## each), nothing when p's cell yields nothing (they would turn straight back). The hazard is the
## first gas or water pocket cell on the tunnel. Stewart's build 5c run: six sorties brought home 4
## ore and 13 gems, because nothing said which clicks were veins.
static func estimate(d: DrillSim, p: Vector2, vein_max: int, yield_pct: int) -> Dictionary:
	var out: Dictionary = {"ore": 0, "gems": 0, "hazard": ""}
	for i: int in plan(d, p):
		var m0: int = d.grid[i]
		if m0 != 0 and d.burst_marks[i] == 0 and (d.gas_of[m0] == 1 or d.water_of[m0] == 1):
			out["hazard"] = "gas" if d.gas_of[m0] == 1 else "water"
			break
	var c: int = floori(p.x / d.cell_m)
	var r: int = floori(p.y / d.cell_m)
	if c < 0 or r < 0 or c >= d.cols or r >= d.rows:
		return out
	var start: int = r * d.cols + c
	if d.grid[start] == 0 or d.yield_res_of[d.grid[start]] < 0:
		return out
	var ore_i: int = RunState.RESOURCES.find("ore")
	var seen := {start: true}
	var queue := PackedInt32Array([start])
	var k: int = 0
	var ore: int = 0
	var gems: int = 0
	while k < queue.size() and k < vein_max:
		var j: int = queue[k]
		k += 1
		var m: int = d.grid[j]
		var amt: int = d.yield_amount_of[m] * yield_pct / 100
		if d.yield_res_of[m] == ore_i:
			ore += amt
		else:
			gems += amt
		var jr: int = j / d.cols
		var jc: int = j % d.cols
		for n: int in [j - d.cols if jr > 0 else -1, j - 1 if jc > 0 else -1, j + 1 if jc < d.cols - 1 else -1,
				j + d.cols if jr < d.rows - 1 else -1]:
			if n >= 0 and not seen.has(n) and d.grid[n] != 0 and d.yield_res_of[d.grid[n]] >= 0:
				seen[n] = true
				queue.append(n)
	out["ore"] = ore
	out["gems"] = gems
	return out
