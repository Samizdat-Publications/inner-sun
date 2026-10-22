class_name EventEffects
extends RefCounted
## The event effects and requirements of docs/STYLE_GUIDE.md, applied to the player's ship and the
## run. Static functions: the Sim and the Encounter are passed in, never stored. Resources change
## only through run.add, heat only through hazards.add_heat (exact integer joules).

const TYPES: Array[String] = [
	"res", "res_range", "reward", "hull", "crew_damage", "crew_join", "crew_lose", "fight", "hazard",
	"system_damage", "codex", "pursuer", "reveal", "store",
]
const SKILLS: Array[String] = ["fire", "repair"]
const J_PER_KJ: float = 1000.0


static func apply(sim: Sim, enc: Encounter, e: Dictionary) -> void:
	var kind: String = str(e.get("type", ""))
	match kind:
		"res":
			sim.run.add(sim, str(e.get("res", "")), int(e.get("amount", 0)))
		"res_range":
			var n: int = sim.rng.get_stream("events").randi_range(int(e.get("min", 0)), int(e.get("max", 0)))
			sim.run.add(sim, str(e.get("res", "")), n)
		"reward":
			# A tiered ore or gem reward at the ship's map row (Rewards; one draw, "reward" stream).
			var res: String = str(e.get("res", ""))
			sim.run.add(sim, res, Rewards.roll(sim, res, str(e.get("tier", "")), sim.run.current_row()))
		"hull":
			sim.run.add(sim, "hull", int(e.get("amount", 0)))
		"crew_damage":
			var amount: float = float(e.get("amount", 0.0))
			for i: int in _targets(sim, enc, str(e.get("target", "picked"))):
				hurt(sim, sim.ship.crew[i], amount)
		"crew_join":
			var member: String = roll_member(sim, enc, str(e.get("pool", "")), "events")
			if member.is_empty():
				sim.emit("crew_pool_empty", {"pool": str(e.get("pool", ""))})
			else:
				join(sim, enc, str(e.get("pool", "")), member)
		"crew_lose":
			for i: int in _targets(sim, enc, str(e.get("target", "picked"))):
				kill(sim, sim.ship.crew[i])
		"fight":
			enc.pending_fight = str(e.get("enemy", ""))
			enc.pending_boss = bool(e.get("boss", false))
		"hazard":
			_hazard(sim, e)
		"system_damage":
			var ri: int = sim.ship.room_with_system(str(e.get("system", "")))
			if ri >= 0:
				var r: Room = sim.ship.rooms[ri]
				r.sys_damage = minf(float(r.sys_max), r.sys_damage + float(e.get("bars", 0)))
				sim.emit("system_damaged", {"room": r.id, "bars": int(e.get("bars", 0)), "by": "event"})
		"codex":
			sim.run.learn(sim, str(e.get("id", "")))
		"pursuer":
			sim.run.move_pursuer(sim, float(e.get("rows", 0.0)))
		"reveal":
			sim.run.add_reveal(sim, int(e.get("rows", 0)))
		"store":
			enc.pending_store = str(e.get("store", ""))
		_:
			push_error("EventEffects: unknown effect type \"%s\" (run the data lint)" % kind)


static func _hazard(sim: Sim, e: Dictionary) -> void:
	var where: String = str(e.get("room", "random"))
	var ri: int = -1
	if where == "random":
		ri = sim.rng.get_stream("events").randi_range(0, sim.ship.rooms.size() - 1)
	elif where.begins_with("system:"):
		ri = sim.ship.room_with_system(where.substr(7))
	if ri < 0:
		return
	var r: Room = sim.ship.rooms[ri]
	var level: float = float(e.get("level", 0.0))
	match str(e.get("kind", "")):
		"fire":
			sim.hazards.ignite(sim, sim.player, r, level)
		"breach":
			r.breach_m2 += level
			sim.emit("breach", {"room": r.id, "by": "event"})
		"heat":
			var joules: int = roundi(level * J_PER_KJ)
			sim.hazards.add_heat(r, joules)
			sim.emit("heat_added", {"room": r.id, "joules": joules, "by": "event"})


## Crew indexes an effect acts on: "picked", "random" (a live one, events stream) or "all" (live).
static func _targets(sim: Sim, enc: Encounter, target: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var crew: Array[CrewMember] = sim.ship.crew
	if target == "picked":
		if enc.picked >= 0 and enc.picked < crew.size() and crew[enc.picked].alive:
			out.append(enc.picked)
		return out
	var alive := PackedInt32Array()
	for c: CrewMember in crew:
		if c.alive:
			alive.append(c.index)
	if target == "all" or alive.is_empty():
		return alive
	out.append(alive[sim.rng.get_stream("events").randi_range(0, alive.size() - 1)])
	return out


static func hurt(sim: Sim, c: CrewMember, amount: float) -> void:
	if not c.alive or amount <= 0.0:
		return
	c.hp -= amount
	sim.emit("crew_hurt", {"crew": c.id, "amount": amount, "by": "event"})
	if c.hp <= 0.0:
		kill(sim, c)


## Permadeath from an event.
static func kill(sim: Sim, c: CrewMember) -> void:
	if not c.alive:
		return
	c.hp = 0.0
	c.alive = false
	c.cause_of_death = "event"
	c.path = PackedVector2Array()
	c.path_i = 0
	c.climbing = false
	sim.emit("crew_died", {"crew": c.id, "cause": "event"})


## A pool member who has not come aboard this run, picked from `stream` ("" if none is left).
static func roll_member(sim: Sim, enc: Encounter, pool_id: String, stream: String) -> String:
	var pool: Dictionary = sim.db.table("crew").get(pool_id, {})
	var free := PackedStringArray()
	for m: Variant in pool.get("members", []):
		var mid: String = str((m as Dictionary).get("id", ""))
		if not enc.joined.has(mid):
			free.append(mid)
	if free.is_empty():
		return ""
	return free[sim.rng.get_stream(stream).randi_range(0, free.size() - 1)]


## Bring a pool member aboard. Their station is the first system room nobody alive is stationed
## in, else the system room with the fewest; they board at the entry room (the ship's "entry_room",
## else the drill room) and walk to their station. The walking graph is per room, so it needs no
## rebuild for a new crew member.
static func join(sim: Sim, enc: Encounter, pool_id: String, member_id: String) -> CrewMember:
	var pool: Dictionary = sim.db.table("crew").get(pool_id, {})
	var md: Dictionary = {}
	for m: Variant in pool.get("members", []):
		if str((m as Dictionary).get("id", "")) == member_id:
			md = m
	if md.is_empty():
		return null
	var ship: Ship = sim.ship
	var station: int = station_for_newcomer(ship)
	var cid: String = "%s_%d" % [member_id, enc.joined.size() + 1]
	var c: CrewMember = ship.add_crew({"id": cid, "name": str(md.get("name", member_id)), "room": ship.rooms[station].id,
		"skills": md.get("skills", {})})
	if c == null:
		return null
	enc.joined.append(member_id)
	var entry: int = ship.room_index(str(ship.source_def.get("entry_room", "")))
	if entry < 0:
		entry = ship.room_with_system("drill")
	if entry >= 0:
		c.room = entry
		c.pos = ship.rooms[entry].center_floor()
	sim.emit("crew_joined", {"crew": cid, "member": member_id, "pool": pool_id, "station": ship.rooms[station].id})
	return c


static func station_for_newcomer(ship: Ship) -> int:
	var counts := PackedInt32Array()
	counts.resize(ship.rooms.size())
	for c: CrewMember in ship.crew:
		if c.alive:
			counts[c.start_room] += 1
	var best: int = -1
	for r: Room in ship.rooms:
		if r.system == "none":
			continue
		if best < 0 or counts[r.index] < counts[best]:
			best = r.index
	return best if best >= 0 else 0


static func skill_of(c: CrewMember, skill: String) -> float:
	if skill == "fire":
		return c.skill_fire
	if skill == "repair":
		return c.skill_repair
	return 0.0


## Why a "requires" block fails right now ("" = it holds).
static func requirement_failure(sim: Sim, req: Dictionary) -> String:
	var res: Dictionary = req.get("res", {})
	for k: Variant in res.keys():
		if sim.run.get_res(str(k)) < int(res[k]):
			return "needs %d %s" % [int(res[k]), str(k)]
	var sys: Dictionary = req.get("system", {})
	for k: Variant in sys.keys():
		var ri: int = sim.ship.room_with_system(str(k))
		var bars: int = sim.ship.rooms[ri].effective_bars() if ri >= 0 else 0
		if bars < int(sys[k]):
			return "needs %s at %d bars" % [str(k), int(sys[k])]
	var sk: Dictionary = req.get("skill", {})
	for k: Variant in sk.keys():
		var ok: bool = false
		for c: CrewMember in sim.ship.crew:
			if c.alive and skill_of(c, str(k)) >= float(sk[k]):
				ok = true
				break
		if not ok:
			return "needs a crew member with %s %.1f" % [str(k), float(sk[k])]
	var codex: String = str(req.get("codex", ""))
	if not codex.is_empty() and not sim.run.knows(codex):
		return "needs codex \"%s\"" % codex
	return ""
