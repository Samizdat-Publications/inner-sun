class_name Sim
extends RefCounted
## The whole simulation: ship, hazards, crew and randomness, stepped at a fixed 60 Hz tick. No Nodes,
## no rendering, no clock, no delta: the same code runs in the game, in tests and in headless
## balance runs. Everything that changes the world arrives as a command (from the player, a bot or a
## scenario timeline), so a replay is just a seed plus the command log.

const TICK_HZ: int = 60
const DT: float = 1.0 / 60.0
const HAZARD_EVERY: int = 6  ## Hazards update at 10 Hz.
const THINK_EVERY: int = 15  ## Crew decide at 4 Hz.

var tick: int = 0
var run_seed: int = 0
var ship_id: String = ""
var rng: RngStreams
var ship: Ship
var hazards: HazardSim
var crew_ai: CrewAI
var events: Array[Dictionary] = []
var command_log: Array[Dictionary] = []
var _pending: Array[Dictionary] = []


func _init(db: DataDB, p_seed: int, p_ship_id: String) -> void:
	run_seed = p_seed
	ship_id = p_ship_id
	rng = RngStreams.new(p_seed)
	ship = Ship.from_def(db.ships[p_ship_id])
	hazards = HazardSim.new(db, ship)
	crew_ai = CrewAI.new(db)


## Queue a command. It is applied at the start of the next step and recorded in command_log.
func push(cmd: Dictionary) -> void:
	_pending.append(cmd)


func step() -> void:
	var batch: Array[Dictionary] = _pending
	_pending = []
	for cmd: Dictionary in batch:
		var logged: Dictionary = {"t": tick}
		logged.merge(cmd)
		command_log.append(logged)
		_apply(cmd)
	if tick % THINK_EVERY == 0:
		crew_ai.think(self)
	crew_ai.move(self, DT)
	if tick % HAZARD_EVERY == 0:
		hazards.step(self, DT * HAZARD_EVERY)
	tick += 1


func emit(kind: String, info: Dictionary) -> void:
	var e: Dictionary = {"t": tick, "kind": kind}
	e.merge(info)
	events.append(e)


func seconds() -> float:
	return float(tick) / TICK_HZ


func _apply(cmd: Dictionary) -> void:
	var kind: String = str(cmd.get("type", ""))
	var room: int = ship.room_index(str(cmd.get("room", "")))
	var crew: CrewMember = ship.crew_by_id(str(cmd.get("crew", "")))
	match kind:
		"assign":
			if crew != null and room >= 0:
				crew.order_room = room
				crew_ai.replan(self, crew)
		"release":
			if crew != null:
				crew.order_room = -1
				crew_ai.replan(self, crew)
		"auto":
			if crew != null:
				crew.auto = bool(cmd.get("on", true))
		"ignite":
			if room >= 0:
				hazards.ignite(self, ship.rooms[room], float(cmd.get("level", 0.2)))
		"breach":
			if room >= 0:
				ship.rooms[room].breach_m2 += float(cmd.get("size_m2", 0.02))
				emit("breach", {"room": ship.rooms[room].id})
		"door":
			for l: Link in ship.links:
				if l.id == str(cmd.get("link", "")):
					l.open = bool(cmd.get("open", true))
		_:
			emit("bad_command", {"type": kind})


## Everything that defines the world right now, in a fixed order, for the state hash.
func state() -> Array:
	var rooms: Array = []
	for r: Room in ship.rooms:
		rooms.append([r.energy_j, r.water_ml, r.fire, r.breach_m2, r.flooded_s])
	var crew: Array = []
	for c: CrewMember in ship.crew:
		crew.append([c.pos.x, c.pos.y, c.hp, c.alive, c.room, c.order_room, c.auto, c.job_kind, c.job_room, c.path_i])
	var links: Array = []
	for l: Link in ship.links:
		links.append(l.open)
	return [tick, run_seed, ship_id, rooms, crew, links, rng.state(), hazards.state()]


func state_hash() -> String:
	return StateHash.of(state())


## Rebuild a run from its seed and command log alone.
static func replay(db: DataDB, p_seed: int, p_ship_id: String, commands: Array[Dictionary], ticks: int) -> Sim:
	var s := Sim.new(db, p_seed, p_ship_id)
	var i: int = 0
	while s.tick < ticks:
		while i < commands.size() and int(commands[i]["t"]) == s.tick:
			var cmd: Dictionary = commands[i].duplicate()
			cmd.erase("t")
			s.push(cmd)
			i += 1
		var before: int = s.tick
		s.step()
		if s.tick == before:
			push_error("Sim.replay: the sim stopped advancing at tick %d" % before)
			break
	return s
