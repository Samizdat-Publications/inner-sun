extends TestCase
## The visible pause (view only): freezing the world view nodes stops their animation clocks and their
## particles and thawing restores them, the HUD layer is never touched, and who gets frozen is decided
## by Main.world_frozen (a person's pause or a replay's, never a bot's unless a capture asks).


func _burning_view() -> Dictionary:
	var s := Sim.new(db(), 3, "light_drill")
	var v := ShipView.new()
	v.setup(s, s.player, 80.0)
	var drill: Room = s.player.ship.rooms[s.player.ship.room_index("drill")]
	drill.fire = 0.8
	for i: int in range(60):
		v._process(0.016)
	return {"sim": s, "view": v, "room": drill}


func _particles(n: Node, out: Array[CPUParticles2D]) -> void:
	var p: CPUParticles2D = n as CPUParticles2D
	if p != null:
		out.append(p)
	for c: Node in n.get_children():
		_particles(c, out)


func test_frozen_view_stands_still_and_thaws() -> void:
	var made: Dictionary = _burning_view()
	var v: ShipView = made["view"]
	var drill: Room = made["room"]
	var all: Array[CPUParticles2D] = []
	_particles(v, all)
	check_gt(float(all.size()), 10.0, "the ship view has particles to freeze")
	var flame: CPUParticles2D = v._fire._tongues[drill.index]
	check_gt(flame.speed_scale, 0.1, "a burning room's flames run before the freeze")
	var before_scale: float = flame.speed_scale
	var t0: float = v._time
	var lamp_e: float = v._alarms[drill.index].energy
	v.frozen = true
	for i: int in range(30):
		v._process(0.016)
	check_eq(v._time, t0, "no animation time passes while frozen")
	check_eq(v._alarms[drill.index].energy, lamp_e, "the alarm light stops flickering")
	for p: CPUParticles2D in all:
		check_eq(p.speed_scale, 0.0, "every particle is held (%s)" % str(p.name))
	v.frozen = false
	check_gt(flame.speed_scale, 0.0, "thawing gives the flames their speed back")
	v._process(0.016)
	check_gt(v._time, t0, "time passes again after the thaw")
	check_gt(flame.speed_scale, 0.1, "and the flames run on")
	check(not flame.has_meta(WorldFreeze.META), "the saved speed is cleared")
	v.free()


func test_freeze_does_not_change_the_sim() -> void:
	var a := Sim.new(db(), 5, "light_drill")
	var b := Sim.new(db(), 5, "light_drill")
	var v := ShipView.new()
	v.setup(b, b.player, 80.0)
	run_seconds(a, 2.0)
	for i: int in range(roundi(2.0 * Sim.TICK_HZ)):
		v.frozen = (i / 30) % 2 == 0
		v._process(0.016)
		b.step()
	check_eq(a.state_hash(), b.state_hash(), "freezing the view never touches the sim")
	v.free()


func test_other_world_layers_freeze_too() -> void:
	var s := Sim.new(db(), 3, "light_drill")
	var fx := DigFx.new()
	fx.setup(s, null, 80.0)
	fx._process(0.1)
	var t0: float = fx._t
	fx.frozen = true
	fx._process(0.1)
	check_eq(fx._t, t0, "the dig effects' clock stops")
	fx.frozen = false
	fx._process(0.1)
	check_gt(fx._t, t0, "and runs again")
	var rv := RockView.new()
	check_eq(WorldFreeze.dt(true, 0.5), 0.0, "frozen time is zero")
	check_eq(WorldFreeze.dt(false, 0.5), 0.5, "thawed time is the frame time")
	check_eq(rv.frozen, false, "the rock view starts thawed")
	rv.free()
	fx.free()


func test_veil_sits_between_world_and_hud_over_the_world_rect() -> void:
	var p := PauseLayer.new()
	check(p.layer < 10, "the veil layer is below the run screen (layer 10)")
	check(p.layer > 0, "and above the world")
	p.set_state(true, true)
	p.settle()
	check(p.is_dimming(), "it dims when asked")
	check(p._veil.visible, "the veil shows")
	check(p._label.visible, "a pause shows the big line")
	check_eq(p._label.text, "PAUSED: SPACE TO RESUME", "its words")
	check_eq(Rect2(p._veil.position, p._veil.size), RunScreen.WORLD_RECT, "the veil covers the world area only")
	p.set_state(true, false)
	check(not p._label.visible, "a held page gets the veil but not the big line")
	p.set_state(false, true)
	p.settle()
	check(not p._veil.visible and not p._label.visible, "unpausing clears both")
	p.free()


func test_who_gets_frozen() -> void:
	var m := Main.new()
	m.paused = false
	check(not m.world_frozen(), "running is not frozen")
	m.paused = true
	check(m.world_frozen(), "a person's pause freezes the world")
	m.bot_driven = true
	check(not m.world_frozen(), "a bot-driven run is never frozen")
	m.pause_demo = true
	check(m.world_frozen(), "unless a capture asks for the paused still")
	m.pause_demo = false
	m.bot_driven = false
	m.replaying = true
	check(m.world_frozen(), "a replay paused with Space looks paused")
	m.paused = false
	check(not m.world_frozen(), "and runs when not paused")
	m.free()
