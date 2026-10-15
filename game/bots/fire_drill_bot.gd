class_name FireDrillBot
extends Bot
## Scripted responder for captures and demos. It switches the crew's own judgement off and gives
## every order itself: the nearest free crew member to each burning room, then to each breach, and
## everyone else back to their station. Orders are only re-sent when they change.

var _started: bool = false
var _given: Dictionary = {}


func act(sim: Sim) -> void:
	var ship: Ship = sim.ship
	if not _started:
		_started = true
		Bot.take_control(sim)
	if sim.tick % 15 != 0:
		return
	var free: Array[CrewMember] = []
	for c: CrewMember in ship.crew:
		if c.alive:
			free.append(c)
	var targets: Array[int] = []
	for r: Room in ship.rooms:
		if r.fire > 0.0:
			targets.append(r.index)
	for r: Room in ship.rooms:
		if r.breach_m2 > 0.0 and not targets.has(r.index):
			targets.append(r.index)
	var want: Dictionary = {}
	for t: int in targets:
		var best: CrewMember = null
		var best_time: float = INF
		for c: CrewMember in free:
			var tt: float = sim.crew_ai.travel_time(ship, c, t)
			if tt >= 0.0 and tt < best_time:
				best_time = tt
				best = c
		if best != null:
			want[best.id] = t
			free.erase(best)
	for c: CrewMember in free:
		want[c.id] = c.start_room
	for cid: String in want.keys():
		var room: int = int(want[cid])
		if int(_given.get(cid, -1)) != room:
			_given[cid] = room
			sim.push({"type": "assign", "crew": cid, "room": ship.rooms[room].id})
