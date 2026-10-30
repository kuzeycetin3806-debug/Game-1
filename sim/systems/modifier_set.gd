class_name ModifierSet
extends RefCounted
## Sums every active effect on a stat: timed modifiers from events, enacted
## policies that took effect, and the current weather. Computed once per tick.
## Stats: happiness, traffic_demand, traffic_relief, income, pollution,
## attractiveness (permille) and daily_cost (lira/day).

## Validation only (load time). Never iterate this in per-tick code: see collect().
const STATS: Array[String] = ["happiness", "traffic_demand", "traffic_relief", "income", "pollution", "attractiveness", "daily_cost"]


static func collect(state: SimState, content: ContentDb) -> Dictionary:
	# Literal, not a loop over STATS: iterating a const typed array from a hot
	# static function corrupted the heap in Godot 4.4.1 (double free).
	var out: Dictionary = {"happiness": 0, "traffic_demand": 0, "traffic_relief": 0, "income": 0,
		"pollution": 0, "attractiveness": 0, "daily_cost": 0}
	for raw: Variant in state.modifiers:
		var m: Dictionary = raw
		if state.tick < int(m.until):
			_add(out, String(m.stat), int(m.amount))
	var ids: Array = state.policies.keys()
	ids.sort()
	for id: String in ids:
		var def: Dictionary = content.policies.get(id, {})
		var p: Dictionary = state.policies[id]
		_add(out, "daily_cost", int(def.get("cost_per_day", 0)))
		if state.tick >= int(p.active_from):
			var eff: Dictionary = def.get("effects", {})
			for stat: String in eff:
				_add(out, stat, int(eff[stat]))
	var weather_eff: Dictionary = (content.weather.get("effects", {}) as Dictionary).get(state.weather, {})
	for stat: String in weather_eff:
		_add(out, stat, int(weather_eff[stat]))
	return out


## Drops expired timed modifiers (keeps saves small).
static func prune(state: SimState) -> void:
	var kept: Array = []
	for raw: Variant in state.modifiers:
		if state.tick < int((raw as Dictionary).until):
			kept.append(raw)
	state.modifiers = kept


static func _add(out: Dictionary, stat: String, amount: int) -> void:
	out[stat] = int(out.get(stat, 0)) + amount
