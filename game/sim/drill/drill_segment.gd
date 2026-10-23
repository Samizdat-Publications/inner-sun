class_name DrillSegment
extends RefCounted
## Starting and ending a drilling segment, split out of DrillSim (M1d): generating the rock and
## resetting the segment's counters (begin), and arrival (arrive). Static: every function works on the
## DrillSim passed in (its state stays there, so DrillSim.state() is unchanged) and holds no reference
## to it or to the Sim.


## DrillSim.begin_segment: see there.
static func begin(sim: Sim, d: DrillSim, p_segment_id: String, p_depth_m: float, lateral_m: float,
		p_rock_id: String, p_survey: Dictionary) -> bool:
	var db: DataDB = d._db
	var phase: String = sim.run.phase
	if d.active or (phase != "idle" and phase != "scenario"):
		sim.emit("bad_command", {"type": "begin_segment", "why": "not idle (phase %s)" % phase})
		return false
	var table: Dictionary = db.table("rock").get(p_rock_id, {})
	if table.is_empty() or p_segment_id.is_empty():
		sim.emit("bad_command", {"type": "begin_segment", "why": "no rock table \"%s\" or no segment id" % p_rock_id})
		return false
	d._cut_x = sim.run.gear_x("cut_speed_x")
	d._wear_x = sim.run.gear_x("wear_x")
	d._hard_x = sim.run.gear_x("hard_rock_x")
	DrillMaterials.load_into(d, table, d._hard_x, d._hard_min)
	d.segment_id = p_segment_id
	d.rock_id = p_rock_id
	d.survey = RockGen.options_of(p_survey)
	d.ship_size = ship_footprint(sim.ship)
	var cell_m: float = d.cell_m
	var ship_size: Vector2 = d.ship_size
	d.cols = roundi(db.tune("drill.width_m") / cell_m)
	var width: float = float(d.cols) * cell_m
	d.depth_m = maxf(cell_m, p_depth_m)
	var max_lat: float = minf(db.tune("drill.max_lateral_m"), maxf(0.0, width - ship_size.x))
	var lat: float = clampf(lateral_m, -max_lat, max_lat)
	var x0: float = clampf(snappedf(width * 0.5 - lat * 0.5 - ship_size.x * 0.5, cell_m), 0.0, width - ship_size.x)
	var y0: float = snappedf(db.tune("drill.top_air_m"), cell_m)
	d.start_center_x = x0 + ship_size.x * 0.5
	d.start_y = y0
	d.target_y = y0 + ship_size.y + d.depth_m
	d.target_x = clampf(d.start_center_x + lat, ship_size.x * 0.5, width - ship_size.x * 0.5)
	d.rows = ceili((d.target_y + db.tune("drill.bottom_margin_m")) / cell_m)
	var rng: RandomNumberGenerator = sim.rng.get_stream("drill/" + p_segment_id)
	# The layer's ore richness (D060) scales the ore and gem feature counts on top of the survey's;
	# scenarios (no layer) use 1.
	var ore_mult: float = float(sim.run.layer.get("ore_richness_mult", 1.0)) if not sim.run.layer.is_empty() else 1.0
	d.grid = RockGen.generate(table, rng, d.cols, d.rows, cell_m, Rect2(x0, y0, ship_size.x, ship_size.y), d.target_x,
			d.depth_m, sim.run.depth_m, db.tune("drill.shaft_margin_m"), db.tune("drill.top_air_m"), d.survey, ore_mult)
	d.structure_marks = PackedByteArray()
	d.structure_marks.resize(d.grid.size())
	d.structures.begin_segment(sim, d, db.table("structures").get(str(d.survey.get("structure", "")), {}),
			RockGen.codes_of(table), rng, Rect2(x0, y0, ship_size.x, ship_size.y), d._stamp_tune)
	var generated := PackedInt32Array()
	generated.resize(DrillSim.MAX_CODES)
	var grid: PackedByteArray = d.grid  # Read only in this loop.
	for i: int in range(grid.size()):
		generated[grid[i]] += 1
	d.generated = generated
	d.mined = PackedInt32Array()
	d.mined.resize(DrillSim.MAX_CODES)
	d.yielded.fill(0)
	d.yield_mat.fill(0)
	d._pend_amt.fill(0)
	d._pend_n = 0
	d.burst_marks = PackedByteArray()
	d.burst_marks.resize(d.grid.size())
	d.chunk_cols = ceili(float(d.cols) / DrillSim.CHUNK_CELLS)
	d.chunk_rows = ceili(float(d.rows) / DrillSim.CHUNK_CELLS)
	d.chunk_changes = PackedInt32Array()
	d.chunk_changes.resize(d.chunk_cols * d.chunk_rows)
	d._px = x0
	d._py = y0
	d.ship_pos = Vector2(x0, y0)
	d.heading_deg = 0.0
	d.target_heading_deg = 0.0
	d.speed_m_s = 0.0
	d.cutting = false
	d.at_wall = false
	d.parked = false
	d.verbs.begin_segment()
	d.distance_m = 0.0
	d.segment_ticks = 0
	d.noise_segment = 0.0
	d.water_in_ml = 0
	d.lost_water_ml = 0
	d.heat_added_j = 0
	d.pockets_burst = 0
	d.gas_bursts = 0
	d.start_depth_m = sim.run.depth_m
	d._return_phase = phase
	d.drill_room = sim.ship.room_with_system("drill")
	d.water_cell_ml = 0
	if d.drill_room >= 0:
		d.water_cell_ml = roundi(cell_m * cell_m * sim.ship.rooms[d.drill_room].depth_m * Room.ML_PER_M3)
	d._set_footprint()
	d._band_dirty = true
	d.active = true
	d.grid_serial += 1
	sim.emit("segment_begin", {"segment": d.segment_id, "depth_m": d.depth_m, "lateral_m": lat, "rock": d.rock_id})
	sim.run.set_phase(sim, "drill")
	return true


## The ship's bottom edge reached target_y: close the segment and hand the run on.
static func arrive(sim: Sim, d: DrillSim) -> void:
	d.miner.end_segment(sim, d)
	d.verbs.end_segment(sim, d)
	d.structures.resolve(sim, d, false)
	sim.emit("segment_done", DrillReport.segment_done(d))
	d.active = false
	d.speed_m_s = 0.0
	d.cutting = false
	if d._return_phase == "scenario":
		sim.run.set_phase(sim, "scenario")
	elif sim.run.mode == "run":
		sim.run.arrive(sim)  # The run hands the node to its module (or back to idle).
	else:
		sim.run.set_phase(sim, "idle")


static func ship_footprint(ship: Ship) -> Vector2:
	var box := Rect2()
	for i: int in range(ship.rooms.size()):
		box = ship.rooms[i].rect if i == 0 else box.merge(ship.rooms[i].rect)
	return box.end
