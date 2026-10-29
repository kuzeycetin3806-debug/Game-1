class_name CatchUp
extends RefCounted
## Decides how to bring a city up to "now". Pure integer math.

const MAX_TICKS: int = 14 * SimConfig.TICKS_PER_DAY # VARSAYIM: 14-day cap (CLAUDE.md §2.2)
## Small backward jumps (DST, NTP, timezone travel) just wait. Bigger ones mean
## the clock was really set back; then the city re-anchors instead of freezing for days.
## VARSAYIM: 6 hours.
const REBASE_THRESHOLD_S: int = 6 * 3600


## Returns {steps: int, shift_seconds: int}. Apply the shift first (as a
## RealignClockCommand), then step `steps` ticks: the simulated span is always
## the most recent one, ending now.
static func plan(tick: int, start_unix: int, now_unix: int, max_ticks: int = MAX_TICKS) -> Dictionary:
	var elapsed: int = now_unix - start_unix
	# Floor division that is correct for negative values too.
	var raw_target: int = (elapsed - posmod(elapsed, SimConfig.TICK_SECONDS)) / SimConfig.TICK_SECONDS
	if raw_target < tick:
		var behind: int = tick - raw_target
		if behind * SimConfig.TICK_SECONDS > REBASE_THRESHOLD_S:
			return {"steps": 0, "shift_seconds": -behind * SimConfig.TICK_SECONDS}
		return {"steps": 0, "shift_seconds": 0}
	var gap: int = raw_target - tick
	if gap > max_ticks:
		return {"steps": max_ticks, "shift_seconds": (gap - max_ticks) * SimConfig.TICK_SECONDS}
	return {"steps": gap, "shift_seconds": 0}
