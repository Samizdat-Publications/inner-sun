class_name DeathScreen
extends Control
## The end-of-run screen: a typed mission report on paper with a rubber stamp. Shows while the run's
## phase is "dead" or "won". The cause is written out in plain words and typed onto the page, then
## the page lists how deep the ship got, the time, the crew lost, what was gained, and the codex
## entries learned this run with each entry's teaser (all of them new: they were not in the profile
## at the start). Two buttons: New run (emits new_run_requested) and Codex (opens a CodexView).
##
## Stamp: KIA (everyone died), RECOVERED (the ship was lost but some crew got out), MISSION COMPLETE
## (the gate was breached).
##
## Mount (main.gd, on the HUD CanvasLayer as the topmost child):
##   var death: DeathScreen = DeathScreen.build(layer, sim, profile)
##   death.new_run_requested.connect(main._start_new_run)
##   death.bind(new_sim, profile)      # again for a new run; it hides itself while the run lives
## Main should fold the finished run into the profile (Profile.merge_run(run.summary(sim),
## run.learned), then save) when the phase turns dead or won; this screen only reads. Enter or the
## New run button starts a new run. It owns a CodexView (`codex`) for its Codex button.

signal new_run_requested

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const PAGE_W: float = 1240.0
const COL_W: float = 556.0
const TYPE_CPS: float = 170.0
const FADE_S: float = 0.3
const CAUSE_TEXT: Dictionary = {
	"hull": "Hull breached. The rock took the tower apart one plate at a time.",
	"crew_fire": "Crew lost to fire. The last of them went down in a corridor full of smoke.",
	"crew_drowned": "Crew lost to flooding. The water found every room, and then it found them.",
	"crew_heat": "Crew lost to heat. The gauges topped out before anyone did.",
	"crew_event": "Crew lost to whatever was found down there. The report on this one is short.",
	"flooded": "Drill room flooded. The bit drowned, the shaft filled, and the drill went quiet.",
	"gate": "Gate guardian down. The way below is open. TOPSIDE requests a full written account.",
}
const RES_LABEL: Dictionary = {
	"ore": "ORE", "gems": "GEMS", "coolant": "COOLANT", "cells": "CELLS", "bits": "BITS", "charges": "CHARGES",
}

var sim: Sim = null
var profile: Profile = null
var codex: CodexView = null

var _sig: String = ""
var _sheet: Dossier.DossierSheet = null
var _center: CenterContainer = null
var _cause_label: RichTextLabel = null
var _typed: float = 0.0
var _age: float = 0.0
var _new_button: Button = null
var _codex_button: Button = null


static func build(parent: Control, p_sim: Sim, p_profile: Profile = null) -> DeathScreen:
	var d := DeathScreen.new()
	d.position = Vector2.ZERO
	d.size = DESIGN_SIZE
	parent.add_child(d)
	d.bind(p_sim, p_profile)
	return d


func _init() -> void:
	theme = UiTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	codex = CodexView.new()
	codex.position = Vector2.ZERO
	codex.size = DESIGN_SIZE
	add_child(codex)


func bind(p_sim: Sim, p_profile: Profile = null) -> void:
	sim = p_sim
	profile = p_profile
	_sig = ""
	codex.bind(p_sim, p_profile)
	codex.close()
	_refresh()


func is_open() -> bool:
	return sim != null and sim.run.is_over()


func _process(delta: float) -> void:
	_refresh()
	if not visible:
		return
	_age += delta
	if _sheet != null:
		_sheet.modulate.a = clampf(_age / FADE_S, 0.0, 1.0)
	if _cause_label != null and _typed < float(_cause_label.get_total_character_count()):
		_typed += delta * TYPE_CPS
		_cause_label.visible_characters = int(_typed)


func _refresh() -> void:
	var open: bool = is_open()
	visible = open
	if not open:
		_sig = ""
		return
	var sig: String = "%s|%s|%s" % [sim.run.phase, sim.run.end_cause, ",".join(sim.run.learned)]
	if sig != _sig:
		_sig = sig
		_rebuild()


## Show the whole report at once (the typing is skipped).
func skip_typing() -> void:
	if _cause_label != null:
		_typed = float(_cause_label.get_total_character_count())
		_cause_label.visible_characters = -1


## The stamp for this ending.
func stamp_for(s: Sim) -> String:
	if s.run.phase == "won":
		return "MISSION COMPLETE"
	var alive: int = 0
	for c: CrewMember in s.ship.crew:
		if c.alive:
			alive += 1
	return "RECOVERED" if alive > 0 else "KIA"


## The cause in plain words.
func cause_text(s: Sim) -> String:
	var cause: String = s.run.end_cause
	var base: String = str(CAUSE_TEXT.get(cause, "Contact lost. Cause not recorded."))
	if cause == "hull":
		base = hull_text(s)
	if s.run.phase != "won" and not cause.begins_with("crew_"):
		var alive: int = 0
		for c: CrewMember in s.ship.crew:
			if c.alive:
				alive += 1
		if alive > 0:
			base += " %d of the crew got out." % alive
	return base


## A hull death names what was hitting the ship: the gate machine or a rival rig in a fight, the
## front when it had caught the ship, the rock otherwise.
static func hull_text(s: Sim) -> String:
	if s.combat.active and s.enemy != null:
		if s.combat.boss:
			return "Hull breached. The gate machine took the tower apart one plate at a time."
		return "Hull breached. The rival rig took the tower apart one plate at a time."
	if s.run.caught or s.run.strikes > 0:
		return "Hull breached. The front caught the tower and struck it until the plates gave."
	return str(CAUSE_TEXT["hull"])


func _on_new() -> void:
	new_run_requested.emit()


func _on_codex() -> void:
	codex.open()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not visible or codex.visible:
		return
	if k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER:
		_on_new()
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_C:
		_on_codex()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.015, 0.84), true)
	for i: int in range(8):
		draw_rect(Rect2(Vector2.ZERO, size).grow(-float(i) * 40.0), Color(0, 0, 0, 0.05), false, 40.0)


func _rebuild() -> void:
	_age = 0.0
	_typed = 0.0
	if _sheet != null:
		_center.remove_child(_sheet)
		_sheet.free()
	var run: RunState = sim.run
	var sum: Dictionary = run.summary(sim)
	_sheet = Dossier.DossierSheet.new()
	_sheet.stamp_text = stamp_for(sim)
	_sheet.stamp_at = Vector2(PAGE_W - 250.0, 86.0)
	_sheet.custom_minimum_size = Vector2(PAGE_W, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 62)
	margin.add_theme_constant_override("margin_right", 62)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 36)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	box.add_child(_label("FINAL REPORT %02d // AUGER" % (sim.run_seed % 100), 17, UiTheme.INK_RED))
	box.add_child(_rule())
	var title: Label = _label("END OF MISSION REPORT", 40, UiTheme.INK)
	box.add_child(title)
	box.add_child(_label("VESSEL: %s     LAYER: %s     SEED %d" % [
		str(sim.ship.source_def.get("name", sim.ship_id)).to_upper(),
		str(run.layer.get("name", run.layer_id)).to_upper(), sim.run_seed], 18, UiTheme.INK))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cols)
	# Left column: the cause, then the numbers.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size = Vector2(COL_W, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(left)
	left.add_child(_label("CAUSE", 16, UiTheme.INK_RED))
	_cause_label = RichTextLabel.new()
	_cause_label.bbcode_enabled = false
	_cause_label.fit_content = true
	_cause_label.scroll_active = false
	_cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cause_label.custom_minimum_size = Vector2(COL_W, 0)
	_cause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cause_label.add_theme_font_override("normal_font", UiTheme.typewriter())
	_cause_label.add_theme_font_size_override("normal_font_size", 26)
	_cause_label.add_theme_color_override("default_color", UiTheme.INK)
	_cause_label.text = cause_text(sim)
	_cause_label.visible_characters = 0
	left.add_child(_cause_label)
	left.add_child(_rule())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(grid)
	var deepest: int = maxi(0, int(sum.get("rows_total", 1)) - 1)
	var crew_total: int = sim.ship.crew.size()
	var rows: Array = [
		["DEEPEST ROW", "%d of %d" % [int(sum.get("rows_reached", 0)), deepest]],
		["DEPTH", "%d m" % roundi(float(sum.get("depth_m", 0.0)))],
		["TIME", _clock(float(sum.get("time_s", 0.0)))],
		["CREW LOST", "%d of %d" % [int(sum.get("crew_lost", 0)), crew_total]],
		["FIGHTS WON", str(int(sum.get("fights_won", 0)))],
	]
	for r: Array in rows:
		grid.add_child(_label(str(r[0]), 21, UiTheme.INK_RED))
		grid.add_child(_label(str(r[1]), 23, UiTheme.INK))
	left.add_child(_label("RECOVERED SUPPLIES", 16, UiTheme.INK_RED))
	var gained: Dictionary = sum.get("gained", {})
	var parts: PackedStringArray = PackedStringArray()
	for res: String in ["ore", "gems", "coolant", "cells", "bits", "charges"]:
		var amt: int = int(gained.get(res, 0))
		if amt > 0:
			parts.append("%s +%d" % [str(RES_LABEL[res]), amt])
	var supplies: Label = _label("   ".join(parts) if not parts.is_empty() else "None.", 21, UiTheme.INK)
	supplies.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	supplies.custom_minimum_size = Vector2(COL_W, 0)
	left.add_child(supplies)
	# Right column: the codex.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(COL_W, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(right)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 52)
	right.add_child(spacer)
	right.add_child(_label("CODEX: %d NEW %s" % [run.learned.size(), "ENTRY" if run.learned.size() == 1 else "ENTRIES"], 16, UiTheme.INK_RED))
	right.add_child(_rule())
	var table: Dictionary = sim.db.table("codex")
	if run.learned.is_empty():
		var none: Label = _label("No new entries filed. The deeper rock keeps its secrets.", 21, UiTheme.INK)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(COL_W, 0)
		right.add_child(none)
	for id: String in run.learned:
		var e: Dictionary = table.get(id, {})
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(_label("NEW", 16, UiTheme.INK_RED))
		head.add_child(_label(str(e.get("title", id)), 25, UiTheme.INK))
		right.add_child(head)
		var tease: Label = _label(str(e.get("teaser", "")), 19, UiTheme.INK)
		tease.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tease.custom_minimum_size = Vector2(COL_W - 30.0, 0)
		tease.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(tease)
	var on_file: int = _known_total()
	var total: int = table.size()
	right.add_child(_label("ON FILE: %d of %d" % [on_file, total], 18, UiTheme.INK_RED))
	# Buttons.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	box.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 20)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(buttons)
	_codex_button = _button("Codex  [C]")
	_codex_button.pressed.connect(_on_codex)
	buttons.add_child(_codex_button)
	_new_button = _button("New run  [Enter]")
	_new_button.pressed.connect(_on_new)
	buttons.add_child(_new_button)
	_center.add_child(_sheet)


func _known_total() -> int:
	var ids: PackedStringArray = codex.known_ids()
	return ids.size()


func _clock(seconds: float) -> String:
	var total: int = roundi(seconds)
	return "T+%02d:%02d" % [total / 60, total % 60]


func _label(s: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", UiTheme.typewriter())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(UiTheme.INK, 0.55)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _button(text: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"PaperButton"
	b.text = text
	b.custom_minimum_size = Vector2(260, 0)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
