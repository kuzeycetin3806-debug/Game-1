@tool
class_name GlassPanel
extends PanelContainer
## Frosted-glass container used by every HUD panel.

@export var corner_radius: float = 28.0:
	set(value):
		corner_radius = value
		_sync()
@export var tint: Color = Color(1, 1, 1, 0.28):
	set(value):
		tint = value
		_sync()
@export var content_margin: int = 20

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/glass_panel.gdshader") as Shader
	material = _mat
	var box := StyleBoxEmpty.new()
	box.content_margin_left = content_margin
	box.content_margin_right = content_margin
	box.content_margin_top = content_margin * 0.8
	box.content_margin_bottom = content_margin * 0.8
	add_theme_stylebox_override("panel", box)
	resized.connect(_sync)
	_sync()


func _draw() -> void:
	# The shader needs geometry covering the panel; draw a plain rect for it.
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


func _sync() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("corner_radius", corner_radius)
	_mat.set_shader_parameter("tint", tint)
	queue_redraw()
