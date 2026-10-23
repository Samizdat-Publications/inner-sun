extends TestCase
## Build 6 feedback (Stewart, 2026-10-22): a power key that cannot work says why and flashes the
## power board; the DOUSE button names the real blocker; an in-fight crew hint says that crew go where
## they are sent.


func _run_sim() -> Sim:
	var s := Sim.new(db(), 5, "light_drill", {"mode": "run"})
	s.step()
	return s


func _last_power_refusal(s: Sim) -> Dictionary:
	for i: int in range(s.events.size() - 1, -1, -1):
		var e: Dictionary = s.events[i]
		if str(e["kind"]) == "bad_command" and str(e.get("type", "")) == "power":
			return e
	return {}


func _wreck_reactor(s: Sim, bars: float) -> void:
	s.systems.damage_room(s, s.player, s.ship.room_with_system("reactor"), bars)


func test_power_with_no_free_bar_is_refused_out_loud() -> void:
	var s: Sim = _run_sim()
	var used: int = s.systems.allocated(s.player)
	var free: int = s.systems.free_bars(s.player)
	s.push({"type": "power", "room": "coolant", "bars": 3})
	s.step()
	check_eq(_last_power_refusal(s).size(), 0 if room(s, "coolant").sys_power == 3 else 1, "a granted change says nothing")
	# Wreck the reactor until nothing is free, then ask for a coolant bar.
	_wreck_reactor(s, 5.0)
	s.step()
	check_eq(s.systems.free_bars(s.player), 0, "no free bar after the hits (was %d free, %d used)" % [free, used])
	var before: int = room(s, "weapons").sys_power
	s.push({"type": "power", "room": "weapons", "bars": before + 1})
	s.step()
	var e: Dictionary = _last_power_refusal(s)
	check_eq(str(e.get("room", "")), "weapons", "the refusal names the room")
	check_eq(str(e.get("why", "")), "no free bars", "and says the reactor had no free bar")
	check_eq(int(e.get("got", -1)), before, "nothing was granted")
	var text: String = DigCallouts.power_refusal_text(s, "weapons", "no free bars")
	check(text.begins_with("NO FREE POWER: REACTOR DAMAGED"), "the callout names the damaged reactor: " + text)
	check(not DigCallouts.message_for(s, e).is_empty(), "and the callouts show it")
	var f: Dictionary = PowerPanel.flash_for(s, e)
	check_eq(int(f.get("room", -1)), s.ship.room_index("weapons"), "the power board flashes the weapons row")
	check(bool(f.get("reactor", false)), "and the reactor")


func test_asking_for_more_than_installed_is_not_an_error() -> void:
	var s: Sim = _run_sim()
	s.push({"type": "power", "room": "coolant", "bars": 0})
	s.step()
	var n0: int = s.events.size()
	s.push({"type": "power", "room": "coolant", "bars": 9})
	s.step()
	var refused: bool = false
	for i: int in range(n0, s.events.size()):
		if str(s.events[i]["kind"]) == "bad_command":
			refused = true
	check(not refused or s.systems.free_bars(s.player) < room(s, "coolant").sys_max, "only a real shortfall is refused")


func test_damaged_system_refusal_says_damaged() -> void:
	var s: Sim = _run_sim()
	s.systems.damage_room(s, s.player, s.ship.room_index("coolant"), 2.0)
	s.step()
	s.push({"type": "power", "room": "coolant", "bars": 3})
	s.step()
	var e: Dictionary = _last_power_refusal(s)
	check_eq(str(e.get("why", "")), "damaged", "broken bars are named as damage")
	check(DigCallouts.power_refusal_text(s, "coolant", "damaged").contains("SEND CREW TO REPAIR"), "and tell the player what fixes it")
	check(not bool(PowerPanel.flash_for(s, e).get("reactor", true)), "the reactor does not flash for the system's own damage")


func test_douse_button_names_no_free_power() -> void:
	var s: Sim = _run_sim()
	s.push({"type": "power", "room": "coolant", "bars": 0})
	s.step()
	check(DouseLayer.reason_text(s, "power coolant").begins_with("POWER COOLANT"), "with a free bar: power coolant (T)")
	_wreck_reactor(s, 8.0)
	s.step()
	check_eq(DouseLayer.reason_text(s, "power coolant"), "NO FREE POWER", "with none free, the button says so instead of naming T")


func test_crew_hint_fires_in_a_fight() -> void:
	check(HintDirector.NAMES.has("crew_fight"), "the in-fight crew hint exists")
	check(HintDirector.FIGHT_NAMES.has("crew_fight"), "and may fire in a fight")
	var s: Sim = _run_sim()
	check(not HintDirector.line_for(s, "crew_fight", 0).is_empty(), "with a TOPSIDE line")
	check(not HintDirector.line_for(s, "crew_fight", 0).contains(char(0x2014)), "and no em dash")
