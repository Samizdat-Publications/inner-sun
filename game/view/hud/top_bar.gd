class_name TopBar
extends Control
## The strip across the top of the run screen: hull bar (flashes and leaves a red trail when hit),
## resources with drawn icons, depth, the phase, the run clock, a pause slot and the pursuer meter.
##
## Mount (from main.gd, on the HUD CanvasLayer; coordinates are the 1920x1080 design space):
##   var top: TopBar = TopBar.build(layer, sim)      # one call to build (positions it)
##   top.bind(new_sim)                               # one call to bind a Sim (again for a new run)
##   top.paused = true                               # the pause indicator slot
## Pursuer meter hook: it already draws the pursuer's front from run.pursuer_row. The player's own
## row appears once the map exists: set `current_row_getter` to a Callable returning the map row the
## ship is on as a float (return a negative number for "no row yet"), and `row_count` to the number
## of rows in the layer. Until then the ship marker stays out.

const DESIGN_SIZE: Vector2 = Vector2(1920, 90)
const RES_ORDER: Array[String] = ["ore", "gems", "coolant", "cells", "bits", "charges"]
const RES_LABEL: Dictionary = {"ore": "ORE", "gems": "GEMS", "coolant": "COOLANT", "cells": "CELLS", "bits": "BITS", "charges": "CHARGES"}
const PHASE_LABEL: Dictionary = {
	"scenario": "SCENARIO", "idle": "STANDING BY", "drill": "DRILLING", "dialog": "DOSSIER",
	"store": "TRADING POST", "combat": "ENGAGED", "dead": "LOST", "won": "BREAKTHROUGH",
}
const HELP_CHIP: Rect2 = Rect2(1750, 57, 150, 28)
const HULL_BAR: Rect2 = Rect2(104, 11, 320, 28)
const FLASH_S: float = 0.7

signal help_requested

var sim: Sim = null
var paused: bool = false  ## The pause indicator slot: main sets it.
var pause_text: String = "PAUSED"  ## "PAUSED: MAP" while the map holds the world.
var current_row_getter: Callable = Callable()  ## Hook for the pursuer meter, see the header.
var row_count: int = 12

var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()  ## Redraws at most 60 times a second.
var _hull_shown: float = 0.0
var _hull_last: int = -1
var _flash: float = 0.0


static func build(parent: Control, p_sim: Sim) -> TopBar:
	var p := TopBar.new()
	p.position = Vector2.ZERO
	p.size = DESIGN_SIZE
	p.mouse_filter = Control.MOUSE_FILTER_STOP  # Only the help chip takes clicks, see _has_point.
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_hull_last = -1
	_flash = 0.0
	if sim != null:
		_hull_shown = float(sim.run.get_res("hull"))
		_hull_last = sim.run.get_res("hull")
	queue_redraw()


## Only the HELP chip is clickable: the rest of the bar lets the mouse through.
func _has_point(point: Vector2) -> bool:
	return HELP_CHIP.has_point(point)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and HELP_CHIP.has_point(mb.position):
		help_requested.emit()
		accept_event()


## Jump every eased value to its target (the gallery and tests use this).
func snap() -> void:
	if sim != null:
		_hull_shown = float(sim.run.get_res("hull"))
		_hull_last = sim.run.get_res("hull")
	_flash = 0.0


func _process(delta: float) -> void:
	_t += delta
	if sim != null:
		var hull: int = sim.run.get_res("hull")
		if _hull_last >= 0 and hull < _hull_last:
			_flash = FLASH_S
		_hull_last = hull
		_hull_shown = move_toward(_hull_shown, float(hull), (3.0 + absf(_hull_shown - float(hull)) * 0.8) * delta)
	_flash = maxf(0.0, _flash - delta)
	if _pacer.due():
		queue_redraw()


static func phase_label(phase: String) -> String:
	return str(PHASE_LABEL.get(phase, phase.to_upper()))


static func clock_text(seconds: float) -> String:
	var total: int = int(seconds)
	return "T+%02d:%02d" % [total / 60, total % 60]


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	UiTheme.draw_panel(self, rect, "", false)
	if sim == null:
		return
	var run: RunState = sim.run
	_draw_hull(run)
	_draw_resources(run)
	_draw_depth(run)
	draw_line(Vector2(18, 51), Vector2(size.x - 18, 51), UiTheme.BRASS_DARK, 1.0)
	_draw_pursuer(run)
	_draw_status(run)


func _draw_hull(run: RunState) -> void:
	var maxh: int = maxi(1, sim.ship.hull_max)
	var cur: int = run.get_res("hull")
	var frac: float = float(cur) / float(maxh)
	var low: bool = frac <= 0.34
	UiTheme.bold_text(self, Vector2(22, 34), "HULL", 21, UiTheme.AMBER if not low else UiTheme.ALARM)
	var bar: Rect2 = HULL_BAR
	draw_rect(bar.grow(3.0), UiTheme.STEEL_DEEP, true)
	draw_rect(bar.grow(3.0), UiTheme.BRASS_DARK, false, 1.0)
	var gap: float = 2.0
	var w: float = (bar.size.x - gap * float(maxh - 1)) / float(maxh)
	var col: Color = UiTheme.CRT.lerp(UiTheme.AMBER, clampf((0.75 - frac) * 3.0, 0.0, 1.0))
	if low:
		col = UiTheme.ALARM.lerp(Color(1.0, 0.55, 0.45), UiTheme.pulse(_t, 2.2) * 0.7)
	for i: int in range(maxh):
		var x: float = bar.position.x + float(i) * (w + gap)
		var seg := Rect2(x, bar.position.y, w, bar.size.y)
		draw_rect(seg, Color(0.10, 0.12, 0.13), true)
		if float(i + 1) <= float(cur):
			draw_rect(seg, col, true)
			draw_rect(Rect2(seg.position, Vector2(w, 4.0)), Color(1, 1, 1, 0.18), true)
		elif float(i) < _hull_shown:
			draw_rect(seg, Color(UiTheme.ALARM, 0.75), true)
	if _flash > 0.0:
		var a: float = clampf(_flash / FLASH_S, 0.0, 1.0)
		draw_rect(bar.grow(3.0), Color(1.0, 0.92, 0.85, 0.55 * a), true)
		draw_rect(bar.grow(3.0), Color(UiTheme.ALARM, a), false, 3.0)
	UiTheme.bold_text(self, Vector2(bar.end.x + 18, 35), "%d/%d" % [cur, maxh], 26, UiTheme.ALARM if low else UiTheme.TEXT)


func _draw_resources(run: RunState) -> void:
	var x: float = 590.0
	for r: String in RES_ORDER:
		var n: int = run.get_res(r)
		var warn: bool = (r == "coolant" and n <= 4)
		var col: Color = UiTheme.AMBER
		if warn:
			col = UiTheme.ALARM.lerp(UiTheme.AMBER, 1.0 - UiTheme.pulse(_t, 2.0))
		UiTheme.icon(self, r, Vector2(x + 16.0, 27.0), 30.0)
		UiTheme.text(self, Vector2(x + 40.0, 20), str(RES_LABEL[r]), 15, UiTheme.TEXT)
		UiTheme.glow_text(self, Vector2(x + 40.0, 46), str(n), 28, col)
		x += 150.0


func _draw_depth(run: RunState) -> void:
	UiTheme.text(self, Vector2(size.x - 280, 20), "DEPTH", 14, UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_RIGHT, 256.0)
	var s: String = "%s m" % _spaced(roundi(run.depth_m))
	UiTheme.glow_text(self, Vector2(size.x - 292, 47), s, 38, UiTheme.CRT, null, HORIZONTAL_ALIGNMENT_RIGHT, 268.0)


static func _spaced(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	for i: int in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("-" if n < 0 else "") + out


func _draw_pursuer(run: RunState) -> void:
	UiTheme.text(self, Vector2(22, 77), "PURSUER", 18, UiTheme.TEXT)
	var track := Rect2(124, 59, 960, 20)
	draw_rect(track, UiTheme.STEEL_DEEP, true)
	draw_rect(track, UiTheme.BRASS_DARK, false, 1.0)
	var rows: float = float(maxi(1, row_count))
	for i: int in range(1, row_count):
		var tx: float = track.position.x + track.size.x * float(i) / rows
		draw_line(Vector2(tx, track.position.y + 12), Vector2(tx, track.end.y), Color(1, 1, 1, 0.10), 1.0)
	var front: float = clampf((run.pursuer_row + 1.0) / rows, 0.0, 1.0)
	if front > 0.0:
		var shade := Rect2(track.position, Vector2(track.size.x * front, track.size.y))
		draw_rect(shade, Color(UiTheme.ALARM, 0.55), true)
		draw_rect(Rect2(shade.end.x - 3.0, shade.position.y, 3.0, shade.size.y), UiTheme.ALARM, true)
	var row: float = -1.0
	if current_row_getter.is_valid():
		row = float(current_row_getter.call())
	if row >= 0.0:
		var sx: float = track.position.x + track.size.x * clampf((row + 0.5) / rows, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 6, track.position.y - 1), Vector2(sx + 6, track.position.y - 1), Vector2(sx, track.end.y + 1)]), UiTheme.CRT)
		UiTheme.bold_text(self, Vector2(sx + 10, 76), "SHIP", 16, UiTheme.CRT)


func _draw_status(run: RunState) -> void:
	var label: String = phase_label(run.phase)
	var chip := Rect2(1130, 57, 240, 28)
	var hot: bool = run.phase == "dead"
	draw_rect(chip, UiTheme.STEEL_DEEP, true)
	draw_rect(chip, UiTheme.ALARM if hot else UiTheme.BRASS, false, 1.5)
	UiTheme.bold_text(self, Vector2(chip.position.x, 78), label, 20, UiTheme.ALARM if hot else UiTheme.AMBER, null, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x)
	UiTheme.text(self, Vector2(1400, 78), clock_text(sim.seconds()), 22, UiTheme.TEXT)
	# Pause slot: two bars and a word while paused, an empty socket otherwise.
	var slot := Rect2(1556, 57, 170, 28)
	draw_rect(slot, UiTheme.STEEL_DEEP, true)
	draw_rect(slot, UiTheme.BRASS_DARK, false, 1.0)
	if paused:
		var on: float = 0.65 + 0.35 * UiTheme.pulse(_t, 1.0)
		draw_rect(Rect2(slot.position.x + 10, slot.position.y + 6, 5, 16), Color(UiTheme.AMBER, on), true)
		draw_rect(Rect2(slot.position.x + 20, slot.position.y + 6, 5, 16), Color(UiTheme.AMBER, on), true)
		UiTheme.bold_text(self, Vector2(slot.position.x + 36, 78), pause_text, 18, Color(UiTheme.AMBER, on))
	draw_rect(HELP_CHIP, UiTheme.STEEL_DEEP, true)
	draw_rect(HELP_CHIP, UiTheme.BRASS, false, 1.5)
	UiTheme.bold_text(self, Vector2(HELP_CHIP.position.x, 78), "HELP [H]", 18, UiTheme.BRASS_LIGHT, null, HORIZONTAL_ALIGNMENT_CENTER, HELP_CHIP.size.x)
