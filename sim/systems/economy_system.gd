class_name EconomySystem
extends RefCounted
## Taxes and upkeep, accrued every tick with exact sub-cent remainders.


static func daily_income(state: SimState, agg: CityAggregates, content: ContentDb) -> int:
	var commerce_filled: int = mini(agg.commercial_jobs, state.employed)
	return state.employed * content.bal_int("tax_per_worker_per_day") \
		+ state.population * content.bal_int("tax_per_resident_per_day") \
		+ commerce_filled * content.bal_int("commerce_income_per_job_per_day")


static func step(state: SimState, agg: CityAggregates, content: ContentDb) -> void:
	var inc_total: int = daily_income(state, agg, content) * SimConfig.CENTS + state.income_frac
	var inc: int = inc_total / SimConfig.TICKS_PER_DAY
	state.income_frac = inc_total % SimConfig.TICKS_PER_DAY
	var exp_total: int = agg.upkeep_per_day * SimConfig.CENTS + state.expense_frac
	var expense: int = exp_total / SimConfig.TICKS_PER_DAY
	state.expense_frac = exp_total % SimConfig.TICKS_PER_DAY
	state.money_cents += inc - expense
	state.day_income_cents += inc
	state.day_expense_cents += expense
