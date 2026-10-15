class_name RandomBot
extends Bot
## Sends each crew member to a random room every 3 seconds: a baseline for how much good orders matter.

var _started: bool = false


func act(sim: Sim) -> void:
	if not _started:
		_started = true
		Bot.take_control(sim)
	if sim.tick % 180 != 90:
		return
	var rng: RandomNumberGenerator = sim.rng.get_stream("bot")
	for c: CrewMember in sim.ship.crew:
		if c.alive:
			var r: Room = sim.ship.rooms[rng.randi_range(0, sim.ship.rooms.size() - 1)]
			sim.push({"type": "assign", "crew": c.id, "room": r.id})
