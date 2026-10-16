class_name HelpView
extends Control
## The help screen: the goal, the controls, what each system does and "when X happens" lines on one
## steel panel.
## H or the HELP chip on the top bar opens it, H or Esc closes it. While it is open the world is held
## (main.gd does not step the sim for a human) and it swallows the mouse. Main opens it by itself on
## the first run of a fresh profile. Reads no sim state: the text is fixed.
##
## Mount (main.gd, on the HUD CanvasLayer, below the death screen):
##   var help: HelpView = HelpView.build(layer)

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const FRAME: Rect2 = Rect2(250, 56, 1420, 968)
const GOAL: String = "Drill down through the Crust to the gate at the bottom of the map. Pick a route on the map, drill there, deal with what you find. Mine ore and gems on the way; spend them in trading posts. Something is following your noise (the red front on the map). Louder drilling (more drill power) draws it faster. If it catches you it strikes the hull every 10 seconds."
const CONTROLS: Array[String] = [
	"MAP   click a lit node to drill there. M opens and closes the map.",
	"STEER   A and D (or the arrows), or click the seismic scanner. B fits a new bit.",
	"POWER   Q W E R T Y add a bar to a system, Shift plus the key removes one. Or click the bars.",
	"CREW   1 2 3 select, left-click a room to send them, right-click to release them.",
	"FIGHTS   F1 F2 arm a weapon, then click an enemy room. Power weapons (E) and bracing (W).",
	"PAUSE   Space. You can give orders while paused. The world also holds while the map is open.",
	"EVENTS   click an option or press its number. Greyed options say what they need. H or Esc closes this page.",
]
const SYSTEMS: Array[String] = [
	"HELM   needs crew on the bridge. Drilling: how fast the drill turns. Fights: dodges shots, 6% a bar.",
	"BRACING   every 2 bars hold a layer that soaks one hit, back after 6 s. It works in fights.",
	"COOLANT AND PUMPS   spends coolant (top bar) to chill every room and runs the pumps. Cool rooms rarely catch fire.",
	"DRILL   more bars cut faster, hotter and louder. Repairs go at crew speed whatever the drill does.",
]
const WHEN: Array[String] = [
	"FLOODING   Water pockets (blue on the scanner) and breaches let water in. Crew patch breaches; pumps run while COOLANT AND PUMPS has power. Crew will not wade into deep water on their own: order one in (1-3, then click the room).",
	"FIRE   Crew put fires out; fires grow, spread through doors and hatches, and break systems.",
	"DAMAGE   Crew repair broken power bars on their own; power comes back after a repair. Hull only comes back at a trading post (2 ore a point).",
	"DRILL STOPPED   a red notice says why: no power (R), a broken bit (B fits a spare), overheated or wrecked.",
]

var _t: float = 0.0


static func build(parent: Control) -> HelpView:
	var h := HelpView.new()
	h.position = Vector2.ZERO
	h.size = DESIGN_SIZE
	parent.add_child(h)
	return h


func _init() -> void:
	theme = UiTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	col.position = FRAME.position + Vector2(48, 78)
	col.size = Vector2(FRAME.size.x - 96.0, FRAME.size.y - 150.0)
	col.add_theme_constant_override("separation", 7)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(_head("THE GOAL"))
	col.add_child(_para(GOAL, UiTheme.TEXT))
	col.add_child(_head("CONTROLS"))
	for s: String in CONTROLS:
		col.add_child(_para(s, UiTheme.BRASS_LIGHT))
	col.add_child(_head("WHAT THE SYSTEMS DO"))
	for s: String in SYSTEMS:
		col.add_child(_para(s, UiTheme.BRASS_LIGHT))
	col.add_child(_head("WHEN SOMETHING GOES WRONG"))
	for s: String in WHEN:
		col.add_child(_para(s, UiTheme.TEXT))
	var close := Button.new()
	close.text = "CLOSE  [H]"
	close.focus_mode = Control.FOCUS_NONE
	close.position = Vector2(FRAME.end.x - 240.0, FRAME.end.y - 58.0)
	close.size = Vector2(200, 40)
	close.pressed.connect(close_help)
	add_child(close)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	queue_redraw()


func close_help() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close_help()
	else:
		open()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not visible:
		return
	if k.physical_keycode == KEY_ESCAPE:
		close_help()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		_t += delta


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.015, 0.84), true)
	UiTheme.draw_panel(self, FRAME, "HELP")


func _head(s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", UiTheme.AMBER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _para(s: String, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(FRAME.size.x - 96.0, 0)
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
