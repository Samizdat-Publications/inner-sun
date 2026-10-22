class_name PolicyPresets
extends RefCounted
## The three policies' settings, split out of PolicyBot (M1d): PolicyBot.make_policy forwards here.


static func make(p_policy: String) -> PolicyBot:
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
