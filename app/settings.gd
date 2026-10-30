extends Node
## Player-facing settings, persisted to user://settings.cfg.

enum Quality { LOW, MEDIUM, HIGH }

const SETTINGS_FILE: String = "settings.cfg"
## VARSAYIM: Turkish is the default language regardless of device locale.
const DEFAULT_LOCALE: String = "tr"
const LOCALES: Array[String] = ["tr", "en"]
## UI scale steps for readability (applied to the whole UI layer, so touch targets grow too).
const TEXT_SCALES: Array[float] = [1.0, 1.15, 1.3]

var locale: String = DEFAULT_LOCALE
## Random per install; identifies the device to the text backend (rate limit). Not personal data.
var device_id: String = ""
var text_scale_index: int = 0
var haptics: bool = true
## Player's choice; the OS permission is asked separately the first time it matters.
var notifications: bool = true
## Set once the automatic quality check ran (it never overrides a manual choice again).
var quality_auto_checked: bool = false

var graphics_quality: Quality = Quality.MEDIUM:
	set(value):
		graphics_quality = value
		EventBus.graphics_quality_changed.emit(value)

var _path: String = "user://" + SETTINGS_FILE


func _ready() -> void:
	# Tests and tools keep their settings next to their scratch saves.
	var dir: String = OS.get_environment("SEHIR_SAVE_DIR")
	if dir != "":
		_path = dir.path_join(SETTINGS_FILE)
	_load()


func set_quality(q: Quality) -> void:
	graphics_quality = q
	quality_auto_checked = true
	_save()


func set_locale(l: String) -> void:
	if not LOCALES.has(l) or l == locale:
		return
	locale = l
	TranslationServer.set_locale(l)
	_save()
	EventBus.locale_changed.emit(l)


func set_text_scale_index(i: int) -> void:
	text_scale_index = clampi(i, 0, TEXT_SCALES.size() - 1)
	_save()
	EventBus.ui_scale_changed.emit(text_scale())


func text_scale() -> float:
	return TEXT_SCALES[text_scale_index]


func set_haptics(on: bool) -> void:
	haptics = on
	_save()


func set_notifications(on: bool) -> void:
	notifications = on
	_save()
	EventBus.notification_settings_changed.emit()


func mark_quality_auto_checked() -> void:
	quality_auto_checked = true
	_save()


## Short buzz for confirmations (placing, replying). No-op on desktop.
func haptic(ms: int = 25) -> void:
	if haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		graphics_quality = _default_quality()
	else:
		graphics_quality = int(cfg.get_value("graphics", "quality", _default_quality())) as Quality
		quality_auto_checked = bool(cfg.get_value("graphics", "auto_checked", false))
		locale = String(cfg.get_value("general", "locale", DEFAULT_LOCALE))
		device_id = String(cfg.get_value("general", "device_id", ""))
		text_scale_index = clampi(int(cfg.get_value("general", "text_scale", 0)), 0, TEXT_SCALES.size() - 1)
		haptics = bool(cfg.get_value("general", "haptics", true))
		notifications = bool(cfg.get_value("general", "notifications", true))
	TranslationServer.set_locale(locale)
	if device_id.length() != 32:
		device_id = Crypto.new().generate_random_bytes(16).hex_encode()
		_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.set_value("graphics", "auto_checked", quality_auto_checked)
	cfg.set_value("general", "locale", locale)
	cfg.set_value("general", "device_id", device_id)
	cfg.set_value("general", "text_scale", text_scale_index)
	cfg.set_value("general", "haptics", haptics)
	cfg.set_value("general", "notifications", notifications)
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	cfg.save(_path)


func _default_quality() -> Quality:
	# Mobile starts on MEDIUM; the first session's FPS check may lower it (PerfWatch).
	return Quality.MEDIUM if OS.has_feature("mobile") else Quality.HIGH
