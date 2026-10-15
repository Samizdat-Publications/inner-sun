class_name DrillSim
extends SimModule
## The drilling segment between map nodes: a rock grid owned by the sim, the drill head and its
## heading, bite, heat, bit wear and noise, ore and gems collected as exact integers.
## STUB from the M1 skeleton. M1 step 1 fills it in (see docs/plans/M1.md).

const COMMANDS: Array[String] = ["steer"]


func _init(_db: DataDB) -> void:
	pass


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


func state() -> Array:
	return []


static func lint(_db: DataDB, _errs: PackedStringArray) -> void:
	pass
