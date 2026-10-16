class_name PickupLayer
extends Node2D
## The floating "+2 IRON" texts at the drill crown (DigLog.pickups): coloured by the material, larger
## for gold and gems, rising and fading, merged while the same vein keeps being cut. Drawn in world
## space (the origin is the segment's top-left, like the rock) but sized in screen pixels, so the text
## reads the same at every wheel zoom. Unshaded, on top of the ship.

const RISE_PX: float = 60.0  ## Screen pixels a text climbs over its life.
const TIP_M: float = 2.3  ## The drill tip hangs this far below the crown: texts start there, on the rock.
const SPREAD_PX: float = 46.0  ## Texts of different materials fan out sideways by this.

var digs: DigLog = null
var ppm: float = 80.0
var _had: bool = false


func setup(p_digs: DigLog, p_ppm: float) -> void:
	digs = p_digs
	ppm = p_ppm
	z_index = 40
	material = ArtLib.unshaded()
	# The canvas modulate (the dark ambient) still multiplies unshaded items: lift by its inverse so
	# the text reaches the screen in its own colours.
	modulate = Color(1.0 / RockView.AMBIENT.r, 1.0 / RockView.AMBIENT.g, 1.0 / RockView.AMBIENT.b, 1.0)


func _process(_delta: float) -> void:
	if digs != null and (not digs.pickups.is_empty() or _had):
		queue_redraw()
	_had = digs != null and not digs.pickups.is_empty()


func _draw() -> void:
	if digs == null:
		return
	var zoom: float = maxf(0.2, get_viewport().get_canvas_transform().get_scale().x)
	var k: float = 1.0 / zoom
	var font: Font = UiTheme.mono()
	for p: Dictionary in digs.pickups:
		var age: float = float(p["age"])
		var t: float = clampf(age / DigLog.LIFE_S, 0.0, 1.0)
		var alpha: float = 1.0 - smoothstep(0.55, 1.0, t)
		var size_px: int = DigLog.pickup_size(p)
		var text: String = DigLog.pickup_text(p)
		var fan: float = float((str(p["mat"]).hash() & 7)) / 7.0 - 0.5
		var base: Vector2 = Vector2(float(p["x_m"]), float(p["y_m"]) + TIP_M) * ppm
		var off: Vector2 = Vector2(fan * SPREAD_PX * 3.0, 10.0 - RISE_PX * (1.0 - pow(1.0 - t, 2.0))) * k
		var pop: float = 1.0 + 0.25 * float(p["pop"])
		var fs: int = maxi(8, roundi(float(size_px) * k * pop))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var pos: Vector2 = base + off - Vector2(w * 0.5, 0.0)
		var col: Color = DigLog.readable(p["color"] as Color)
		var outline: int = maxi(2, roundi(5.0 * k))
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0.02, 0.02, 0.03, 0.9 * alpha))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, alpha))
