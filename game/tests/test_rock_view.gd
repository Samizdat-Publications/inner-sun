extends TestCase
## The rock view's incremental painting: after drilling with budgeted, strip-by-strip repaints, the
## mosaic (albedo, normal and material ids) is byte-identical to a fresh paint of the same grid, and
## the scanner's patched image matches a fresh scanner. A fresh view never paints everything in one
## frame. (When the strip painter replaced the whole-chunk painter, both were checked byte-identical
## against the old code, fresh and after drilling.)


func _seg(p_seed: int, depth: float, lateral: float) -> Sim:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 3})
	s.step()
	s.push({"type": "begin_segment", "segment": "a", "depth_m": depth, "lateral_m": lateral})
	s.step()
	return s


func _same(a: RockView, b: RockView, what: String) -> void:
	check(a._img_a.get_data() == b._img_a.get_data(), what + ": albedo identical")
	check(a._img_n.get_data() == b._img_n.get_data(), what + ": normal identical")
	check(a._img_id.get_data() == b._img_id.get_data(), what + ": material ids identical")


func test_incremental_repaint_matches_fresh_paint() -> void:
	var s: Sim = _seg(11, 12.0, 6.0)
	var v := RockView.new()
	v.setup(s.drill, 80.0)
	v._process(0.016)
	check(v.pending() > 0, "a fresh segment is not painted in one frame")
	v.paint_all_now()
	check_eq(v.pending(), 0, "nothing left after painting everything")
	var bot: Bot = Bot.make("drill")
	s.push({"type": "steer", "angle": 30.0})
	for i: int in range(60 * 12):
		if i == 60 * 4:
			s.push({"type": "steer", "angle": -30.0})
		if i > 60 * 8:
			bot.act(s)
		s.step()
		if i % 3 == 0:
			v._process(0.016)
	v._process(0.016)  # A frame after the last step: cuts in the last ticks are noticed only in _process.
	var guard: int = 0
	while v.pending() > 0 and guard < 10000:
		v._process(0.016)
		guard += 1
	check_eq(v.pending(), 0, "the incremental repaint finishes")
	var fresh := RockView.new()
	fresh.setup(s.drill, 80.0)
	fresh.paint_all_now()
	check_gt(float(v.strips_painted), float(fresh.strips_painted), "drilling repainted strips")
	_same(v, fresh, "after drilling")
	v.free()
	fresh.free()


func test_scanner_patches_match_fresh_scanner() -> void:
	var s: Sim = _seg(5, 40.0, 8.0)
	s.push({"type": "steer", "angle": 30.0})
	var sc := ScannerPanel.new()
	sc.bind(s)
	var bot: Bot = Bot.make("drill")
	var compared: int = 0
	for i: int in range(60 * 20):
		if i == 60 * 6:
			s.push({"type": "steer", "angle": -30.0})
		if i > 60 * 8:
			bot.act(s)
		s.step()
		if not s.drill.active:
			break
		if i % 5 == 0:
			sc._refresh_image()
		if i % 97 == 0:
			var fresh := ScannerPanel.new()
			fresh.bind(s)
			fresh._refresh_image()
			sc._refresh_image()
			check(sc._img.get_data() == fresh._img.get_data(), "scanner image matches a fresh one at tick %d" % i)
			check(str(sc._glints) == str(fresh._glints), "scanner glints match a fresh one at tick %d" % i)
			fresh.free()
			compared += 1
	check_gt(float(compared), 5.0, "compared enough moments")
	sc.free()
