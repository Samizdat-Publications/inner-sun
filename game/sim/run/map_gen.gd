class_name MapGen
extends RefCounted
## The layer's node map, generated from one random stream (the run passes "map"). A vertical map like
## Slay the Spire, read top to bottom like the descent: row 0 is the start, the last row the gate, the
## rows between hold min_nodes_per_row to max_nodes_per_row nodes spread across x_min_m..x_max_m.
##
## The map is an Array of rows; each row is an Array of node Dictionaries, sorted by x:
##   {"id": "r<row>c<col>", "index": flat index, "row": int, "col": int, "x_m": float,
##    "type": "start" | "event" | "cavern" | "hazard" | "store" | "fight" | "gate",
##    "links": PackedStringArray of next-row node ids (empty for the gate),
##    "enemy": ship id for "fight" and "gate" nodes, else ""}
## Node dictionaries are fixed once generated; visited and overtaken live in RunState.
##
## Guarantees (tests in test_map.gd): every node has a way in and a way out, so every node is reached
## from the start and reaches the gate; edges never cross; at least one store in the store rows; never
## two stores in a row on one path; at least min_fights_per_path fights on every path.
##
## Edges between two rows are a monotone staircase: start with the leftmost pair, then step right in
## the upper row, the lower row or both, picking the step whose new edge is shortest in x (plus a
## random jitter). That is "connect to the nearest, then fill the gaps" with the guarantees built in:
## every node of both rows is touched and two edges of a staircase can never cross.

const NODE_TYPES: Array[String] = ["event", "fight", "cavern", "hazard", "store"]  ## Fixed draw order.
const ALL_TYPES: Array[String] = ["start", "event", "fight", "cavern", "hazard", "store", "gate"]
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
	_ensure_store(layer, types, links, parents, rng)
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
			if types[r][i] == "fight" and not enemies.is_empty():
				enemy = str(enemies[rng.randi_range(0, enemies.size() - 1)])
			elif types[r][i] == "gate":
				enemy = str(layer.get("gate_enemy", ""))
			row.append({"id": node_id(r, i), "index": index, "row": r, "col": i, "x_m": xs[r][i],
					"type": types[r][i], "links": ids, "enemy": enemy})
			index += 1
		map.append(row)
	return map


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


## At least one store in the store rows, never next to another store on a path.
static func _ensure_store(layer: Dictionary, types: Array[Array], links: Array[Array], parents: Array[Array], rng: RandomNumberGenerator) -> void:
	var sr: Array = layer.get("store_rows", [3, 5])
	var last_mid: int = types.size() - 2
	var r0: int = clampi(int(sr[0]) if sr.size() > 0 else 1, 1, last_mid)
	var r1: int = clampi(int(sr[1]) if sr.size() > 1 else r0, r0, last_mid)
	var free: Array[Vector2i] = []
	var all: Array[Vector2i] = []
	for r: int in range(r0, r1 + 1):
		for i: int in range(types[r].size()):
			if types[r][i] == "store":
				return
			all.append(Vector2i(r, i))
			if not _next_to_store(r, i, types, links, parents):
				free.append(Vector2i(r, i))
	var pool: Array[Vector2i] = free if not free.is_empty() else all
	var at: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
	types[at.x][at.y] = "store"
	# Only when every candidate touched a store: its store neighbours become events.
	for p: int in (parents[at.x][at.y] as Array):
		if types[at.x - 1][p] == "store":
			types[at.x - 1][p] = "event"
	for c: int in (links[at.x][at.y] as Array):
		if types[at.x + 1][c] == "store":
			types[at.x + 1][c] = "event"


static func _next_to_store(r: int, i: int, types: Array[Array], links: Array[Array], parents: Array[Array]) -> bool:
	for p: int in (parents[r][i] as Array):
		if types[r - 1][p] == "store":
			return true
	for c: int in (links[r][i] as Array):
		if types[r + 1][c] == "store":
			return true
	return false


## Every path from start to gate meets at least `need` fights: while the path with the fewest fights
## is short, turn one of its plain nodes (not a store) into a fight.
static func _ensure_fights(need: int, types: Array[Array], parents: Array[Array], rng: RandomNumberGenerator) -> void:
	var guard: int = 64
	while guard > 0:
		guard -= 1
		var path: Array[Vector2i] = _fewest_fights_path(types, parents)
		var fights: int = 0
		var plain: Array[Vector2i] = []
		for at: Vector2i in path:
			var t: String = types[at.x][at.y]
			if t == "fight":
				fights += 1
			elif t == "event" or t == "cavern" or t == "hazard":
				plain.append(at)
		if fights >= need or plain.is_empty():
			return
		var pick: Vector2i = plain[rng.randi_range(0, plain.size() - 1)]
		types[pick.x][pick.y] = "fight"


## The start-to-gate path with the fewest fights (ties: the lowest parent column), start first.
static func _fewest_fights_path(types: Array[Array], parents: Array[Array]) -> Array[Vector2i]:
	var best: Array[PackedInt32Array] = []
	var via: Array[PackedInt32Array] = []
	for r: int in range(types.size()):
		var b := PackedInt32Array()
		var v := PackedInt32Array()
		for i: int in range(types[r].size()):
			var own: int = 1 if types[r][i] == "fight" else 0
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
	var prev: Dictionary = {}  ## node id -> fewest fights to reach it (lookup only).
	var row0: Array = map[0]
	var start: Dictionary = row0[0]
	prev[str(start["id"])] = 0
	var cur: Dictionary = {}
	for r: int in range(map.size()):
		cur = {}
		var row: Array = map[r]
		for n: Dictionary in row:
			var id: String = str(n["id"])
			if r == 0:
				cur[id] = 0
		if r > 0:
			var above: Array = map[r - 1]
			for p: Dictionary in above:
				var base: int = int(prev.get(str(p["id"]), 1 << 30))
				for to: String in (p["links"] as PackedStringArray):
					var own: int = 0
					for n2: Dictionary in row:
						if str(n2["id"]) == to and str(n2["type"]) == "fight":
							own = 1
					cur[to] = mini(int(cur.get(to, 1 << 30)), base + own)
		prev = cur
	var last: Array = map[map.size() - 1]
	return int(prev.get(str((last[0] as Dictionary)["id"]), 0))
