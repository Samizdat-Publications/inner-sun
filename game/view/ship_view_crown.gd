class_name ShipViewCrown
extends RefCounted
## Builds the ShipView's drill crown, hull floodlights, sparks, dust and debris, moved out of it to keep
## that file short. The nodes and lights are stored on the ShipView `v`, which drives them.

## The painted drill crown under the whole tower (the teeth glow brighter while cutting), the hull
## floodlights, sparks and dust. Rock lights use light mask 2 (RockView.LIGHT_MASK); the crown parts
## use 3 so those lights shade them too.
const TOP_Y: float = 2.0  ## Crown top below the hull's bottom edge, px: its hub sits under the hull, not over its rail (Stewart, 2026-10-22).


static func build(v: ShipView) -> void:
	var size: Vector2 = v.ship_size_m() * v.ppm
	v._crown = Node2D.new()
	v._crown.position = Vector2(0.0, size.y + TOP_Y)
	v._crown.z_index = 6
	v.add_child(v._crown)
	var tex: Texture2D = ArtLib.lit("ship", "drill_crown")
	var glow_tex: Texture2D = ArtLib.plain("ship", "drill_crown", "emission")
	var crown_h: float = 0.0
	if tex != null:
		var art: Vector2 = tex.get_size()
		var sc: float = size.x / art.x
		crown_h = art.y * sc
		var pieces: int = 4
		var pw: float = art.x / float(pieces)
		for i: int in range(pieces):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.region_enabled = true
			s.region_rect = Rect2(pw * float(i), 0.0, pw, art.y)
			s.scale = Vector2(sc, sc)
			s.position = Vector2(pw * float(i) * sc, 0.0)
			s.light_mask = 3
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			v._crown.add_child(s)
			if glow_tex != null:
				var g := Sprite2D.new()
				g.texture = glow_tex
				g.centered = false
				g.region_enabled = true
				g.region_rect = s.region_rect
				g.scale = s.scale
				g.position = s.position
				g.material = ArtLib.additive_unshaded()
				g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				v._crown.add_child(g)
				v._crown_glow.append(g)
		v._set_crown_glow(0.5)
	var tip_y: float = size.y + TOP_Y + maxf(crown_h, 60.0) - 14.0
	v._crown_light = v._light(Vector2(size.x * 0.5, tip_y - 4.0), Color(1.0, 0.55, 0.22), 0.3, v.ppm * 6.0, false, 110.0)
	v._crown_light.texture = RockView.light_texture(128, 0.0, 0.3, 0.6)
	v._crown_light.texture_scale = v.ppm * 6.0 * 2.0 / 128.0 / 0.4
	v._crown_light.range_item_cull_mask = 2
	v._crown_light.enabled = false
	v._crown_fill = v._light(Vector2(size.x * 0.5, size.y + v.ppm * 0.9), Color(1.0, 0.72, 0.5), 1.1, v.ppm * 5.5, false, 140.0)
	# Hull floodlights: low corners throw down and out, mid-hull ones rake the shaft walls.
	# Warm and soft: no flat core (that read as blown-out plaster), a long gentle falloff.
	var flood_col: Color = ShipView.FLOOD_COLD if v._enemy else ShipView.FLOOD_WARM
	var wide: ImageTexture = RockView.light_texture(128, 0.0, 0.5, 0.3)
	for spec: Vector4 in [Vector4(90.0, size.y - 50.0, 1.05, 11.0), Vector4(size.x - 90.0, size.y - 50.0, 1.05, 11.0),
			Vector4(110.0, size.y * 0.5, 0.7, 9.0), Vector4(size.x - 110.0, size.y * 0.5, 0.7, 9.0)]:
		var fl: PointLight2D = v._light(Vector2(spec.x, spec.y), flood_col, spec.z, v.ppm * spec.w, false, 110.0)
		fl.texture = wide
		fl.texture_scale = v.ppm * spec.w * 2.0 / 128.0 / 0.4
		fl.range_item_cull_mask = 2
		fl.enabled = false
		v._floods.append(fl)
	if not v._enemy:
		# One wide, faint warm fill over the shaft so the rock around the tower is never pitch black.
		var fill: PointLight2D = v._light(Vector2(size.x * 0.5, size.y * 0.8), Color(0.95, 0.82, 0.68), 1.1, v.ppm * 20.0, false, 220.0)
		fill.texture = wide
		fill.texture_scale = v.ppm * 20.0 * 2.0 / 128.0 / 0.4
		fill.range_item_cull_mask = 2
		fill.enabled = false
		v._floods.append(fill)
	var hot := Gradient.new()
	hot.set_color(0, Color(1.7, 1.45, 0.8, 1.0))
	hot.set_color(1, Color(0.8, 0.18, 0.04, 0.0))
	hot.add_point(0.35, Color(1.5, 0.8, 0.25, 0.9))
	v._sparks = CPUParticles2D.new()
	v._sparks.texture = ShipView.radial_texture(12)
	v._sparks.material = ArtLib.additive_unshaded()
	v._sparks.amount = 150
	v._sparks.lifetime = 0.6
	v._sparks.emitting = false
	v._sparks.position = Vector2(size.x * 0.5, tip_y)
	v._sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	v._sparks.emission_rect_extents = Vector2(size.x * 0.46, 3.0)
	v._sparks.direction = Vector2(0, -1)
	v._sparks.spread = 100.0
	v._sparks.gravity = Vector2(0, 1200)
	v._sparks.initial_velocity_min = 140.0
	v._sparks.initial_velocity_max = 520.0
	v._sparks.scale_amount_min = 0.5
	v._sparks.scale_amount_max = 1.5
	v._sparks.color_ramp = hot
	v._sparks.z_index = -6
	v.add_child(v._sparks)
	var puff := Gradient.new()
	puff.set_color(0, Color(0.4, 0.36, 0.32, 0.0))
	puff.set_color(1, Color(0.3, 0.27, 0.24, 0.0))
	puff.add_point(0.25, Color(0.36, 0.32, 0.28, 0.3))
	v._dust = CPUParticles2D.new()
	v._dust.texture = ShipView.radial_texture(48)
	v._dust.material = ArtLib.unshaded()
	v._dust.amount = 56
	v._dust.lifetime = 2.2
	v._dust.emitting = false
	v._dust.position = Vector2(size.x * 0.5, tip_y - 6.0)
	v._dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	v._dust.emission_rect_extents = Vector2(size.x * 0.5, 4.0)
	v._dust.direction = Vector2(0, -1)
	v._dust.spread = 90.0
	v._dust.gravity = Vector2(0, -14)
	v._dust.initial_velocity_min = 25.0
	v._dust.initial_velocity_max = 90.0
	v._dust.scale_amount_min = 3.0
	v._dust.scale_amount_max = 7.0
	v._dust.color_ramp = puff
	v._dust.z_index = -7
	v.add_child(v._dust)
	v._chips = CrownDebris.make_chips(size, tip_y)
	v.add_child(v._chips)
	v._streaks = CrownDebris.make_streaks(size, tip_y)
	v.add_child(v._streaks)
