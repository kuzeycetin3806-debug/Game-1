class_name StreetLife
extends Node3D
## Cars, pedestrians and a tram moving through the diorama. Purely visual:
## counts follow population, time of day and weather; positions are a pure
## function of time (LifeMath), written straight into MultiMesh buffers.

const CELL: float = BuildingVisuals.CELL
const STRIDE: int = 16 # 12 transform floats + 4 colour/custom floats
const UPDATE_COUNTS_EVERY: float = 1.0

@export var renderer: CityRenderer
@export_file("*.json") var config_path: String = "res://data/environment/life.json"

## 0 = low, 1 = medium, 2 = high (set by GraphicsQuality).
var quality: int = 2:
	set(value):
		quality = clampi(value, 0, 2)
		_allocate()

var cfg: Dictionary = {}
var car_count: int = 0
var ped_count: int = 0
var tram_active: bool = false

var _cars: MultiMeshInstance3D
var _peds: MultiMeshInstance3D
var _tram: MultiMeshInstance3D
var _rails: MultiMeshInstance3D
var _car_buf := PackedFloat32Array()
var _ped_buf := PackedFloat32Array()
var _tram_buf := PackedFloat32Array()
var _lines: Array[Dictionary] = [] # {axis: "x"|"z", coord: float}
var _tram_line: int = -1
var _half: float = 128.0
var _count_timer: float = 0.0
var _car_colors: Array[Color] = []
var _people_colors: Array[Color] = []


func _ready() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	cfg = d if d is Dictionary else {}
	for c: Variant in cfg.get("car_colors", ["#ffffff"]):
		_car_colors.append(Color.html(String(c)))
	for c: Variant in cfg.get("people_colors", ["#ffffff"]):
		_people_colors.append(Color.html(String(c)))
	_cars = _make_mm(_car_mesh(), false, true, _shader("res://assets/shaders/vehicle.gdshader"))
	_tram = _make_mm(_tram_mesh(), false, true, _shader("res://assets/shaders/vehicle.gdshader"))
	var people_mat := StandardMaterial3D.new()
	people_mat.vertex_color_use_as_albedo = true
	people_mat.roughness = 0.9
	var person := CapsuleMesh.new()
	person.radius = 0.28
	person.height = 1.7
	person.radial_segments = 6
	person.rings = 1
	_peds = _make_mm(person, true, false, people_mat)
	_peds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color("#5a5e66")
	rail_mat.metallic = 0.6
	rail_mat.roughness = 0.4
	_rails = _make_mm(BoxMesh.new(), false, false, rail_mat)
	_rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	EventBus.city_loaded.connect(_rebuild_routes)
	_rebuild_routes()
	_allocate()


func _rebuild_routes() -> void:
	_lines.clear()
	var grid: int = renderer.grid_size
	var every: int = renderer.road_every
	_half = renderer.half_extent()
	for i: int in range(0, grid, every):
		var coord: float = renderer.cell_center(Vector2i(i, i)).x
		_lines.append({"axis": "x", "coord": coord}) # runs along X at z = coord
		_lines.append({"axis": "z", "coord": coord}) # runs along Z at x = coord
	# Tram on the X-axis avenue closest to the centre.
	var best: float = INF
	for i: int in _lines.size():
		if String(_lines[i].axis) == "x" and absf(float(_lines[i].coord)) < best:
			best = absf(float(_lines[i].coord))
			_tram_line = i
	_build_rails()


func _allocate() -> void:
	if _cars == null:
		return
	var car_max: int = int((cfg.get("cars", {}) as Dictionary).get("max", [40, 90, 160])[quality])
	var ped_max: int = int((cfg.get("pedestrians", {}) as Dictionary).get("max", [50, 120, 220])[quality])
	var tram_cars: int = int((cfg.get("tram", {}) as Dictionary).get("cars", 3))
	_cars.multimesh.instance_count = car_max
	_peds.multimesh.instance_count = ped_max
	_tram.multimesh.instance_count = tram_cars
	_car_buf.resize(car_max * STRIDE)
	_ped_buf.resize(ped_max * STRIDE)
	_tram_buf.resize(tram_cars * STRIDE)
	_update_counts()


func _process(delta: float) -> void:
	_count_timer += delta
	if _count_timer >= UPDATE_COUNTS_EVERY:
		_count_timer = 0.0
		_update_counts()
	var t: float = Time.get_ticks_msec() / 1000.0
	_write_cars(t)
	_write_peds(t)
	_write_tram(t)


func _update_counts() -> void:
	var sim: Simulation = SimRunner.sim
	if sim == null or _lines.is_empty():
		return
	var minute: float = fposmod(Clock.local_hour_float() * 60.0, 1440.0)
	var w: Dictionary = (cfg.get("weather", {}) as Dictionary).get(sim.state.weather, {})
	var cc: Dictionary = cfg.get("cars", {})
	var pc: Dictionary = cfg.get("pedestrians", {})
	car_count = LifeMath.count(_cars.multimesh.instance_count, int(cc.get("base", 12)), int(cc.get("per_residents", 6)),
		sim.state.population, TrafficSystem.demand(int(minute), sim.content), float(w.get("cars", 1.0)))
	ped_count = LifeMath.count(_peds.multimesh.instance_count, int(pc.get("base", 14)), int(pc.get("per_residents", 4)),
		sim.state.population, LifeMath.curve(cfg.get("pedestrian_curve", []), minute), float(w.get("pedestrians", 1.0)))
	tram_active = sim.state.population >= int((cfg.get("tram", {}) as Dictionary).get("min_population", 150)) and _tram_line >= 0
	_cars.multimesh.visible_instance_count = car_count
	_peds.multimesh.visible_instance_count = ped_count
	_tram.visible = tram_active
	_rails.visible = tram_active


func _write_cars(t: float) -> void:
	if car_count == 0:
		return
	var cc: Dictionary = cfg.get("cars", {})
	var speed_range: Array = cc.get("speed", [9.0, 14.0])
	var lane: float = float(cc.get("lane_offset", 1.25))
	var length: float = _half * 2.0
	var n_lines: int = _lines.size()
	for i: int in car_count:
		var line_idx: int = int(LifeMath.rand01(i, 2) * n_lines)
		if line_idx == _tram_line and tram_active:
			line_idx = (line_idx + 1) % n_lines
		var dir: int = 1 if LifeMath.rand01(i, 3) < 0.5 else -1
		var speed: float = lerpf(float(speed_range[0]), float(speed_range[1]), LifeMath.rand01(i, 4))
		var s: float = LifeMath.along(i, t, length, speed, dir) - _half
		var color: Color = _car_colors[int(LifeMath.rand01(i, 5) * _car_colors.size())]
		_put(_car_buf, i, _lines[line_idx], s, lane * dir, 0.0, dir, color)
	_cars.multimesh.buffer = _car_buf


func _write_peds(t: float) -> void:
	if ped_count == 0:
		return
	var pc: Dictionary = cfg.get("pedestrians", {})
	var speed_range: Array = pc.get("speed", [1.1, 1.7])
	var side_off: float = float(pc.get("sidewalk_offset", 3.55))
	var length: float = _half * 2.0
	var n_lines: int = _lines.size()
	for i: int in ped_count:
		var line_idx: int = int(LifeMath.rand01(i, 12) * n_lines)
		var dir: int = 1 if LifeMath.rand01(i, 13) < 0.5 else -1
		var side: float = 1.0 if LifeMath.rand01(i, 14) < 0.5 else -1.0
		var speed: float = lerpf(float(speed_range[0]), float(speed_range[1]), LifeMath.rand01(i, 15))
		var s: float = LifeMath.along(i + 10007, t, length, speed, dir) - _half
		var bob: float = absf(sin(t * speed * 5.0 + float(i))) * 0.06
		var color: Color = _people_colors[int(LifeMath.rand01(i, 16) * _people_colors.size())]
		_put(_ped_buf, i, _lines[line_idx], s, side * side_off + (LifeMath.rand01(i, 17) - 0.5) * 0.6, 0.85 + 0.25 + bob, dir, color)
	_peds.multimesh.buffer = _ped_buf


func _write_tram(t: float) -> void:
	if not tram_active:
		return
	var tc: Dictionary = cfg.get("tram", {})
	var cars: int = _tram.multimesh.instance_count
	var seg: float = float(tc.get("length", 11.0)) + float(tc.get("gap", 0.8))
	var span: float = _half * 2.0 - cars * seg - 8.0
	var pp: Dictionary = LifeMath.ping_pong(t, span, float(tc.get("speed", 7.5)), float(tc.get("dwell_seconds", 6.0)))
	var head: float = float(pp.pos) - span * 0.5
	for i: int in cars:
		var s: float = head - i * seg * int(pp.dir)
		_put(_tram_buf, i, _lines[_tram_line], s, 0.0, 0.0, int(pp.dir), Color("#3aa69b") if i % 2 == 0 else Color("#f4efe6"))
	_tram.multimesh.buffer = _tram_buf


## Writes one instance: position `s` along the line, `offset` across it, facing `dir`.
func _put(buf: PackedFloat32Array, i: int, line: Dictionary, s: float, offset: float, y: float, dir: int, color: Color) -> void:
	var o: int = i * STRIDE
	var along_x: bool = String(line.axis) == "x"
	var coord: float = float(line.coord)
	var px: float = s if along_x else coord + offset
	var pz: float = coord + offset if along_x else s
	# Meshes are modelled facing -Z. Rotate so -Z points along the travel direction.
	var fx: float = (1.0 if along_x else 0.0) * dir
	var fz: float = (0.0 if along_x else 1.0) * dir
	# basis columns: x = right, y = up, z = back (= -forward)
	var bx := Vector3(-fz, 0.0, fx)
	var bz := Vector3(-fx, 0.0, -fz)
	buf[o + 0] = bx.x
	buf[o + 1] = 0.0
	buf[o + 2] = bz.x
	buf[o + 3] = px
	buf[o + 4] = bx.y
	buf[o + 5] = 1.0
	buf[o + 6] = bz.y
	buf[o + 7] = y
	buf[o + 8] = bx.z
	buf[o + 9] = 0.0
	buf[o + 10] = bz.z
	buf[o + 11] = pz
	buf[o + 12] = color.r
	buf[o + 13] = color.g
	buf[o + 14] = color.b
	buf[o + 15] = 1.0


func _build_rails() -> void:
	if _tram_line < 0:
		return
	var line: Dictionary = _lines[_tram_line]
	var mm: MultiMesh = _rails.multimesh
	mm.instance_count = 2
	for k: int in 2:
		var off: float = -0.75 if k == 0 else 0.75
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(_half * 2.0, 0.08, 0.14)), Vector3(0.0, 0.07, float(line.coord) + off)))


func _make_mm(mesh: Mesh, colors: bool, custom: bool, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


func _shader(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path) as Shader
	return m


## Body, cabin glass and lights as boxes with mask colours (see vehicle.gdshader).
static func _car_mesh() -> ArrayMesh:
	return _boxes([
		[Vector3(1.8, 0.75, 4.0), Vector3(0, 0.55, 0), Color(0, 0, 0)],
		[Vector3(1.6, 0.6, 2.1), Vector3(0, 1.2, 0.25), Color(1, 0, 0)],
		[Vector3(1.5, 0.22, 0.08), Vector3(0, 0.62, -2.02), Color(0, 1, 0)],
		[Vector3(1.5, 0.2, 0.08), Vector3(0, 0.66, 2.02), Color(0, 0, 1)],
	])


static func _tram_mesh() -> ArrayMesh:
	return _boxes([
		[Vector3(2.5, 0.5, 11.0), Vector3(0, 0.55, 0), Color(0, 0, 0)],
		[Vector3(2.5, 1.4, 11.0), Vector3(0, 1.5, 0), Color(1, 0, 0)],
		[Vector3(2.5, 0.5, 11.0), Vector3(0, 2.45, 0), Color(0, 0, 0)],
		[Vector3(0.3, 0.9, 0.3), Vector3(0, 3.1, 0), Color(0, 0, 0)],
	])


static func _boxes(parts: Array) -> ArrayMesh:
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
			colors.append(part[2] as Color)
		normals.append_array(a[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		for idx: int in a[Mesh.ARRAY_INDEX] as PackedInt32Array:
			indices.append(base + idx)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
