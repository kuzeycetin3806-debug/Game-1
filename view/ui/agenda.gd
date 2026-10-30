class_name Agenda
extends RefCounted
## "Today's agenda": a few things worth the player's next minute, from the
## current city. Pure (reads the sim only); unit tested.

const MAX_ITEMS: int = 4


## [{key, args, action}] where action is "mailbox" | "decisions" | "build:<category>" | "".
static func items(sim: Simulation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: SimState = sim.state
	var open: int = CitizenSystem.open_letters(s)
	if open > 0:
		out.append({"key": "AGENDA_LETTERS", "args": [open], "action": "mailbox"})
	var ids: Array = s.policies.keys()
	ids.sort()
	for id: String in ids:
		var left: int = int(s.policies[id].active_from) - s.tick
		if left > 0:
			out.append({"key": "AGENDA_POLICY_PENDING", "args": [String(sim.content.policies[id].name_key), CatchUpOverlay.duration(left)], "action": "decisions"})
	var building: int = 0
	for b: BuildingInstance in s.buildings:
		if not b.is_complete(s.tick):
			building += 1
	if building > 0:
		out.append({"key": "AGENDA_CONSTRUCTION", "args": [building], "action": ""})
	var tip: Dictionary = weakest_spot(sim)
	if not tip.is_empty():
		out.append(tip)
	if out.size() > MAX_ITEMS:
		out.resize(MAX_ITEMS)
	return out


## One nudge for the city's weakest area, or {}.
static func weakest_spot(sim: Simulation) -> Dictionary:
	var s: SimState = sim.state
	if s.money_cents < 0:
		return {"key": "AGENDA_TIP_BUDGET", "args": [], "action": "decisions"}
	if s.traffic > 450:
		return {"key": "AGENDA_TIP_TRAFFIC", "args": [], "action": "decisions"}
	if PopulationSystem.unemployment_permille(s, sim.content) > 150:
		return {"key": "AGENDA_TIP_JOBS", "args": [], "action": "build:office"}
	if s.green < 350:
		return {"key": "AGENDA_TIP_GREEN", "args": [], "action": "build:park"}
	if s.happiness > 650 and s.population < 1000:
		return {"key": "AGENDA_TIP_GROW", "args": [], "action": "build:residential"}
	return {}
