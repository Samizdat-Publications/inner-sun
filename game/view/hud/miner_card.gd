class_name MinerCard
extends Control
## The away miner's order card while drilling, to the right of the BlastCard. Idle it reads "SEND MINER:
## <CREW NAME>" for the crew member selected on the crew cards; G (or a click on the card) arms it, then a
## left click on the rock (Main) or on the seismic scanner (ScannerPanel) calls `aim(point)`, which pushes
## {"type": "send_miner", "crew", "x_m", "y_m"}. Right click or Esc disarms. While a miner is out the card
## reads "<NAME> OUTSIDE: <phase>" with the crew member's hp bar and the haul so far, and G (or a click)
## recalls ({"type": "recall_miner"}). A refusal is said in words on the card (the sim's own `why`).
## Arming the miner stands the BlastCard down and the reverse. The haul pays only when the miner climbs
## back in (D046), and the card says so.
##
## Mount (RunScreen, on the HUD layer):  var miner: MinerCard = MinerCard.build(layer, sim, blast)

const DESIGN_RECT: Rect2 = Rect2(780.0, 916.0, 430.0, 104.0)
const FLASH_S: float = 2.2
const READY_LINE: String = "G, THEN CLICK THE ROCK. THE DRILL PARKS ITSELF."
const SLOT_COLOR: Color = Color(0.55, 1.0, 0.55)
const PHASE_WORD: Dictionary = {
	"board": "GEARING UP", "exit": "CLIMBING OUT", "dig": "DIGGING", "vein": "AT THE VEIN",
	"return": "COMING HOME", "enter": "CLIMBING IN",
}
const REASONS: Dictionary = {
	"no_segment": "NOT DRILLING", "miner_out": "A MINER IS ALREADY OUT", "no_crew": "NO ONE CAN GO",
	"outside": "NO ROCK THERE", "no_miner": "NO MINER OUT",
}

var sim: Sim = null
var armed: bool = false
var keys_enabled: bool = true
var dev_arm: bool = false  ## Dev only (--arm-miner): arm again whenever the order is ready (for stills).
var blast: BlastCard = null  ## The charge launcher's card: only one of the two orders is armed at a time.
var crew_id_getter: Callable = Callable()  ## Returns the selected crew id (RunScreen sets it).
var _t: float = 0.0
var _flash: String = ""
var _flash_age: float = 99.0
var _hover: bool = false
var _blast_was: bool = false
var _pacer: RedrawPacer = RedrawPacer.new()


static func build(parent: Control, p_sim: Sim, p_blast: BlastCard) -> MinerCard:
	var p := MinerCard.new()
	p.position = DESIGN_RECT.position
	p.size = DESIGN_RECT.size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.blast = p_blast
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	armed = false
	_flash = ""
	_flash_age = 99.0
	_blast_was = false
	visible = false
	queue_redraw()


# Pure helpers (the tests read these) --------------------------------------------------------------

## True when the card shows: a segment is under way and no fight is on.
static func shown_for(s: Sim) -> bool:
	return s.drill.active and s.run.phase == "drill" and s.drill.drill_room >= 0 \
		and not (s.combat.active and s.enemy != null)


## The word for a miner phase ("DIGGING").
static func phase_word(phase: String) -> String:
	return str(PHASE_WORD.get(phase, phase.to_upper()))


## The sim's reason in words for the card ("" for no reason). `range_m` is only used for "range".
static func reason_text(why: String, range_m: float = 12.0) -> String:
	if why.is_empty():
		return ""
	if why == "range":
		return "TOO FAR (%d M)" % roundi(range_m)
	return str(REASONS.get(why, why.to_upper()))


## What a haul holds as words: "+12 ORE +2 GEMS" (a crate's coolant and so on follow), "" when empty.
static func haul_text(haul: PackedInt32Array, upper: bool = true) -> String:
	var parts := PackedStringArray()
	for i: int in range(mini(haul.size(), RunState.RESOURCES.size())):
		if haul[i] > 0:
			parts.append("+%d %s" % [haul[i], RunState.RESOURCES[i]])
	var out: String = " ".join(parts)
	return out.to_upper() if upper else out


## The haul in a plain Dictionary {res: n}, nonzero entries only (the tests and the tally read it).
static func haul_dict(haul: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(mini(haul.size(), RunState.RESOURCES.size())):
		if haul[i] > 0:
			out[RunState.RESOURCES[i]] = haul[i]
	return out


## "" when `crew_id` could be sent out now (no point needed), else the sim's reason word.
static func arm_why(s: Sim, crew_id: String) -> String:
	if not shown_for(s):
		return "no_segment"
	if s.drill.miner.active:
		return "miner_out"
	var c: CrewMember = s.ship.crew_by_id(crew_id)
	if c == null or not c.alive or c.away:
		return "no_crew"
	return ""


## The crew member's name in capitals, "" if there is no such crew member.
static func name_of(s: Sim, crew_id: String) -> String:
	var c: CrewMember = s.ship.crew_by_id(crew_id)
	return c.name.to_upper() if c != null else ""


## The title: "SEND MINER: OKAFOR" idle, "OKAFOR OUTSIDE: DIGGING" while out.
static func title_for(s: Sim, crew_id: String) -> String:
	var m: DrillMiner = s.drill.miner
	if m.active:
		return "%s OUTSIDE: %s" % [name_of(s, m.crew_id), phase_word(m.phase)]
	var who: String = name_of(s, crew_id)
	return "SEND MINER: %s" % who if not who.is_empty() else "SEND MINER"


## Pure status for the tests: {"out": bool, "why": the reason word, "text": its words, "ready": bool,
## "title": the title}.
static func status(s: Sim, crew_id: String) -> Dictionary:
	var m: DrillMiner = s.drill.miner
	var why: String = arm_why(s, crew_id)
	return {"out": m.active, "why": why, "text": reason_text(why, m.range_m), "ready": why.is_empty(),
			"title": title_for(s, crew_id)}


# Orders ---------------------------------------------------------------------------------------------

func crew_id() -> String:
	if sim == null:
		return ""
	if crew_id_getter.is_valid():
		return str(crew_id_getter.call())
	return sim.ship.crew[0].id if not sim.ship.crew.is_empty() else ""


func say(text: String) -> void:
	_flash = text
	_flash_age = 0.0
	queue_redraw()


## G or a click: recall while a miner is out, else arm or disarm. A refusal is said on the card.
func toggle() -> void:
	if sim == null or not shown_for(sim):
		return
	if sim.drill.miner.active:
		recall()
		return
	if armed:
		armed = false
		return
	var st: Dictionary = status(sim, crew_id())
	if bool(st["ready"]):
		armed = true
		if blast != null:
			blast.disarm()
	else:
		say(str(st["text"]))


func disarm() -> void:
	armed = false


func recall() -> void:
	if sim == null or not sim.drill.miner.active:
		return
	sim.push({"type": "recall_miner"})
	say("RECALLED")


## The aim point (segment meters) was chosen: send the selected crew member if the sim allows it.
## Returns true when the order was sent; a point out of range or off the rock leaves the card armed.
func aim(point: Vector2) -> bool:
	if sim == null:
		return false
	var id: String = crew_id()
	var why: String = DrillMiner.target_ok(sim.drill, sim, id, point)
	if not why.is_empty():
		say(reason_text(why, sim.drill.miner.range_m))
		if why != "range" and why != "outside":
			armed = false
		return false
	sim.push({"type": "send_miner", "crew": id, "x_m": snappedf(point.x, 0.01), "y_m": snappedf(point.y, 0.01)})
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
	if k.physical_keycode == KEY_G:
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
	# Arming the blast stands this order down (arming this one disarms the blast in toggle()).
	if blast != null:
		if blast.armed and not _blast_was:
			armed = false
		_blast_was = blast.armed
	if dev_arm and not armed and bool(status(sim, crew_id())["ready"]):
		armed = true
	if armed and not bool(status(sim, crew_id())["ready"]):
		armed = false  # A miner went out, or the crew member can no longer go: the card stands down.
	if _pacer.due():
		queue_redraw()


func _draw() -> void:
	if sim == null or not shown_for(sim):
		return
	var r := Rect2(Vector2.ZERO, size)
	UiTheme.draw_panel(self, r, "", false)
	var m: DrillMiner = sim.drill.miner
	var id: String = crew_id()
	var st: Dictionary = status(sim, id)
	var out: bool = bool(st["out"])
	var ready: bool = bool(st["ready"])
	var p: float = UiTheme.pulse(_t, 2.4)
	var edge: Color = UiTheme.BRASS_DARK
	if out:
		edge = UiTheme.AMBER.lerp(Color(1, 1, 1), 0.25 * p)
	elif armed:
		edge = UiTheme.AMBER.lerp(Color(1, 1, 1), 0.35 * p)
	elif ready:
		edge = UiTheme.CRT_DIM.lerp(UiTheme.CRT, p)
	else:
		edge = Color(0.55, 0.16, 0.12)
	var body := r.grow(-6.0)
	draw_rect(body, UiTheme.STEEL_LIGHT if _hover else UiTheme.STEEL, true)
	draw_rect(body, edge, false, 3.0 if (armed or out) else 2.0)
	draw_rect(Rect2(body.position, Vector2(6.0, body.size.y)), SLOT_COLOR if (ready or out) else UiTheme.AMBER_DIM, true)
	var x0: float = body.position.x + 18.0
	var badge := Rect2(x0, body.position.y + 8.0, 34.0, 24.0)
	draw_rect(badge, UiTheme.STEEL_DEEP, true)
	draw_rect(badge, UiTheme.BRASS_DARK, false, 1.0)
	UiTheme.text(self, badge.position + Vector2(0, 18), "G", 16, UiTheme.BRASS_LIGHT, null, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
	var title_col: Color = UiTheme.AMBER if (ready or out) else UiTheme.AMBER_DIM
	UiTheme.bold_text(self, Vector2(x0 + 44.0, body.position.y + 28.0), str(st["title"]), 18, title_col)
	var sub: String = "DIGS A VEIN OR A CRATE BY HAND"
	if out:
		var haul: String = haul_text(m.haul)
		sub = "HAUL %s" % haul if not haul.is_empty() else "HAUL: NOTHING YET"
		var who: CrewMember = sim.ship.crew_by_id(m.crew_id)
		if who != null:
			UiTheme.bold_text(self, Vector2(body.end.x - 96.0, body.position.y + 52.0), "HP %d" % roundi(who.hp), 16, UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_RIGHT, 84.0)
	UiTheme.text(self, Vector2(x0, body.position.y + 52.0), sub, 14, UiTheme.AMBER if out else UiTheme.TEXT_DIM)
	var line: String = ""
	var col: Color = UiTheme.TEXT
	if _flash_age < FLASH_S and not _flash.is_empty():
		line = _flash
		col = UiTheme.ALARM.lerp(Color(1, 1, 1), 0.3 * p)
	elif out:
		line = "PRESS G TO RECALL. PAID ON RETURN"
		col = UiTheme.AMBER.lerp(Color(1, 1, 1), 0.2 * p)
	elif armed:
		line = "CLICK THE ROCK. RANGE %d M. ESC CANCELS" % roundi(m.range_m)
		col = UiTheme.AMBER.lerp(Color(1, 1, 1), 0.3 * p)
	elif not ready:
		line = str(st["text"])
		col = UiTheme.ALARM
	else:
		line = READY_LINE
		col = UiTheme.CRT
	var bar := Rect2(x0, body.position.y + 62.0, body.size.x - 32.0, 22.0)
	draw_rect(bar, UiTheme.STEEL_DEEP, true)
	if out:
		var who2: CrewMember = sim.ship.crew_by_id(m.crew_id)
		var frac: float = clampf(who2.hp / CrewMember.MAX_HP, 0.0, 1.0) if who2 != null else 0.0
		var hp_col: Color = UiTheme.CRT_DIM if frac > 0.6 else (UiTheme.AMBER_DIM if frac > 0.3 else Color(0.6, 0.15, 0.1))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), hp_col, true)
	draw_rect(bar, UiTheme.BRASS_DARK, false, 1.0)
	var line_size: int = 16
	while line_size > 11 and UiTheme.text_width(line, line_size) > bar.size.x - 14.0:
		line_size -= 1
	UiTheme.text(self, bar.position + Vector2(8, 17), line, line_size, col)
