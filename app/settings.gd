extends Node
## Player-facing settings, persisted to user://settings.cfg.

enum Quality { LOW, MEDIUM, HIGH }

const SETTINGS_PATH: String = "user://settings.cfg"
## VARSAYIM: Turkish is the default language regardless of device locale; a
## language picker comes with the M6 settings screen.
const DEFAULT_LOCALE: String = "tr"

var locale: String = DEFAULT_LOCALE

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
	else:
		graphics_quality = int(cfg.get_value("graphics", "quality", _default_quality())) as Quality
		locale = String(cfg.get_value("general", "locale", DEFAULT_LOCALE))
	TranslationServer.set_locale(locale)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.set_value("general", "locale", locale)
	cfg.save(SETTINGS_PATH)


func _default_quality() -> Quality:
	# VARSAYIM: mobile starts on MEDIUM, desktop (dev) on HIGH. Auto-detect comes in M6.
	return Quality.MEDIUM if OS.has_feature("mobile") else Quality.HIGH
