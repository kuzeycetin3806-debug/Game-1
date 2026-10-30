class_name WeatherSystem
extends RefCounted
## Deterministic weather in 6-hour blocks with persistence and seasonal odds.
## The forecast uses the same function as the real roll, so it is always right.
## VARSAYIM: forecasts are perfect for now; uncertainty can be layered on later.



static func block_seconds(content: ContentDb) -> int:
	return int(content.weather.get("block_hours", 6)) * 3600


static func block_index(local_s: int, content: ContentDb) -> int:
	var bs: int = block_seconds(content)
	return (local_s - posmod(local_s, bs)) / bs


static func season_name_at(local_s: int) -> String:
	var date: Dictionary = SimClockMath.civil_from_days(SimClockMath.day_number(local_s))
	match SimClockMath.season_for_month(int(date.month)):
		SimClockMath.Season.SPRING:
			return "spring"
		SimClockMath.Season.SUMMER:
			return "summer"
		SimClockMath.Season.AUTUMN:
			return "autumn"
	return "winter"


static func roll(content: ContentDb, city_seed: int, block: int, prev: String, season: String) -> String:
	var table: Dictionary = (content.weather.get("seasons", {}) as Dictionary).get(season, {"clear": 1})
	var rng: SimRng = SimRng.for_tick(city_seed, block, SimConfig.STREAM_WEATHER)
	if prev != "" and table.has(prev) and rng.chance_permille(int(content.weather.get("persistence_permille", 600))):
		return prev
	var names: Array = table.keys()
	names.sort() # dictionary order must never matter
	var total: int = 0
	for n: String in names:
		total += int(table[n])
	var pick: int = rng.range_int(0, maxi(total - 1, 0))
	for n: String in names:
		pick -= int(table[n])
		if pick < 0:
			return n
	return String(names[0])


static func step(state: SimState, content: ContentDb, local_s: int, events: Array[SimEvent]) -> void:
	var b: int = block_index(local_s, content)
	if b == state.weather_block:
		return
	var first: bool = state.weather_block < 0
	var next: String = roll(content, state.city_seed, b, "" if first else state.weather, season_name_at(local_s))
	if not first and next != state.weather and (content.weather.get("notable", []) as Array).has(next):
		events.append(SimEvent.create("weather_changed", state.tick, {"weather": next, "season": season_name_at(local_s)}))
	state.weather = next
	state.weather_block = b


## Next `count` blocks after the current one: [{block, start_local, weather}].
static func forecast(state: SimState, content: ContentDb, local_s: int, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bs: int = block_seconds(content)
	var b: int = block_index(local_s, content)
	var prev: String = state.weather
	for i: int in count:
		b += 1
		var start: int = b * bs
		prev = roll(content, state.city_seed, b, prev, season_name_at(start))
		out.append({"block": b, "start_local": start, "weather": prev})
	return out
