class_name PolicyBot
extends Bot
## A whole-run player with a policy ("cautious", "greedy", "balanced"), through commands only. It
## reads the sim and pushes commands; it never changes the sim. Deterministic: no randomness at all,
## ties go to the first item in map, slot or stock order. Crew keep their own judgement, except that
## in a fight an unmanned helm gets a crew member ordered to it (released when the fight ends).
##
## Per phase (decisions every DECIDE_TICKS, drilling every 12 ticks through DrillBot):
## - idle: waits (up to wait_s) while fires, breaches or broken systems are being handled, then picks
##   the next node by policy (PolicyChoices.choose_node).
## - drill: DrillBot with this policy's detour greed, noise budget and steering range; drill bars by
##   policy, one bar less while coolant runs low. Bracing up (2 bars, one layer) when fault rock is
##   within fault_look_m (cautious: always). The charge launcher (weapons to 1 bar for the shot)
##   blasts an unburst gas pocket on the lane before the drill reaches it, and (greedy, balanced) a
##   vein or pocket in range whose blast circle is worth blast_min_value, keeping blast_keep charges.
##   A buried structure's crates and interior pull the lanes (DrillBot value_crate, value_interior;
##   cautious only a little) and its unopened crates count for loot blasts (blast_crate_value).
##   A mid-segment store or event (a structure's break-in) is handled like any other. The away miner
##   (MinerPlanner.decide) goes out for a rich vein off the lane while the pursuer is far enough behind
##   (miner_rows; cautious 3, greedy 1.5) and comes back early when it closes in or the miner is hurt.
## - any world phase: douse the worst fire above douse_at while coolant is above low_coolant.
## - dialog: the event option the policy scores best (PolicyChoices.choose_option).
## - store: one purchase per decision (PolicyChoices.next_purchase), then leave.
## - combat: drill off, weapons, helm, bracing and coolant up (re-powered after cuts), targets like
##   the smart fight bot (charges break the bracing, the rest go for the weapons, then the helm),
##   flee when losing badly (never from the gate).
## Power is set per phase by PolicyBot.wanted_power and applied as a diff: lowers first, then raises
## in priority order as far as free bars allow, so no command is wasted.

const DECIDE_TICKS: int = 15
const SYSTEMS: Array[String] = ["helm", "bracing", "weapons", "drill", "coolant"]

var policy: String = "balanced"
# Drilling.
var drill_bars: int = 3
var low_coolant: int = 5  ## Below this many coolant units, drill one bar lower (and never douse).
var fault_look_m: float = 6.0  ## Brace when fault rock is this close ahead.
var brace_always: bool = false  ## Keep a bracing layer up all the way down.
var blast_loot: bool = true  ## Blast veins and pockets in range for their ore and gems.
var blast_gas: bool = true  ## Blast gas pockets on the lane before the drill bursts them.
var blast_min_value: float = 50.0  ## Ore-equivalent value a loot blast must reach.
var blast_keep: int = 3  ## Charges never spent on blasts (kept for fights and the gate).
var blast_crate_value: float = 12.0  ## Loot blasts: value per unopened crate cell (a blast pays the crate in full).
var douse_at: float = 0.4  ## Douse a fire above this level.
# The away miner (read by MinerPlanner.decide).
var miner_on: bool = true
var miner_rows: float = 2.0  ## Send only with the pursuer's front at least this many rows behind.
var miner_recall_rows: float = 1.2  ## Recall when the front comes within this many rows.
var miner_recall_hp: float = 40.0  ## Recall when the miner drops below this hp.
var miner_min_value: float = 20.0  ## Ore-equivalent value a vein must reach (ore x 1, gems x value_gem).
var miner_value_ore: float = 1.0
var miner_value_gem: float = 3.0
var miner_off_line_m: float = 3.0  ## The vein must lie at least this far sideways of the ship's centre line.
var miner_next_tick: int = 0  ## The next tick a send is considered (once a second).
# Idle.
var wait_s: float = 8.0  ## Longest wait in idle for the crew to clear fires, breaches and damage.
# Combat.
var flee_hull_frac: float = 0.25  ## Flee below this hull fraction while the enemy is still healthy.
var flee_enemy_frac: float = 0.4  ## Only flee while the enemy has more than this hull fraction.
var flee_when_caught: bool = true  ## Also flee while the pursuer is striking and the enemy is still above half hull.
var charge_reserve: int = 2  ## Against rivals, charges at or below this are kept for the gate.
var gate_charges: int = 2  ## Store: extra charges stocked when the gate is four rows away or less.
var hot_c: float = 50.0  ## In a fight, coolant goes to its third bar (before bracing) above this room temperature.
# Choices (read by PolicyChoices).
var node_scores: Dictionary = {}  ## node type -> base score
var hurt_frac: float = 0.5  ## Below this hull fraction stores are worth a lot and fights avoided.
var fight_ok_frac: float = 0.6  ## Fights are welcome at or above this hull fraction.
var risk_down: float = 0.25  ## Weight on the worst outcome below the mean (risk aversion).
var risk_up: float = 0.0  ## Weight on the best outcome above the mean (risk seeking).
var gain_scale: float = 1.0  ## How much resource gains count.
var loss_scale: float = 1.0  ## How much hull, crew and hazards count.
var fight_value: float = -6.0  ## Value of an event option that starts a fight.
var repair_to_frac: float = 0.8  ## Store repairs bring the hull up to this fraction.
var gate_repair_frac: float = 1.0  ## ...and up to this one when the gate is two rows away or less.
var keep: Dictionary = {}  ## Store: resource -> units to stock up to.
var upgrades: Array[String] = []  ## Store: wanted extras in order ("gear:<id>", "system:<id>", "weapon", "crew").
var gem_reserve: int = 10  ## Gems kept back from extras.
var ore_reserve: int = 10  ## Ore kept back from extras (hull repairs at the next store).
var survey_weight: float = 2.0  ## Node score per unit of survey richness above 1 (revealed nodes).
var gem_bonus: float = 0.5  ## Node score when the survey found gems.
var gas_fear: float = 0.8  ## Node score lost when the survey found gas.
var water_fear: float = 0.5  ## Node score lost when the survey found water.
var structure_bonus: float = 0.8  ## Node score when the survey found a buried structure.

var _drill_bot: DrillBot = DrillBot.new()
var _next: int = 0
var _idle_since: int = -1
var _helm_order: String = ""  ## Crew id ordered to the helm in this fight ("" none).
var _helm_empty_thinks: int = 0
var _was_combat: bool = false
var _fault_ahead: bool = false
var _blast: Dictionary = {}  ## The aim point the bot wants to blast ({} none).


static func make_policy(p_policy: String) -> PolicyBot:
	var b := PolicyBot.new()
	b.policy = p_policy
	# Balanced, the reasonable middle; the other policies override below.
	b.node_scores = {"event": 1.2, "cavern": 1.3, "hazard": -0.5, "store": 0.4, "fight": 0.3, "deposit": 1.6, "gate": 50.0}
	b.keep = {"coolant": 12, "cells": 0, "bits": 1, "charges": 5}
	b.upgrades = ["gear:tungsten_head", "system:bracing", "gear:hull_plating", "system:reactor", "gear:diamond_head",
			"gear:pumps", "system:helm", "system:weapons", "weapon"]
	b.repair_to_frac = 0.9
	b.fight_ok_frac = 0.7
	b.flee_hull_frac = 0.3
	b.wait_s = 10.0
	b.ore_reserve = 15
	b._drill_bot.noise_budget = 80.0
	b._drill_bot.max_detour_m = 8.0
	b._drill_bot.level_steer = true
	b._drill_bot.max_steer_deg = 60.0
	b._drill_bot.side_look_m = 1.5
	b._drill_bot.cost_fault = 0.3
	match p_policy:
		"cautious":
			b.drill_bars = 3
			b.low_coolant = 6
			b.wait_s = 10.0
			b.flee_hull_frac = 0.4
			b.flee_enemy_frac = 0.3
			b.node_scores = {"event": 1.0, "cavern": 1.0, "hazard": -1.5, "store": 0.8, "fight": -2.0, "deposit": 1.0, "gate": 50.0}
			b.hurt_frac = 0.65
			b.fight_ok_frac = 0.85
			b.risk_down = 0.7
			b.loss_scale = 2.0
			b.fight_value = -20.0
			b.repair_to_frac = 1.0
			b.keep = {"coolant": 16, "cells": 1, "bits": 2, "charges": 6}
			b.upgrades = ["gear:tungsten_head", "gear:hull_plating", "system:bracing", "gear:pumps", "system:helm",
					"system:reactor"]
			b.gem_reserve = 20
			b.ore_reserve = 30
			b.survey_weight = 1.0
			b.gas_fear = 2.0
			b.water_fear = 1.5
			b._drill_bot.noise_budget = 50.0
			b._drill_bot.max_detour_m = 4.0
			b._drill_bot.max_steer_deg = 50.0
			b._drill_bot.cost_gas = 12.0
			b._drill_bot.cost_water = 8.0
			b._drill_bot.cost_fault = 1.5
			b._drill_bot.value_crate = 2.0
			b._drill_bot.value_interior = 0.1
			b.structure_bonus = 0.3
			b.brace_always = true
			b.blast_loot = false
			b.blast_keep = 3
			b.miner_rows = 3.0
			b.miner_min_value = 30.0
		"greedy":
			b.drill_bars = 4
			b.low_coolant = 4
			b.wait_s = 0.0
			b.flee_hull_frac = 0.15
			b.flee_enemy_frac = 0.5
			b.flee_when_caught = false
			b.charge_reserve = 0
			b.gate_charges = 1
			b.node_scores = {"event": 1.5, "cavern": 2.0, "hazard": 0.5, "store": 0.2, "fight": 2.0, "deposit": 2.5, "gate": 50.0}
			b.hurt_frac = 0.35
			b.fight_ok_frac = 0.4
			b.risk_down = 0.0
			b.risk_up = 0.4
			b.gain_scale = 1.8
			b.loss_scale = 0.6
			b.fight_value = 3.0
			b.repair_to_frac = 0.6
			b.gate_repair_frac = 0.8
			b.keep = {"coolant": 8, "cells": 0, "bits": 2, "charges": 6}
			b.upgrades = ["gear:tungsten_head", "gear:diamond_head", "weapon", "system:weapons", "system:drill",
					"system:reactor", "gear:hull_plating"]
			b.gem_reserve = 0
			b.ore_reserve = 0
			b.survey_weight = 3.0
			b.gem_bonus = 1.0
			b.gas_fear = 0.0
			b.water_fear = 0.0
			b._drill_bot.noise_budget = 200.0
			b._drill_bot.max_detour_m = 10.0
			b._drill_bot.max_steer_deg = 80.0
			b._drill_bot.cost_gas = 1.0
			b._drill_bot.cost_water = 1.5
			b._drill_bot.cost_fault = 0.0
			b._drill_bot.value_crate = 6.0
			b._drill_bot.value_interior = 0.5
			b.structure_bonus = 1.2
			b.blast_keep = 3
			b.blast_min_value = 40.0
			b.miner_rows = 2.0
			b.miner_min_value = 14.0
	return b


func act(sim: Sim) -> void:
	var run: RunState = sim.run
	if run.is_over():
		return
	if run.phase == "drill":
		_drill_bot.act(sim)
	if sim.tick < _next:
		return
	_next = sim.tick + DECIDE_TICKS
	var in_combat: bool = run.phase == "combat" and sim.combat.active and sim.enemy != null
	if _was_combat and not in_combat:
		_release_helm(sim)
	_was_combat = in_combat
	if run.phase == "drill":
		_dig_verbs(sim)
		var mc: Dictionary = MinerPlanner.decide(sim, self)
		if not mc.is_empty():
			sim.push(mc)
	else:
		_fault_ahead = false
		_blast = {}
	if run.world_running():
		_apply_power(sim, wanted_power(sim))
		_douse(sim)
	match run.phase:
		"idle":
			_idle(sim)
		"dialog":
			sim.push({"type": "choose", "option": PolicyChoices.choose_option(sim, self)})
		"store":
			var buy: Array = PolicyChoices.next_purchase(sim, self)
			if buy.is_empty():
				sim.push({"type": "leave"})
			else:
				sim.push({"type": "buy", "item": int(buy[0]), "qty": int(buy[1])})
		"combat":
			if in_combat:
				_combat(sim)
	if run.phase != "idle":
		_idle_since = -1


func _idle(sim: Sim) -> void:
	if _idle_since < 0:
		_idle_since = sim.tick
	if float(sim.tick - _idle_since) < wait_s * Sim.TICK_HZ and _crew_busy(sim):
		return
	var id: String = PolicyChoices.choose_node(sim, self)
	if not id.is_empty():
		sim.push({"type": "choose_node", "node": id})


## While drilling: is fault rock ahead (bracing), and is there something worth a charge? Fires at
## once when the launcher is ready; otherwise wanted_power raises the weapons for the next decision.
func _dig_verbs(sim: Sim) -> void:
	var d: DrillSim = sim.drill
	_fault_ahead = _drill_bot.fault_ahead(d, fault_look_m)
	_blast = {}
	var why: String = d.blast_ready(sim)
	if (why != "" and why != "power weapons") or sim.run.get_res("charges") <= blast_keep:
		return
	if blast_gas:
		_blast = BlastPlanner.gas_target(sim, d, _drill_bot.lookahead_m)
	if _blast.is_empty() and blast_loot:
		_blast = BlastPlanner.loot_target(sim, d, _drill_bot.value_ore, _drill_bot.value_gem, blast_min_value,
				blast_crate_value)
	if not _blast.is_empty() and why.is_empty():
		sim.push({"type": "blast", "x_m": float(_blast["x_m"]), "y_m": float(_blast["y_m"])})
		_blast = {}


## Douse the worst fire above douse_at while coolant is above the low mark.
func _douse(sim: Sim) -> void:
	if sim.run.get_res("coolant") <= low_coolant:
		return
	var worst: Room = null
	for r: Room in sim.ship.rooms:
		if r.fire > douse_at and (worst == null or r.fire > worst.fire):
			worst = r
	if worst != null and sim.systems.douse_ready(sim, worst.id).is_empty():
		sim.push({"type": "douse", "room": worst.id})


## Fires, breaches or system damage still being handled on board.
static func _crew_busy(sim: Sim) -> bool:
	for r: Room in sim.ship.rooms:
		if r.fire > 0.0 or r.breach_m2 > 0.0 or (r.sys_max > 0 and r.sys_damage > 0.0):
			return true
	return false


# Power -------------------------------------------------------------------------------------------

## Wanted bars per system for the current phase, in raise order: [[system, bars], ...].
func wanted_power(sim: Sim) -> Array:
	var run: RunState = sim.run
	if run.phase == "combat" and sim.combat.active:
		var guns: int = _gun_bars(sim)
		if sim.combat.flee_ticks >= 0 or _should_flee(sim):
			var fb: int = roundi(sim.db.tune("combat.flee_drill_bars"))
			return [["drill", fb], ["helm", 9], ["weapons", guns], ["coolant", 2], ["bracing", 9]]
		var cool: int = 3 if _hottest_c(sim) > hot_c else 2
		return [["weapons", guns], ["helm", 9], ["coolant", cool], ["bracing", 9], ["drill", 0]]
	if run.phase == "drill":
		var d: int = drill_bars
		if run.get_res("coolant") < low_coolant:
			d -= 1
		var w: int = 0 if _blast.is_empty() else 1
		var out: Array = [["coolant", 2]]
		if brace_always:
			out.append(["bracing", 2])
		out.append(["drill", d])
		if w > 0:
			out.append(["weapons", w])
		if _fault_ahead and not brace_always:
			out.append(["bracing", 2])
		out.append(["helm", 9])
		if not brace_always and not _fault_ahead:
			out.append(["bracing", 9])
		if w == 0:
			out.append(["weapons", 0])
		return out
	# Idle: drill off, cooling up so hot rooms recover while the crew repairs.
	return [["coolant", 3], ["helm", 9], ["bracing", 9], ["drill", 0], ["weapons", 0]]


## Bars for the guns: all of them, except that against rivals a charge weapon in the last slot is
## left unpowered while charges are at or below charge_reserve (saved for the gate).
func _gun_bars(sim: Sim) -> int:
	var side: CombatSide = sim.combat.player_side
	var bars: int = side.power_needed()
	var n: int = side.size()
	if n > 0 and not sim.combat.boss and side.defs[n - 1].kind == "charge" 			and sim.run.get_res(side.defs[n - 1].ammo) <= charge_reserve:
		bars -= side.defs[n - 1].power
	return bars


## The wanted list is a priority order over the reactor's output: each system's target is capped by
## its intact bars and by what the systems before it left (M1b, D027: before, bars held by helm and
## bracing were never freed, so the drill ran at about 1.6 bars whatever the policy wanted, and in a
## fight the guns got only what the drill released).
func _apply_power(sim: Sim, want: Array) -> void:
	var sy: Systems = sim.systems
	var ship: Ship = sim.ship
	var free: int = sy.free_bars(sim.player)
	var budget: int = sy.reactor_output(sim.player)
	var targets := PackedInt32Array()
	var rooms := PackedInt32Array()
	for w: Variant in want:
		var pair: Array = w
		var ri: int = ship.room_with_system(str(pair[0]))
		rooms.append(ri)
		var t: int = mini(mini(int(pair[1]), ship.rooms[ri].intact_bars()), budget) if ri >= 0 else 0
		budget -= t
		targets.append(t)
	for i: int in range(rooms.size()):
		var ri: int = rooms[i]
		if ri >= 0 and ship.rooms[ri].sys_power > targets[i]:
			free += ship.rooms[ri].sys_power - targets[i]
			sim.push({"type": "power", "room": ship.rooms[ri].id, "bars": targets[i]})
	for i: int in range(rooms.size()):
		var ri: int = rooms[i]
		if ri < 0 or free <= 0:
			continue
		var r: Room = ship.rooms[ri]
		if r.sys_power < targets[i]:
			var give: int = mini(targets[i] - r.sys_power, free)
			free -= give
			sim.push({"type": "power", "room": r.id, "bars": r.sys_power + give})


# Combat ------------------------------------------------------------------------------------------

func _combat(sim: Sim) -> void:
	var foe: Ship = sim.enemy.ship
	var wr: int = foe.room_with_system("weapons")
	var main: int = wr
	if wr < 0 or foe.rooms[wr].intact_bars() <= 0:
		main = foe.room_with_system("helm")
		if main < 0 or foe.rooms[main].intact_bars() <= 0:
			main = _first_intact(foe)
	var br: int = foe.room_with_system("bracing")
	var side: CombatSide = sim.combat.player_side
	for slot: int in range(side.size()):
		var t: int = main
		if side.defs[slot].kind == "charge" and br >= 0 and sim.systems.bracing_layers(sim.enemy) > 0:
			t = br
		if t >= 0 and side.target[slot] != t:
			sim.push({"type": "target", "weapon": slot, "room": foe.rooms[t].id})
	_man_helm(sim)
	if sim.combat.flee_ticks < 0 and _should_flee(sim) and _can_flee(sim):
		sim.push({"type": "flee"})


## The flee rule's own conditions (CombatSim): enough drill bars and a manned helm.
static func _can_flee(sim: Sim) -> bool:
	var fb: int = roundi(sim.db.tune("combat.flee_drill_bars"))
	return sim.systems.drill_bars(sim.player) >= fb and sim.systems.is_manned(sim.player, sim.ship.room_with_system("helm"))


func _should_flee(sim: Sim) -> bool:
	if sim.combat.boss or flee_hull_frac <= 0.0:
		return false
	var hull: float = float(sim.run.get_res("hull")) / maxf(1.0, float(sim.ship.hull_max))
	var foe: float = float(sim.combat.enemy_hull) / maxf(1.0, float(sim.combat.enemy_hull_max))
	if hull < flee_hull_frac and foe > flee_enemy_frac:
		return true
	if flee_when_caught and sim.run.caught and foe > 0.5:
		return true
	return _alive(sim.ship) <= 1 and foe > 0.5


## The hottest room's temperature (C).
static func _hottest_c(sim: Sim) -> float:
	var t: float = -INF
	for r: Room in sim.ship.rooms:
		t = maxf(t, r.temp_c())
	return t


static func _first_intact(ship: Ship) -> int:
	for r: Room in ship.rooms:
		if r.sys_max > 0 and r.intact_bars() > 0:
			return r.index
	return 0


static func _alive(ship: Ship) -> int:
	var n: int = 0
	for c: CrewMember in ship.crew:
		if c.alive:
			n += 1
	return n


## An unmanned helm for two seconds gets a crew member ordered to it: the one stationed there, else
## the first live crew member not fighting a fire, else the first live one.
func _man_helm(sim: Sim) -> void:
	var hi: int = sim.ship.room_with_system("helm")
	if hi < 0:
		return
	if sim.systems.is_manned(sim.player, hi):
		_helm_empty_thinks = 0
		return
	if not _helm_order.is_empty():
		var c0: CrewMember = sim.ship.crew_by_id(_helm_order)
		if c0 != null and c0.alive:
			return
		_helm_order = ""
	_helm_empty_thinks += 1
	if _helm_empty_thinks < 8:
		return
	var pick: CrewMember = null
	for c: CrewMember in sim.ship.crew:
		if c.alive and c.start_room == hi:
			pick = c
			break
	if pick == null:
		for c: CrewMember in sim.ship.crew:
			if c.alive and c.job_kind != "extinguish":
				pick = c
				break
	if pick == null:
		return
	_helm_order = pick.id
	sim.push({"type": "assign", "crew": pick.id, "room": sim.ship.rooms[hi].id})


func _release_helm(sim: Sim) -> void:
	_helm_empty_thinks = 0
	if _helm_order.is_empty():
		return
	sim.push({"type": "release", "crew": _helm_order})
	_helm_order = ""
