class_name PerfWatch
extends Node
## First-session FPS check: if the device struggles, step graphics down once
## and tell the player. Never runs again after a decision or a manual choice.

const WARMUP_S: float = 4.0
const SAMPLE_S: float = 10.0
const LOW_FPS: float = 45.0

signal quality_lowered

var _elapsed: float = 0.0
var _frames: int = 0
var _sample_time: float = 0.0


## Pure decision, unit tested: new quality or -1 for "keep".
static func decide(avg_fps: float, quality: int) -> int:
	if avg_fps < LOW_FPS and quality > 0:
		return quality - 1
	return -1


func _ready() -> void:
	if Settings.quality_auto_checked:
		set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < WARMUP_S or SimRunner.catching_up:
		return
	_frames += 1
	_sample_time += delta
	if _sample_time < SAMPLE_S:
		return
	var avg: float = _frames / _sample_time
	var q: int = decide(avg, Settings.graphics_quality)
	if q >= 0:
		Settings.set_quality(q as Settings.Quality)
		quality_lowered.emit()
	Settings.mark_quality_auto_checked()
	set_process(false)
