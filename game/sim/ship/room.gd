class_name Room
extends RefCounted
## One room of a ship. Geometry is in meters in ship space (y grows downward, like Godot 2D).
## Water (millilitres) and heat (joules above 0 C) are integers so every transfer is exact.

const ML_PER_M3: float = 1_000_000.0

var id: String = ""
var index: int = 0
var name: String = ""
var rect: Rect2 = Rect2()
var depth_m: float = 3.0
var system: String = "none"
var has_pump: bool = false
var start_temp_c: float = 22.0

# Set by Ship and HazardSim when the ship is built.
var hull_area_m2: float = 0.0
var capacity_ml: int = 0
var heat_cap_j_per_k: float = 1.0

# Hazard state.
var energy_j: int = 0
var water_ml: int = 0
var fire: float = 0.0
var breach_m2: float = 0.0
var flooded_s: float = 0.0

# System state (one system per room; the Systems module owns the rules, see docs/ARCHITECTURE.md).
var sys_max: int = 0  ## Bars of capacity.
var sys_damage: float = 0.0  ## Bars lost to hits and fire; crew repair it.
var sys_power: int = 0  ## Bars allocated by the player or the AI.
var sys_failed: bool = false  ## Set by Systems while the room is too hot for its system to work.


## Bars this room's system can use right now.
func effective_bars() -> int:
	if sys_failed or sys_max <= 0:
		return 0
	return clampi(mini(sys_power, sys_max - ceili(sys_damage)), 0, sys_max)


## Bars that still work (capacity minus damage), whatever the allocation.
func intact_bars() -> int:
	return clampi(sys_max - ceili(sys_damage), 0, sys_max)


func floor_y() -> float:
	return rect.position.y + rect.size.y


func top_y() -> float:
	return rect.position.y


func floor_area_m2() -> float:
	return rect.size.x * depth_m


func capacity_m3() -> float:
	return rect.size.x * rect.size.y * depth_m


func level_m() -> float:
	return float(water_ml) / ML_PER_M3 / floor_area_m2()


func is_full() -> bool:
	return water_ml >= capacity_ml


func temp_c() -> float:
	return float(energy_j) / heat_cap_j_per_k


func set_temp_c(t: float) -> void:
	energy_j = roundi(t * heat_cap_j_per_k)


func center_floor() -> Vector2:
	return Vector2(rect.position.x + rect.size.x * 0.5, floor_y())
