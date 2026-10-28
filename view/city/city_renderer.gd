class_name CityRenderer
extends Node3D
## Draws the city from SimRunner.sim: a static layer (plinth, roads, street
## furniture) built once per city, and a dynamic layer (buildings, lots, park
## trees) rebuilt whenever the city changes. Everything is MultiMesh.

const CELL: float = BuildingVisuals.CELL
const BASE_DEPTH: float = 6.0
const BASE_MARGIN: float = 6.0
const STREET_LEAVES: Array[Color] = [Color("#7fae6a"), Color("#93bb6f"), Color("#6c9e64"), Color("#a7c47a")]

## 0..1, scales how many trees are drawn (graphics quality).
@export_range(0.0, 1.0) var foliage_density: float = 1.0:
	set(value):
		foliage_density = value
		_apply_density()

var grid_size: int = 32
var road_every: int = 6

var _static_root: Node3D
var _buildings_mm: MultiMeshInstance3D
var _plates_mm: MultiMeshInstance3D
var _round_crowns: MultiMeshInstance3D
var _cone_crowns: MultiMeshInstance3D
var _round_trunks: MultiMeshInstance3D
var _cone_trunks: MultiMeshInstance3D
var _street_trees: Array[Dictionary] = []
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _selection: MeshInstance3D
var _construction_signature: int = -1


func _ready() -> void:
	_create_dynamic_layers()
	_create_overlays()
	EventBus.city_loaded.connect(_on_city_loaded)
	EventBus.city_changed.connect(rebuild)
	EventBus.tick_advanced.connect(_on_tick)
	if SimRunner.sim != null:
		_on_city_loaded()


func half_extent() -> float:
	return grid_size * CELL * 0.5


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL - half_extent(), 0.0, (c.y + 0.5) * CELL - half_extent())


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + half_extent()) / CELL), floori((p.z + half_extent()) / CELL))


## World centre of a size x size footprint whose origin cell is `c`.
func footprint_center(c: Vector2i, size: int) -> Vector3:
	return cell_center(c) + Vector3((size - 1) * CELL * 0.5, 0.0, (size - 1) * CELL * 0.5)


## Origin cell so that a size x size footprint is centred on world point p.
func origin_for(p: Vector3, size: int) -> Vector2i:
	var shift: float = (size - 1) * CELL * 0.5
	return world_to_cell(p - Vector3(shift, 0, shift))


# --- Overlays ---------------------------------------------------------------

func show_ghost(def: BuildingDef, origin: Vector2i, valid: bool) -> void:
	var height: float = float(def.visual.get("height", 6.0)) if String(def.visual.get("kind", "")) != "park" else 1.2
	var span: float = def.size * CELL - 1.0
	_ghost.scale = Vector3(span, height, span)
	_ghost.position = footprint_center(origin, def.size) + Vector3(0, height * 0.5 + 0.3, 0)
	_ghost_mat.albedo_color = Color(0.45, 0.85, 0.55, 0.45) if valid else Color(0.95, 0.4, 0.35, 0.45)
	_ghost.visible = true


func hide_ghost() -> void:
	_ghost.visible = false


func show_selection(b: BuildingInstance, def: BuildingDef) -> void:
	var span: float = def.size * CELL - 0.2
	_selection.scale = Vector3(span, 1.0, span)
	_selection.position = footprint_center(b.cell, def.size) + Vector3(0, 0.32, 0)
	_selection.visible = true


func hide_selection() -> void:
	_selection.visible = false


# --- City lifecycle ----------------------------------------------------------

func _on_city_loaded() -> void:
	var s: SimState = SimRunner.sim.state
	grid_size = s.grid_size
	road_every = s.road_every
	_build_static()
	rebuild()


func _on_tick(_tick: int) -> void:
	# Re-draw only when some construction visibly advanced.
	var sig: int = _construction_progress_signature()
	if sig != _construction_signature:
		rebuild()


func rebuild() -> void:
	var sim: Simulation = SimRunner.sim
	if sim == null:
		return
	var boxes: Array = []
	var plates: Array = []
	var trees: Array = _street_trees.duplicate()
	for b: BuildingInstance in sim.state.buildings:
		var def: BuildingDef = sim.content.get_building(b.def_id)
		if def == null:
			continue
		var parts: Dictionary = BuildingVisuals.build(b, def, sim.state.tick, cell_center(b.cell))
		boxes.append_array(parts.boxes)
		plates.append_array(parts.plates)
		trees.append_array(parts.trees)
	_fill_boxes(_buildings_mm, boxes)
	_fill_plates(plates)
	_fill_trees(trees)
	_construction_signature = _construction_progress_signature()


func _construction_progress_signature() -> int:
	var sim: Simulation = SimRunner.sim
	var sig: int = 0
	for b: BuildingInstance in sim.state.buildings:
		if not b.is_complete(sim.state.tick):
			# 5 % steps are plenty for the scaffold to visibly grow.
			sig = SimRng.mix32(sig ^ (b.id * 31 + int(BuildingVisuals.construction_progress(b, sim.state.tick) * 20.0)))
	return sig


# --- Static layer ------------------------------------------------------------

func _build_static() -> void:
	if _static_root != null:
		_static_root.queue_free()
	_static_root = Node3D.new()
	_static_root.name = "Static"
	add_child(_static_root)
	_street_trees.clear()
	var road_tiles: Array[Dictionary] = []
	var lamps: Array[Transform3D] = []
	for x: int in grid_size:
		for z: int in grid_size:
			var c := Vector2i(x, z)
			var on_x: bool = x % road_every == 0
			var on_z: bool = z % road_every == 0
			if not (on_x or on_z):
				continue
			var kind: int = 2 if (on_x and on_z) else (1 if on_x else 0)
			road_tiles.append({"pos": cell_center(c), "kind": kind})
			if kind != 2 and (x + z) % 2 == 0:
				_add_street_furniture(c, kind, lamps)
	_build_base()
	_build_roads(road_tiles)
	_build_lamps(lamps)


func _add_street_furniture(c: Vector2i, kind: int, lamps: Array[Transform3D]) -> void:
	var center: Vector3 = cell_center(c)
	var across: Vector3 = Vector3(0, 0, 1) if kind == 0 else Vector3(1, 0, 0)
	var side: float = 1.0 if (c.x + c.y) % 4 == 0 else -1.0
	var facing: float = 0.0 if kind == 0 else PI * 0.5
	lamps.append(Transform3D(Basis(Vector3.UP, facing + (PI if side < 0 else 0.0)), center + across * 3.45 * side))
	var h: int = SimRng.mix32(c.x * 73856093 ^ c.y * 19349663)
	_street_trees.append({"pos": center - across * 3.5 * side, "scale": 0.8 + (h & 0xFF) / 255.0 * 0.25, "color": STREET_LEAVES[(h >> 8) % STREET_LEAVES.size()], "conifer": false})


func _build_base() -> void:
	var size: float = grid_size * CELL + BASE_MARGIN * 2.0
	var box := BoxMesh.new()
	box.size = Vector3(size, BASE_DEPTH, size)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _shader_mat("res://assets/shaders/diorama_base.gdshader")
	mi.position = Vector3(0, -BASE_DEPTH * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_static_root.add_child(mi)


func _build_roads(tiles: Array[Dictionary]) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(CELL, CELL)
	var mmi: MultiMeshInstance3D = _multimesh(_static_root, plane, false, true, _shader_mat("res://assets/shaders/road.gdshader"), false)
	mmi.multimesh.instance_count = tiles.size()
	for i: int in tiles.size():
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, (tiles[i].pos as Vector3) + Vector3(0, 0.03, 0)))
		mmi.multimesh.set_instance_custom_data(i, Color(float(tiles[i].kind), 0, 0, 0))


func _build_lamps(lamps: Array[Transform3D]) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _merge_boxes([
		[Vector3(0.18, 4.6, 0.18), Vector3(0, 2.3, 0), 0.0],
		[Vector3(0.12, 0.12, 1.1), Vector3(0, 4.55, -0.5), 0.0],
		[Vector3(0.42, 0.22, 0.5), Vector3(0, 4.45, -1.0), 1.0],
	]))
	var poles: MultiMeshInstance3D = _multimesh(_static_root, mesh, false, false, _shader_mat("res://assets/shaders/lamp_head.gdshader"))
	var glow_plane := PlaneMesh.new()
	glow_plane.size = Vector2(9.0, 9.0)
	var glow: MultiMeshInstance3D = _multimesh(_static_root, glow_plane, false, false, _shader_mat("res://assets/shaders/lamp_glow.gdshader"), false)
	poles.multimesh.instance_count = lamps.size()
	glow.multimesh.instance_count = lamps.size()
	for i: int in lamps.size():
		poles.multimesh.set_instance_transform(i, lamps[i])
		var head: Vector3 = lamps[i] * Vector3(0, 0, -1.0)
		glow.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(head.x, 0.08, head.z)))


# --- Dynamic layer -----------------------------------------------------------

func _create_dynamic_layers() -> void:
	_buildings_mm = _multimesh(self, BoxMesh.new(), true, true, _shader_mat("res://assets/shaders/building.gdshader"))
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color("#e3ddd2")
	plate_mat.roughness = 0.95
	_plates_mm = _multimesh(self, BoxMesh.new(), false, false, plate_mat, false)
	var foliage: ShaderMaterial = _shader_mat("res://assets/shaders/foliage.gdshader")
	var round_mesh := SphereMesh.new()
	round_mesh.radius = 2.2
	round_mesh.height = 3.8
	round_mesh.radial_segments = 7
	round_mesh.rings = 3
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 1.9
	cone_mesh.height = 5.5
	cone_mesh.radial_segments = 6
	cone_mesh.rings = 1
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 2.6
	trunk_mesh.radial_segments = 5
	trunk_mesh.rings = 1
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("#8a6a55")
	trunk_mat.roughness = 1.0
	_round_crowns = _multimesh(self, round_mesh, true, false, foliage)
	_cone_crowns = _multimesh(self, cone_mesh, true, false, foliage)
	_round_trunks = _multimesh(self, trunk_mesh, false, false, trunk_mat)
	_cone_trunks = _multimesh(self, trunk_mesh, false, false, trunk_mat)


func _create_overlays() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Always visible, even behind towers: the player must see where it lands.
	_ghost_mat.no_depth_test = true
	_ghost_mat.render_priority = 10
	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	var sel_mat := StandardMaterial3D.new()
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sel_mat.albedo_color = Color(1.0, 0.78, 0.35, 0.55)
	var sel_mesh := PlaneMesh.new()
	sel_mesh.size = Vector2.ONE
	_selection = MeshInstance3D.new()
	_selection.mesh = sel_mesh
	_selection.material_override = sel_mat
	_selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection.visible = false
	add_child(_selection)


func _fill_boxes(mmi: MultiMeshInstance3D, boxes: Array) -> void:
	var mm: MultiMesh = mmi.multimesh
	mm.instance_count = boxes.size()
	for i: int in boxes.size():
		var b: Dictionary = boxes[i]
		mm.set_instance_transform(i, b.xform)
		mm.set_instance_color(i, b.color)
		mm.set_instance_custom_data(i, b.custom)


func _fill_plates(plates: Array) -> void:
	var mm: MultiMesh = _plates_mm.multimesh
	mm.instance_count = plates.size()
	for i: int in plates.size():
		mm.set_instance_transform(i, plates[i])


func _fill_trees(trees: Array) -> void:
	var rounds: Array = []
	var cones: Array = []
	for t: Dictionary in trees:
		(cones if t.conifer else rounds).append(t)
	# Stable interleaved order so lowering density thins trees evenly.
	rounds.sort_custom(_tree_order)
	cones.sort_custom(_tree_order)
	for group: Array in [[_round_crowns, _round_trunks, rounds, 4.2], [_cone_crowns, _cone_trunks, cones, 4.4]]:
		var crowns: MultiMesh = (group[0] as MultiMeshInstance3D).multimesh
		var trunks: MultiMesh = (group[1] as MultiMeshInstance3D).multimesh
		var list: Array = group[2]
		var crown_y: float = group[3]
		crowns.instance_count = list.size()
		trunks.instance_count = list.size()
		for i: int in list.size():
			var t: Dictionary = list[i]
			var s: float = t.scale
			var p: Vector3 = t.pos
			var spin: float = float(SimRng.mix32(int(p.x * 13.0) ^ int(p.z * 7.0)) & 0xFFFF) / 65535.0 * TAU
			crowns.set_instance_transform(i, Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * s), p + Vector3(0, crown_y * s, 0)))
			crowns.set_instance_color(i, t.color)
			trunks.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p + Vector3(0, 1.3 * s, 0)))
	_apply_density()


static func _tree_order(a: Dictionary, b: Dictionary) -> bool:
	return _tree_key(a) < _tree_key(b)


static func _tree_key(t: Dictionary) -> int:
	var p: Vector3 = t.pos
	return SimRng.mix32(int(p.x * 10.0) * 92821 ^ int(p.z * 10.0))


func _apply_density() -> void:
	if _round_trunks == null:
		return
	for mmi: MultiMeshInstance3D in [_round_crowns, _cone_crowns, _round_trunks, _cone_trunks]:
		var mm: MultiMesh = mmi.multimesh
		mm.visible_instance_count = -1 if foliage_density >= 1.0 else int(ceil(mm.instance_count * foliage_density))


# --- Helpers -----------------------------------------------------------------

func _multimesh(parent: Node, mesh: Mesh, colors: bool, custom: bool, mat: Material, cast_shadows: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


func _shader_mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path) as Shader
	return m


## Merges axis-aligned boxes into one mesh; the third value becomes vertex color alpha.
static func _merge_boxes(parts: Array) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[0]
		var a: Array = box.get_mesh_arrays()
		var base: int = verts.size()
		for v: Vector3 in a[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			verts.append(v + (part[1] as Vector3))
			colors.append(Color(1, 1, 1, float(part[2])))
		normals.append_array(a[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		for idx: int in a[Mesh.ARRAY_INDEX] as PackedInt32Array:
			indices.append(base + idx)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	return out
