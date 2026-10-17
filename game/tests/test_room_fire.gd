extends TestCase
## RoomFire's pure functions: flame height from the fire level, smoke amount and decay, scorch decay.


func test_flame_height_follows_fire() -> void:
	var h: float = 240.0
	check_lt(RoomFire.flame_height_px(0.1, h), h * 0.15, "a lick along the floor at 0.1")
	check_gt(RoomFire.flame_height_px(1.0, h), h * 0.55, "about 60 percent of the room at full fire")
	check_lt(RoomFire.flame_height_px(1.0, h), h * 0.65, "not more than about 60 percent")
	check_gt(RoomFire.flame_height_px(0.6, h), RoomFire.flame_height_px(0.3, h), "taller with more fire")
	check_gt(RoomFire.flame_span(1.0), RoomFire.flame_span(0.1), "spreads wider with more fire")
	check_lt(RoomFire.flame_span(1.0), 1.0, "never wider than the room")


func test_smoke_target_grows_and_clears() -> void:
	check_eq(RoomFire.smoke_target(0.0, 99.0), 0.0, "no fire, no smoke target")
	check_gt(RoomFire.smoke_target(0.1, 0.0), 0.0, "a small fire still smokes")
	check_gt(RoomFire.smoke_target(0.8, 0.0), RoomFire.smoke_target(0.2, 0.0), "more fire, more smoke")
	check_gt(RoomFire.smoke_target(0.3, 40.0), RoomFire.smoke_target(0.3, 0.0), "burning longer, more smoke")
	check_lt(RoomFire.smoke_target(1.0, 99.0), 1.0001, "capped at 1")


func test_smoke_thins_out_in_about_8_seconds() -> void:
	var s: float = 1.0
	for i: int in range(60 * 8):
		s = RoomFire.smoke_step(s, 0.0, 1.0 / 60.0)
	check_lt(s, 0.02, "the haze is gone after 8 s")
	var rise: float = RoomFire.smoke_step(0.0, 1.0, 1.0)
	check_gt(rise, 0.0, "the haze thickens")
	check_lt(rise, 1.0, "but not in one step")
	check_eq(RoomFire.smoke_step(0.5, 0.5, 1.0), 0.5, "holds at the target")


func test_scorch_builds_and_fades_over_30_seconds() -> void:
	var s: float = 0.0
	for i: int in range(60 * 10):
		s = RoomFire.scorch_step(s, 0.8, 1.0 / 60.0)
	check_eq(s, 1.0, "a long fire scorches fully")
	for i: int in range(60 * 15):
		s = RoomFire.scorch_step(s, 0.0, 1.0 / 60.0)
	check_gt(s, 0.4, "still there after 15 s")
	for i: int in range(60 * 16):
		s = RoomFire.scorch_step(s, 0.0, 1.0 / 60.0)
	check_eq(s, 0.0, "gone after 31 s")


func test_upstairs_haze_is_thinner() -> void:
	check_eq(RoomFire.shown_haze(0.0, 1.0), RoomFire.UPSTAIRS_SHARE, "the room above shows a share")
	check_lt(RoomFire.shown_haze(0.0, 1.0), 1.0, "thinner than below")
	check_eq(RoomFire.shown_haze(0.9, 0.2), 0.9, "its own smoke wins when thicker")


func test_view_burns_smokes_and_forgets() -> void:
	var s := Sim.new(db(), 3, "light_drill")
	var v := ShipView.new()
	v.setup(s, s.player, 80.0)
	var ship: Ship = s.player.ship
	var drill: Room = ship.rooms[ship.room_index("drill")]
	var reactor: Room = ship.rooms[ship.room_index("reactor")]
	v._process(0.016)
	check(not v._fire._haze_nodes[drill.index].visible, "idle rooms draw no haze")
	check(not v._fire._tongues[drill.index].emitting, "idle rooms emit nothing")
	drill.fire = 0.8
	for i: int in range(120):
		v._process(0.016)
	var f: RoomFire = v._fire
	check(f._tongues[drill.index].emitting, "a burning room emits flames")
	check(f._smoke_p[drill.index].emitting, "and smoke")
	check_gt(f._smoke[drill.index], 0.3, "the haze thickens under the ceiling")
	check(f._haze_nodes[drill.index].visible, "the haze node shows")
	check_gt(f._haze_in[reactor.index], 0.2, "the room above the hatch borrows some haze")
	check(f._haze_nodes[reactor.index].visible, "and shows it")
	check(f._lights[drill.index].enabled, "the fire light is on")
	check_gt(f._lights[drill.index].energy, 0.5, "and it has energy")
	check(not f._lights[ship.room_index("coolant")].enabled, "other rooms keep their light off")
	drill.fire = 0.0
	for i: int in range(60 * 9):
		v._process(1.0 / 60.0)
	check_lt(f._smoke[drill.index], 0.02, "the haze has thinned out after 9 s")
	check_gt(f._scorch[drill.index], 0.5, "the scorch is still there")
	check(not f._tongues[drill.index].emitting, "no flames once out")
	v.rebind(s, s.player)
	check_eq(f._scorch[drill.index], 0.0, "a rebind clears the scorch")
	check(not f._scorch_nodes[drill.index].visible, "and hides it")
	v.free()
