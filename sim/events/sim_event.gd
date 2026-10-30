class_name SimEvent
extends RefCounted
## A fact the simulation produced. Pure data; the newspaper and UI read these.

var type: String
var tick: int
var data: Dictionary


static func create(p_type: String, p_tick: int, p_data: Dictionary = {}) -> SimEvent:
	var e := SimEvent.new()
	e.type = p_type
	e.tick = p_tick
	e.data = p_data
	return e


func to_dict() -> Dictionary:
	return {"type": type, "tick": tick, "data": data}


static func from_dict(d: Dictionary) -> SimEvent:
	var data_v: Variant = d.get("data", {})
	return create(String(d.type), int(d.tick), SimJson.ints(data_v) as Dictionary)
