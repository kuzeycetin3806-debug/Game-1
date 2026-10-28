class_name SkyPalette
extends RefCounted
## Data-driven sky/light colours keyed by sun elevation, loaded from JSON.

class Sample:
	var sky_top: Color
	var sky_horizon: Color
	var sky_bottom: Color
	var light_color: Color
	var light_energy: float
	var ambient_color: Color
	var ambient_energy: float
	var fog_color: Color
	## 0 = full daylight, 1 = deep night.
	var darkness: float

const COLOR_KEYS: Array[String] = ["sky_top", "sky_horizon", "sky_bottom", "light_color", "ambient_color", "fog_color"]
const FLOAT_KEYS: Array[String] = ["light_energy", "ambient_energy", "darkness"]

var _keys: Array[Dictionary] = []
var _occupancy: Array[Dictionary] = []
var street_lamp_on_darkness: float = 0.4


static func load_from_file(path: String) -> SkyPalette:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "SkyPalette: cannot parse %s" % path)
	return from_dict(parsed as Dictionary)


static func from_dict(d: Dictionary) -> SkyPalette:
	var p := SkyPalette.new()
	for raw: Variant in d.get("keys", []):
		var k: Dictionary = raw
		var entry: Dictionary = {"elevation": float(k.elevation)}
		for c: String in COLOR_KEYS:
			entry[c] = Color.html(String(k[c]))
		for f: String in FLOAT_KEYS:
			entry[f] = float(k[f])
		p._keys.append(entry)
	p._keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.elevation < b.elevation)
	for raw: Variant in d.get("window_occupancy", []):
		var o: Dictionary = raw
		p._occupancy.append({"hour": float(o.hour), "value": float(o.value)})
	p._occupancy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.hour < b.hour)
	p.street_lamp_on_darkness = float(d.get("street_lamp_on_darkness", 0.4))
	assert(p._keys.size() >= 2, "SkyPalette needs at least two keys")
	return p


func sample(elevation: float) -> Sample:
	var hi: int = 0
	while hi < _keys.size() - 1 and _keys[hi].elevation < elevation:
		hi += 1
	var lo: int = maxi(hi - 1, 0)
	var a: Dictionary = _keys[lo]
	var b: Dictionary = _keys[hi]
	var span: float = float(b.elevation) - float(a.elevation)
	var t: float = 0.0 if span <= 0.0 else clampf((elevation - float(a.elevation)) / span, 0.0, 1.0)
	var s := Sample.new()
	s.sky_top = (a.sky_top as Color).lerp(b.sky_top, t)
	s.sky_horizon = (a.sky_horizon as Color).lerp(b.sky_horizon, t)
	s.sky_bottom = (a.sky_bottom as Color).lerp(b.sky_bottom, t)
	s.light_color = (a.light_color as Color).lerp(b.light_color, t)
	s.ambient_color = (a.ambient_color as Color).lerp(b.ambient_color, t)
	s.fog_color = (a.fog_color as Color).lerp(b.fog_color, t)
	s.light_energy = lerpf(a.light_energy, b.light_energy, t)
	s.ambient_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
	s.darkness = lerpf(a.darkness, b.darkness, t)
	return s


## Share of windows lit at the given local hour, before darkness is applied.
func window_occupancy(local_hour: float) -> float:
	if _occupancy.is_empty():
		return 0.5
	var h: float = fposmod(local_hour, 24.0)
	for i: int in range(1, _occupancy.size()):
		var a: Dictionary = _occupancy[i - 1]
		var b: Dictionary = _occupancy[i]
		if h <= float(b.hour):
			var span: float = float(b.hour) - float(a.hour)
			var t: float = 0.0 if span <= 0.0 else (h - float(a.hour)) / span
			return lerpf(a.value, b.value, t)
	return float(_occupancy[-1].value)


## Final window light amount in [0, 1]. Some windows stay lit even by day (offices).
func window_light(darkness: float, local_hour: float) -> float:
	return clampf(window_occupancy(local_hour) * lerpf(0.06, 1.0, darkness), 0.0, 1.0)


func street_lamps(darkness: float) -> float:
	return smoothstep(street_lamp_on_darkness - 0.15, street_lamp_on_darkness + 0.15, darkness)
