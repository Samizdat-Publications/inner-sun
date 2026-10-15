class_name SimModule
extends RefCounted
## Base for the parts of a run that the Sim steps in a fixed order (run, systems, drill, combat,
## encounter). A module declares the command types it handles, applies them, steps every tick (it
## checks the phase itself) and reports its state for the hash. Modules hold no reference to the Sim;
## the Sim passes itself in. See docs/ARCHITECTURE.md.


## The command types this module handles. Sim dispatches each command to the module that declares it.
func commands() -> PackedStringArray:
	return PackedStringArray()


func apply(_sim: Sim, _cmd: Dictionary) -> void:
	pass


## Called every tick, after commands, in module order.
func step(_sim: Sim) -> void:
	pass


## Everything this module owns, in a fixed order, for the state hash.
func state() -> Array:
	return []
