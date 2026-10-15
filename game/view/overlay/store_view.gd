class_name StoreView
extends Control
## The store overlay: a requisition form on a dimmed screen. Each stock line shows what it is, what it
## does for this ship right now, its price in gems or ore, how many may still be bought, and a BUY
## button ({"type": "buy", "item": i, "qty": 1}); a line that cannot be bought is greyed with the
## reason from EncounterStore.refusal. The hire candidate (if the store has one) is named on its
## line. Leave pushes {"type": "leave"} (Escape does too). Current gems and ore sit in the corner.
## Shows only while a store is open (Encounter.store_id and the "store" phase).
##
## Mount (main.gd, as a child of the HUD CanvasLayer, above the panels):
##   var store: StoreView = StoreView.build(layer, sim)   # one call to build
##   store.bind(new_sim)                                  # one call to bind a Sim
## Nothing else is needed: it shows and hides itself.

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const PAGE_W: float = 1240.0
const TAG: Dictionary = {"res": "SUPPLY", "hull": "HULL", "weapon": "ARMS", "crew": "CREW", "upgrade": "REFIT"}
const FADE_S: float = 0.2

var sim: Sim = null
var _sig: String = ""
var _sheet: Dossier.DossierSheet = null
var _center: CenterContainer = null
var _age: float = 0.0
var _buy_buttons: Array[Button] = []


static func build(parent: Control, p_sim: Sim) -> StoreView:
	var s := StoreView.new()
	s.position = Vector2.ZERO
	s.size = DESIGN_SIZE
	parent.add_child(s)
	s.bind(p_sim)
	return s


func _init() -> void:
	theme = UiTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_sig = ""
	_refresh()


func is_open() -> bool:
	return sim != null and not sim.encounter.store_id.is_empty() and sim.run.phase == "store"


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
		return
	var sig: String = signature()
	if sig != _sig:
		_sig = sig
		_rebuild()


## Everything the form depends on (purchases, money, what the ship has); a change rebuilds it.
func signature() -> String:
	var enc: Encounter = sim.encounter
	var parts: PackedStringArray = PackedStringArray([enc.store_id, str(Array(enc.purchases)), enc.hire_member,
			str(sim.ship.weapons.size()), str(sim.run.state())])
	for r: Room in sim.ship.rooms:
		parts.append(str(r.sys_max))
	return "|".join(parts)


func buy(line: int, qty: int = 1) -> void:
	if sim != null and is_open():
		sim.push({"type": "buy", "item": line, "qty": qty})


func leave() -> void:
	if sim != null and is_open():
		sim.push({"type": "leave"})


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and visible and k.physical_keycode == KEY_ESCAPE:
		leave()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.015, 0.78), true)
	for i: int in range(8):
		draw_rect(Rect2(Vector2.ZERO, size).grow(-float(i) * 40.0), Color(0, 0, 0, 0.05), false, 40.0)


# The text under each line ---------------------------------------------------------------------

## What this line does for the ship as it stands ("HELM 2 > 3 BARS", "ON HAND 20", the candidate).
static func info_text(s: Sim, line: Dictionary) -> String:
	match str(line.get("item", "")):
		"res":
			return "ON HAND %d" % s.run.get_res(str(line.get("res", "")))
		"hull":
			return "HULL %d/%d" % [s.run.get_res("hull"), s.ship.hull_max]
		"weapon":
			var slots: int = int(s.ship.source_def.get("weapon_slots", 0))
			if slots > 0:
				return "MOUNTS %d/%d" % [s.ship.weapons.size(), slots]
			return "MOUNTED %d" % s.ship.weapons.size()
		"crew":
			return candidate_text(s)
		"upgrade":
			var ri: int = s.ship.room_with_system(str(line.get("system", "")))
			if ri < 0:
				return "NO SUCH SYSTEM"
			var r: Room = s.ship.rooms[ri]
			var sys_name: String = str(s.db.table("systems").get(r.system, {}).get("name", r.system)).to_upper()
			if r.sys_max >= int(line.get("max_bars", 0)):
				return "%s AT MAXIMUM" % sys_name
			return "%s %d > %d BARS" % [sys_name, r.sys_max, r.sys_max + 1]
	return ""


## The hire candidate: name and skills, or that nobody is left.
static func candidate_text(s: Sim) -> String:
	var enc: Encounter = s.encounter
	if enc.hire_member.is_empty():
		return "NOBODY LEFT"
	for pool: Variant in s.db.table("crew").values():
		var members: Array = (pool as Dictionary).get("members", [])
		for m: Variant in members:
			var md: Dictionary = m
			if str(md.get("id", "")) == enc.hire_member:
				var sk: Dictionary = md.get("skills", {})
				return "%s  FIRE %.1f  REPAIR %.1f" % [str(md.get("name", "")).to_upper(), float(sk.get("fire", 1.0)), float(sk.get("repair", 1.0))]
	return enc.hire_member.to_upper()


# Building -------------------------------------------------------------------------------------

func _rebuild() -> void:
	_age = 0.0
	_buy_buttons.clear()
	if _sheet != null:
		_center.remove_child(_sheet)
		_sheet.free()
	var enc: Encounter = sim.encounter
	var st: Dictionary = enc.current_store()
	_sheet = Dossier.DossierSheet.new()
	_sheet.stamp_text = "ALL SALES FINAL"
	_sheet.show_clip = false
	_sheet.stamp_at = Vector2(400.0, -1.0)
	_sheet.custom_minimum_size = Vector2(PAGE_W, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 58)
	margin.add_theme_constant_override("margin_right", 58)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 34)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	box.add_child(_header(st))
	box.add_child(_rule())
	var stock: Array = st.get("stock", [])
	for i: int in range(stock.size()):
		box.add_child(_stock_row(i, stock[i]))
		if i < stock.size() - 1:
			box.add_child(_dotted())
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.alignment = BoxContainer.ALIGNMENT_END
	var out: Button = _button("Leave", 20)
	out.custom_minimum_size = Vector2(200, 0)
	out.pressed.connect(leave)
	foot.add_child(out)
	box.add_child(foot)
	_center.add_child(_sheet)


func _header(st: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_label("REQUISITION // TRADER", 16, UiTheme.INK_RED))
	left.add_child(_label(str(st.get("name", "")), 42, UiTheme.INK))
	var blurb: Label = _label(str(st.get("blurb", "")), 18, Color(UiTheme.INK, 0.85))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(700, 0)
	left.add_child(blurb)
	row.add_child(left)
	# Money, as a steel plate pasted on the form.
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.STEEL_DARK, UiTheme.BRASS, 2, 2, 14))
	plate.size_flags_vertical = Control.SIZE_SHRINK_END
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cur: String in ["gems", "ore"]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(CurrencyIcon.new().with_kind(cur, 30.0))
		var v := Label.new()
		v.text = "%d" % sim.run.get_res(cur)
		v.add_theme_font_size_override("font_size", 32)
		v.add_theme_color_override("font_color", UiTheme.AMBER)
		cell.add_child(v)
		var n := Label.new()
		n.text = cur.to_upper()
		n.add_theme_font_size_override("font_size", 14)
		n.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		n.size_flags_vertical = Control.SIZE_SHRINK_END
		cell.add_child(n)
		cols.add_child(cell)
	plate.add_child(cols)
	row.add_child(plate)
	return row


func _stock_row(i: int, line: Dictionary) -> Control:
	var enc: Encounter = sim.encounter
	var why: String = EncounterStore.refusal(sim, enc, i, 1)
	var limit: int = int(line.get("limit", 0))
	var bought: int = enc.purchases[i] if i < enc.purchases.size() else 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, 38)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag: Label = _label(str(TAG.get(str(line.get("item", "")), "")), 15, UiTheme.INK_RED)
	tag.custom_minimum_size = Vector2(78, 0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	var text: Label = _label(str(line.get("text", "")), 19, UiTheme.INK if why.is_empty() else Color(UiTheme.INK, 0.62))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(240, 0)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_mono_label(info_text(sim, line), 15, UiTheme.STEEL_LIGHT))
	if not why.is_empty():
		info.add_child(_mono_label(why.to_upper(), 13, UiTheme.INK_RED))
	row.add_child(info)
	var price := HBoxContainer.new()
	price.custom_minimum_size = Vector2(96, 0)
	price.alignment = BoxContainer.ALIGNMENT_END
	price.add_theme_constant_override("separation", 6)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_child(_label("%d" % int(line.get("price", 0)), 24, UiTheme.INK))
	price.add_child(CurrencyIcon.new().with_kind(str(line.get("currency", "gems")), 24.0))
	row.add_child(price)
	var left_txt: String = ""
	if limit > 0:
		left_txt = "%d LEFT" % maxi(0, limit - bought)
	elif bought > 0:
		left_txt = "BOUGHT %d" % bought
	var lim: Label = _mono_label(left_txt, 14, UiTheme.STEEL_LIGHT)
	lim.custom_minimum_size = Vector2(82, 0)
	lim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lim)
	var b: Button = _button("BUY", 19)
	b.custom_minimum_size = Vector2(96, 36)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not why.is_empty()
	b.pressed.connect(buy.bind(i, 1))
	_buy_buttons.append(b)
	row.add_child(b)
	return row


func _label(s: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", UiTheme.typewriter())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _mono_label(s: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"PaperButton"
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(UiTheme.INK, 0.55)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _dotted() -> Control:
	var r := ColorRect.new()
	r.color = Color(UiTheme.INK, 0.18)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A currency icon as a Control (gems or ore), so it sits in a container row.
class CurrencyIcon extends Control:
	var kind: String = "gems"
	var px: float = 24.0

	func with_kind(k: String, p: float) -> CurrencyIcon:
		kind = k
		px = p
		custom_minimum_size = Vector2(p, p)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return self

	func _draw() -> void:
		UiTheme.icon(self, kind, Vector2(px, px) * 0.5, px * 0.85)
