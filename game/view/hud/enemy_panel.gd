class_name EnemyPanel
extends Control
## The threat readout along the top of the world area during a fight: who it is, its hull, its bracing
## layers, its evasion and every enemy weapon with its charge bar, so the player can read what is
## about to hit them. Informational only (it never takes the mouse).
##
## Mount (RunScreen, on the HUD CanvasLayer, 1920x1080 design space):
##   var enemy: EnemyPanel = EnemyPanel.build(layer, sim)
##   enemy.bind(new_sim)

const DESIGN_RECT: Rect2 = Rect2(340.0, 98.0, 1180.0, 80.0)

var sim: Sim = null
var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()  ## Redraws at most 60 times a second.
var _hull_shown: float = 0.0
var _charge_shown: PackedFloat32Array = PackedFloat32Array()


static func build(parent: Control, p_sim: Sim) -> EnemyPanel:
	var p := EnemyPanel.new()
	p.position = DESIGN_RECT.position
	p.size = DESIGN_RECT.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_charge_shown = PackedFloat32Array()
	visible = false
	queue_redraw()


func in_fight() -> bool:
	return sim != null and sim.combat.active and sim.enemy != null


func _process(delta: float) -> void:
	_t += delta
	var fight: bool = in_fight()
	if visible != fight:
		visible = fight
		if fight:
			_hull_shown = float(sim.combat.enemy_hull)
	if not fight:
		return
	_hull_shown = move_toward(_hull_shown, float(sim.combat.enemy_hull), 10.0 * delta)
	var wv: Array[Dictionary] = sim.combat.weapons_view(sim, true)
	if _charge_shown.size() != wv.size():
		_charge_shown.resize(wv.size())
	for i: int in range(wv.size()):
		_charge_shown[i] = move_toward(_charge_shown[i], float(wv[i]["charge_s"]), 18.0 * delta)
	if _pacer.due():
		queue_redraw()


func _draw() -> void:
	if not in_fight():
		return
	UiTheme.draw_panel(self, Rect2(Vector2.ZERO, size), "", false)
	var c: CombatSim = sim.combat
	var info: Dictionary = sim.db.ships.get(c.enemy_id, {})
	var name_text: String = str(info.get("name", c.enemy_id)).to_upper()
	UiTheme.bold_text(self, Vector2(18, 28), "HOSTILE" if not c.boss else "HOSTILE: BOSS", 17, UiTheme.ALARM)
	UiTheme.glow_text(self, Vector2(18, 62), name_text, 28, UiTheme.AMBER)
	# Hull.
	var hull_x: float = 290.0
	UiTheme.icon(self, "hull", Vector2(hull_x + 12.0, 24.0), 22.0)
	UiTheme.bold_text(self, Vector2(hull_x + 32.0, 30.0), "HULL %d / %d" % [c.enemy_hull, c.enemy_hull_max], 19, UiTheme.TEXT)
	var bar := Rect2(hull_x, 42.0, 230.0, 22.0)
	draw_rect(bar, UiTheme.STEEL_DEEP, true)
	var frac: float = clampf(_hull_shown / float(maxi(1, c.enemy_hull_max)), 0.0, 1.0)
	var low: bool = frac < 0.34
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), UiTheme.ALARM if low else UiTheme.AMBER, true)
	draw_rect(bar, UiTheme.BRASS_DARK, false, 1.0)
	# Bracing layers and evasion.
	var br_x: float = 560.0
	var layers: int = sim.systems.bracing_layers(sim.enemy)
	var layers_max: int = sim.systems.max_layers(sim.enemy)
	UiTheme.icon(self, "shield", Vector2(br_x + 12.0, 24.0), 22.0)
	UiTheme.bold_text(self, Vector2(br_x + 32.0, 30.0), "BRACING", 19, UiTheme.TEXT)
	if layers_max <= 0:
		UiTheme.text(self, Vector2(br_x, 62.0), "NONE", 18, UiTheme.TEXT_DIM)
	for i: int in range(layers_max):
		var pip := Rect2(br_x + float(i) * 26.0, 42.0, 22.0, 22.0)
		draw_rect(pip, Color(0.35, 0.75, 1.0) if i < layers else UiTheme.STEEL_DEEP, true)
		draw_rect(pip, UiTheme.BRASS_DARK, false, 1.0)
	var eva: int = roundi(sim.systems.evasion(sim.enemy) * 100.0)
	UiTheme.text(self, Vector2(br_x + 120.0, 62.0), "EVADE %d%%" % eva, 19, UiTheme.TEXT if eva > 0 else UiTheme.TEXT_DIM)
	# Weapons, charging (or, in the magnetite snow, unreadable).
	var wv: Array[Dictionary] = c.weapons_view(sim, true)
	var wx: float = 780.0
	if sim.run.rival_rooms_hidden():
		UiTheme.bold_text(self, Vector2(wx, 30.0), "SYSTEMS UNREADABLE", 18, UiTheme.ALARM)
		UiTheme.text(self, Vector2(wx, 62.0), "MAGNETITE: NO SIGNAL FROM ITS ROOMS", 16, UiTheme.TEXT_DIM)
		return
	var avail: float = size.x - wx - 14.0
	var ww: float = minf(250.0, avail / float(maxi(1, wv.size())) - 10.0)
	for i: int in range(wv.size()):
		var w: Dictionary = wv[i]
		var x: float = wx + float(i) * (ww + 10.0)
		var cmax: float = maxf(0.01, float(w["charge_max_s"]))
		var f: float = clampf(_charge_shown[i] / cmax, 0.0, 1.0) if i < _charge_shown.size() else 0.0
		var powered: bool = bool(w["powered"])
		UiTheme.bold_text(self, Vector2(x, 30.0), str(w["name"]).to_upper(), 16, UiTheme.TEXT if powered else UiTheme.TEXT_DIM)
		var wb := Rect2(x, 42.0, ww, 22.0)
		draw_rect(wb, UiTheme.STEEL_DEEP, true)
		var col: Color = UiTheme.ALARM.lerp(Color(1.0, 0.6, 0.4), UiTheme.pulse(_t, 4.0)) if f >= 0.999 and powered else (UiTheme.FIRE if powered else Color(0.35, 0.34, 0.33))
		draw_rect(Rect2(wb.position, Vector2(wb.size.x * f, wb.size.y)), col, true)
		draw_rect(wb, UiTheme.BRASS_DARK, false, 1.0)
		var state: String = ("FIRING" if f >= 0.999 else "%.0f s" % maxf(0.0, cmax - _charge_shown[i])) if powered else "NO POWER"
		UiTheme.text(self, wb.position + Vector2(0, 17), state, 15, UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_CENTER, wb.size.x)
