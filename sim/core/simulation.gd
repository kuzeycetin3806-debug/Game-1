class_name Simulation
extends RefCounted
## Deterministic city simulation. Live play and offline catch-up both call
## step(); commands are applied between steps and stamped with the tick.

enum Stream { POPULATION = 1, EVENTS = 2, CITIZENS = 3 }

var state: SimState
var content: ContentDb
var grid: CityGrid
var aggregates: CityAggregates
var command_log: Array[Command] = []
var event_log: EventLog = EventLog.new()

var _aggregates_dirty: bool = true


static func create(p_state: SimState, p_content: ContentDb) -> Simulation:
	var sim := Simulation.new()
	sim.state = p_state
	sim.content = p_content
	sim.mark_buildings_changed()
	return sim


## Fresh city from the map's starting layout. start_unix is snapped to a tick boundary.
static func new_game(p_content: ContentDb, city_seed: int, start_unix: int, utc_offset_s: int) -> Simulation:
	var s := SimState.new()
	s.city_seed = city_seed & SimRng.MASK32
	s.start_unix = start_unix - posmod(start_unix, SimConfig.TICK_SECONDS)
	s.utc_offset_s = utc_offset_s
	s.grid_size = int(p_content.map.get("grid_size", 32))
	s.road_every = int(p_content.map.get("road_every", 6))
	s.money_cents = p_content.bal_int("start_money") * SimConfig.CENTS
	for raw: Variant in p_content.map.get("starting_buildings", []):
		var sb: Dictionary = raw
		var cell: Array = sb.cell
		s.buildings.append(BuildingInstance.create(s.next_building_id, String(sb.def), Vector2i(int(cell[0]), int(cell[1])), -1, 0))
		s.next_building_id += 1
	var sim: Simulation = create(s, p_content)
	# Start the town already lived-in so the first session is not empty.
	sim._refresh_aggregates()
	sim._settle_initial_mood()
	return sim


## Rebuilds a city from its seed and command history (save verification, tests).
static func replay(p_content: ContentDb, city_seed: int, start_unix: int, utc_offset_s: int, commands: Array[Command], until_tick: int) -> Simulation:
	var sim: Simulation = new_game(p_content, city_seed, start_unix, utc_offset_s)
	var i: int = 0
	while true:
		while i < commands.size() and commands[i].tick == sim.state.tick:
			var copy: Command = Command.from_dict(commands[i].to_dict())
			var result: Dictionary = sim.apply_command(copy)
			assert(result.ok, "replay diverged at tick %d: %s" % [sim.state.tick, result.error])
			i += 1
		if sim.state.tick >= until_tick:
			break
		sim.step()
	return sim


## Independent deep copy (state, history, events) for background catch-up.
func clone() -> Simulation:
	var copy: Simulation = create(SimState.from_dict(state.to_dict()), content)
	for c: Command in command_log:
		copy.command_log.append(Command.from_dict(c.to_dict()))
	copy.event_log = EventLog.from_array(event_log.to_array())
	copy.event_log.capacity = event_log.capacity
	return copy


## Re-runs this city from its seed and command history and compares hashes.
## Slow for old cities (every tick is simulated again); used by tools/verify_save.gd.
func verify_replay() -> bool:
	var origin: int = state.start_unix
	for c: Command in command_log:
		if c is RealignClockCommand:
			origin -= (c as RealignClockCommand).shift_seconds
	var re: Simulation = replay(content, state.city_seed, origin, state.utc_offset_s, command_log, state.tick)
	return re.state.hash() == state.hash()


func mark_buildings_changed() -> void:
	grid = CityGrid.build(state, content)
	_aggregates_dirty = true


## Validates and applies a player command at the current tick.
## Returns {ok: bool, error: String, events: Array[SimEvent]}.
func apply_command(cmd: Command) -> Dictionary:
	cmd.tick = state.tick
	var err: String = cmd.validate(self)
	if err != "":
		return {"ok": false, "error": err, "events": [] as Array[SimEvent]}
	var events: Array[SimEvent] = cmd.apply(self)
	command_log.append(cmd)
	event_log.append_all(events)
	return {"ok": true, "error": "", "events": events}


func can_apply(cmd: Command) -> String:
	return cmd.validate(self)


## Advances one tick and returns the events it produced.
func step() -> Array[SimEvent]:
	var t: int = state.tick
	var events: Array[SimEvent] = []
	var local_s: int = SimClockMath.local_seconds(state.start_unix, state.utc_offset_s, t)
	var minute: int = SimClockMath.minute_of_day(local_s)

	_complete_construction(t, events)
	if _aggregates_dirty:
		_refresh_aggregates()

	var prev_pop: int = state.population
	PopulationSystem.step(state, aggregates, content, SimRng.for_tick(state.city_seed, t, Stream.POPULATION))
	EconomySystem.step(state, aggregates, content)
	TrafficSystem.step(state, aggregates, content, minute)
	EnvironmentSystem.step(state, aggregates, content)
	HappinessSystem.step(state, aggregates, content)

	_check_milestones(t, prev_pop, events)
	_check_traffic(t, events)
	state.tick = t + 1
	_check_day_boundary(t, local_s, events)
	event_log.append_all(events)
	return events


## Local time of the start of the current tick, for UI.
func local_seconds_now() -> int:
	return SimClockMath.local_seconds(state.start_unix, state.utc_offset_s, state.tick)


## Converges population, jobs and mood for the starting town without running
## ticks, so the first session shows a believable, steady city.
func _settle_initial_mood() -> void:
	var workforce_pm: int = content.bal_int("workforce_permille", 600)
	state.green = EnvironmentSystem.green_permille(aggregates)
	state.pollution = clampi(aggregates.pollution_static - aggregates.green_total * content.bal_int("environment.green_absorb_permille", 4) / SimConfig.PERMILLE, 0, SimConfig.PERMILLE)
	for i: int in 8:
		state.population = PopulationSystem.target(aggregates.residents_capacity, state.happiness, content)
		state.employed = mini(state.population * workforce_pm / SimConfig.PERMILLE, aggregates.jobs_total)
		state.happiness = HappinessSystem.target(state, aggregates, content)


func _refresh_aggregates() -> void:
	aggregates = CityAggregates.compute(state, content, grid)
	_aggregates_dirty = false


func _complete_construction(t: int, events: Array[SimEvent]) -> void:
	for b: BuildingInstance in state.buildings:
		if b.ready_tick == t and b.placed_tick >= 0:
			events.append(SimEvent.create("building_completed", t, {"building_id": b.id, "def": b.def_id, "cell": [b.cell.x, b.cell.y]}))
			_aggregates_dirty = true


func _check_milestones(t: int, prev_pop: int, events: Array[SimEvent]) -> void:
	var ms: Array = content.bal("milestones", [])
	while state.milestone_index < ms.size() and state.population >= int(ms[state.milestone_index]):
		if prev_pop < int(ms[state.milestone_index]):
			events.append(SimEvent.create("population_milestone", t, {"population": int(ms[state.milestone_index])}))
		state.milestone_index += 1


func _check_traffic(t: int, events: Array[SimEvent]) -> void:
	# Hysteresis so a jam hovering at the threshold is reported once.
	if not state.traffic_jam_active and state.traffic >= 750:
		state.traffic_jam_active = true
		var worst: String = ""
		var worst_v: int = -1
		var keys: Array = state.block_traffic.keys()
		keys.sort()
		for k: String in keys:
			if int(state.block_traffic[k]) > worst_v:
				worst_v = int(state.block_traffic[k])
				worst = k
		events.append(SimEvent.create("traffic_jam", t, {"traffic": state.traffic, "block": worst}))
	elif state.traffic_jam_active and state.traffic < 600:
		state.traffic_jam_active = false


func _check_day_boundary(t: int, local_s: int, events: Array[SimEvent]) -> void:
	var next_local: int = local_s + SimConfig.TICK_SECONDS
	if SimClockMath.day_number(next_local) == SimClockMath.day_number(local_s):
		return
	var date: Dictionary = SimClockMath.civil_from_days(SimClockMath.day_number(next_local))
	events.append(SimEvent.create("day_started", t + 1, {
		"year": date.year, "month": date.month, "day": date.day,
		"income": state.day_income_cents / SimConfig.CENTS, "expense": state.day_expense_cents / SimConfig.CENTS,
		"population": state.population, "happiness": state.happiness, "money": state.money_cents / SimConfig.CENTS,
	}))
	state.day_income_cents = 0
	state.day_expense_cents = 0
