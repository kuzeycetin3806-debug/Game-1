class_name NotificationPlanner
extends RefCounted
## Decides which local notifications to schedule when the app goes to the
## background. The sim is deterministic, so running a clone forward tells us
## exactly what will happen if the player stays away. Pure; unit tested.


## Returns [{at_unix, key, args, priority}] sorted by time.
## `sim` is consumed (pass a clone). `rules` = data/config/notifications.json.
static func plan(sim: Simulation, rules: Dictionary) -> Array[Dictionary]:
	var horizon: int = int(rules.get("horizon_hours", 24)) * SimConfig.TICKS_PER_DAY / 24
	var candidates: Array[Dictionary] = []
	for i: int in horizon:
		for e: SimEvent in sim.step():
			var c: Dictionary = candidate(sim, e, rules)
			if not c.is_empty():
				candidates.append(c)
	return choose(candidates, sim.state, rules)


## A notification candidate for an event, or {}.
static func candidate(sim: Simulation, e: SimEvent, rules: Dictionary) -> Dictionary:
	var pr: Dictionary = rules.get("priority", {})
	match e.type:
		"population_milestone":
			return _c(e.tick, "NOTIF_MILESTONE", [str(int(e.data.population))], int(pr.get("population_milestone", 80)))
		"letter_received":
			var c: Citizen = CitizenSystem.citizen_by_id(sim.state, int(e.data.citizen))
			return _c(e.tick, "NOTIF_LETTER", [c.full_name() if c != null else ""], int(pr.get("letter_received", 70)))
		"policy_took_effect":
			var pol: Dictionary = sim.content.policies.get(String(e.data.policy), {})
			return _c(e.tick, "NOTIF_POLICY", [String(pol.get("name_key", ""))], int(pr.get("policy_took_effect", 65)))
		"building_completed":
			var def: BuildingDef = sim.content.get_building(String(e.data.def))
			if def != null and (def.size > 1 or def.category == "transit"):
				return _c(e.tick, "NOTIF_BUILDING", [def.name_key], int(pr.get("big_building_completed", 60)))
		"story":
			if int(e.data.importance) >= int(pr.get("story_min_importance", 55)):
				return _c(e.tick, "NOTIF_STORY", ["story." + String(e.data.id)], int(e.data.importance))
		"traffic_jam":
			return _c(e.tick, "NOTIF_TRAFFIC", [], int(pr.get("traffic_jam", 45)))
		"day_started":
			return _c(e.tick, "NOTIF_PAPER", [], int(pr.get("morning_paper", 35)))
	return {}


## Moves quiet-hour candidates to the morning, then greedily keeps the most
## important ones that respect the daily cap and the minimum gap.
static func choose(candidates: Array[Dictionary], state: SimState, rules: Dictionary) -> Array[Dictionary]:
	var quiet_start: int = int(rules.get("quiet_start_minute", 1320))
	var quiet_end: int = int(rules.get("quiet_end_minute", 480))
	var paper_minute: int = int(rules.get("morning_paper_minute", 510))
	var gap_s: int = int(rules.get("min_gap_minutes", 180)) * 60
	var max_per_day: int = int(rules.get("max_per_day", 3))
	var timed: Array[Dictionary] = []
	for c: Dictionary in candidates:
		var at: int = state.start_unix + int(c.tick) * SimConfig.TICK_SECONDS
		var local: int = at + state.utc_offset_s
		var minute: int = posmod(local, SimConfig.SECONDS_PER_DAY) / 60
		var target_minute: int = minute
		if String(c.key) == "NOTIF_PAPER":
			target_minute = paper_minute
		elif _is_quiet(minute, quiet_start, quiet_end):
			target_minute = quiet_end + 30
		if target_minute != minute:
			var day_start: int = local - posmod(local, SimConfig.SECONDS_PER_DAY)
			var moved: int = day_start + target_minute * 60
			if moved < local:
				moved += SimConfig.SECONDS_PER_DAY
			at = moved - state.utc_offset_s
		var t: Dictionary = c.duplicate()
		t.at_unix = at
		timed.append(t)
	timed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority) != int(b.priority):
			return int(a.priority) > int(b.priority)
		return int(a.at_unix) < int(b.at_unix))
	var chosen: Array[Dictionary] = []
	var per_day: Dictionary = {}
	for t: Dictionary in timed:
		var day: int = SimClockMath.day_number(int(t.at_unix) + state.utc_offset_s)
		if int(per_day.get(day, 0)) >= max_per_day:
			continue
		var clash: bool = false
		for k: Dictionary in chosen:
			if absi(int(k.at_unix) - int(t.at_unix)) < gap_s:
				clash = true
				break
		if clash:
			continue
		chosen.append(t)
		per_day[day] = int(per_day.get(day, 0)) + 1
	chosen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.at_unix) < int(b.at_unix))
	return chosen


static func _is_quiet(minute: int, start: int, end: int) -> bool:
	return minute >= start or minute < end if start > end else (minute >= start and minute < end)


static func _c(tick: int, key: String, args: Array, priority: int) -> Dictionary:
	return {"tick": tick, "key": key, "args": args, "priority": priority}
