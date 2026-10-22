extends TestCase
## Combat rules: power, charging, bracing, charges and ammo, the beam, evasion, the enemy crew,
## victory and loot, fleeing, targeting commands and the lint. Whole fights, bots, replays and leaks
## are in test_combat_fights.gd.


## A run-mode sim with the fight started against `enemy`. Weapons get `weapon_bars` bars (the drill
## gives up its two, so 3 bars are free).
func _fight(enemy: String = "rival_light", weapon_bars: int = 2, overrides: Dictionary = {}, p_seed: int = 3, mode: String = "run") -> Sim:
	var s := Sim.new(db(overrides), p_seed, "light_drill", {"mode": mode})
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.push({"type": "power", "room": "weapons", "bars": weapon_bars})
	s.step()
	s.combat.start_fight(s, enemy, false)
	return s


## Take the rival's guns away (its AI then has nothing to aim), so a test sees only its own shots.
func _disarm(s: Sim) -> void:
	s.combat.enemy_side = CombatSide.new()


func _eroom(s: Sim, id: String) -> Room:
	return s.enemy.ship.rooms[s.enemy.ship.room_index(id)]


func _count(s: Sim, kind: String, side: String = "") -> int:
	var n: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind and (side.is_empty() or str(e.get("side", "player")) == side):
			n += 1
	return n


## Step until no round is in flight (or the fight ends).
func _land(s: Sim) -> void:
	var guard: int = 0
	while s.combat.active and s.combat.shots.size() > 0 and guard < 2000:
		s.step()
		guard += 1


func test_start_fight_builds_the_rival() -> void:
	var s: Sim = _fight()
	check_eq(s.run.phase, "combat", "the run is in combat")
	check(s.enemy != null and s.enemy.side == "enemy", "the enemy world exists")
	check_eq(s.combat.enemy_hull, 12, "rival_light starts with 12 hull")
	check(has_event(s, "fight_start"), "fight_start")
	var ox: float = s.combat.enemy_origin.x
	check(absf(ox - 22.0) < 0.001 or absf(ox + 22.0) < 0.001, "14 m of rock between 8 m wide hulls (origin %.2f)" % ox)
	check_eq(s.combat.player_side.size(), 2, "the light drill carries two weapons")
	check_eq(s.combat.enemy_side.size(), 1, "the rival carries one")
	s.combat.start_fight(s, "rival_heavy", false)
	check(has_event(s, "bad_command"), "a second fight is refused")
	var u := Sim.new(db(), 3, "light_drill", {"mode": "run"})
	u.combat.start_fight(u, "battleship", false)
	check_eq(u.run.phase, "idle", "an unknown ship is refused")
	check(u.enemy == null, "and nothing is built")


func test_weapons_need_power() -> void:
	var s: Sim = _fight("rival_light", 0)
	_disarm(s)
	s.push({"type": "target", "weapon": 0, "room": "weapons"})
	s.push({"type": "target", "weapon": 1, "room": "weapons"})
	run_seconds(s, 13.0)
	check_eq(_count(s, "weapon_fired", "player"), 0, "unpowered weapons never fire")
	check_eq(s.combat.player_side.charge[0], 0.0, "and never charge")
	s.push({"type": "power", "room": "weapons", "bars": 1})
	s.step()
	check_eq(s.combat.player_side.powered[0], 1, "one bar powers slot 0 (the borer)")
	check_eq(s.combat.player_side.powered[1], 0, "but not slot 1")
	run_seconds(s, 9.1)
	check_eq(_count(s, "weapon_fired", "player"), 1, "the borer fired after its 9 s charge")
	check_eq(s.combat.player_side.charge[1], 0.0, "the charge launcher stayed cold")
	s.push({"type": "power", "room": "weapons", "bars": 2})
	s.step()
	check_eq(s.combat.player_side.powered[1], 1, "two bars power both")
	s.combat.player_side.set_charge(0, 5.0)
	s.push({"type": "power", "room": "weapons", "bars": 0})
	run_seconds(s, 2.0)
	check(absf(s.combat.player_side.charge[0] - 4.0) < 0.02, "unpowered, the charge drains slowly (got %.3f)" % s.combat.player_side.charge[0])


func test_targeting_commands() -> void:
	var s: Sim = _fight()
	_disarm(s)
	s.push({"type": "target", "weapon": 0, "room": "bracing"})
	s.step()
	check_eq(s.combat.player_side.target[0], s.enemy.ship.room_index("bracing"), "slot 0 aims at the bracing")
	s.push({"type": "target", "weapon": 0, "room": ""})
	s.step()
	check_eq(s.combat.player_side.target[0], -1, "an empty room clears the target")
	s.push({"type": "target", "weapon": 5, "room": "bracing"})
	s.push({"type": "target", "weapon": 0, "room": "galley"})
	s.step()
	check_eq(_count(s, "bad_command"), 2, "bad slots and rooms are refused")
	var idle := Sim.new(db(), 3, "light_drill", {"mode": "run"})
	idle.push({"type": "target", "weapon": 0, "room": "bracing"})
	idle.push({"type": "flee"})
	idle.step()
	check_eq(_count(idle, "bad_command"), 2, "combat commands need a fight")
	check(Sim.known_commands().has("target") and Sim.known_commands().has("flee"), "commands are declared")


func test_bracing_absorbs_a_projectile_and_recharges() -> void:
	var s: Sim = _fight("rival_light", 2, {"systems.evasion_per_bar": 0.0})
	_disarm(s)
	var borer := WeaponDef.from_def(s.db.table("weapons")["borer_turret"])
	var rng: RandomNumberGenerator = s.enemy.stream(s, "combat")
	var hull: int = s.run.get_res("hull")
	check_eq(s.systems.bracing_layers(s.player), 1, "the light drill holds one layer")
	var dmg: int = CombatHits.projectile(s, s.player, s.ship.room_index("drill"), borer, rng, 0.25)
	check_eq(dmg, 0, "the first round is absorbed")
	check_eq(s.systems.bracing_layers(s.player), 0, "the layer is spent")
	check(has_event(s, "bracing_absorbed"), "bracing_absorbed")
	check_eq(room(s, "drill").sys_damage, 0.0, "an absorbed round does no system damage")
	dmg = CombatHits.projectile(s, s.player, s.ship.room_index("drill"), borer, rng, 0.25)
	check_eq(dmg, 1, "the second round gets through")
	s.combat._hurt(s, false, dmg)
	check_eq(s.run.get_res("hull"), hull - 1, "the player's hull is run.resources.hull")
	check_eq(room(s, "drill").sys_damage, 1.0, "and breaks a bar")
	run_seconds(s, 6.2)
	check_eq(s.systems.bracing_layers(s.player), 1, "the layer recharged after about 6 s")


func test_borer_volley_flies_and_strikes() -> void:
	var s: Sim = _fight("rival_light", 1, {"systems.evasion_per_bar": 0.0})
	_disarm(s)
	s.push({"type": "target", "weapon": 0, "room": "coolant"})
	s.step()
	s.combat.player_side.set_charge(0, 9.0)
	s.step()
	check_eq(_count(s, "weapon_fired", "player"), 1, "the borer fires when charged and aimed")
	check_eq(s.combat.shots.size(), 1, "the first slug is in flight")
	var v: Array[Dictionary] = s.combat.shots_view()
	check_eq(str(v[0]["from"]), "player", "the view sees who fired it")
	var start: Vector2 = v[0]["start"]
	var end: Vector2 = v[0]["end"]
	check(start.distance_to(Vector2(6.0, 4.5)) < 0.001, "it leaves the player's weapons room")
	check(end.distance_to(s.combat.enemy_origin + Vector2(2.0, 7.5)) < 0.001, "for the enemy coolant room")
	run_seconds(s, 0.31)
	check_eq(s.combat.shots.size(), 2, "the second slug follows 0.3 s later")
	var p0: float = s.combat.shots.progress(0)
	s.step()
	check_gt(s.combat.shots.progress(0), p0, "rounds advance every tick")
	_land(s)
	check_eq(s.combat.enemy_hull, 11, "one slug absorbed by the rival's layer, one got through")
	check_eq(_count(s, "bracing_absorbed", "enemy"), 1, "the enemy layer took the first")


func test_charges_ignore_bracing_and_spend_ammo() -> void:
	var s: Sim = _fight("rival_light", 2, {"systems.evasion_per_bar": 0.0})
	_disarm(s)
	var charges: int = s.run.get_res("charges")
	s.push({"type": "target", "weapon": 1, "room": "bracing"})
	s.step()
	s.combat.player_side.set_charge(1, 12.0)
	s.step()
	check_eq(s.run.get_res("charges"), charges - 1, "one charge spent per shot")
	var layers: int = s.systems.bracing_layers(s.enemy)
	check_eq(layers, 1, "the rival still has its layer")
	_land(s)
	check_eq(s.combat.enemy_hull, 10, "the charge did 2 damage through the bracing")
	check_eq(_count(s, "bracing_absorbed", "enemy"), 0, "no layer was spent")
	check_eq(_eroom(s, "bracing").sys_damage, 1.0, "and broke a bracing bar")
	run_seconds(s, 0.2)
	check_eq(s.systems.bracing_layers(s.enemy), 0, "one intact bar holds no layer")
	s.run.add(s, "charges", -s.run.get_res("charges"))
	s.combat.player_side.set_charge(1, 12.0)
	run_seconds(s, 1.0)
	check_eq(_count(s, "no_ammo"), 1, "out of charges: warned once")
	check_eq(s.combat.shots.size(), 0, "and nothing fired")
	check_eq(s.combat.player_side.charge[1], 12.0, "the launcher stays charged")


func test_beam_is_reduced_by_layers_and_heats_rooms() -> void:
	var s: Sim = _fight("rival_light", 2, {"systems.evasion_per_bar": 0.0})
	_disarm(s)
	var lance := WeaponDef.from_def(s.db.table("weapons")["thermal_lance"])
	var seg := PackedVector2Array()
	var rooms: PackedInt32Array = CombatHits.beam_rooms(s.enemy.ship, s.enemy.ship.room_index("bridge"), lance.beam_len_m, seg)
	var names: Array[String] = []
	for ri: int in rooms:
		names.append(s.enemy.ship.rooms[ri].id)
	check_eq(names, ["bridge", "reactor", "coolant"], "the lance sweeps down the left column")
	check(seg[0].is_equal_approx(Vector2(2.0, 1.5)) and seg[1].is_equal_approx(Vector2(2.0, 7.5)), "the sweep segment runs 6 m down from the bridge center")
	var e0: Array[int] = []
	for ri: int in rooms:
		e0.append(s.enemy.ship.rooms[ri].energy_j)
	var in0: int = s.enemy.hazards.energy_in_j
	var rng: RandomNumberGenerator = s.player.stream(s, "combat")
	var dmg: int = CombatHits.beam(s, s.enemy, rooms, lance, rng, 0.25)
	check_eq(dmg, 3, "2 damage per room minus 1 bracing layer, over 3 rooms")
	check_eq(s.systems.bracing_layers(s.enemy), 1, "the beam spends no layer")
	for k: int in range(rooms.size()):
		check_eq(s.enemy.ship.rooms[rooms[k]].energy_j - e0[k], lance.heat_j, "room %s took exactly the lance's heat" % names[k])
	check_eq(s.enemy.hazards.energy_in_j - in0, 3 * lance.heat_j, "the heat is booked as energy in")
	s.systems.absorb_hit(s, s.enemy)
	check_eq(CombatHits.beam(s, s.enemy, rooms, lance, rng, 0.25), 6, "with no layer each room takes the full 2")
	var heavy: Sim = _fight("rival_heavy", 2, {"systems.evasion_per_bar": 0.0})
	check_eq(heavy.systems.bracing_layers(heavy.enemy), 2, "the boss holds two layers")
	var r2: PackedInt32Array = CombatHits.beam_rooms(heavy.enemy.ship, 0, lance.beam_len_m, seg)
	var hot0: int = heavy.enemy.ship.rooms[0].energy_j
	check_eq(CombatHits.beam(heavy, heavy.enemy, r2, lance, heavy.player.stream(heavy, "combat"), 0.25), 0, "two layers block the beam's damage")
	check(has_event(heavy, "beam_blocked"), "beam_blocked")
	check_eq(heavy.enemy.ship.rooms[0].energy_j - hot0, lance.heat_j, "but the room is still heated")


func test_lance_fires_through_the_real_path() -> void:
	var s := Sim.new(db({"systems.evasion_per_bar": 0.0}), 4, "light_drill", {"mode": "run"})
	s.ship.weapons = PackedStringArray(["thermal_lance"])
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.push({"type": "power", "room": "weapons", "bars": 2})
	s.step()
	s.combat.start_fight(s, "rival_light", false)
	s.push({"type": "target", "weapon": 0, "room": "bridge"})
	s.step()
	s.combat.player_side.set_charge(0, 16.0)
	s.step()
	check_eq(s.combat.enemy_hull, 9, "the lance struck at once: 3 damage")
	check_eq(s.combat.shots.size(), 1, "a beam trace is kept for the view")
	check_eq(int(s.combat.shots.beam[0]), 1, "marked as a beam")
	run_seconds(s, 1.0)
	check_eq(s.combat.shots.size(), 0, "the trace fades")
	check_eq(s.combat.enemy_hull, 9, "and does no more damage")


func test_evasion_lowers_hits_with_a_fixed_seed() -> void:
	var misses: Array[int] = []
	for per_bar: float in [0.0, 0.2]:
		var s: Sim = _fight("rival_light", 2, {"systems.evasion_per_bar": per_bar}, 11)
		_disarm(s)
		s.systems.set_power(s, s.enemy, s.enemy.ship.room_index("coolant"), 0)
		s.systems.set_power(s, s.enemy, s.enemy.ship.room_index("bridge"), 2)
		check_eq(s.systems.evasion(s.enemy), per_bar * 2.0, "two manned helm bars")
		var w := WeaponDef.from_def(s.db.table("weapons")["charge_launcher"])
		w.crew_damage = 0.0
		w.fire_chance = 0.0
		w.breach_chance = 0.0
		var rng: RandomNumberGenerator = s.player.stream(s, "combat")
		var hits: int = 0
		for i: int in range(400):
			if CombatHits.projectile(s, s.enemy, s.enemy.ship.room_index("coolant"), w, rng, 0.25) > 0:
				hits += 1
		misses.append(400 - hits)
		check_eq(_count(s, "shot_missed", "enemy"), 400 - hits, "every miss is reported")
	check_eq(misses[0], 0, "no evasion, no misses")
	check(misses[1] > 120 and misses[1] < 200, "40%% evasion misses about 160 of 400 (got %d)" % misses[1])


func test_enemy_crew_repairs_and_fights_fires() -> void:
	var s: Sim = _fight("rival_light", 0)
	var r: Room = _eroom(s, "weapons")
	s.systems.damage_room(s, s.enemy, r.index, 1.0)
	s.enemy.hazards.ignite(s, s.enemy, _eroom(s, "bracing"), 0.3)
	run_seconds(s, 45.0)
	check_eq(_eroom(s, "bracing").fire, 0.0, "the rival crew put the fire out")
	check_eq(r.sys_damage, 0.0, "and repaired the weapons")
	check(_count(s, "fire_out", "enemy") >= 1, "fire_out from the enemy side")
	check(_count(s, "system_repaired", "enemy") >= 1, "system_repaired from the enemy side")


func test_enemy_ai_powers_and_targets() -> void:
	var s: Sim = _fight("rival_light", 0)
	var w: Room = _eroom(s, "weapons")
	s.systems.set_power(s, s.enemy, w.index, 0)
	run_seconds(s, 0.5)
	check_eq(w.sys_power, 1, "the AI put weapons back to its plan's first bar")
	check_eq(s.systems.allocated(s.enemy), 6, "using the whole reactor")
	var t: int = s.combat.enemy_side.target[0]
	check(t >= 0, "the enemy borer has a target")
	check(_count(s, "enemy_target", "enemy") >= 1, "targeting is reported")
	s.systems.damage_room(s, s.player, t, 10.0)
	run_seconds(s, 0.3)
	check(s.combat.enemy_side.target[0] != t, "the AI retargets when its target system is destroyed")
	s.systems.damage_room(s, s.enemy, s.enemy.ship.room_index("reactor"), 3.0)
	run_seconds(s, 0.3)
	check_eq(s.systems.allocated(s.enemy), 3, "after reactor damage the AI fits its plan to 3 bars")
	check_eq(w.sys_power, 1, "weapons keep their first bar")
	check_eq(_eroom(s, "bracing").sys_power, 2, "bracing comes next in the plan")


func test_victory_gives_loot_and_returns_to_idle() -> void:
	var s: Sim = _fight("rival_light", 2, {"systems.evasion_per_bar": 0.0})
	_disarm(s)
	var ore: int = s.run.get_res("ore")
	var gems: int = s.run.get_res("gems")
	s.combat.enemy_hull = 2
	s.push({"type": "target", "weapon": 1, "room": "coolant"})
	s.step()
	s.combat.player_side.set_charge(1, 12.0)
	run_seconds(s, 6.0)
	check(has_event(s, "fight_won"), "fight_won")
	check_eq(s.combat.last_result, "won", "result won")
	check_eq(s.run.phase, "idle", "back to idle")
	check(s.enemy == null, "the rival ship is gone")
	check(not s.combat.active and s.combat.shots.size() == 0, "nothing left in flight")
	check(s.run.get_res("ore") >= ore + 3, "ore looted")
	check(s.run.get_res("gems") >= gems + 4, "gems looted")
	var crew_win: Sim = _fight()
	for c: CrewMember in crew_win.enemy.ship.crew:
		CombatHits.harm_crew(crew_win, crew_win.enemy, c.room, 1000.0)
	crew_win.step()
	check_eq(crew_win.combat.last_result, "won", "killing every rival crew member wins too")
	var b: Sim = _fight("rival_heavy")
	b.combat.boss = true
	var ore_b: int = b.run.get_res("ore")
	b.combat.enemy_hull = 0
	b.step()
	check_eq(b.run.phase, "won", "beating the boss wins the run")
	check_eq(b.run.end_cause, "gate", "at the gate")
	check(b.run.get_res("ore") >= ore_b + 9, "the boss drops more (loot scaled)")


func test_flee_needs_drill_power_and_a_manned_helm() -> void:
	var s: Sim = _fight()  # The drill was cut to 0 bars to power weapons.
	_disarm(s)
	var ore: int = s.run.get_res("ore")
	s.push({"type": "flee"})
	s.step()
	check_eq(s.combat.flee_ticks, -1, "no drill power, no flight")
	check_eq(_count(s, "bad_command"), 1, "refused")
	s.push({"type": "power", "room": "weapons", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 2})
	s.push({"type": "assign", "crew": "vasquez", "room": "reactor"})
	run_seconds(s, 4.0)
	s.push({"type": "flee"})
	s.step()
	check_eq(s.combat.flee_ticks, -1, "nobody at the helm, no flight")
	s.push({"type": "assign", "crew": "vasquez", "room": "bridge"})
	run_seconds(s, 6.0)
	s.push({"type": "flee"})
	s.step()
	check(s.combat.flee_ticks >= 0, "drill bars and a pilot: digging out")
	check(has_event(s, "flee_start"), "flee_start")
	run_seconds(s, 14.0)
	check_eq(s.run.phase, "combat", "still digging after 14 s")
	run_seconds(s, 1.5)
	check(has_event(s, "fled"), "fled after about 15 s")
	check_eq(s.combat.last_result, "fled", "result fled")
	check_eq(s.run.phase, "idle", "back to idle")
	check(s.enemy == null, "the rival is left behind")
	check_eq(s.run.get_res("ore"), ore, "no loot for running")


func test_scenario_mode_fight_returns_to_the_scenario() -> void:
	var s: Sim = _fight("rival_light", 2, {}, 3, "scenario")
	check_eq(s.run.phase, "combat", "a scenario can stage a fight")
	s.run.add(s, "hull", -s.run.get_res("hull"))
	s.step()
	check(has_event(s, "fight_lost"), "with no RunState judge, a hull at 0 loses the fight")
	check_eq(s.run.phase, "scenario", "and the scenario goes on")


func test_lint_catches_broken_weapons_and_ai() -> void:
	var d: DataDB = db()
	d.table("weapons")["bad_gun"] = {"id": "bad_gun", "name": "Bad", "blurb": "", "kind": "laser", "power": 0,
		"charge_s": 0.0, "shots": 1, "damage": 1, "sys_damage": 1, "crew_damage": 0, "fire_chance": 2.0,
		"breach_chance": 0, "breach_m2": 0, "heat_kj": 0, "speed_m_s": 0, "beam_len_m": 0, "ammo": "plutonium",
		"pierces_bracing": "yes"}
	var ship: Dictionary = (d.ships["rival_light"] as Dictionary).duplicate(true)
	ship["id"] = "bad_rival"
	ship["weapons"] = ["borer_turret", "railgun", "charge_launcher", "borer_turret"]
	ship["ai"] = {"power": [{"room": "reactor", "bars": 2}, {"room": "galley", "bars": 1}], "target_weights": {"warp": 1.0}}
	d.ships["bad_rival"] = ship
	d.tuning.erase("combat.flee_s")
	var errs: PackedStringArray = PackedStringArray()
	CombatLint.lint(d, errs)
	var all: String = "\n".join(errs)
	for want: String in ["blurb", "laser", "\"power\"", "charge_s must be above zero", "a chance", "plutonium",
			"pierces_bracing", "railgun", "need 3 bars but the weapons room has 2", "4 weapons mounted in 2 slots", "\"reactor\" takes no power",
			"\"galley\" does not exist", "unknown system \"warp\"", "combat.flee_s"]:
		check(all.contains(want), "the lint reports %s" % want)
	var clean := PackedStringArray()
	CombatLint.lint(db(), clean)
	check(clean.is_empty(), "the real data is clean: " + " | ".join(clean))


## Gemini audit (plausible, overstated): power restore gives freed bars by system priority (coolant
## first) while a rival's plan puts weapons first. Checked here: a hit on the weapons never costs
## them more than the broken bar (the spare bar goes down the plan to coolant, as the plan says), and
## after the repair the weapons are back at their planned 3 bars within one AI think.
func test_rival_power_follows_its_plan_after_damage_and_repair() -> void:
	var s: Sim = _fight("rival_heavy")
	_disarm(s)
	run_seconds(s, 1.0)
	var wr: Room = _eroom(s, "weapons")
	check_eq(wr.sys_power, 3, "the plan powers the rival's weapons first, 3 bars")
	s.systems.damage_room(s, s.enemy, s.enemy.ship.room_index("weapons"), 1.0)
	var short: int = 0  # Ticks the weapons sit below their intact bars.
	for t: int in range(60):
		s.step()
		if wr.sys_power < wr.intact_bars():
			short += 1
	check_eq(short, 0, "the damaged weapons keep every intact bar")
	check_eq(_eroom(s, "coolant").sys_power, 2, "the plan gives the spare bar to coolant")
	wr.sys_damage = 0.0
	var back: int = -1
	for t: int in range(120):
		s.step()
		if wr.sys_power == 3:
			back = t
			break
	check(back >= 0 and back <= Sim.THINK_EVERY + 6, "repaired weapons are back at 3 bars within one AI think (took %d ticks)" % back)
	check_eq(_eroom(s, "coolant").sys_power, 1, "and coolant gives its bar back")
