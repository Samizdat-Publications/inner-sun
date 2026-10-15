class_name ScenarioRun
extends RefCounted
## One situation to play out: a ship, a timeline of events, a bot and a time limit. The rendered
## game, the tests, captures and headless balance runs all play situations through this class.
## Timeline events and bot orders both enter the sim as commands, so they all land in the replay log.

const FLOOD_LIMIT_S: float = 10.0

var sim: Sim
var bot: Bot
var scenario_id: String = ""
var bot_name: String = ""
var timeline: Array[Dictionary] = []
var duration_ticks: int = 0
var outcome: String = ""
var cause: String = ""
var first_fire_out_s: float = -1.0
var max_water_ml: int = 0
var _next: int = 0
var _seen: int = 0
var _drill_room: int = -1


static func from_scenario(db: DataDB, p_scenario_id: String, run_seed: int, bot_override: String = "") -> ScenarioRun:
	var def: Dictionary = db.scenarios[p_scenario_id]
	var run := ScenarioRun.new()
	run.scenario_id = p_scenario_id
	run.sim = Sim.new(db, run_seed, str(def["ship"]))
	run.duration_ticks = roundi(float(def.get("duration_s", 60.0)) * Sim.TICK_HZ)
	for e: Dictionary in def.get("timeline", []):
		run.timeline.append({"tick": roundi(float(e["at_s"]) * Sim.TICK_HZ), "cmd": e["cmd"]})
	run._finish_setup(bot_override if bot_override != "" else str(def.get("bot", "auto")))
	return run


## A random situation for balance runs: one or two fires and a breach, at random times and places,
## all drawn from the run's own "scenario" stream.
static func generated(db: DataDB, run_seed: int, p_bot_name: String, duration_s: float, ship_id: String = "light_drill") -> ScenarioRun:
	var run := ScenarioRun.new()
	run.scenario_id = "generated"
	run.sim = Sim.new(db, run_seed, ship_id)
	run.duration_ticks = roundi(duration_s * Sim.TICK_HZ)
	var rng: RandomNumberGenerator = run.sim.rng.get_stream("scenario")
	var rooms: Array[Room] = run.sim.ship.rooms
	var fires: int = 1 if rng.randf() < 0.5 else 2
	for i: int in range(fires):
		var fr: Room = rooms[rng.randi_range(0, rooms.size() - 1)]
		run.timeline.append({"tick": rng.randi_range(30, 1200), "cmd": {"type": "ignite", "room": fr.id, "level": rng.randf_range(0.1, 0.4)}})
	var br: Room = rooms[rng.randi_range(0, rooms.size() - 1)]
	run.timeline.append({"tick": rng.randi_range(30, 2400), "cmd": {"type": "breach", "room": br.id, "size_m2": rng.randf_range(0.01, 0.06)}})
	run._finish_setup(p_bot_name)
	return run


func _finish_setup(p_bot_name: String) -> void:
	timeline.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["tick"]) < int(y["tick"]))
	bot_name = p_bot_name
	bot = Bot.make(p_bot_name)
	_drill_room = sim.ship.room_with_system("drill")


func done() -> bool:
	return outcome != ""


func step() -> void:
	if outcome != "":
		return
	while _next < timeline.size() and int(timeline[_next]["tick"]) <= sim.tick:
		var cmd: Dictionary = timeline[_next]["cmd"]
		sim.push(cmd.duplicate(true))
		_next += 1
	bot.act(sim)
	sim.step()
	_watch()


func _watch() -> void:
	while _seen < sim.events.size():
		var e: Dictionary = sim.events[_seen]
		_seen += 1
		if str(e["kind"]) == "fire_out" and first_fire_out_s < 0.0:
			first_fire_out_s = float(int(e["t"])) / Sim.TICK_HZ
	max_water_ml = maxi(max_water_ml, sim.ship.total_water_ml())
	var alive: int = 0
	var last_cause: String = ""
	for c: CrewMember in sim.ship.crew:
		if c.alive:
			alive += 1
		else:
			last_cause = c.cause_of_death
	if alive == 0:
		outcome = "died"
		cause = "crew_" + last_cause
	elif _drill_room >= 0 and sim.ship.rooms[_drill_room].flooded_s >= FLOOD_LIMIT_S:
		outcome = "died"
		cause = "flooded"
	elif sim.tick >= duration_ticks:
		outcome = "survived"


func crew_alive() -> int:
	var n: int = 0
	for c: CrewMember in sim.ship.crew:
		if c.alive:
			n += 1
	return n


## One line of results for balance reports.
func summary() -> Dictionary:
	return {
		"seed": sim.run_seed,
		"bot": bot_name,
		"scenario": scenario_id,
		"outcome": outcome,
		"cause": cause,
		"ticks": sim.tick,
		"first_fire_out_s": snappedf(first_fire_out_s, 0.01),
		"max_water_m3": snappedf(float(max_water_ml) / Room.ML_PER_M3, 0.001),
		"crew_alive": crew_alive(),
		"hash": sim.state_hash(),
	}
