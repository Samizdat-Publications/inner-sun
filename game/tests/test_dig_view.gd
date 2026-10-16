extends TestCase
## The dig view's pure helpers (M1b round 3): the drilling camera numbers, the water surface, and the
## crew marks' colours. Nothing here draws; the look is judged on the captured stills.


func test_default_zoom_shows_about_twenty_meters() -> void:
	var z: float = DigCamera.default_zoom(1180.0, 80.0)
	check(absf(1180.0 / (z * 80.0) - 20.0) < 0.1, "the world area shows about 20 m across")
	check(z >= DigCamera.ZOOM_MIN and z <= DigCamera.ZOOM_MAX, "inside the wheel range")


func test_wheel_steps_stay_in_range() -> void:
	var z: float = 0.74
	for i: int in range(40):
		z = DigCamera.stepped(z, 1)
	check(absf(z - DigCamera.ZOOM_MAX) < 0.0001, "zooming in stops at the maximum")
	for i: int in range(80):
		z = DigCamera.stepped(z, -1)
	check(absf(z - DigCamera.ZOOM_MIN) < 0.0001, "zooming out stops at the minimum")
	check_gt(DigCamera.stepped(0.7, 1), 0.7, "wheel up zooms in")
	check(DigCamera.stepped(0.7, -1) < 0.7, "wheel down zooms out")


func test_crown_sits_low_enough_for_the_tower_and_never_above_a_third() -> void:
	var ship_h: float = 720.0
	var area_h: float = 938.0
	var f: float = DigCamera.crown_frac(ship_h, area_h, 0.74)
	check(f > 0.5 and f <= DigCamera.FRAC_MAX, "at the default zoom the whole tower fits with rock below")
	check(DigCamera.crown_frac(ship_h, area_h, DigCamera.ZOOM_MIN) >= DigCamera.FRAC_MIN, "zoomed far out the crown stays in the upper third or lower")
	# The crown's screen height follows from the centre the camera is given.
	var c: Vector2 = DigCamera.center_for(500.0, 2000.0, ship_h, area_h, 0.74)
	var crown_below_center: float = (2000.0 - c.y) * 0.74
	check(absf(crown_below_center - (f - 0.5) * area_h) < 0.01, "the crown lands where crown_frac says")


func test_water_surface_tilts_with_slosh_and_stays_finite() -> void:
	var rp := Rect2(0.0, 0.0, 320.0, 240.0)
	var left_y: float = RoomWater.wave(rp, 10.0, 0.0, 1.0, 0.0, 0)
	var right_y: float = RoomWater.wave(rp, 310.0, 0.0, 1.0, 0.0, 0)
	check(absf(right_y - left_y) > 20.0, "a full slosh tilts the surface across the room")
	var calm: float = absf(RoomWater.wave(rp, 160.0, 1.0, 0.0, 0.0, 0))
	check(calm < 4.0, "calm water only swells a little")
	for i: int in range(20):
		var y: float = RoomWater.wave(rp, float(i) * 16.0, float(i) * 0.37, 5.0, 3.0, 1)
		check(is_finite(y) and absf(y) < 80.0, "the wave is bounded even with wild inputs")


func test_crew_accents_differ_and_enemies_are_red() -> void:
	var seen: Dictionary = {}
	for c: Color in CrewMarks.ACCENTS:
		seen[c.to_html()] = true
	check_eq(seen.size(), CrewMarks.ACCENTS.size(), "every crew accent is its own colour")
	check(CrewMarks.ENEMY_ACCENT.r > CrewMarks.ENEMY_ACCENT.b, "rivals wear red")
