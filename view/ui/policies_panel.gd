class_name PoliciesPanel
extends GlassPanel
## City decisions: enact or repeal policies. Effects start after a delay, so the
## card shows when a pending policy will kick in.

const TICKS_PER_HOUR: int = 6

var _list: VBoxContainer


func _ready() -> void:
	super._ready()
	content_margin = 16
	var v := VBoxContainer.new()
	add_child(v)
	var title := Label.new()
	title.text = tr("UI_DECISIONS")
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size = Vector2(0, 420)
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	EventBus.city_changed.connect(refresh)
	EventBus.tick_advanced.connect(func(_t: int) -> void:
		if visible:
			refresh())
	visibility_changed.connect(func() -> void:
		if visible:
			refresh())


func refresh() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var sim: Simulation = SimRunner.sim
	for id: String in sim.content.policy_order:
		_list.add_child(_card(sim, id))


## "Yürürlükte" / "12 saat sonra etkili" / "" for a policy's current state.
static func status_text(sim: Simulation, id: String) -> String:
	if not sim.state.policies.has(id):
		return ""
	var p: Dictionary = sim.state.policies[id]
	var left: int = int(p.active_from) - sim.state.tick
	if left <= 0:
		return TranslationServer.translate("UI_POLICY_ACTIVE")
	return TranslationServer.translate("UI_POLICY_PENDING") % CatchUpOverlay.duration(left)


func _card(sim: Simulation, id: String) -> Control:
	var def: Dictionary = sim.content.policies[id]
	var active: bool = sim.state.policies.has(id)
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.62 if active else 0.42)
	s.set_corner_radius_all(16)
	s.border_color = UiTheme.ACCENT if active else Color(1, 1, 1, 0.0)
	s.set_border_width_all(2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var name := Label.new()
	name.text = tr(String(def.name_key))
	name.add_theme_font_size_override("font_size", 19)
	v.add_child(name)
	var desc := Label.new()
	desc.text = tr(String(def.desc_key))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	v.add_child(desc)
	var cost := Label.new()
	cost.text = tr("UI_POLICY_COST") % [UiFormat.money(int(def.setup_cost)), UiFormat.money(int(def.cost_per_day))]
	cost.add_theme_font_size_override("font_size", 14)
	v.add_child(cost)
	var row := HBoxContainer.new()
	v.add_child(row)
	var st := Label.new()
	st.text = status_text(sim, id) if active else tr("UI_POLICY_DELAY") % CatchUpOverlay.duration(int(def.delay_hours) * TICKS_PER_HOUR)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_theme_font_size_override("font_size", 14)
	st.add_theme_color_override("font_color", UiTheme.ACCENT.darkened(0.25) if active else UiTheme.TEXT_SOFT)
	row.add_child(st)
	var b := Button.new()
	b.text = tr("UI_REPEAL") if active else tr("UI_ENACT")
	b.custom_minimum_size = Vector2(120, 52)
	var err: String = SimRunner.check(ChoosePolicyCommand.create(id, not active))
	b.disabled = err != ""
	b.tooltip_text = tr(err) if err != "" else ""
	b.pressed.connect(func() -> void:
		SimRunner.submit(ChoosePolicyCommand.create(id, not active))
		refresh())
	row.add_child(b)
	return panel
