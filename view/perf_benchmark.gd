class_name PerfBenchmark
extends Control
## In-game performance test for real devices. Shows a dense temporary town
## (the player's city is untouched), measures every graphics quality from far
## and close, then shows a copyable report and a recommended quality.

signal finished(report: String, recommended: int)

const WARMUP_S: float = 1.5
const SAMPLE_S: float = 4.0
const ORBIT_SPEED: float = 0.25 # rad/s, so frames include camera motion

var city: CityView
var _label: Label
var _result: VBoxContainer
var _panel: GlassPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = GlassPanel.new()
	_panel.content_margin = 20
	_panel.custom_minimum_size = Vector2(470, 0)
	center.add_child(_panel)
	_result = VBoxContainer.new()
	_result.add_theme_constant_override("separation", 10)
	_panel.add_child(_result)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_result.add_child(_label)


func run() -> void:
	var quality_names: Array = [tr("UI_QUALITY_LOW"), tr("UI_QUALITY_MEDIUM"), tr("UI_QUALITY_HIGH")]
	var view_names: Dictionary = {"overview": tr("UI_BENCH_VIEW_FAR"), "close": tr("UI_BENCH_VIEW_NEAR")}
	var old_quality: int = Settings.graphics_quality
	var rig: CityCamera = city.camera_rig
	var old_focus: Vector3 = rig.focus
	var old_distance: float = rig.distance
	_label.text = tr("UI_BENCH_PREPARING")
	await get_tree().process_frame
	var s: SimState = SimRunner.sim.state
	var preview: Simulation = BenchmarkCity.build(SimRunner.content, s.start_unix, s.utc_offset_s)
	SimRunner.begin_preview(preview)
	var runs: Array = []
	for q: int in [2, 1, 0]:
		Settings.graphics_quality = q as Settings.Quality # applied, not saved
		for view: String in ["overview", "close"]:
			_label.text = tr("UI_BENCH_RUNNING") % [quality_names[q], view_names[view]]
			Engine.max_fps = 0 # measure what the device can do, not the profile's cap
			if view == "overview":
				rig.snap_to(Vector3.ZERO, 560.0)
			else:
				rig.snap_to(Vector3(-20, 0, -20), 170.0)
			var r: Dictionary = await _measure(rig)
			r.quality = q
			r.view = view
			runs.append(r)
	var device: Dictionary = {
		"model": OS.get_model_name(), "os": "%s %s" % [OS.get_name(), OS.get_version()],
		"gpu": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(),
		"cores": OS.get_processor_count(), "screen": "%dx%d" % [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"buildings": preview.state.buildings.size(),
	}
	var rec: int = BenchmarkReport.recommend(runs)
	var report: String = BenchmarkReport.text(device, runs, rec, quality_names, view_names,
		tr("UI_BENCH_TITLE") % String(ProjectSettings.get_setting("application/config/version", "")), tr("UI_BENCH_RECOMMENDED"))
	# Restore everything exactly as it was.
	Settings.graphics_quality = old_quality as Settings.Quality
	SimRunner.end_preview()
	rig.snap_to(old_focus, old_distance)
	print(report)
	_save_report(report)
	_show_result(report, rec, quality_names)
	finished.emit(report, rec)


func _measure(rig: CityCamera) -> Dictionary:
	var t: float = 0.0
	while t < WARMUP_S:
		await get_tree().process_frame
		t += get_process_delta_time()
		rig.yaw += ORBIT_SPEED * get_process_delta_time()
		rig.set("_target_yaw", rig.yaw)
	var times := PackedFloat32Array()
	t = 0.0
	var draw_calls: int = 0
	var prims: int = 0
	while t < SAMPLE_S:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		t += dt
		times.append(dt)
		rig.yaw += ORBIT_SPEED * dt
		rig.set("_target_yaw", rig.yaw)
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		prims = maxi(prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var st: Dictionary = BenchmarkReport.stats(times)
	st.draw_calls = draw_calls
	st.primitives = prims
	return st


func _save_report(report: String) -> void:
	var f: FileAccess = FileAccess.open("user://perf_report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(report + "\n")
		f.close()


func _show_result(report: String, rec: int, quality_names: Array) -> void:
	_label.text = report
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_font_size_override("font_size", 14)
	var copy := Button.new()
	copy.text = tr("UI_BENCH_COPY")
	copy.custom_minimum_size = Vector2(0, 54)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(report)
		copy.text = tr("UI_BENCH_COPIED"))
	_result.add_child(copy)
	var apply := Button.new()
	apply.text = tr("UI_BENCH_APPLY") % quality_names[rec]
	apply.custom_minimum_size = Vector2(0, 54)
	apply.pressed.connect(func() -> void:
		Settings.set_quality(rec as Settings.Quality)
		queue_free())
	_result.add_child(apply)
	var close := Button.new()
	close.text = tr("UI_CLOSE")
	close.custom_minimum_size = Vector2(0, 54)
	close.pressed.connect(queue_free)
	_result.add_child(close)
