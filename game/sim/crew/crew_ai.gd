class_name CrewAI
extends RefCounted
## Crew decisions and movement. A crew member with an order goes to that room and works there; one
## on auto takes the most urgent job anywhere (fight a fire, patch a breach, repair a damaged
## system), scored by urgency, skill and travel time. Thinking runs at 4 Hz; walking, climbing and
## working run every tick. Away crew (the miner outside) and crew boarding for a sortie (job
## "sortie", set by DrillMiner) are left alone: no replanning, and away crew do not move or work.
## Holds no reference to the Sim or its ShipWorld; both are passed in, so
## the same code runs the player's crew and an enemy crew.

const TUNING_KEYS: Array[String] = [
	"crew.walk_m_s", "crew.climb_m_s", "crew.slow_full_m", "crew.avoid_level_m",
	"crew.urgency_fire", "crew.urgency_breach", "crew.fight_per_s", "crew.patch_m2_per_s",
	"crew.urgency_repair", "crew.repair_bars_per_s",
]

var _t: Dictionary = {}


func _init(db: DataDB) -> void:
	for k: String in TUNING_KEYS:
		_t[k] = db.tune(k)


func _k(key: String) -> float:
	return float(_t[key])


func think(_sim: Sim, world: ShipWorld) -> void:
	for c: CrewMember in world.ship.crew:
		replan(world, c)


## Pick this crew member's best job now and route to it (keeps the current route if unchanged).
func replan(world: ShipWorld, c: CrewMember) -> void:
	if not c.alive or c.climbing or c.away or c.job_kind == "sortie":
		return
	var ship: Ship = world.ship
	var best_kind: String = ""
	var best_room: int = -1
	var best: float = 0.0
	for r: Room in ship.rooms:
		if c.order_room >= 0:
			if r.index != c.order_room:
				continue
		elif not c.auto or r.level_m() > _k("crew.avoid_level_m"):
			continue
		var travel: float = travel_time(ship, c, r.index)
		if travel < 0.0:
			continue
		var reach: float = 1.0 / (1.0 + travel / 10.0)
		if r.fire > 0.0:
			var s_fire: float = _k("crew.urgency_fire") * (0.5 + r.fire) * c.skill_fire * reach
			if s_fire > best:
				best = s_fire
				best_kind = "extinguish"
				best_room = r.index
		if r.breach_m2 > 0.0:
			var s_breach: float = _k("crew.urgency_breach") * (0.5 + minf(r.breach_m2 * 25.0, 1.0)) * c.skill_repair * reach
			if s_breach > best:
				best = s_breach
				best_kind = "patch"
				best_room = r.index
		if r.sys_damage > 0.0 and r.sys_max > 0:
			var s_fix: float = _k("crew.urgency_repair") * (0.5 + minf(r.sys_damage / float(r.sys_max), 1.0)) * c.skill_repair * reach
			if s_fix > best:
				best = s_fix
				best_kind = "repair"
				best_room = r.index
	if best_kind == "" and c.order_room >= 0:
		best_kind = "go"
		best_room = c.order_room
	elif best_kind == "" and c.auto:
		best_kind = "go"  # Nothing urgent: return to station.
		best_room = c.start_room
	_set_job(ship, c, best_kind, best_room)


## Seconds to walk and climb to a room, or -1 if it cannot be reached.
func travel_time(ship: Ship, c: CrewMember, to_room: int) -> float:
	if to_room == c.room:
		return absf(ship.rooms[to_room].center_floor().x - c.pos.x) / _k("crew.walk_m_s")
	var pts: PackedVector2Array = ship.nav.route(ship, c.room, to_room, ship.rooms[to_room].center_floor().x)
	if pts.is_empty():
		return -1.0
	var lengths: Vector2 = NavGraph.route_lengths(c.pos, pts)
	return lengths.x / _k("crew.walk_m_s") + lengths.y / _k("crew.climb_m_s")


func _set_job(ship: Ship, c: CrewMember, kind: String, room: int) -> void:
	if kind == c.job_kind and room == c.job_room:
		return
	c.job_kind = kind
	c.job_room = room
	c.path_i = 0
	if room < 0:
		c.path = PackedVector2Array()
		return
	c.path = ship.nav.route(ship, c.room, room, ship.rooms[room].center_floor().x)


func move(sim: Sim, world: ShipWorld, dt: float) -> void:
	var ship: Ship = world.ship
	for c: CrewMember in ship.crew:
		if not c.alive or c.away:
			continue
		if c.path_i < c.path.size():
			_advance(ship, c, dt)
			if c.path_i >= c.path.size() and c.job_room >= 0:
				world.emit(sim, "arrive", {"crew": c.id, "room": ship.rooms[c.job_room].id, "job": c.job_kind})
		else:
			_work(sim, world, c, dt)


func _advance(ship: Ship, c: CrewMember, dt: float) -> void:
	var budget: float = dt
	c.climbing = false
	while budget > 0.0 and c.path_i < c.path.size():
		var target: Vector2 = c.path[c.path_i]
		var d: Vector2 = target - c.pos
		var dist: float = d.length()
		var vertical: bool = absf(d.x) < 0.001 and absf(d.y) > 0.001
		var speed: float = _k("crew.climb_m_s") if vertical else _k("crew.walk_m_s") * _wade(ship, c)
		c.climbing = vertical
		if dist <= speed * budget:
			c.pos = target
			c.path_i += 1
			budget -= dist / speed
		else:
			c.pos += d / dist * speed * budget
			budget = 0.0
	c.room = ship.room_at(c.pos, c.room)


## Walking speed factor in water: deep water slows crew to half speed.
func _wade(ship: Ship, c: CrewMember) -> float:
	var lvl: float = ship.rooms[c.room].level_m()
	return 1.0 - 0.5 * clampf(lvl / _k("crew.slow_full_m"), 0.0, 1.0)


func _work(sim: Sim, world: ShipWorld, c: CrewMember, dt: float) -> void:
	if c.job_room < 0 or c.room != c.job_room:
		return
	var r: Room = world.ship.rooms[c.job_room]
	if c.job_kind == "extinguish" and r.fire > 0.0:
		r.fire = maxf(0.0, r.fire - _k("crew.fight_per_s") * c.skill_fire * dt)
		if r.fire <= 0.0:
			world.emit(sim, "fire_out", {"room": r.id, "by": c.id})
	elif c.job_kind == "patch" and r.breach_m2 > 0.0:
		r.breach_m2 = maxf(0.0, r.breach_m2 - _k("crew.patch_m2_per_s") * c.skill_repair * dt)
		if r.breach_m2 <= 0.0:
			world.emit(sim, "breach_patched", {"room": r.id, "by": c.id})
	elif c.job_kind == "repair" and r.sys_damage > 0.0:
		r.sys_damage = maxf(0.0, r.sys_damage - _k("crew.repair_bars_per_s") * c.skill_repair * dt)
		if r.sys_damage <= 0.0:
			world.emit(sim, "system_repaired", {"room": r.id, "by": c.id})
