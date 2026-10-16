class_name Dossier
extends Control
## The event overlay: a typed page of paper on a dimmed screen. File header line, title, the page
## text with {crew} filled (Encounter.fill_text), words the codex has not unlocked blacked out as
## redaction bars ([[id:words]]), TOPSIDE's radio line in a separate strip, and the options as
## buttons (greyed with the reason from Encounter.option_block). A click pushes
## {"type": "choose", "option": i}; a page without options shows Continue (option 0). The digits
## 1 to 9 pick an option and Enter continues. The whole overlay shows only while an event is open
## (Encounter.event_id and the "dialog" phase) and swallows clicks while it does.
##
## Mount (main.gd, as the last child of the HUD CanvasLayer so it draws on top):
##   var dossier: Dossier = Dossier.build(layer, sim)    # one call to build
##   dossier.bind(new_sim)                               # one call to bind a Sim
## Nothing else is needed: it shows and hides itself.

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const PAGE_W: float = 880.0
const TEXT_W: float = 740.0
const FADE_S: float = 0.2
const REDACTION_INK: String = "#0a0908"
const KNOWN_INK: String = "#7a1e1e"

var sim: Sim = null
var _sig: String = ""
var _page_key: String = ""  ## Event, page and picked crew: the page's identity, apart from its option states.
var _sheet: DossierSheet = null
var _center: CenterContainer = null
var _age: float = 0.0
var _buttons: Array[Button] = []  ## Option buttons of the open page (or the one Continue).


static func build(parent: Control, p_sim: Sim) -> Dossier:
	var d := Dossier.new()
	d.position = Vector2.ZERO
	d.size = DESIGN_SIZE
	parent.add_child(d)
	d.bind(p_sim)
	return d


func _init() -> void:
	theme = UiTheme.make_theme()
	# The dim backdrop lets clicks through to the power panel (options can need power); the sheet
	# itself still takes them. World clicks stay blocked by main.gd while an overlay is open.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_sig = ""
	_refresh()


## True while an event page should be on screen.
func is_open() -> bool:
	return sim != null and not sim.encounter.event_id.is_empty() and sim.run.phase == "dialog"


func _process(delta: float) -> void:
	_refresh()
	if visible:
		_age += delta
		if _sheet != null:
			_sheet.modulate.a = clampf(_age / FADE_S, 0.0, 1.0)


func _refresh() -> void:
	var open: bool = is_open()
	visible = open
	if not open:
		_sig = ""
		_page_key = ""
		return
	var sig: String = signature()
	if sig != _sig:
		_sig = sig
		var key: String = "%s|%s|%s" % [sim.encounter.event_id, sim.encounter.page, str(sim.encounter.picked)]
		var fresh: bool = key != _page_key
		_page_key = key
		var keep_age: float = _age
		_rebuild()  # Option states change live (power comes in): rebuild, but do not fade the page in again.
		if not fresh:
			_age = keep_age
			if _sheet != null:
				_sheet.modulate.a = 1.0


## Everything the page's look depends on; a change rebuilds it.
func signature() -> String:
	var enc: Encounter = sim.encounter
	var parts: PackedStringArray = PackedStringArray([enc.event_id, enc.page, str(enc.picked), ",".join(sim.run.learned)])
	var options: Array = enc.current_page().get("options", [])
	for i: int in range(options.size()):
		parts.append(enc.option_block(sim, i))
	return "|".join(parts)


## Page text to RichTextLabel markup: redactions become black bars, or lifted words in red ink.
static func to_bbcode(text: String, run: RunState) -> String:
	var re := RegEx.new()
	re.compile("\\[\\[([^:\\]]+):([^\\]]*)\\]\\]")
	var out: String = ""
	var at: int = 0
	for m: RegExMatch in re.search_all(text):
		out += _esc(text.substr(at, m.get_start() - at))
		var words: String = _esc(m.get_string(2))
		if run.knows(m.get_string(1)):
			out += "[color=%s][u]%s[/u][/color]" % [KNOWN_INK, words]
		else:
			out += "[bgcolor=%s][color=%s]%s[/color][/bgcolor]" % [REDACTION_INK, REDACTION_INK, words]
		at = m.get_end()
	return out + _esc(text.substr(at))


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


## Plain text for a button: redactions without markup (unknown words become a REDACTED tag).
static func plain_text(text: String, run: RunState) -> String:
	var re := RegEx.new()
	re.compile("\\[\\[([^:\\]]+):([^\\]]*)\\]\\]")
	var out: String = ""
	var at: int = 0
	for m: RegExMatch in re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		out += m.get_string(2) if run.knows(m.get_string(1)) else "[REDACTED]"
		at = m.get_end()
	return out + text.substr(at)


## The sim's refusal ("needs helm at 2 bars") as a line for the page.
func reason_text(raw: String) -> String:
	var s: String = raw
	var q: int = s.find("codex \"")
	if q >= 0:
		var id: String = s.substr(q + 7).trim_suffix("\"")
		var entry: Dictionary = sim.db.table("codex").get(id, {})
		s = "knowledge of %s" % str(entry.get("title", id))
	elif s.begins_with("needs "):
		s = s.substr(6)
	return "REQUIRES: %s" % s.to_upper()


func choose(option: int) -> void:
	if sim == null or not is_open():
		return
	sim.push({"type": "choose", "option": option})


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not visible:
		return
	var n: int = -1
	if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
		n = k.physical_keycode - KEY_1
	elif k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER:
		var opts: Array = sim.encounter.current_page().get("options", [])
		n = 0 if opts.is_empty() else -1
	if n >= 0 and n < _buttons.size() and not _buttons[n].disabled:
		choose(n)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.015, 0.78), true)
	for i: int in range(8):
		draw_rect(Rect2(Vector2.ZERO, size).grow(-float(i) * 40.0), Color(0, 0, 0, 0.05), false, 40.0)


func _rebuild() -> void:
	_age = 0.0
	_buttons.clear()
	if _sheet != null:
		_center.remove_child(_sheet)
		_sheet.free()
	var enc: Encounter = sim.encounter
	var ev: Dictionary = enc.current_event()
	var pg: Dictionary = enc.current_page()
	_sheet = DossierSheet.new()
	_sheet.stamp_text = "CLASSIFIED" if enc.page == str(ev.get("start", "")) else "LOGGED"
	_sheet.custom_minimum_size = Vector2(PAGE_W, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 62)
	margin.add_theme_constant_override("margin_right", 62)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	# File header and title.
	box.add_child(_label(str(ev.get("file", "")), 17, UiTheme.INK_RED))
	box.add_child(_rule())
	var title: Label = _label(str(ev.get("title", "")), 40, UiTheme.INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(TEXT_W - 150.0, 0)
	box.add_child(title)
	# Body.
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(TEXT_W, 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_override("normal_font", UiTheme.typewriter())
	body.add_theme_font_size_override("normal_font_size", 24)
	body.add_theme_constant_override("line_separation", 6)
	body.add_theme_color_override("default_color", UiTheme.INK)
	body.text = to_bbcode(enc.fill_text(sim, str(pg.get("text", ""))), sim.run)
	box.add_child(body)
	# TOPSIDE.
	var radio: String = str(pg.get("radio", ""))
	if not radio.is_empty():
		box.add_child(_radio_strip(enc.fill_text(sim, radio)))
	# Options.
	var options: Array = pg.get("options", [])
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	box.add_child(gap)
	if options.is_empty():
		var cont: Button = _option_button("Continue", false)
		cont.alignment = HORIZONTAL_ALIGNMENT_CENTER
		cont.size_flags_horizontal = Control.SIZE_SHRINK_END
		cont.custom_minimum_size = Vector2(220, 0)
		cont.pressed.connect(choose.bind(0))
		_buttons.append(cont)
		box.add_child(cont)
	else:
		for i: int in range(options.size()):
			var opt: Dictionary = options[i]
			var block: String = enc.option_block(sim, i)
			var text: String = plain_text(enc.fill_text(sim, str(opt.get("text", ""))), sim.run)
			var b: Button = _option_button("%d.  %s" % [i + 1, text], not block.is_empty())
			b.pressed.connect(choose.bind(i))
			_buttons.append(b)
			box.add_child(b)
			if not block.is_empty():
				var why: Label = _label(reason_text(block), 15, UiTheme.INK_RED)
				why.add_theme_constant_override("outline_size", 0)
				box.add_child(why)
	_center.add_child(_sheet)


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


func _option_button(text: String, blocked: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"PaperButton"
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(TEXT_W, 0)
	b.disabled = blocked
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _radio_strip(text: String) -> Control:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.STEEL_DARK, UiTheme.BRASS_DARK, 2, 2, 12))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	var tag := Label.new()
	tag.text = "TOPSIDE"
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", UiTheme.AMBER)
	tag.custom_minimum_size = Vector2(86, 0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tag)
	var msg := Label.new()
	msg.text = text
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(TEXT_W - 130.0, 0)
	msg.add_theme_font_size_override("font_size", 19)
	msg.add_theme_color_override("font_color", UiTheme.CRT)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(msg)
	return strip


## The sheet of paper: shadow, worn edge, a coffee ring, a paper clip and a rubber stamp. It sizes
## itself to the text inside it (a PanelContainer) and draws behind it.
class DossierSheet extends PanelContainer:
	var stamp_text: String = "CLASSIFIED"
	var show_clip: bool = true
	var stamp_at: Vector2 = Vector2(-1.0, -1.0)  ## Stamp centre; x negative = top right, y negative = near the bottom.

	func _init() -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.45), true)
		draw_rect(r, UiTheme.PAPER, true)
		# Darker, mottled edge bands.
		for i: int in range(6):
			var a: float = 0.05 * (1.0 - float(i) / 6.0)
			draw_rect(r.grow(-float(i) * 3.0), Color(0.35, 0.25, 0.1, a), false, 3.0)
		# Faint ruled lines low on the page and a fold.
		draw_line(Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5), Color(0.4, 0.3, 0.15, 0.10), 2.0)
		draw_line(Vector2(0, r.size.y * 0.5 + 2), Vector2(r.size.x, r.size.y * 0.5 + 2), Color(1, 1, 1, 0.12), 1.0)
		# Coffee ring.
		var ring := Vector2(r.size.x - 110.0, r.size.y - 120.0)
		draw_arc(ring, 44.0, 0.3, TAU - 0.5, 40, Color(0.30, 0.17, 0.06, 0.20), 4.0)
		draw_arc(ring, 41.0, 1.0, TAU - 1.2, 32, Color(0.30, 0.17, 0.06, 0.10), 2.0)
		# Paper clip.
		if show_clip:
			draw_polyline(PackedVector2Array([Vector2(26, 54), Vector2(26, -14), Vector2(38, -24), Vector2(50, -14), Vector2(50, 36), Vector2(36, 36), Vector2(36, -4)]), Color(0.62, 0.64, 0.68), 3.0)
		# Rubber stamp.
		var f: Font = UiTheme.typewriter()
		var tw: float = f.get_string_size(stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var centre: Vector2 = Vector2(r.size.x - 190.0, 70.0)
		if stamp_at.x >= 0.0:
			centre = Vector2(stamp_at.x, stamp_at.y if stamp_at.y >= 0.0 else r.size.y - 30.0)
		draw_set_transform(centre, deg_to_rad(-11.0), Vector2.ONE)
		var sr := Rect2(Vector2(-tw * 0.5 - 14.0, -26.0), Vector2(tw + 28.0, 46.0))
		var ink: Color = Color(0.70, 0.12, 0.10, 0.72)
		draw_rect(sr, ink, false, 3.0)
		draw_rect(sr.grow(-6.0), ink, false, 1.0)
		draw_string(f, Vector2(-tw * 0.5, 8.0), stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
