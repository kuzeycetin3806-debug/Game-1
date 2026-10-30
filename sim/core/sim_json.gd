class_name SimJson
extends RefCounted
## JSON helpers for sim data. JSON turns every number into a float; the sim is
## integer-only by convention, so integral floats are turned back into ints.


static func ints(v: Variant) -> Variant:
	if v is float and is_equal_approx(float(v), roundf(float(v))):
		return int(v)
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary):
			out[k] = ints((v as Dictionary)[k])
		return out
	if v is Array:
		var out_a: Array = []
		for x: Variant in (v as Array):
			out_a.append(ints(x))
		return out_a
	return v


## Same fingerprint SimState.hash() produces, computed from a plain dictionary
## (e.g. a parsed save of any version).
static func canonical_hash(d: Dictionary) -> int:
	return SimRng.hash_bytes(JSON.stringify(ints(d), "", true).to_utf8_buffer())
