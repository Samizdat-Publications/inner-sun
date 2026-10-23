class_name PauseLayer
extends CanvasLayer
## Makes a pause obvious (Stewart, build 6: he did not see the game was paused). Between the world and
## the run screen's HUD layer: a dark, slightly desaturated veil over the world area only (the HUD
## panels draw above it, untouched), and, for a real pause, a large amber "PAUSED: SPACE TO RESUME".
## A held world (the map or the help page open) gets the veil but no big text: those pages say so.
## View only; Main feeds it every frame and it eases on real time, not on the frozen world's clock.

const DIM_AMOUNT: float = 1.0  ## Shader strength at full veil.
const FADE_PER_S: float = 8.0
const TEXT_PAUSED: String = "PAUSED: SPACE TO RESUME"

const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), 0.5 * amount);
	c *= 1.0 - 0.45 * amount;
	COLOR = vec4(c, 1.0);
}
"""

var _veil: ColorRect
var _mat: ShaderMaterial
var _label: Label
var _target: float = 0.0
var _amount: float = 0.0
var _show_text: bool = false


func _init() -> void:
	layer = 5  # Above the world (layer 0), below RunScreen (layer 10).
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat.shader = sh
	_veil = ColorRect.new()
	_veil.position = RunScreen.WORLD_RECT.position
	_veil.size = RunScreen.WORLD_RECT.size
	_veil.material = _mat
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	add_child(_veil)
	_label = Label.new()
	_label.text = TEXT_PAUSED
	_label.position = Vector2(RunScreen.WORLD_RECT.position.x, RunScreen.WORLD_RECT.get_center().y - 36.0)
	_label.size = Vector2(RunScreen.WORLD_RECT.size.x, 72.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 48)
	_label.add_theme_color_override("font_color", UiTheme.AMBER)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 10)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)


## Called by Main every frame: `veil` darkens the world area, `text` adds the big PAUSED line.
func set_state(veil: bool, text: bool) -> void:
	_target = 1.0 if veil else 0.0
	_show_text = text and veil
	_label.visible = _show_text


## Jump to the target at once (tests and the paused still).
func settle() -> void:
	_amount = _target
	_apply()


func is_dimming() -> bool:
	return _target > 0.0


func _process(delta: float) -> void:
	_amount = move_toward(_amount, _target, FADE_PER_S * delta)
	_apply()


func _apply() -> void:
	_veil.visible = _amount > 0.001
	_mat.set_shader_parameter("amount", _amount * DIM_AMOUNT)
