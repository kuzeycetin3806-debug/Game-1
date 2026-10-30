class_name SettingsView
extends Control
## Settings: language, graphics, text size, haptics, notifications.

var _panel: GlassPanel
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.08, 0.12, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = GlassPanel.new()
	_panel.content_margin = 22
	_panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_panel.add_child(_box)


func open() -> void:
	_build()
	visible = true


func _build() -> void:
	for c: Node in _box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = tr("UI_SETTINGS")
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_choice(tr("UI_LANGUAGE"), ["Türkçe", "English"], Settings.LOCALES.find(Settings.locale), func(i: int) -> void:
		visible = false
		Settings.set_locale(Settings.LOCALES[i]))
	_choice(tr("UI_GRAPHICS"), [tr("UI_QUALITY_LOW"), tr("UI_QUALITY_MEDIUM"), tr("UI_QUALITY_HIGH")], Settings.graphics_quality, func(i: int) -> void:
		Settings.set_quality(i as Settings.Quality)
		_build())
	_choice(tr("UI_TEXT_SIZE"), [tr("UI_TEXT_NORMAL"), tr("UI_TEXT_LARGE"), tr("UI_TEXT_XLARGE")], Settings.text_scale_index, func(i: int) -> void:
		Settings.set_text_scale_index(i)
		_build())
	_choice(tr("UI_HAPTICS"), [tr("UI_ON"), tr("UI_OFF")], 0 if Settings.haptics else 1, func(i: int) -> void:
		Settings.set_haptics(i == 0)
		_build())
	_choice(tr("UI_NOTIFICATIONS"), [tr("UI_ON"), tr("UI_OFF")], 0 if Settings.notifications else 1, func(i: int) -> void:
		Settings.set_notifications(i == 0)
		_build())
	var about := Label.new()
	about.text = tr("UI_ABOUT") % String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	about.add_theme_font_size_override("font_size", 14)
	about.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(about)
	var close := Button.new()
	close.text = tr("UI_CLOSE")
	close.custom_minimum_size = Vector2(0, 58)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: visible = false)
	_box.add_child(close)


func _choice(label: String, options: Array, selected: int, on_pick: Callable) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	_box.add_child(l)
	var row := HBoxContainer.new()
	_box.add_child(row)
	for i: int in options.size():
		var b := Button.new()
		b.text = String(options[i])
		b.toggle_mode = true
		b.button_pressed = i == selected
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		var idx: int = i
		b.pressed.connect(func() -> void: on_pick.call(idx))
		row.add_child(b)
