class_name RunSummary
extends RefCounted
## The run's results, split out of RunState (M1d): RunState.summary forwards here. Static and read
## only: it reads the RunState and the Sim passed in and holds neither.


## The run's results for the death screen, balance reports and Profile.merge_run (result, cause,
## depth_m). gained and spent sum the positive and negative resource events per resource. Dig verb
## counters (M1c): rockfalls_hit, rockfalls_absorbed, rockfall_hull (hull lost to them), blasts,
## blast_ore and blast_gems (paid by blasts), douses, steep_s (drilling seconds past 60 degrees).
## Structure counters (M1c round C): structures_placed (segments that held one), structures_entered,
## crates_opened, loot_units (resource units paid by crates into the run), traders_met, structure_events.
## Away miner counters (M1c round E): sorties (miners out), miner_backs (came back aboard),
## miner_deaths, haul_ore and haul_gems (paid on return), haul_lost (units lost with dead miners),
## sortie_first_s (whole seconds to the first sortie, -1 for none: finds seeds for miner captures).
static func build(sim: Sim, run: RunState) -> Dictionary:
	var gained: Dictionary = {}
	var spent: Dictionary = {}
	for r: String in RunState.RESOURCES:
		gained[r] = 0
		spent[r] = 0
	var fights_won: int = 0
	var verbs: Dictionary = {"rockfalls_hit": 0, "rockfalls_absorbed": 0, "rockfall_hull": 0, "blasts": 0,
		"blast_ore": 0, "blast_gems": 0, "douses": 0, "structures_placed": 0, "structures_entered": 0,
		"crates_opened": 0, "loot_units": 0, "traders_met": 0, "structure_events": 0, "sorties": 0, "sortie_first_s": -1, "miner_backs": 0,
		"miner_deaths": 0, "haul_ore": 0, "haul_gems": 0, "haul_lost": 0}
	for e: Dictionary in sim.events:
		var kind: String = str(e["kind"])
		if kind == "resource":
			var res: String = str(e["res"])
			var amt: int = int(e["amount"])
			if amt > 0:
				gained[res] = int(gained[res]) + amt
			else:
				spent[res] = int(spent[res]) - amt
		elif kind == "fight_won":
			fights_won += 1
		elif kind == "rockfall":
			if bool(e["absorbed"]):
				verbs["rockfalls_absorbed"] += 1
			else:
				verbs["rockfalls_hit"] += 1
				verbs["rockfall_hull"] += int(e["hull"])
		elif kind == "blast":
			verbs["blasts"] += 1
			verbs["blast_ore"] += int(e["ore"])
			verbs["blast_gems"] += int(e["gems"])
		elif kind == "doused":
			verbs["douses"] += 1
		elif kind == "structure_placed":
			verbs["structures_placed"] += 1
		elif kind == "structure_entered":
			verbs["structures_entered"] += 1
		elif kind == "loot":
			verbs["crates_opened"] += 1
			if not bool(e.get("miner", false)):
				verbs["loot_units"] += int(e["amount"])
		elif kind == "structure_outcome":
			if str(e["outcome"]) == "trader":
				verbs["traders_met"] += 1
			elif str(e["outcome"]) == "event":
				verbs["structure_events"] += 1
		elif kind == "miner_out":
			verbs["sorties"] += 1
			if int(verbs["sortie_first_s"]) < 0:
				verbs["sortie_first_s"] = floori(float(int(e["t"])) / float(Sim.TICK_HZ))
		elif kind == "miner_back":
			var paid: Dictionary = e["haul"]
			if not bool(e.get("called_off", false)):
				verbs["miner_backs"] += 1
			verbs["haul_ore"] += int(paid.get("ore", 0))
			verbs["haul_gems"] += int(paid.get("gems", 0))
		elif kind == "miner_lost":
			verbs["miner_deaths"] += 1
			var lost: Dictionary = e["haul"]
			for n: Variant in lost.values():
				verbs["haul_lost"] += int(n)
	var crew_lost: int = 0
	for c: CrewMember in sim.ship.crew:
		if not c.alive:
			crew_lost += 1
	var n_visited: int = 0
	var n_overtaken: int = 0
	for i: int in range(run.nodes.size()):
		n_visited += run.visited[i]
		n_overtaken += run.overtaken[i]
	var out: Dictionary = {
		"result": run.phase if run.is_over() else "unfinished",
		"cause": run.end_cause,
		"depth_m": snappedf(run.depth_m, 0.1),
		"rows_reached": run.current_row(),
		"rows_total": run.map.size(),
		"time_s": snappedf(sim.seconds(), 0.1),
		"gained": gained,
		"spent": spent,
		"fights_won": fights_won,
		"codex": Array(run.learned),
		"crew_lost": crew_lost,
		"nodes_visited": n_visited,
		"nodes_overtaken": n_overtaken,
		"strikes": run.strikes,
		"gear": Array(run.gear),
		"seed": sim.run_seed,
		"ship": sim.ship_id,
		"layer": run.layer_id,
		"steep_s": snappedf(float(sim.drill.steep_ticks) / Sim.TICK_HZ, 0.1),
	}
	out.merge(verbs)
	return out
