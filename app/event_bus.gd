extends Node
## Global signals only. No logic lives here.

@warning_ignore_start("unused_signal")
signal tick_advanced(tick: int)
signal sim_event_emitted(event: RefCounted)
signal catch_up_finished(summary: RefCounted)
signal graphics_quality_changed(quality: int)
signal debug_time_offset_changed(offset_seconds: float)
@warning_ignore_restore("unused_signal")
