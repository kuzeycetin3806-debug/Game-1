class_name LifeMath
extends RefCounted
## Pure helpers for street life: how many movers to show and where they are.
## Movement is a pure function of (index, time), so nothing accumulates and no
## per-frame state needs to be stored.


## Visible count from population, a time-of-day curve value (0..1000) and weather.
static func count(max_count: int, base: int, per_residents: int, population: int, curve_permille: int, weather_factor: float) -> int:
	var by_pop: int = base + population / maxi(per_residents, 1)
	var n: float = float(mini(by_pop, max_count)) * clampf(curve_permille / 1000.0, 0.0, 1.0) * weather_factor
	return clampi(roundi(n), 0, max_count)


## Linear interpolation of [[minute, value], ...] at `minute`.
static func curve(points: Array, minute: float) -> int:
	if points.is_empty():
		return 1000
	for i: int in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if minute <= float(b[0]):
			var t: float = (minute - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1.0)
			return roundi(lerpf(float(a[1]), float(b[1]), clampf(t, 0.0, 1.0)))
	return int((points[-1] as Array)[1])


## Stable per-index random in [0, 1).
static func rand01(index: int, salt: int) -> float:
	return float(SimRng.mix32(index * 7919 + salt * 104729) & 0xFFFFFF) / float(0x1000000)


## Position along a straight route of `length` metres, looping, for mover `index` at `time` seconds.
## dir = +1 or -1. Returns distance from the route start in [0, length).
static func along(index: int, time: float, length: float, speed: float, dir: int) -> float:
	var start: float = rand01(index, 1) * length
	return fposmod(start + dir * speed * time, length)


## Ping-pong position with dwell at each end (the tram): distance from start in [0, length].
static func ping_pong(time: float, length: float, speed: float, dwell: float) -> Dictionary:
	var run: float = length / maxf(speed, 0.01)
	var cycle: float = 2.0 * (run + dwell)
	var t: float = fposmod(time, cycle)
	if t < run:
		return {"pos": t * speed, "dir": 1}
	if t < run + dwell:
		return {"pos": length, "dir": 1}
	if t < 2.0 * run + dwell:
		return {"pos": length - (t - run - dwell) * speed, "dir": -1}
	return {"pos": 0.0, "dir": -1}
