class_name PopulationSystem
extends RefCounted
## Residents drift towards a target set by housing and happiness.


static func target(capacity: int, happiness: int, content: ContentDb, attractiveness: int = 0) -> int:
	var floor_pm: int = content.bal_int("population.vacancy_floor_permille", 450)
	var fill: int = clampi(floor_pm + (SimConfig.PERMILLE - floor_pm) * happiness / SimConfig.PERMILLE + attractiveness, 0, SimConfig.PERMILLE)
	return capacity * fill / SimConfig.PERMILLE


static func step(state: SimState, agg: CityAggregates, content: ContentDb, rng: SimRng, mods: Dictionary = {}) -> void:
	var tgt: int = target(agg.residents_capacity, state.happiness, content, int(mods.get("attractiveness", 0)))
	var diff: int = tgt - state.population
	var divisor: int = maxi(content.bal_int("population.move_divisor", 96), 1)
	var delta: int = diff / divisor
	if delta == 0 and diff != 0:
		# Small gaps close one household at a time, at a random pace.
		delta = signi(diff) if rng.chance_permille(400) else 0
	state.population = clampi(state.population + delta, 0, agg.residents_capacity)
	var workforce: int = state.population * content.bal_int("workforce_permille", 600) / SimConfig.PERMILLE
	state.employed = mini(workforce, agg.jobs_total)


static func unemployment_permille(state: SimState, content: ContentDb) -> int:
	var workforce: int = state.population * content.bal_int("workforce_permille", 600) / SimConfig.PERMILLE
	if workforce <= 0:
		return 0
	return (workforce - state.employed) * SimConfig.PERMILLE / workforce
