class_name CombatSim
extends SimModule
## Real-time combat with pause, in the rock. A rival tower (sim.enemy, a ShipWorld built from ship
## data, so it has rooms, systems, crew on auto, fire, breaches and heat like yours) stands beside the
## player's, left or right (stream "combat"), with combat.rock_gap_m of rock between the hulls.
## Geometry is world meters in the player's ship space: the player's origin is (0, 0), the enemy's is
## enemy_origin. Hull: the player's is run.resources.hull, the enemy's is kept here.
##
## Per tick in the "combat" phase, in this order:
##   1. enemy AI at 4 Hz (EnemyAI: power by priority, targeting);
##   2. weapons, player side then enemy side: the weapons system's effective bars are handed to
##      weapons in slot order; powered slots charge at weapon_bonus, unpowered ones lose charge
##      slowly; a charged, aimed slot fires a volley (charges spend one ammo unit per volley);
##      projectiles and charges fly as tick countdowns, beams strike at once (CombatHits);
##   3. rounds in flight count down in spawn order and strike on arrival (CombatHits.projectile);
##   4. flee progress (needs drill bars and a manned helm; paused while either is missing);
##   5. victory (enemy hull 0 or every enemy crew member dead): loot, back to idle or, for the
##      boss, the run is won. Defeat is RunState's job (hull 0, crew dead); in scenario mode, where
##      RunState judges nothing, the fight ends "fight_lost" instead.
## Commands: {"type": "target", "weapon": slot, "room": "<enemy room id>"} ("" clears) and
## {"type": "flee"}. Tuning: game/data/tuning/combat.json. Weapons: game/data/weapons/<id>.json.

const COMMANDS: Array[String] = ["target", "flee"]
const TUNING_KEYS: Array[String] = [
	"combat.rock_gap_m", "combat.unpowered_decay_s_per_s", "combat.burst_gap_s", "combat.beam_show_s",
	"combat.hit_fire_level", "combat.flee_s", "combat.flee_drill_bars",
	"combat.loot_cells_chance", "combat.loot_cells_max_units",
	"combat.loot_charges_chance", "combat.loot_charges_max_units", "combat.loot_weapon_chance",
	"combat.loot_boss_scale",
]

var active: bool = false
var enemy_id: String = ""
var boss: bool = false
var enemy_hull: int = 0
var enemy_hull_max: int = 0
var enemy_on_right: bool = true
var enemy_origin: Vector2 = Vector2.ZERO  ## The enemy ship's origin in the player's ship space (m).
var flee_ticks: int = -1  ## Ticks of flee progress so far; -1 when not fleeing.
var started_tick: int = 0
var player_side: CombatSide = CombatSide.new()
var enemy_side: CombatSide = CombatSide.new()
var shots: Projectiles = Projectiles.new()
var last_result: String = ""  ## "won", "fled", "lost" or "" (for bots and the view).
var rockfall_ticks: PackedInt32Array = PackedInt32Array([-1, -1])  ## Rockfall seam: ticks to the next fall, [player, rival] (-1: none drawn).

var _db: DataDB
var _ai: EnemyAI = null
var _return_phase: String = "idle"
var _gap_m: float = 14.0
var _decay_s: float = 0.0
var _burst_ticks: int = 1
var _beam_ticks: int = 1
var _fire_level: float = 0.25
var _flee_total: int = 1
var _flee_bars: int = 2
var _seg: PackedVector2Array = PackedVector2Array()
var _rf_serial: int = -1  ## RunState.env_serial the rockfall rhythm was drawn for.
var _rf_warn: int = 72  ## The drill's rockfall tuning, reused: warning, hull and system damage.
var _rf_hull: int = 1
var _rf_bars: float = 0.5


func _init(db: DataDB) -> void:
	_rf_warn = maxi(1, roundi(db.tune("drill.rockfall_warn_s") * Sim.TICK_HZ))
	_rf_hull = maxi(0, roundi(db.tune("drill.rockfall_hull_pts")))
	_rf_bars = maxf(0.0, db.tune("drill.rockfall_sys_bars"))
	_db = db
	_gap_m = db.tune("combat.rock_gap_m")
	_decay_s = db.tune("combat.unpowered_decay_s_per_s") * Sim.DT
	_burst_ticks = maxi(1, roundi(db.tune("combat.burst_gap_s") * Sim.TICK_HZ))
	_beam_ticks = maxi(1, roundi(db.tune("combat.beam_show_s") * Sim.TICK_HZ))
	_fire_level = db.tune("combat.hit_fire_level")
	_flee_total = maxi(1, roundi(db.tune("combat.flee_s") * Sim.TICK_HZ))
	_flee_bars = roundi(db.tune("combat.flee_drill_bars"))


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


func apply(sim: Sim, cmd: Dictionary) -> void:
	var kind: String = str(cmd.get("type", ""))
	if not active or sim.run.phase != "combat" or sim.enemy == null:
		sim.emit("bad_command", {"type": kind, "why": "not in a fight"})
		return
	match kind:
		"target":
			var slot: int = int(cmd.get("weapon", -1))
			var rid: String = str(cmd.get("room", ""))
			var ri: int = -1 if rid.is_empty() else sim.enemy.ship.room_index(rid)
			if slot < 0 or slot >= player_side.size() or (ri < 0 and not rid.is_empty()):
				sim.emit("bad_command", {"type": kind, "why": "no such weapon slot or enemy room"})
				return
			player_side.set_target(slot, ri)
			sim.emit("target", {"weapon": slot, "room": rid})
		"flee":
			if flee_ticks >= 0:
				return
			var why: String = _flee_blocker(sim)
			if not why.is_empty():
				sim.emit("bad_command", {"type": kind, "why": why})
				return
			flee_ticks = 0
			sim.emit("flee_start", {"seconds": float(_flee_total) / Sim.TICK_HZ})


## Start a fight against a ship from the ships table. Called by events (after the page closes) and by
## the run at fight and gate nodes. Unknown ships are refused and the run goes back to idle.
func start_fight(sim: Sim, p_enemy_id: String, p_boss: bool) -> void:
	if sim.run.is_over():
		return
	if active:
		sim.emit("bad_command", {"type": "fight", "why": "already in a fight"})
		return
	if not _db.ships.has(p_enemy_id):
		sim.emit("bad_command", {"type": "fight", "why": "no ship \"%s\"" % p_enemy_id})
		if sim.run.mode == "run":
			sim.run.set_phase(sim, "idle")
		return
	_return_phase = "scenario" if sim.run.phase == "scenario" else "idle"
	enemy_id = p_enemy_id
	boss = p_boss
	sim.enemy = ShipWorld.new(_db, _db.ships[p_enemy_id], "enemy")
	enemy_hull_max = sim.enemy.ship.hull_max
	enemy_hull = enemy_hull_max
	enemy_on_right = sim.rng.get_stream("combat").randf() < 0.5
	var pw: float = _width(sim.ship)
	enemy_origin = Vector2(pw + _gap_m if enemy_on_right else -_gap_m - _width(sim.enemy.ship), 0.0)
	player_side = CombatSide.new()
	player_side.setup(_db.table("weapons"), sim.ship, true)
	enemy_side = CombatSide.new()
	enemy_side.setup(_db.table("weapons"), sim.enemy.ship, false)
	_ai = EnemyAI.new(sim.enemy.ship, sim.ship)
	shots.clear()
	flee_ticks = -1
	started_tick = sim.tick
	last_result = ""
	active = true
	sim.enemy.ship.rock_temp_c += sim.run.rock_add_c(sim.enemy)  # The same rock for both hulls (magma).
	rockfall_ticks = PackedInt32Array([-1, -1])
	_rf_serial = sim.run.env_serial
	sim.run.set_phase(sim, "combat")
	sim.emit("fight_start",{"enemy": enemy_id, "boss": boss, "side": "right" if enemy_on_right else "left"})


func step(sim: Sim) -> void:
	if not active or sim.run.phase != "combat":
		return
	if sim.enemy == null:
		_finish(sim, "lost")
		return
	if sim.tick % Sim.THINK_EVERY == 0:
		_ai.think(sim, sim.enemy, sim.player, enemy_side)
	_step_guns(sim, player_side, sim.player, sim.enemy, false)
	_step_guns(sim, enemy_side, sim.enemy, sim.player, true)
	_step_shots(sim)
	_step_rockfalls(sim, 0, sim.player)
	_step_rockfalls(sim, 1, sim.enemy)
	if flee_ticks >= 0 and _can_flee(sim):
		flee_ticks += 1
		if flee_ticks >= _flee_total:
			sim.emit("fled", {"enemy": enemy_id})
			_finish(sim, "fled")
			return
	if enemy_hull <= 0 or not _any_alive(sim.enemy.ship):
		_win(sim)
		return
	if sim.run.mode != "run" and (sim.run.get_res("hull") <= 0 or not _any_alive(sim.ship)):
		sim.emit("fight_lost", {"enemy": enemy_id})
		_finish(sim, "lost")


func state() -> Array:
	return [active, enemy_id, boss, enemy_hull, enemy_hull_max, enemy_on_right, enemy_origin.x,
		enemy_origin.y, flee_ticks, started_tick, last_result, _return_phase, player_side.state(),
		enemy_side.state(), shots.state(), rockfall_ticks, _rf_serial]


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	CombatLint.lint(db, errs)


# Read-only helpers for the view, bots and tests -------------------------------------------------

## Seconds of flee progress needed, and done so far (0 when not fleeing).
func flee_total_s() -> float:
	return float(_flee_total) / Sim.TICK_HZ


func flee_s() -> float:
	return maxf(0.0, float(flee_ticks)) / Sim.TICK_HZ


## A ship's origin in world meters (the player's ship space).
func origin(enemy_side_: bool) -> Vector2:
	return enemy_origin if enemy_side_ else Vector2.ZERO


## Every weapon of one side: id, name, kind, charge and its maximum (s), powered, target room id.
func weapons_view(sim: Sim, of_enemy: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sd: CombatSide = enemy_side if of_enemy else player_side
	var other: ShipWorld = sim.player if of_enemy else sim.enemy
	for i: int in range(sd.size()):
		var t: int = sd.target[i]
		out.append({"id": sd.defs[i].id, "name": sd.defs[i].name, "kind": sd.defs[i].kind,
			"charge_s": sd.charge[i], "charge_max_s": sd.defs[i].charge_s, "powered": sd.powered[i] == 1,
			"target": other.ship.rooms[t].id if t >= 0 and other != null else ""})
	return out


## Rounds in flight and beam traces: side, weapon, kind, start, end, progress (0 to 1), pos.
func shots_view() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(shots.size()):
		var sd: CombatSide = enemy_side if shots.from_enemy[i] == 1 else player_side
		out.append({"from": "enemy" if shots.from_enemy[i] == 1 else "player",
			"weapon": sd.defs[shots.slot[i]].id, "kind": sd.defs[shots.slot[i]].kind,
			"start": shots.start_of(i), "end": shots.end_of(i), "progress": shots.progress(i),
			"pos": shots.pos(i)})
	return out


# Internals -------------------------------------------------------------------------------------

func _step_guns(sim: Sim, sd: CombatSide, own: ShipWorld, other: ShipWorld, from_enemy: bool) -> void:
	if sd.size() == 0:
		return
	sd.charge_all(sim.systems.weapon_bars(own), Sim.DT * sim.systems.weapon_bonus(own), _decay_s)
	for i: int in range(sd.size()):
		var w: WeaponDef = sd.defs[i]
		var ri: int = sd.next_round(i, _burst_ticks)
		if ri >= 0:
			_launch(sim, own, other, from_enemy, i, ri, w)
			continue
		if not sd.ready(i):
			continue
		if not w.ammo.is_empty():
			var have: int = sd.enemy_ammo(w.ammo) if from_enemy else sim.run.get_res(w.ammo)
			if have <= 0:
				if sd.warn_ammo(i):
					own.emit(sim, "no_ammo", {"slot": i, "weapon": w.id, "res": w.ammo})
				continue
			if from_enemy:
				sd.spend_enemy_ammo(w.ammo)
			else:
				sim.run.add(sim, w.ammo, -1)
		var target: int = sd.target[i]
		own.emit(sim, "weapon_fired", {"slot": i, "weapon": w.id, "room": other.ship.rooms[target].id})
		sd.begin_volley(i)
		if w.is_beam():
			sd.next_round(i, _burst_ticks)  # A beam is its whole volley.
			_beam(sim, own, other, from_enemy, i, target, w)
		else:
			_launch(sim, own, other, from_enemy, i, sd.next_round(i, _burst_ticks), w)


## A projectile or charge leaves the attacker's weapons room for the center of the target room.
func _launch(sim: Sim, own: ShipWorld, other: ShipWorld, from_enemy: bool, slot: int, ri: int, w: WeaponDef) -> void:
	var wr: int = own.ship.room_with_system("weapons")
	var from: Vector2 = own.ship.rooms[wr if wr >= 0 else 0].rect.get_center() + origin(from_enemy)
	var to: Vector2 = other.ship.rooms[ri].rect.get_center() + origin(not from_enemy)
	var ticks: int = roundi(from.distance_to(to) / w.speed_m_s * Sim.TICK_HZ)
	shots.add(from_enemy, slot, ri, false, from, to, ticks)


func _beam(sim: Sim, own: ShipWorld, other: ShipWorld, from_enemy: bool, slot: int, ri: int, w: WeaponDef) -> void:
	var rooms: PackedInt32Array = CombatHits.beam_rooms(other.ship, ri, w.beam_len_m, _seg)
	var dmg: int = CombatHits.beam(sim, other, rooms, w, own.stream(sim, "combat"), _fire_level)
	_hurt(sim, not from_enemy, dmg)
	var o: Vector2 = origin(not from_enemy)
	shots.add(from_enemy, slot, ri, true, _seg[0] + o, _seg[1] + o, _beam_ticks)


func _step_shots(sim: Sim) -> void:
	var i: int = 0
	while i < shots.size():
		if shots.countdown(i) > 0:
			i += 1
			continue
		if shots.beam[i] == 0:
			var from_enemy: bool = shots.from_enemy[i] == 1
			var sd: CombatSide = enemy_side if from_enemy else player_side
			var own: ShipWorld = sim.enemy if from_enemy else sim.player
			var other: ShipWorld = sim.player if from_enemy else sim.enemy
			var dmg: int = CombatHits.projectile(sim, other, shots.room[i], sd.defs[shots.slot[i]], own.stream(sim, "combat"), _fire_level)
			_hurt(sim, not from_enemy, dmg)
		shots.remove_at(i)


## A rockfall seam in force (RunState.rockfall_band for that ship): each ship on its own rhythm, the
## intervals drawn from its side's "env/rockfall" stream, a warning rockfall_warn_s before each fall
## (CombatHits.rockfall).
func _step_rockfalls(sim: Sim, i: int, w: ShipWorld) -> void:
	if _rf_serial != sim.run.env_serial:
		_rf_serial = sim.run.env_serial
		rockfall_ticks[0] = -1
		rockfall_ticks[1] = -1
	var band: Vector2 = sim.run.rockfall_band(w)
	if band.y <= 0.0:
		rockfall_ticks[i] = -1
		return
	var rng: RandomNumberGenerator = w.stream(sim, "env/rockfall")
	if rockfall_ticks[i] < 0:
		rockfall_ticks[i] = Environments.next_rockfall_ticks(band, rng)
	rockfall_ticks[i] -= 1
	if rockfall_ticks[i] == _rf_warn:
		w.emit(sim, "rockfall_warn", {"in_s": snappedf(float(_rf_warn) / Sim.TICK_HZ, 0.01), "cause": "seam"})
	if rockfall_ticks[i] > 0:
		return
	rockfall_ticks[i] = Environments.next_rockfall_ticks(band, rng)
	_hurt(sim, not w.is_player(), CombatHits.rockfall(sim, w, rng, _rf_hull, _rf_bars))


## Take hull damage off the enemy (enemy_hit) or the player (run.resources.hull).
func _hurt(sim: Sim, enemy_hit: bool, dmg: int) -> void:
	if dmg <= 0:
		return
	if enemy_hit:
		var before: int = enemy_hull
		enemy_hull = maxi(0, enemy_hull - dmg)
		sim.emit("enemy_hull", {"amount": enemy_hull - before, "now": enemy_hull})
	else:
		sim.run.add(sim, "hull", -dmg)


## The player can dig out: enough drill bars and someone at the helm (checked every tick of a flight;
## progress pauses while either is missing).
func _can_flee(sim: Sim) -> bool:
	return sim.systems.drill_bars(sim.player) >= _flee_bars and sim.systems.is_manned(sim.player, sim.ship.room_with_system("helm"))


## Why the player cannot dig out right now, or "" if they can.
func _flee_blocker(sim: Sim) -> String:
	if sim.systems.drill_bars(sim.player) < _flee_bars:
		return "needs %d drill bars" % _flee_bars
	if not sim.systems.is_manned(sim.player, sim.ship.room_with_system("helm")):
		return "needs someone at the helm"
	return ""


func _win(sim: Sim) -> void:
	var loot: Dictionary = CombatLoot.roll(sim, _db, boss)
	sim.emit("fight_won", {"enemy": enemy_id, "boss": boss, "loot": loot})
	var was_boss: bool = boss
	_finish(sim, "won")
	if was_boss and sim.run.mode == "run":
		sim.run.end_run(sim, "won", "gate")


## Close the fight: the enemy ship goes, rounds in flight vanish, the run returns to idle (or to the
## scenario it came from).
func _finish(sim: Sim, result: String) -> void:
	last_result = result
	active = false
	sim.enemy = null
	_ai = null
	shots.clear()
	flee_ticks = -1
	sim.emit("fight_over", {"enemy": enemy_id, "result": result})
	if not sim.run.is_over():
		sim.run.set_phase(sim, _return_phase)


static func _width(ship: Ship) -> float:
	var w: float = 0.0
	for r: Room in ship.rooms:
		w = maxf(w, r.rect.end.x)
	return w


static func _any_alive(ship: Ship) -> bool:
	for c: CrewMember in ship.crew:
		if c.alive:
			return true
	return false
