class_name EnvironmentSystem
extends RefCounted
## Green coverage and pollution.


static func green_permille(agg: CityAggregates) -> int:
	# One green point per resident counts as fully green.
	if agg.residents_capacity <= 0:
		return SimConfig.PERMILLE if agg.green_total > 0 else 0
	return clampi(agg.green_total * SimConfig.PERMILLE / agg.residents_capacity, 0, SimConfig.PERMILLE)


static func step(state: SimState, agg: CityAggregates, content: ContentDb, mods: Dictionary = {}) -> void:
	state.green = green_permille(agg)
	var traffic_part: int = 0
	for k: String in state.block_traffic:
		traffic_part += int(state.block_traffic[k])
	traffic_part = traffic_part * content.bal_int("environment.pollution_per_trip_permille", 6) / SimConfig.PERMILLE
	var absorb: int = agg.green_total * content.bal_int("environment.green_absorb_permille", 4) / SimConfig.PERMILLE
	var target: int = clampi(agg.pollution_static + traffic_part - absorb + int(mods.get("pollution", 0)), 0, SimConfig.PERMILLE)
	var follow: int = maxi(content.bal_int("environment.follow_divisor", 48), 1)
	var diff: int = target - state.pollution
	var d: int = diff / follow
	state.pollution += signi(diff) if d == 0 and diff != 0 else d
