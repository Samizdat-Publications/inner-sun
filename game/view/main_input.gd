class_name MainInput
extends RefCounted
## Main's unhandled input, moved out of it to keep that file short: replay pause, the wheel zoom, blast and
## miner aiming, DOUSE clicks, weapon targeting, crew orders, and the key bindings (F, H, Space, 1 to 3
## and the steering keys). Every order goes through the command chain on the Main `m`.

static func unhandled(m: Main, event: InputEvent) -> void:
	if m.replaying and m.run != null:
		var k: InputEventKey = event as InputEventKey
		if k != null and k.pressed and not k.echo and k.keycode == KEY_SPACE:
			m.paused = not m.paused
		return
	if m.bot_driven or m.run == null or m.view == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if not key.echo:
			on_key(m, key)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and not m.screen.overlay_open():
		ShipPick.of(m).motion(mm)
		return
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		ShipPick.of(m).release(mb)  # a box select ends, or a plain click on a room sends the crew
		return
	if mb == null or not mb.pressed or m.screen.overlay_open():
		return
	# The wheel over the world area zooms the drilling camera (the choice lasts for the run).
	var wheel: int = 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0)
	if wheel != 0:
		if m.rock_view != null and RunScreen.WORLD_RECT.has_point(mb.position):
			m.drill_zoom = DigCamera.stepped(m.drill_zoom, wheel)
			m.get_viewport().set_input_as_handled()
		return
	# Armed, a left click on the rock fires the charge launcher there (right click or Esc disarms).
	if m.screen.blast.armed and m.rock_view != null and RunScreen.WORLD_RECT.has_point(mb.position):
		if mb.button_index == MOUSE_BUTTON_LEFT:
			m.screen.blast.aim(m.world_to_m(mb.position))
			m.get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			m.screen.blast.disarm()
			m.get_viewport().set_input_as_handled()
			return
	# Armed, a left click on the rock sends the selected crew member out as the miner.
	if m.screen.miner.armed and m.rock_view != null and RunScreen.WORLD_RECT.has_point(mb.position):
		if mb.button_index == MOUSE_BUTTON_LEFT:
			m.screen.miner.aim(m.world_to_m(mb.position))
			m.get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			m.screen.miner.disarm()
			m.get_viewport().set_input_as_handled()
			return
	# A click on a burning room's DOUSE button.
	if mb.button_index == MOUSE_BUTTON_LEFT and m.douse != null:
		var burning_id: String = m.douse.room_at(mb.position)
		if not burning_id.is_empty():
			m.run.sim.push({"type": "douse", "room": burning_id})
			m.get_viewport().set_input_as_handled()
			return
	# The cutaway: a door, hatch or vent toggles, a figure selects, a press on a room starts a click or a box
	# (ShipPick); these come before any crew order.
	if mb.button_index == MOUSE_BUTTON_LEFT and ShipPick.of(m).press(mb):
		m.get_viewport().set_input_as_handled()
		return
	# In a fight, a left click on an enemy room with a weapon armed aims it (a command, like all orders).
	var wc: WeaponCards = m.screen.weapons
	if mb.button_index == MOUSE_BUTTON_LEFT and wc.armed >= 0 and m.combat_view.active():
		var er: int = m.combat_view.enemy_room_at(mb.position)
		if er >= 0:
			m.run.sim.push({"type": "target", "weapon": wc.armed, "room": m.run.sim.enemy.ship.rooms[er].id})
			wc.disarm()
			m.get_viewport().set_input_as_handled()
			return
	# Right click releases the selected crew back to their own judgement (the left click is ShipPick's:
	# a room click sends them, through the same command chain the bots use).
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		for id: String in ShipPick.of(m).current():
			m.run.sim.push({"type": "release", "crew": id})


## F puts out the worst fire (one command, like a click on its button); the callouts say why not.
static func douse_worst(m: Main) -> void:
	var id: String = DouseLayer.worst(m.run.sim)
	if id.is_empty():
		m.screen.callouts.push_line("NO FIRE TO DOUSE", "info")
		return
	m.run.sim.push({"type": "douse", "room": id})


static func on_key(m: Main, key: InputEventKey) -> void:
	var code: Key = key.keycode
	if key.pressed and code == KEY_ESCAPE and not m.screen.overlay_open() and m.screen.weapons.armed < 0 and not m.screen.blast.armed and not m.screen.miner.armed:
		ShipPick.of(m).clear()
		return
	if key.pressed and (code == KEY_F or key.physical_keycode == KEY_F) and not m.screen.overlay_open() and not key.shift_pressed:
		douse_worst(m)
		return
	if key.pressed and code == KEY_H and m.screen.help.is_open():
		m.screen.help.close_help()
		return
	if key.pressed and code == KEY_H and not m.screen.codex.is_open() and not m.screen.death.is_open():
		m.screen.help.open()
		return
	if key.pressed and code == KEY_SPACE and not m.screen.overlay_open():
		m.paused = not m.paused
		return
	if key.pressed and code >= KEY_1 and code <= KEY_3 and not m.screen.overlay_open():
		m.screen.cards.select_index(int(code - KEY_1))
		return
	drill_key(m, key)


## Steering while drilling (SteerControl): A and D step the heading 15 degrees and repeat while held, S
## points straight down, Shift plus A or D holds depth. Drill power is on the power panel. Commands, like
## the bots use.
static func drill_key(m: Main, key: InputEventKey) -> void:
	var d: DrillSim = m.run.sim.drill
	if not d.active:
		return
	if not key.pressed:
		m._steer.release(key.keycode)
		return
	var a: float = m._steer.press(key.keycode, key.shift_pressed, m.screen.scanner.target_heading(), m.run.sim.db.tune("drill.max_heading_deg"))
	if not is_nan(a):
		m.screen.scanner.queue_steer(a)
