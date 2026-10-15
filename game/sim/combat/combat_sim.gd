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


## Start a fight against a ship from the ships table. STUB until step 4: the fight is skipped (the
## enemy flees), the run returns to idle, and a boss fight counts as won.
func start_fight(sim: Sim, enemy_id: String, boss: bool) -> void:
	sim.emit("fight_skipped", {"enemy": enemy_id, "boss": boss})
	if boss and sim.run.mode == "run":
		sim.run.end_run(sim, "won", "gate")
	elif sim.run.mode == "run":
		sim.run.set_phase(sim, "idle")


func state() -> Array:
	return []


static func lint(_db: DataDB, _errs: PackedStringArray) -> void:
	pass
