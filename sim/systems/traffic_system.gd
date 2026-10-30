class_name TrafficSystem
extends RefCounted
## Block-level congestion from a time-of-day demand curve.


## Integer interpolation of [[minute, permille], ...].
static func demand(minute: int, content: ContentDb) -> int:
	var curve: Array = content.bal("traffic.demand_curve", [[0, 500], [1440, 500]])
	for i: int in range(1, curve.size()):
		var a: Array = curve[i - 1]
		var b: Array = curve[i]
		if minute <= int(b[0]):
			var span: int = maxi(int(b[0]) - int(a[0]), 1)
			return int(a[1]) + (int(b[1]) - int(a[1])) * (minute - int(a[0])) / span
	return int((curve[-1] as Array)[1])


static func step(state: SimState, agg: CityAggregates, content: ContentDb, minute: int, mods: Dictionary = {}) -> void:
	var dem: int = maxi(demand(minute, content) * (SimConfig.PERMILLE + int(mods.get("traffic_demand", 0))) / SimConfig.PERMILLE, 0)
	var city_relief: int = clampi(int(mods.get("traffic_relief", 0)), 0, SimConfig.PERMILLE)
	var cap: int = maxi(content.bal_int("traffic.road_capacity_per_tile", 40) * state.road_every * 2, 1)
	var follow: int = maxi(content.bal_int("traffic.follow_divisor", 3), 1)
	var res_fill: int = 0 if agg.residents_capacity == 0 else state.population * SimConfig.PERMILLE / agg.residents_capacity
	var work_fill: int = 0 if agg.jobs_total == 0 else state.employed * SimConfig.PERMILLE / agg.jobs_total
	var keys: Dictionary = {}
	for k: String in agg.block_res_trips:
		keys[k] = true
	for k: String in agg.block_work_trips:
		keys[k] = true
	for k: String in state.block_traffic:
		keys[k] = true
	var sorted_keys: Array = keys.keys()
	sorted_keys.sort()
	var weighted: int = 0
	var weight: int = 0
	var next: Dictionary = {}
	for k: String in sorted_keys:
		var trips: int = int(agg.block_res_trips.get(k, 0)) * res_fill / SimConfig.PERMILLE \
			+ int(agg.block_work_trips.get(k, 0)) * work_fill / SimConfig.PERMILLE
		var load: int = trips * dem / SimConfig.PERMILLE
		load = load * (SimConfig.PERMILLE - int(agg.block_relief.get(k, 0))) / SimConfig.PERMILLE
		load = load * (SimConfig.PERMILLE - city_relief) / SimConfig.PERMILLE
		var target: int = clampi(load * SimConfig.PERMILLE / cap, 0, SimConfig.PERMILLE)
		var cur: int = int(state.block_traffic.get(k, 0))
		var moved: int = cur + _approach(target - cur, follow)
		if moved > 0 or trips > 0:
			next[k] = moved
		weighted += moved * maxi(trips, 1)
		weight += maxi(trips, 1)
	state.block_traffic = next
	state.traffic = 0 if weight == 0 else weighted / weight


static func _approach(diff: int, divisor: int) -> int:
	var d: int = diff / divisor
	return signi(diff) if d == 0 and diff != 0 else d
