class_name CombatSide
extends RefCounted
## One side's guns in a fight: the weapon types in slot order and, per slot, the charge, whether it
## has power, its target room in the other ship and the volley in progress. Packed arrays indexed by
## slot, so the per-tick loop allocates nothing. Holds no reference to the Sim or any ShipWorld.

var is_player: bool = true
var defs: Array[WeaponDef] = []
var charge: PackedFloat64Array = PackedFloat64Array()  ## Seconds of charge built up (0 to def.charge_s).
var powered: PackedByteArray = PackedByteArray()  ## 1 when the slot has its bars this tick.
var target: PackedInt32Array = PackedInt32Array()  ## Room index in the other ship, -1 for none.
var burst_left: PackedInt32Array = PackedInt32Array()  ## Rounds of the current volley still to fire.
var burst_ticks: PackedInt32Array = PackedInt32Array()  ## Ticks until the next round of the volley.
var burst_room: PackedInt32Array = PackedInt32Array()  ## Room the current volley was aimed at.
var ammo_warned: PackedByteArray = PackedByteArray()  ## "no_ammo" was emitted for this slot.
var ammo: Dictionary = {}  ## Enemy only: resource -> units (the player's ammo is run.resources).
var _ammo_keys: PackedStringArray = PackedStringArray()  ## Fixed order for the hash.


## Build a side from a ship's mounted weapons. Unknown weapon ids are skipped (the lint reports them).
func setup(weapons: Dictionary, ship: Ship, p_is_player: bool) -> void:
	is_player = p_is_player
	for wid: String in ship.weapons:
		if weapons.has(wid):
			defs.append(WeaponDef.from_def(weapons[wid]))
	var n: int = defs.size()
	charge.resize(n)
	powered.resize(n)
	target.resize(n)
	burst_left.resize(n)
	burst_ticks.resize(n)
	burst_room.resize(n)
	ammo_warned.resize(n)
	for i: int in range(n):
		target[i] = -1
		burst_room[i] = -1
	if not is_player:
		var start: Dictionary = ship.source_def.get("start_resources", {})
		for r: String in RunState.RESOURCES:
			if start.has(r):
				ammo[r] = int(start[r])
				_ammo_keys.append(r)


func size() -> int:
	return defs.size()


## Hand out weapon-system bars in slot order: a slot is powered when the bars left cover its need.
func assign_power(bars: int) -> void:
	var left: int = bars
	for i: int in range(defs.size()):
		var need: int = defs[i].power
		if need <= left:
			powered[i] = 1
			left -= need
		else:
			powered[i] = 0


## One tick of charging: hand out the bars, then powered slots gain `gain_s` seconds of charge and
## unpowered slots lose `decay_s` (both clamped). Mutations stay inside this object so the packed
## arrays are written in place, never copied.
func charge_all(bars: int, gain_s: float, decay_s: float) -> void:
	assign_power(bars)
	for i: int in range(defs.size()):
		if powered[i] == 1:
			charge[i] = minf(defs[i].charge_s, charge[i] + gain_s)
		else:
			charge[i] = maxf(0.0, charge[i] - decay_s)


## Charged, powered, aimed and not already firing.
func ready(i: int) -> bool:
	return powered[i] == 1 and burst_left[i] == 0 and target[i] >= 0 and charge[i] >= defs[i].charge_s - 0.000001


## Start a volley at the current target: the charge is spent, the rounds are queued.
func begin_volley(i: int) -> void:
	charge[i] = 0.0
	burst_room[i] = target[i]
	burst_left[i] = defs[i].shots
	burst_ticks[i] = 0
	ammo_warned[i] = 0


## Advance slot i's volley one tick. Returns the room to fire a round at now, or -1.
func next_round(i: int, gap_ticks: int) -> int:
	if burst_left[i] <= 0:
		return -1
	burst_ticks[i] -= 1
	if burst_ticks[i] > 0:
		return -1
	burst_left[i] -= 1
	burst_ticks[i] = gap_ticks
	return burst_room[i]


func set_target(i: int, room: int) -> void:
	target[i] = room


func set_charge(i: int, seconds: float) -> void:
	charge[i] = clampf(seconds, 0.0, defs[i].charge_s)


func warn_ammo(i: int) -> bool:
	if ammo_warned[i] == 1:
		return false
	ammo_warned[i] = 1
	return true


## Bars the mounted weapons need all together.
func power_needed() -> int:
	var total: int = 0
	for w: WeaponDef in defs:
		total += w.power
	return total


func enemy_ammo(res: String) -> int:
	return int(ammo.get(res, 0))


func spend_enemy_ammo(res: String) -> void:
	if not ammo.has(res):
		ammo[res] = 0
		_ammo_keys.append(res)
	ammo[res] = maxi(0, int(ammo[res]) - 1)


func state() -> Array:
	var ids: Array = []
	for w: WeaponDef in defs:
		ids.append(w.id)
	var am: Array = []
	for k: String in _ammo_keys:
		am.append([k, int(ammo[k])])
	return [is_player, ids, Array(charge), Array(powered), Array(target), Array(burst_left),
		Array(burst_ticks), Array(burst_room), Array(ammo_warned), am]
