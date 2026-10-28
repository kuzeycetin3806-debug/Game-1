class_name DebugPanel
extends Control
## Developer-only overlay: time travel, time-lapse, quality and perf counters.
## Not shown in release builds, so its strings are not translated.

const TIMELAPSE_SPEED: float = 1800.0 # 1 real second = 30 game minutes
const MONTHS: Array[String] = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
const QUALITY_NAMES: Array[String] = ["Düşük", "Orta", "Yüksek"]

var day_night: DayNight

@onready var _time_label: Label = %TimeLabel
@onready var _perf_label: Label = %PerfLabel
@onready var _body: Control = %Body
@onready var _quality_button: Button = %QualityButton
@onready var _timelapse_button: Button = %TimelapseButton

var _timelapse: bool = false
var _perf_accum: float = 0.0


func _ready() -> void:
	%MinusHour.pressed.connect(func() -> void: Clock.debug_offset_seconds -= 3600.0)
	%PlusHour.pressed.connect(func() -> void: Clock.debug_offset_seconds += 3600.0)
	%NowButton.pressed.connect(func() -> void:
		_timelapse = false
		Clock.debug_offset_seconds = 0.0
		_refresh_buttons())
	%PlusDay.pressed.connect(func() -> void: Clock.debug_offset_seconds += 86400.0 * 30.0)
	_timelapse_button.pressed.connect(func() -> void:
		_timelapse = not _timelapse
		_refresh_buttons())
	_quality_button.pressed.connect(func() -> void:
		Settings.set_quality(((Settings.graphics_quality + 1) % 3) as Settings.Quality)
		_refresh_buttons())
	%Header.pressed.connect(func() -> void: _body.visible = not _body.visible)
	_body.visible = false # collapsed by default; tap the clock to open
	_refresh_buttons()


func _process(delta: float) -> void:
	if _timelapse:
		Clock.debug_offset_seconds += delta * TIMELAPSE_SPEED
	var t: Dictionary = Clock.now_local()
	var sun: String = "" if day_night == null else " · güneş %d°" % roundi(day_night.sun_elevation)
	_time_label.text = "%02d:%02d · %d %s%s" % [t.hour, t.minute, t.day, MONTHS[int(t.month) - 1], sun]
	_perf_accum += delta
	if _perf_accum >= 0.5:
		_perf_accum = 0.0
		_perf_label.text = "FPS %d · çağrı %d · üçgen %dk" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		]


func _refresh_buttons() -> void:
	_quality_button.text = "Kalite: %s" % QUALITY_NAMES[Settings.graphics_quality]
	_timelapse_button.text = "Durdur" if _timelapse else "Hızlı akış"
