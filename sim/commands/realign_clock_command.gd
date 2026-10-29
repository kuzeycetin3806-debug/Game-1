class_name RealignClockCommand
extends Command
## Moves the city's calendar anchor (start_unix) without simulating, so sim
## time keeps matching the wall clock. Forward = the city slept through a gap
## longer than the catch-up cap; backward = the device clock was set back a lot.
## Logged like any command, so replays stay exact.

var shift_seconds: int = 0


static func create(p_shift: int) -> RealignClockCommand:
	var c := RealignClockCommand.new()
	c.shift_seconds = p_shift
	return c


func type_name() -> String:
	return "realign_clock"


func validate(_sim: Simulation) -> String:
	if shift_seconds == 0 or shift_seconds % SimConfig.TICK_SECONDS != 0:
		return "ERR_BAD_TIME_SHIFT"
	return ""


func apply(sim: Simulation) -> Array[SimEvent]:
	sim.state.start_unix += shift_seconds
	var ticks: int = shift_seconds / SimConfig.TICK_SECONDS
	var type: String = "city_slept" if shift_seconds > 0 else "clock_rebased"
	return [SimEvent.create(type, sim.state.tick, {"ticks": absi(ticks)})]


func _payload() -> Dictionary:
	return {"shift_seconds": shift_seconds}
