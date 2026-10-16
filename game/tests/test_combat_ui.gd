extends TestCase
## The combat console (weapon cards, flee button) and its pure helpers. Controls here are never
## drawn: only what they read from the sim and which commands they push.

func _fight() -> Sim:
	var s := Sim.new(db(), 7, "light_drill", {"mode": "run"})
	s.combat.start_fight(s, "rival_light", false)
	s.step()
	return s


func test_cards_hidden_without_a_fight() -> void:
	var s := Sim.new(db(), 7, "light_drill", {"mode": "run"})
	var w: WeaponCards = WeaponCards.build(Control.new(), s)
	check(not w.in_fight(), "no fight, no console")
	check(not w.visible, "the console starts hidden")
	w.arm(0)
	check_eq(w.armed, -1, "nothing arms outside a fight")
	w.get_parent().free()


func test_cards_arm_and_target_commands() -> void:
	var s: Sim = _fight()
	var w: WeaponCards = WeaponCards.build(Control.new(), s)
	var n: int = s.combat.player_side.size()
	check_gt(float(n), 0.0, "the player has weapons")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = WeaponCards.card_rect(0, n).get_center()
	w._gui_input(click)
	check_eq(w.armed, 0, "a left click arms that card")
	w._gui_input(click)
	check_eq(w.armed, -1, "a second click disarms")
	s.push({"type": "target", "weapon": 0, "room": s.enemy.ship.rooms[1].id})
	s.step()
	check_eq(s.combat.player_side.target[0], 1, "the target command aims the slot")
	var right := InputEventMouseButton.new()
	right.pressed = true
	right.button_index = MOUSE_BUTTON_RIGHT
	right.position = click.position
	w._gui_input(right)
	s.step()
	check_eq(s.combat.player_side.target[0], -1, "a right click clears the target")
	check_eq(w.hit(WeaponCards.flee_rect().get_center()), -1, "the flee button is slot -1")
	w.get_parent().free()


func test_flee_status_matches_the_sim() -> void:
	var s: Sim = _fight()
	var st: Dictionary = WeaponCards.flee_status(s)
	check_eq(bool(st["allowed"]), str(st["why"]).is_empty(), "allowed exactly when there is no reason")
	check(not bool(st["fleeing"]), "not fleeing yet")
	check_gt(float(st["total_s"]), 0.0, "the flight has a length")
	var di: int = s.ship.room_with_system("drill")
	s.push({"type": "power", "room": s.ship.rooms[di].id, "bars": 2})
	run_seconds(s, 3.0)
	st = WeaponCards.flee_status(s)
	if bool(st["allowed"]):
		s.push({"type": "flee"})
		s.step()
		check(bool(WeaponCards.flee_status(s)["fleeing"]), "the flee command starts the flight")
	else:
		check(str(st["why"]).contains("HELM") or str(st["why"]).contains("DRILL"), "the reason names what is missing")
