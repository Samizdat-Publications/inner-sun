class_name UiTheme
extends RefCounted
## The look of every UI piece: dark steel panels with brass edges, amber and CRT green instrument
## text, paper for documents (docs/STYLE_GUIDE.md, "Look"). Fonts, colors, a Theme for Controls, and
## drawing helpers (panel frames, icons, text) that the HUD panels call from their _draw.
## Fonts (assets/fonts, credited in docs/CREDITS.md): Share Tech Mono for instruments, Special Elite
## for documents. Pure view code: reads nothing from the sim.

const STEEL_DEEP: Color = Color(0.050, 0.060, 0.072)
const STEEL_DARK: Color = Color(0.082, 0.098, 0.116)
const STEEL: Color = Color(0.125, 0.150, 0.175)
const STEEL_LIGHT: Color = Color(0.200, 0.235, 0.268)
const BRASS: Color = Color(0.720, 0.540, 0.235)
const BRASS_DARK: Color = Color(0.420, 0.305, 0.130)
const BRASS_LIGHT: Color = Color(0.940, 0.780, 0.450)
const AMBER: Color = Color(1.000, 0.700, 0.280)
const AMBER_DIM: Color = Color(0.560, 0.380, 0.150)
const CRT: Color = Color(0.350, 0.950, 0.480)
const CRT_DIM: Color = Color(0.090, 0.340, 0.170)
const ALARM: Color = Color(0.930, 0.260, 0.190)
const FIRE: Color = Color(1.000, 0.480, 0.110)
const WATER: Color = Color(0.250, 0.560, 0.860)
const HAZARD: Color = Color(0.930, 0.760, 0.100)
const TEXT: Color = Color(0.850, 0.830, 0.760)
const TEXT_DIM: Color = Color(0.500, 0.510, 0.510)
const PAPER: Color = Color(0.835, 0.775, 0.640)
const PAPER_DARK: Color = Color(0.700, 0.635, 0.505)
const INK: Color = Color(0.110, 0.095, 0.080)
const INK_RED: Color = Color(0.560, 0.120, 0.100)

const MONO_PATH: String = "res://assets/fonts/ShareTechMono-Regular.ttf"
const TYPEWRITER_PATH: String = "res://assets/fonts/SpecialElite-Regular.ttf"

static var _mono: Font = null
static var _typewriter: Font = null
static var _theme: Theme = null


## The instrument font (Share Tech Mono). Falls back to a system monospace if the import is missing.
static func mono() -> Font:
	if _mono == null:
		_mono = _load_font(MONO_PATH, ["Consolas", "Courier New", "monospace"])
	return _mono


## The document font (Special Elite, a worn typewriter).
static func typewriter() -> Font:
	if _typewriter == null:
		_typewriter = _load_font(TYPEWRITER_PATH, ["Courier New", "monospace"])
	return _typewriter


static func _load_font(path: String, fallback: Array[String]) -> Font:
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path) as Font
	if f == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(fallback)
		f = sf
	return f


# Text ------------------------------------------------------------------------------------------

## Draw text with its baseline at pos.y. Call from a _draw.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int = 16, color: Color = TEXT,
		font: Font = null, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = font if font != null else mono()
	ci.draw_string(f, pos, s, align, width, size, color)


static func text_width(s: String, size: int = 16, font: Font = null) -> float:
	var f: Font = font if font != null else mono()
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Text with a soft glow behind it, for the green and amber instruments.
static func glow_text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color,
		font: Font = null, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var halo: Color = Color(color.r, color.g, color.b, 0.22)
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		text(ci, pos + o, s, size, halo, font, align, width)
	text(ci, pos, s, size, color, font, align, width)


# Frames ----------------------------------------------------------------------------------------

## A steel panel with a brass edge, corner rivets and a title strip. Call from a _draw.
static func draw_panel(ci: CanvasItem, rect: Rect2, title: String = "", stripes: bool = true) -> void:
	ci.draw_rect(rect, BRASS_DARK, true)
	var body: Rect2 = rect.grow(-2.0)
	ci.draw_rect(body, STEEL_DARK, true)
	ci.draw_rect(Rect2(body.position, Vector2(body.size.x, 3.0)), Color(1, 1, 1, 0.05), true)
	ci.draw_rect(body, BRASS, false, 1.5)
	# Faint scratches, fixed by the panel size so nothing shimmers.
	var h: int = int(rect.size.x * 7.0 + rect.size.y * 13.0)
	for i: int in range(5):
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var sx: float = rect.position.x + 16.0 + float(h % maxi(1, int(rect.size.x) - 60))
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var sy: float = rect.position.y + 34.0 + float(h % maxi(1, int(rect.size.y) - 50))
		ci.draw_line(Vector2(sx, sy), Vector2(sx + 14.0 + float(h % 22), sy + 1.0), Color(1, 1, 1, 0.035), 1.0)
	for c: Vector2 in [Vector2(7, 7), Vector2(rect.size.x - 7, 7), Vector2(7, rect.size.y - 7), Vector2(rect.size.x - 7, rect.size.y - 7)]:
		var p: Vector2 = rect.position + c
		ci.draw_circle(p, 3.0, BRASS_DARK)
		ci.draw_circle(p + Vector2(-0.6, -0.6), 2.0, BRASS)
		ci.draw_circle(p + Vector2(-1.0, -1.0), 0.8, BRASS_LIGHT)
	if title.is_empty():
		return
	var strip: Rect2 = Rect2(rect.position + Vector2(14, 5), Vector2(rect.size.x - 28, 22))
	ci.draw_rect(strip, STEEL_DEEP, true)
	ci.draw_line(strip.position + Vector2(0, strip.size.y), strip.position + strip.size, BRASS_DARK, 1.0)
	text(ci, strip.position + Vector2(8, 16), title, 15, AMBER)
	if stripes:
		hazard_stripes(ci, Rect2(strip.end.x - 54.0, strip.position.y + 3.0, 48.0, strip.size.y - 6.0))


## Yellow and black diagonal warning stripes in a rect.
static func hazard_stripes(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, Color(0.07, 0.07, 0.06), true)
	var step: float = rect.size.y
	var clip: PackedVector2Array = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var x: float = rect.position.x - step
	while x < rect.end.x:
		var band: PackedVector2Array = PackedVector2Array([
			Vector2(x, rect.end.y), Vector2(x + step, rect.position.y),
			Vector2(x + step * 1.5, rect.position.y), Vector2(x + step * 0.5, rect.end.y)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(band, clip):
			ci.draw_colored_polygon(piece, HAZARD)
		x += step


## A flat StyleBoxFlat (for Buttons and containers).
static func box(fill: Color, border: Color, border_w: int = 2, radius: int = 2, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.5
	sb.content_margin_bottom = pad * 0.5
	return sb


## A ready PanelContainer-style box: steel with a brass edge.
static func steel_box(pad: int = 10) -> StyleBoxFlat:
	return box(STEEL_DARK, BRASS, 2, 3, pad)


## The Theme for Controls (Buttons, Labels, RichTextLabel). Variations: "PaperButton" (a typed tag on
## paper) and "SteelButton" (a switch on a steel panel).
static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = mono()
	t.default_font_size = 18
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_color(&"font_color", &"RichTextLabel", INK)
	t.set_color(&"default_color", &"RichTextLabel", INK)
	# Steel buttons.
	t.set_stylebox(&"normal", &"Button", box(STEEL, BRASS_DARK))
	t.set_stylebox(&"hover", &"Button", box(STEEL_LIGHT, BRASS))
	t.set_stylebox(&"pressed", &"Button", box(STEEL_DEEP, AMBER))
	t.set_stylebox(&"disabled", &"Button", box(STEEL_DEEP, Color(0.2, 0.2, 0.2)))
	t.set_stylebox(&"focus", &"Button", box(Color(0, 0, 0, 0), AMBER, 2, 2, 8))
	t.set_color(&"font_color", &"Button", AMBER)
	t.set_color(&"font_hover_color", &"Button", BRASS_LIGHT)
	t.set_color(&"font_pressed_color", &"Button", BRASS_LIGHT)
	t.set_color(&"font_disabled_color", &"Button", Color(0.38, 0.38, 0.36))
	t.set_font_size(&"font_size", &"Button", 18)
	# Paper buttons: a typed tag.
	t.set_type_variation(&"PaperButton", &"Button")
	t.set_stylebox(&"normal", &"PaperButton", box(Color(0.80, 0.74, 0.60), INK, 1, 1, 12))
	t.set_stylebox(&"hover", &"PaperButton", box(Color(0.93, 0.85, 0.62), INK_RED, 2, 1, 12))
	t.set_stylebox(&"pressed", &"PaperButton", box(Color(0.70, 0.62, 0.46), INK_RED, 2, 1, 12))
	t.set_stylebox(&"disabled", &"PaperButton", box(Color(0.72, 0.67, 0.56), Color(0.52, 0.48, 0.40), 1, 1, 12))
	t.set_stylebox(&"focus", &"PaperButton", box(Color(0, 0, 0, 0), INK_RED, 2, 1, 12))
	t.set_color(&"font_color", &"PaperButton", INK)
	t.set_color(&"font_hover_color", &"PaperButton", INK_RED)
	t.set_color(&"font_pressed_color", &"PaperButton", INK_RED)
	t.set_color(&"font_disabled_color", &"PaperButton", Color(0.45, 0.42, 0.36))
	t.set_font(&"font", &"PaperButton", typewriter())
	t.set_font_size(&"font_size", &"PaperButton", 22)
	_theme = t
	return t


# Icons -----------------------------------------------------------------------------------------

## Small drawn icons, centered on c with a nominal size (pixels across). Kinds: ore, gems, coolant,
## cells, bits, charges, hull, crew, warn, flame, drop, shield, hammer.
static func icon(ci: CanvasItem, kind: String, c: Vector2, size: float, tint: Color = Color(1, 1, 1, 1)) -> void:
	var s: float = size * 0.5
	match kind:
		"ore":
			var pts: PackedVector2Array = PackedVector2Array([
				c + Vector2(-s, s * 0.6), c + Vector2(-s * 0.7, -s * 0.4), c + Vector2(-s * 0.1, -s),
				c + Vector2(s * 0.7, -s * 0.5), c + Vector2(s, s * 0.5), c + Vector2(s * 0.1, s)])
			ci.draw_colored_polygon(pts, Color(0.72, 0.38, 0.24) * tint)
			ci.draw_line(c + Vector2(-s * 0.7, -s * 0.4), c + Vector2(s * 0.1, s * 0.1), Color(1, 0.8, 0.6, 0.5), 1.0)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.1, 0.07), 1.0)
		"gems":
			var pts2: PackedVector2Array = PackedVector2Array([
				c + Vector2(-s, -s * 0.2), c + Vector2(-s * 0.5, -s), c + Vector2(s * 0.5, -s),
				c + Vector2(s, -s * 0.2), c + Vector2(0, s)])
			ci.draw_colored_polygon(pts2, Color(0.35, 0.85, 0.80) * tint)
			ci.draw_line(c + Vector2(-s, -s * 0.2), c + Vector2(s, -s * 0.2), Color(1, 1, 1, 0.6), 1.0)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.2), c + Vector2(-s * 0.5, -s), Color(1, 1, 1, 0.5), 1.0)
			ci.draw_polyline(pts2 + PackedVector2Array([pts2[0]]), Color(0.05, 0.25, 0.25), 1.0)
		"coolant", "drop":
			var col: Color = (WATER if kind == "drop" else Color(0.45, 0.78, 0.95)) * tint
			var pts3: PackedVector2Array = PackedVector2Array()
			var mid: Vector2 = c + Vector2(0, s * 0.28)
			for i: int in range(0, 15):
				var a: float = -(PI - 0.5) + float(i) * ((PI - 0.5) * 2.0 / 14.0)
				pts3.append(mid + Vector2(sin(a), cos(a)) * s * 0.72)
			pts3.append(c + Vector2(0, -s))
			ci.draw_colored_polygon(pts3, col)
			ci.draw_circle(c + Vector2(-s * 0.25, s * 0.15), s * 0.16, Color(1, 1, 1, 0.55))
		"cells":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.8), Vector2(s * 1.1, s * 1.7)), Color(0.18, 0.2, 0.22), true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s), Vector2(s * 0.5, s * 0.25)), BRASS * tint, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.55), Vector2(s * 0.8, s * 1.25)), CRT * tint, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.8), Vector2(s * 1.1, s * 1.7)), BRASS_DARK, false, 1.0)
		"bits":
			var tip: PackedVector2Array = PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.9), c + Vector2(s * 0.6, -s * 0.9), c + Vector2(0, s)])
			ci.draw_colored_polygon(tip, Color(0.72, 0.76, 0.8) * tint)
			for i: int in range(3):
				var y: float = -s * 0.5 + float(i) * s * 0.5
				var half: float = s * 0.6 * (1.0 - (y + s * 0.9) / (s * 1.9))
				ci.draw_line(c + Vector2(-half, y + s * 0.18), c + Vector2(half, y - s * 0.12), Color(0.2, 0.22, 0.25), 1.2)
		"charges":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.55), Vector2(s * 1.1, s * 1.5)), Color(0.78, 0.2, 0.15) * tint, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.1), Vector2(s * 1.1, s * 0.3)), Color(0.95, 0.85, 0.5), true)
			ci.draw_line(c + Vector2(0, -s * 0.55), c + Vector2(s * 0.35, -s * 0.95), TEXT, 1.2)
			ci.draw_circle(c + Vector2(s * 0.4, -s), 1.6, FIRE)
		"hull":
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.6), Vector2(s * 2.0, s * 1.2)), Color(0.45, 0.5, 0.55) * tint, true)
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.6), Vector2(s * 2.0, s * 1.2)), BRASS, false, 1.2)
			for dx: float in [-0.65, 0.0, 0.65]:
				ci.draw_circle(c + Vector2(s * dx, 0), 1.3, BRASS_LIGHT)
		"crew":
			ci.draw_circle(c + Vector2(0, -s * 0.45), s * 0.38, TEXT * tint)
			var body: PackedVector2Array = PackedVector2Array([
				c + Vector2(-s * 0.75, s * 0.9), c + Vector2(-s * 0.6, s * 0.15), c + Vector2(s * 0.6, s * 0.15), c + Vector2(s * 0.75, s * 0.9)])
			ci.draw_colored_polygon(body, TEXT * tint)
		"warn":
			var tri: PackedVector2Array = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.85), c + Vector2(-s, s * 0.85)])
			ci.draw_colored_polygon(tri, HAZARD * tint)
			ci.draw_line(c + Vector2(0, -s * 0.35), c + Vector2(0, s * 0.3), STEEL_DEEP, 2.0)
			ci.draw_circle(c + Vector2(0, s * 0.6), 1.2, STEEL_DEEP)
		"flame":
			var fl: PackedVector2Array = PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s * 0.55, -s * 0.1), c + Vector2(s * 0.7, s * 0.4), c + Vector2(s * 0.3, s),
				c + Vector2(-s * 0.3, s), c + Vector2(-s * 0.7, s * 0.4), c + Vector2(-s * 0.45, -s * 0.2), c + Vector2(-s * 0.15, s * 0.1)])
			ci.draw_colored_polygon(fl, FIRE * tint)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.1), c + Vector2(s * 0.3, s * 0.6), c + Vector2(0, s * 0.95), c + Vector2(-s * 0.3, s * 0.6)]), Color(1, 0.85, 0.4))
		"shield":
			var sh: PackedVector2Array = PackedVector2Array([
				c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.8, s * 0.1), c + Vector2(0, s), c + Vector2(-s * 0.8, s * 0.1)])
			ci.draw_colored_polygon(sh, CRT * tint)
			ci.draw_polyline(sh + PackedVector2Array([sh[0]]), STEEL_DEEP, 1.2)
		"hammer":
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.8), c + Vector2(s * 0.4, -s * 0.3), BRASS_LIGHT * tint, 2.5)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.9), Vector2(s * 1.0, s * 0.55)), TEXT * tint, true)
		_:
			ci.draw_circle(c, s * 0.6, TEXT * tint)


## 0..1 pulse for alerts, from a time in seconds.
static func pulse(t: float, hz: float = 1.6) -> float:
	return 0.5 + 0.5 * sin(t * TAU * hz)
