class_name CatchUpOverlay
extends Control
## Blocks input while the city catches up. When it is done the newspaper opens.

var _dim: ColorRect
var _panel: GlassPanel
var _box: VBoxContainer
var _bar: ProgressBar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.1, 0.12, 0.2, 0.28)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = GlassPanel.new()
	_panel.content_margin = 24
	_panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_box)
	visible = false
	EventBus.catch_up_started.connect(func(ticks: int) -> void: show_progress(ticks))
	EventBus.catch_up_progressed.connect(func(p: float) -> void:
		if _bar != null:
			_bar.value = p * 100.0)
	EventBus.catch_up_finished.connect(func(s: RefCounted) -> void: show_summary(s as CatchUpSummary))
	if SimRunner.catching_up:
		show_progress(-1)


func show_progress(ticks: int) -> void:
	_clear()
	visible = true
	_box.add_child(_label(tr("UI_CATCHUP_TITLE"), 26, UiTheme.TEXT))
	if ticks > 0:
		_box.add_child(_label(tr("UI_CATCHUP_SUB") % duration(ticks), 17, UiTheme.TEXT_SOFT))
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	_bar.value = SimRunner.catch_up_progress() * 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.ACCENT
	fill.set_corner_radius_all(7)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.45)
	bg.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	_box.add_child(_bar)


## The newspaper (published by TextService on the same signal) tells the story;
## this overlay only covers the wait.
func show_summary(_s: CatchUpSummary) -> void:
	_bar = null
	visible = false


## Ticks -> "2 gün 3 saat" / "4 saat 20 dakika" / "30 dakika".
static func duration(ticks: int) -> String:
	var minutes: int = ticks * SimConfig.TICK_SECONDS / 60
	var days: int = minutes / 1440
	var hours: int = (minutes % 1440) / 60
	var mins: int = minutes % 60
	var parts: PackedStringArray = []
	if days > 0:
		parts.append(TranslationServer.translate("UI_DAYS") % days)
	if hours > 0:
		parts.append(TranslationServer.translate("UI_HOURS") % hours)
	if days == 0 and (mins > 0 or parts.is_empty()):
		parts.append(TranslationServer.translate("UI_MINUTES") % mins)
	return " ".join(parts)


func _label(text: String, size: int, color: Color, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


func _clear() -> void:
	for c: Node in _box.get_children():
		c.queue_free()
