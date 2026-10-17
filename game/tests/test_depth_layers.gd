extends TestCase
## The depth layers' pure functions (view only): depth bands (25 to 60 m thick, a tint per band, a short
## blend at the boundary) and the silhouette slots (an integer hash of the segment and the slot).


func test_band_boundaries_rise_and_bands_are_25_to_60_m() -> void:
	var worst_lo: float = 1000.0
	var worst_hi: float = 0.0
	for k: int in range(-5, 400):
		var t: float = DepthLayers.band_thickness(k)
		worst_lo = minf(worst_lo, t)
		worst_hi = maxf(worst_hi, t)
	check_gt(worst_lo, 24.9, "no band thinner than 25 m")
	check_lt(worst_hi, 60.1, "no band thicker than 60 m")


func test_band_index_matches_boundaries() -> void:
	var d: float = 0.0
	while d < 3000.0:
		var k: int = DepthLayers.band_index(d)
		check(DepthLayers.band_boundary(k) <= d and d < DepthLayers.band_boundary(k + 1), "depth %.1f sits inside band %d" % [d, k])
		d += 7.3


func test_band_tint_is_stable_and_bands_differ() -> void:
	check_eq(DepthLayers.band_tint(12), DepthLayers.band_tint(12), "same band, same tint")
	var seen: Dictionary = {}
	for k: int in range(0, 60):
		var c: Color = DepthLayers.band_tint(k)
		seen[c.to_html()] = true
		check(c.r > 0.5 and c.r < 1.6 and c.g > 0.5 and c.g < 1.6 and c.b > 0.5 and c.b < 1.6, "tint %d stays moderate" % k)
	check_gt(float(seen.size()), 8.0, "bands do not all look alike")


func test_tint_blends_across_a_boundary_without_a_jump() -> void:
	var b: float = DepthLayers.band_boundary(3)
	var before: Color = DepthLayers.tint_at(b - 0.01)
	var after: Color = DepthLayers.tint_at(b + 0.01)
	check_lt(absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b), 0.05, "continuous at the boundary")
	var far_in: Color = DepthLayers.tint_at(b + 6.0)
	check(far_in.is_equal_approx(DepthLayers.band_tint(3)), "well inside a band the tint is the band's own")


func test_band_arrays_cover_the_segment() -> void:
	for top: float in [-4.0, 0.0, 37.5, 120.0, 900.0]:
		var bottom: float = top + 160.0
		var a: Dictionary = DepthLayers.band_arrays(top, bottom)
		var n: int = int(a["n"])
		var b: PackedFloat32Array = a["b"]
		var c: PackedVector3Array = a["c"]
		check_eq(b.size(), 32, "32 boundaries")
		check_eq(c.size(), 32, "32 colours")
		check(b[0] <= top and b[n] > bottom, "the bands span %.0f to %.0f m" % [top, bottom])
		for j: int in range(n):
			check(b[j] < b[j + 1], "boundaries rise")
		var k: int = int(a["k0"]) + 1
		check(is_equal_approx(c[1].x, DepthLayers.band_tint(k).r), "colours follow the band numbers")


func test_silhouette_slots_are_deterministic_and_sparse() -> void:
	var has: int = 0
	var kinds: Dictionary = {}
	for slot: int in range(-20, 480):
		var a: Dictionary = DepthLayers.shape_for(77, slot)
		var b: Dictionary = DepthLayers.shape_for(77, slot)
		check_eq(a, b, "slot %d repeats" % slot)
		var d: float = float(a["depth_m"])
		check(d >= float(slot) * DepthLayers.SLOT_M and d < float(slot + 1) * DepthLayers.SLOT_M, "slot %d keeps its shape inside it" % slot)
		if bool(a["has"]):
			has += 1
			kinds[int(a["kind"])] = true
	var frac: float = float(has) / 500.0
	check(frac > 0.45 and frac < 0.8, "about %d%% of slots hold a shape" % roundi(DepthLayers.SLOT_ODDS * 100.0))
	check_eq(kinds.size(), 4, "all four kinds of shape turn up")
	check(DepthLayers.shape_for(78, 5) != DepthLayers.shape_for(77, 5) or DepthLayers.shape_for(78, 6) != DepthLayers.shape_for(77, 6), "another segment places differently")


func test_shape_outlines_are_polygons() -> void:
	for kind: int in range(4):
		var pts: PackedVector2Array = DepthLayers.shape_points(kind, 6.0, 5.0, 9)
		check_gt(float(pts.size()), 2.0, "kind %d has an outline" % kind)
		check(not Geometry2D.triangulate_polygon(pts).is_empty(), "kind %d triangulates" % kind)


func test_layer_factors_order_far_to_near() -> void:
	check(DepthLayers.F_FAR < DepthLayers.F_MID and DepthLayers.F_MID < 1.0 and 1.0 < DepthLayers.F_DUST, "far wall, silhouettes, rock, dust")
