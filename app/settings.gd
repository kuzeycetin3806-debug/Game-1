extends Node
## Player-facing settings, persisted to user://settings.cfg.

enum Quality { LOW, MEDIUM, HIGH }

const SETTINGS_PATH: String = "user://settings.cfg"

var graphics_quality: Quality = Quality.MEDIUM:
	set(value):
		graphics_quality = value
		EventBus.graphics_quality_changed.emit(value)


func _ready() -> void:
	_load()


func set_quality(q: Quality) -> void:
	graphics_quality = q
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		graphics_quality = _default_quality()
		return
	graphics_quality = int(cfg.get_value("graphics", "quality", _default_quality())) as Quality


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.save(SETTINGS_PATH)


func _default_quality() -> Quality:
	# VARSAYIM: mobile starts on MEDIUM, desktop (dev) on HIGH. Auto-detect comes in M6.
	return Quality.MEDIUM if OS.has_feature("mobile") else Quality.HIGH
