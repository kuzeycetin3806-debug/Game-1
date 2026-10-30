class_name NewspaperView
extends Control
## Full-screen newspaper. Opens by itself after an absence; reopened from the
## HUD. Renders editions through TextService, so the archive follows the language.

const PAPER: Color = Color("#f7f1e3")
const INK: Color = Color("#2a2622")
const INK_SOFT: Color = Color("#6b625a")
const RULE: Color = Color("#2a2622", 0.55)
const UP: Color = Color("#3f8f5a")
const DOWN: Color = Color("#c2543c")
const WEATHER_ICONS: Dictionary = {"clear": "☀", "cloudy": "☁", "rain": "☂", "storm": "⚡", "fog": "≋", "snow": "❄"}

var _index: int = -1
var _scroll: ScrollContainer
var _col: VBoxContainer
var _prev: Button
var _next: Button
var _bold: FontVariation


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.9
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.08, 0.12, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 18
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 14
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 12
	paper.offset_right = -12
	paper.offset_top = 24
	paper.offset_bottom = -16
	var outer := VBoxContainer.new()
	paper.add_child(outer)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 10)
	_scroll.add_child(_col)
	var bar := HBoxContainer.new()
	outer.add_child(bar)
	_prev = _nav_button("‹", func() -> void: show_edition(_index - 1))
	bar.add_child(_prev)
	var close := Button.new()
	close.text = tr("UI_BACK_TO_CITY")
	close.custom_minimum_size = Vector2(0, 60)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.add_theme_font_size_override("font_size", 21)
	close.pressed.connect(close_paper)
	bar.add_child(close)
	_next = _nav_button("›", func() -> void: show_edition(_index + 1))
	bar.add_child(_next)
	EventBus.newspaper_published.connect(func(_ed: Dictionary, auto_open: bool) -> void:
		if auto_open:
			open_latest())


func open_latest() -> void:
	show_edition(TextService.archive().size() - 1)


func show_edition(i: int) -> void:
	var archive: Array = TextService.archive()
	if archive.is_empty():
		return
	_index = clampi(i, 0, archive.size() - 1)
	_build(TextService.render(archive[_index]))
	_prev.disabled = _index <= 0
	_next.disabled = _index >= archive.size() - 1
	if _index == archive.size() - 1:
		TextService.mark_read()
	_scroll.scroll_vertical = 0
	if not visible:
		visible = true
		modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.25)


func close_paper() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void: visible = false)
	EventBus.newspaper_closed.emit()


func _build(page: Dictionary) -> void:
	for c: Node in _col.get_children():
		c.queue_free()
	_col.add_child(_text(String(page.masthead), 34, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	_col.add_child(_text(String(page.tagline), 14, INK_SOFT, false, HORIZONTAL_ALIGNMENT_CENTER))
	_col.add_child(_rule(3))
	_col.add_child(_text(String(page.edition_line), 14, INK_SOFT, false, HORIZONTAL_ALIGNMENT_CENTER))
	_col.add_child(_rule(1))
	var head: Dictionary = page.headline
	_col.add_child(_text(String(head.title), 27, INK, true))
	_col.add_child(_text(String(head.body), 17, INK))
	_col.add_child(_boxes(page))
	var stories: Array = page.stories
	if not stories.is_empty():
		_col.add_child(_rule(1))
		_col.add_child(_text(String(page.section_more).to_upper(), 13, INK_SOFT, true))
	for raw: Variant in stories:
		var st: Dictionary = raw
		_col.add_child(_text(String(st.title), 20, INK, true))
		_col.add_child(_text(String(st.body), 16, INK))
		_col.add_child(_rule(1))


func _boxes(page: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var nums := _box(String(page.section_numbers))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	for raw: Variant in page.numbers:
		var n: Dictionary = raw
		grid.add_child(_text(String(n.label), 13, INK_SOFT, false, HORIZONTAL_ALIGNMENT_LEFT, false))
		grid.add_child(_text(String(n.value), 14, INK, true, HORIZONTAL_ALIGNMENT_RIGHT, false))
		var d: String = String(n.delta)
		var col: Color = UP if d.begins_with("+") else (DOWN if d.begins_with("-") else INK_SOFT)
		if String(n.key) == "traffic":
			col = DOWN if d.begins_with("+") else (UP if d.begins_with("-") else INK_SOFT) # more traffic is bad news
		grid.add_child(_text(d, 13, col, false, HORIZONTAL_ALIGNMENT_RIGHT, false))
	nums.get_child(0).add_child(grid)
	nums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nums.size_flags_stretch_ratio = 1.4
	row.add_child(nums)
	var w: Dictionary = page.weather
	var wbox := _box(String(page.section_weather))
	var wv: VBoxContainer = wbox.get_child(0)
	wv.add_child(_text("%s %s" % [WEATHER_ICONS.get(String(w.now_weather), ""), String(w.now)], 15, INK, true, HORIZONTAL_ALIGNMENT_LEFT, false))
	for raw: Variant in w.forecast:
		var f: Dictionary = raw
		wv.add_child(_text("%s  %s %s" % [String(f.label), WEATHER_ICONS.get(String(f.weather), ""), String(f.text)], 13, INK_SOFT, false, HORIZONTAL_ALIGNMENT_LEFT, false))
	wbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(wbox)
	return row


func _box(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(INK, 0.05)
	s.border_color = Color(INK, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(_text(title.to_upper(), 12, INK_SOFT, true, HORIZONTAL_ALIGNMENT_LEFT, false))
	return p


func _text(t: String, size: int, color: Color, bold: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _rule(px: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = RULE
	r.custom_minimum_size = Vector2(0, px)
	return r


func _nav_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 60)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	return b
