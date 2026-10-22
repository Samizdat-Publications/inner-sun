class_name StoreView
extends Control
## The store overlay: a requisition form on a dimmed screen. The visit's lines are grouped under
## their sections (Supplies, then the rolled Systems, Gear, Weapons, Crew); each shows what it is,
## what it does for this ship right now (a system line names its next bar and that bar's price), its
## price in gems or ore, the units left on the shelf, and a BUY button ({"type": "buy", "item": i,
## "qty": 1}); a line that cannot be bought is greyed with the reason from EncounterStore.refusal.
## Below them a Sell list names what the ship owns that the trader would take, with the sale price
## and a SELL button ({"type": "sell", "what", "id"}), greyed with the reason when it cannot go.
## Leave pushes {"type": "leave"} (Escape does too). Current gems and ore sit in the corner.
## Shows only while a store is open (Encounter.store_id and the "store" phase). Widgets: StoreParts.
##
## Mount (main.gd, as a child of the HUD CanvasLayer, above the panels):
##   var store: StoreView = StoreView.build(layer, sim)   # one call to build
##   store.bind(new_sim)                                  # one call to bind a Sim
## Nothing else is needed: it shows and hides itself.

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const PAGE_W: float = 1240.0
const TAG: Dictionary = {"res": "SUPPLY", "hull": "HULL", "weapon": "ARMS", "crew": "CREW", "upgrade": "REFIT", "gear": "GEAR"}
const FADE_S: float = 0.2
const ROW_H: float = 34.0

var sim: Sim = null
var _sig: String = ""
var _sheet: Dossier.DossierSheet = null
var _center: CenterContainer = null
var _age: float = 0.0
var _buy_buttons: Array[Button] = []  ## One per visit line, in visit order.
var _sell_buttons: Array[Button] = []  ## One per EncounterStore.sellable entry, in that order.


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


## Everything the form depends on (the visit, money, what the ship has); a change rebuilds it.
func signature() -> String:
	var enc: Encounter = sim.encounter
	var parts: PackedStringArray = PackedStringArray([enc.store_id, str(Array(enc.purchases)), enc.hire_member,
			str(sim.ship.weapons), str(sim.run.gear), str(sim.run.state()), str(sim.drill.active)])
	for d: Dictionary in enc.visit:
		parts.append("%d:%d" % [int(d["price"]), int(d["stock"])])
	for r: Room in sim.ship.rooms:
		parts.append(str(r.sys_max))
	return "|".join(parts)


func buy(line: int, qty: int = 1) -> void:
	if sim != null and is_open():
		sim.push({"type": "buy", "item": line, "qty": qty})


func sell(what: String, id: String) -> void:
	if sim != null and is_open():
		sim.push({"type": "sell", "what": what, "id": id})


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

## What this line does for the ship as it stands ("DRILL BAR 5 OF 6: 100 ORE", "ON HAND 20", the
## candidate).
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
		"gear":
			return gear_effects(s.db, str(line.get("gear", "")))
		"upgrade":
			var ri: int = s.ship.room_with_system(str(line.get("system", "")))
			if ri < 0:
				return "NO SUCH SYSTEM"
			var r: Room = s.ship.rooms[ri]
			var sys_name: String = str(s.db.table("systems").get(r.system, {}).get("name", r.system)).to_upper()
			var top: int = StoreRoll.ladder(s.db, r.system).size()
			if r.sys_max >= top:
				return "%s AT ITS TOP (%d BARS)" % [sys_name, r.sys_max]
			return "%s BAR %d OF %d: %d ORE" % [sys_name, r.sys_max + 1, top, StoreRoll.next_bar_price(s, r.system)]
	return ""


## What a piece of gear does, in a few words ("CUT +25%  WEAR -40%"), from its effects in the data.
static func gear_effects(db: DataDB, id: String) -> String:
	var eff: Dictionary = (db.table("gear").get(id, {}) as Dictionary).get("effects", {})
	var parts: PackedStringArray = PackedStringArray()
	if eff.has("cut_speed_x"):
		parts.append("CUT %+d%%" % roundi((float(eff["cut_speed_x"]) - 1.0) * 100.0))
	if eff.has("wear_x"):
		parts.append("WEAR %+d%%" % roundi((float(eff["wear_x"]) - 1.0) * 100.0))
	if eff.has("hard_rock_x"):
		parts.append("HARD ROCK %+d%%" % roundi((float(eff["hard_rock_x"]) - 1.0) * 100.0))
	if eff.has("pump_x"):
		parts.append("PUMPS x%s" % str(snappedf(float(eff["pump_x"]), 0.1)))
	if eff.has("max_hull_add"):
		parts.append("+%d HULL" % int(eff["max_hull_add"]))
	return "  ".join(parts)


## "REPLACES TUNGSTEN HEAD" when this gear takes over an occupied slot, else "".
static func gear_replaces(s: Sim, id: String) -> String:
	var def: Dictionary = s.db.table("gear").get(id, {})
	var slot: String = str(def.get("slot", ""))
	if slot.is_empty():
		return ""
	var fitted: String = Gear.fitted_in(s, slot)
	if fitted.is_empty() or Gear.tier_of(s.db, fitted) >= int(def.get("tier", 0)):
		return ""
	return "REPLACES " + str((s.db.table("gear").get(fitted, {}) as Dictionary).get("name", fitted)).to_upper()


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


## The display name of an owned weapon or piece of gear.
static func item_name(db: DataDB, what: String, id: String) -> String:
	var def: Dictionary = db.table("weapons" if what == "weapon" else "gear").get(id, {})
	return str(def.get("name", id))


# Building -------------------------------------------------------------------------------------

func _rebuild() -> void:
	_age = 0.0
	_buy_buttons.clear()
	_sell_buttons.clear()
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
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	box.add_child(_header(st))
	box.add_child(StoreParts.rule())
	var stock: Array = st.get("stock", [])
	var section: String = ""
	for i: int in range(stock.size()):
		var line: Dictionary = stock[i]
		if str(line.get("section", "")) != section:
			section = str(line.get("section", ""))
			box.add_child(StoreParts.section_header(section))
		elif i > 0:
			box.add_child(StoreParts.dotted())
		box.add_child(_stock_row(i, line))
	box.add_child(_sell_block())
	var gap := Control.new()  # Room for the stamp between the Sell list and the foot.
	gap.custom_minimum_size = Vector2(0, 16)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.alignment = BoxContainer.ALIGNMENT_END
	var out: Button = StoreParts.button("Leave", 20)
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
	left.add_child(StoreParts.label("REQUISITION // TRADER", 16, UiTheme.INK_RED))
	left.add_child(StoreParts.label(str(st.get("name", "")), 40, UiTheme.INK))
	var blurb: Label = StoreParts.label(str(st.get("blurb", "")), 17, Color(UiTheme.INK, 0.85))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(760, 0)
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
		cell.add_child(StoreParts.CurrencyIcon.new().with_kind(cur, 30.0))
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
	var left: int = int(line.get("stock", -1))
	var bought: int = enc.purchases[i] if i < enc.purchases.size() else 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag: Label = StoreParts.label(str(TAG.get(str(line.get("item", "")), "")), 15, UiTheme.INK_RED)
	tag.custom_minimum_size = Vector2(78, 0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	var text: Label = StoreParts.label(str(line.get("text", "")), 18, UiTheme.INK if why.is_empty() else Color(UiTheme.INK, 0.62))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(540, 0)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(260, 0)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_gear: bool = str(line.get("item", "")) == "gear"
	info.add_child(StoreParts.mono_label(info_text(sim, line), 13 if is_gear else 14, UiTheme.STEEL_LIGHT))
	if is_gear:
		var rep: String = gear_replaces(sim, str(line.get("gear", "")))
		if not rep.is_empty() and why.is_empty():
			info.add_child(StoreParts.mono_label(rep, 13, UiTheme.INK_RED))
	if not why.is_empty():
		info.add_child(StoreParts.mono_label(why.to_upper(), 13, UiTheme.INK_RED))
	row.add_child(info)
	var cur: String = str(line.get("currency", "gems"))
	var short: bool = sim.run.get_res(cur) < int(line.get("price", 0))
	row.add_child(StoreParts.price_box(int(line.get("price", 0)), cur, short, 96.0, 24))
	var left_txt: String = ""
	if left >= 0:
		left_txt = "%d LEFT" % left
	elif bought > 0:
		left_txt = "BOUGHT %d" % bought
	var lim: Label = StoreParts.mono_label(left_txt, 14, UiTheme.STEEL_LIGHT)
	lim.custom_minimum_size = Vector2(82, 0)
	lim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lim)
	var b: Button = StoreParts.button("BUY", 19)
	b.custom_minimum_size = Vector2(96, 32)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not why.is_empty()
	b.pressed.connect(buy.bind(i, 1))
	_buy_buttons.append(b)
	row.add_child(b)
	return row


## The Sell list: what the ship owns that the trader would take, packed into a flowing row of
## small cards (name, sale price, SELL), each greyed with its reason when it cannot go now.
func _sell_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(StoreParts.section_header("sell"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 26)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e: Dictionary in EncounterStore.sellable(sim, sim.encounter):
		var why: String = str(e["why"])
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm: Label = StoreParts.label(item_name(sim.db, str(e["what"]), str(e["id"])), 17,
				UiTheme.INK if why.is_empty() else Color(UiTheme.INK, 0.62))
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(nm)
		card.add_child(StoreParts.price_box(int(e["price"]), str(e["currency"]), false, 64.0, 19))
		if not why.is_empty():
			var r: Label = StoreParts.mono_label(why.to_upper(), 12, UiTheme.INK_RED)
			r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(r)
		var b: Button = StoreParts.button("SELL", 16)
		b.custom_minimum_size = Vector2(76, 28)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not why.is_empty()
		b.pressed.connect(sell.bind(str(e["what"]), str(e["id"])))
		_sell_buttons.append(b)
		card.add_child(b)
		flow.add_child(card)
	if flow.get_child_count() == 0:
		flow.add_child(StoreParts.mono_label("NOTHING ABOARD TO SELL", 13, UiTheme.STEEL_LIGHT))
	box.add_child(flow)
	return box
