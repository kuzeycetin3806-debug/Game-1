class_name SimState
extends RefCounted
## The complete, serializable state of a city. Everything that affects the
## future lives here; caches (grid, aggregates) are rebuilt from it.

var city_seed: int = 0
var start_unix: int = 0 # wall time of tick 0, aligned to a tick boundary
var utc_offset_s: int = 0 # VARSAYIM: fixed at city creation; later timezone changes are ignored
var tick: int = 0 # number of completed steps
var grid_size: int = 32
var road_every: int = 6

var money_cents: int = 0
var buildings: Array[BuildingInstance] = []
var next_building_id: int = 1

var population: int = 0
var employed: int = 0
var happiness: int = 500 # permille
var traffic: int = 0 # permille, city-wide
var pollution: int = 0 # permille
var green: int = 0 # permille
var block_traffic: Dictionary = {} # "bx,bz" -> permille

var income_frac: int = 0 # sub-cent remainders, keeps per-tick money exact
var expense_frac: int = 0
var day_income_cents: int = 0
var day_expense_cents: int = 0
var milestone_index: int = 0 # how many population milestones are passed
var traffic_jam_active: bool = false


func building_by_id(id: int) -> BuildingInstance:
	for b: BuildingInstance in buildings:
		if b.id == id:
			return b
	return null


func to_dict() -> Dictionary:
	var bs: Array = []
	for b: BuildingInstance in buildings:
		bs.append(b.to_dict())
	return {
		"city_seed": city_seed, "start_unix": start_unix, "utc_offset_s": utc_offset_s, "tick": tick,
		"grid_size": grid_size, "road_every": road_every,
		"money_cents": money_cents, "buildings": bs, "next_building_id": next_building_id,
		"population": population, "employed": employed, "happiness": happiness, "traffic": traffic,
		"pollution": pollution, "green": green, "block_traffic": block_traffic.duplicate(),
		"income_frac": income_frac, "expense_frac": expense_frac,
		"day_income_cents": day_income_cents, "day_expense_cents": day_expense_cents,
		"milestone_index": milestone_index, "traffic_jam_active": traffic_jam_active,
	}


static func from_dict(d: Dictionary) -> SimState:
	var s := SimState.new()
	s.city_seed = int(d.city_seed)
	s.start_unix = int(d.start_unix)
	s.utc_offset_s = int(d.utc_offset_s)
	s.tick = int(d.tick)
	s.grid_size = int(d.grid_size)
	s.road_every = int(d.road_every)
	s.money_cents = int(d.money_cents)
	for raw: Variant in d.buildings:
		s.buildings.append(BuildingInstance.from_dict(raw as Dictionary))
	s.next_building_id = int(d.next_building_id)
	s.population = int(d.population)
	s.employed = int(d.employed)
	s.happiness = int(d.happiness)
	s.traffic = int(d.traffic)
	s.pollution = int(d.pollution)
	s.green = int(d.green)
	for k: Variant in (d.block_traffic as Dictionary):
		s.block_traffic[String(k)] = int((d.block_traffic as Dictionary)[k])
	s.income_frac = int(d.income_frac)
	s.expense_frac = int(d.expense_frac)
	s.day_income_cents = int(d.day_income_cents)
	s.day_expense_cents = int(d.day_expense_cents)
	s.milestone_index = int(d.milestone_index)
	s.traffic_jam_active = bool(d.traffic_jam_active)
	return s


## Stable 32-bit fingerprint of the full state (sorted-key JSON, FNV-1a).
func hash() -> int:
	return SimRng.hash_bytes(JSON.stringify(to_dict(), "", true).to_utf8_buffer())
