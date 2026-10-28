extends Node
## App entry: hosts the city view and the UI layer.

@onready var _city: CityView = %City
@onready var _ui_root: Control = %UiRoot
@onready var _debug_panel: DebugPanel = %DebugPanel


func _ready() -> void:
	_ui_root.theme = UiTheme.build()
	if OS.is_debug_build():
		_debug_panel.day_night = _city.day_night
	else:
		_debug_panel.queue_free()
