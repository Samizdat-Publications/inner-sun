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
	var rows: int = int(layer["rows"])
	var lo_n: int = int(layer["min_nodes_per_row"])
	var hi_n: int = int(layer["max_nodes_per_row"])
	var x_lo: float = float(layer["x_min_m"])
	var x_hi: float = float(layer["x_max_m"])
	for s: int in range(1, SEEDS + 1):
		var m: Array = _gen(layer, s)
		if m.size() != rows:
			failures.append("seed %d: %d rows, want the layer's %d" % [s, m.size(), rows])
			continue
		var first: Array = m[0]
		var last: Array = m[rows - 1]
		check(first.size() == 1 and str((first[0] as Dictionary)["type"]) == "start", "seed %d: row 0 is one start node" % s)
		check(last.size() == 1 and str((last[0] as Dictionary)["type"]) == "gate", "seed %d: the last row is one gate node" % s)
		var index: int = 0
		for r: int in range(rows):
			var row: Array = m[r]
			if r > 0 and r < rows - 1 and (row.size() < lo_n or row.size() > hi_n):
				failures.append("seed %d row %d: %d nodes, want %d to %d" % [s, r, row.size(), lo_n, hi_n])
			var prev_x: float = -INF
			for i: int in range(row.size()):
				var n: Dictionary = row[i]
				check_eq(str(n["id"]), "r%dc%d" % [r, i], "seed %d: stable node id" % s)
				check_eq(int(n["index"]), index, "seed %d: flat index in map order" % s)
				index += 1
				var x: float = float(n["x_m"])
				if x < x_lo or x > x_hi or x <= prev_x:
					failures.append("seed %d %s: x %.2f out of range or out of order" % [s, n["id"], x])
				prev_x = x
				var t: String = str(n["type"])
				if r > 0 and r < rows - 1 and not MapGen.NODE_TYPES.has(t):
					failures.append("seed %d %s: middle node type \"%s\"" % [s, n["id"], t])
				if (t == "fight" or t == "gate") and str(n["enemy"]).is_empty():
					failures.append("seed %d %s: a fight without an enemy" % [s, n["id"]])
		var gate: Dictionary = last[0]
		check_eq(str(gate["enemy"]), str(layer["gate_enemy"]), "seed %d: the gate enemy comes from the layer" % s)
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
	var windows: Array = layer["store_windows"]
	var need: int = int(layer["min_fights_per_path"])
	check_gt(float(windows.size()), 0.0, "the layer guarantees stores")
	check_gt(float(need), 0.0, "the layer guarantees fights")
	var stores: int = 0
	var fights: int = 0
	var middle: int = 0
	var most_fights: int = 0
	var path_fight_frac: float = 0.0
	for s: int in range(1, SEEDS + 1):
		var m: Array = _gen(layer, s)
		for w: Variant in windows:
			var r0: int = int((w as Array)[0])
			var r1: int = int((w as Array)[1])
			check(MapGen.min_on_paths(m, "store", r0, r1) >= 1, "seed %d: every path meets a store in rows %d to %d" % [s, r0, r1])
		check(not MapGen.has_store_pair(m), "seed %d: never two stores in a row (helper)" % s)
		var type_of: Dictionary = {}
		for row: Array in m:
			for n: Dictionary in row:
				type_of[str(n["id"])] = str(n["type"])
				stores += 1 if str(n["type"]) == "store" else 0
				fights += 1 if str(n["type"]) == "fight" else 0
				middle += 1 if MapGen.NODE_TYPES.has(str(n["type"])) else 0
		for row: Array in m:
			for n: Dictionary in row:
				if str(n["type"]) != "store":
					continue
				for to: String in (n["links"] as PackedStringArray):
					check(str(type_of[to]) != "store", "seed %d: %s and %s are two stores in a row" % [s, n["id"], to])
		check(MapGen.min_fights(m) >= need, "seed %d: every path has at least %d fights (plus the gate)" % [s, need])
		var worst: int = _most_on_a_path(m, "fight")
		most_fights = maxi(most_fights, worst)
		path_fight_frac += float(worst) / float(m.size() - 2)
		if failures.size() > 20:
			return
	print("MAP fights: %.2f per map of %.1f middle nodes; the most on any path averages %.2f of its middle nodes (max %d)"
			% [float(fights) / SEEDS, float(middle) / SEEDS, path_fight_frac / SEEDS, most_fights])
	check_gt(float(stores) / SEEDS, float(windows.size()), "stores are not only the guaranteed ones")
	check_lt(float(fights) / float(middle), 0.25, "fights are occasional: well under a quarter of the middle nodes")
	check_lt(path_fight_frac / SEEDS, 0.30, "even the fight-heaviest path is mostly not fights")


## The most nodes of `kind` on any start-to-gate path of a built map.
func _most_on_a_path(m: Array, kind: String) -> int:
	var prev: Dictionary = {}
	for r: int in range(m.size()):
		var cur: Dictionary = {}
		for n: Dictionary in (m[r] as Array):
			var own: int = 1 if str(n["type"]) == kind else 0
			if r == 0:
				cur[str(n["id"])] = own
		if r > 0:
			var own_of: Dictionary = {}
			for n: Dictionary in (m[r] as Array):
				own_of[str(n["id"])] = 1 if str(n["type"]) == kind else 0
			for p: Dictionary in (m[r - 1] as Array):
				var base: int = int(prev.get(str(p["id"]), 0))
				for to: String in (p["links"] as PackedStringArray):
					cur[to] = maxi(int(cur.get(to, 0)), base + int(own_of[to]))
		prev = cur
	return int(prev.get(str(((m[m.size() - 1] as Array)[0] as Dictionary)["id"]), 0))


func test_rivals_get_tougher_with_depth() -> void:
	var layer: Dictionary = _layer()
	var tiers: Array = layer.get("enemy_tiers", [])
	check_gt(float(tiers.size()), 1.0, "the layer names tougher rivals for deeper rows")
	var deep_seen: Dictionary = {}
	for s: int in range(1, 101):
		for row: Variant in _gen(layer, s):
			for n: Dictionary in (row as Array):
				if str(n["type"]) != "fight":
					continue
				var pool: Array = MapGen.enemies_for_row(layer, int(n["row"]))
				check(pool.has(str(n["enemy"])), "seed %d %s: enemy %s comes from its row's tier" % [s, n["id"], n["enemy"]])
				deep_seen[str(n["enemy"])] = true
	var last: Dictionary = tiers[tiers.size() - 1]
	for ship: Variant in (last["ships"] as Array):
		check(deep_seen.has(str(ship)), "the deepest tier's %s turns up" % str(ship))
	var t: Dictionary = {"enemies": ["a"], "enemy_tiers": [{"from_row": 3, "ships": ["b"]}, {"from_row": 6, "ships": ["c", "d"]}]}
	check_eq(MapGen.enemies_for_row(t, 2), ["a"], "above every tier: the plain list")
	check_eq(MapGen.enemies_for_row(t, 3), ["b"], "a tier starts at its from_row")
	check_eq(MapGen.enemies_for_row(t, 9), ["c", "d"], "the last tier that applies wins")


func test_survey_gas_and_water_get_likelier_deeper() -> void:
	var sd: Dictionary = {"tiers": [{"name": "fair", "richness": 1.0, "weight": 1}], "gems_chance": 0.0,
		"gas_chance": 0.0, "water_chance": 0.0, "per_row": {"gas_chance": 0.5, "water_chance": 0.25}}
	var rock: Dictionary = db().table("rock")["crust"]
	var rng: RandomNumberGenerator = RngStreams.new(3).get_stream("survey")
	var gas_top: int = 0
	var gas_deep: int = 0
	var water_mid: int = 0
	for i: int in range(200):
		gas_top += 1 if bool(Survey.roll(sd, rock, false, 0.0, 60.0, rng, 0)["gas"]) else 0
		gas_deep += 1 if bool(Survey.roll(sd, rock, false, 120.0, 60.0, rng, 2)["gas"]) else 0
		water_mid += 1 if bool(Survey.roll(sd, rock, false, 120.0, 60.0, rng, 2)["water"]) else 0
	check_eq(gas_top, 0, "no gas in the first segment at chance 0")
	check_eq(gas_deep, 200, "two rows down 0 + 2 * 0.5 = always gas")
	check(water_mid > 60 and water_mid < 140, "two rows down water at 0.5 (got %d of 200)" % water_mid)
	var layer: Dictionary = _layer()
	check((layer["survey"] as Dictionary).has("per_row"), "the crust's surveys get gassier with depth")


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
