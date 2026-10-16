class_name RequisitionsView
extends Control
## The requisitions screen: a steel binder on a dimmed screen. The balance of research sits at the top,
## then one row per requisition (name, blurb, what it does, cost, and OWNED or a BUY button that is
## greyed with the reason when it cannot be bought yet). Buying saves the profile at once. Every owned
## requisition is loaded onto every later run (Requisitions). Escape or the Close button leaves.
##
## Mount (the death screen owns one, like its CodexView, so it sits above the death page):
##   var req: RequisitionsView = RequisitionsView.build(parent, db, profile)   # hidden until open()
##   req.bind(db, profile)         # again when the profile changes
##   req.open() / req.close()      # or Escape; `closed` and `bought(id)` signals
## It swallows the mouse while it is visible. `buy(id)` is what the BUY buttons call (tests too).

signal closed
signal bought(id: String)

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const FRAME: Rect2 = Rect2(290, 70, 1340, 940)
const ROW_X: float = 330.0
const ROW_W: float = 1260.0
const ROW_H: float = 112.0
const ROW_TOP: float = 230.0
const ROW_GAP: float = 8.0

var db: DataDB = null
var profile: Profile = null
var save_on_buy: bool = true  ## Tests and the gallery switch this off.

var _rows: Array[ReqRow] = []
var _close_button: Button = null
var _note: String = ""


static func build(parent: Control, p_db: DataDB, p_profile: Profile) -> RequisitionsView:
	var v := RequisitionsView.new()
	v.position = Vector2.ZERO
	v.size = DESIGN_SIZE
	parent.add_child(v)
	v.bind(p_db, p_profile)
	return v


func _init() -> void:
	theme = UiTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_close_button = Button.new()
	_close_button.text = "CLOSE  [ESC]"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.position = Vector2(FRAME.end.x - 280.0, FRAME.end.y - 64.0)
	_close_button.size = Vector2(250.0, 44.0)
	_close_button.add_theme_font_size_override("font_size", 19)
	_close_button.pressed.connect(close)
	add_child(_close_button)


func bind(p_db: DataDB, p_profile: Profile) -> void:
	db = p_db
	profile = p_profile
	_note = ""
	_reload()


func open() -> void:
	_note = ""
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


## Requisition ids in the order the rows show.
func row_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r: ReqRow in _rows:
		out.append(r.req_id)
	return out


## Buy one (what a BUY button does). Returns "" on success, else the reason.
func buy(id: String) -> String:
	if profile == null or db == null:
		return "no profile"
	var why: String = profile.buy(id, db)
	if why.is_empty():
		if save_on_buy:
			profile.save()
		_note = "LOADED ON EVERY DIVE: %s" % str((db.table("requisitions")[id] as Dictionary).get("name", id)).to_upper()
		bought.emit(id)
	else:
		_note = why.to_upper()
	_reload()
	return why


func _reload() -> void:
	for r: ReqRow in _rows:
		remove_child(r)
		r.queue_free()  # Not free(): a BUY press may be what called this.
	_rows.clear()
	if db == null or profile == null:
		queue_redraw()
		return
	var table: Dictionary = db.table("requisitions")
	var i: int = 0
	for id: String in Requisitions.ordered_ids(db):
		var def: Dictionary = table[id]
		var row := ReqRow.new()
		row.req_id = id
		row.title = str(def.get("name", id))
		row.blurb = str(def.get("blurb", ""))
		row.effect = Requisitions.effect_line(def, db)
		row.cost = int(def.get("cost", 0))
		row.owned = profile.owns(id)
		row.refusal = profile.buy_refusal(id, db)
		row.position = Vector2(ROW_X, ROW_TOP + float(i) * (ROW_H + ROW_GAP))
		row.size = Vector2(ROW_W, ROW_H)
		row.buy_pressed.connect(buy)
		add_child(row)
		_rows.append(row)
		i += 1
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not visible:
		return
	if k.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.015, 0.84), true)
	UiTheme.draw_panel(self, FRAME, "REQUISITIONS  /  TOPSIDE SUPPLY")
	var research: int = profile.research if profile != null else 0
	UiTheme.text(self, Vector2(ROW_X, 128.0), "RESEARCH BANKED", 18, UiTheme.TEXT_DIM)
	UiTheme.glow_text(self, Vector2(ROW_X, 182.0), str(research), 54, UiTheme.CRT)
	var w: float = UiTheme.text_width(str(research), 54)
	UiTheme.text(self, Vector2(ROW_X + w + 16.0, 182.0), "RP", 22, UiTheme.CRT_DIM)
	UiTheme.text(self, Vector2(ROW_X + 520.0, 128.0), "Equipment bought here is loaded onto every later dive.", 18, UiTheme.TEXT_DIM)
	UiTheme.text(self, Vector2(ROW_X + 520.0, 158.0), "Research comes from every run, even the ones that end badly.", 18, UiTheme.TEXT_DIM)
	if not _note.is_empty():
		UiTheme.text(self, Vector2(ROW_X + 520.0, 192.0), _note, 19, UiTheme.AMBER)
	draw_line(Vector2(ROW_X, 206.0), Vector2(ROW_X + ROW_W, 206.0), UiTheme.BRASS_DARK, 1.5)


## One requisition: name, blurb, effect, cost and a BUY button (or OWNED).
class ReqRow extends Control:
	signal buy_pressed(id: String)
	var req_id: String = ""
	var title: String = ""
	var blurb: String = ""
	var effect: String = ""
	var cost: int = 0
	var owned: bool = false
	var refusal: String = ""
	var button: Button = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		if owned:
			return
		button = Button.new()
		button.text = "BUY"
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(size.x - 190.0, 34.0)
		button.size = Vector2(160.0, 44.0)
		button.add_theme_font_size_override("font_size", 20)
		button.disabled = not refusal.is_empty()
		button.pressed.connect(func() -> void: buy_pressed.emit(req_id))
		add_child(button)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UiTheme.STEEL if not owned else UiTheme.STEEL_DEEP, true)
		draw_rect(r, UiTheme.BRASS_DARK, false, 1.0)
		if owned:
			draw_rect(Rect2(0, 0, 5, size.y), UiTheme.CRT, true)
		var dim: bool = not owned and not refusal.is_empty()
		UiTheme.text(self, Vector2(24, 38), title.to_upper(), 24, UiTheme.AMBER_DIM if dim else UiTheme.AMBER)
		UiTheme.text(self, Vector2(24, 68), blurb, 17, UiTheme.TEXT_DIM if dim else UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_LEFT, size.x - 520.0)
		UiTheme.text(self, Vector2(24, 96), effect, 18, UiTheme.CRT_DIM if dim else UiTheme.CRT)
		var cx: float = size.x - 470.0
		UiTheme.text(self, Vector2(cx, 48), "%d RP" % cost, 28, UiTheme.TEXT_DIM if dim else UiTheme.BRASS_LIGHT)
		if owned:
			UiTheme.bold_text(self, Vector2(size.x - 190.0, 64), "OWNED", 26, UiTheme.CRT)
		elif dim:
			UiTheme.text(self, Vector2(cx, 84), refusal, 17, UiTheme.ALARM)
