extends GutTest

var _saved: Dictionary


func before_each() -> void:
	_saved = {"locale": Settings.locale, "scale": Settings.text_scale_index, "haptics": Settings.haptics, "notif": Settings.notifications}


func after_each() -> void:
	Settings.set_locale(_saved.locale)
	Settings.set_text_scale_index(_saved.scale)
	Settings.set_haptics(_saved.haptics)
	Settings.set_notifications(_saved.notif)


func test_locale_switch_translates_and_signals() -> void:
	watch_signals(EventBus)
	Settings.set_locale("en")
	assert_eq(tr("UI_BUILD"), "Build")
	assert_signal_emitted(EventBus, "locale_changed")
	Settings.set_locale("tr")
	assert_eq(tr("UI_BUILD"), "İnşa et")


func test_unknown_locale_ignored() -> void:
	var before: String = Settings.locale
	Settings.set_locale("xx")
	assert_eq(Settings.locale, before)


func test_settings_persist() -> void:
	Settings.set_text_scale_index(2)
	Settings.set_haptics(false)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(Settings._path), OK)
	assert_eq(int(cfg.get_value("general", "text_scale")), 2)
	assert_false(bool(cfg.get_value("general", "haptics")))
	assert_true(Settings._path.begins_with(OS.get_environment("SEHIR_SAVE_DIR")), "tests never touch the real settings")


func test_ui_scale_keeps_ui_full_screen() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_process_frames(2)
	Settings.set_text_scale_index(2)
	await wait_process_frames(1)
	var root: Control = main.get_node("%UiRoot")
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	assert_almost_eq(root.size.x * 1.3, vp.x, 1.0)
	assert_almost_eq((main.get_node("UI") as CanvasLayer).scale.x, 1.3, 0.001)
