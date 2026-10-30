class_name CitizenSystem
extends RefCounted
## Named citizens: they move in as the town grows, their mood follows what
## they care about, they remember the mayor's decisions, and now and then one
## writes a letter. All randomness comes from SimConfig.STREAM_CITIZENS.

const HOUR: int = 3600


## Once a day (first tick of a new local day) and at the letter hour.
static func step(sim: Simulation, local_s: int, events: Array[SimEvent]) -> void:
	var prev: int = local_s - SimConfig.TICK_SECONDS
	if _floor_div(local_s, HOUR) == _floor_div(prev, HOUR):
		return
	var hour: int = posmod(_floor_div(local_s, HOUR), 24)
	var rng: SimRng = SimRng.for_tick(sim.state.city_seed, sim.state.tick, SimConfig.STREAM_CITIZENS)
	if hour == 0:
		grow(sim, rng)
		update_moods(sim)
	if hour == sim.content.bal_int("citizens.letter_hour", 10):
		expire_letters(sim, events)
		maybe_write_letter(sim, local_s, rng, events)


static func target_count(sim: Simulation) -> int:
	var per: int = maxi(sim.content.bal_int("citizens.per_residents", 10), 1)
	return clampi(sim.state.population / per, sim.content.bal_int("citizens.min", 6), sim.content.bal_int("citizens.max", 120))


## Adds citizens until the target is met. Nobody is removed: people who
## were named stay part of the city's story.
static func grow(sim: Simulation, rng: SimRng) -> void:
	var s: SimState = sim.state
	var target: int = target_count(sim)
	while s.citizens.size() < target:
		s.citizens.append(spawn(sim, rng))


static func spawn(sim: Simulation, rng: SimRng) -> Citizen:
	var s: SimState = sim.state
	var archetypes: Array = sim.content.citizens.archetypes
	var total: int = 0
	for a: Variant in archetypes:
		total += int((a as Dictionary).weight)
	var pick: int = rng.range_int(0, maxi(total - 1, 0))
	var arch: Dictionary = archetypes[0]
	for a: Variant in archetypes:
		pick -= int((a as Dictionary).weight)
		if pick < 0:
			arch = a
			break
	var c := Citizen.new()
	c.id = s.next_citizen_id
	s.next_citizen_id += 1
	var firsts: Array = sim.content.citizens.names.first
	var lasts: Array = sim.content.citizens.names.last
	c.first = String(firsts[rng.range_int(0, firsts.size() - 1)])
	c.last = String(lasts[rng.range_int(0, lasts.size() - 1)])
	c.age = rng.range_int(int(arch.age[0]), int(arch.age[1]))
	c.archetype = String(arch.id)
	c.occupation_key = String(arch.occupation_key)
	var trait_names: Array = (arch.traits as Dictionary).keys()
	trait_names.sort()
	for t: String in trait_names:
		c.traits[t] = rng.range_int(int(arch.traits[t][0]), int(arch.traits[t][1]))
	c.interests = (arch.interests as Array).duplicate()
	c.home_block = _home_block(sim, rng)
	c.mood = (s.happiness - 500) / 5
	c.joined_tick = s.tick
	return c


## Mood drifts towards a target built from the things this citizen cares about.
static func mood_target(sim: Simulation, c: Citizen) -> int:
	var s: SimState = sim.state
	var m: int = (s.happiness - 500) / 4
	if c.has_interest(["parks", "environment"]):
		m += (s.green - 400) / 10
	if c.has_interest(["traffic", "commute"]):
		m -= (s.traffic - 300) / 6
	if c.has_interest(["business", "budget"]):
		m -= (PopulationSystem.unemployment_permille(s, sim.content) - 80) / 6
	if c.has_interest(["quiet", "environment"]):
		m -= s.pollution / 10
	# Memories colour the outlook (strongest first; fades as memories age out).
	for raw: Variant in c.memory:
		m += int((raw as Dictionary).valence) / 2
	return clampi(m, -100, 100)


static func update_moods(sim: Simulation) -> void:
	var div: int = maxi(sim.content.bal_int("citizens.mood_follow_divisor", 4), 1)
	for c: Citizen in sim.state.citizens:
		var diff: int = mood_target(sim, c) - c.mood
		var d: int = diff / div
		c.mood = clampi(c.mood + (signi(diff) if d == 0 and diff != 0 else d), -100, 100)


## Called for every event the sim or a command produced: matching citizens remember it.
static func observe(sim: Simulation, events: Array[SimEvent]) -> void:
	if sim.state.citizens.is_empty():
		return
	var rules: Array = sim.content.citizens.get("memory_rules", [])
	var cap: int = sim.content.bal_int("citizens.memory_size", 6)
	for e: SimEvent in events:
		for raw: Variant in rules:
			var r: Dictionary = raw
			if String(r.event) != e.type or not _matches(sim, r.get("match", {}), e):
				continue
			var ref: String = _ref_of(e)
			for c: Citizen in sim.state.citizens:
				if c.has_interest(r.interests):
					c.remember({"tick": e.tick, "kind": e.type, "ref": ref, "valence": int(r.valence)}, cap)
					c.mood = clampi(c.mood + int(r.valence) / 2, -100, 100)


static func expire_letters(sim: Simulation, events: Array[SimEvent]) -> void:
	var s: SimState = sim.state
	var limit: int = sim.content.bal_int("citizens.expire_hours", 72) * SimConfig.TICKS_PER_DAY / 24
	for raw: Variant in s.letters:
		var l: Dictionary = raw
		if String(l.status) != "open" or s.tick - int(l.tick) < limit:
			continue
		l.status = "expired"
		var c: Citizen = citizen_by_id(s, int(l.citizen))
		if c != null:
			c.mood = clampi(c.mood + sim.content.bal_int("citizens.ignored_mood", -12), -100, 100)
			c.remember({"tick": s.tick, "kind": "letter_ignored", "ref": String(l.topic), "valence": sim.content.bal_int("citizens.ignored_memory", -10)}, sim.content.bal_int("citizens.memory_size", 6))
		events.append(SimEvent.create("letter_expired", s.tick, {"letter_id": int(l.id), "citizen": int(l.citizen), "topic": String(l.topic)}))


static func open_letters(s: SimState) -> int:
	var n: int = 0
	for raw: Variant in s.letters:
		if String((raw as Dictionary).status) == "open":
			n += 1
	return n


static func maybe_write_letter(sim: Simulation, local_s: int, rng: SimRng, events: Array[SimEvent]) -> void:
	var s: SimState = sim.state
	if s.citizens.is_empty() or open_letters(s) >= sim.content.bal_int("citizens.max_open_letters", 4):
		return
	if not rng.chance_permille(sim.content.bal_int("citizens.letter_chance_permille", 650)):
		return
	var cooldown: int = sim.content.bal_int("citizens.letter_cooldown_days", 5) * SimConfig.TICKS_PER_DAY
	var pairs: Array = [] # [weight, citizen, topic]
	var total: int = 0
	for t: Variant in sim.content.citizens.topics:
		var topic: Dictionary = t
		if not EventEngine.conditions_met(sim, topic.get("conditions", {}), local_s):
			continue
		for c: Citizen in s.citizens:
			if s.tick - c.last_letter_tick < cooldown or not c.has_interest(topic.interests):
				continue
			var mood_range: Array = topic.get("mood", [-100, 100])
			if c.mood < int(mood_range[0]) or c.mood > int(mood_range[1]):
				continue
			# Civic-minded and strongly-feeling people write more.
			var w: int = int(topic.weight) * (10 + int(c.traits.get("civic", 50)) / 10 + absi(c.mood) / 10)
			pairs.append([w, c, topic])
			total += w
	if pairs.is_empty():
		return
	var pick: int = rng.range_int(0, total - 1)
	for p: Array in pairs:
		pick -= int(p[0])
		if pick < 0:
			_send(sim, p[1] as Citizen, p[2] as Dictionary, events)
			return


static func _send(sim: Simulation, c: Citizen, topic: Dictionary, events: Array[SimEvent]) -> void:
	var s: SimState = sim.state
	var letter: Dictionary = {"id": s.next_letter_id, "citizen": c.id, "topic": String(topic.id), "tone": String(topic.tone),
		"tick": s.tick, "status": "open", "reply": "", "reply_tick": -1,
		"district": EventEngine.district_name(sim, c.home_block), "memory": c.strongest_memory()}
	s.next_letter_id += 1
	s.letters.append(letter)
	c.letters_sent += 1
	c.last_letter_tick = s.tick
	events.append(SimEvent.create("letter_received", s.tick, {"letter_id": int(letter.id), "citizen": c.id, "topic": String(topic.id)}))


static func citizen_by_id(s: SimState, id: int) -> Citizen:
	for c: Citizen in s.citizens:
		if c.id == id:
			return c
	return null


static func letter_by_id(s: SimState, id: int) -> Dictionary:
	for raw: Variant in s.letters:
		if int((raw as Dictionary).id) == id:
			return raw
	return {}


static func topic_def(sim: Simulation, id: String) -> Dictionary:
	for t: Variant in sim.content.citizens.topics:
		if String((t as Dictionary).id) == id:
			return t
	return {}


static func _home_block(sim: Simulation, rng: SimRng) -> String:
	var homes: Dictionary = {}
	for b: BuildingInstance in sim.state.buildings:
		var def: BuildingDef = sim.content.get_building(b.def_id)
		if def != null and def.residents > 0:
			homes[sim.grid.block_key(b.cell)] = true
	var keys: Array = homes.keys()
	keys.sort()
	if keys.is_empty():
		return ""
	return String(keys[rng.range_int(0, keys.size() - 1)])


static func _matches(sim: Simulation, match: Dictionary, e: SimEvent) -> bool:
	for k: String in match:
		if k == "category":
			var def: BuildingDef = sim.content.get_building(String(e.data.get("def", "")))
			if def == null or def.category != String(match[k]):
				return false
		elif String(e.data.get(k, "")) != String(match[k]):
			return false
	return true


static func _ref_of(e: SimEvent) -> String:
	for k: String in ["policy", "def", "id"]:
		if e.data.has(k):
			return String(e.data[k])
	return ""


static func _floor_div(a: int, b: int) -> int:
	return (a - posmod(a, b)) / b
