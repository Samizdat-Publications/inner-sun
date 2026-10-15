class_name Systems
extends SimModule
## Power and ship systems: the reactor's bars split across systems, damage and heat failure, and
## what each system does (helm evasion, bracing layers, coolant and pumps, drill power, weapons
## power). System state sits on the rooms (Room.sys_*); this module owns the rules.
## STUB from the M1 skeleton: the "power" command only clamps to capacity. M1 step 2 fills it in.

const COMMANDS: Array[String] = ["power"]


func _init(_db: DataDB) -> void:
	pass


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


## {"type": "power", "room": "<room id>", "bars": n}
func apply(sim: Sim, cmd: Dictionary) -> void:
	var ri: int = sim.ship.room_index(str(cmd.get("room", "")))
	if ri < 0:
		sim.emit("bad_command", {"type": "power", "why": "no such room"})
		return
	var r: Room = sim.ship.rooms[ri]
	r.sys_power = clampi(int(cmd.get("bars", 0)), 0, r.sys_max)


func state() -> Array:
	return []


static func lint(_db: DataDB, _errs: PackedStringArray) -> void:
	pass
