class_name CodexView
extends Control
## The codex browser: a steel binder on a dimmed screen. The left column lists every codex entry
## grouped by category; entries you know show their title, the rest are blacked out. The right side
## is a sheet of paper: a known entry is readable (title and text), an unknown one is a redacted file
## card (bars where the title and text would be). Click a row or use the Up and Down keys to read;
## Escape or the Close button leaves.
##
## What is known = the Profile's known_codex, plus the run's start knowledge and run.learned.
##
## Mount (main.gd, on the HUD CanvasLayer, above everything except the death screen's own copy):
##   var codex: CodexView = CodexView.build(layer, sim, profile)   # hidden until open()
##   codex.bind(new_sim, profile)                                  # again for a new run or profile
##   codex.open()                                                  # and codex.close(), or Escape
## DeathScreen builds its own CodexView for its Codex button; main only needs one for a menu or key.
## It swallows the mouse while it is visible and emits `closed` when it hides.

signal closed

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const FRAME: Rect2 = Rect2(190, 60, 1540, 960)
const LIST_RECT: Rect2 = Rect2(220, 118, 478, 842)
const SHEET_POS: Vector2 = Vector2(730, 112)
const SHEET_SIZE: Vector2 = Vector2(970, 860)
const CATEGORY_ORDER: Array[String] = ["history", "place", "tech", "creature", "topside"]
const CATEGORY_LABEL: Dictionary = {
	"history": "HISTORY", "place": "PLACES", "tech": "TECHNOLOGY", "creature": "CREATURES", "topside": "TOPSIDE",
}

var db: DataDB = null
var run: RunState = null
var profile: Profile = null

var _entries: Array[Dictionary] = []  ## id, title, category, text, teaser, number (sorted for display).
var _known: PackedStringArray = PackedStringArray()
var _selected: String = ""
var _list_box: VBoxContainer = null
var _scroll: ScrollContainer = null
var _rows: Array[CodexRow] = []
var _sheet: Dossier.DossierSheet = null
var _close_button: Button = null
var _count_label: Label = null


static func build(parent: Control, p_sim: Sim, p_profile: Profile = null) -> CodexView:
	var c := CodexView.new()
	c.position = Vector2.ZERO
	c.size = DESIGN_SIZE
	parent.add_child(c)
	c.bind(p_sim, p_profile)
	return c


func _init() -> void:
	theme = UiTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scroll = ScrollContainer.new()
	_scroll.position = LIST_RECT.position
	_scroll.size = LIST_RECT.size - Vector2(0, 54)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 4)
	_list_box.custom_minimum_size = Vector2(LIST_RECT.size.x - 14.0, 0)
	_scroll.add_child(_list_box)
	_close_button = Button.new()
	_close_button.text = "CLOSE  [ESC]"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.position = Vector2(LIST_RECT.position.x, LIST_RECT.end.y - 40.0)
	_close_button.size = Vector2(LIST_RECT.size.x - 14.0, 40.0)
	_close_button.add_theme_font_size_override("font_size", 17)
	_close_button.pressed.connect(close)
	add_child(_close_button)


## Bind a Sim (its data, its run's learned entries) and optionally the Profile.
func bind(p_sim: Sim, p_profile: Profile = null) -> void:
	db = p_sim.db if p_sim != null else null
	run = p_sim.run if p_sim != null else null
	profile = p_profile
	_selected = ""
	_reload()


## Bind without a Sim (a menu): just the data and the profile.
func bind_db(p_db: DataDB, p_profile: Profile) -> void:
	db = p_db
	run = null
	profile = p_profile
	_selected = ""
	_reload()


func open() -> void:
	_reload()
	visible = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


## Every codex id the player knows right now.
func known_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if profile != null:
		out.append_array(profile.known_codex)
	if run != null:
		for id: String in run.known_codex:
			if not out.has(id):
				out.append(id)
		for id: String in run.learned:
			if not out.has(id):
				out.append(id)
	return out


func is_known(id: String) -> bool:
	return _known.has(id)


## Entry ids in display order (category order, then title).
func entry_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in _entries:
		out.append(str(e["id"]))
	return out


func selected_id() -> String:
	return _selected


func select(id: String) -> void:
	if id.is_empty() or (id == _selected and _sheet != null):
		return
	_selected = id
	for r: CodexRow in _rows:
		r.selected = r.entry_id == id
		r.queue_redraw()
	_rebuild_sheet()


func _reload() -> void:
	_known = known_ids()
	_entries.clear()
	if db != null:
		var table: Dictionary = db.table("codex")
		var by_cat: Dictionary = {}
		for id: Variant in table.keys():
			var d: Dictionary = table[id]
			var cat: String = str(d.get("category", "history"))
			if not by_cat.has(cat):
				by_cat[cat] = []
			(by_cat[cat] as Array).append({"id": str(id), "title": str(d.get("title", id)), "category": cat,
				"text": str(d.get("text", "")), "teaser": str(d.get("teaser", ""))})
		var cats: Array[String] = []
		for c: String in CATEGORY_ORDER:
			if by_cat.has(c):
				cats.append(c)
		var extra: Array[String] = []
		for c: Variant in by_cat.keys():
			if not CATEGORY_ORDER.has(str(c)):
				extra.append(str(c))
		extra.sort()
		cats.append_array(extra)
		var number: int = 1
		for cat: String in cats:
			var list: Array = by_cat[cat]
			list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["title"]) < str(b["title"]))
			for e: Variant in list:
				var entry: Dictionary = e
				entry["number"] = number
				number += 1
				_entries.append(entry)
	_rebuild_list()
	var first: String = ""
	for e: Dictionary in _entries:
		if _known.has(str(e["id"])):
			first = str(e["id"])
			break
	if first.is_empty() and not _entries.is_empty():
		first = str(_entries[0]["id"])
	if not _entries.any(func(e: Dictionary) -> bool: return str(e["id"]) == _selected):
		_selected = ""
	var keep: String = _selected if not _selected.is_empty() else first
	_selected = ""
	select(keep)


func _rebuild_list() -> void:
	for ch: Node in _list_box.get_children():
		_list_box.remove_child(ch)
		ch.free()
	_rows.clear()
	var known_n: int = 0
	for e: Dictionary in _entries:
		if _known.has(str(e["id"])):
			known_n += 1
	_count_label = Label.new()
	_count_label.text = "%d OF %d FILES RECOVERED" % [known_n, _entries.size()]
	_count_label.add_theme_font_size_override("font_size", 16)
	_count_label.add_theme_color_override("font_color", UiTheme.CRT)
	_list_box.add_child(_count_label)
	var last_cat: String = ""
	for e: Dictionary in _entries:
		var cat: String = str(e["category"])
		if cat != last_cat:
			last_cat = cat
			var head := Label.new()
			head.text = "%s" % str(CATEGORY_LABEL.get(cat, cat.to_upper()))
			head.add_theme_font_size_override("font_size", 15)
			head.add_theme_color_override("font_color", UiTheme.AMBER)
			head.custom_minimum_size = Vector2(0, 30)
			head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_list_box.add_child(head)
			var rule := ColorRect.new()
			rule.color = UiTheme.BRASS_DARK
			rule.custom_minimum_size = Vector2(0, 1)
			_list_box.add_child(rule)
		var id: String = str(e["id"])
		var row := CodexRow.new()
		row.entry_id = id
		row.entry_title = str(e["title"])
		row.number = int(e["number"])
		row.known = _known.has(id)
		row.is_new = run != null and run.learned.has(id)
		row.picked.connect(select)
		_rows.append(row)
		_list_box.add_child(row)


func _rebuild_sheet() -> void:
	if _sheet != null:
		remove_child(_sheet)
		_sheet.free()
		_sheet = null
	var e: Dictionary = {}
	for it: Dictionary in _entries:
		if str(it["id"]) == _selected:
			e = it
	if e.is_empty():
		return
	var known: bool = _known.has(_selected)
	_sheet = Dossier.DossierSheet.new()
	_sheet.stamp_text = "ON FILE" if known else "REDACTED"
	_sheet.position = SHEET_POS
	_sheet.custom_minimum_size = SHEET_SIZE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	box.add_child(_label("FILE %02d   /   %s" % [int(e["number"]), str(CATEGORY_LABEL.get(str(e["category"]), "")).to_upper()], 17, UiTheme.INK_RED))
	box.add_child(_rule())
	if known:
		var title := _label(str(e["title"]), 42, UiTheme.INK)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(620, 0)
		box.add_child(title)
		var body := _label(str(e["text"]), 25, UiTheme.INK)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(800, 0)
		body.add_theme_constant_override("line_spacing", 7)
		box.add_child(body)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		box.add_child(gap)
		box.add_child(_rule())
		var ref := _label("SUMMARY: " + str(e["teaser"]), 18, UiTheme.INK_RED)
		ref.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ref.custom_minimum_size = Vector2(800, 0)
		box.add_child(ref)
	else:
		box.add_child(_bar(Vector2(430, 46)))
		var widths: Array[float] = [800.0, 760.0, 790.0, 520.0, 0.0, 770.0, 700.0, 380.0]
		var h: int = _selected.hash() & 0xff
		for i: int in range(widths.size()):
			if widths[i] <= 0.0:
				var sp := Control.new()
				sp.custom_minimum_size = Vector2(0, 8)
				box.add_child(sp)
			else:
				box.add_child(_bar(Vector2(widths[i] - float((h + i * 37) % 90), 24)))
		var gap2 := Control.new()
		gap2.custom_minimum_size = Vector2(0, 14)
		box.add_child(gap2)
		var why := _label("FILE NOT YET RECOVERED. SOMETHING DOWN THERE HOLDS IT.", 20, UiTheme.INK_RED)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size = Vector2(800, 0)
		box.add_child(why)
	add_child(_sheet)
	_sheet.size = SHEET_SIZE


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


func _bar(s: Vector2) -> Control:
	var r := ColorRect.new()
	r.color = Color(0.04, 0.035, 0.03)
	r.custom_minimum_size = s
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or not visible:
		return
	if k.physical_keycode == KEY_ESCAPE and not k.echo:
		close()
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_DOWN or k.physical_keycode == KEY_UP:
		var ids: PackedStringArray = entry_ids()
		var at: int = ids.find(_selected)
		if at >= 0 and not ids.is_empty():
			select(ids[clampi(at + (1 if k.physical_keycode == KEY_DOWN else -1), 0, ids.size() - 1)])
			_scroll_to_selected()
		get_viewport().set_input_as_handled()


func _scroll_to_selected() -> void:
	for r: CodexRow in _rows:
		if r.entry_id == _selected:
			_scroll.ensure_control_visible(r)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.015, 0.84), true)
	UiTheme.draw_panel(self, FRAME, "CODEX  /  RECOVERED FILES")


## One line of the list: a number, the title (or a black bar), a NEW tag.
class CodexRow extends Control:
	signal picked(id: String)
	var entry_id: String = ""
	var entry_title: String = ""
	var number: int = 0
	var known: bool = false
	var is_new: bool = false
	var selected: bool = false
	var _hot: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 40)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_set_hot.bind(true))
		mouse_exited.connect(_set_hot.bind(false))

	func _set_hot(h: bool) -> void:
		_hot = h
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(entry_id)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UiTheme.STEEL_LIGHT if (selected or _hot) else UiTheme.STEEL, true)
		draw_rect(r, UiTheme.BRASS if selected else UiTheme.BRASS_DARK, false, 1.5 if selected else 1.0)
		if selected:
			draw_rect(Rect2(0, 0, 5, size.y), UiTheme.AMBER, true)
		UiTheme.text(self, Vector2(16, 26), "%02d" % number, 16, Color(UiTheme.CRT, 0.6))
		if known:
			UiTheme.text(self, Vector2(58, 26), entry_title, 19, UiTheme.AMBER if selected else UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_LEFT, size.x - 130.0)
			if is_new:
				UiTheme.text(self, Vector2(size.x - 62, 25), "NEW", 15, UiTheme.CRT)
		else:
			var w: float = 150.0 + float(entry_id.hash() % 130)
			draw_rect(Rect2(58, 10, w, 20), Color(0.02, 0.018, 0.016), true)
			draw_rect(Rect2(58, 10, w, 20), Color(UiTheme.BRASS_DARK, 0.6), false, 1.0)
