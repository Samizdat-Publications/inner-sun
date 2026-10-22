class_name CrewWorkFx
extends RefCounted
## The effects of a crew member at work, moved out of CrewSprite to keep that file short: foam from the
## extinguisher, hammer sparks and a welder's spark stream with a hot white spot. The emitters live on
## the CrewSprite `s` (made the first time a job needs them).

## Foam from the extinguisher, hammer sparks and a welder's spark stream with a hot white spot. The
## emitters are made the first time a job needs them and switched off otherwise.
static func apply(s: CrewSprite, working: bool, t: float) -> void:
	var job: String = s.crew.job_kind if working else ""
	var h: float = s.FIGURE_H_ART * s._k
	if job == "extinguish":
		if s._spray == null:
			s._spray = make_spray(s, h)
		s._spray.position = Vector2(s._face * 0.4 * h, -0.55 * h)
		s._spray.direction = Vector2(s._face, -0.12)
		s._spray.emitting = true
	elif s._spray != null:
		s._spray.emitting = false
	if job == "repair" or job == "patch":
		if s._sparks == null:
			s._sparks = make_sparks(s, h)
		s._sparks.position = Vector2(s._face * 0.34 * h, -0.36 * h if job == "repair" else -0.5 * h)
		s._sparks.direction = Vector2(s._face * 0.5, -1.0)
		s._sparks.emitting = job == "repair" or s._hammer_hit(t) > 0.55
	elif s._sparks != null:
		s._sparks.emitting = false
	if job == "repair":
		if s._weld == null:
			s._weld = Sprite2D.new()
			s._weld.texture = ShipView.radial_texture(32)
			s._weld.material = ArtLib.additive_unshaded()
			s._weld.z_index = 2
			s.add_child(s._weld)
		s._weld.visible = true
		s._weld.position = Vector2(s._face * 0.34 * h, -0.36 * h)
		var flick: float = 0.8 + 0.4 * sin(t * 47.0) * sin(t * 31.0)
		var sc: float = s.ppm / 80.0 * 0.55 * flick
		s._weld.scale = Vector2(sc, sc)
		s._weld.modulate = Color(1.8, 2.0, 2.4, 1.0)
	elif s._weld != null:
		s._weld.visible = false


static func make_spray(s: CrewSprite, h: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = ShipView.radial_texture(24)
	p.material = ArtLib.additive_unshaded()
	p.amount = 70
	p.lifetime = 0.55
	p.spread = 14.0
	p.gravity = Vector2(0.0, 90.0)
	p.initial_velocity_min = 0.9 * h
	p.initial_velocity_max = 1.5 * h
	p.scale_amount_min = 0.5 * s.ppm / 80.0
	p.scale_amount_max = 1.1 * s.ppm / 80.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.5, 1.7, 1.9, 0.9))
	ramp.set_color(1, Color(0.7, 0.85, 1.0, 0.0))
	p.color_ramp = ramp
	p.emitting = false
	p.z_index = 2
	s.add_child(p)
	return p


static func make_sparks(s: CrewSprite, h: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = ShipView.radial_texture(8)
	p.material = ArtLib.additive_unshaded()
	p.amount = 30
	p.lifetime = 0.5
	p.spread = 70.0
	p.gravity = Vector2(0.0, 520.0)
	p.initial_velocity_min = 0.7 * h
	p.initial_velocity_max = 1.6 * h
	p.scale_amount_min = 0.5 * s.ppm / 80.0
	p.scale_amount_max = 1.1 * s.ppm / 80.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(2.0, 1.8, 1.1, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	p.color_ramp = ramp
	p.emitting = false
	p.z_index = 2
	s.add_child(p)
	return p
