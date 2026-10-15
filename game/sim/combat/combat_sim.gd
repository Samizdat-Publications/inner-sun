class_name CombatSim
extends SimModule
## Real-time combat with pause: the enemy ShipWorld (sim.enemy), weapons charging and firing,
## projectiles and beams, bracing, evasion, hits on rooms, and the enemy AI.
## STUB from the M1 skeleton. M1 step 4 fills it in.

const COMMANDS: Array[String] = ["target"]


func _init(_db: DataDB) -> void:
	pass


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


func state() -> Array:
	return []


static func lint(_db: DataDB, _errs: PackedStringArray) -> void:
	pass
