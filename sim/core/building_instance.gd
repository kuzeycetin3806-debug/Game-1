class_name BuildingInstance
extends RefCounted
## One placed building. placed_tick = -1 marks buildings that came with the map.

var id: int
var def_id: String
var cell: Vector2i
var placed_tick: int
var ready_tick: int


static func create(p_id: int, p_def: String, p_cell: Vector2i, p_placed: int, p_ready: int) -> BuildingInstance:
	var b := BuildingInstance.new()
	b.id = p_id
	b.def_id = p_def
	b.cell = p_cell
	b.placed_tick = p_placed
	b.ready_tick = p_ready
	return b


func is_complete(tick: int) -> bool:
	return tick >= ready_tick


func to_dict() -> Dictionary:
	return {"id": id, "def": def_id, "cell": [cell.x, cell.y], "placed": placed_tick, "ready": ready_tick}


static func from_dict(d: Dictionary) -> BuildingInstance:
	var c: Array = d.cell
	return create(int(d.id), String(d.def), Vector2i(int(c[0]), int(c[1])), int(d.placed), int(d.ready))
