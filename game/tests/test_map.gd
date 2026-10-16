extends TestCase
## The layer node map (game/sim/run/map_gen.gd): shape, connectivity, no crossing edges, the store
## and fight guarantees, determinism per seed, the scanner reveal, and the layer lint.

const SEEDS: int = 300


func _layer() -> Dictionary:
	return db().table("layers")["crust"]


func _gen(layer: Dictionary, s: int) -> Array:
	return MapGen.generate(layer, RngStreams.new(s).get_stream("map"))


func test_shape_types_and_positions() -> void:
	var layer: Dictionary = _layer()
	for s: int in range(1, SEEDS + 1):
		var m: Array = _gen(layer, s)
		if m.size() != 10:
			failures.append("seed %d: %d rows, want 10" % [s, m.size()])
			continue
		var first: Array = m[0]
		var last: Array = m[9]
		check(first.size() == 1 and str((first[0] as Dictionary)["type"]) == "start", "seed %d: row 0 is one start node" % s)
		check(last.size() == 1 and str((last[0] as Dictionary)["type"]) == "gate", "seed %d: the last row is one gate node" % s)
		var index: int = 0
		for r: int in range(10):
			var row: Array = m[r]
			if r > 0 and r < 9 and (row.size() < 2 or row.size() > 3):
				failures.append("seed %d row %d: %d nodes, want 2 or 3" % [s, r, row.size()])
			var prev_x: float = -INF
			for i: int in range(row.size()):
				var n: Dictionary = row[i]
				check_eq(str(n["id"]), "r%dc%d" % [r, i], "seed %d: stable node id" % s)
				check_eq(int(n["index"]), index, "seed %d: flat index in map order" % s)
				index += 1
				var x: float = float(n["x_m"])
				if x < -12.0 or x > 12.0 or x <= prev_x:
					failures.append("seed %d %s: x %.2f out of range or out of order" % [s, n["id"], x])
				prev_x = x
				var t: String = str(n["type"])
				if r > 0 and r < 9 and not MapGen.NODE_TYPES.has(t):
					failures.append("seed %d %s: middle node type \"%s\"" % [s, n["id"], t])
				if (t == "fight" or t == "gate") and str(n["enemy"]).is_empty():
					failures.append("seed %d %s: a fight without an enemy" % [s, n["id"]])
		var gate: Dictionary = last[0]
		check_eq(str(gate["enemy"]), "rival_heavy", "seed %d: the gate enemy comes from the layer" % s)
		if failures.size() > 20:
			return


func test_connected_and_no_crossings() -> void:
	var layer: Dictionary = _layer()
	for s: int in range(1, SEEDS + 1):
		var m: Array = _gen(layer, s)
		var has_in: Dictionary = {"r0c0": true}
		var reach: Dictionary = {"r0c0": true}
		for r: int in range(m.size() - 1):
			var row: Array = m[r]
			var below: Array = m[r + 1]
			var col_of: Dictionary = {}
			for n: Dictionary in below:
				col_of[str(n["id"])] = int(n["col"])
			var edges: Array[Vector2i] = []
			for n: Dictionary in row:
				var links: PackedStringArray = n["links"]
				if links.is_empty():
					failures.append("seed %d %s: no way out" % [s, n["id"]])
				for to: String in links:
					if not col_of.has(to):
						failures.append("seed %d %s: link to %s is not in the next row" % [s, n["id"], to])
						continue
					edges.append(Vector2i(int(n["col"]), int(col_of[to])))
					has_in[to] = true
					if reach.has(str(n["id"])):
						reach[to] = true
			for a: Vector2i in edges:
				for b: Vector2i in edges:
					if a.x < b.x and a.y > b.y:
						failures.append("seed %d row %d: edges %s and %s cross" % [s, r, str(a), str(b)])
		for row: Array in m:
			for n: Dictionary in row:
				check(has_in.has(str(n["id"])), "seed %d %s: has a way in" % [s, n["id"]])
				check(reach.has(str(n["id"])), "seed %d %s: reachable from the start" % [s, n["id"]])
		if failures.size() > 20:
			return


func test_store_and_fight_guarantees() -> void:
	var layer: Dictionary = _layer()
	var stores: int = 0
	var fights: int = 0
	for s: int in range(1, SEEDS + 1):
		var m: Array = _gen(layer, s)
		check(MapGen.min_on_paths(m, "store", 2, 4) >= 1, "seed %d: every path meets a store in rows 2 to 4" % s)
		check(MapGen.min_on_paths(m, "store", 6, 8) >= 1, "seed %d: every path meets a store in rows 6 to 8" % s)
		check(not MapGen.has_store_pair(m), "seed %d: never two stores in a row (helper)" % s)
		var type_of: Dictionary = {}
		for row: Array in m:
			for n: Dictionary in row:
				type_of[str(n["id"])] = str(n["type"])
				stores += 1 if str(n["type"]) == "store" else 0
				fights += 1 if str(n["type"]) == "fight" else 0
		for row: Array in m:
			for n: Dictionary in row:
				if str(n["type"]) != "store":
					continue
				for to: String in (n["links"] as PackedStringArray):
					check(str(type_of[to]) != "store", "seed %d: %s and %s are two stores in a row" % [s, n["id"], to])
		check(MapGen.min_fights(m) >= 1, "seed %d: every path has at least one fight (plus the gate)" % s)
		if failures.size() > 20:
			return
	check_gt(float(stores) / SEEDS, 2.0, "stores are not only the guaranteed ones")
	check_lt(float(fights) / SEEDS, 6.0, "fights are occasional: few of the about 20 middle nodes")


func test_mining_first_node_mix() -> void:
	var layer: Dictionary = _layer()
	var count: Dictionary = {}
	var total: int = 0
	for t: String in MapGen.NODE_TYPES:
		count[t] = 0
	for s: int in range(1, SEEDS + 1):
		for row: Variant in _gen(layer, s):
			for n: Dictionary in (row as Array):
				var t: String = str(n["type"])
				if count.has(t):
					count[t] = int(count[t]) + 1
					total += 1
	print("MAP node mix over %d seeds: %s" % [SEEDS, str(count)])
	check_gt(float(count["deposit"]) / total, 0.15, "deposits are a big share of the nodes")
	check_gt(float(count["deposit"]), float(count["fight"]), "more deposits than fights")


func test_same_seed_same_map_and_run_uses_map_stream() -> void:
	var layer: Dictionary = _layer()
	check_eq(var_to_str(_gen(layer, 5)), var_to_str(_gen(layer, 5)), "the same seed gives the same map")
	var differs: bool = false
	for s: int in range(6, 12):
		differs = differs or var_to_str(_gen(layer, s)) != var_to_str(_gen(layer, 5))
	check(differs, "other seeds give other maps")
	var sim := Sim.new(db(), 5, "light_drill", {"mode": "run"})
	var want: Array = _gen(layer, 5)
	Survey.add_to_map(want, layer, db().table("rock")["crust"], RngStreams.new(5).get_stream("survey"))
	check_eq(var_to_str(sim.run.map), var_to_str(want), "the run's map comes from the \"map\" stream, its surveys from \"survey\"")
	check_eq(sim.run.current_node, "r0c0", "the run starts at the start node")
	check(sim.run.is_visited(sim.run.node("r0c0")), "the start node is visited")
	check_eq(sim.run.nodes.size(), sim.run.visited.size(), "one visited flag per node")


func test_scanner_reveal() -> void:
	var sim := Sim.new(db(), 9, "light_drill", {"mode": "run"})
	sim.step()
	check_eq(room(sim, "bridge").effective_bars(), 1, "the helm starts at one bar")
	check_eq(sim.run.scanner_rows, 2, "range = layer base 1 + helm bars 1")
	var r2: Dictionary = (sim.run.map[2] as Array)[0]
	var r3: Dictionary = (sim.run.map[3] as Array)[0]
	check(sim.run.is_revealed(r2), "row 2 is in range")
	check(not sim.run.is_revealed(r3), "row 3 is not")
	sim.run.add_reveal(sim, 1)
	check(sim.run.is_revealed(r3), "an event's reveal bonus adds a row")
	sim.push({"type": "power", "room": "bridge", "bars": 2})
	sim.step()
	check_eq(sim.run.scanner_rows, 4, "more helm bars see further")
	check(not sim.run.is_revealed((sim.run.map[5] as Array)[0]), "row 5 still unknown")


func test_lint_catches_a_broken_layer() -> void:
	var d: DataDB = db()
	var bad: Dictionary = (d.table("layers")["crust"] as Dictionary).duplicate(true)
	bad["rock"] = "cheese"
	bad["enemies"] = ["rival_light", "pirate_zeppelin"]
	bad["node_weights"] = {"event": 40, "picnic": 5}
	bad["store_windows"] = [[2, 4], [0, 12]]
	(bad["survey"] as Dictionary)["gas_chance"] = 1.5
	d.table("layers")["broken"] = bad
	var all: String = "\n".join(d.lint())
	check(all.contains("\"cheese\" does not exist"), "a missing rock table is caught")
	check(all.contains("pirate_zeppelin"), "an unknown enemy ship is caught")
	check(not all.contains("\"rival_light\" does not exist"), "pending ships are accepted")
	check(all.contains("picnic"), "an unknown node type is caught")
	check(all.contains("store_windows"), "store windows outside the middle rows are caught")
	check(all.contains("gas_chance"), "a survey chance above 1 is caught")
	d.tuning.erase("run.strike_every_s")
	check("\n".join(d.lint()).contains("run.strike_every_s"), "missing run tuning is caught")
