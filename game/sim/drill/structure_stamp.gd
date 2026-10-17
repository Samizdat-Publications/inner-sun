class_name StructureStamp
extends RefCounted
## Stamps a buried structure (game/data/structures/<id>.json) into a segment's rock grid. Static and
## pure: the grid, the per-cell marks and the segment's own stream are passed in.
##
## A stamp is a list of equal-length strings, one per cell row (0.5 m cells), top row first. Each
## char names a material through the structure's "legend" ({char: material id, or {"material",
## "from_depth_m", "else"}: that material at or below the depth, else the other one}); a " " leaves
## the rock as it was. A placed stamp may be mirrored left to right ("mirror": true) by the stream.
##
## Placement (four draws from the stream, always all four, after the rock features): the centre sits
## at a depth fraction at_min..at_max of the segment below the ship's start, offset off_min..off_max m
## to either side of the corridor line (start centre to target), then the stamp is clamped inside
## the grid and at least one cell below the start shaft (the rows beside and above the ship).
## Cells written: grid = the material; marks = 2 for interior cells (an "interior" or "loot"
## material: the old air and the crates in it), 1 for the rest of the stamp, 0 outside it.

const MARK_SHELL: int = 1
const MARK_INTERIOR: int = 2


## The material id a legend entry gives at this run depth ("" for an unknown shape).
static func legend_material(entry: Variant, depth_m: float) -> String:
	if entry is String:
		return entry
	if entry is Dictionary:
		var d: Dictionary = entry
		if depth_m >= float(d.get("from_depth_m", 0.0)):
			return str(d.get("material", ""))
		return str(d.get("else", ""))
	return ""


## Width and height in cells (0, 0 for an empty stamp).
static func size_of(def: Dictionary) -> Vector2i:
	var stamp: Array = def.get("stamp", [])
	if stamp.is_empty():
		return Vector2i.ZERO
	return Vector2i(str(stamp[0]).length(), stamp.size())


## Places the stamp; returns {"c0", "r0", "w", "h", "mirror", "depth_m"} (cells, the run depth at its
## centre) or {} when it cannot fit. tune: {"at_min", "at_max", "off_min_m", "off_max_m"}.
## interior_of and loot_of: per material code flags (DrillMaterials).
static func place(def: Dictionary, codes: Dictionary, rng: RandomNumberGenerator, grid: PackedByteArray,
		marks: PackedByteArray, cols: int, rows: int, cell_m: float, start: Rect2, target_cx_m: float,
		depth_m: float, run_depth_m: float, tune: Dictionary, interior_of: PackedByteArray,
		loot_of: PackedByteArray) -> Dictionary:
	var size: Vector2i = size_of(def)
	var frac: float = rng.randf_range(float(tune.get("at_min", 0.25)), float(tune.get("at_max", 0.75)))
	var off: float = rng.randf_range(float(tune.get("off_min_m", 3.0)), float(tune.get("off_max_m", 9.0)))
	var left: bool = rng.randf() < 0.5
	var mirror: bool = rng.randf() < 0.5 and bool(def.get("mirror", false))
	var r_min: int = ceili(start.end.y / cell_m - 0.000001) + 1
	if size.x <= 0 or size.x > cols or size.y > rows - r_min:
		return {}
	var y0: float = start.end.y
	var cy: float = y0 + frac * depth_m
	var cx: float = lerpf(start.get_center().x, target_cx_m, frac) + (-off if left else off)
	var c0: int = clampi(roundi(cx / cell_m - float(size.x) * 0.5), 0, cols - size.x)
	var r0: int = clampi(roundi(cy / cell_m - float(size.y) * 0.5), r_min, rows - size.y)
	var at_depth: float = run_depth_m + (float(r0) + float(size.y) * 0.5) * cell_m - y0
	var legend: Dictionary = def.get("legend", {})
	var code_of: Dictionary = {}  ## char -> material code (lookup only).
	for k: Variant in legend.keys():
		code_of[str(k)] = int(codes.get(legend_material(legend[k], at_depth), -1))
	var stamp: Array = def.get("stamp", [])
	for r: int in range(size.y):
		var line: String = str(stamp[r])
		var row: int = (r0 + r) * cols + c0
		for c: int in range(size.x):
			var ch: String = line[size.x - 1 - c] if mirror else line[c]
			if ch == " ":
				continue
			var code: int = int(code_of.get(ch, -1))
			if code < 0:
				continue  # The lint rejects this; never write a bad code.
			grid[row + c] = code
			marks[row + c] = MARK_INTERIOR if interior_of[code] == 1 or loot_of[code] == 1 else MARK_SHELL
	return {"c0": c0, "r0": r0, "w": size.x, "h": size.y, "mirror": mirror, "depth_m": snappedf(at_depth, 0.01)}
