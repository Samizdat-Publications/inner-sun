class_name BlastCard
extends Control
## The charge launcher's card while drilling ("BLAST: 4 charges"). Shown over the bottom left of the
## world area whenever a segment is under way and the ship carries a launcher (the fight console,
## WeaponCards, takes over during a fight). The launcher's own key (F2 on the light drill) or a click
## on the card arms it, Esc disarms; with it armed a left click on the rock (Main) or on the seismic
## scanner (ScannerPanel) calls `aim(point)`, which pushes {"type": "blast", "x_m", "y_m"}. The card
## says why it cannot fire (the sim's own reasons from `blast_ready` and `aim_ok`) and shows the
## cooldown. A blast pays half the ore it frees (D039), and the card says so.
##
## Mount (RunScreen, on the HUD layer):  var blast: BlastCard = BlastCard.build(layer, sim)

const DESIGN_RECT: Rect2 = Rect2(340.0, 916.0, 430.0, 104.0)
const FLASH_S: float = 2.2
const SLOT_COLOR: Color = Color(0.45, 0.85, 1.0)
const KEYS: Array[Key] = [KEY_F1, KEY_F2, KEY_F3]
const REASONS: Dictionary = {
	"no charges": "NO CHARGES", "no launcher": "NO LAUNCHER", "not drilling": "NOT DRILLING",
	"out of range": "OUT OF RANGE",
}

var sim: Sim = null
var armed: bool = false
var keys_enabled: bool = true
var _t: float = 0.0
var _flash: String = ""
var _flash_age: float = 99.0
var _hover: bool = false
var _pacer: RedrawPacer = RedrawPacer.new()


static func build(parent: Control, p_sim: Sim) -> BlastCard:
	var p := BlastCard.new()
	p.position = DESIGN_RECT.position
	p.size = DESIGN_RECT.size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	armed = false
	_flash = ""
	_flash_age = 99.0
	visible = false
	queue_redraw()


## The slot of the ship's charge launcher in its weapon list (F1 is slot 0), or -1.
static func launcher_slot(s: Sim) -> int:
	var table: Dictionary = s.db.table("weapons")
	for i: int in range(s.ship.weapons.size()):
		if str((table.get(str(s.ship.weapons[i]), {}) as Dictionary).get("kind", "")) == "charge":
			return i
	return -1


## True when the card shows: a segment is under way, there is a launcher and no fight is on.
static func shown_for(s: Sim) -> bool:
	return s.drill.active and s.run.phase == "drill" and launcher_slot(s) >= 0 \
		and not (s.combat.active and s.enemy != null)


## The sim's reason in words for the card ("" when a blast may be fired now).
static func reason_text(s: Sim, why: String) -> String:
	if why.is_empty():
		return ""
	if why == "power weapons":
		var key: String = AlertsStrip.power_key(s.ship, s.ship.room_with_system("weapons"))
		return "POWER WEAPONS (%s)" % key if not key.is_empty() else "POWER WEAPONS"
	if why == "reloading":
		if s.drill.verbs.blast_pending:
			return "CHARGE IN FLIGHT"
		return "RELOADING %.1f S" % s.drill.verbs.blast_cooldown_left_s
	return str(REASONS.get(why, why.to_upper()))


## Charges held, or -1 when charges are free (scenarios).
static func charges_of(s: Sim) -> int:
	if s.run.mode != "run":
		return -1
	return s.run.get_res("charges")


## "BLAST: 4 CHARGES" and its variants.
static func title_for(s: Sim) -> String:
	var n: int = charges_of(s)
	if n < 0:
		return "BLAST: FREE CHARGES"
	return "BLAST: %d CHARGE%s" % [n, "" if n == 1 else "S"]


## Pure status for the tests: {"why": the blast_ready reason, "text": its words, "ready": bool}.
static func status(s: Sim) -> Dictionary:
	var why: String = s.drill.blast_ready(s)
	return {"why": why, "text": reason_text(s, why), "ready": why.is_empty()}


func say(text: String) -> void:
	_flash = text
	_flash_age = 0.0
	queue_redraw()


## Arm or disarm. A refusal is said on the card instead.
func toggle() -> void:
	if sim == null or not shown_for(sim):
		return
	if armed:
		armed = false
		return
	var st: Dictionary = status(sim)
	if bool(st["ready"]):
		armed = true
	else:
		say(str(st["text"]))


func disarm() -> void:
	armed = false


## The aim point (segment meters) was chosen: fire if the sim allows it. Returns true when the order
## was sent; a refusal is said on the card (and a point out of range leaves the card armed).
func aim(point: Vector2) -> bool:
	if sim == null:
		return false
	var why: String = sim.drill.blast_ready(sim)
	if why.is_empty():
		why = sim.drill.verbs.aim_ok(sim.drill, point)
		if why == "out of range":
			say("OUT OF RANGE (%d M)" % roundi(sim.db.tune("drill.blast_range_m")))
			return false
	if not why.is_empty():
		say(reason_text(sim, why))
		armed = false
		return false
	sim.push({"type": "blast", "x_m": snappedf(point.x, 0.01), "y_m": snappedf(point.y, 0.01)})
	armed = false
	return true


func _gui_input(event: InputEvent) -> void:
	if sim == null or not shown_for(sim):
		return
	if event is InputEventMouseMotion:
		_hover = true
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		toggle()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not keys_enabled or sim == null or not shown_for(sim):
		return
	if k.physical_keycode == KEY_ESCAPE and armed:
		armed = false
		get_viewport().set_input_as_handled()
		return
	var slot: int = launcher_slot(sim)
	if slot >= 0 and slot < KEYS.size() and k.physical_keycode == KEYS[slot]:
		toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = false


func _process(delta: float) -> void:
	_t += delta
	_flash_age += delta
	var show: bool = sim != null and shown_for(sim)
	if visible != show:
		visible = show
		if not show:
			armed = false
	if not show:
		return
	if armed and not bool(status(sim)["ready"]):
		armed = false  # The charge went off or the power was cut: the card stands down.
	if _pacer.due():
		queue_redraw()


func _draw() -> void:
	if sim == null or not shown_for(sim):
		return
	var r := Rect2(Vector2.ZERO, size)
	UiTheme.draw_panel(self, r, "", false)
	var st: Dictionary = status(sim)
	var ready: bool = bool(st["ready"])
	var p: float = UiTheme.pulse(_t, 2.4)
	var edge: Color = UiTheme.BRASS_DARK
	if armed:
		edge = UiTheme.AMBER.lerp(Color(1, 1, 1), 0.35 * p)
	elif ready:
		edge = UiTheme.CRT_DIM.lerp(UiTheme.CRT, p)
	else:
		edge = Color(0.55, 0.16, 0.12)
	var body := r.grow(-6.0)
	draw_rect(body, UiTheme.STEEL_LIGHT if _hover else UiTheme.STEEL, true)
	draw_rect(body, edge, false, 3.0 if armed else 2.0)
	draw_rect(Rect2(body.position, Vector2(6.0, body.size.y)), SLOT_COLOR if ready else UiTheme.AMBER_DIM, true)
	var x0: float = body.position.x + 18.0
	var slot: int = launcher_slot(sim)
	var badge := Rect2(x0, body.position.y + 8.0, 34.0, 24.0)
	draw_rect(badge, UiTheme.STEEL_DEEP, true)
	draw_rect(badge, UiTheme.BRASS_DARK, false, 1.0)
	UiTheme.text(self, badge.position + Vector2(0, 18), "F%d" % (slot + 1), 16, UiTheme.BRASS_LIGHT, null, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
	var dry: bool = charges_of(sim) == 0
	UiTheme.bold_text(self, Vector2(x0 + 44.0, body.position.y + 28.0), title_for(sim), 19, UiTheme.ALARM if dry else (UiTheme.AMBER if ready else UiTheme.AMBER_DIM))
	UiTheme.text(self, Vector2(x0, body.position.y + 52.0), "SHATTERS HALF THE ORE IT FREES", 14, UiTheme.TEXT_DIM)
	# The state line: the flash first, then armed, then why not, then ready.
	var line: String = ""
	var col: Color = UiTheme.TEXT
	if _flash_age < FLASH_S and not _flash.is_empty():
		line = _flash
		col = UiTheme.ALARM.lerp(Color(1, 1, 1), 0.3 * p)
	elif armed:
		line = "CLICK THE ROCK. RANGE %d M. ESC CANCELS" % roundi(sim.db.tune("drill.blast_range_m"))
		col = UiTheme.AMBER.lerp(Color(1, 1, 1), 0.3 * p)
	elif not ready:
		line = str(st["text"])
		col = UiTheme.ALARM
	else:
		line = "READY. PRESS F%d OR CLICK HERE" % (slot + 1)
		col = UiTheme.CRT
	var bar := Rect2(x0, body.position.y + 62.0, body.size.x - 32.0, 22.0)
	draw_rect(bar, UiTheme.STEEL_DEEP, true)
	var total: float = maxf(0.01, sim.db.tune("drill.blast_cooldown_s"))
	var left: float = sim.drill.verbs.blast_cooldown_left_s
	var frac: float = clampf(1.0 - left / total, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), UiTheme.CRT_DIM if frac < 1.0 else UiTheme.CRT_DIM.lerp(UiTheme.CRT, 0.5), true)
	draw_rect(bar, UiTheme.BRASS_DARK, false, 1.0)
	UiTheme.text(self, bar.position + Vector2(8, 17), line, 16, col)
	var n: int = charges_of(sim)
	if n >= 0:
		UiTheme.icon(self, "charges", Vector2(body.end.x - 62.0, body.position.y + 22.0), 22.0, Color(1, 1, 1) if not dry else Color(0.5, 0.3, 0.3))
		UiTheme.bold_text(self, Vector2(body.end.x - 46.0, body.position.y + 29.0), "x%d" % n, 22, UiTheme.ALARM if dry else UiTheme.TEXT)

