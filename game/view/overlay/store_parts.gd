class_name StoreParts
extends RefCounted
## Small widget factories for the store form (StoreView), kept apart so the form stays readable.
## Static only; every widget ignores the mouse unless it is a button.

const SECTION_NAMES: Dictionary = {"supplies": "Supplies", "systems": "Systems", "gear": "Gear", "weapons": "Weapons",
	"crew": "Crew", "sell": "Sell"}


static func label(s: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", UiTheme.typewriter())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func mono_label(s: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"PaperButton"
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(UiTheme.INK, 0.55)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func dotted() -> Control:
	var r := ColorRect.new()
	r.color = Color(UiTheme.INK, 0.18)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A section heading on the form: the name in red caps over a thin rule.
static func section_header(section: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: String = str(SECTION_NAMES.get(section, section.capitalize()))
	var l: Label = label(title.to_upper(), 15, UiTheme.INK_RED)
	box.add_child(l)
	var r := ColorRect.new()
	r.color = Color(UiTheme.INK_RED, 0.45)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)
	return box


## A price with its currency icon, right-aligned in a fixed width.
static func price_box(amount: int, currency: String, short: bool, width: float, font_size: int) -> Control:
	var price := HBoxContainer.new()
	price.custom_minimum_size = Vector2(width, 0)
	price.alignment = BoxContainer.ALIGNMENT_END
	price.add_theme_constant_override("separation", 6)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_child(label("%d" % amount, font_size, UiTheme.INK_RED if short else UiTheme.INK))
	price.add_child(CurrencyIcon.new().with_kind(currency, float(font_size)))
	return price


## A currency icon as a Control (gems or ore), so it sits in a container row.
class CurrencyIcon extends Control:
	var kind: String = "gems"
	var px: float = 24.0

	func with_kind(k: String, p: float) -> CurrencyIcon:
		kind = k
		px = p
		custom_minimum_size = Vector2(p, p)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return self

	func _draw() -> void:
		UiTheme.icon(self, kind, Vector2(px, px) * 0.5, px * 0.85)
