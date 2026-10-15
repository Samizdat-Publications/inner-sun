extends TestCase
## Whole fights: a simple gunner bot against the light rival and the gate boss over many seeds, the
## same seed giving the same fight, a replay of the command log matching, and no leaks.

const FIGHT_CAP_S: float = 300.0


## A run-mode sim with "sensible power" for a fight (drill off, helm 2, weapons 2) and the fight on.
func _setup(p_seed: int, enemy: String, boss: bool) -> Sim:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.push({"type": "power", "room": "bridge", "bars": 2})
	s.push({"type": "power", "room": "weapons", "bars": 2})
	s.step()
	s.combat.start_fight(s, enemy, boss)
	return s


## The gunner bot, at 4 Hz: every weapon aims at the enemy weapons room while its system works,
## then at the helm. Everything goes through sim.push.
func _bot(s: Sim) -> void:
	if s.enemy == null or s.tick % Sim.THINK_EVERY != 0:
		return
	var ship: Ship = s.enemy.ship
	var wr: int = ship.room_with_system("weapons")
	var want: int = wr if wr >= 0 and ship.rooms[wr].intact_bars() > 0 else ship.room_with_system("helm")
	for slot: int in range(s.combat.player_side.size()):
		if s.combat.player_side.target[slot] != want:
			s.push({"type": "target", "weapon": slot, "room": ship.rooms[want].id})


## A more careful player, for the report only: the charge launcher breaks the enemy bracing while it
## holds a layer, the borer goes for the weapons; and when power cuts starve the guns, coolant and
## then the helm give up a bar each.
func _smart_bot(s: Sim) -> void:
	if s.enemy == null or s.tick % Sim.THINK_EVERY != 0:
		return
	var ship: Ship = s.enemy.ship
	var wr: int = ship.room_with_system("weapons")
	var main: int = wr if wr >= 0 and ship.rooms[wr].intact_bars() > 0 else ship.room_with_system("helm")
	var br: int = ship.room_with_system("bracing")
	var want: Array[int] = [main, br if s.systems.bracing_layers(s.enemy) > 0 else main]
	for slot: int in range(mini(2, s.combat.player_side.size())):
		if s.combat.player_side.target[slot] != want[slot]:
			s.push({"type": "target", "weapon": slot, "room": ship.rooms[want[slot]].id})
	var guns: Room = room(s, "weapons")
	var need: int = mini(s.combat.player_side.power_needed(), guns.intact_bars())
	if guns.sys_power >= need:
		return
	if s.systems.free_bars(s.player) > 0:
		s.push({"type": "power", "room": "weapons", "bars": need})
	elif room(s, "coolant").sys_power > 1:
		s.push({"type": "power", "room": "coolant", "bars": room(s, "coolant").sys_power - 1})
	elif room(s, "bridge").sys_power > 1:
		s.push({"type": "power", "room": "bridge", "bars": 1})


## Play one fight to its end. Returns [won, seconds, hull lost, how it ended].
func _play(p_seed: int, enemy: String, boss: bool, smart: bool = false) -> Array:
	var s: Sim = _setup(p_seed, enemy, boss)
	var hull0: int = s.run.get_res("hull")
	var t0: int = s.tick
	var cap: int = roundi(FIGHT_CAP_S * Sim.TICK_HZ)
	while s.run.phase == "combat" and s.tick - t0 < cap:
		if smart:
			_smart_bot(s)
		else:
			_bot(s)
		s.step()
	var won: bool = s.combat.last_result == "won"
	var how: String = s.combat.last_result if not s.combat.last_result.is_empty() else s.run.end_cause
	if how.is_empty():
		how = "timeout"
	return [won, float(s.tick - t0) / Sim.TICK_HZ, hull0 - s.run.get_res("hull"), how]


func _series(enemy: String, boss: bool, seeds: int, smart: bool = false) -> Dictionary:
	var wins: int = 0
	var secs: float = 0.0
	var lost: int = 0
	var ends: Dictionary = {}
	var t0: int = Time.get_ticks_usec()
	for i: int in range(seeds):
		var r: Array = _play(100 + i, enemy, boss, smart)
		if bool(r[0]):
			wins += 1
		secs += float(r[1])
		lost += int(r[2])
		ends[str(r[3])] = int(ends.get(str(r[3]), 0)) + 1
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var out: Dictionary = {"enemy": enemy, "bot": "smart" if smart else "simple", "seeds": seeds, "wins": wins, "mean_s": secs / seeds,
		"mean_hull_lost": float(lost) / seeds, "ends": ends, "sim_s_per_wall_s": secs / maxf(0.001, ms / 1000.0)}
	print("COMBAT_SERIES %s" % JSON.stringify(out))
	return out


func test_simple_bot_beats_the_rival_and_the_boss_is_clearly_harder() -> void:
	var light: Dictionary = _series("rival_light", false, 20)
	var heavy: Dictionary = _series("rival_heavy", true, 20)
	check_gt(float(light["wins"]), 13.0, "the gunner bot wins most fights against rival_light: %s" % str(light))
	check_lt(float(light["mean_s"]), 150.0, "fights are not endless: %s" % str(light))
	check_lt(float(heavy["wins"]), float(light["wins"]) * 0.5, "the gate boss is clearly harder: light %s, heavy %s" % [str(light), str(heavy)])
	check_gt(float(heavy["mean_hull_lost"]), 2.0 * float(light["mean_hull_lost"]), "and costs far more hull")


## Report only (no balance claim): how a more careful player fares over the first 10 seeds.
func test_smart_bot_report() -> void:
	var light: Dictionary = _series("rival_light", false, 10, true)
	var heavy: Dictionary = _series("rival_heavy", true, 10, true)
	check_gt(float(light["wins"]) + 0.5, float(heavy["wins"]), "even played well, the boss is not easier than the rival")


func test_same_seed_same_fight() -> void:
	var a: Sim = _setup(42, "rival_light", false)
	var b: Sim = _setup(42, "rival_light", false)
	var c: Sim = _setup(43, "rival_light", false)
	for i: int in range(roundi(40.0 * Sim.TICK_HZ)):
		for s: Sim in [a, b, c]:
			_bot(s)
			s.step()
	check_eq(a.state_hash(), b.state_hash(), "the same seed and commands give the same fight")
	check(a.state_hash() != c.state_hash(), "another seed gives another fight")
	check(a.combat.enemy_hull < a.combat.enemy_hull_max or not a.combat.active, "the fight actually happened")


## Sim.replay rebuilds from commands alone; a fight is started by the run or an event (not a command),
## so this replays the same way: a fresh sim, the same start_fight at the same tick, then the log.
func test_replay_matches() -> void:
	var s: Sim = _setup(9, "rival_heavy", true)
	var start_tick: int = s.tick
	for i: int in range(roundi(30.0 * Sim.TICK_HZ)):
		_bot(s)
		if i == 600:
			s.push({"type": "power", "room": "weapons", "bars": 1})
		s.step()
	var again := Sim.new(db(), 9, "light_drill", {"mode": "run"})
	var log: Array[Dictionary] = s.command_log
	var k: int = 0
	while again.tick < s.tick:
		if again.tick == start_tick:
			again.combat.start_fight(again, "rival_heavy", true)
		while k < log.size() and int(log[k]["t"]) == again.tick:
			var cmd: Dictionary = log[k].duplicate()
			cmd.erase("t")
			again.push(cmd)
			k += 1
		again.step()
	check_eq(again.state_hash(), s.state_hash(), "replaying the command log gives the same fight")
	check_eq(again.combat.enemy_hull, s.combat.enemy_hull, "same enemy hull")
	check_eq(again.events.size(), s.events.size(), "same events")


## Hits move heat and water only through HazardSim, so both ships' books balance exactly in a fight.
func test_heat_and_water_are_conserved_in_a_fight() -> void:
	var s: Sim = _setup(21, "rival_heavy", true)
	var foe: ShipWorld = s.enemy
	var e_p: int = s.ship.total_energy_j() - (s.hazards.energy_in_j - s.hazards.energy_out_j)
	var w_p: int = s.ship.total_water_ml() - (s.hazards.water_in_ml - s.hazards.water_out_ml)
	var e_e: int = foe.ship.total_energy_j() - (foe.hazards.energy_in_j - foe.hazards.energy_out_j)
	var w_e: int = foe.ship.total_water_ml() - (foe.hazards.water_in_ml - foe.hazards.water_out_ml)
	for i: int in range(roundi(50.0 * Sim.TICK_HZ)):
		_smart_bot(s)
		s.step()
	check(has_event(s, "room_hit"), "rooms were hit")
	check_eq(s.ship.total_energy_j() - (s.hazards.energy_in_j - s.hazards.energy_out_j), e_p, "player heat: change equals in minus out")
	check_eq(s.ship.total_water_ml() - (s.hazards.water_in_ml - s.hazards.water_out_ml), w_p, "player water: change equals in minus out")
	check_eq(foe.ship.total_energy_j() - (foe.hazards.energy_in_j - foe.hazards.energy_out_j), e_e, "enemy heat: change equals in minus out")
	check_eq(foe.ship.total_water_ml() - (foe.hazards.water_in_ml - foe.hazards.water_out_ml), w_e, "enemy water: change equals in minus out")


func test_state_lists_weapons_shots_and_geometry() -> void:
	var s: Sim = _setup(5, "rival_heavy", true)
	run_seconds(s, 0.5)
	var st: Array = s.combat.state()
	check_eq(st[0], true, "active")
	check_eq(st[1], "rival_heavy", "enemy id")
	check_eq(st[3], 16, "enemy hull")
	var ps: Array = st[12]
	check_eq(ps[1], ["borer_turret", "charge_launcher"], "player weapons listed in slot order")
	var es: Array = st[13]
	check_eq(es[1], ["borer_turret", "thermal_lance"], "enemy weapons listed in slot order")
	var view: Array[Dictionary] = s.combat.weapons_view(s, true)
	check_eq(view.size(), 2, "the view lists the enemy guns")
	check_eq(str(view[1]["kind"]), "beam", "with their kinds")


func test_no_leaks_over_many_fights() -> void:
	var d: DataDB = db()
	var warm := Sim.new(d, 1, "light_drill", {"mode": "run"})
	warm.combat.start_fight(warm, "rival_light", false)
	run_seconds(warm, 1.0)
	warm = null
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i: int in range(30):
		var s := Sim.new(d, i, "light_drill", {"mode": "run"})
		s.combat.start_fight(s, "rival_heavy" if i % 2 == 0 else "rival_light", i % 2 == 0)
		s.push({"type": "power", "room": "drill", "bars": 0})
		s.push({"type": "power", "room": "weapons", "bars": 2})
		for slot: int in range(2):
			s.push({"type": "target", "weapon": slot, "room": "weapons"})
		run_seconds(s, 25.0)
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	check_lt(float(after - before), 50.0, "objects return to the baseline after 30 fights (before %d, after %d)" % [before, after])

