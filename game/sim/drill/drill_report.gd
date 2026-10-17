class_name DrillReport
extends RefCounted
## The "segment_done" event's payload, built from a DrillSim's public fields at arrival (moved out of
## drill_sim.gd to keep it short). Static and read-only.


static func segment_done(d: DrillSim) -> Dictionary:
	var counts: Dictionary = {}
	var yields: Dictionary = {}
	for code: int in range(1, d.materials.size()):
		var mid: String = str(d.materials[code].get("id", ""))
		if d.mined[code] > 0:
			counts[mid] = d.mined[code]
		if d.yield_mat[code] > 0:
			yields[mid] = d.yield_mat[code]
	return {
		"segment": d.segment_id,
		"time_s": snappedf(float(d.segment_ticks) / Sim.TICK_HZ, 0.01),
		"distance_m": snappedf(d.distance_m, 0.01),
		"mined": counts,
		"yield": yields,
		"ore": d.yielded[RunState.RESOURCES.find("ore")],
		"gems": d.yielded[RunState.RESOURCES.find("gems")],
		"noise": snappedf(d.noise_segment, 0.01),
		"lost_water_ml": d.lost_water_ml,
		"gas_bursts": d.gas_bursts,
		"rockfalls": d.verbs.rockfalls,
		"blasts": d.verbs.blasts,
		"structure": d.structures.id,
		"entered": d.structures.entered,
		"crates": d.structures.crates_opened,
	}
