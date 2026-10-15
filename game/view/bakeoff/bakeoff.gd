class_name Bakeoff
extends Node2D
## Art style bake-off: the same Reactor room and crew member in three styles (PIXEL, PAINTED, BLENDER),
## lit by an identical rig, side by side. Run through tools/bakeoff.py:
##   --bakeoff --out=<dir> [--glow=<preset|k=v,...>] [--boost=<f>] [--only=<frame,frame>]
## Frames: 01_lamp 02_alarm 03_sweep_a/b/c 04_zoom06 05a/b/c_close_<style> 06_noglow_lamp 06_noglow_alarm.
## Prints EMIT lines (screen position of every emission sprite) and BAKEOFF done for the tool.
##
## Assets are loaded at run time (Image.load_from_file) so mipmaps can be forced for the 0.5 scale
## styles; the real game would use import settings instead.

const ROOM_PX: Vector2 = Vector2(320.0, 240.0)   # 4 m x 3 m at 80 px per meter
const GAP_PX: float = 80.0                       # 1 m of rock between rooms
const FLOOR_Y: float = 221.0                     # standing surface inside a room, room-local px
const WALL_PX: float = 12.0
const CANVAS_MOD: Color = Color(0.30, 0.30, 0.34)
const LAMP_POS: Vector2 = Vector2(160.0, 28.0)
const ALARM_POS: Vector2 = Vector2(32.0, 24.0)
const FIRE_POS: Vector2 = Vector2(160.0, 192.0)
const REACTOR_X: float = 200.0
const CREW_X: float = 96.0
const BASE_ZOOM: float = 1.6

var out_dir: String = "user://bakeoff"
var only: PackedStringArray = PackedStringArray()
var glow_spec: String = "game"
var boost: float = 1.0          # emission brightness above 1.0 AFTER the canvas modulate
var env: Environment
var cam: Camera2D
var styles: Array[Dictionary] = [
	{"id": "pixel", "label": "PIXEL", "scale": 2.0, "filter": CanvasItem.TEXTURE_FILTER_NEAREST, "mips": false},
	{"id": "painted", "label": "PAINTED", "scale": 0.5, "filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "mips": true},
	{"id": "blender", "label": "BLENDER", "scale": 0.5, "filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "mips": true},
]
var _lamps: Array[PointLight2D] = []
var _alarms: Array[PointLight2D] = []
var _fires: Array[PointLight2D] = []
var _sweeps: Array[PointLight2D] = []
var _emits: Array[Dictionary] = []   # {node, style, name, size}
var _radial: GradientTexture2D


func _ready() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	for a: String in argv:
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--glow="):
			glow_spec = a.substr(7)
		elif a.begins_with("--boost="):
			boost = a.substr(8).to_float()
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_radial = _radial_texture(256)
	_build_environment()
	var dark := CanvasModulate.new()
	dark.color = CANVAS_MOD
	add_child(dark)
	_build_rock()
	for i: int in range(styles.size()):
		_build_room(i, styles[i])
	cam = Camera2D.new()
	cam.position = Vector2(560.0, 110.0)
	cam.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
	add_child(cam)
	cam.make_current()
	_run_frames.call_deferred()


# ------------------------------------------------------------------ build
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	_apply_glow(glow_spec)
	we.environment = env
	add_child(we)


func _apply_glow(spec: String) -> void:
	# "game" = the settings of game/view/main.gd. "off" disables glow. Otherwise key=value overrides on top of "game".
	env.glow_enabled = spec != "off"
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_scale = 2.0
	env.glow_hdr_luminance_cap = 12.0
	for i: int in range(7):
		env.set_glow_level(i, [0.0, 0.8, 0.4, 0.1, 0.0, 0.0, 0.0][i])
	if spec == "game" or spec == "off":
		return
	for kv: String in spec.split(","):
		var p: PackedStringArray = kv.split("=")
		if p.size() != 2:
			continue
		var v: float = p[1].to_float()
		match p[0]:
			"intensity": env.glow_intensity = v
			"strength": env.glow_strength = v
			"bloom": env.glow_bloom = v
			"threshold": env.glow_hdr_threshold = v
			"scale": env.glow_hdr_scale = v
			"cap": env.glow_hdr_luminance_cap = v
			"blend": env.glow_blend_mode = int(v) as Environment.GlowBlendMode
			"l1": env.set_glow_level(0, v)
			"l2": env.set_glow_level(1, v)
			"l3": env.set_glow_level(2, v)
			"l4": env.set_glow_level(3, v)
			"l5": env.set_glow_level(4, v)
			"l6": env.set_glow_level(5, v)
			"l7": env.set_glow_level(6, v)


static func _radial_texture(size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func _load_tex(path: String, mips: bool) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img: Image = Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	if mips:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _canvas_tex(style_id: String, name: String, mips: bool) -> CanvasTexture:
	var base: String = "res://assets/bakeoff/%s/%s" % [style_id, name]
	var d: Texture2D = _load_tex(base + "_albedo.png", mips)
	if d == null:
		return null
	var ct := CanvasTexture.new()
	ct.diffuse_texture = d
	var n: Texture2D = _load_tex(base + "_normal.png", mips)
	if n != null:
		ct.normal_texture = n
	return ct


func _build_rock() -> void:
	var rock := Sprite2D.new()
	var ct := CanvasTexture.new()
	ct.diffuse_texture = _load_tex("res://assets/test/rock_albedo.png", true)
	ct.normal_texture = _load_tex("res://assets/test/rock_normal.png", true)
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rock.texture = ct
	rock.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rock.region_enabled = true
	rock.region_rect = Rect2(0, 0, 2400, 1400)
	rock.centered = false
	rock.position = Vector2(-600.0, -500.0)
	rock.light_mask = 8
	add_child(rock)


func _sprite(parent: Node2D, tex: Texture2D, pos: Vector2, sc: float, filt: int, mask: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.scale = Vector2(sc, sc)
	s.texture_filter = filt as CanvasItem.TextureFilter
	s.light_mask = mask
	parent.add_child(s)
	return s


func _tex_size(t: CanvasTexture) -> Vector2:
	return t.diffuse_texture.get_size()


func _build_room(i: int, st: Dictionary) -> void:
	var sid: String = str(st["id"])
	var sc: float = float(st["scale"])
	var filt: int = int(st["filter"])
	var mips: bool = bool(st["mips"])
	var mask: int = 1 << i
	var room := Node2D.new()
	room.name = "Room_" + sid
	room.position = Vector2(float(i) * (ROOM_PX.x + GAP_PX), 0.0)
	add_child(room)
	# dark interior backing so a missing style still shows its room
	var back := ColorRect.new()
	back.color = Color(0.05, 0.05, 0.06)
	back.size = ROOM_PX
	back.light_mask = mask
	room.add_child(back)
	var parts: Dictionary = {"room_wall": null, "floor": null, "reactor": null, "lamp": null, "crew": null}
	for k: String in parts.keys():
		parts[k] = _canvas_tex(sid, k, mips)
	var tw: CanvasTexture = parts["room_wall"]
	if tw != null:
		_sprite(room, tw, Vector2.ZERO, sc, filt, mask)
	var tf: CanvasTexture = parts["floor"]
	if tf != null:
		var fh: float = _tex_size(tf).y * sc
		_sprite(room, tf, Vector2(0.0, ROOM_PX.y - fh), sc, filt, mask)
	var tr: CanvasTexture = parts["reactor"]
	if tr != null:
		var sz: Vector2 = _tex_size(tr) * sc
		var pos := Vector2(REACTOR_X - sz.x * 0.5, FLOOR_Y - sz.y)
		_sprite(room, tr, pos, sc, filt, mask)
		_emission(room, sid, "reactor", pos, sc, filt, mips)
	var tc: CanvasTexture = parts["crew"]
	if tc != null:
		var sz2: Vector2 = _tex_size(tc) * sc
		var pos2 := Vector2(CREW_X - sz2.x * 0.5, FLOOR_Y - sz2.y)
		_sprite(room, tc, pos2, sc, filt, mask)
		_emission(room, sid, "crew", pos2, sc, filt, mips)
	var tl: CanvasTexture = parts["lamp"]
	if tl != null:
		var sz3: Vector2 = _tex_size(tl) * sc
		var pos3 := Vector2(LAMP_POS.x - sz3.x * 0.5, 0.0)
		_sprite(room, tl, pos3, sc, filt, mask)
		_emission(room, sid, "lamp", pos3, sc, filt, mips)
	_build_occluders(room, mask)
	_build_lights(room, mask)
	var lab := Label.new()
	lab.text = str(st["label"])
	lab.add_theme_font_size_override("font_size", 18)
	lab.position = Vector2(90.0, -34.0)
	lab.modulate = Color(3.3, 3.3, 3.0)
	lab.light_mask = 0
	room.add_child(lab)
	if tw == null:
		var miss := Label.new()
		miss.text = "NO ASSETS"
		miss.position = Vector2(110.0, 110.0)
		miss.modulate = Color(3.3, 1.2, 1.2)
		miss.light_mask = 0
		room.add_child(miss)


func _emission(room: Node2D, sid: String, name: String, pos: Vector2, sc: float, filt: int, mips: bool) -> void:
	var tex: Texture2D = _load_tex("res://assets/bakeoff/%s/%s_emission.png" % [sid, name], mips)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.scale = Vector2(sc, sc)
	s.texture_filter = filt as CanvasItem.TextureFilter
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	s.light_mask = 0
	s.z_index = 2
	s.set_meta("emit_name", name)
	room.add_child(s)
	_emits.append({"node": s, "style": sid, "name": name, "size": tex.get_size() * sc})
	_set_emit_boost(s, boost)


func _set_emit_boost(s: Sprite2D, b: float) -> void:
	# CanvasModulate multiplies every item, so the item itself must carry boost / modulate to land above 1.0.
	s.modulate = Color(b / CANVAS_MOD.r, b / CANVAS_MOD.g, b / CANVAS_MOD.b, 1.0)


func _build_occluders(room: Node2D, mask: int) -> void:
	var h: float = WALL_PX * 0.5
	var w: float = ROOM_PX.x
	var t: float = ROOM_PX.y
	var rects: Array[Rect2] = [
		Rect2(-h, -h, w + WALL_PX, WALL_PX), Rect2(-h, t - h, w + WALL_PX, WALL_PX),
		Rect2(-h, -h, WALL_PX, t + WALL_PX), Rect2(w - h, -h, WALL_PX, t + WALL_PX)]
	for r: Rect2 in rects:
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
		var occ := LightOccluder2D.new()
		occ.occluder = poly
		occ.occluder_light_mask = mask
		room.add_child(occ)


func _light(room: Node2D, mask: int, at: Vector2, color: Color, energy: float, radius_px: float, height: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _radial
	l.texture_scale = radius_px * 2.0 / float(_radial.width)
	l.position = at
	l.color = color
	l.energy = energy
	l.height = height
	l.shadow_enabled = true
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_color = Color(0, 0, 0, 0.85)
	l.range_item_cull_mask = mask
	l.shadow_item_cull_mask = mask
	room.add_child(l)
	return l


func _build_lights(room: Node2D, mask: int) -> void:
	_lamps.append(_light(room, mask, LAMP_POS, Color(1.0, 0.86, 0.66), 1.25, ROOM_PX.x * 0.9, 220.0))
	_alarms.append(_light(room, mask, ALARM_POS, Color(1.0, 0.1, 0.06), 0.0, ROOM_PX.x * 0.9, 160.0))
	_fires.append(_light(room, mask, FIRE_POS, Color(1.0, 0.48, 0.16), 0.0, ROOM_PX.x * 0.95, 140.0))
	_sweeps.append(_light(room, mask, Vector2(160.0, 130.0), Color(1, 1, 1), 0.0, ROOM_PX.x * 0.9, 180.0))


# ------------------------------------------------------------------ states and capture
func _state(lamp: float, alarm: float, fire: float, sweep: float, sweep_at: Vector2 = Vector2(160.0, 130.0)) -> void:
	for i: int in range(styles.size()):
		_lamps[i].energy = lamp
		_lamps[i].enabled = lamp > 0.0
		_alarms[i].energy = alarm
		_alarms[i].enabled = alarm > 0.0
		_fires[i].energy = fire
		_fires[i].enabled = fire > 0.0
		_sweeps[i].energy = sweep
		_sweeps[i].enabled = sweep > 0.0
		_sweeps[i].position = sweep_at


func _focus(pos: Vector2, zoom: float) -> void:
	cam.position = pos
	cam.zoom = Vector2(zoom, zoom)


func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)


func _snap(n: String) -> void:
	for _i: int in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out_dir.path_join(n + ".png"))
	print("SHOT %s %dx%d err=%d" % [n, img.get_width(), img.get_height(), err])
	_print_emits(n)


func _print_emits(n: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	for e: Dictionary in _emits:
		var node: Sprite2D = e["node"]
		var sz: Vector2 = e["size"]
		var c: Vector2 = node.global_position + sz * 0.5
		var sp: Vector2 = (c - cam.position) * cam.zoom.x + vp * 0.5
		print("EMIT %s %s %s %.0f %.0f %.0f %.0f" % [n, e["style"], e["name"], sp.x, sp.y, sz.x * cam.zoom.x, sz.y * cam.zoom.x])


func _run_frames() -> void:
	var centre := Vector2(560.0, 110.0)
	if _want("01_lamp"):
		_state(1.25, 0.0, 0.0, 0.0)
		await _snap("01_lamp")
	if _want("02_alarm"):
		_state(0.4, 2.2, 1.8, 0.0)
		await _snap("02_alarm")
	var orbit: Array[Vector2] = [Vector2(42.0, 109.0), Vector2(160.0, 12.0), Vector2(278.0, 109.0)]
	var names: Array[String] = ["03_sweep_a", "03_sweep_b", "03_sweep_c"]
	for k: int in range(3):
		if _want(names[k]):
			_state(0.0, 0.0, 0.0, 2.0, orbit[k])
			await _snap(names[k])
	if _want("04_zoom06"):
		_state(1.25, 0.0, 0.0, 0.0)
		_focus(centre, 0.6)
		await _snap("04_zoom06")
	for i: int in range(styles.size()):
		var nm: String = "05%s_close_%s" % [char(97 + i), str(styles[i]["id"])]
		if _want(nm):
			_state(1.25, 0.0, 0.0, 0.0)
			_focus(Vector2(float(i) * (ROOM_PX.x + GAP_PX) + 148.0, 150.0), 2.6)
			await _snap(nm)
	_focus(centre, BASE_ZOOM)
	if _want("06_noglow_lamp"):
		env.glow_enabled = false
		_state(1.25, 0.0, 0.0, 0.0)
		await _snap("06_noglow_lamp")
	if _want("06_noglow_alarm"):
		env.glow_enabled = false
		_state(0.4, 2.2, 1.8, 0.0)
		await _snap("06_noglow_alarm")
	print("BAKEOFF done renderer %s" % RenderingServer.get_video_adapter_name())
	get_tree().quit(0)
