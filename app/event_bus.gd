extends Node
## Global signals only. No logic lives here.

@warning_ignore_start("unused_signal")
signal tick_advanced(tick: int)
signal sim_event_emitted(event: RefCounted)
signal catch_up_started(total_ticks: int)
## 0..1
signal catch_up_progressed(progress: float)
signal catch_up_finished(summary: RefCounted)
## A new or loaded city is ready on SimRunner.sim.
signal city_loaded
## Buildings were added, removed or finished; views should rebuild.
signal city_changed
signal command_rejected(error_key: String)
## A newspaper edition (NewsDesk data) was published; auto_open after an absence.
signal newspaper_published(edition: Dictionary, auto_open: bool)
signal newspaper_closed
signal graphics_quality_changed(quality: int)
signal debug_time_offset_changed(offset_seconds: float)
@warning_ignore_restore("unused_signal")
