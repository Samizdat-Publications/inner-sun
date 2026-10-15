class_name Projectiles
extends RefCounted
## Rounds in flight through the rock between the two hulls, plus beam traces kept briefly for the
## view. World meters in the player's ship space (the player's origin is 0,0; the enemy's origin is
## offset sideways). Flight is a deterministic tick countdown: a round goes from start to end in
## `total` ticks, so its position is an exact function of the tick and the view can draw it.
## Packed arrays in spawn order; removal keeps that order, so resolution order is fixed.

var from_enemy: PackedByteArray = PackedByteArray()  ## 1 if the enemy fired it.
var slot: PackedInt32Array = PackedInt32Array()  ## Firing weapon's slot.
var room: PackedInt32Array = PackedInt32Array()  ## Target room index in the struck ship.
var beam: PackedByteArray = PackedByteArray()  ## 1 for a beam trace (already resolved; view only).
var sx: PackedFloat64Array = PackedFloat64Array()
var sy: PackedFloat64Array = PackedFloat64Array()
var ex: PackedFloat64Array = PackedFloat64Array()
var ey: PackedFloat64Array = PackedFloat64Array()
var total: PackedInt32Array = PackedInt32Array()  ## Ticks from start to end.
var left: PackedInt32Array = PackedInt32Array()  ## Ticks until impact (or until the trace fades).


func size() -> int:
	return left.size()


func add(p_from_enemy: bool, p_slot: int, p_room: int, p_beam: bool, start: Vector2, end: Vector2, ticks: int) -> void:
	from_enemy.append(1 if p_from_enemy else 0)
	slot.append(p_slot)
	room.append(p_room)
	beam.append(1 if p_beam else 0)
	sx.append(start.x)
	sy.append(start.y)
	ex.append(end.x)
	ey.append(end.y)
	total.append(maxi(1, ticks))
	left.append(maxi(1, ticks))


func remove_at(i: int) -> void:
	from_enemy.remove_at(i)
	slot.remove_at(i)
	room.remove_at(i)
	beam.remove_at(i)
	sx.remove_at(i)
	sy.remove_at(i)
	ex.remove_at(i)
	ey.remove_at(i)
	total.remove_at(i)
	left.remove_at(i)


func clear() -> void:
	from_enemy.clear()
	slot.clear()
	room.clear()
	beam.clear()
	sx.clear()
	sy.clear()
	ex.clear()
	ey.clear()
	total.clear()
	left.clear()


## One tick off round i's countdown; returns the ticks left (0 means it lands now).
func countdown(i: int) -> int:
	left[i] -= 1
	return left[i]


## 0 at launch, 1 at impact.
func progress(i: int) -> float:
	return 1.0 - float(left[i]) / float(total[i])


func start_of(i: int) -> Vector2:
	return Vector2(sx[i], sy[i])


func end_of(i: int) -> Vector2:
	return Vector2(ex[i], ey[i])


## Where a round is now (a beam trace reports its end point).
func pos(i: int) -> Vector2:
	if beam[i] == 1:
		return end_of(i)
	return start_of(i).lerp(end_of(i), progress(i))


func state() -> Array:
	return [Array(from_enemy), Array(slot), Array(room), Array(beam), Array(sx), Array(sy), Array(ex),
		Array(ey), Array(total), Array(left)]
