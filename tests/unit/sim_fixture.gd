class_name SimFixture
extends RefCounted
## Shared helpers for sim tests.

const START_UNIX: int = 1_761_609_600 # 2025-10-28 00:00 UTC
const UTC_OFFSET: int = 3 * 3600
const SEED: int = 1234567

static var _content: ContentDb


static func content() -> ContentDb:
	if _content == null:
		_content = ContentDb.load_default()
	return _content


static func new_sim(seed_value: int = SEED) -> Simulation:
	return Simulation.new_game(content(), seed_value, START_UNIX, UTC_OFFSET)


## Empty map (no starting buildings) for isolated system tests.
static func empty_sim(money: int = 1_000_000) -> Simulation:
	var c: ContentDb = content()
	var map: Dictionary = c.map.duplicate(true)
	map.starting_buildings = []
	var db := ContentDb.new()
	db.buildings = c.buildings
	db.building_order = c.building_order
	db.balance = c.balance.duplicate(true)
	db.balance.start_money = money
	db.map = map
	db.weather = c.weather
	db.events = c.events
	db.event_order = c.event_order
	db.policies = c.policies
	db.policy_order = c.policy_order
	db.citizens = c.citizens
	return Simulation.new_game(db, SEED, START_UNIX, UTC_OFFSET)


## Same content but with no random events (isolates systems from stories).
static func quiet_sim() -> Simulation:
	var sim: Simulation = empty_sim()
	var db: ContentDb = sim.content
	var quiet := ContentDb.new()
	quiet.buildings = db.buildings
	quiet.building_order = db.building_order
	quiet.balance = db.balance
	quiet.map = db.map
	quiet.weather = db.weather
	quiet.policies = db.policies
	quiet.policy_order = db.policy_order
	quiet.citizens = db.citizens
	sim.content = quiet
	return sim


static func run(sim: Simulation, ticks: int) -> Array[SimEvent]:
	var all: Array[SimEvent] = []
	for i: int in ticks:
		all.append_array(sim.step())
	return all


static func place(sim: Simulation, def_id: String, cell: Vector2i) -> Dictionary:
	return sim.apply_command(PlaceBuildingCommand.create(def_id, cell))


static func count(events: Array[SimEvent], type: String) -> int:
	var n: int = 0
	for e: SimEvent in events:
		if e.type == type:
			n += 1
	return n
