class_name SimClockMath
extends RefCounted
## Integer calendar math for the sim (no Time singleton, no floats).

const MONTH_TO_SEASON: Array[int] = [3, 3, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3] # Jan..Dec
enum Season { SPRING, SUMMER, AUTUMN, WINTER }


## Local seconds since epoch for a given tick.
static func local_seconds(start_unix: int, utc_offset_s: int, tick: int) -> int:
	return start_unix + utc_offset_s + tick * SimConfig.TICK_SECONDS


static func minute_of_day(local_s: int) -> int:
	return posmod(local_s, SimConfig.SECONDS_PER_DAY) / 60


static func day_number(local_s: int) -> int:
	# Floor division that also works for negative values (no floats).
	return (local_s - posmod(local_s, SimConfig.SECONDS_PER_DAY)) / SimConfig.SECONDS_PER_DAY


## Days since 1970-01-01 -> {year, month, day}. Howard Hinnant's civil_from_days.
static func civil_from_days(z: int) -> Dictionary:
	z += 719468
	var era: int = (z if z >= 0 else z - 146096) / 146097
	var doe: int = z - era * 146097
	var yoe: int = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y: int = yoe + era * 400
	var doy: int = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: int = (5 * doy + 2) / 153
	var d: int = doy - (153 * mp + 2) / 5 + 1
	var m: int = mp + 3 if mp < 10 else mp - 9
	return {"year": y + (1 if m <= 2 else 0), "month": m, "day": d}


static func season_for_month(month: int) -> int:
	return MONTH_TO_SEASON[clampi(month, 1, 12) - 1]
