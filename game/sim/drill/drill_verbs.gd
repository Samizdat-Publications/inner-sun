class_name DrillVerbs
extends RefCounted
## The drill's pocket hazards and dig verbs, owned by a DrillSim (DrillSim.verbs). Holds its tuning
## and state, never the DrillSim or the Sim: both are passed in, so nothing here forms a cycle.
##
## - Water and gas pockets (moved here from DrillSim): the first cut cell of a pocket bursts it (a
##   breach in the drill room, or a fire there), and the connected pocket is marked so it bursts once.
## - Fault rock: every unstable cell the drill cuts adds 1 to `strain`. At rockfall_strain_cells a
##   rockfall is scheduled rockfall_warn_s later and strain drops by the threshold (one rockfall is
##   pending at a time; strain past the next threshold schedules the next one when it lands). On
##   impact a bracing layer soaks it (Systems.absorb_hit); otherwise the run loses rockfall_hull_pts
##   hull (run mode only) and one top-deck room (the smallest rect y, picked with the stream
##   "drill/rockfall") takes rockfall_sys_bars of damage. A run killed by it ends with cause "rockfall".
## - Blast: the charge launcher fires a charge into the rock (fire_blast; blast_ready says why not).
##   It spends one charge at once and goes off blast_fuse_s later: every non-air cell whose centre is
##   within blast_radius_m is cut (counted in mined; blast_yield_pct of each material's yield is paid,
##   rounded down, the rest shatters (D039); "mined" events at the blast point), a water pocket cell drains its whole connected pocket (cells become air, no water enters
##   the ship; counted in mined and in drained_cells), a gas pocket cell burns off its whole pocket
##   (and lights the drill room like a gas burst only when the blast is within blast_fire_m of the
##   ship). Blasts make blast_noise and no strain. A blast still in flight when the segment ends goes
##   off at arrival.
##
## Events: "pocket_burst" {"room", "cells"}, "gas_burst" {"room", "cells", "x_m", "y_m"},
## "rockfall_warn" {"in_s"}, "rockfall" {"absorbed", "room", "hull"}, "blast_fired" {"x_m", "y_m",
## "from_x_m", "from_y_m", "fuse_s"}, "blast" {"x_m", "y_m", "cells", "yield", "ore", "gems",
## "drained", "burned"}, "bad_command" {"type": "blast", "why"}.

# Read-only for the view.
var strain: int = 0  ## Unstable cells cut toward the next rockfall (this segment).
var rockfall_ticks: int = 0  ## Ticks until the scheduled rockfall lands (0: none scheduled).
var rockfalls: int = 0  ## Rockfalls this segment.
var blast_pending: bool = false  ## A charge is in flight.
var blast_point: Vector2 = Vector2.ZERO  ## Where it goes off (segment meters).
var blast_from: Vector2 = Vector2.ZERO  ## Where it was fired from (the crown).
var blast_fuse_ticks: int = 0
var blast_cooldown_ticks: int = 0
var blast_cooldown_left_s: float = 0.0
var blasts: int = 0  ## Blasts set off this segment.
var drained_cells: int = 0  ## Water pocket cells drained by blasts this segment (in mined, no water).

var _weapons: Dictionary = {}  ## The weapons table (data), to find the charge launcher.
var _strain_max: int = 80
var _warn_ticks: int = 72
var _rf_hull: int = 1
var _rf_bars: float = 0.5
var _cool_ticks: int = 300
var _range: float = 14.0
var _fuse_ticks: int = 36
var _radius: float = 1.75
var _fire_m: float = 3.0
var _noise: float = 15.0
var _yield_pct: int = 100  ## Share of a blast's yield that survives (blast_yield_pct).
var _breach_m2: float = 0.0
var _gas_fire: float = 0.3
var _gas_noise: float = 0.0


func _init(db: DataDB) -> void:
	_weapons = db.table("weapons")
	_strain_max = maxi(1, roundi(db.tune("drill.rockfall_strain_cells")))
	_warn_ticks = maxi(1, roundi(db.tune("drill.rockfall_warn_s") * Sim.TICK_HZ))
	_rf_hull = maxi(0, roundi(db.tune("drill.rockfall_hull_pts")))
	_rf_bars = maxf(0.0, db.tune("drill.rockfall_sys_bars"))
	_cool_ticks = maxi(1, roundi(db.tune("drill.blast_cooldown_s") * Sim.TICK_HZ))
	_range = db.tune("drill.blast_range_m")
	_fuse_ticks = maxi(1, roundi(db.tune("drill.blast_fuse_s") * Sim.TICK_HZ))
	_radius = db.tune("drill.blast_radius_m")
	_fire_m = db.tune("drill.blast_fire_m")
	_noise = db.tune("drill.blast_noise")
	_yield_pct = clampi(roundi(db.tune("drill.blast_yield_pct")), 0, 100)
	_breach_m2 = db.tune("drill.pocket_breach_m2")
	_gas_fire = db.tune("drill.gas_fire_level")
	_gas_noise = db.tune("drill.gas_noise")


func begin_segment() -> void:
	strain = 0
	rockfall_ticks = 0
	rockfalls = 0
	blast_pending = false
	blast_fuse_ticks = 0
	blasts = 0
	drained_cells = 0


## Every world tick (any phase where the world runs): the launcher reloads.
func tick_cooldown() -> void:
	if blast_cooldown_ticks > 0:
		blast_cooldown_ticks -= 1
		blast_cooldown_left_s = float(blast_cooldown_ticks) / Sim.TICK_HZ


## Every drilling tick, after the ship moved: the fuse, the rockfall timer, new rockfalls.
func step(sim: Sim, d: DrillSim) -> void:
	if blast_pending:
		blast_fuse_ticks -= 1
		if blast_fuse_ticks <= 0:
			detonate(sim, d)
	if rockfall_ticks > 0:
		rockfall_ticks -= 1
		if rockfall_ticks == 0:
			_rockfall(sim)
	if rockfall_ticks == 0 and strain >= _strain_max and not sim.run.is_over():
		strain -= _strain_max
		rockfall_ticks = _warn_ticks
		sim.emit("rockfall_warn", {"in_s": snappedf(float(_warn_ticks) / Sim.TICK_HZ, 0.01)})


## The segment ended: a charge in flight goes off now, a rockfall still to come is dropped.
func end_segment(sim: Sim, d: DrillSim) -> void:
	if blast_pending:
		detonate(sim, d)
	rockfall_ticks = 0


# Pockets ---------------------------------------------------------------------------------------

## The first cut cell of a water pocket bursts it: a small breach in the drill room, and the whole
## connected pocket is marked so it bursts only once.
func burst_pocket(sim: Sim, d: DrillSim, start: int, drill_room: int) -> void:
	var cells: int = DrillMaterials.flood(d.grid, d.cols, d.rows, start, d.water_of, d.burst_marks)
	d.pockets_burst += 1
	var room_id: String = ""
	if drill_room >= 0:
		var room: Room = sim.ship.rooms[drill_room]
		room.breach_m2 += _breach_m2
		room_id = room.id
	sim.emit("pocket_burst", {"room": room_id, "cells": cells})


## The first cut cell of a gas pocket ignites it: a fire in the drill room (or a hotter one), a burst
## of noise, and the whole connected pocket is marked so it ignites only once.
func burst_gas(sim: Sim, d: DrillSim, start: int, drill_room: int, at: Vector2) -> void:
	var cells: int = DrillMaterials.flood(d.grid, d.cols, d.rows, start, d.gas_of, d.burst_marks)
	_gas_in_ship(sim, d, cells, drill_room, at)


func _gas_in_ship(sim: Sim, d: DrillSim, cells: int, drill_room: int, at: Vector2) -> void:
	d.gas_bursts += 1
	d.noise_segment += _gas_noise
	d.noise_total += _gas_noise
	var room_id: String = ""
	if drill_room >= 0:
		var room: Room = sim.ship.rooms[drill_room]
		sim.hazards.ignite(sim, sim.player, room, _gas_fire)
		room_id = room.id
	sim.emit("gas_burst", {"room": room_id, "cells": cells, "x_m": snappedf(at.x, 0.01), "y_m": snappedf(at.y, 0.01)})


# Rockfalls -------------------------------------------------------------------------------------

func _rockfall(sim: Sim) -> void:
	rockfalls += 1
	var absorbed: bool = sim.systems.absorb_hit(sim, sim.player)
	var room_id: String = ""
	var lost: int = 0
	if not absorbed:
		if sim.run.mode == "run" and _rf_hull > 0:
			lost = -sim.run.add(sim, "hull", -_rf_hull)
		var ri: int = _top_room(sim)
		if ri >= 0:
			room_id = sim.ship.rooms[ri].id
			sim.systems.damage_room(sim, sim.player, ri, _rf_bars)
	sim.emit("rockfall", {"absorbed": absorbed, "room": room_id, "hull": lost})
	if lost > 0 and sim.run.mode == "run" and sim.run.get_res("hull") <= 0:
		sim.run.end_run(sim, "dead", "rockfall")


## One of the rooms on the top deck (smallest rect y), picked with the stream "drill/rockfall".
func _top_room(sim: Sim) -> int:
	var rooms: Array[Room] = sim.ship.rooms
	if rooms.is_empty():
		return -1
	var top: float = INF
	for r: Room in rooms:
		top = minf(top, r.rect.position.y)
	var picks := PackedInt32Array()
	for r: Room in rooms:
		if r.rect.position.y <= top + 0.0001:
			picks.append(r.index)
	var rng: RandomNumberGenerator = sim.rng.get_stream("drill/rockfall")
	return picks[rng.randi_range(0, picks.size() - 1)]


# Blasts ----------------------------------------------------------------------------------------

## The first mounted weapon of kind "charge" (its data), or {} when the ship carries none.
func launcher(sim: Sim) -> Dictionary:
	for wid: String in sim.ship.weapons:
		var w: Dictionary = _weapons.get(wid, {})
		if str(w.get("kind", "")) == "charge":
			return w
	return {}


## "" when a blast may be fired now, else the reason: "not drilling", "no launcher", "no charges",
## "power weapons", "reloading". The aim point has its own check ("out of range", fire_blast).
func blast_ready(sim: Sim, d: DrillSim) -> String:
	if not d.active or sim.run.phase != "drill":
		return "not drilling"
	var w: Dictionary = launcher(sim)
	if w.is_empty():
		return "no launcher"
	if sim.run.mode == "run" and sim.run.get_res(str(w.get("ammo", "charges"))) < 1:
		return "no charges"
	if sim.systems.weapon_bars(sim.player) < int(w.get("power", 1)):
		return "power weapons"
	if blast_pending or blast_cooldown_ticks > 0:
		return "reloading"
	return ""


## "" when the point (segment meters) can be aimed at: inside the grid, outside the ship and within
## blast_range_m of the ship's centre; else "out of range".
func aim_ok(d: DrillSim, p: Vector2) -> String:
	var size := Vector2(float(d.cols) * d.cell_m, float(d.rows) * d.cell_m)
	var ship := Rect2(d.ship_pos, d.ship_size)
	if p.x < 0.0 or p.y < 0.0 or p.x >= size.x or p.y >= size.y or ship.has_point(p) \
			or p.distance_to(ship.get_center()) > _range:
		return "out of range"
	return ""


func fire_blast(sim: Sim, d: DrillSim, p: Vector2) -> bool:
	var why: String = blast_ready(sim, d)
	if why.is_empty():
		why = aim_ok(d, p)
	if not why.is_empty():
		sim.emit("bad_command", {"type": "blast", "why": why})
		return false
	if sim.run.mode == "run":
		sim.run.add(sim, str(launcher(sim).get("ammo", "charges")), -1)
	blast_pending = true
	blast_point = p
	blast_from = Vector2(d.ship_pos.x + d.ship_size.x * 0.5, d.ship_pos.y + d.ship_size.y)
	blast_fuse_ticks = _fuse_ticks
	blast_cooldown_ticks = _cool_ticks
	blast_cooldown_left_s = float(_cool_ticks) / Sim.TICK_HZ
	sim.emit("blast_fired", {"x_m": snappedf(p.x, 0.01), "y_m": snappedf(p.y, 0.01),
			"from_x_m": snappedf(blast_from.x, 0.01), "from_y_m": snappedf(blast_from.y, 0.01),
			"fuse_s": snappedf(float(_fuse_ticks) / Sim.TICK_HZ, 0.01)})
	return true


## Which cells a blast at p clears (centre within the radius): the cell indices, row-major order.
func circle_cells(d: DrillSim, p: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cell: float = d.cell_m
	var c0: int = maxi(0, floori((p.x - _radius) / cell))
	var c1: int = mini(d.cols - 1, floori((p.x + _radius) / cell))
	var r0: int = maxi(0, floori((p.y - _radius) / cell))
	var r1: int = mini(d.rows - 1, floori((p.y + _radius) / cell))
	var r2: float = _radius * _radius
	for r: int in range(r0, r1 + 1):
		var dy: float = (float(r) + 0.5) * cell - p.y
		for c: int in range(c0, c1 + 1):
			var dx: float = (float(c) + 0.5) * cell - p.x
			if dx * dx + dy * dy <= r2:
				out.append(r * d.cols + c)
	return out


func detonate(sim: Sim, d: DrillSim) -> void:
	blast_pending = false
	blast_fuse_ticks = 0
	blasts += 1
	var p: Vector2 = blast_point
	d.flush_yields(sim, snappedf(p.x, 0.01), snappedf(p.y, 0.01))  # Nothing of the drill's own may be scaled.
	var before: PackedInt32Array = d.yield_mat.duplicate()
	var cells: int = 0
	var drained: bool = false
	var burned: bool = false
	var gas_cells: int = 0
	for i: int in circle_cells(d, p):
		var m: int = d.grid[i]
		if m == 0:
			continue
		if d.water_of[m] == 1 or d.gas_of[m] == 1:
			var water: bool = d.water_of[m] == 1
			var pocket: PackedInt32Array = DrillMaterials.flood_cells(d.grid, d.cols, d.rows, i,
					d.water_of if water else d.gas_of)
			for j: int in pocket:
				d.burst_marks[j] = 1
				d.take_cell(j)
			cells += pocket.size()
			if water:
				drained = true
				drained_cells += pocket.size()
			else:
				burned = true
				gas_cells += pocket.size()
		else:
			d.take_cell(i)
			cells += 1
	d.scale_pending(_yield_pct)
	d.flush_yields(sim, snappedf(p.x, 0.01), snappedf(p.y, 0.01))
	d.noise_segment += _noise
	d.noise_total += _noise
	var yields: Dictionary = {}
	var ore: int = 0
	var gems: int = 0
	for code: int in range(1, d.materials.size()):
		var got: int = d.yield_mat[code] - before[code]
		if got > 0:
			yields[str(d.materials[code].get("id", ""))] = got
			var res: String = RunState.RESOURCES[d.yield_res_of[code]]
			if res == "ore":
				ore += got
			elif res == "gems":
				gems += got
	sim.emit("blast", {"x_m": snappedf(p.x, 0.01), "y_m": snappedf(p.y, 0.01), "cells": cells, "yield": yields,
			"ore": ore, "gems": gems, "drained": drained, "burned": burned})
	if burned and _rect_distance(Rect2(d.ship_pos, d.ship_size), p) <= _fire_m:
		_gas_in_ship(sim, d, gas_cells, d.drill_room, p)


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func state() -> Array:
	return [strain, rockfall_ticks, rockfalls, blast_pending, blast_point, blast_from, blast_fuse_ticks,
		blast_cooldown_ticks, blasts, drained_cells]
