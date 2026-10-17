class_name CrewCards
extends Control
## One card per crew member: name, HP bar, what they are doing and where, skills. Click a card to
## select that crew member. A hurt crew member's card flashes red; the dead are greyed with the cause.
##
## Mount (main.gd, on the HUD CanvasLayer, 1920x1080 design space):
##   var cards: CrewCards = CrewCards.build(layer, sim)
##   cards.crew_selected.connect(_on_crew_selected)     # (crew_id: String)
##   cards.selected_id                                  # the selected crew id, read it for orders
##   cards.select_index(0)                              # keys 1 to 3 can call this
##   cards.bind(new_sim)

signal crew_selected(crew_id: String)

const WIDTH: float = 400.0
const HEAD_H: float = 42.0
const CARD_H: float = 112.0
const GAP: float = 5.0
const TOP: float = 512.0
const JOB_LABEL: Dictionary = {"": "IDLE", "extinguish": "EXTINGUISH", "patch": "PATCH", "repair": "REPAIR", "go": "GO TO", "sortie": "TO HATCH"}
const JOB_ICON: Dictionary = {"": "", "extinguish": "flame", "patch": "hammer", "repair": "hammer", "go": "", "sortie": ""}
const FLASH_S: float = 0.8

var sim: Sim = null
var selected_id: String = ""
var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()  ## Redraws at most 60 times a second.
var _hp_last: Dictionary = {}
var _flash: Dictionary = {}
var _hp_shown: Dictionary = {}


static func build(parent: Control, p_sim: Sim) -> CrewCards:
	var p := CrewCards.new()
	p.position = Vector2(1920.0 - WIDTH, TOP)
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_hp_last.clear()
	_flash.clear()
	_hp_shown.clear()
	selected_id = ""
	if sim != null:
		for c: CrewMember in sim.ship.crew:
			_hp_last[c.id] = c.hp
			_hp_shown[c.id] = c.hp
		if not sim.ship.crew.is_empty():
			selected_id = sim.ship.crew[0].id
		size = Vector2(WIDTH, HEAD_H + float(sim.ship.crew.size()) * (CARD_H + GAP) + 4.0)
	queue_redraw()


func snap() -> void:
	if sim == null:
		return
	for c: CrewMember in sim.ship.crew:
		_hp_shown[c.id] = c.hp
		_hp_last[c.id] = c.hp
	_flash.clear()


func select_index(i: int) -> void:
	if sim == null or i < 0 or i >= sim.ship.crew.size():
		return
	select(sim.ship.crew[i].id)


func select(crew_id: String) -> void:
	if sim == null or sim.ship.crew_by_id(crew_id) == null:
		return
	selected_id = crew_id
	crew_selected.emit(crew_id)


static func card_rect(i: int) -> Rect2:
	return Rect2(10.0, HEAD_H + float(i) * (CARD_H + GAP), WIDTH - 20.0, CARD_H)


## Which crew index is at a panel-space point, or -1.
func index_at(p: Vector2) -> int:
	if sim == null:
		return -1
	for i: int in range(sim.ship.crew.size()):
		if card_rect(i).has_point(p):
			return i
	return -1


static func job_text(job_kind: String) -> String:
	return str(JOB_LABEL.get(job_kind, job_kind.to_upper()))


static func cause_text(cause: String) -> String:
	match cause:
		"fire":
			return "BURNED"
		"drowned":
			return "DROWNED"
		"heat":
			return "HEAT"
		"event":
			return "LOST IN THE DARK"
		"miner_gas":
			return "OUTSIDE: GAS BURST"
		"miner_water":
			return "OUTSIDE: WATER BURST"
		"miner_rockfall":
			return "OUTSIDE: ROCKFALL"
		"miner_strike":
			return "OUTSIDE: STRUCK"
	return cause.to_upper() if not cause.is_empty() else "UNKNOWN"


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var i: int = index_at(mb.position)
	if i >= 0:
		select(sim.ship.crew[i].id)
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	if sim != null:
		for c: CrewMember in sim.ship.crew:
			if c.hp < float(_hp_last.get(c.id, c.hp)) - 0.01:
				_flash[c.id] = FLASH_S
			_hp_last[c.id] = c.hp
			_hp_shown[c.id] = move_toward(float(_hp_shown.get(c.id, c.hp)), c.hp, (10.0 + absf(float(_hp_shown.get(c.id, c.hp)) - c.hp)) * delta)
			_flash[c.id] = maxf(0.0, float(_flash.get(c.id, 0.0)) - delta)
	if _pacer.due():
		queue_redraw()


func _draw() -> void:
	UiTheme.draw_panel(self, Rect2(Vector2.ZERO, size), "CREW")
	if sim == null:
		return
	for i: int in range(sim.ship.crew.size()):
		_draw_card(i, sim.ship.crew[i])


func _draw_card(i: int, c: CrewMember) -> void:
	var rect: Rect2 = card_rect(i)
	var selected: bool = c.id == selected_id
	var flash: float = clampf(float(_flash.get(c.id, 0.0)) / FLASH_S, 0.0, 1.0)
	draw_rect(rect, UiTheme.STEEL if c.alive else Color(0.07, 0.08, 0.09), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), Color(1, 1, 1, 0.05), true)
	if flash > 0.0:
		draw_rect(rect, Color(UiTheme.ALARM, 0.45 * flash), true)
	var edge: Color = UiTheme.BRASS_DARK
	if selected and c.alive:
		edge = UiTheme.AMBER
	draw_rect(rect, edge, false, 2.5 if selected else 1.0)
	if selected:
		draw_colored_polygon(PackedVector2Array([rect.position + Vector2(-8, 50), rect.position + Vector2(0, 44), rect.position + Vector2(0, 56)]), UiTheme.AMBER)
	var left: float = rect.position.x + 12.0
	var name_col: Color = UiTheme.TEXT if c.alive else UiTheme.TEXT_DIM
	# Hotkey badge and name.
	var badge := Rect2(left, rect.position.y + 9.0, 24, 24)
	draw_rect(badge, UiTheme.STEEL_DEEP, true)
	draw_rect(badge, UiTheme.BRASS if c.alive else UiTheme.BRASS_DARK, false, 1.0)
	UiTheme.text(self, Vector2(badge.position.x, badge.position.y + 18), str(i + 1), 17, UiTheme.BRASS_LIGHT if c.alive else UiTheme.TEXT_DIM, null, HORIZONTAL_ALIGNMENT_CENTER, 24.0)
	UiTheme.bold_text(self, Vector2(left + 34.0, rect.position.y + 29.0), c.name.to_upper(), 24, name_col)
	# HP bar.
	var bar := Rect2(left, rect.position.y + 42.0, rect.size.x - 24.0 - 56.0, 18.0)
	draw_rect(bar, UiTheme.STEEL_DEEP, true)
	var shown: float = clampf(float(_hp_shown.get(c.id, c.hp)) / CrewMember.MAX_HP, 0.0, 1.0)
	var now: float = clampf(c.hp / CrewMember.MAX_HP, 0.0, 1.0)
	if shown > now:
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * now, 0), Vector2(bar.size.x * (shown - now), bar.size.y)), UiTheme.ALARM, true)
	var hp_col: Color = UiTheme.CRT if now > 0.6 else (UiTheme.AMBER if now > 0.3 else UiTheme.ALARM)
	if not c.alive:
		hp_col = Color(0.3, 0.3, 0.3)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * now, bar.size.y)), hp_col, true)
	draw_rect(bar, UiTheme.BRASS_DARK, false, 1.0)
	UiTheme.bold_text(self, Vector2(bar.end.x + 8.0, bar.position.y + 16.0), "%d" % roundi(c.hp), 22, name_col)
	if not c.alive:
		UiTheme.bold_text(self, Vector2(left, rect.position.y + 90.0), "LOST: %s" % cause_text(c.cause_of_death), 20, UiTheme.ALARM)
		draw_line(rect.position + Vector2(6, 6), rect.end - Vector2(6, 6), Color(0.5, 0.15, 0.12, 0.45), 2.0)
		return
	# Job chip and place.
	var job: String = "away" if c.away else c.job_kind
	var label: String = job_text_for(c)
	var jw: float = UiTheme.text_width(label, 17) + 34.0
	var chip := Rect2(rect.end.x - jw - 10.0, rect.position.y + 8.0, jw, 28.0)
	var busy: bool = job != ""
	draw_rect(chip, UiTheme.STEEL_DEEP, true)
	draw_rect(chip, UiTheme.AMBER if busy else UiTheme.BRASS_DARK, false, 1.0)
	var icon_kind: String = str(JOB_ICON.get(job, ""))
	if not icon_kind.is_empty():
		UiTheme.icon(self, icon_kind, chip.position + Vector2(14, 14), 16.0)
	elif job == "go":
		draw_colored_polygon(PackedVector2Array([chip.position + Vector2(7, 7), chip.position + Vector2(20, 14), chip.position + Vector2(7, 21)]), UiTheme.AMBER)
	UiTheme.text(self, Vector2(chip.position.x + 28.0, chip.position.y + 21.0), label, 17, UiTheme.AMBER if busy else UiTheme.TEXT_DIM)
	var place: String = sim.ship.rooms[c.room].name.to_upper() if c.room >= 0 and c.room < sim.ship.rooms.size() else ""
	if c.away:
		place = outside_line(sim)
	elif c.order_room >= 0 and c.order_room < sim.ship.rooms.size():
		place += "  > STATION %s" % sim.ship.rooms[c.order_room].name.to_upper()
	elif c.job_room >= 0 and c.job_room != c.room and c.job_room < sim.ship.rooms.size():
		place += "  > %s" % sim.ship.rooms[c.job_room].name.to_upper()
	UiTheme.text(self, Vector2(left, rect.position.y + 84.0), place, 17, UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0)
	# Skills.
	UiTheme.text(self, Vector2(left, rect.position.y + 106.0), "FIRE %.1f" % c.skill_fire, 16, UiTheme.TEXT)
	_draw_skill_bar(Vector2(left + 84.0, rect.position.y + 96.0), c.skill_fire)
	UiTheme.text(self, Vector2(left + 164.0, rect.position.y + 106.0), "REPAIR %.1f" % c.skill_repair, 16, UiTheme.TEXT)
	_draw_skill_bar(Vector2(left + 270.0, rect.position.y + 96.0), c.skill_repair)


## The place line of the away miner: "DIGGING +12 ORE +2 GEMS".
static func outside_line(s: Sim) -> String:
	var m: DrillMiner = s.drill.miner
	var haul: String = MinerCard.haul_text(m.haul)
	return MinerCard.phase_word(m.phase) + ("  " + haul if not haul.is_empty() else "")


func job_text_for(c: CrewMember) -> String:
	if c.away:
		return "OUTSIDE"
	if c.job_kind == "go" and c.job_room >= 0 and c.job_room < sim.ship.rooms.size() and c.job_room != c.room:
		return "GO TO"
	return job_text(c.job_kind)


func _draw_skill_bar(at: Vector2, skill: float) -> void:
	var r := Rect2(at, Vector2(64, 10))
	draw_rect(r, UiTheme.STEEL_DEEP, true)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(skill / 2.0, 0.0, 1.0), r.size.y)), UiTheme.BRASS, true)
	draw_rect(r, UiTheme.BRASS_DARK, false, 1.0)
