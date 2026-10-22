class_name HazardSim
extends RefCounted
## Heat, fire and water, simulated room by room at 10 Hz (like Barotrauma's hulls and gaps, never
## per pixel). Water (millilitres) and heat (joules) are integers: whatever leaves one room arrives
## in another, or is counted in the ship's in/out totals, so conservation tests can demand equality.
## Anything outside this class that adds or removes heat or water goes through add_heat/add_water.
## Holds no reference to the Sim or its ShipWorld; both are passed in.

const TUNING_KEYS: Array[String] = [
	"heat.capacity_kj_per_m3_k", "heat.wall_kw_per_m2_k", "heat.door_kw_per_m2_k",
	"heat.hatch_up_kw_per_m2_k", "heat.hatch_down_kw_per_m2_k", "heat.hull_kw_per_m2_k",
	"heat.breach_hull_factor", "heat.fire_kw", "heat.coolant_kw_per_room", "heat.coolant_target_c",
	"heat.coolant_kw_per_k", "heat.purge_kw_per_k", "heat.purge_draught_factor",
	"fire.start_level", "fire.growth_per_s", "fire.spread_per_s", "fire.spread_up_factor",
	"fire.spread_down_factor", "fire.spread_wall_factor", "fire.spread_closed_factor",
	"fire.autoignite_c", "fire.autoignite_per_s",
	"fire.water_suppress_per_m_s", "fire.crew_dps", "fire.purge_out_per_s", "fire.purge_neighbour_factor",
	"water.breach_cd", "water.gravity", "water.door_flow_per_m2_s", "water.hatch_cd", "water.pump_m3_s",
	"water.crew_head_m", "water.drown_dps",
	"crew.heat_safe_c", "crew.heat_dps_per_k", "crew.heal_per_s",
]

const J_PER_KJ: float = 1000.0

var coolant_on: bool = true
var cooling_scale: float = 1.0  ## Share of full coolant power, set by the Systems module (0 to 1).
var pump_scale: float = 1.0  ## Share of full pump power, set by the Systems module (0 to 1).
var water_in_ml: int = 0
var water_out_ml: int = 0
var energy_in_j: int = 0
var energy_out_j: int = 0
var cooled_j: int = 0  ## Joules removed by the coolant system so far (part of energy_out_j); Systems bills it.
var link_flow_ml_s: PackedFloat64Array = PackedFloat64Array()  ## Last water flow per link, a to b positive (visuals).

var _t: Dictionary = {}
var _adj_from: PackedInt32Array = PackedInt32Array()
var _adj_to: PackedInt32Array = PackedInt32Array()
var _adj_link: PackedInt32Array = PackedInt32Array()
var _adj_factor: PackedFloat64Array = PackedFloat64Array()
var _spread_acc: PackedFloat64Array = PackedFloat64Array()
var _purge: PackedByteArray = PackedByteArray()  ## Per room: 1 while its purge vent is open (L-DOR-02).
var _open_k: PackedFloat64Array = PackedFloat64Array()  ## Per room: kW/K through its open links this step.


func _init(db: DataDB, ship: Ship) -> void:
	for k: String in TUNING_KEYS:
		_t[k] = db.tune(k)
	var cap: float = _k("heat.capacity_kj_per_m3_k") * J_PER_KJ
	for r: Room in ship.rooms:
		r.heat_cap_j_per_k = maxf(1.0, r.capacity_m3() * cap)
		r.set_temp_c(r.start_temp_c)
	link_flow_ml_s.resize(ship.links.size())
	_purge.resize(ship.rooms.size())
	_open_k.resize(ship.rooms.size())
	# Fire paths: each link is one path each way (closed, it passes fire at spread_closed_factor times
	# its own open rate). A wall is a fire path only between rooms with no link: the wall beside a door
	# is not a second, parallel path past it. Walls still carry heat either way.
	for l: Link in ship.links:
		if l.kind == Link.Kind.DOOR:
			_add_adj(l.a, l.b, l.index, 1.0)
			_add_adj(l.b, l.a, l.index, 1.0)
		else:
			_add_adj(l.b, l.a, l.index, _k("fire.spread_up_factor"))
			_add_adj(l.a, l.b, l.index, _k("fire.spread_down_factor"))
	for w: WallPair in ship.walls:
		if _linked(ship, w.a, w.b):
			continue
		_add_adj(w.a, w.b, -1, _k("fire.spread_wall_factor"))
		_add_adj(w.b, w.a, -1, _k("fire.spread_wall_factor"))
	_spread_acc.resize(_adj_from.size())


func _k(key: String) -> float:
	return float(_t[key])


static func _linked(ship: Ship, a: int, b: int) -> bool:
	for l: Link in ship.links:
		if (l.a == a and l.b == b) or (l.a == b and l.b == a):
			return true
	return false


func _add_adj(from: int, to: int, link: int, factor: float) -> void:
	_adj_from.append(from)
	_adj_to.append(to)
	_adj_link.append(link)
	_adj_factor.append(factor)


func step(sim: Sim, world: ShipWorld, dt: float) -> void:
	_heat(world.ship, dt)
	_fire(sim, world, dt)
	_water(world.ship, dt)
	_crew_harm(sim, world, dt)
	_flood_watch(sim, world, dt)


## Start or feed a fire. A room with its purge vent open cannot burn: nothing happens there.
func ignite(sim: Sim, world: ShipWorld, r: Room, level: float) -> void:
	if _purge[r.index] != 0:
		return
	if r.fire <= 0.0:
		r.fire = clampf(level, 0.01, 1.0)
		world.emit(sim, "fire_started", {"room": r.id})
	else:
		r.fire = maxf(r.fire, level)


## Add (positive) or remove (negative) heat from outside the hazard model, keeping the books exact.
func add_heat(r: Room, joules: int) -> void:
	r.energy_j += joules
	if joules >= 0:
		energy_in_j += joules
	else:
		energy_out_j -= joules


## Add water from outside (a burst pocket, an event), clamped to the room's capacity. Returns the
## millilitres that actually went in.
func add_water(r: Room, ml: int) -> int:
	var add: int = clampi(ml, 0, r.capacity_ml - r.water_ml)
	r.water_ml += add
	water_in_ml += add
	return add


func state() -> Array:
	return [water_in_ml, water_out_ml, energy_in_j, energy_out_j, cooled_j, Array(_spread_acc), Array(_purge)]


## True while the room's purge vent is open.
func is_purged(room_index: int) -> bool:
	return _purge[room_index] != 0


## Open or close a room's purge vent (the core "purge" command checks validity first). Opening it
## clears the spread exposure built up into the room, so it cannot ignite the instant it closes.
func set_purge(room_index: int, open: bool) -> void:
	_purge[room_index] = 1 if open else 0
	if open:
		for j: int in range(_adj_to.size()):
			if _adj_to[j] == room_index:
				_spread_acc[j] = 0.0


## Fire paths from one room into another (links and walls), for tests and tools.
func fire_paths(from_room: int, to_room: int) -> int:
	var n: int = 0
	for j: int in range(_adj_from.size()):
		if _adj_from[j] == from_room and _adj_to[j] == to_room:
			n += 1
	return n


## Spread exposure built up so far from one room into another, summed over every path (1.0 ignites).
func spread_exposure(from_room: int, to_room: int) -> float:
	var sum: float = 0.0
	for j: int in range(_adj_from.size()):
		if _adj_from[j] == from_room and _adj_to[j] == to_room:
			sum += _spread_acc[j]
	return sum


## True while any room joined to this one by a door or hatch (open or closed) is burning.
static func linked_fire(ship: Ship, room_index: int) -> bool:
	for l: Link in ship.links:
		if l.a == room_index and ship.rooms[l.b].fire > 0.0:
			return true
		if l.b == room_index and ship.rooms[l.a].fire > 0.0:
			return true
	return false


# Heat ------------------------------------------------------------------------------------------

func _heat(ship: Ship, dt: float) -> void:
	var n: int = ship.rooms.size()
	var temps := PackedFloat64Array()
	temps.resize(n)
	for i: int in range(n):
		temps[i] = ship.rooms[i].temp_c()
	var delta := PackedInt64Array()
	delta.resize(n)
	var per_j: float = J_PER_KJ * dt
	_open_k.fill(0.0)
	for w: WallPair in ship.walls:
		var q: int = roundi(_k("heat.wall_kw_per_m2_k") * w.area_m2 * (temps[w.a] - temps[w.b]) * per_j)
		delta[w.a] -= q
		delta[w.b] += q
	for l: Link in ship.links:
		if not l.open:
			continue
		var k: float = _k("heat.door_kw_per_m2_k")
		if l.kind == Link.Kind.HATCH:
			# Hot air rises: a hatch passes heat upward far better than downward.
			k = _k("heat.hatch_up_kw_per_m2_k") if temps[l.b] > temps[l.a] else _k("heat.hatch_down_kw_per_m2_k")
		var ka: float = k * l.area_m2()
		_open_k[l.a] += ka
		_open_k[l.b] += ka
		var q2: int = roundi(ka * (temps[l.a] - temps[l.b]) * per_j)
		delta[l.a] -= q2
		delta[l.b] += q2
	for i: int in range(n):
		var r: Room = ship.rooms[i]
		var hull_k: float = _k("heat.hull_kw_per_m2_k") * (r.hull_area_m2 + r.breach_m2 * _k("heat.breach_hull_factor"))
		if _purge[i] != 0:
			# An open purge vent joins the room to the bore: its own conductance, plus a draught through
			# every open door or hatch of the room (bore gas is drawn in as fast as they let air out).
			# Booked inside the one rounded q_rock, so the joules stay exact.
			hull_k += _k("heat.purge_kw_per_k") + _k("heat.purge_draught_factor") * _open_k[i]
		var q_rock: int = roundi(hull_k * (ship.rock_temp_c - temps[i]) * per_j)
		var q_fire: int = roundi(_k("heat.fire_kw") * r.fire * per_j)
		var q_cool: int = 0
		var target: float = _k("heat.coolant_target_c")
		if coolant_on and cooling_scale > 0.0 and temps[i] > target:
			var cool_kw: float = minf(_k("heat.coolant_kw_per_room") * cooling_scale, _k("heat.coolant_kw_per_k") * (temps[i] - target))
			q_cool = roundi(cool_kw * per_j)
		delta[i] += q_rock + q_fire - q_cool
		if q_rock >= 0:
			energy_in_j += q_rock
		else:
			energy_out_j -= q_rock
		energy_in_j += q_fire
		energy_out_j += q_cool
		cooled_j += q_cool
	for i: int in range(n):
		ship.rooms[i].energy_j += delta[i]


# Fire ------------------------------------------------------------------------------------------

func _fire(sim: Sim, world: ShipWorld, dt: float) -> void:
	var ship: Ship = world.ship
	var rng: RandomNumberGenerator = world.stream(sim, "fire")
	for r: Room in ship.rooms:
		if _purge[r.index] != 0:
			# A purged room's fire never grows: it falls, more slowly while a linked room burns.
			if r.fire > 0.0:
				var out: float = _k("fire.purge_out_per_s")
				if linked_fire(ship, r.index):
					out *= _k("fire.purge_neighbour_factor")
				r.fire -= out * dt
				var lv: float = r.level_m()
				if lv > 0.05:
					r.fire -= _k("fire.water_suppress_per_m_s") * minf(lv, 1.0) * dt
				if r.fire <= 0.0:
					r.fire = 0.0
					world.emit(sim, "fire_out", {"room": r.id, "by": "purge"})
			continue
		if r.fire > 0.0:
			r.fire = minf(1.0, r.fire + _k("fire.growth_per_s") * dt * (1.0 - r.fire))
			var lvl: float = r.level_m()
			if lvl > 0.05:
				r.fire -= _k("fire.water_suppress_per_m_s") * minf(lvl, 1.0) * dt
			if r.fire <= 0.0:
				r.fire = 0.0
				world.emit(sim, "fire_out", {"room": r.id, "by": "water"})
		elif r.temp_c() >= _k("fire.autoignite_c") and rng.randf() < _k("fire.autoignite_per_s") * dt:
			ignite(sim, world, r, _k("fire.start_level"))
	# Spread: each neighbour accumulates exposure; at 1.0 it catches. Deterministic and testable.
	for j: int in range(_adj_from.size()):
		var src: Room = ship.rooms[_adj_from[j]]
		var dst: Room = ship.rooms[_adj_to[j]]
		if dst.fire > 0.0 or _purge[_adj_to[j]] != 0:
			_spread_acc[j] = 0.0
			continue
		if src.fire <= 0.0:
			_spread_acc[j] = maxf(0.0, _spread_acc[j] - 0.05 * dt)
			continue
		var factor: float = _adj_factor[j]
		var li: int = _adj_link[j]
		if li >= 0 and not ship.links[li].open:
			factor *= _k("fire.spread_closed_factor")
		_spread_acc[j] += _k("fire.spread_per_s") * src.fire * factor * dt
		if _spread_acc[j] >= 1.0:
			_spread_acc[j] = 0.0
			ignite(sim, world, dst, _k("fire.start_level"))
			world.emit(sim, "fire_spread", {"from": src.id, "to": dst.id})


# Water -----------------------------------------------------------------------------------------

func _water(ship: Ship, dt: float) -> void:
	var head_v: float = sqrt(2.0 * _k("water.gravity") * ship.water_head_m)
	for r: Room in ship.rooms:
		if r.breach_m2 > 0.0:
			var want: int = roundi(_k("water.breach_cd") * r.breach_m2 * head_v * dt * Room.ML_PER_M3)
			var add: int = mini(want, r.capacity_ml - r.water_ml)
			if add > 0:
				r.water_ml += add
				water_in_ml += add
	for l: Link in ship.links:
		var moved: int = 0
		if l.open:
			if l.kind == Link.Kind.DOOR:
				moved = _door_flow(ship.rooms[l.a], ship.rooms[l.b], l, dt)
			else:
				moved = _hatch_flow(ship.rooms[l.a], ship.rooms[l.b], l, dt)
		link_flow_ml_s[l.index] = float(moved) / dt
	for r: Room in ship.rooms:
		if r.has_pump and r.water_ml > 0:
			var out: int = mini(r.water_ml, roundi(_k("water.pump_m3_s") * pump_scale * dt * Room.ML_PER_M3))
			r.water_ml -= out
			water_out_ml += out


## Rooms on one deck: only water inside the door opening can pass, and never past equal levels.
func _door_flow(a: Room, b: Room, l: Link, dt: float) -> int:
	var ha: float = clampf(a.level_m(), 0.0, l.height_m)
	var hb: float = clampf(b.level_m(), 0.0, l.height_m)
	if absf(ha - hb) < 0.0005:
		return 0
	var want: int = roundi(_k("water.door_flow_per_m2_s") * l.breadth_m * (ha - hb) * dt * Room.ML_PER_M3)
	var fa: float = a.floor_area_m2()
	var fb: float = b.floor_area_m2()
	var level_gap: int = roundi((a.level_m() - b.level_m()) * fa * fb / (fa + fb) * Room.ML_PER_M3)
	if want > 0:
		want = mini(mini(want, level_gap), mini(a.water_ml, b.capacity_ml - b.water_ml))
		want = maxi(want, 0)
	else:
		want = maxi(maxi(want, level_gap), maxi(-b.water_ml, -(a.capacity_ml - a.water_ml)))
		want = mini(want, 0)
	a.water_ml -= want
	b.water_ml += want
	return want


## A hatch drains the room above into the room below like an orifice, until the lower room is full.
func _hatch_flow(up: Room, lo: Room, l: Link, dt: float) -> int:
	if up.water_ml <= 0 or lo.water_ml >= lo.capacity_ml:
		return 0
	var v: float = sqrt(2.0 * _k("water.gravity") * up.level_m())
	var want: int = roundi(_k("water.hatch_cd") * l.area_m2() * v * dt * Room.ML_PER_M3)
	want = mini(want, mini(up.water_ml, lo.capacity_ml - lo.water_ml))
	up.water_ml -= want
	lo.water_ml += want
	return want


# Crew harm and flooding ------------------------------------------------------------------------

func _crew_harm(sim: Sim, world: ShipWorld, dt: float) -> void:
	for c: CrewMember in world.ship.crew:
		if not c.alive or c.away:  # The away miner is outside: no room harm, no rest healing.
			continue
		var r: Room = world.ship.rooms[c.room]
		var fire_d: float = _k("fire.crew_dps") * r.fire * dt
		var heat_d: float = maxf(0.0, r.temp_c() - _k("crew.heat_safe_c")) * _k("crew.heat_dps_per_k") * dt
		var drown_d: float = _k("water.drown_dps") * dt if r.level_m() >= _k("water.crew_head_m") else 0.0
		if fire_d + heat_d + drown_d <= 0.0:
			# Rest heals: a crew member not taking harm slowly recovers.
			c.hp = minf(CrewMember.MAX_HP, c.hp + _k("crew.heal_per_s") * dt)
			continue
		c.hp -= fire_d + heat_d + drown_d
		if c.hp <= 0.0:
			c.hp = 0.0
			c.alive = false
			c.path = PackedVector2Array()
			if fire_d >= heat_d and fire_d >= drown_d:
				c.cause_of_death = "fire"
			elif drown_d >= heat_d:
				c.cause_of_death = "drowned"
			else:
				c.cause_of_death = "heat"
			world.emit(sim, "crew_died", {"crew": c.id, "cause": c.cause_of_death})


func _flood_watch(sim: Sim, world: ShipWorld, dt: float) -> void:
	for r: Room in world.ship.rooms:
		if r.is_full():
			if r.flooded_s == 0.0:
				world.emit(sim, "room_flooded", {"room": r.id})
			r.flooded_s += dt
		else:
			r.flooded_s = 0.0
