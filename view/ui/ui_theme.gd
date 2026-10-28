class_name UiTheme
extends RefCounted
## Builds the shared UI theme in code so sizes stay consistent and touch-friendly.

const TEXT: Color = Color("#22303f")
const TEXT_SOFT: Color = Color("#4a5a6b")
const ACCENT: Color = Color("#ff8a5c")
const FONT_SIZE: int = 20
const MIN_TOUCH: Vector2 = Vector2(64, 56)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_stylebox("normal", "Button", _pill(Color(1, 1, 1, 0.55)))
	t.set_stylebox("hover", "Button", _pill(Color(1, 1, 1, 0.7)))
	t.set_stylebox("pressed", "Button", _pill(ACCENT.lerp(Color.WHITE, 0.45)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("separation", "VBoxContainer", 8)
	return t


static func _pill(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(22)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s
