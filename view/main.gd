extends Node
## App entry: hosts the city view and the UI layer.

@onready var _city: CityView = %City
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
	if SimRunner.recovered_from_backup:
		_hud.show_toast(tr("UI_RECOVERED"))
	if OS.is_debug_build():
		_debug_panel.day_night = _city.day_night
	else:
		_debug_panel.queue_free()
