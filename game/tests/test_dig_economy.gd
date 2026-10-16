extends TestCase
## The dig economy's targets per segment (docs/plans/specs/m1b_dig_sim.md), measured on real
## segments driven by the drill bot: 60 m segments of 45 to 75 s at 3 bars (the balanced policy's
## power; a fresh bit, so runs with worn bits are slower); 8 to 14 deposits in the
## steerable band; driving straight for the node yields about 15 to 25 ore, a greedy weaving path 60
## to 150 at mid depth. Prints the table it checks (DIG lines) so retuning has numbers.

const SEEDS: int = 12
const SEG_M: float = 60.0


func _segment(p_seed: int, run_depth: float, bars: int, greedy: bool, survey: Dictionary) -> Dictionary:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": bars})
	s.step()
	s.run.depth_m = run_depth
	var lateral: float = float((p_seed * 7) % 17) - 8.0  # Node to node offsets like the map's.
	s.push({"type": "begin_segment", "segment": "eco%d" % p_seed, "depth_m": SEG_M, "lateral_m": lateral, "survey": survey})
	s.step()
	var deposits: int = _deposits(s.drill)
	var bot := DrillBot.new()
	if greedy:
		bot.noise_budget = 1.0e9
		bot.max_detour_m = 9.0
	else:
		bot.noise_budget = -1.0
	var cap: int = 60 * 300
	while s.drill.active and cap > 0:
		bot.act(s)
		s.step()
		cap -= 1
	var d: DrillSim = s.drill
	return {"ore": d.yielded[RunState.RESOURCES.find("ore")], "gems": d.yielded[RunState.RESOURCES.find("gems")],
		"time_s": float(d.segment_ticks) / Sim.TICK_HZ, "deposits": deposits, "noise": d.noise_segment, "wear": d.bit_wear}


## Connected groups (4-neighbours) of yielding cells of at least 3 cells: the deposits a player sees.
func _deposits(d: DrillSim) -> int:
	var seen := PackedByteArray()
	seen.resize(d.grid.size())
	var n: int = 0
	for i: int in range(d.grid.size()):
		if seen[i] == 1 or d.yield_res_of[d.grid[i]] < 0:
			continue
		var stack := PackedInt32Array([i])
		seen[i] = 1
		var cells: int = 0
		while not stack.is_empty():
			var j: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			cells += 1
			var r: int = j / d.cols
			var c: int = j % d.cols
			for k: int in [j - d.cols if r > 0 else -1, j + d.cols if r < d.rows - 1 else -1, j - 1 if c > 0 else -1, j + 1 if c < d.cols - 1 else -1]:
				if k >= 0 and seen[k] == 0 and d.yield_res_of[d.grid[k]] >= 0:
					seen[k] = 1
					stack.append(k)
		if cells >= 3:
			n += 1
	return n


func _mean(xs: PackedFloat64Array) -> float:
	var t: float = 0.0
	for x: float in xs:
		t += x
	return t / maxf(1.0, float(xs.size()))


func test_segment_economy_bands() -> void:
	var fair: Dictionary = {"richness": 1.0, "gems": ["gem"], "gas": false, "water": false}
	for depth: float in [0.0, 240.0, 420.0]:
		var dep := PackedFloat64Array()
		var straight := PackedFloat64Array()
		var greedy := PackedFloat64Array()
		var gems := PackedFloat64Array()
		var t2 := PackedFloat64Array()
		var t2g := PackedFloat64Array()
		var t3 := PackedFloat64Array()
		var wear := PackedFloat64Array()
		for p_seed: int in range(1, SEEDS + 1):
			var a: Dictionary = _segment(p_seed, depth, 2, false, fair)
			var b: Dictionary = _segment(p_seed, depth, 2, true, fair)
			var c: Dictionary = _segment(p_seed, depth, 3, false, fair)
			dep.append(float(a["deposits"]))
			straight.append(float(a["ore"]))
			greedy.append(float(b["ore"]))
			gems.append(float(b["gems"]))
			t2.append(float(a["time_s"]))
			t2g.append(float(b["time_s"]))
			t3.append(float(c["time_s"]))
			wear.append(float(b["wear"]))
		print("DIG depth %3.0f m: deposits %.1f, ore straight %.1f, ore greedy %.1f, gems greedy %.1f, time 2 bars %.1f s (greedy %.1f), 3 bars %.1f s, bit wear per greedy segment %.3f" % [
				depth, _mean(dep), _mean(straight), _mean(greedy), _mean(gems), _mean(t2), _mean(t2g), _mean(t3), _mean(wear)])
		check(_mean(dep) >= 6.0 and _mean(dep) <= 16.0, "depth %.0f: about 8 to 14 deposits per segment (%.1f)" % [depth, _mean(dep)])
		check(_mean(t3) >= 45.0 and _mean(t3) <= 75.0, "depth %.0f: 45 to 75 s at 3 bars, the balanced power (%.1f)" % [depth, _mean(t3)])
		check(_mean(t2) >= 55.0 and _mean(t2) <= 95.0, "depth %.0f: 2 bars is slower but not a crawl (%.1f)" % [depth, _mean(t2)])
		check_lt(_mean(t3), _mean(t2), "depth %.0f: 3 bars is faster" % depth)
		check_gt(_mean(greedy), _mean(straight) * 2.0, "depth %.0f: weaving pays (%.1f against %.1f)" % [depth, _mean(greedy), _mean(straight)])
		if depth == 240.0:
			check(_mean(straight) >= 10.0 and _mean(straight) <= 35.0, "mid depth: straight about 15 to 25 ore (%.1f)" % _mean(straight))
			check(_mean(greedy) >= 60.0 and _mean(greedy) <= 150.0, "mid depth: greedy 60 to 150 ore (%.1f)" % _mean(greedy))
			check(_mean(wear) >= 0.3 and _mean(wear) <= 0.5, "mid depth: a bit lasts 2 to 3 greedy segments (wear %.2f each)" % _mean(wear))
