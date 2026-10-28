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
	return create(String(d.type), int(d.tick), _ints(data_v) as Dictionary)


## JSON turns every number into a float; event payloads are integer-only by convention.
static func _ints(v: Variant) -> Variant:
	if v is float and is_equal_approx(float(v), roundf(float(v))):
		return int(v)
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary):
			out[k] = _ints((v as Dictionary)[k])
		return out
	if v is Array:
		var out_a: Array = []
		for x: Variant in (v as Array):
			out_a.append(_ints(x))
		return out_a
	return v
