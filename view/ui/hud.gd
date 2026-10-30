class_name Hud
extends Control
## In-game HUD: stats bar on top, a context bar at the bottom (build button,
## placement confirm, building info) and the build drawer. Built in code because
## most of it is data-driven (one card per building definition).

const CATEGORIES: Array[String] = ["all", "residential", "commercial", "office", "park", "transit"]
const TOAST_SECONDS: float = 2.6

var controller: BuildController

var _money: Label
var _pop: Label
var _happy: Label
var _traffic: Label
var _bottom: GlassPanel
var _bottom_box: VBoxContainer
var _drawer: GlassPanel
var _cards: HBoxContainer
var _category: String = "all"
var _toast: GlassPanel
var _toast_label: Label
var _toast_time: float = 0.0
var _stats_accum: float = 0.0
var _place_info: Label
var _policies: PoliciesPanel
var _paper_button: Button
var _paper_dot: Control
## Set by main: the newspaper overlay the "Gazete" button opens.
var newspaper: NewspaperView


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_stats_bar()
	_build_drawer()
	_build_bottom_bar()
	_build_toast()
	_build_policies()
	EventBus.sim_event_emitted.connect(_on_sim_event)
	EventBus.command_rejected.connect(func(key: String) -> void: show_toast(tr(key)))
	EventBus.city_changed.connect(_refresh_cards)
	EventBus.newspaper_published.connect(func(_e: Dictionary, _a: bool) -> void: _refresh_paper_dot())
	EventBus.newspaper_closed.connect(_refresh_paper_dot)


func bind(p_controller: BuildController) -> void:
	controller = p_controller
	controller.mode_changed.connect(_on_mode_changed)
	controller.placement_updated.connect(_on_placement_updated)
	controller.selection_changed.connect(func(_id: int) -> void: _show_selected())
	_on_mode_changed(controller.mode)


func _process(delta: float) -> void:
	_stats_accum += delta
	if _stats_accum >= 0.25:
		_stats_accum = 0.0
		_refresh_stats()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		_toast.visible = _toast_time > 0.0


func open_drawer() -> void:
	_drawer.visible = true
	_refresh_cards()


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_time = TOAST_SECONDS


# --- Layout --------------------------------------------------------------------

func _build_stats_bar() -> void:
	var panel := GlassPanel.new()
	panel.content_margin = 14
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = 12
	add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	_money = _stat(row, "UI_MONEY")
	_pop = _stat(row, "UI_POPULATION")
	_happy = _stat(row, "UI_HAPPINESS")
	_traffic = _stat(row, "UI_TRAFFIC")


func _stat(parent: Container, caption_key: String) -> Label:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var cap := Label.new()
	cap.text = tr(caption_key)
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var val := Label.new()
	val.add_theme_font_size_override("font_size", 21)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(val)
	return val


func _build_bottom_bar() -> void:
	_bottom = GlassPanel.new()
	_bottom.content_margin = 16
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_left = 12
	_bottom.offset_right = -12
	_bottom.offset_bottom = -16
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_bottom)
	_bottom_box = VBoxContainer.new()
	_bottom.add_child(_bottom_box)


func _build_drawer() -> void:
	_drawer = GlassPanel.new()
	_drawer.content_margin = 14
	_drawer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_drawer.offset_left = 12
	_drawer.offset_right = -12
	_drawer.offset_bottom = -112
	_drawer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_drawer.visible = false
	add_child(_drawer)
	var v := VBoxContainer.new()
	_drawer.add_child(v)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tabs_scroll.custom_minimum_size = Vector2(0, 52)
	v.add_child(tabs_scroll)
	var tabs := HBoxContainer.new()
	tabs_scroll.add_child(tabs)
	for cat: String in CATEGORIES:
		var b := Button.new()
		b.text = tr("UI_CAT_" + cat.to_upper())
		b.toggle_mode = true
		b.button_pressed = cat == _category
		b.custom_minimum_size = Vector2(76, 46)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func() -> void:
			_category = cat
			for other: Node in tabs.get_children():
				(other as Button).button_pressed = other == b
			_refresh_cards())
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size = Vector2(0, 176)
	v.add_child(scroll)
	_cards = HBoxContainer.new()
	scroll.add_child(_cards)


func _build_toast() -> void:
	_toast = GlassPanel.new()
	_toast.content_margin = 14
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 120
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)


# --- Content -------------------------------------------------------------------

func _refresh_stats() -> void:
	var sim: Simulation = SimRunner.sim
	if sim == null:
		return
	var s: SimState = sim.state
	_money.text = UiFormat.money(s.money_cents / SimConfig.CENTS)
	_money.add_theme_color_override("font_color", Color("#c2543c") if s.money_cents < 0 else UiTheme.TEXT)
	_pop.text = UiFormat.thousands(s.population)
	_happy.text = UiFormat.percent(s.happiness)
	_traffic.text = UiFormat.percent(s.traffic)


func _refresh_cards() -> void:
	if not _drawer.visible:
		return
	for c: Node in _cards.get_children():
		c.queue_free()
	var sim: Simulation = SimRunner.sim
	for id: String in sorted_building_ids(sim.content):
		var def: BuildingDef = sim.content.get_building(id)
		if _category != "all" and def.category != _category:
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 168)
		card.clip_text = false
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 16)
		var lines: PackedStringArray = [tr(def.name_key), UiFormat.money(def.cost)]
		if def.residents > 0:
			lines.append(tr("UI_RESIDENTS") % def.residents)
		if def.jobs > 0:
			lines.append(tr("UI_JOBS") % def.jobs)
		lines.append(tr("UI_BUILD_TIME") % def.build_hours)
		card.text = "\n".join(lines)
		card.tooltip_text = tr(def.desc_key)
		card.disabled = sim.state.money_cents < def.cost * SimConfig.CENTS
		card.pressed.connect(func() -> void:
			_drawer.visible = false
			controller.start_placing(id))
		_cards.add_child(card)


## Category order of the tabs, then cheapest first.
static func sorted_building_ids(content: ContentDb) -> Array[String]:
	var ids: Array[String] = content.building_order.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: BuildingDef = content.get_building(a)
		var db: BuildingDef = content.get_building(b)
		var ca: int = CATEGORIES.find(da.category)
		var cb: int = CATEGORIES.find(db.category)
		return ca < cb if ca != cb else (da.cost < db.cost if da.cost != db.cost else a < b))
	return ids


func _clear_bottom() -> void:
	for c: Node in _bottom_box.get_children():
		c.queue_free()
	_place_info = null


func _on_mode_changed(mode: BuildController.Mode) -> void:
	match mode:
		BuildController.Mode.IDLE:
			_show_idle()
		BuildController.Mode.PLACING:
			_show_placing()
		BuildController.Mode.SELECTED:
			_show_selected()


func _show_idle() -> void:
	_clear_bottom()
	var row := HBoxContainer.new()
	_bottom_box.add_child(row)
	_paper_button = _side_button(tr("UI_NEWSPAPER"))
	_paper_button.pressed.connect(func() -> void:
		_drawer.visible = false
		_policies.visible = false
		if newspaper != null:
			newspaper.open_latest())
	row.add_child(_paper_button)
	_paper_dot = ColorRect.new()
	(_paper_dot as ColorRect).color = UiTheme.ACCENT
	_paper_dot.custom_minimum_size = Vector2(12, 12)
	_paper_dot.position = Vector2(8, 8)
	_paper_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper_button.add_child(_paper_dot)
	var build := _big_button(tr("UI_BUILD"), true)
	build.size_flags_stretch_ratio = 1.6
	build.pressed.connect(func() -> void:
		_policies.visible = false
		_drawer.visible = not _drawer.visible
		_refresh_cards())
	row.add_child(build)
	var decisions := _side_button(tr("UI_DECISIONS"))
	decisions.pressed.connect(func() -> void:
		_drawer.visible = false
		_policies.visible = not _policies.visible)
	row.add_child(decisions)
	_refresh_paper_dot()


func _side_button(text: String) -> Button:
	var b := _big_button(text, false)
	b.add_theme_font_size_override("font_size", 17)
	return b


func _refresh_paper_dot() -> void:
	if _paper_dot != null and is_instance_valid(_paper_dot):
		_paper_dot.visible = TextService.has_unread()


func _build_policies() -> void:
	_policies = PoliciesPanel.new()
	_policies.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_policies.offset_left = 12
	_policies.offset_right = -12
	_policies.offset_bottom = -112
	_policies.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_policies.visible = false
	add_child(_policies)


func _show_placing() -> void:
	_clear_bottom()
	_drawer.visible = false
	_policies.visible = false
	_place_info = Label.new()
	_place_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bottom_box.add_child(_place_info)
	var row := HBoxContainer.new()
	_bottom_box.add_child(row)
	var cancel := _big_button(tr("UI_CANCEL"), false)
	cancel.pressed.connect(func() -> void: controller.cancel())
	row.add_child(cancel)
	var place := _big_button(tr("UI_PLACE"), true)
	place.name = "PlaceButton"
	place.pressed.connect(func() -> void: controller.confirm_placement())
	row.add_child(place)


func _on_placement_updated(def: BuildingDef, _origin: Vector2i, error_key: String) -> void:
	if _place_info == null:
		return
	var hint: String = tr("UI_PLACE_HINT") if error_key == "" else tr(error_key)
	_place_info.text = "%s · %s\n%s" % [tr(def.name_key), UiFormat.money(def.cost), hint]
	_place_info.add_theme_color_override("font_color", UiTheme.TEXT if error_key == "" else Color("#c2543c"))
	var place: Button = _bottom_box.find_child("PlaceButton", true, false) as Button
	if place != null:
		place.disabled = error_key != ""


func _show_selected() -> void:
	_clear_bottom()
	_drawer.visible = false
	var sim: Simulation = SimRunner.sim
	var b: BuildingInstance = sim.state.building_by_id(controller.selected_id)
	if b == null:
		return
	var def: BuildingDef = sim.content.get_building(b.def_id)
	var title := Label.new()
	title.text = tr(def.name_key)
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_box.add_child(title)
	var info := Label.new()
	var parts: PackedStringArray = []
	if b.is_complete(sim.state.tick):
		parts.append(tr("UI_COMPLETED"))
	else:
		parts.append(tr("UI_UNDER_CONSTRUCTION") % roundi(BuildingVisuals.construction_progress(b, sim.state.tick) * 100.0))
	if def.residents > 0:
		parts.append(tr("UI_RESIDENTS") % def.residents)
	if def.jobs > 0:
		parts.append(tr("UI_JOBS") % def.jobs)
	info.text = " · ".join(parts) + "\n" + tr(def.desc_key)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	_bottom_box.add_child(info)
	var row := HBoxContainer.new()
	_bottom_box.add_child(row)
	var close := _big_button(tr("UI_CLOSE"), false)
	close.pressed.connect(func() -> void: controller.cancel())
	row.add_child(close)
	var refund: int = def.cost * sim.content.bal_int("demolish_refund_permille", 300) / SimConfig.PERMILLE
	var demolish := _big_button(tr("UI_DEMOLISH") % UiFormat.money(refund), false)
	demolish.pressed.connect(func() -> void: controller.demolish_selected())
	row.add_child(demolish)


func _big_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	if primary:
		var s := StyleBoxFlat.new()
		s.bg_color = UiTheme.ACCENT
		s.set_corner_radius_all(26)
		b.add_theme_stylebox_override("normal", s)
		var sh: StyleBoxFlat = s.duplicate()
		sh.bg_color = UiTheme.ACCENT.lightened(0.1)
		b.add_theme_stylebox_override("hover", sh)
		var sd: StyleBoxFlat = s.duplicate()
		sd.bg_color = UiTheme.ACCENT.lerp(Color.WHITE, 0.55)
		b.add_theme_stylebox_override("disabled", sd)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	return b


func _on_sim_event(e: RefCounted) -> void:
	var ev: SimEvent = e as SimEvent
	match ev.type:
		"building_completed":
			var def: BuildingDef = SimRunner.content.get_building(String(ev.data.def))
			show_toast(tr("EVT_BUILDING_COMPLETED") % tr(def.name_key))
		"building_placed":
			var def2: BuildingDef = SimRunner.content.get_building(String(ev.data.def))
			show_toast(tr("EVT_BUILDING_PLACED") % tr(def2.name_key))
		"population_milestone":
			show_toast(tr("EVT_POPULATION_MILESTONE") % UiFormat.thousands(int(ev.data.population)))
		"traffic_jam":
			show_toast(tr("EVT_TRAFFIC_JAM"))
		"policy_took_effect":
			var pol: Dictionary = SimRunner.content.policies.get(String(ev.data.policy), {})
			if not pol.is_empty():
				show_toast(tr("EVT_POLICY_TOOK_EFFECT") % tr(String(pol.name_key)))
		"story":
			# Live stories: a short teaser; the full text waits for tomorrow's paper.
			var t: Dictionary = TextService.writer().story_text({"key": "story." + String(ev.data.id), "count": 1, "vars": {"district": String(ev.data.get("district", ""))}}, int(ev.data.seq))
			show_toast(String(t.title))
