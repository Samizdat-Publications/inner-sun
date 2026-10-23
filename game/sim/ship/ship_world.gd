class_name ShipWorld
extends RefCounted
## A ship plus everything that runs on it: its hazards, its crew AI and which side it is on. The
## player's ship and an enemy ship are both ShipWorlds, stepped by the same code. Random streams
## and events are tagged by side, so the enemy's dice never shift the player's.

var side: String = "player"
var ship: Ship
var hazards: HazardSim
var crew_ai: CrewAI


func _init(db: DataDB, ship_def: Dictionary, p_side: String) -> void:
	side = p_side
	ship = Ship.from_def(ship_def)
	hazards = HazardSim.new(db, ship)
	crew_ai = CrewAI.new(db)


func is_player() -> bool:
	return side == "player"


## The name of this side's copy of a random stream: "fire" for the player, "enemy/fire" otherwise.
func stream_name(stream: String) -> String:
	return stream if is_player() else side + "/" + stream


func stream(sim: Sim, p_name: String) -> RandomNumberGenerator:
	return sim.rng.get_stream(stream_name(p_name))


## Emit a sim event, tagged with the side when it is not the player's.
func emit(sim: Sim, kind: String, info: Dictionary) -> void:
	if not is_player():
		info["side"] = side
	sim.emit(kind, info)


## Crew decide at 4 Hz, crew move every tick, hazards update at 10 Hz.
func step(sim: Sim) -> void:
	if sim.tick % Sim.THINK_EVERY == 0:
		crew_ai.think(sim, self)
	crew_ai.move(sim, self, Sim.DT)
	if sim.tick % Sim.HAZARD_EVERY == 0:
		hazards.step(sim, self, Sim.DT * Sim.HAZARD_EVERY)


func state() -> Array:
	var rooms: Array = []
	for r: Room in ship.rooms:
		rooms.append([r.energy_j, r.water_ml, r.fire, r.breach_m2, r.flooded_s, r.sys_max, r.sys_damage, r.sys_power, r.sys_want, r.sys_failed])
	var crew: Array = []
	for c: CrewMember in ship.crew:
		crew.append([c.pos.x, c.pos.y, c.hp, c.alive, c.room, c.order_room, c.auto, c.job_kind, c.job_room, c.path_i, c.away])
	var links: Array = []
	for l: Link in ship.links:
		links.append(l.open)
	# hull_max and weapons change mid-run (gear, requisitions, stores, loot): hashed since the Gemini audit.
	return [side, ship.id, ship.hull_max, Array(ship.weapons), rooms, crew, links, hazards.state()]
