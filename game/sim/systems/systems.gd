class_name Systems
extends SimModule
## Power and ship systems: the reactor's bars split across systems, damage from fire and hits, heat
## failure, and what each system does. System state sits on the rooms (Room.sys_*); this module owns
## the rules and steps every ship world (the player's and, in a fight, the enemy's) with the same
## code. Per-world state (bracing layers, the coolant bill) lives here in a SystemsSide per side.
## System types are data: game/data/systems/<id>.json. Tuning: game/data/tuning/systems.json.
##
## In world phases, per world, at the hazard rate (10 Hz: ticks where tick % Sim.HAZARD_EVERY == 0,
## just before that tick's hazard step reads cooling_scale and pump_scale), in this order:
##   1. heat failure: a room at or above its system's fail_c fails (0 effective bars) until it cools
##      below recover_c ("system_failed", "system_recovered");
##   2. fire damage: a burning room's system loses fire_damage_bars_per_s * fire level bars;
##   3. power: allocations are clamped to each system's intact bars, then, while the total exceeds the
##      reactor output, bars are cut lowest priority first ("power_cut"); cut bars stay cut;
##   4. coolant: hazards.cooling_scale = coolant effective bars / coolant_bars_full and
##      hazards.pump_scale = 1 with at least one bar (times the player's gear pump_x, RunState.gear_x);
##      in run mode the player's cooling is billed in
##      whole run "coolant" units (exact integer joules, remainder carried) and stops at zero units;
##   5. bracing: layers are capped at effective bars / bracing_bars_per_layer; a missing layer
##      recharges after bracing_recharge_s, one at a time.
## The coolant bill itself runs every tick (it only does work when hazards.cooled_j moved), so at any
## tick: units billed * coolant_j_per_unit + carried remainder == joules cooled up to the last tick.
## Commands (power, douse), damage_room and absorb_hit act at once.
## Douse (SystemsDouse): {"type": "douse", "room": id} vents one coolant unit into a burning room of
## the player's ship: fire down by douse_fire_level, up to douse_j of its heat removed (never below
## the room's design temperature), then douse_cooldown_s before the next. douse_ready(sim) says why
## not ("" when it may).
##
## Effects other modules read (all take the ShipWorld):
##   reactor_output, allocated, free_bars: reactor bars made, allocated, still free.
##   is_manned(world, room): a live crew member stands at that station (not climbing, job "go" or
##     none, path finished).
##   evasion: helm effective bars * evasion_per_bar when the helm is manned, else 0.
##   steer_rate_scale: 1 + steer_per_helm_bar * helm effective bars when manned, else 1.
##   side_cut_scale: side_cut_base + side_cut_per_helm_bar * helm effective bars when manned, else the
##     base (the drill's sideways motion is multiplied by it).
##   drill_bars, weapon_bars: effective bars. drill_bonus, weapon_bonus: a MULTIPLIER, 1 + manned_bonus
##     when the station is manned, else 1.
##   bracing_layers, max_layers; absorb_hit(sim, world) spends a layer ("bracing_absorbed").
##   damage_room(sim, world, room, bars): hit damage from combat ("system_damaged").
##   set_power(sim, world, room, bars): what the "power" command does, for enemy AI use.

const COMMANDS: Array[String] = ["power", "douse"]
const SIDES: Array[String] = ["player", "enemy"]
const NEVER_J: int = 1 << 62  ## A heat threshold no room reaches (systems without a definition).
const TUNING_KEYS: Array[String] = [
	"systems.fire_damage_bars_per_s", "systems.coolant_bars_full", "systems.coolant_j_per_unit",
	"systems.evasion_per_bar", "systems.steer_per_helm_bar", "systems.bracing_recharge_s",
	"systems.bracing_bars_per_layer", "systems.side_cut_base", "systems.side_cut_per_helm_bar",
	"systems.douse_cooldown_s", "systems.douse_fire_level", "systems.douse_j",
]

var _defs: Dictionary = {}  ## system id -> definition (from the systems table)
var _sides: Dictionary = {}  ## side -> SystemsSide
var _player: SystemsSide = null  ## Same objects as in _sides, kept for the hot path.
var _enemy: SystemsSide = null
var _fire_dmg: float = 0.0
var _cool_full: float = 2.0
var _j_per_unit: int = 1
var _evasion: float = 0.0
var _steer: float = 0.0
var _recharge_ticks: int = 1
var _bars_per_layer: int = 2
var _side_base: float = 1.0
var _side_per_bar: float = 0.0
# Douse (the player's ship only; SystemsDouse has the rule).
var douse_cooldown_ticks: int = 0  ## Ticks before the next douse is allowed (read-only for the view).
var douse_cooldown_full: int = 1
var douse_fire: float = 0.0
var douse_j: int = 0


func _init(db: DataDB) -> void:
	_defs = db.table("systems")
	_fire_dmg = db.tune("systems.fire_damage_bars_per_s")
	_cool_full = maxf(0.001, db.tune("systems.coolant_bars_full"))
	_j_per_unit = maxi(1, roundi(db.tune("systems.coolant_j_per_unit")))
	_evasion = db.tune("systems.evasion_per_bar")
	_steer = db.tune("systems.steer_per_helm_bar")
	_recharge_ticks = maxi(1, roundi(db.tune("systems.bracing_recharge_s") * Sim.TICK_HZ))
	_bars_per_layer = maxi(1, roundi(db.tune("systems.bracing_bars_per_layer")))
	_side_base = db.tune("systems.side_cut_base")
	_side_per_bar = db.tune("systems.side_cut_per_helm_bar")
	douse_cooldown_full = maxi(1, roundi(db.tune("systems.douse_cooldown_s") * Sim.TICK_HZ))
	douse_fire = db.tune("systems.douse_fire_level")
	douse_j = maxi(0, roundi(db.tune("systems.douse_j")))


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


## {"type": "power", "room": "<room id>", "bars": n} | {"type": "douse", "room": "<room id>"}: always
## the player's ship.
func apply(sim: Sim, cmd: Dictionary) -> void:
	if str(cmd.get("type", "")) == "douse":
		SystemsDouse.douse(sim, self, str(cmd.get("room", "")))
		return
	var ri: int = sim.ship.room_index(str(cmd.get("room", "")))
	if ri < 0:
		sim.emit("bad_command", {"type": "power", "why": "no such room"})
		return
	set_power(sim, sim.player, ri, int(cmd.get("bars", 0)))


func step(sim: Sim) -> void:
	if sim.enemy == null and _enemy != null:
		_sides.erase("enemy")
		_enemy = null
	if not sim.run.world_running():
		return
	if douse_cooldown_ticks > 0:
		douse_cooldown_ticks -= 1
	var pl: SystemsSide = _player if _player != null else side(sim.player)  # The player's world never changes.
	if sim.player.hazards.cooled_j != pl.charged_j and sim.run.mode == "run":
		_bill(sim, pl, sim.player.hazards.cooled_j)
	if sim.tick % Sim.HAZARD_EVERY != 0:
		return
	_step_world(sim, sim.player, pl)
	if sim.enemy != null:
		_step_world(sim, sim.enemy, side(sim.enemy))


func state() -> Array:
	var out: Array = []
	for s: String in SIDES:
		var sd: SystemsSide = _sides.get(s, null)
		out.append(sd.state() if sd != null else [])
	out.append(douse_cooldown_ticks)
	return out


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	SystemsLint.lint(db, errs)


# Commands and hooks for other modules ---------------------------------------------------------

## Set a room's allocation, clamped to its intact bars and to what the reactor has left after the
## other systems. Returns the bars now allocated. The reactor room itself cannot be powered.
func set_power(sim: Sim, world: ShipWorld, ri: int, bars: int) -> int:
	var sd: SystemsSide = side(world)
	if ri < 0 or ri >= world.ship.rooms.size():
		world.emit(sim, "bad_command", {"type": "power", "why": "no such room"})
		return 0
	var r: Room = world.ship.rooms[ri]
	if sd.has_sys[ri] == 0 or ri == sd.reactor:
		world.emit(sim, "bad_command", {"type": "power", "room": r.id, "why": "the reactor and rooms without a system take no power"})
		return r.sys_power
	var want: int = clampi(bars, 0, r.intact_bars())
	var left: int = maxi(0, reactor_output(world) - (allocated(world) - r.sys_power))
	r.sys_power = mini(want, left)
	r.sys_want = r.sys_power  # Only what was granted is remembered (a click with no free bars queues nothing).
	return r.sys_power


## Hit damage from combat: bars of capacity lost (clamped), then power is reconciled at once.
func damage_room(sim: Sim, world: ShipWorld, ri: int, bars: float) -> void:
	if ri < 0 or ri >= world.ship.rooms.size() or bars <= 0.0:
		return
	var r: Room = world.ship.rooms[ri]
	if r.sys_max <= 0:
		return
	var before: int = r.intact_bars()
	r.sys_damage = clampf(r.sys_damage + bars, 0.0, float(r.sys_max))
	world.emit(sim, "system_damaged", {"room": r.id, "bars": before - r.intact_bars(), "cause": "hit"})
	_reconcile(sim, world, side(world))


## Spend one bracing layer on a hit. Returns true if a layer absorbed it.
func absorb_hit(sim: Sim, world: ShipWorld) -> bool:
	var sd: SystemsSide = side(world)
	if sd.layers <= 0:
		return false
	sd.layers -= 1
	world.emit(sim, "bracing_absorbed", {"layers": sd.layers})
	return true


# Effects (read-only) ---------------------------------------------------------------------------

func reactor_output(world: ShipWorld) -> int:
	return _output(world, side(world))


func allocated(world: ShipWorld) -> int:
	var sd: SystemsSide = side(world)
	var total: int = 0
	for ri: int in sd.powered:
		total += world.ship.rooms[ri].sys_power
	return total


func free_bars(world: ShipWorld) -> int:
	return maxi(0, reactor_output(world) - allocated(world))


func is_manned(world: ShipWorld, ri: int) -> bool:
	if ri < 0:
		return false
	for c: CrewMember in world.ship.crew:
		if c.alive and c.room == ri and not c.climbing and (c.job_kind == "go" or c.job_kind == "") and c.path_i >= c.path.size():
			return true
	return false


func evasion(world: ShipWorld) -> float:
	var hi: int = side(world).helm
	if hi < 0 or not _crewed(world, hi):
		return 0.0
	return float(world.ship.rooms[hi].effective_bars()) * _evasion


func steer_rate_scale(world: ShipWorld) -> float:
	var hi: int = side(world).helm
	if hi < 0 or not _crewed(world, hi):
		return 1.0
	return 1.0 + _steer * float(world.ship.rooms[hi].effective_bars())


func side_cut_scale(world: ShipWorld) -> float:
	var hi: int = side(world).helm
	if hi < 0 or not _crewed(world, hi):
		return _side_base
	return _side_base + _side_per_bar * float(world.ship.rooms[hi].effective_bars())


## Why a douse cannot be ordered now ("" when it can). With a room id, also that room's own reasons.
func douse_ready(sim: Sim, room_id: String = "") -> String:
	return SystemsDouse.why_not(sim, self, room_id)


func coolant_bars(world: ShipWorld) -> int:
	return _bars(world, side(world).coolant)


func drill_bars(world: ShipWorld) -> int:
	return _bars(world, side(world).drill)


func drill_bonus(world: ShipWorld) -> float:
	return _bonus(world, side(world).drill)


func weapon_bars(world: ShipWorld) -> int:
	return _bars(world, side(world).weapons)


func weapon_bonus(world: ShipWorld) -> float:
	return _bonus(world, side(world).weapons)


func bracing_layers(world: ShipWorld) -> int:
	return side(world).layers


func max_layers(world: ShipWorld) -> int:
	var bi: int = side(world).bracing
	if bi < 0:
		return 0
	return world.ship.rooms[bi].effective_bars() / _bars_per_layer


## Coolant units billed so far, and the cooled joules not yet worth a whole unit (run mode, player).
func coolant_units_used(world: ShipWorld) -> int:
	return side(world).units_used


func coolant_carry_j(world: ShipWorld) -> int:
	return side(world).carry_j


## The per-side state for a world, built on first use and rebuilt when a new ship takes the side.
func side(world: ShipWorld) -> SystemsSide:
	var sd: SystemsSide = _sides.get(world.side, null)
	if sd == null or sd.world_id != world.get_instance_id():
		sd = _build(world)
		_sides[world.side] = sd
		if world.side == "player":
			_player = sd
		elif world.side == "enemy":
			_enemy = sd
	return sd


# Internals -------------------------------------------------------------------------------------

func _output(world: ShipWorld, sd: SystemsSide) -> int:
	if sd.reactor < 0:
		return 0
	var r: Room = world.ship.rooms[sd.reactor]
	# An overheated reactor limps at half output instead of shutting everything down (coolant included),
	# which made heat failures an instant death spiral.
	return r.intact_bars() / 2 if r.sys_failed else r.intact_bars()


func _bars(world: ShipWorld, ri: int) -> int:
	return world.ship.rooms[ri].effective_bars() if ri >= 0 else 0


func _bonus(world: ShipWorld, ri: int) -> float:
	if ri < 0 or side(world).bonus[ri] == 0.0 or not is_manned(world, ri):
		return 1.0
	return 1.0 + side(world).bonus[ri]


func _crewed(world: ShipWorld, ri: int) -> bool:
	return side(world).needs_crew[ri] == 0 or is_manned(world, ri)


func _build(world: ShipWorld) -> SystemsSide:
	var sd := SystemsSide.new()
	sd.world_id = world.get_instance_id()
	var rooms: Array[Room] = world.ship.rooms
	var n: int = rooms.size()
	sd.has_sys.resize(n)
	sd.fail_j.resize(n)
	sd.recover_j.resize(n)
	sd.needs_crew.resize(n)
	sd.bonus.resize(n)
	var prio := PackedInt32Array()
	prio.resize(n)
	for i: int in range(n):
		var r: Room = rooms[i]
		sd.fail_j[i] = NEVER_J
		sd.recover_j[i] = NEVER_J
		if r.system == "none":
			continue
		sd.has_sys[i] = 1
		var def: Dictionary = _defs.get(r.system, {})
		if def.has("fail_c"):
			# Integer thresholds: for whole joules e, e >= x exactly when e >= ceil(x).
			sd.fail_j[i] = ceili(float(def["fail_c"]) * r.heat_cap_j_per_k)
			sd.recover_j[i] = ceili(float(def.get("recover_c", def["fail_c"])) * r.heat_cap_j_per_k)
		sd.needs_crew[i] = 1 if bool(def.get("needs_crew", false)) else 0
		sd.bonus[i] = float(def.get("manned_bonus", 0.0))
		prio[i] = int(def.get("priority", 0))
		match r.system:
			"reactor":
				if sd.reactor < 0:
					sd.reactor = i
			"helm":
				if sd.helm < 0:
					sd.helm = i
			"bracing":
				if sd.bracing < 0:
					sd.bracing = i
			"weapons":
				if sd.weapons < 0:
					sd.weapons = i
			"drill":
				if sd.drill < 0:
					sd.drill = i
			"coolant":
				if sd.coolant < 0:
					sd.coolant = i
		if r.system != "reactor":
			sd.powered.append(i)
	# Cut order: lowest priority first, ties by room index (insertion sort: stable and tiny).
	for ri: int in sd.powered:
		var at: int = sd.cut_order.size()
		while at > 0 and prio[sd.cut_order[at - 1]] > prio[ri]:
			at -= 1
		sd.cut_order.insert(at, ri)
	sd.charged_j = world.hazards.cooled_j
	sd.layers = 0
	if sd.bracing >= 0:
		sd.layers = rooms[sd.bracing].effective_bars() / _bars_per_layer
	return sd


func _step_world(sim: Sim, world: ShipWorld, sd: SystemsSide) -> void:
	var rooms: Array[Room] = world.ship.rooms
	var dt: float = Sim.DT * Sim.HAZARD_EVERY
	for i: int in range(rooms.size()):
		if sd.has_sys[i] == 0:
			continue
		var r: Room = rooms[i]
		if r.sys_failed:
			if r.energy_j < sd.recover_j[i]:
				r.sys_failed = false
				world.emit(sim, "system_recovered", {"room": r.id, "system": r.system})
		elif r.energy_j >= sd.fail_j[i]:
			r.sys_failed = true
			world.emit(sim, "system_failed", {"room": r.id, "system": r.system})
		if r.fire > 0.0 and r.sys_damage < float(r.sys_max):
			var d0: float = r.sys_damage
			var d1: float = minf(float(r.sys_max), d0 + _fire_dmg * r.fire * dt)
			r.sys_damage = d1
			var lost: int = ceili(d1) - ceili(d0)
			if lost > 0:
				world.emit(sim, "system_damaged", {"room": r.id, "bars": lost, "cause": "fire"})
	_reconcile(sim, world, sd)
	_coolant(sim, world, sd)
	_bracing(world, sd)


## Broken bars give their power back; then, while the reactor cannot feed everything, cut bars from
## the lowest-priority systems first. Nothing is restored automatically.
func _reconcile(sim: Sim, world: ShipWorld, sd: SystemsSide) -> void:
	var rooms: Array[Room] = world.ship.rooms
	var total: int = 0
	for ri: int in sd.powered:
		var r: Room = rooms[ri]
		var cap: int = r.intact_bars()
		if r.sys_power > cap:
			r.sys_power = cap
		total += r.sys_power
	var out: int = _output(world, sd)
	if total <= out:
		_restore(sim, world, sd, total, out)
		return
	for ri: int in sd.cut_order:
		if total <= out:
			break
		var r: Room = rooms[ri]
		if r.sys_power <= 0:
			continue
		var take: int = mini(r.sys_power, total - out)
		r.sys_power -= take
		total -= take
		world.emit(sim, "power_cut", {"room": r.id, "bars": take})
	_restore(sim, world, sd, total, out)


## Bring power back toward each room's remembered allocation (after repairs, or when the reactor
## recovers), highest priority first, while the reactor has bars free.
func _restore(sim: Sim, world: ShipWorld, sd: SystemsSide, total: int, out: int) -> void:
	var free: int = out - total
	var i: int = sd.cut_order.size() - 1
	while i >= 0 and free > 0:
		var r: Room = world.ship.rooms[sd.cut_order[i]]
		var target: int = mini(r.sys_want, r.intact_bars())
		if r.sys_power < target:
			var give: int = mini(target - r.sys_power, free)
			r.sys_power += give
			free -= give
			world.emit(sim, "power_restored", {"room": r.id, "bars": give})
		i -= 1


## Bill the coolant the player's ship used (run mode): every coolant_j_per_unit joules cooled cost one
## run "coolant" unit, the remainder is carried. Exact integers; never more units than there are.
func _bill(sim: Sim, sd: SystemsSide, cooled_j: int) -> void:
	sd.carry_j += cooled_j - sd.charged_j
	sd.charged_j = cooled_j
	var pay: int = mini(sd.carry_j / _j_per_unit, sim.run.get_res("coolant"))
	if pay > 0:
		sim.run.add(sim, "coolant", -pay)
		sd.carry_j -= pay * _j_per_unit
		sd.units_used += pay


func _coolant(sim: Sim, world: ShipWorld, sd: SystemsSide) -> void:
	if sd.coolant < 0:
		return  # A ship without a coolant system keeps the hazard model's defaults.
	var h: HazardSim = world.hazards
	var bars: int = world.ship.rooms[sd.coolant].effective_bars()
	var scale: float = float(bars) / _cool_full
	if sim.run.mode == "run" and world.is_player():
		if sim.run.get_res("coolant") <= 0:
			scale = 0.0
			if not sd.empty_warned:
				sd.empty_warned = true
				world.emit(sim, "coolant_empty", {})
		else:
			sd.empty_warned = false
	h.cooling_scale = scale
	var pumps: float = sim.run.gear_x("pump_x") if world.is_player() else 1.0  # Gear: better pumps.
	h.pump_scale = pumps if bars >= 1 else 0.0


func _bracing(world: ShipWorld, sd: SystemsSide) -> void:
	if sd.bracing < 0:
		return
	var most: int = world.ship.rooms[sd.bracing].effective_bars() / _bars_per_layer
	if sd.layers >= most:
		sd.layers = most
		sd.recharge_ticks = 0
		return
	sd.recharge_ticks += Sim.HAZARD_EVERY
	if sd.recharge_ticks >= _recharge_ticks:
		sd.layers += 1
		sd.recharge_ticks = 0
