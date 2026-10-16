class_name DrillMaterials
extends RefCounted
## The per-code lookup tables a DrillSim reads in its hot loop, built from a rock table when a
## segment begins: material info, effective hardness (gear can make hard rock cheaper), yields,
## water and gas flags. Also the flood fill that marks a connected pocket. Static helpers only.


## Fill d.materials, d.hardness_of, d.yield_res_of, d.yield_amount_of, d.water_of and d.gas_of from
## a rock table. Hardness at or above hard_min is multiplied by hard_x (a diamond head: 0.5).
static func load_into(d: DrillSim, table: Dictionary, hard_x: float, hard_min: float) -> void:
	var n: int = DrillSim.MAX_CODES
	d.materials = []
	d.materials.resize(n)
	d.hardness_of = PackedFloat64Array()
	d.hardness_of.resize(n)
	d.yield_res_of = PackedInt32Array()
	d.yield_res_of.resize(n)
	d.yield_res_of.fill(-1)
	d.yield_amount_of = PackedInt32Array()
	d.yield_amount_of.resize(n)
	d.water_of = PackedByteArray()
	d.water_of.resize(n)
	d.gas_of = PackedByteArray()
	d.gas_of.resize(n)
	for i: int in range(n):
		d.materials[i] = {}
	for m: Variant in table.get("materials", []):
		var md: Dictionary = m
		var code: int = clampi(int(md.get("code", 0)), 0, n - 1)
		var h: float = float(md.get("hardness", 1.0))
		var info: Dictionary = {"id": str(md.get("id", "")), "name": str(md.get("name", "")), "hardness": h,
				"color": str(md.get("color", "#808080")), "res": "", "amount": 0}
		d.hardness_of[code] = h * hard_x if h >= hard_min else h
		d.water_of[code] = 1 if bool(md.get("water", false)) else 0
		d.gas_of[code] = 1 if bool(md.get("gas", false)) else 0
		var y: Variant = md.get("yield", null)
		if y is Dictionary:
			var yd: Dictionary = y
			d.yield_res_of[code] = RunState.RESOURCES.find(str(yd.get("res", "")))
			d.yield_amount_of[code] = int(yd.get("amount", 0))
			info["res"] = str(yd.get("res", ""))
			info["amount"] = int(yd.get("amount", 0))
		d.materials[code] = info


## Mark the connected cells (4-neighbours) whose material has flag 1, starting at `start`, in
## `marks`. Returns the number of cells marked. Cells already marked are not crossed.
static func flood(grid: PackedByteArray, cols: int, rows: int, start: int, flag: PackedByteArray,
		marks: PackedByteArray) -> int:
	var stack := PackedInt32Array([start])
	marks[start] = 1
	var cells: int = 0
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		cells += 1
		var r: int = i / cols
		var c: int = i % cols
		var nbs := PackedInt32Array([i - cols if r > 0 else -1, i + cols if r < rows - 1 else -1,
				i - 1 if c > 0 else -1, i + 1 if c < cols - 1 else -1])
		for j: int in nbs:
			if j >= 0 and marks[j] == 0 and flag[grid[j]] == 1:
				marks[j] = 1
				stack.append(j)
	return cells
