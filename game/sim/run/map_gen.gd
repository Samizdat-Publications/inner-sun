class_name MapGen
extends RefCounted
## The layer's node map, generated from one random stream (the run passes "map"). A vertical map like
## Slay the Spire, read top to bottom like the descent: row 0 is the start, the last row the gate, the
## rows between hold min_nodes_per_row to max_nodes_per_row nodes spread across x_min_m..x_max_m.
##
## The map is an Array of rows; each row is an Array of node Dictionaries, sorted by x:
##   {"id": "r<row>c<col>", "index": flat index, "row": int, "col": int, "x_m": float,
##    "type": "start" | "event" | "cavern" | "hazard" | "store" | "fight" | "deposit" | "gate",
##    "links": PackedStringArray of next-row node ids (empty for the gate),
##    "enemy": ship id for "fight" and "gate" nodes, else ""}
## Fight enemies come from the layer's "enemies", or from "enemy_tiers" ([{"from_row", "ships"}, ...]
## in ascending from_row) so rivals get tougher deeper down (enemies_for_row).
## RunState adds "env" (assign_envs: an environment id or "") and "survey" (Survey.add_to_map)
## before the map is used. Node dictionaries are fixed
## from then on; visited and overtaken live in RunState.
##
## Guarantees (tests in test_map.gd): every node has a way in and a way out, so every node is reached
## from the start and reaches the gate; edges never cross; every path meets a store in each of the
## layer's store_windows ([first row, last row] pairs); never two stores in a row on one path; at
## least min_fights_per_path fights on every path (the gate not counted).
##
## Edges between two rows are a monotone staircase: start with the leftmost pair, then step right in
## the upper row, the lower row or both, picking the step whose new edge is shortest in x (plus a
## random jitter). That is "connect to the nearest, then fill the gaps" with the guarantees built in:
## every node of both rows is touched and two edges of a staircase can never cross.

const NODE_TYPES: Array[String] = ["event", "fight", "cavern", "hazard", "store", "deposit"]  ## Fixed draw order.
const ALL_TYPES: Array[String] = ["start", "event", "fight", "cavern", "hazard", "store", "deposit", "gate"]
const PLAIN: Array[String] = ["event", "cavern", "hazard", "deposit"]  ## Types the guarantees may overwrite.
const STEPS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)]


static func generate(layer: Dictionary, rng: RandomNumberGenerator) -> Array:
	var n_rows: int = maxi(3, int(layer.get("rows", 10)))
	var lo_n: int = maxi(1, int(layer.get("min_nodes_per_row", 2)))
	var hi_n: int = maxi(lo_n, int(layer.get("max_nodes_per_row", 3)))
	var x_min: float = float(layer.get("x_min_m", -12.0))
	var x_max: float = float(layer.get("x_max_m", 12.0))
	var jitter: float = float(layer.get("x_jitter_frac", 0.25))
	var link_jitter: float = float(layer.get("link_jitter_m", 6.0))
	# Positions.
	var xs: Array[PackedFloat64Array] = []
	for r: int in range(n_rows):
		var n: int = 1 if r == 0 or r == n_rows - 1 else rng.randi_range(lo_n, hi_n)
		var row_x := PackedFloat64Array()
		var slot: float = (x_max - x_min) / float(n)
		for i: int in range(n):
			if n == 1:
				row_x.append(0.0)
			else:
				var x: float = x_min + (float(i) + 0.5) * slot + rng.randf_range(-jitter, jitter) * slot
				row_x.append(snappedf(clampf(x, x_min, x_max), 0.5))
		xs.append(row_x)
	# Edges: links[r][i] = next-row columns.
	var links: Array[Array] = []
	for r: int in range(n_rows):
		var row_links: Array[Array] = []
		for i: int in range(xs[r].size()):
			row_links.append([])
		links.append(row_links)
	for r: int in range(n_rows - 1):
		_staircase(xs[r], xs[r + 1], links[r], rng, link_jitter)
	# Types.
	var types: Array[Array] = []  ## types[r][i]: plain Arrays (packed arrays copy on write).
	for r: int in range(n_rows):
		var row_t: Array[String] = []
		row_t.resize(xs[r].size())
		types.append(row_t)
	types[0][0] = "start"
	types[n_rows - 1][0] = "gate"
	var weights := PackedFloat64Array()
	var w_in: Dictionary = layer.get("node_weights", {})
	for t: String in NODE_TYPES:
		weights.append(maxf(0.0, float(w_in.get(t, 0.0))))
	var parents: Array[Array] = _parents(links, xs)
	for r: int in range(1, n_rows - 1):
		for i: int in range(xs[r].size()):
			var no_store: bool = false
			for p: int in (parents[r][i] as Array):
				if types[r - 1][p] == "store":
					no_store = true
			types[r][i] = _pick(weights, no_store, rng)
	for w: Variant in layer.get("store_windows", []):
		var wa: Array = w
		_ensure_store(types, links, parents, rng, clampi(int(wa[0]), 1, n_rows - 2), clampi(int(wa[1]), 1, n_rows - 2))
	_ensure_fights(int(layer.get("min_fights_per_path", 2)), types, parents, rng)
	# Build the node dictionaries.
	var enemies: Array = layer.get("enemies", [])
	var map: Array = []
	var index: int = 0
	for r: int in range(n_rows):
		var row: Array[Dictionary] = []
		for i: int in range(xs[r].size()):
			var ids := PackedStringArray()
			for j: int in (links[r][i] as Array):
				ids.append(node_id(r + 1, j))
			var enemy: String = ""
			var pool: Array = enemies_for_row(layer, r) if types[r][i] == "fight" else enemies
			if types[r][i] == "fight" and not pool.is_empty():
				enemy = str(pool[rng.randi_range(0, pool.size() - 1)])
			elif types[r][i] == "gate":
				enemy = str(layer.get("gate_enemy", ""))
			row.append({"id": node_id(r, i), "index": index, "row": r, "col": i, "x_m": xs[r][i],
					"type": types[r][i], "links": ids, "enemy": enemy})
			index += 1
		map.append(row)
	return map


## Give every node an "env" (an environment id or ""; Environments): the nodes of the layer's
## environments.node_types roll, in map order, from their own stream (the run passes "map/env"),
## after the map is complete, so the map is otherwise exactly what generate() made. The start, a
## store and the gate never carry one. Two draws per eligible node (Environments.roll).
static func assign_envs(map: Array, layer: Dictionary, table: Dictionary, rng: RandomNumberGenerator) -> void:
	var block: Dictionary = layer.get("environments", {})
	var chance: float = float(block.get("chance", 0.0)) if not table.is_empty() else 0.0
	var types: Array = block.get("node_types", [])
	var order: PackedStringArray = Environments.ids(table)
	for row: Variant in map:
		for nv: Variant in (row as Array):
			var n: Dictionary = nv
			var t: String = str(n["type"])
			n["env"] = ""
			if chance <= 0.0 or t == "start" or t == "store" or t == "gate" or not types.has(t):
				continue
			n["env"] = Environments.roll(table, order, int(n["row"]), chance, rng)


## The rival ships a fight in this row may meet: the ships of the last "enemy_tiers" entry whose
## from_row is at or above the row (tiers in ascending from_row), else the layer's "enemies".
static func enemies_for_row(layer: Dictionary, row: int) -> Array:
	var out: Array = layer.get("enemies", [])
	for t: Variant in layer.get("enemy_tiers", []):
		var td: Dictionary = t
		if int(td.get("from_row", 0)) <= row:
			out = td.get("ships", [])
	return out


static func node_id(row: int, col: int) -> String:
	return "r%dc%d" % [row, col]


## Connect two sorted rows with a monotone staircase (see the header).
static func _staircase(up: PackedFloat64Array, down: PackedFloat64Array, out: Array, rng: RandomNumberGenerator, link_jitter: float) -> void:
	var a: int = up.size()
	var b: int = down.size()
	var i: int = 0
	var j: int = 0
	(out[0] as Array).append(0)
	while i < a - 1 or j < b - 1:
		var best: Vector2i = Vector2i.ZERO
		var best_score: float = INF
		for s: Vector2i in STEPS:
			if i + s.x >= a or j + s.y >= b:
				continue
			var score: float = absf(up[i + s.x] - down[j + s.y]) + rng.randf() * link_jitter
			if score < best_score:
				best_score = score
				best = s
		i += best.x
		j += best.y
		(out[i] as Array).append(j)


## parents[r][i] = previous-row columns linking to node (r, i), ascending.
static func _parents(links: Array[Array], xs: Array[PackedFloat64Array]) -> Array[Array]:
	var parents: Array[Array] = []
	for r: int in range(xs.size()):
		var row_p: Array[Array] = []
		for i: int in range(xs[r].size()):
			row_p.append([])
		parents.append(row_p)
	for r: int in range(xs.size() - 1):
		for i: int in range(xs[r].size()):
			for j: int in (links[r][i] as Array):
				(parents[r + 1][j] as Array).append(i)
	return parents


static func _pick(weights: PackedFloat64Array, no_store: bool, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for k: int in range(weights.size()):
		if not (no_store and NODE_TYPES[k] == "store"):
			total += weights[k]
	var roll: float = rng.randf() * total
	for k: int in range(weights.size()):
		if no_store and NODE_TYPES[k] == "store":
			continue
		roll -= weights[k]
		if roll < 0.0:
			return NODE_TYPES[k]
	return "event"


## Every path meets a store in rows r0..r1, and no store sits next to another on a path: while the
## path with the fewest stores in the window has none, turn one of its plain window nodes that does
## not touch a store into a store (if every one touches a store, any plain or fight node, and its
## store neighbours become events; the loop then repairs any path that lost its store).
static func _ensure_store(types: Array[Array], links: Array[Array], parents: Array[Array],
		rng: RandomNumberGenerator, r0: int, r1: int) -> void:
	var guard: int = 64
	while guard > 0:
		guard -= 1
		var path: Array[Vector2i] = _fewest_path(types, parents, "store", r0, r1)
		var free: Array[Vector2i] = []
		var free_deposits: Array[Vector2i] = []  ## Converted only when no other free node is left (mining first).
		var any: Array[Vector2i] = []
		for at: Vector2i in path:
			if at.x < r0 or at.x > r1:
				continue
			var t: String = types[at.x][at.y]
			if t == "store":
				return
			if PLAIN.has(t) or t == "fight":
				any.append(at)
				if PLAIN.has(t) and not _next_to_store(at.x, at.y, types, links, parents):
					if t == "deposit":
						free_deposits.append(at)
					else:
						free.append(at)
		var pool: Array[Vector2i] = free if not free.is_empty() else free_deposits if not free_deposits.is_empty() else any
		if pool.is_empty():
			return
		var pick: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		types[pick.x][pick.y] = "store"
		for p: int in (parents[pick.x][pick.y] as Array):
			if types[pick.x - 1][p] == "store":
				types[pick.x - 1][p] = "event"
		for c: int in (links[pick.x][pick.y] as Array):
			if types[pick.x + 1][c] == "store":
				types[pick.x + 1][c] = "event"


static func _next_to_store(r: int, i: int, types: Array[Array], links: Array[Array], parents: Array[Array]) -> bool:
	for p: int in (parents[r][i] as Array):
		if types[r - 1][p] == "store":
			return true
	for c: int in (links[r][i] as Array):
		if types[r + 1][c] == "store":
			return true
	return false


## Every path from start to gate meets at least `need` fights: while the path with the fewest fights
## is short, turn one of its plain nodes (never a store) into a fight.
static func _ensure_fights(need: int, types: Array[Array], parents: Array[Array], rng: RandomNumberGenerator) -> void:
	var guard: int = 64
	while guard > 0:
		guard -= 1
		var path: Array[Vector2i] = _fewest_path(types, parents, "fight", 0, types.size())
		var fights: int = 0
		var plain: Array[Vector2i] = []
		var deposits: Array[Vector2i] = []  ## Converted only when nothing else is left (mining first).
		for at: Vector2i in path:
			var t: String = types[at.x][at.y]
			if t == "fight":
				fights += 1
			elif t == "deposit":
				deposits.append(at)
			elif PLAIN.has(t):
				plain.append(at)
		var pool: Array[Vector2i] = plain if not plain.is_empty() else deposits
		if fights >= need or pool.is_empty():
			return
		var pick: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		types[pick.x][pick.y] = "fight"


## The start-to-gate path with the fewest nodes of `kind` in rows r0..r1 (ties: the lowest parent
## column), start first.
static func _fewest_path(types: Array[Array], parents: Array[Array], kind: String, r0: int, r1: int) -> Array[Vector2i]:
	var best: Array[PackedInt32Array] = []
	var via: Array[PackedInt32Array] = []
	for r: int in range(types.size()):
		var b := PackedInt32Array()
		var v := PackedInt32Array()
		for i: int in range(types[r].size()):
			var own: int = 1 if types[r][i] == kind and r >= r0 and r <= r1 else 0
			var m: int = 0
			var from: int = -1
			if r > 0:
				m = 1 << 30
				for p: int in (parents[r][i] as Array):
					if best[r - 1][p] < m:
						m = best[r - 1][p]
						from = p
			b.append(m + own)
			v.append(from)
		best.append(b)
		via.append(v)
	var path: Array[Vector2i] = []
	var r2: int = types.size() - 1
	var i2: int = 0
	while r2 >= 0 and i2 >= 0:
		path.push_front(Vector2i(r2, i2))
		i2 = via[r2][i2]
		r2 -= 1
	return path


## Fewest fights on any start-to-gate path of a built map (tests and lint).
static func min_fights(map: Array) -> int:
	return min_on_paths(map, "fight", 0, map.size())


## Fewest nodes of `kind` in rows r0..r1 on any start-to-gate path of a built map (tests and lint).
static func min_on_paths(map: Array, kind: String, r0: int, r1: int) -> int:
	var prev: Dictionary = {}  ## node id -> fewest so far (lookup only, never iterated).
	for r: int in range(map.size()):
		var cur: Dictionary = {}
		var row: Array = map[r]
		var own_of: Dictionary = {}
		for n: Dictionary in row:
			own_of[str(n["id"])] = 1 if str(n["type"]) == kind and r >= r0 and r <= r1 else 0
			if r == 0:
				cur[str(n["id"])] = int(own_of[str(n["id"])])
		if r > 0:
			var above: Array = map[r - 1]
			for p: Dictionary in above:
				var base: int = int(prev.get(str(p["id"]), 1 << 30))
				for to: String in (p["links"] as PackedStringArray):
					cur[to] = mini(int(cur.get(to, 1 << 30)), base + int(own_of.get(to, 0)))
		prev = cur
	var last: Array = map[map.size() - 1]
	return int(prev.get(str((last[0] as Dictionary)["id"]), 0))


## True if some edge of a built map joins two stores (a path with two stores in a row).
static func has_store_pair(map: Array) -> bool:
	for r: int in range(map.size() - 1):
		var below: Dictionary = {}
		for n: Dictionary in (map[r + 1] as Array):
			below[str(n["id"])] = str(n["type"])
		for n: Dictionary in (map[r] as Array):
			if str(n["type"]) != "store":
				continue
			for to: String in (n["links"] as PackedStringArray):
				if str(below.get(to, "")) == "store":
					return true
	return false


