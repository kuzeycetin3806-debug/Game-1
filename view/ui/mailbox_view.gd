class_name MailboxView
extends Control
## Citizens' letters: an inbox list and a paper-like letter with reply buttons.

const PAPER: Color = Color("#fbf6ea")
const INK: Color = Color("#2b2a33")
const INK_SOFT: Color = Color("#6d6772")
const STAMP: Color = Color("#ff8a5c")

var _list_box: VBoxContainer
var _letter_box: VBoxContainer
var _scroll: ScrollContainer
var _open_id: int = -1
var _close: Button
var _italic: FontVariation
var _bold: FontVariation


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_italic = FontVariation.new()
	_italic.base_font = ThemeDB.fallback_font
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.18, 1), Vector2.ZERO)
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.8
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
	style.shadow_size = 16
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
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(stack)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 10)
	stack.add_child(_list_box)
	_letter_box = VBoxContainer.new()
	_letter_box.add_theme_constant_override("separation", 12)
	stack.add_child(_letter_box)
	_close = Button.new()
	var close: Button = _close
	close.text = tr("UI_BACK_TO_CITY")
	close.custom_minimum_size = Vector2(0, 60)
	close.add_theme_font_size_override("font_size", 21)
	close.pressed.connect(func() -> void:
		if _open_id >= 0:
			show_list()
		else:
			visible = false
			EventBus.mailbox_closed.emit())
	outer.add_child(close)
	EventBus.city_changed.connect(func() -> void:
		if visible:
			_refresh())
	EventBus.letter_text_updated.connect(func(id: int) -> void:
		if visible and id == _open_id:
			show_letter(id))


func open() -> void:
	visible = true
	show_list()


func show_list() -> void:
	_open_id = -1
	_close.text = tr("UI_BACK_TO_CITY")
	_clear(_letter_box)
	_clear(_list_box)
	_list_box.add_child(_label(tr("UI_LETTERS"), 30, INK, _bold, HORIZONTAL_ALIGNMENT_CENTER))
	var letters: Array = (SimRunner.sim.state.letters as Array).duplicate()
	# Open letters first, newest first.
	letters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao: bool = String(a.status) == "open"
		var bo: bool = String(b.status) == "open"
		return ao if ao != bo else int(a.id) > int(b.id))
	if letters.is_empty():
		_list_box.add_child(_label(tr("UI_NO_LETTERS"), 17, INK_SOFT, null, HORIZONTAL_ALIGNMENT_CENTER))
	for raw: Variant in letters:
		var l: Dictionary = raw
		_list_box.add_child(_row(l))
	_scroll.scroll_vertical = 0


func show_letter(id: int) -> void:
	var l: Dictionary = CitizenSystem.letter_by_id(SimRunner.sim.state, id)
	if l.is_empty():
		show_list()
		return
	_open_id = id
	_close.text = tr("UI_BACK")
	_clear(_list_box)
	_clear(_letter_box)
	var page: Dictionary = TextService.letter_page(l)
	_letter_box.add_child(_label(String(page.subject), 24, INK, _bold))
	_letter_box.add_child(_rule())
	_letter_box.add_child(_label(String(page.greeting), 18, INK, _italic))
	_letter_box.add_child(_label(String(page.body), 18, INK))
	if String(page.memory_line) != "":
		_letter_box.add_child(_label(String(page.memory_line), 18, INK))
	_letter_box.add_child(_label(String(page.signoff), 18, INK, _italic))
	_letter_box.add_child(_label(String(page.signature), 16, INK_SOFT))
	_letter_box.add_child(_rule())
	if String(l.status) == "open":
		for raw: Variant in page.options:
			var o: Dictionary = raw
			var b := Button.new()
			b.text = String(o.label)
			b.custom_minimum_size = Vector2(0, 58)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 18)
			var err: String = SimRunner.check(ReplyLetterCommand.create(id, String(o.id)))
			b.disabled = err != ""
			b.pressed.connect(func() -> void:
				if SimRunner.submit(ReplyLetterCommand.create(id, String(o.id))).ok:
					show_letter(id))
			_letter_box.add_child(b)
	else:
		_letter_box.add_child(_label(String(page.status_line), 17, STAMP.darkened(0.2), _italic))
	_scroll.scroll_vertical = 0


func _refresh() -> void:
	if _open_id >= 0:
		show_letter(_open_id)
	else:
		show_list()


func _row(l: Dictionary) -> Control:
	var page: Dictionary = TextService.letter_page(l)
	var b := Button.new()
	var status_key: String = {"open": "UI_LETTER_OPEN", "answered": "UI_LETTER_ANSWERED", "expired": "UI_LETTER_EXPIRED"}.get(String(l.status), "")
	b.text = "%s\n%s · %s" % [String(page.subject), String(page.signature).get_slice("\n", 0), tr(status_key)]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 17)
	if String(l.status) == "open":
		var s := StyleBoxFlat.new()
		s.bg_color = Color(1, 1, 1, 0.9)
		s.border_color = STAMP
		s.set_border_width_all(2)
		s.set_corner_radius_all(14)
		s.content_margin_left = 14
		s.content_margin_right = 14
		b.add_theme_stylebox_override("normal", s)
	var id: int = int(l.id)
	b.pressed.connect(func() -> void: show_letter(id))
	return b


func _label(t: String, size: int, color: Color, font: Font = null, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(INK, 0.3)
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _clear(box: Container) -> void:
	for c: Node in box.get_children():
		c.queue_free()
