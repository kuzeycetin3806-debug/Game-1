extends Node
## Wall-clock abstraction. Everything that needs "now" asks Clock, so tests and
## the debug panel can shift or freeze time without touching the system clock.

## Seconds added to the system clock (debug time travel). Never saved.
var debug_offset_seconds: float = 0.0:
	set(value):
		debug_offset_seconds = value
		EventBus.debug_time_offset_changed.emit(value)

## When >= 0, time is frozen at this unix timestamp (tests).
var frozen_unix_time: float = -1.0


func now_unix() -> float:
	if frozen_unix_time >= 0.0:
		return frozen_unix_time
	return Time.get_unix_time_from_system() + debug_offset_seconds


## Local wall time as a dictionary (year, month, day, hour, minute, second).
func now_local() -> Dictionary:
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_dict_from_unix_time(int(now_unix()) + bias_seconds)


## Local hour as a float in [0, 24).
func local_hour_float() -> float:
	var t: Dictionary = now_local()
	var frac: float = now_unix() - floorf(now_unix())
	return float(t.hour) + float(t.minute) / 60.0 + (float(t.second) + frac) / 3600.0


## Day of year in [1, 366], from local time.
func local_day_of_year() -> int:
	var t: Dictionary = now_local()
	var jan1: int = Time.get_unix_time_from_datetime_dict({"year": t.year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var today: int = Time.get_unix_time_from_datetime_dict({"year": t.year, "month": t.month, "day": t.day, "hour": 0, "minute": 0, "second": 0})
	return int((today - jan1) / 86400) + 1
