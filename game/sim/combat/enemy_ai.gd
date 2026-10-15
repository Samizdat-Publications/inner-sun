class_name EnemyAI
extends RefCounted
## The rival crew's captain, thinking at 4 Hz (the crew-decision ticks). Power: walks the ship's
## "ai.power" list ({"room", "bars"} steps, each "bring this room up to n bars") against the reactor
## output and intact bars, lowers what must come down first, then raises in list order, all through
## Systems.set_power. Targeting: every slot without a target, or whose target room's system is
## destroyed, picks a player room at random, weighted by "ai.target_weights" per system type
## (destroyed systems weigh nothing). Only the enemy's own stream ("enemy/ai") is used, and the AI
## never pushes commands into the player's log. Holds no reference to the Sim or any ShipWorld.

const DEFAULT_WEIGHT: float = 1.0

var _steps_room: PackedInt32Array = PackedInt32Array()
var _steps_bars: PackedInt32Array = PackedInt32Array()
var _weights: Dictionary = {}  ## system id -> weight
var _want: PackedInt32Array = PackedInt32Array()  ## Scratch: desired bars per enemy room.
var _w: PackedFloat64Array = PackedFloat64Array()  ## Scratch: target weight per player room.


func _init(enemy_ship: Ship, player_ship: Ship) -> void:
	var ai: Dictionary = enemy_ship.source_def.get("ai", {})
	for step: Variant in ai.get("power", []):
		if not (step is Dictionary):
			continue
		var ri: int = enemy_ship.room_index(str((step as Dictionary).get("room", "")))
		if ri < 0:
			continue
		_steps_room.append(ri)
		_steps_bars.append(int((step as Dictionary).get("bars", 0)))
	var tw: Dictionary = ai.get("target_weights", {})
	for k: Variant in tw.keys():
		_weights[str(k)] = float(tw[k])
	_want.resize(enemy_ship.rooms.size())
	_w.resize(player_ship.rooms.size())


func think(sim: Sim, enemy: ShipWorld, player: ShipWorld, side: CombatSide) -> void:
	_power(sim, enemy)
	_aim(sim, enemy, player, side)


func _power(sim: Sim, enemy: ShipWorld) -> void:
	if _steps_room.is_empty():
		return  # No plan: keep the allocation from the ship data.
	var rooms: Array[Room] = enemy.ship.rooms
	var sy: Systems = sim.systems
	var budget: int = sy.reactor_output(enemy)
	_want.fill(0)
	for i: int in range(_steps_room.size()):
		var ri: int = _steps_room[i]
		var goal: int = mini(_steps_bars[i], rooms[ri].intact_bars())
		var add: int = clampi(goal - _want[ri], 0, budget)
		_want[ri] += add
		budget -= add
	# Lower first so the raises find free bars, then raise in plan order.
	for ri: int in range(rooms.size()):
		if rooms[ri].sys_max > 0 and rooms[ri].system != "reactor" and _want[ri] < rooms[ri].sys_power:
			sy.set_power(sim, enemy, ri, _want[ri])
	for i: int in range(_steps_room.size()):
		var ri: int = _steps_room[i]
		if _want[ri] > rooms[ri].sys_power:
			sy.set_power(sim, enemy, ri, _want[ri])


func _aim(sim: Sim, enemy: ShipWorld, player: ShipWorld, side: CombatSide) -> void:
	var rooms: Array[Room] = player.ship.rooms
	for slot: int in range(side.size()):
		var t: int = side.target[slot]
		if t >= 0 and (rooms[t].sys_max <= 0 or rooms[t].intact_bars() > 0):
			continue
		var total: float = 0.0
		for ri: int in range(rooms.size()):
			var r: Room = rooms[ri]
			var wt: float = 0.0
			if r.sys_max > 0 and r.intact_bars() > 0:
				wt = float(_weights.get(r.system, DEFAULT_WEIGHT))
			_w[ri] = wt
			total += wt
		if total <= 0.0:
			_w.fill(1.0)
			total = float(rooms.size())
		var roll: float = enemy.stream(sim, "ai").randf() * total
		var pick: int = rooms.size() - 1
		for ri: int in range(rooms.size()):
			roll -= _w[ri]
			if roll < 0.0:
				pick = ri
				break
		side.set_target(slot, pick)
		enemy.emit(sim, "enemy_target", {"slot": slot, "room": rooms[pick].id})
