class_name Hud
extends CanvasLayer
## Plain readout for M0: time and status, each room's heat, water and fire, the crew, and the last
## few events. M1 replaces this with real instrument panels.

const HINT_M0: String = "M0 loop proof. Click a room to send the first crew member there (same command the bots use)."
const HINT_DRILL: String = "Drilling: A and D steer, W and S add or remove drill power. Click a room to send a crew member."

var run: Driver
var _label: Label
var _hint: Label
var _bg: ColorRect


func bind(p_run: Driver) -> void:
	run = p_run


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.025, 0.72)
	_bg.position = Vector2(16, 16)
	_bg.size = Vector2(470, 330)
	add_child(_bg)
	_label = Label.new()
	_label.position = Vector2(28, 24)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.32))
	add_child(_label)
	_hint = Label.new()
	_hint.position = Vector2(28, 1030)
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.7))
	_hint.text = HINT_M0
	add_child(_hint)


func _process(_delta: float) -> void:
	if run == null:
		return
	var s: Sim = run.sim
	var lines := PackedStringArray()
	lines.append("INNER SUN // DRILL VESSEL %s" % s.ship.name.to_upper())
	lines.append("T+%05.1f s   seed %d   bot %s   %s" % [s.seconds(), s.run_seed, run.bot_name, run.outcome if run.done() else "running"])
	lines.append("")
	var dr: DrillSim = s.drill
	var drilling: bool = dr.segment_id != ""
	if drilling:
		lines.append_array(_drill_lines(s, dr))
		lines.append("")
	_bg.size.y = 330.0 + (130.0 if drilling else 0.0)
	_hint.text = HINT_DRILL if dr.active else HINT_M0
	for r: Room in s.ship.rooms:
		lines.append("%-18s %4d C  %4.2f m  fire %3d%%" % [r.name, roundi(r.temp_c()), r.level_m(), roundi(r.fire * 100.0)])
	lines.append("")
	for c: CrewMember in s.ship.crew:
		var job: String = c.job_kind if not c.job_kind.is_empty() else "idle"
		lines.append("%-10s hp %3d  %-10s %s" % [c.name, roundi(c.hp), job, "" if c.alive else "LOST (" + c.cause_of_death + ")"])
	lines.append("")
	var first: int = maxi(0, s.events.size() - 4)
	for i: int in range(first, s.events.size()):
		var e: Dictionary = s.events[i]
		lines.append("T+%05.1f %s %s" % [float(int(e["t"])) / Sim.TICK_HZ, str(e["kind"]), str(e.get("room", e.get("crew", "")))])
	_label.text = "\n".join(lines)


## The drilling readout: depth, speed, heading, bit wear, drill power and what has been mined.
func _drill_lines(s: Sim, d: DrillSim) -> PackedStringArray:
	var out := PackedStringArray()
	var di: int = s.ship.room_with_system("drill")
	var bars: String = ""
	if di >= 0:
		var room: Room = s.ship.rooms[di]
		bars = "%d/%d" % [room.effective_bars(), room.sys_max]
	var state: String = "CUTTING" if d.cutting else "IDLE"
	if not d.active:
		state = "ARRIVED"
	elif d.bit_broken:
		state = "BIT BROKEN"
	elif d.bit_change_left_s > 0.0:
		state = "BIT CHANGE %.0fs" % d.bit_change_left_s
	out.append("DRILL %s   %s" % [d.segment_id, state])
	out.append("depth %6.1f m   segment %3d%%   speed %.2f m/s" % [s.run.depth_m, roundi(d.progress() * 100.0), d.speed_m_s])
	out.append("heading %+3d deg (set %+3d)   drill bars %s" % [roundi(d.heading_deg), roundi(d.target_heading_deg), bars])
	var wear: int = clampi(roundi(d.bit_wear * 10.0), 0, 10)
	out.append("bit wear [%s%s] %3d%%   bits %d" % ["#".repeat(wear), "-".repeat(10 - wear), roundi(d.bit_wear * 100.0), s.run.get_res("bits")])
	out.append("ore %d   gems %d   pockets burst %d" % [s.run.get_res("ore"), s.run.get_res("gems"), d.pockets_burst])
	return out
