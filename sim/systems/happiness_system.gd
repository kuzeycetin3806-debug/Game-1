class_name HappinessSystem
extends RefCounted
## City mood drifts slowly towards what the city offers. Slow on purpose:
## decisions should be felt over days, not minutes.


static func target(state: SimState, agg: CityAggregates, content: ContentDb) -> int:
	var h: int = content.bal_int("happiness.base", 520)
	h += mini(agg.amenity, content.bal_int("happiness.amenity_cap", 220))
	h += content.bal_int("happiness.green_bonus", 160) * state.green / SimConfig.PERMILLE
	h -= content.bal_int("happiness.unemployment_penalty", 260) * PopulationSystem.unemployment_permille(state, content) / SimConfig.PERMILLE
	h -= content.bal_int("happiness.traffic_penalty", 220) * state.traffic / SimConfig.PERMILLE
	h -= content.bal_int("happiness.pollution_penalty", 240) * state.pollution / SimConfig.PERMILLE
	return clampi(h, 0, SimConfig.PERMILLE)


static func step(state: SimState, agg: CityAggregates, content: ContentDb) -> void:
	var diff: int = target(state, agg, content) - state.happiness
	var follow: int = maxi(content.bal_int("happiness.follow_divisor", 36), 1)
	var d: int = diff / follow
	state.happiness = clampi(state.happiness + (signi(diff) if d == 0 and diff != 0 else d), 0, SimConfig.PERMILLE)
