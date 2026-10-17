extends TestCase
## The view of the away miner: the order card's words and status (MinerCard), the alert and the stop
## notice, the crew card's OUTSIDE line, the tally of the haul on return, the world layer's pure helpers
## and the help page's fit. Nothing here draws; the look is judged on the captured stills.


## A scenario-mode sim on light_drill with a segment begun, every rock cell outside the ship set to
## granite, crew judgement off, the drill still (no bars).
func _sim() -> Sim:
	var s := Sim.new(db(), 11, "light_drill")
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 0})
	crew_auto_off(s)
	s.step()
	s.push({"type": "begin_segment", "segment": "m", "depth_m": 36.0, "lateral_m": 0.0})
	s.step()
	var d: DrillSim = s.drill
	var ship := Rect2(d.ship_pos, d.ship_size)
	var rock: int = _code(s, "rock")
	for r: int in range(d.rows):
		for c: int in range(d.cols):
			if not ship.has_point(Vector2((c + 0.5) * d.cell_m, (r + 0.5) * d.cell_m)):
				d.grid[r * d.cols + c] = rock
	d._band_dirty = true
	return s


func _code(s: Sim, id: String) -> int:
	for c: int in range(s.drill.materials.size()):
		if str(s.drill.materials[c].get("id", "")) == id:
			return c
	return -1


func _queued(s: Sim, kind: String) -> Dictionary:
	for i: int in range(s._pending.size() - 1, -1, -1):
		if str(s._pending[i].get("type", "")) == kind:
			return s._pending[i]
	return {}


func _card(s: Sim, crew: String) -> MinerCard:
	var c := MinerCard.new()
	c.bind(s)
	c.crew_id_getter = func() -> String: return crew
	return c


# Words -------------------------------------------------------------------------------------------

func test_words_for_phases_reasons_and_hauls() -> void:
	check_eq(MinerCard.phase_word("dig"), "DIGGING", "the dig phase")
	check_eq(MinerCard.phase_word("vein"), "AT THE VEIN", "the vein phase")
	check_eq(MinerCard.phase_word("return"), "COMING HOME", "the way back")
	check_eq(MinerCard.reason_text(""), "", "no reason, no words")
	check_eq(MinerCard.reason_text("range", 12.0), "TOO FAR (12 M)", "out of range says the range")
	check_eq(MinerCard.reason_text("miner_out"), "A MINER IS ALREADY OUT", "a miner is already out")
	check_eq(MinerCard.reason_text("outside"), "NO ROCK THERE", "off the rock")
	var haul := PackedInt32Array()
	haul.resize(RunState.RESOURCES.size())
	check_eq(MinerCard.haul_text(haul), "", "an empty haul says nothing")
	haul[RunState.RESOURCES.find("ore")] = 12
	haul[RunState.RESOURCES.find("gems")] = 2
	check_eq(MinerCard.haul_text(haul), "+12 ORE +2 GEMS", "ore then gems, in capitals")
	check_eq(MinerCard.haul_text(haul, false), "+12 ore +2 gems", "or as the tag over the head")
	check_eq(MinerLayer.tag_text(haul), "+12 ore +2 gems", "the tag over the miner")
	check_eq(int(MinerCard.haul_dict(haul)["ore"]), 12, "the haul as a dictionary")
	check_eq(MinerCard.haul_dict(haul).size(), 2, "nonzero entries only")


# The card ----------------------------------------------------------------------------------------

func test_status_idle_and_blocked() -> void:
	var s: Sim = _sim()
	var st: Dictionary = MinerCard.status(s, "okafor")
	check(bool(st["ready"]) and not bool(st["out"]), "ready to send while drilling")
	check_eq(str(st["title"]), "SEND MINER: OKAFOR", "the title names the selected crew member")
	check(MinerCard.shown_for(s), "the card shows while a segment runs")
	check_eq(MinerCard.arm_why(s, "nobody"), "no_crew", "an unknown crew member cannot go")
	s.ship.crew_by_id("okafor").alive = false
	check_eq(MinerCard.arm_why(s, "okafor"), "no_crew", "a dead one cannot go")
	var idle := Sim.new(db(), 11, "light_drill")
	idle.step()
	check(not MinerCard.shown_for(idle), "no card between segments")
	check_eq(MinerCard.arm_why(idle, "okafor"), "no_segment", "and the reason is the segment")


func test_aim_sends_and_refuses_in_words() -> void:
	var s: Sim = _sim()
	var card: MinerCard = _card(s, "okafor")
	card.armed = true
	var head: Vector2 = DrillMiner.head(s.drill)
	check(not card.aim(head + Vector2(12.5, 1.0)), "too far is refused")
	check(card.armed, "and the card stays armed to try again")
	check_eq(card._flash, "TOO FAR (12 M)", "the flash says how far")
	check(_queued(s, "send_miner").is_empty(), "nothing was sent")
	check(not card.aim(Vector2(head.x, 0.5)), "above the ship is refused")
	check_eq(card._flash, "NO ROCK THERE", "in words")
	var at: Vector2 = head + Vector2(6.0, 2.0)
	check(card.aim(at), "a fair target is sent")
	var cmd: Dictionary = _queued(s, "send_miner")
	check_eq(str(cmd.get("crew", "")), "okafor", "for the selected crew member")
	check(absf(float(cmd.get("x_m", 0.0)) - at.x) < 0.01 and absf(float(cmd.get("y_m", 0.0)) - at.y) < 0.01, "at the clicked point")
	check(not card.armed, "sending disarms")
	card.free()


func test_arming_stands_the_blast_down_and_back() -> void:
	var s: Sim = _sim()
	var blast := BlastCard.new()
	blast.bind(s)
	var card: MinerCard = _card(s, "okafor")
	card.blast = blast
	blast.armed = true
	card.toggle()
	check(card.armed, "G arms the miner order")
	check(not blast.armed, "and disarms the blast")
	card.free()
	blast.free()


func test_recall_while_out() -> void:
	var s: Sim = _sim()
	var card: MinerCard = _card(s, "okafor")
	s.push({"type": "send_miner", "crew": "okafor", "x_m": 22.25, "y_m": 11.75})
	s.step()
	check(bool(MinerCard.status(s, "okafor")["out"]), "the card sees the sortie")
	check_eq(str(MinerCard.status(s, "okafor")["why"]), "miner_out", "no second sortie")
	s._pending.clear()
	card.toggle()
	check(not _queued(s, "recall_miner").is_empty(), "G (toggle) recalls while one is out")
	card.free()


func test_title_and_alert_while_out() -> void:
	var s: Sim = _sim()
	s.push({"type": "send_miner", "crew": "okafor", "x_m": 22.25, "y_m": 11.75})
	for i: int in range(60 * Sim.TICK_HZ):
		if s.drill.miner.phase == "dig":
			break
		s.step()
	check_eq(s.drill.miner.phase, "dig", "the miner is digging")
	check_eq(MinerCard.title_for(s, "vasquez"), "OKAFOR OUTSIDE: DIGGING", "the title names the one outside, not the selection")
	var found: bool = false
	for a: Dictionary in AlertsStrip.compute(s):
		if str(a["kind"]) == "miner":
			found = true
			check(str(a["text"]).begins_with("MINER OUTSIDE: OKAFOR "), "the chip names them and their hp")
	check(found, "a MINER OUTSIDE alert shows")
	check(s.drill.parked, "the drill is parked")
	var stop: Dictionary = AlertsStrip.drill_stop(s)
	check_eq(str(stop.get("notice", "")), "PARKED: OKAFOR IS OUTSIDE. G recalls.", "the stop notice says why")
	check(not str(stop.get("notice", "")).contains("POWER"), "a parked drill does not say no power")
	check_eq(CrewCards.job_text("sortie"), "TO HATCH", "a crew member on the way to the hatch")
	check(CrewCards.outside_line(s).begins_with("DIGGING"), "the crew card says what they are doing")
	check_eq(CrewCards.cause_text("miner_gas"), "OUTSIDE: GAS BURST", "a miner's death on the card")


# The tally ---------------------------------------------------------------------------------------

func test_haul_paid_on_return_joins_the_dig_tally() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	var iron: int = _code(s, "iron_ore")
	for r: int in range(22, 26):
		for c: int in range(42, 47):
			d.grid[r * d.cols + c] = iron
	var log := DigLog.new()
	log.bind(s)
	s.push({"type": "send_miner", "crew": "okafor", "x_m": 22.25, "y_m": 11.75})
	for i: int in range(120 * Sim.TICK_HZ):
		s.step()
		if not d.miner.active and i > 10:
			break
	log.update(s, 0.0)
	check_gt(float(s.run.get_res("ore")), 0.0, "the haul was paid")
	check_eq(log.ore, s.run.get_res("ore"), "the tally counts exactly what was paid")
	check_eq(int(log.totals.get("miner", 0)), log.ore + log.gems, "as its own entry")
	check(DigLog.pickup_text(log.pickups[log.pickups.size() - 1]).begins_with("MINER: +"), "and a text rises at the hatch")


# The world layer ---------------------------------------------------------------------------------

func test_layer_helpers() -> void:
	check_eq(MinerLayer.harness_color(0), CrewMarks.ACCENTS[0], "the first crew member's harness")
	check_eq(MinerLayer.harness_color(CrewMarks.ACCENTS.size() + 1), CrewMarks.ACCENTS[1], "the colours wrap")
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	check(not MinerLayer.digging_solid(d), "no one digging, no chips")
	s.push({"type": "send_miner", "crew": "okafor", "x_m": 22.25, "y_m": 11.75})
	var chips: bool = false
	for i: int in range(60 * Sim.TICK_HZ):
		s.step()
		if MinerLayer.digging_solid(d):
			chips = true
			break
	check(chips, "chips fly while a solid cell is dug")
	var cc: Vector2 = MinerLayer.cell_center(d, d.miner.next_cell)
	check(absf(fmod(cc.x, d.cell_m) - d.cell_m * 0.5) < 0.001, "the cell centre is in the middle of the cell")


func test_help_mentions_the_miner_and_fits() -> void:
	var text: String = "\n".join(HelpView.CONTROLS) + "\n".join(HelpView.WHEN)
	check(text.contains("MINER   G"), "the controls name the key")
	check(text.contains("AWAY MINER"), "the help has the paragraph")
	check(text.contains("lost if they die"), "and says the haul is lost with them")
	var h: float = HelpView.content_height(UiTheme.mono())
	check_lt(h, HelpView.FRAME.size.y - 190.0, "the help text still fits its frame (%.0f)" % h)


func test_view_files_have_no_em_dash() -> void:
	var dash: String = String.chr(0x2014)
	for p: String in ["res://view/hud/miner_card.gd", "res://view/miner_layer.gd"]:
		var f: FileAccess = FileAccess.open(p, FileAccess.READ)
		check(f != null, "%s opens" % p)
		if f != null:
			check(not f.get_as_text().contains(dash), "%s has no em dash" % p)
