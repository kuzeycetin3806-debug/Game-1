class_name AgendaCard
extends GlassPanel
## Shows Agenda.items() once the newspaper is closed; each line is a shortcut.

signal action_requested(action: String)

var _box: VBoxContainer


func _ready() -> void:
	super._ready()
	content_margin = 16
	visible = false
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	EventBus.newspaper_closed.connect(show_agenda)


func show_agenda() -> void:
	var list: Array[Dictionary] = Agenda.items(SimRunner.sim)
	for c: Node in _box.get_children():
		c.queue_free()
	if list.is_empty():
		visible = false
		return
	var head := HBoxContainer.new()
	_box.add_child(head)
	var title := Label.new()
	title.text = tr("AGENDA_TITLE")
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.custom_minimum_size = Vector2(44, 40)
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	for item: Dictionary in list:
		var b := Button.new()
		var args: Array = (item.args as Array).map(func(a: Variant) -> Variant: return tr(String(a)) if a is String and (String(a).begins_with("POL_")) else a)
		b.text = "• " + (tr(String(item.key)) % args if not args.is_empty() else tr(String(item.key)))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.flat = String(item.action) == ""
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 16)
		var action: String = String(item.action)
		b.disabled = action == ""
		b.pressed.connect(func() -> void:
			visible = false
			action_requested.emit(action))
		_box.add_child(b)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
