class_name SystemsSide
extends RefCounted
## The Systems module's state for one ship world ("player" or "enemy"): bracing layers and their
## recharge timer, the coolant bill, plus room lookups cached from the ship and the system table.
## Holds no reference to the ShipWorld (only its instance id, to notice a new enemy ship), so
## nothing here can form a reference cycle.

var world_id: int = 0  ## Instance id of the ShipWorld this was built for (not hashed).

# Cached lookups (rebuilt with the side; not hashed: they follow from the ship and the data).
var reactor: int = -1
var helm: int = -1
var bracing: int = -1
var weapons: int = -1
var drill: int = -1
var coolant: int = -1
var has_sys: PackedByteArray = PackedByteArray()  ## 1 for rooms with a system other than "none".
var fail_j: PackedInt64Array = PackedInt64Array()  ## Room energy at which the system fails (fail_c in joules).
var recover_j: PackedInt64Array = PackedInt64Array()  ## Below this energy a failed system recovers.
var needs_crew: PackedByteArray = PackedByteArray()
var bonus: PackedFloat64Array = PackedFloat64Array()
var powered: PackedInt32Array = PackedInt32Array()  ## Rooms that draw reactor power, in room order.
var cut_order: PackedInt32Array = PackedInt32Array()  ## The same rooms, lowest priority (cut first) first.

# State (hashed).
var layers: int = 0  ## Bracing layers ready to absorb a hit.
var recharge_ticks: int = 0  ## Ticks spent recharging the next layer.
var carry_j: int = 0  ## Cooled joules not yet billed as a whole coolant unit.
var charged_j: int = 0  ## hazards.cooled_j already taken into the bill.
var units_used: int = 0  ## Coolant units billed so far.
var empty_warned: bool = false  ## coolant_empty was emitted and coolant has not come back since.


func state() -> Array:
	return [layers, recharge_ticks, carry_j, charged_j, units_used, empty_warned]
