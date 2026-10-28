class_name CityAggregates
extends RefCounted
## Static totals derived from completed buildings. Recomputed only when the set
## of completed buildings changes, so per-tick systems stay O(blocks).

var residents_capacity: int = 0
var jobs_total: int = 0
var commercial_jobs: int = 0
var green_total: int = 0
var pollution_static: int = 0
var upkeep_per_day: int = 0 # lira
## Residents-weighted average of nearby amenity happiness (permille, uncapped).
var amenity: int = 0
var block_res_trips: Dictionary = {} # block key -> trips from homes
var block_work_trips: Dictionary = {} # block key -> trips from workplaces
var block_relief: Dictionary = {} # block key -> traffic relief permille (best transit nearby)


static func compute(state: SimState, content: ContentDb, grid: CityGrid) -> CityAggregates:
	var a := CityAggregates.new()
	var complete: Array[BuildingInstance] = []
	for b: BuildingInstance in state.buildings:
		var def: BuildingDef = content.get_building(b.def_id)
		# Upkeep starts on placement (construction crews cost money too).
		a.upkeep_per_day += def.upkeep_per_day
		if b.is_complete(state.tick):
			complete.append(b)
	var amenity_sum: int = 0
	for b: BuildingInstance in complete:
		var def: BuildingDef = content.get_building(b.def_id)
		a.residents_capacity += def.residents
		a.jobs_total += def.jobs
		if def.category == "commercial":
			a.commercial_jobs += def.jobs
		a.green_total += def.green
		a.pollution_static += def.pollution
		var key: String = grid.block_key(b.cell)
		if def.residents > 0:
			a.block_res_trips[key] = int(a.block_res_trips.get(key, 0)) + def.traffic
			amenity_sum += def.residents * _amenity_at(b, def, complete, content)
		elif def.traffic > 0:
			a.block_work_trips[key] = int(a.block_work_trips.get(key, 0)) + def.traffic
		if def.traffic_relief > 0:
			_spread_relief(a, b, def, grid)
	if a.residents_capacity > 0:
		a.amenity = amenity_sum / a.residents_capacity
	return a


## Sum of happiness effects whose radius reaches this home (Chebyshev distance in cells).
static func _amenity_at(home: BuildingInstance, home_def: BuildingDef, all: Array[BuildingInstance], content: ContentDb) -> int:
	var total: int = 0
	for o: BuildingInstance in all:
		var def: BuildingDef = content.get_building(o.def_id)
		if def.happiness == 0:
			continue
		var reach: int = def.radius + (home_def.size + def.size) / 2
		var d: Vector2i = (o.cell - home.cell).abs()
		if maxi(d.x, d.y) <= reach:
			total += def.happiness
	return total


static func _spread_relief(a: CityAggregates, b: BuildingInstance, def: BuildingDef, grid: CityGrid) -> void:
	var r_blocks: int = (def.radius + grid.road_every - 1) / grid.road_every
	var center: Vector2i = grid.block_of(b.cell)
	for bx: int in range(center.x - r_blocks, center.x + r_blocks + 1):
		for bz: int in range(center.y - r_blocks, center.y + r_blocks + 1):
			var key: String = "%d,%d" % [bx, bz]
			a.block_relief[key] = maxi(int(a.block_relief.get(key, 0)), def.traffic_relief)
