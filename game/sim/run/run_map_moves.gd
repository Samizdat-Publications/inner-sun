class_name RunMapMoves
extends RefCounted
## The run's map and travel on it, split out of RunState (M1d): building the layer's node map,
## choosing the next node (a drilling segment) and arriving at it. Static: every function works on the
## RunState passed in (its state stays there, so RunState.state() is unchanged) and holds no reference
## to it or to the Sim.


static func build_map(sim: Sim, run: RunState) -> void:
	run.map = MapGen.generate(run.layer, sim.rng.get_stream("map"))
	var rock: Dictionary = sim.db.table("rock").get(str(run.layer.get("rock", DrillSim.DEFAULT_ROCK)), {})
	Survey.add_to_map(run.map, run.layer, rock, sim.rng.get_stream("survey"), sim.rng.get_stream("survey/structure"))
	for row: Array in run.map:
		for n: Dictionary in row:
			run._index_of[str(n["id"])] = run.nodes.size()
			run.nodes.append(n)
			run._map_state.append([n["id"], n["type"], n["x_m"], n["enemy"], Array(n["links"] as PackedStringArray),
					(n["survey"] as Dictionary).values()])
	run.visited.resize(run.nodes.size())
	run.overtaken.resize(run.nodes.size())
	run._current = 0
	run.current_node = str(run.nodes[0]["id"])
	run.visited[0] = 1
	var pd: Dictionary = run.layer.get("pursuer", {})
	run.pursuer_row = float(pd.get("start_row", -1.5))
	run._rate_per_tick = float(pd.get("rows_per_s", 0.0)) / Sim.TICK_HZ
	run._rate_per_row_tick = float(pd.get("rows_per_s_per_row", 0.0)) / Sim.TICK_HZ
	run._rows_per_noise = float(pd.get("rows_per_noise", 0.0))
	run._overtaken_row = floori(run.pursuer_row)
	run._last_noise = sim.drill.noise_total
	run.scanner_rows = run._scanner(sim)


## RunState.choose_node: see there.
static func choose_node(sim: Sim, run: RunState, id: String) -> bool:
	var why: String = ""
	if run.mode != "run" or run.nodes.is_empty():
		why = "not a run"
	elif run.phase != "idle":
		why = "not idle (phase %s)" % run.phase
	elif not run.links_from_current().has(id):
		why = "\"%s\" is not linked from %s" % [id, run.current_node]
	if not why.is_empty():
		sim.emit("bad_command", {"type": "choose_node", "why": why})
		return false
	var from: Dictionary = run.nodes[run._current]
	var to: Dictionary = run.node(id)
	var reserve: bool = run.get_res("cells") <= 0
	sim.drill.speed_scale = run._reserve_factor if reserve else 1.0
	var rows: int = int(to["row"]) - int(from["row"])
	var ok: bool = sim.drill.begin_segment(sim, "%s-%s" % [from["id"], to["id"]],
			float(run.layer.get("row_depth_m", 36.0)) * float(rows), float(to["x_m"]) - float(from["x_m"]),
			str(run.layer.get("rock", DrillSim.DEFAULT_ROCK)), to.get("survey", {}) as Dictionary)
	if not ok:
		return false
	run._target = int(to["index"])
	run.target_node = id
	if not reserve:
		run.add(sim, "cells", -1)
	sim.emit("travel", {"from": from["id"], "to": id, "reserve": reserve})
	return true


## RunState.arrive: see there.
static func arrive(sim: Sim, run: RunState) -> void:
	if run._target < 0:
		run.set_phase(sim, "idle")  # A segment begun directly (tests): no node to arrive at.
		return
	run._current = run._target
	run._target = -1
	run.target_node = ""
	var n: Dictionary = run.nodes[run._current]
	run.current_node = str(n["id"])
	run.visited[run._current] = 1
	run.depth_m = float(run.layer.get("row_depth_m", 36.0)) * float(int(n["row"]))
	run.scanner_rows = run._scanner(sim)
	var kind: String = str(n["type"])
	sim.emit("arrived", {"node": run.current_node, "type": kind, "row": int(n["row"])})
	if run.overtaken[run._current] == 1:
		sim.emit("node_lost", {"node": run.current_node, "type": kind})
		run._strike(sim, "overtaken")
		run.set_phase(sim, "idle")
		return
	match kind:
		"event", "cavern", "hazard", "store":
			sim.encounter.start_node(sim, kind, run.event_row(int(n["row"])))
		"fight":
			sim.combat.start_fight(sim, str(n["enemy"]), false)
		"gate":
			sim.combat.start_fight(sim, str(n["enemy"]), true)
	if run.phase == "drill":
		run.set_phase(sim, "idle")  # No module took the node.
