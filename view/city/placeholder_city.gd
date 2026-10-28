class_name PlaceholderCity
extends Node3D
## M1 stand-in city: a procedurally laid-out diorama drawn entirely with
## MultiMesh so the scene, camera, lighting and performance budget can be
## tuned before the simulation exists. M2 replaces the layout with sim data.
## VARSAYIM: square grid, 8 m cells, 32x32 map, a road every 6th cell.

const CELL: float = 8.0
const GRID: int = 32
const ROAD_EVERY: int = 6
const BASE_DEPTH: float = 6.0
const BASE_MARGIN: float = 6.0

const FACADES: Array[Color] = [
	Color("#f2d3ae"), Color("#e59f84"), Color("#a9c49e"), Color("#9dbad6"),
	Color("#efbcbc"), Color("#dcc6a0"), Color("#f4e6cf"), Color("#c3b2d8"),
]
const TOWER_FACADES: Array[Color] = [
	Color("#a6bfd6"), Color("#8eaec8"), Color("#c6d5de"), Color("#9cbfb6"),
]
const LEAVES: Array[Color] = [
	Color("#7fae6a"), Color("#93bb6f"), Color("#6c9e64"), Color("#a7c47a"), Color("#e0a35e"),
]

@export var layout_seed: int = 20261028
## 0..1, scales how many trees are drawn (graphics quality).
@export_range(0.0, 1.0) var foliage_density: float = 1.0:
	set(value):
		foliage_density = value
		_apply_density()

var _rng := RandomNumberGenerator.new()
var _occupied: Dictionary = {} # Vector2i -> true
var _buildings: Array[Dictionary] = [] # {xform, color, custom}
var _road_tiles: Array[Dictionary] = []
var _plates: Array[Transform3D] = []
var _trees: Array[Dictionary] = [] # {pos, scale, color, conifer}
var _lamps: Array[Transform3D] = []
var _round_crowns: MultiMeshInstance3D
var _cone_crowns: MultiMeshInstance3D
var _round_trunks: MultiMeshInstance3D
var _cone_trunks: MultiMeshInstance3D


func _ready() -> void:
	_rng.seed = layout_seed
	_layout()
	_build_base()
	_build_roads()
	_build_plates()
	_build_buildings()
	_build_trees()
	_build_lamps()
	_apply_density()


func half_extent() -> float:
	return GRID * CELL * 0.5


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL - half_extent(), 0.0, (c.y + 0.5) * CELL - half_extent())


static func is_road(c: Vector2i) -> bool:
	return c.x % ROAD_EVERY == 0 or c.y % ROAD_EVERY == 0


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	for x: int in GRID:
		for z: int in GRID:
			var c := Vector2i(x, z)
			if is_road(c):
				var kind: int = 2 if (x % ROAD_EVERY == 0 and z % ROAD_EVERY == 0) else (1 if x % ROAD_EVERY == 0 else 0)
				_road_tiles.append({"pos": cell_center(c), "kind": kind})
				if kind != 2 and (x + z) % 2 == 0:
					_add_street_furniture(c, kind)
	var blocks: int = int(ceil(float(GRID) / ROAD_EVERY))
	for bx: int in blocks:
		for bz: int in blocks:
			_fill_block(Vector2i(bx * ROAD_EVERY + 1, bz * ROAD_EVERY + 1))


func _add_street_furniture(c: Vector2i, kind: int) -> void:
	var center: Vector3 = cell_center(c)
	var across: Vector3 = Vector3(0, 0, 1) if kind == 0 else Vector3(1, 0, 0)
	var side: float = 1.0 if (c.x + c.y) % 4 == 0 else -1.0
	var lamp_pos: Vector3 = center + across * 3.45 * side
	var facing: float = 0.0 if kind == 0 else PI * 0.5
	_lamps.append(Transform3D(Basis(Vector3.UP, facing + (PI if side < 0 else 0.0)), lamp_pos))
	var tree_pos: Vector3 = center - across * 3.5 * side
	_trees.append({"pos": tree_pos, "scale": _rng.randf_range(0.8, 1.05), "color": LEAVES[_rng.randi() % 4], "conifer": false})


func _fill_block(origin: Vector2i) -> void:
	var size: int = ROAD_EVERY - 1
	if origin.x + size > GRID or origin.y + size > GRID:
		size = mini(GRID - origin.x, GRID - origin.y)
	if size <= 0:
		return
	var block_center: Vector3 = cell_center(origin) + Vector3((size - 1) * CELL * 0.5, 0, (size - 1) * CELL * 0.5)
	var dist: float = block_center.length() / half_extent() # 0 center .. ~1.4 corner
	var park_chance: float = 0.12 if dist < 0.4 else 0.22
	if _rng.randf() < park_chance:
		_fill_park(origin, size)
		return
	_plates.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size * CELL - 0.6, 0.25, size * CELL - 0.6)), block_center + Vector3(0, 0.125, 0)))
	for x: int in size:
		for z: int in size:
			var c := origin + Vector2i(x, z)
			if _occupied.has(c):
				continue
			var lot: int = 2 if (x < size - 1 and z < size - 1 and _rng.randf() < (0.55 if dist < 0.5 else 0.3) and _lot_free(c, 2)) else 1
			_mark(c, lot)
			if lot == 1 and dist > 0.55 and _rng.randf() < 0.18:
				var p: Vector3 = cell_center(c)
				_trees.append({"pos": p, "scale": _rng.randf_range(0.9, 1.3), "color": LEAVES[_rng.randi() % LEAVES.size()], "conifer": _rng.randf() < 0.3})
				continue
			_add_building(c, lot, dist)


func _fill_park(origin: Vector2i, size: int) -> void:
	for x: int in size:
		for z: int in size:
			_occupied[origin + Vector2i(x, z)] = true
	var lo: Vector3 = cell_center(origin) - Vector3(CELL * 0.5, 0, CELL * 0.5)
	var extent: float = size * CELL
	var count: int = 10 + _rng.randi() % 10
	for i: int in count:
		var p := lo + Vector3(_rng.randf_range(2.0, extent - 2.0), 0, _rng.randf_range(2.0, extent - 2.0))
		# Keep the central cross path clear.
		var local: Vector3 = p - lo - Vector3(extent * 0.5, 0, extent * 0.5)
		if absf(local.x) < 2.0 or absf(local.z) < 2.0:
			continue
		_trees.append({"pos": p, "scale": _rng.randf_range(0.9, 1.6), "color": LEAVES[_rng.randi() % LEAVES.size()], "conifer": _rng.randf() < 0.35})
	var path_center: Vector3 = lo + Vector3(extent * 0.5, 0.05, extent * 0.5)
	_plates.append(Transform3D(Basis.IDENTITY.scaled(Vector3(extent - 1.0, 0.1, 2.6)), path_center))
	_plates.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.6, 0.1, extent - 1.0)), path_center))


func _lot_free(c: Vector2i, lot: int) -> bool:
	for x: int in lot:
		for z: int in lot:
			var cc := c + Vector2i(x, z)
			if _occupied.has(cc) or is_road(cc):
				return false
	return true


func _mark(c: Vector2i, lot: int) -> void:
	for x: int in lot:
		for z: int in lot:
			_occupied[c + Vector2i(x, z)] = true


func _add_building(c: Vector2i, lot: int, dist: float) -> void:
	var footprint: float = lot * CELL - 2.2
	var center: Vector3 = cell_center(c) + Vector3((lot - 1) * CELL * 0.5, 0.25, (lot - 1) * CELL * 0.5)
	var tower: bool = dist < 0.45 and lot == 2 and _rng.randf() < 0.75
	var height: float
	var color: Color
	var style: float
	if tower:
		height = _rng.randf_range(38.0, 86.0) * (1.2 - dist)
		color = TOWER_FACADES[_rng.randi() % TOWER_FACADES.size()]
		style = 2.0
	else:
		var floors: int = _rng.randi_range(2, 4) if dist > 0.7 else _rng.randi_range(3, 8)
		height = floors * 3.2 + 1.0
		color = FACADES[_rng.randi() % FACADES.size()]
		style = 1.0
	var w: float = footprint * _rng.randf_range(0.82, 1.0)
	var d: float = footprint * _rng.randf_range(0.82, 1.0)
	var garden: float = 1.0 if (not tower and _rng.randf() < 0.3) else 0.0
	var seed_v: float = _rng.randf()
	_buildings.append({"xform": _box(center, Vector3(w, height, d)), "color": color, "custom": Color(seed_v, style, garden, 0)})
	if tower and _rng.randf() < 0.7:
		# Setback crown on top of the tower.
		var h2: float = height * _rng.randf_range(0.18, 0.35)
		_buildings.append({"xform": _box(center + Vector3(0, height, 0), Vector3(w * 0.68, h2, d * 0.68)), "color": color.lightened(0.06), "custom": Color(seed_v + 0.5, style, 0.0, 0)})
	elif not tower and _rng.randf() < 0.25:
		# Small rooftop volume (stair / plant room) for silhouette variety.
		_buildings.append({"xform": _box(center + Vector3(w * 0.15, height, -d * 0.1), Vector3(w * 0.35, 2.4, d * 0.3)), "color": color.darkened(0.05), "custom": Color(seed_v, 0.0, 0.0, 0)})


static func _box(base_center: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(size), base_center + Vector3(0, size.y * 0.5, 0))


# --- Mesh building ------------------------------------------------------------

func _multimesh(mesh: Mesh, count: int, colors: bool, custom: bool, mat: Material, cast_shadows: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _shader_mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path) as Shader
	return m


func _build_base() -> void:
	var size: float = GRID * CELL + BASE_MARGIN * 2.0
	var box := BoxMesh.new()
	box.size = Vector3(size, BASE_DEPTH, size)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _shader_mat("res://assets/shaders/diorama_base.gdshader")
	mi.position = Vector3(0, -BASE_DEPTH * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_roads() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(CELL, CELL)
	var mmi: MultiMeshInstance3D = _multimesh(plane, _road_tiles.size(), false, true, _shader_mat("res://assets/shaders/road.gdshader"), false)
	for i: int in _road_tiles.size():
		var t: Dictionary = _road_tiles[i]
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, (t.pos as Vector3) + Vector3(0, 0.03, 0)))
		mmi.multimesh.set_instance_custom_data(i, Color(float(t.kind), 0, 0, 0))


func _build_plates() -> void:
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e3ddd2")
	mat.roughness = 0.95
	var mmi: MultiMeshInstance3D = _multimesh(box, _plates.size(), false, false, mat, false)
	for i: int in _plates.size():
		mmi.multimesh.set_instance_transform(i, _plates[i])


func _build_buildings() -> void:
	var box := BoxMesh.new()
	var mmi: MultiMeshInstance3D = _multimesh(box, _buildings.size(), true, true, _shader_mat("res://assets/shaders/building.gdshader"))
	for i: int in _buildings.size():
		var b: Dictionary = _buildings[i]
		mmi.multimesh.set_instance_transform(i, b.xform)
		mmi.multimesh.set_instance_color(i, b.color)
		mmi.multimesh.set_instance_custom_data(i, b.custom)


func _build_trees() -> void:
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
	# Shuffle once so lowering density thins trees evenly across the map.
	_shuffle(_trees)
	var rounds: Array[Dictionary] = []
	var cones: Array[Dictionary] = []
	for t: Dictionary in _trees:
		if t.conifer:
			cones.append(t)
		else:
			rounds.append(t)
	_round_crowns = _multimesh(round_mesh, rounds.size(), true, false, foliage)
	_cone_crowns = _multimesh(cone_mesh, cones.size(), true, false, foliage)
	_round_trunks = _multimesh(trunk_mesh, rounds.size(), false, false, trunk_mat)
	_cone_trunks = _multimesh(trunk_mesh, cones.size(), false, false, trunk_mat)
	for group: Array in [[_round_crowns, _round_trunks, rounds, 4.2], [_cone_crowns, _cone_trunks, cones, 4.4]]:
		var crowns: MultiMeshInstance3D = group[0]
		var trunks: MultiMeshInstance3D = group[1]
		var list: Array[Dictionary] = group[2]
		var crown_y: float = group[3]
		for i: int in list.size():
			var t: Dictionary = list[i]
			var s: float = t.scale
			var p: Vector3 = t.pos
			crowns.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p + Vector3(0, crown_y * s, 0)))
			crowns.multimesh.set_instance_color(i, t.color)
			trunks.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p + Vector3(0, 1.3 * s, 0)))


func _build_lamps() -> void:
	var arrays: Array = _merge_boxes([
		[Vector3(0.18, 4.6, 0.18), Vector3(0, 2.3, 0), 0.0],
		[Vector3(0.12, 0.12, 1.1), Vector3(0, 4.55, -0.5), 0.0],
		[Vector3(0.42, 0.22, 0.5), Vector3(0, 4.45, -1.0), 1.0],
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mmi: MultiMeshInstance3D = _multimesh(mesh, _lamps.size(), false, false, _shader_mat("res://assets/shaders/lamp_head.gdshader"))
	var glow_plane := PlaneMesh.new()
	glow_plane.size = Vector2(9.0, 9.0)
	var glow: MultiMeshInstance3D = _multimesh(glow_plane, _lamps.size(), false, false, _shader_mat("res://assets/shaders/lamp_glow.gdshader"), false)
	for i: int in _lamps.size():
		mmi.multimesh.set_instance_transform(i, _lamps[i])
		var head: Vector3 = _lamps[i] * Vector3(0, 0, -1.0)
		glow.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(head.x, 0.08, head.z)))


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


func _shuffle(arr: Array[Dictionary]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var tmp: Dictionary = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _apply_density() -> void:
	if _round_trunks == null:
		return
	for mmi: MultiMeshInstance3D in [_round_crowns, _cone_crowns, _round_trunks, _cone_trunks]:
		var mm: MultiMesh = mmi.multimesh
		mm.visible_instance_count = -1 if foliage_density >= 1.0 else int(ceil(mm.instance_count * foliage_density))
