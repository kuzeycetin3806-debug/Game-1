class_name CatchUpOverlay
extends Control
## Blocks input while the city catches up, then shows "while you were away".
## The newspaper (M4) will replace the summary card; this is its raw preview.

const MAX_HIGHLIGHTS: int = 4
## Short absences with nothing notable skip the card entirely.
const TRIVIAL_TICKS: int = 6

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


func show_summary(s: CatchUpSummary) -> void:
	_bar = null
	if s.away_ticks() <= TRIVIAL_TICKS and s.highlights.is_empty():
		visible = false
		return
	_clear()
	visible = true
	_box.add_child(_label(tr("UI_AWAY_TITLE"), 28, UiTheme.TEXT))
	_box.add_child(_label(tr("UI_AWAY_TIME") % duration(s.away_ticks()), 17, UiTheme.TEXT_SOFT))
	if s.slept_ticks > 0:
		_box.add_child(_label(tr("UI_AWAY_SLEPT") % duration(s.slept_ticks), 15, UiTheme.TEXT_SOFT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	_box.add_child(grid)
	_row(grid, tr("UI_POPULATION"), signed(s.delta("population")))
	_row(grid, tr("UI_MONEY"), signed_money(s.delta("money")))
	_row(grid, tr("UI_HAPPINESS"), signed_points(s.delta("happiness")))
	_row(grid, tr("UI_TRAFFIC"), signed_points(s.delta("traffic")))
	var shown: int = 0
	for e: SimEvent in s.highlights:
		var line: String = highlight_text(e)
		if line == "":
			continue
		_box.add_child(_label("• " + line, 17, UiTheme.TEXT))
		shown += 1
		if shown >= MAX_HIGHLIGHTS:
			break
	if shown == 0:
		_box.add_child(_label(tr("UI_NOTHING_MAJOR"), 17, UiTheme.TEXT_SOFT))
	var ok := Button.new()
	ok.text = tr("UI_BACK_TO_CITY")
	ok.custom_minimum_size = Vector2(0, 60)
	ok.add_theme_font_size_override("font_size", 22)
	ok.pressed.connect(func() -> void: visible = false)
	_box.add_child(ok)


static func highlight_text(e: SimEvent) -> String:
	match e.type:
		"building_completed":
			var def: BuildingDef = SimRunner.content.get_building(String(e.data.def))
			return TranslationServer.translate("EVT_BUILDING_COMPLETED") % TranslationServer.translate(def.name_key) if def != null else ""
		"population_milestone":
			return TranslationServer.translate("EVT_POPULATION_MILESTONE") % UiFormat.thousands(int(e.data.population))
		"traffic_jam":
			return TranslationServer.translate("EVT_TRAFFIC_JAM")
		"clock_rebased":
			return TranslationServer.translate("EVT_CLOCK_REBASED")
	return ""


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


static func signed(n: int) -> String:
	return ("+" if n > 0 else "") + UiFormat.thousands(n)


static func signed_money(n: int) -> String:
	return ("+" if n > 0 else "") + UiFormat.money(n)


## Permille change shown as percentage points: +2.
static func signed_points(permille: int) -> String:
	var p: int = roundi(permille / 10.0)
	return ("+" if p > 0 else "") + str(p)


func _row(grid: GridContainer, caption: String, value: String) -> void:
	var c: Label = _label(caption, 17, UiTheme.TEXT_SOFT, false)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grid.add_child(c)
	var v: Label = _label(value, 19, UiTheme.TEXT, false)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)


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
