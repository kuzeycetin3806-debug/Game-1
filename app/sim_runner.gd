extends Node
## Owns the Simulation and drives it from the wall clock. The only bridge
## between the pure sim and Godot signals.

## Ticks processed per frame when behind, so the UI never freezes.
## VARSAYIM: M3 adds a proper sliced catch-up screen and the 14-day cap.
const MAX_TICKS_PER_FRAME: int = 48

var sim: Simulation
var content: ContentDb


func _ready() -> void:
	content = ContentDb.load_default()
	if not content.is_valid():
		for e: String in content.errors:
			push_error(e)
	new_city()


## VARSAYIM: until saving lands in M3 every launch starts a new town.
func new_city(city_seed: int = -1) -> void:
	if city_seed < 0:
		city_seed = int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() & 0xFFFF)
	var offset: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	sim = Simulation.new_game(content, city_seed, int(Clock.now_unix()), offset)
	EventBus.city_loaded.emit()


func target_tick() -> int:
	return maxi(int(floorf((Clock.now_unix() - float(sim.state.start_unix)) / SimConfig.TICK_SECONDS)), 0)


func _process(_delta: float) -> void:
	if sim == null:
		return
	var goal: int = target_tick()
	var budget: int = MAX_TICKS_PER_FRAME
	var changed: bool = false
	# A clock that jumps backwards just waits; the city never rewinds.
	while sim.state.tick < goal and budget > 0:
		var events: Array[SimEvent] = sim.step()
		budget -= 1
		for e: SimEvent in events:
			if e.type == "building_completed":
				changed = true
			EventBus.sim_event_emitted.emit(e)
		EventBus.tick_advanced.emit(sim.state.tick)
	if changed:
		EventBus.city_changed.emit()


## Applies a player command now. Returns the sim result dictionary.
func submit(cmd: Command) -> Dictionary:
	var result: Dictionary = sim.apply_command(cmd)
	if result.ok:
		for e: SimEvent in result.events:
			EventBus.sim_event_emitted.emit(e)
		EventBus.city_changed.emit()
	else:
		EventBus.command_rejected.emit(result.error)
	return result


func check(cmd: Command) -> String:
	return sim.can_apply(cmd)
