class_name EventEngine
extends RefCounted
## Data-driven city events. Each tick: fire due follow-ups, then, on an hour or
## daily slot, maybe pick one eligible event by weight. Everything comes from
## the tick-derived RNG, so catch-up and live play produce the same stories.

const HOUR: int = 3600


static func step(sim: Simulation, local_s: int, events: Array[SimEvent]) -> void:
	var s: SimState = sim.state
	var t: int = s.tick
	var rng: SimRng = SimRng.for_tick(s.city_seed, t, SimConfig.STREAM_EVENTS)
	_fire_due_follow_ups(sim, local_s, rng, events)
	var prev_s: int = local_s - SimConfig.TICK_SECONDS
	# "Crossed an hour boundary during this tick" works for any UTC offset.
	if _floor_div(local_s, HOUR) == _floor_div(prev_s, HOUR):
		return
	var hour: int = posmod(_floor_div(local_s, HOUR), 24)
	var slots: Array[String] = ["hourly"]
	if hour == sim.content.bal_int("events.daily_hour", 9):
		slots.append("daily")
	for slot: String in slots:
		var chance: int = sim.content.bal_int("events.%s_chance_permille" % slot, 0)
		if not rng.chance_permille(chance):
			continue
		var pick: String = _weighted_pick(sim, slot, local_s, rng)
		if pick != "":
			fire(sim, pick, local_s, rng, "", events)


## Applies an event now. `cause` is the id of the event that scheduled it ("" for random).
static func fire(sim: Simulation, id: String, local_s: int, rng: SimRng, cause: String, events: Array[SimEvent]) -> void:
	var s: SimState = sim.state
	var def: Dictionary = sim.content.events[id]
	s.story_seq += 1
	var vars: Dictionary = resolve_vars(sim, def, rng)
	apply_effects(sim, String(def.id), def.get("effects", []), rng)
	var cooldown_days: int = int(def.get("cooldown_days", 0))
	if cooldown_days > 0:
		s.cooldowns[id] = s.tick + cooldown_days * SimConfig.TICKS_PER_DAY
	if bool(def.get("once", false)):
		s.flags["event_done:" + id] = s.tick
	var data: Dictionary = {"id": id, "category": def.category, "importance": int(def.importance), "seq": s.story_seq,
		"weather": s.weather, "cause": cause}
	data.merge(vars)
	events.append(SimEvent.create("story", s.tick, data))


static func is_eligible(sim: Simulation, id: String, local_s: int) -> bool:
	var s: SimState = sim.state
	var def: Dictionary = sim.content.events[id]
	if s.tick < int(s.cooldowns.get(id, -1)):
		return false
	if bool(def.get("once", false)) and s.flags.has("event_done:" + id):
		return false
	return conditions_met(sim, def.get("conditions", {}), local_s)


static func conditions_met(sim: Simulation, c: Dictionary, local_s: int) -> bool:
	var s: SimState = sim.state
	if c.has("season") and not (c.season as Array).has(WeatherSystem.season_name_at(local_s)):
		return false
	if c.has("weather") and not (c.weather as Array).has(s.weather):
		return false
	if c.has("hour_between"):
		var h: int = posmod(_floor_div(local_s, HOUR), 24)
		var from: int = int(c.hour_between[0])
		var to: int = int(c.hour_between[1])
		var inside: bool = (h >= from and h < to) if from <= to else (h >= from or h < to)
		if not inside:
			return false
	if c.has("weekdays") and not (c.weekdays as Array).has(weekday(local_s)):
		return false
	for stat: String in c.get("min", {}):
		if stat_value(sim, stat) < int(c.min[stat]):
			return false
	for stat: String in c.get("max", {}):
		if stat_value(sim, stat) > int(c.max[stat]):
			return false
	for key: String in c.get("has_building", {}):
		if count_buildings(sim, key) < int(c.has_building[key]):
			return false
	for f: String in c.get("flags_all", []):
		if not s.flags.has(f):
			return false
	for f: String in c.get("flags_none", []):
		if s.flags.has(f):
			return false
	for p: String in c.get("policies_all", []):
		if not s.policies.has(p):
			return false
	for p: String in c.get("policies_none", []):
		if s.policies.has(p):
			return false
	return true


## 1 = Monday ... 7 = Sunday. 1970-01-01 was a Thursday.
static func weekday(local_s: int) -> int:
	return posmod(SimClockMath.day_number(local_s) + 3, 7) + 1


static func stat_value(sim: Simulation, stat: String) -> int:
	var s: SimState = sim.state
	match stat:
		"money":
			return s.money_cents / SimConfig.CENTS
		"unemployment":
			return PopulationSystem.unemployment_permille(s, sim.content)
		"buildings":
			return s.buildings.size()
	return int(s.get(stat))


## `key` is a building def id, or "category:<name>". Only finished buildings count.
static func count_buildings(sim: Simulation, key: String) -> int:
	var n: int = 0
	var cat: String = key.trim_prefix("category:") if key.begins_with("category:") else ""
	for b: BuildingInstance in sim.state.buildings:
		if not b.is_complete(sim.state.tick):
			continue
		if cat != "":
			var def: BuildingDef = sim.content.get_building(b.def_id)
			if def != null and def.category == cat:
				n += 1
		elif b.def_id == key:
			n += 1
	return n


## Template variables for a story, e.g. {"district": "Çınaraltı", "block": "2,3"}.
static func resolve_vars(sim: Simulation, def: Dictionary, rng: SimRng) -> Dictionary:
	var out: Dictionary = {}
	for name: String in def.get("vars", {}):
		var block: String = _pick_block(sim, String(def.vars[name]), rng)
		out[name] = district_name(sim, block)
		out[name + "_block"] = block
	return out


static func district_name(sim: Simulation, block: String) -> String:
	var names: Array = sim.content.map.get("districts", [])
	if names.is_empty() or block == "":
		return ""
	var parts: PackedStringArray = block.split(",")
	var per_row: int = (sim.state.grid_size + sim.state.road_every - 1) / sim.state.road_every
	var idx: int = int(parts[0]) + int(parts[1]) * per_row
	return String(names[posmod(idx, names.size())])


static func _pick_block(sim: Simulation, source: String, rng: SimRng) -> String:
	var s: SimState = sim.state
	match source:
		"busiest":
			var best: String = ""
			var best_v: int = -1
			var keys: Array = s.block_traffic.keys()
			keys.sort()
			for k: String in keys:
				if int(s.block_traffic[k]) > best_v:
					best_v = int(s.block_traffic[k])
					best = k
			if best != "":
				return best
		"greenest":
			var green_by_block: Dictionary = {}
			for b: BuildingInstance in s.buildings:
				var def: BuildingDef = sim.content.get_building(b.def_id)
				if def != null and def.green > 0 and b.is_complete(s.tick):
					var k: String = sim.grid.block_key(b.cell)
					green_by_block[k] = int(green_by_block.get(k, 0)) + def.green
			var keys2: Array = green_by_block.keys()
			keys2.sort()
			var best2: String = ""
			var best_v2: int = -1
			for k: String in keys2:
				if int(green_by_block[k]) > best_v2:
					best_v2 = int(green_by_block[k])
					best2 = k
			if best2 != "":
				return best2
	# random_built, and the fallback for the others
	var built: Dictionary = {}
	for b: BuildingInstance in s.buildings:
		built[sim.grid.block_key(b.cell)] = true
	var list: Array = built.keys()
	list.sort()
	if list.is_empty():
		return ""
	return String(list[rng.range_int(0, list.size() - 1)])


static func _weighted_pick(sim: Simulation, slot: String, local_s: int, rng: SimRng) -> String:
	var eligible: Array[String] = []
	var total: int = 0
	for id: String in sim.content.event_order:
		var def: Dictionary = sim.content.events[id]
		if String(def.check) == slot and is_eligible(sim, id, local_s):
			eligible.append(id)
			total += int(def.weight)
	if eligible.is_empty():
		return ""
	var pick: int = rng.range_int(0, total - 1)
	for id: String in eligible:
		pick -= int(sim.content.events[id].weight)
		if pick < 0:
			return id
	return eligible[-1]


static func _fire_due_follow_ups(sim: Simulation, local_s: int, rng: SimRng, events: Array[SimEvent]) -> void:
	var s: SimState = sim.state
	while not s.pending.is_empty() and int((s.pending[0] as Dictionary).tick) <= s.tick:
		var p: Dictionary = s.pending.pop_front()
		var id: String = String(p.event)
		# A follow-up still needs its conditions (the park may have been demolished).
		if sim.content.events.has(id) and conditions_met(sim, sim.content.events[id].get("conditions", {}), local_s):
			fire(sim, id, local_s, rng, String(p.cause), events)


## Applies an effect list (events, letter replies). `source` tags modifiers and follow-ups.
static func apply_effects(sim: Simulation, source: String, effects: Array, rng: SimRng) -> void:
	for raw: Variant in effects:
		_apply_effect(sim, source, raw as Dictionary, rng)


static func _apply_effect(sim: Simulation, source: String, eff: Dictionary, rng: SimRng) -> void:
	var s: SimState = sim.state
	match String(eff.type):
		"modifier":
			s.modifiers.append({"source": source, "stat": String(eff.stat), "amount": int(eff.amount),
				"until": s.tick + int(eff.hours) * SimConfig.TICKS_PER_DAY / 24})
		"money":
			var cents: int = int(eff.amount) * SimConfig.CENTS
			s.money_cents += cents
			if cents >= 0:
				s.day_income_cents += cents
			else:
				s.day_expense_cents -= cents
		"flag":
			s.flags[String(eff.name)] = s.tick
		"unflag":
			s.flags.erase(String(eff.name))
		"follow_up":
			if rng.chance_permille(int(eff.get("chance", 1000))):
				s.story_seq += 1
				s.pending.append({"tick": s.tick + int(eff.hours) * SimConfig.TICKS_PER_DAY / 24, "event": String(eff.event),
					"cause": source, "seq": s.story_seq})
				s.pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					return int(a.tick) < int(b.tick) or (int(a.tick) == int(b.tick) and int(a.seq) < int(b.seq)))


static func _floor_div(a: int, b: int) -> int:
	return (a - posmod(a, b)) / b
