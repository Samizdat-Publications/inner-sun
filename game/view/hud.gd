class_name Hud
extends CanvasLayer
## Plain readout for M0: time and status, each room's heat, water and fire, the crew, and the last
## few events. M1 replaces this with real instrument panels.

var run: ScenarioRun
var _label: Label
var _hint: Label


func bind(p_run: ScenarioRun) -> void:
	run = p_run


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025, 0.72)
	bg.position = Vector2(16, 16)
	bg.size = Vector2(470, 330)
	add_child(bg)
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
	_hint.text = "M0 loop proof. Click a room to send the first crew member there (same command the bots use)."
	add_child(_hint)


func _process(_delta: float) -> void:
	if run == null:
		return
	var s: Sim = run.sim
	var lines := PackedStringArray()
	lines.append("INNER SUN // DRILL VESSEL %s" % s.ship.name.to_upper())
	lines.append("T+%05.1f s   seed %d   bot %s   %s" % [s.seconds(), s.run_seed, run.bot_name, run.outcome if run.done() else "running"])
	lines.append("")
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
