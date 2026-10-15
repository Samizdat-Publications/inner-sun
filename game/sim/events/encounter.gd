class_name Encounter
extends SimModule
## What happens at a node: dossier events with choices and weighted outcomes, the store, salvage and
## hazard nodes. Runs in the "dialog" and "store" phases (the world is frozen while a page is open).
## STUB from the M1 skeleton. M1 step 5 fills it in.

const COMMANDS: Array[String] = ["choose", "buy", "leave"]


func _init(_db: DataDB) -> void:
	pass


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


## Resolve a node on arrival: "event", "cavern", "hazard" start an event; "store" opens the store.
## STUB until step 5: emits an event and returns to idle.
func start_node(sim: Sim, node_type: String, row: int) -> void:
	sim.emit("node_skipped", {"type": node_type, "row": row})
	if sim.run.mode == "run":
		sim.run.set_phase(sim, "idle")


func state() -> Array:
	return []


static func lint(_db: DataDB, _errs: PackedStringArray) -> void:
	pass
