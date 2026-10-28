class_name BuildController
extends Node
## Player interaction state machine: idle → placing → idle, idle → selected.
## One-handed placement: the ghost sits under the screen centre, so the player
## pans the map with the thumb and taps "Place".

enum Mode { IDLE, PLACING, SELECTED }

signal mode_changed(mode: Mode)
signal placement_updated(def: BuildingDef, origin: Vector2i, error_key: String)
signal selection_changed(building_id: int)

@export var camera_rig: CityCamera
@export var renderer: CityRenderer

var mode: Mode = Mode.IDLE
var placing_def: BuildingDef
var selected_id: int = -1

var _origin: Vector2i = Vector2i(-999, -999)


func _ready() -> void:
	camera_rig.tapped.connect(_on_tapped)
	EventBus.city_changed.connect(_on_city_changed)
	EventBus.tick_advanced.connect(func(_t: int) -> void: _refresh_placement(true))


func start_placing(def_id: String) -> void:
	placing_def = SimRunner.content.get_building(def_id)
	if placing_def == null:
		return
	_clear_selection()
	_origin = Vector2i(-999, -999)
	_set_mode(Mode.PLACING)
	_refresh_placement(true)


func cancel() -> void:
	renderer.hide_ghost()
	_clear_selection()
	placing_def = null
	_set_mode(Mode.IDLE)


func confirm_placement() -> Dictionary:
	if mode != Mode.PLACING:
		return {"ok": false, "error": ""}
	var result: Dictionary = SimRunner.submit(PlaceBuildingCommand.create(placing_def.id, _origin))
	if result.ok:
		cancel()
	return result


func select(building_id: int) -> void:
	var sim: Simulation = SimRunner.sim
	var b: BuildingInstance = sim.state.building_by_id(building_id)
	if b == null:
		_clear_selection()
		_set_mode(Mode.IDLE)
		return
	selected_id = building_id
	renderer.show_selection(b, sim.content.get_building(b.def_id))
	_set_mode(Mode.SELECTED)
	selection_changed.emit(building_id)


func demolish_selected() -> Dictionary:
	if selected_id < 0:
		return {"ok": false, "error": ""}
	var result: Dictionary = SimRunner.submit(DemolishCommand.create(selected_id))
	if result.ok:
		cancel()
	return result


func _process(_delta: float) -> void:
	if mode == Mode.PLACING:
		_refresh_placement(false)


func _refresh_placement(force: bool) -> void:
	if mode != Mode.PLACING or placing_def == null:
		return
	var origin: Vector2i = renderer.origin_for(camera_rig.focus, placing_def.size)
	if origin == _origin and not force:
		return
	_origin = origin
	var err: String = SimRunner.check(PlaceBuildingCommand.create(placing_def.id, origin))
	renderer.show_ghost(placing_def, origin, err == "")
	placement_updated.emit(placing_def, origin, err)


func _on_tapped(screen_pos: Vector2) -> void:
	var hit: Variant = camera_rig.ground_point(screen_pos)
	if hit == null:
		return
	var p: Vector3 = hit
	if mode == Mode.PLACING:
		camera_rig.focus_on(renderer.footprint_center(renderer.origin_for(p, placing_def.size), placing_def.size))
		return
	var id: int = SimRunner.sim.grid.building_at(renderer.world_to_cell(p))
	if id >= 0:
		select(id)
	else:
		cancel()


func _on_city_changed() -> void:
	if mode == Mode.SELECTED:
		select(selected_id)
	_refresh_placement(true)


func _clear_selection() -> void:
	selected_id = -1
	renderer.hide_selection()


func _set_mode(m: Mode) -> void:
	if m == mode and m != Mode.SELECTED:
		return
	mode = m
	if m != Mode.PLACING:
		renderer.hide_ghost()
	mode_changed.emit(m)
