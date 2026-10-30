extends Node
## App entry: hosts the city view and the UI layer.

@onready var _city: CityView = %City
@onready var _ui_layer: CanvasLayer = $UI
@onready var _ui_root: Control = %UiRoot
@onready var _hud: Hud = %Hud
@onready var _debug_panel: DebugPanel = %DebugPanel


func _ready() -> void:
	_ui_root.theme = UiTheme.build()
	_hud.bind(_city.build_controller)
	var paper := NewspaperView.new()
	_ui_root.add_child(CatchUpOverlay.new())
	_ui_root.add_child(paper)
	_hud.newspaper = paper
	var mailbox := MailboxView.new()
	_ui_root.add_child(mailbox)
	_hud.mailbox = mailbox
	var settings := SettingsView.new()
	_ui_root.add_child(settings)
	_hud.settings_requested.connect(settings.open)
	if SimRunner.recovered_from_backup:
		_hud.show_toast(tr("UI_RECOVERED"))
	if OS.is_debug_build():
		_debug_panel.day_night = _city.day_night
	else:
		_debug_panel.queue_free()
	# A new language re-creates the UI (every label was built with tr()); the city keeps running.
	EventBus.locale_changed.connect(func(_l: String) -> void: get_tree().reload_current_scene.call_deferred())
	EventBus.ui_scale_changed.connect(func(_s: float) -> void: _apply_ui_scale())
	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_ui_scale()


## Scales the whole UI layer (text and touch targets) while keeping it full-screen.
func _apply_ui_scale() -> void:
	var s: float = Settings.text_scale()
	_ui_layer.scale = Vector2(s, s)
	_ui_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ui_root.position = Vector2.ZERO
	_ui_root.size = get_viewport().get_visible_rect().size / s
