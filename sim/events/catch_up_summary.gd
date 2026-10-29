class_name CatchUpSummary
extends RefCounted
## What happened while the player was away. Raw facts only; the newspaper (M4)
## turns these into prose.

const HIGHLIGHT_TYPES: Array[String] = ["building_completed", "population_milestone", "traffic_jam", "city_slept", "clock_rebased"]
const STAT_KEYS: Array[String] = ["population", "happiness", "traffic", "pollution", "green", "employed"]

var from_tick: int = 0
var to_tick: int = 0
var slept_ticks: int = 0
var before: Dictionary = {}
var after: Dictionary = {}
var counts: Dictionary = {} # event type -> count
var highlights: Array[SimEvent] = []
var days: Array[Dictionary] = [] # day_started payloads, oldest first


static func snapshot(state: SimState) -> Dictionary:
	var d: Dictionary = {"money": state.money_cents / SimConfig.CENTS}
	for k: String in STAT_KEYS:
		d[k] = state.get(k)
	return d


func begin(state: SimState) -> void:
	from_tick = state.tick
	before = snapshot(state)


func add(events: Array[SimEvent]) -> void:
	for e: SimEvent in events:
		counts[e.type] = int(counts.get(e.type, 0)) + 1
		if HIGHLIGHT_TYPES.has(e.type):
			highlights.append(e)
		if e.type == "day_started":
			days.append(e.data)
		if e.type == "city_slept":
			slept_ticks += int(e.data.ticks)


func finish(state: SimState) -> void:
	to_tick = state.tick
	after = snapshot(state)


func simulated_ticks() -> int:
	return to_tick - from_tick


## Wall time covered, including any slept part.
func away_ticks() -> int:
	return simulated_ticks() + slept_ticks


func delta(key: String) -> int:
	return int(after.get(key, 0)) - int(before.get(key, 0))


func to_dict() -> Dictionary:
	var hl: Array = []
	for e: SimEvent in highlights:
		hl.append(e.to_dict())
	return {"from_tick": from_tick, "to_tick": to_tick, "slept_ticks": slept_ticks, "before": before,
		"after": after, "counts": counts, "highlights": hl, "days": days}
