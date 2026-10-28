class_name CityGrid
extends RefCounted
## Derived spatial index over SimState.buildings (never saved).
## VARSAYIM: fixed road lattice — every `road_every`-th row/column is road.

var size: int
var road_every: int
var _occupancy: Dictionary = {} # Vector2i -> building id


static func build(state: SimState, content: ContentDb) -> CityGrid:
	var g := CityGrid.new()
	g.size = state.grid_size
	g.road_every = state.road_every
	for b: BuildingInstance in state.buildings:
		var def: BuildingDef = content.get_building(b.def_id)
		var s: int = def.size if def != null else 1
		for c: Vector2i in g.footprint(b.cell, s):
			g._occupancy[c] = b.id
	return g


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


func is_road(c: Vector2i) -> bool:
	return c.x % road_every == 0 or c.y % road_every == 0


func building_at(c: Vector2i) -> int:
	return int(_occupancy.get(c, -1))


func footprint(origin: Vector2i, s: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in s:
		for y: int in s:
			out.append(origin + Vector2i(x, y))
	return out


## Empty string when the footprint is buildable, else a translation key.
func check_footprint(origin: Vector2i, s: int) -> String:
	for c: Vector2i in footprint(origin, s):
		if not in_bounds(c):
			return "ERR_OUT_OF_BOUNDS"
		if is_road(c):
			return "ERR_ON_ROAD"
		if _occupancy.has(c):
			return "ERR_CELL_OCCUPIED"
	return ""


## District = the block between roads a cell belongs to.
func block_of(c: Vector2i) -> Vector2i:
	return Vector2i(c.x / road_every, c.y / road_every)


func block_key(c: Vector2i) -> String:
	var b: Vector2i = block_of(c)
	return "%d,%d" % [b.x, b.y]
