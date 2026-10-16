class_name CrownDebris
extends RefCounted
## Rock being torn up at the drill crown (critic 004: "I want to see sparks flying, debris, and a
## sense of immense friction"): chips of rock thrown out and down, tumbling, on top of the spark and
## dust emitters ShipView already has, plus a second, heavier spark layer. All view-side particles
## (CPUParticles2D), unshaded, so their colors are the colors on screen after the boost.

static var _chip: ImageTexture


## A small ragged chip: a square with the corners cut, so each particle reads as a rock fragment.
static func chip_texture() -> ImageTexture:
	if _chip == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y: int in range(8):
			for x: int in range(8):
				var cut: bool = (x + y < 2) or (x + (7 - y) < 3) or ((7 - x) + y < 2) or ((7 - x) + (7 - y) < 3)
				var shade: float = 0.75 + 0.25 * float((x * 3 + y * 5) % 4) / 3.0
				img.set_pixel(x, y, Color(shade, shade, shade, 0.0 if cut else 1.0))
		_chip = ImageTexture.create_from_image(img)
	return _chip


## Rock fragments thrown from the crown: dark, warm grey, falling with gravity and spinning.
static func make_chips(size: Vector2, tip_y: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = chip_texture()
	p.material = ArtLib.unshaded()
	p.amount = 46
	p.lifetime = 0.8
	p.emitting = false
	p.position = Vector2(size.x * 0.5, tip_y)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.42, 4.0)
	p.direction = Vector2(0, -1)
	p.spread = 85.0
	p.gravity = Vector2(0, 1250)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 420.0
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 0.9
	p.scale_amount_max = 2.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.58, 0.44, 1.0))
	ramp.set_color(1, Color(0.4, 0.34, 0.28, 0.0))
	ramp.add_point(0.6, Color(0.55, 0.46, 0.36, 0.9))
	p.color_ramp = ramp
	p.z_index = -6
	return p


## A hot streak layer: long fast sparks with a white core, thrown wide off the bit.
static func make_streaks(size: Vector2, tip_y: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = ShipView.radial_texture(10)
	p.material = ArtLib.additive_unshaded()
	p.amount = 60
	p.lifetime = 0.45
	p.emitting = false
	p.position = Vector2(size.x * 0.5, tip_y - 2.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.5, 2.0)
	p.direction = Vector2(0, -1)
	p.spread = 135.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 300.0
	p.initial_velocity_max = 760.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(2.6, 2.3, 1.7, 1.0))
	ramp.set_color(1, Color(1.1, 0.3, 0.06, 0.0))
	p.color_ramp = ramp
	p.z_index = -5
	return p
