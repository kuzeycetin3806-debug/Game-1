class_name NewsDesk
extends RefCounted
## Editor: turns a window of SimEvents into a structured edition (no prose).
## Pure and deterministic: the same city and window always give the same paper.

const DAY_PART_HOURS: int = 6


## `before` is a CatchUpSummary.snapshot() taken at the start of the window.
static func build(sim: Simulation, events: Array[SimEvent], edition_no: int, from_tick: int, before: Dictionary, editorial: Dictionary) -> Dictionary:
	var imp: Dictionary = editorial.get("importance", {})
	var merged: Dictionary = {} # key -> story
	var order: Array[String] = []
	for e: SimEvent in events:
		if e.tick < from_tick:
			continue
		var s: Dictionary = story_for(sim, e, imp)
		if s.is_empty():
			continue
		var key: String = String(s.key)
		if merged.has(key):
			var m: Dictionary = merged[key]
			m.count = int(m.count) + 1
			m.importance = int(m.importance) + int(imp.get("many_bonus_per_extra", 4))
			m.tick = e.tick
			m.vars = s.vars # latest wins
		else:
			merged[key] = s
			order.append(key)
	var stories: Array = []
	for key: String in order:
		stories.append(merged[key])
	stories.sort_custom(_by_importance)
	var max_n: int = int(editorial.get("max_stories", 5))
	if stories.size() > max_n:
		stories.resize(max_n)
	for f: String in fillers(sim, int(editorial.get("min_stories", 3)) - stories.size()):
		stories.append({"key": f, "importance": 0, "count": 1, "tick": sim.state.tick, "vars": {}})
	var local_s: int = sim.local_seconds_now()
	var date: Dictionary = SimClockMath.civil_from_days(SimClockMath.day_number(local_s))
	return {
		"edition": edition_no,
		"from_tick": from_tick,
		"to_tick": sim.state.tick,
		"date": {"year": date.year, "month": date.month, "day": date.day, "weekday": EventEngine.weekday(local_s)},
		"stories": stories,
		"numbers": numbers(before, CatchUpSummary.snapshot(sim.state)),
		"weather": weather_box(sim, local_s),
	}


## One story candidate for an event, or {} when the event is not newsworthy.
static func story_for(sim: Simulation, e: SimEvent, imp: Dictionary) -> Dictionary:
	match e.type:
		"story":
			var vars: Dictionary = {}
			if e.data.has("district"):
				vars.district = String(e.data.district)
			return _s("story." + String(e.data.id), int(e.data.importance), e.tick, vars)
		"building_completed", "building_demolished":
			var def: BuildingDef = sim.content.get_building(String(e.data.def))
			if def == null:
				return {}
			var key: String = ("built." + def.category) if e.type == "building_completed" else "demolished"
			var score: int = int(imp.get(key, 25)) + (int(imp.get("big_building_bonus", 15)) if def.size > 1 else 0)
			return _s(key, score, e.tick, {"building_key": def.name_key})
		"population_milestone":
			return _s("milestone", int(imp.get("milestone", 70)) + mini(int(e.data.population) / 1000, 20), e.tick, {"population": int(e.data.population)})
		"traffic_jam":
			return _s("traffic_jam", int(imp.get("traffic_jam", 55)), e.tick, {"district": EventEngine.district_name(sim, String(e.data.get("block", "")))})
		"policy_enacted", "policy_took_effect", "policy_repealed":
			var pol: Dictionary = sim.content.policies.get(String(e.data.policy), {})
			if pol.is_empty():
				return {}
			var k: String = {"policy_enacted": "policy_enacted", "policy_took_effect": "policy_effect", "policy_repealed": "policy_repealed"}[e.type]
			# Distinct keys per policy so two policies are two stories.
			return _s(k + ":" + String(pol.id), int(imp.get(k, 50)), e.tick, {"policy_key": String(pol.name_key)})
		"weather_changed":
			var wk: String = "weather." + String(e.data.weather)
			return _s(wk, int(imp.get(wk, 25)), e.tick, {})
		"city_slept":
			return _s("city_slept", int(imp.get("city_slept", 20)), e.tick, {})
	return {}


## Slice-of-life stories from the city's state, most pressing first.
static func fillers(sim: Simulation, n: int) -> Array[String]:
	var out: Array[String] = []
	if n <= 0:
		return out
	var s: SimState = sim.state
	var candidates: Array[String] = []
	if s.money_cents < 0:
		candidates.append("filler.budget_tight")
	if s.happiness < 450:
		candidates.append("filler.mood_low")
	if s.traffic > 500:
		candidates.append("filler.traffic_busy")
	if s.green > 700:
		candidates.append("filler.green_city")
	if s.happiness > 720:
		candidates.append("filler.mood_high")
	if s.money_cents > 1_000_000 * SimConfig.CENTS:
		candidates.append("filler.budget_rich")
	candidates.append("filler.quiet")
	for c: String in candidates:
		if out.size() >= n:
			break
		out.append(c)
	return out


static func numbers(before: Dictionary, after: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ["population", "money", "happiness", "traffic"]:
		out[k] = {"before": int(before.get(k, after.get(k, 0))), "after": int(after.get(k, 0))}
	return out


static func weather_box(sim: Simulation, local_s: int) -> Dictionary:
	var fc: Array = []
	for f: Dictionary in WeatherSystem.forecast(sim.state, sim.content, local_s, 3):
		var hour: int = posmod(int(f.start_local), SimConfig.SECONDS_PER_DAY) / 3600
		fc.append({"part": hour / DAY_PART_HOURS, "weather": String(f.weather)})
	return {"now": sim.state.weather, "forecast": fc}


static func _s(key: String, importance: int, tick: int, vars: Dictionary) -> Dictionary:
	return {"key": key, "importance": importance, "count": 1, "tick": tick, "vars": vars}


static func _by_importance(a: Dictionary, b: Dictionary) -> bool:
	if int(a.importance) != int(b.importance):
		return int(a.importance) > int(b.importance)
	if int(a.tick) != int(b.tick):
		return int(a.tick) > int(b.tick)
	return String(a.key) < String(b.key)
