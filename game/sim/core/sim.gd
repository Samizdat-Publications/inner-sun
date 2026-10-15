class_name Sim
extends RefCounted
## The whole simulation of a run: the player's ship world, the run state and the modules (systems,
## drilling, combat, encounters), stepped at a fixed 60 Hz tick. No Nodes, no rendering, no clock, no
## delta: the same code runs in the game, in tests and in headless balance runs. Everything that
## changes the world arrives as a command (from the player, a bot or a scenario timeline), so a
## replay is the seed, the run options and the command log. See docs/ARCHITECTURE.md.

const TICK_HZ: int = 60
const DT: float = 1.0 / 60.0
const HAZARD_EVERY: int = 6  ## Hazards update at 10 Hz.
const THINK_EVERY: int = 15  ## Crew decide at 4 Hz.
const CORE_COMMANDS: Array[String] = ["assign", "release", "auto", "ignite", "breach", "door"]

var tick: int = 0
var run_seed: int = 0
var ship_id: String = ""
var options: Dictionary = {}
var db: DataDB
var rng: RngStreams
var player: ShipWorld
var enemy: ShipWorld = null  ## Set by CombatSim during a fight.
var run: RunState
var systems: Systems
var drill: DrillSim
var combat: CombatSim
var encounter: Encounter
var modules: Array[SimModule] = []
var events: Array[Dictionary] = []
var command_log: Array[Dictionary] = []
# Aliases of the player's ship world, for older code and the view.
var ship: Ship
var hazards: HazardSim
var crew_ai: CrewAI
var _pending: Array[Dictionary] = []
var _dispatch: Dictionary = {}  ## command type -> module


## p_options: {"mode": "scenario" (default) or "run", "known_codex": [ids the profile knows]}.
func _init(p_db: DataDB, p_seed: int, p_ship_id: String, p_options: Dictionary = {}) -> void:
	db = p_db
	run_seed = p_seed
	ship_id = p_ship_id
	options = p_options.duplicate(true)
	rng = RngStreams.new(p_seed)
	player = ShipWorld.new(db, db.ships[p_ship_id], "player")
	ship = player.ship
	hazards = player.hazards
	crew_ai = player.crew_ai
	var known := PackedStringArray()
	for k: Variant in options.get("known_codex", []):
		known.append(str(k))
	run = RunState.new(str(options.get("mode", "scenario")), known)
	systems = Systems.new(db)
	drill = DrillSim.new(db)
	combat = CombatSim.new(db)
	encounter = Encounter.new(db)
	modules = [run, systems, drill, combat, encounter]
	for m: SimModule in modules:
		for kind: String in m.commands():
			if CORE_COMMANDS.has(kind) or _dispatch.has(kind):
				push_error("Sim: command type \"%s\" is declared twice" % kind)
				continue
			_dispatch[kind] = m
	run.begin(self)


## Every command type any part of the sim understands (the data lint checks timelines against it).
static func known_commands() -> PackedStringArray:
	var out := PackedStringArray(CORE_COMMANDS)
	for list: Array in [RunState.COMMANDS, Systems.COMMANDS, DrillSim.COMMANDS, CombatSim.COMMANDS, Encounter.COMMANDS]:
		for kind: Variant in list:
			out.append(str(kind))
	return out


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
	for m: SimModule in modules:
		m.step(self)
	if run.world_running():
		player.step(self)
		if enemy != null:
			enemy.step(self)
	tick += 1


func emit(kind: String, info: Dictionary) -> void:
	var e: Dictionary = {"t": tick, "kind": kind}
	e.merge(info)
	events.append(e)


func seconds() -> float:
	return float(tick) / TICK_HZ


func _apply(cmd: Dictionary) -> void:
	var kind: String = str(cmd.get("type", ""))
	if _dispatch.has(kind):
		var m: SimModule = _dispatch[kind]
		m.apply(self, cmd)
		return
	var room: int = ship.room_index(str(cmd.get("room", "")))
	var crew: CrewMember = ship.crew_by_id(str(cmd.get("crew", "")))
	match kind:
		"assign":
			if crew != null and room >= 0:
				crew.order_room = room
				crew_ai.replan(player, crew)
		"release":
			if crew != null:
				crew.order_room = -1
				crew_ai.replan(player, crew)
		"auto":
			if crew != null:
				crew.auto = bool(cmd.get("on", true))
		"ignite":
			if room >= 0:
				hazards.ignite(self, player, ship.rooms[room], float(cmd.get("level", 0.2)))
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
	var mods: Array = []
	for m: SimModule in modules:
		mods.append(m.state())
	return [tick, run_seed, ship_id, player.state(), enemy.state() if enemy != null else [], rng.state(), mods]


func state_hash() -> String:
	return StateHash.of(state())


## Rebuild a run from its seed, options and command log alone.
static func replay(p_db: DataDB, p_seed: int, p_ship_id: String, commands: Array[Dictionary], ticks: int, p_options: Dictionary = {}) -> Sim:
	var s := Sim.new(p_db, p_seed, p_ship_id, p_options)
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
