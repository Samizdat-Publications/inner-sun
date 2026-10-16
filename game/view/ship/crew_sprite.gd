class_name CrewSprite
extends Node2D
## One crew member as a painted figure, 1.8 m tall, feet at this node's origin.
## Vasquez and Okafor are cut-out puppets (thigh, shin, upper arm, forearm rotated around the pivots
## from pipeline/manifests/crew_<name>.json in a sine cycle). Lindqvist and the rivals use their four
## painted walk frames. Everyone flips to face the way they move, sways on ladders, leans in while
## working (extinguish, patch, repair), lies down dimmed when dead, and flashes red when HP drops.
## Reads sim state only.

const FIGURE_H_ART: float = 288.0
const STRIDE_M: float = 1.5  ## One full walk cycle covers this much floor.
const FRAME_M: float = 0.38  ## Floor covered per walk frame for the painted frames.
const CLIMB_M: float = 0.55

## Puppet joints in part pixels (second manifest run, the art in game/assets/crew).
## part: [pivot, child]; torso: [pivot, neck, shoulder]; head: [pivot]
const PUPPETS: Dictionary = {
	"vasquez": {
		"head": [Vector2(18.2, 52.0)], "torso": [Vector2(55.6, 107.0), Vector2(40.5, 8.0), Vector2(36.9, 21.9)],
		"upper_arm": [Vector2(14.0, 4.0), Vector2(13.7, 58.0)], "forearm": [Vector2(13.8, 7.0), Vector2(31.9, 105.0)],
		"thigh": [Vector2(21.1, 5.0), Vector2(20.0, 79.0)], "shin": [Vector2(21.6, 7.0), Vector2(21.4, 93.0)],
	},
	"okafor": {
		"head": [Vector2(14.7, 39.0)], "torso": [Vector2(39.5, 131.0), Vector2(22.0, 9.0), Vector2(22.9, 25.9)],
		"upper_arm": [Vector2(16.3, 5.0), Vector2(16.6, 67.0)], "forearm": [Vector2(11.0, 5.0), Vector2(24.8, 76.0)],
		"thigh": [Vector2(13.5, 5.0), Vector2(17.2, 67.0)], "shin": [Vector2(15.5, 5.0), Vector2(18.7, 68.0)],
	},
}
const SHIN_FOOT: Dictionary = {"vasquez": 100.0, "okafor": 74.0}
const WORK_JOBS: PackedStringArray = ["extinguish", "patch", "repair"]
const RECRUIT_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.85, 0.95, 1.1), Color(1.1, 0.95, 0.85), Color(0.95, 1.08, 0.9), Color(1.1, 0.9, 1.05),
]

var crew: CrewMember
var ppm: float = 80.0
var art_id: String = "lindqvist"
var puppet: bool = false
var tint: Color = Color.WHITE
var _body: Node2D
var _sprite: Sprite2D
var _still: Texture2D
var _frames: Array[Texture2D] = []
var _k: float = 0.5
var _face: float = 1.0
var _phase: float = 0.0
var _amp: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _speed: Vector2 = Vector2.ZERO
var _last_hp: float = 100.0
var _flash: float = 0.0
var _joints: Dictionary = {}


## Which painted figure and tint a crew member gets. Enemies use the rivals; recruits borrow a
## figure tinted by a hash of their id.
static func art_for(c: CrewMember, enemy: bool) -> Array:
	if c.id == "vasquez" or c.id == "okafor" or c.id == "lindqvist":
		return [c.id, Color.WHITE]
	if enemy:
		return ["rival_a" if c.index % 2 == 0 else "rival_b", Color.WHITE]
	var h: int = absi(c.id.hash())
	var figures: Array[String] = ["vasquez", "okafor", "lindqvist"]
	return [figures[h % 3], RECRUIT_TINTS[(h / 3) % RECRUIT_TINTS.size()]]


func setup(c: CrewMember, p_ppm: float, enemy: bool) -> void:
	crew = c
	ppm = p_ppm
	_k = ppm / ArtLib.ART_PPM
	var pick: Array = CrewSprite.art_for(c, enemy)
	art_id = str(pick[0])
	tint = pick[1] as Color
	_face = -1.0 if enemy else 1.0
	_last_pos = c.pos
	_last_hp = c.hp
	z_index = 6
	_body = Node2D.new()
	add_child(_body)
	puppet = PUPPETS.has(art_id)
	if puppet:
		_build_puppet()
	else:
		_still = ArtLib.lit("crew/" + art_id, "full")
		for i: int in range(4):
			_frames.append(ArtLib.lit("crew/" + art_id, "walk_%d" % i))
		_sprite = Sprite2D.new()
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_body.add_child(_sprite)
		_show_texture(_still)


func head_top_px() -> float:
	return -FIGURE_H_ART * _k


func _show_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	_sprite.texture = tex
	var sz: Vector2 = tex.get_size()
	_sprite.scale = Vector2(_k, _k)
	_sprite.position = Vector2(-sz.x * 0.5 * _k, -sz.y * _k)


func _part_tex(part: String) -> Texture2D:
	return ArtLib.lit("crew/" + art_id, part)


## One joint node with its sprite hung so the part's pivot sits on the joint.
func _joint(parent: Node2D, part: String, at: Vector2, z: int, shade: float) -> Node2D:
	var j := Node2D.new()
	j.position = at
	j.z_index = z
	parent.add_child(j)
	var tex: Texture2D = _part_tex(part)
	if tex != null:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = -(PUPPETS[art_id][part][0] as Vector2)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.self_modulate = Color(shade, shade, shade, 1.0)
		j.add_child(s)
	return j


func _build_puppet() -> void:
	var d: Dictionary = PUPPETS[art_id]
	var thigh: Array = d["thigh"]
	var shin: Array = d["shin"]
	var torso: Array = d["torso"]
	var head: Array = d["head"]
	var ua: Array = d["upper_arm"]
	var shin_h: float = float(SHIN_FOOT[art_id])
	var leg: float = ((thigh[1] as Vector2).y - (thigh[0] as Vector2).y) + ((shin[1] as Vector2).y - (shin[0] as Vector2).y) + (shin_h - (shin[1] as Vector2).y)
	var total: float = leg + ((torso[0] as Vector2).y - (torso[1] as Vector2).y) + (head[0] as Vector2).y
	var fit: float = FIGURE_H_ART / total * _k
	var root := Node2D.new()
	root.scale = Vector2(fit, fit)
	root.position = Vector2(0.0, -leg * fit)
	_body.add_child(root)
	_joints["root"] = root
	for side: int in range(2):
		var far: bool = side == 0
		var shade: float = 0.62 if far else 1.0
		var leg_j: Node2D = _joint(root, "thigh", Vector2.ZERO, -3 if far else -1, shade)
		var knee: Node2D = _joint(leg_j, "shin", (thigh[1] as Vector2) - (thigh[0] as Vector2), 0, shade)
		_joints["thigh_%d" % side] = leg_j
		_joints["shin_%d" % side] = knee
	var tj: Node2D = _joint(root, "torso", Vector2.ZERO, 0, 1.0)
	_joints["torso"] = tj
	var neck_at: Vector2 = (torso[1] as Vector2) - (torso[0] as Vector2)
	_joints["head"] = _joint(tj, "head", neck_at, 0, 1.0)
	var sh_at: Vector2 = (torso[2] as Vector2) - (torso[0] as Vector2)
	for side: int in range(2):
		var far2: bool = side == 0
		var shade2: float = 0.62 if far2 else 1.0
		var arm: Node2D = _joint(tj, "upper_arm", sh_at, -2 if far2 else 2, shade2)
		var fore: Node2D = _joint(arm, "forearm", (ua[1] as Vector2) - (ua[0] as Vector2), 0, shade2)
		_joints["arm_%d" % side] = arm
		_joints["fore_%d" % side] = fore


func update(delta: float, t: float) -> void:
	var c: CrewMember = crew
	var d: float = maxf(delta, 0.0001)
	var move: Vector2 = c.pos - _last_pos
	_last_pos = c.pos
	_speed = _speed.lerp(move / d, clampf(d * 12.0, 0.0, 1.0))
	if c.hp < _last_hp - 0.01:
		_flash = 0.5
	_last_hp = c.hp
	_flash = maxf(0.0, _flash - delta)
	var flash_c: Color = Color.WHITE.lerp(Color(2.0, 0.3, 0.25), clampf(_flash / 0.5, 0.0, 1.0))
	_body.modulate = tint * flash_c
	if not c.alive:
		_lie_down()
		return
	_body.rotation = 0.0
	_body.position = Vector2.ZERO
	var climbing: bool = c.climbing
	var walking: bool = (not climbing) and absf(_speed.x) > 0.12
	if absf(move.x) > 0.0004 and not climbing:
		_face = 1.0 if move.x > 0.0 else -1.0
	_body.scale = Vector2(_face, 1.0)
	var working: bool = (not climbing) and (not walking) and WORK_JOBS.has(c.job_kind) and c.job_room == c.room
	if climbing:
		_phase += absf(move.y) / CLIMB_M * TAU
		_body.rotation = 0.05 * sin(_phase)
		_body.position.y = -2.0 * absf(sin(_phase * 0.5))
	elif walking:
		_phase += absf(move.x) / (STRIDE_M if puppet else FRAME_M * 4.0) * TAU
	var mode_amp: float = 1.0 if (walking or climbing) else 0.0
	_amp = lerpf(_amp, mode_amp, clampf(d * 9.0, 0.0, 1.0))
	if working:
		_body.rotation = _face * (0.11 + 0.05 * sin(t * 8.0))
	if puppet:
		_pose_puppet(t, climbing, working)
	else:
		_pose_frames(climbing, walking, working, t)


func _lie_down() -> void:
	_body.scale = Vector2(1.0, 1.0)
	_body.rotation = -PI * 0.5 * (1.0 if _face > 0.0 else -1.0)
	_body.position = Vector2(0.0, -0.1 * ppm)
	_body.modulate = Color(0.5, 0.46, 0.46, 1.0)
	if puppet:
		_pose_puppet(0.0, false, false)
	elif _sprite != null:
		_show_texture(_still)


func _pose_frames(climbing: bool, walking: bool, working: bool, t: float) -> void:
	if (walking or climbing) and _frames[0] != null:
		var f: int = int(floorf(_phase / TAU * 4.0)) % 4
		_show_texture(_frames[f])
	else:
		_show_texture(_still)
		if working:
			_body.position.y = -1.5 * absf(sin(t * 8.0))
		else:
			_body.position.y = -0.6 * (0.5 + 0.5 * sin(t * 1.9 + float(crew.index)))


func _pose_puppet(t: float, climbing: bool, working: bool) -> void:
	var s: float = sin(_phase)
	var amp: float = _amp
	for side: int in range(2):
		var sg: float = 1.0 if side == 1 else -1.0
		var thigh: Node2D = _joints["thigh_%d" % side]
		var shin: Node2D = _joints["shin_%d" % side]
		var arm: Node2D = _joints["arm_%d" % side]
		var fore: Node2D = _joints["fore_%d" % side]
		var ph: float = sin(_phase + (0.0 if side == 1 else PI))
		var ph_c: float = cos(_phase + (0.0 if side == 1 else PI))
		if climbing:
			thigh.rotation = lerpf(0.0, -0.8 + 0.7 * ph, amp)
			shin.rotation = lerpf(0.0, 1.0 - 0.5 * ph, amp)
			arm.rotation = lerpf(0.0, -2.5 + 0.5 * -ph, amp)
			fore.rotation = lerpf(0.0, -0.3, amp)
		else:
			thigh.rotation = -0.55 * ph * amp
			shin.rotation = 0.9 * maxf(0.0, ph_c) * amp
			arm.rotation = 0.5 * ph * amp
			fore.rotation = -0.35 * amp * (0.5 + 0.5 * ph)
		if working:
			arm.rotation = -1.25 + 0.2 * sin(t * 9.0 + sg)
			fore.rotation = -0.5 + 0.15 * sin(t * 9.0 + 1.0)
		elif amp < 0.05:
			arm.rotation = 0.04 * sin(t * 1.9 + sg)
			fore.rotation = -0.08
	var torso: Node2D = _joints["torso"]
	torso.scale = Vector2(1.0, 1.0 + 0.008 * sin(t * 2.0 + float(crew.index)))
	torso.position.y = -2.0 * absf(s) * amp
