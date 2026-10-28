class_name EventLog
extends RefCounted
## Bounded history of SimEvents (newest last). Saved with the city.

const DEFAULT_CAPACITY: int = 2000

var capacity: int = DEFAULT_CAPACITY
var events: Array[SimEvent] = []


func append_all(new_events: Array[SimEvent]) -> void:
	events.append_array(new_events)
	if events.size() > capacity:
		events = events.slice(events.size() - capacity)


func since(tick: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.tick >= tick:
			out.append(e)
	return out


func to_array() -> Array:
	var out: Array = []
	for e: SimEvent in events:
		out.append(e.to_dict())
	return out


static func from_array(a: Array) -> EventLog:
	var result := EventLog.new()
	for raw: Variant in a:
		result.events.append(SimEvent.from_dict(raw as Dictionary))
	return result
