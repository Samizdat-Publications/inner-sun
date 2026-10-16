class_name SystemsDouse
extends RefCounted
## Douse: vent coolant into a burning room of the player's ship (the coolant system's active verb).
## Valid in world phases when the coolant system has at least one effective bar, the room is burning,
## the run holds at least one "coolant" unit (scenario mode: free) and the cooldown has run out. It
## spends one unit through run.add, lowers the fire by douse_fire (floored at 0) and removes up to
## douse_j of the room's heat through hazards.add_heat (so the heat books stay exact), never taking
## the room below its design temperature (Room.start_temp_c). Static: the Sim and Systems are passed in.
##
## Events: "doused" {"room", "fire_before", "fire_after", "heat_j"}, "fire_out" {"room", "by": "douse"}
## when the fire is out; refusals are "bad_command" {"type": "douse", "room", "why"}.


## Why a douse cannot be ordered now ("" when it can): "not now", "power coolant", "no coolant",
## "venting" (cooldown), "no such room", "no fire". room_id "" skips the room's own checks except
## that some room must be burning.
static func why_not(sim: Sim, sys: Systems, room_id: String) -> String:
	if not sim.run.world_running():
		return "not now"
	if sys.coolant_bars(sim.player) < 1:
		return "power coolant"
	if sim.run.mode == "run" and sim.run.get_res("coolant") < 1:
		return "no coolant"
	if sys.douse_cooldown_ticks > 0:
		return "venting"
	if room_id.is_empty():
		for r: Room in sim.ship.rooms:
			if r.fire > 0.0:
				return ""
		return "no fire"
	var ri: int = sim.ship.room_index(room_id)
	if ri < 0:
		return "no such room"
	if sim.ship.rooms[ri].fire <= 0.0:
		return "no fire"
	return ""


static func douse(sim: Sim, sys: Systems, room_id: String) -> bool:
	var why: String = "no such room" if room_id.is_empty() else why_not(sim, sys, room_id)
	if not why.is_empty():
		sim.emit("bad_command", {"type": "douse", "room": room_id, "why": why})
		return false
	var r: Room = sim.ship.rooms[sim.ship.room_index(room_id)]
	if sim.run.mode == "run":
		sim.run.add(sim, "coolant", -1)
	var before: float = r.fire
	r.fire = maxf(0.0, r.fire - sys.douse_fire)
	var floor_j: int = ceili(r.start_temp_c * r.heat_cap_j_per_k)
	var take: int = clampi(r.energy_j - floor_j, 0, sys.douse_j)
	if take > 0:
		sim.hazards.add_heat(r, -take)
	sys.douse_cooldown_ticks = sys.douse_cooldown_full
	sim.emit("doused", {"room": r.id, "fire_before": snappedf(before, 0.001), "fire_after": snappedf(r.fire, 0.001),
			"heat_j": take})
	if r.fire <= 0.0:
		sim.emit("fire_out", {"room": r.id, "by": "douse"})
	return true
