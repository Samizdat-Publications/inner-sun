class_name RockGen
extends RefCounted
## Builds a drilling segment's rock grid from a rock table (game/data/rock/*.json) and ONE seeded
## stream (the sim's "drill/<segment id>"). Square cells, row-major, one material code per cell.
## Order: strata bands (base rock by depth, wavy boundaries), then features in data order (ore veins,
## hard rock lenses, gem pockets in hard shells, water pockets, air caverns), then the open start
## shaft. Features sit around the corridor from the start to the next node so detours are choices.
## Pure function of its inputs: no other randomness, no engine noise.


## Material id -> code for one rock table.
static func codes_of(table: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for m: Variant in table.get("materials", []):
		var md: Dictionary = m
		out[str(md.get("id", ""))] = int(md.get("code", 0))
	return out


## start: the ship's footprint at the start (meters, cell aligned). target_cx_m: the corridor's end
## (centre x at the target depth). run_depth_m: the run's depth at the start (strata eligibility).
static func generate(table: Dictionary, rng: RandomNumberGenerator, cols: int, rows: int, cell_m: float,
		start: Rect2, target_cx_m: float, depth_m: float, run_depth_m: float, shaft_margin_m: float,
		top_air_m: float) -> PackedByteArray:
	var codes: Dictionary = codes_of(table)
	var grid := PackedByteArray()
	grid.resize(cols * rows)
	_strata(table, codes, rng, grid, cols, rows, cell_m, start.end.y, run_depth_m)
	var sx: float = start.get_center().x
	var y0: float = start.end.y
	for f: Variant in table.get("features", []):
		_feature(f as Dictionary, codes, rng, grid, cols, rows, cell_m, sx, target_cx_m, y0, depth_m)
	_carve(grid, cols, rows, cell_m, start, shaft_margin_m, top_air_m)
	return grid


static func _range(d: Dictionary, key: String, rng: RandomNumberGenerator, fallback: float) -> float:
	var v: Variant = d.get(key, fallback)
	if v is Array:
		var a: Array = v
		return rng.randf_range(float(a[0]), float(a[1]))
	return float(v)


static func _strata(table: Dictionary, codes: Dictionary, rng: RandomNumberGenerator, grid: PackedByteArray,
		cols: int, rows: int, cell_m: float, start_bottom_m: float, run_depth_m: float) -> void:
	var strata: Array = table.get("strata", [])
	var bottoms := PackedFloat64Array()
	var band_codes := PackedByteArray()
	var wobble: float = float(table.get("strata_wobble_m", 0.0))
	var y: float = -wobble - 1.0
	var limit: float = float(rows) * cell_m + wobble + 1.0
	while y < limit:
		var depth_here: float = maxf(0.0, run_depth_m + y - start_bottom_m)
		var total: float = 0.0
		for s: Variant in strata:
			var sd: Dictionary = s
			if depth_here >= float(sd.get("from_depth_m", 0.0)) and depth_here < float(sd.get("to_depth_m", 1.0e12)):
				total += float(sd.get("weight", 1.0))
		var pick: Dictionary = strata[0] if not strata.is_empty() else {}
		var u: float = rng.randf() * total
		for s: Variant in strata:
			var sd: Dictionary = s
			if depth_here >= float(sd.get("from_depth_m", 0.0)) and depth_here < float(sd.get("to_depth_m", 1.0e12)):
				u -= float(sd.get("weight", 1.0))
				pick = sd
				if u < 0.0:
					break
		y += maxf(cell_m, rng.randf_range(float(pick.get("min_m", 4.0)), float(pick.get("max_m", 8.0))))
		bottoms.append(y)
		band_codes.append(int(codes.get(str(pick.get("material", "")), 0)))
	var k1: float = TAU / rng.randf_range(8.0, 16.0)
	var k2: float = TAU / rng.randf_range(2.5, 5.0)
	var ph1: float = rng.randf() * TAU
	var ph2: float = rng.randf() * TAU
	var nb: int = bottoms.size()
	for c: int in range(cols):
		var xc: float = (float(c) + 0.5) * cell_m
		var off: float = wobble * (0.7 * sin(xc * k1 + ph1) + 0.3 * sin(xc * k2 + ph2))
		var b: int = 0
		for r: int in range(rows):
			var yy: float = (float(r) + 0.5) * cell_m + off
			while b < nb - 1 and yy >= bottoms[b]:
				b += 1
			grid[r * cols + c] = band_codes[b] if nb > 0 else 0


static func _feature(fd: Dictionary, codes: Dictionary, rng: RandomNumberGenerator, grid: PackedByteArray,
		cols: int, rows: int, cell_m: float, sx: float, tx: float, y0: float, depth_m: float) -> void:
	var kind: String = str(fd.get("kind", ""))
	var code: int = int(codes.get(str(fd.get("material", "")), 0))
	var count: Array = fd.get("count", [1, 1])
	var n: int = rng.randi_range(int(count[0]), int(count[1]))
	for i: int in range(n):
		var frac: float = _range(fd, "at", rng, 0.5)
		var cy: float = y0 + frac * depth_m
		var off: float = _range(fd, "offset_m", rng, 0.0)
		if str(fd.get("side", "")) == "either" and rng.randf() < 0.5:
			off = -off
		var cx: float = lerpf(sx, tx, frac) + off
		match kind:
			"vein":
				var length: float = _range(fd, "length_m", rng, 6.0)
				var thick: float = _range(fd, "thickness_m", rng, 1.0)
				var ang: float = deg_to_rad(_range(fd, "angle_deg", rng, 0.0))
				var half := Vector2(sin(ang), cos(ang)) * (length * 0.5)
				_capsule(grid, cols, rows, cell_m, Vector2(cx, cy) - half, Vector2(cx, cy) + half, thick * 0.5, code)
			"lens":
				var w: float = _range(fd, "width_m", rng, 6.0)
				var h: float = _range(fd, "height_m", rng, 1.5)
				_ellipse(grid, cols, rows, cell_m, cx, cy, w * 0.5, h * 0.5, code)
			"pocket":
				var r: float = _range(fd, "radius_m", rng, 0.6)
				var shell: float = float(fd.get("shell_m", 0.5))
				var shell_code: int = int(codes.get(str(fd.get("shell", "")), code))
				_ellipse(grid, cols, rows, cell_m, cx, cy, r + shell, r + shell, shell_code)
				_ellipse(grid, cols, rows, cell_m, cx, cy, r, r, code)
			"blob":
				var rb: float = _range(fd, "radius_m", rng, 1.0)
				var rx: float = rb * rng.randf_range(0.8, 1.25)
				var ry: float = rb * rng.randf_range(0.8, 1.25)
				_ellipse(grid, cols, rows, cell_m, cx, cy, rx, ry, code)


static func _ellipse(grid: PackedByteArray, cols: int, rows: int, cell_m: float, cx: float, cy: float,
		rx: float, ry: float, code: int) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var c0: int = maxi(0, floori((cx - rx) / cell_m))
	var c1: int = mini(cols - 1, floori((cx + rx) / cell_m))
	var r0: int = maxi(0, floori((cy - ry) / cell_m))
	var r1: int = mini(rows - 1, floori((cy + ry) / cell_m))
	for r: int in range(r0, r1 + 1):
		var dy: float = ((float(r) + 0.5) * cell_m - cy) / ry
		for c: int in range(c0, c1 + 1):
			var dx: float = ((float(c) + 0.5) * cell_m - cx) / rx
			if dx * dx + dy * dy <= 1.0:
				grid[r * cols + c] = code


static func _capsule(grid: PackedByteArray, cols: int, rows: int, cell_m: float, a: Vector2, b: Vector2,
		radius: float, code: int) -> void:
	var c0: int = maxi(0, floori((minf(a.x, b.x) - radius) / cell_m))
	var c1: int = mini(cols - 1, floori((maxf(a.x, b.x) + radius) / cell_m))
	var r0: int = maxi(0, floori((minf(a.y, b.y) - radius) / cell_m))
	var r1: int = mini(rows - 1, floori((maxf(a.y, b.y) + radius) / cell_m))
	var ab: Vector2 = b - a
	var len2: float = maxf(ab.length_squared(), 0.000001)
	var r2: float = radius * radius
	for r: int in range(r0, r1 + 1):
		for c: int in range(c0, c1 + 1):
			var p := Vector2((float(c) + 0.5) * cell_m, (float(r) + 0.5) * cell_m)
			var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			if (a + ab * t - p).length_squared() <= r2:
				grid[r * cols + c] = code


## The open shaft the ship starts in: the top rows everywhere, and every cell beside and above the
## ship's start footprint (plus a margin).
static func _carve(grid: PackedByteArray, cols: int, rows: int, cell_m: float, start: Rect2,
		shaft_margin_m: float, top_air_m: float) -> void:
	for r: int in range(rows):
		var yc: float = (float(r) + 0.5) * cell_m
		if yc >= start.end.y and yc >= top_air_m:
			break
		for c: int in range(cols):
			var xc: float = (float(c) + 0.5) * cell_m
			if yc < top_air_m or (xc > start.position.x - shaft_margin_m and xc < start.end.x + shaft_margin_m):
				grid[r * cols + c] = 0
