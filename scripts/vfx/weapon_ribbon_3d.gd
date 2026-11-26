class_name WeaponRibbon3D
extends Node3D

const MAX_SAMPLES := 14
const SAMPLE_LIFETIME := 0.24
const SUBDIVISIONS := 2

var ribbon_tint: Color = Color(0.85, 0.88, 0.96, 0.85)

var _headless: bool = false
var _mesh: ImmediateMesh
var _mesh_inst: MeshInstance3D
var _mat: ShaderMaterial
var _samples: Array[Dictionary] = []
var _dirty: bool = false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return

	_mesh = ImmediateMesh.new()
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "RibbonMesh"
	_mesh_inst.mesh = _mesh
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var sh := load("res://shaders/vfx_ribbon.gdshader") as Shader
	if sh != null:
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("ribbon_tint", ribbon_tint)
		var warm_edge := Vector3(
			maxf(ribbon_tint.r * 2.8, 1.4),
			maxf(ribbon_tint.g * 2.1, 1.0),
			maxf(ribbon_tint.b * 1.6, 0.7)
		)
		_mat.set_shader_parameter("edge_hdr", warm_edge)
		_mesh_inst.material_override = _mat

	add_child(_mesh_inst)


func set_tint(tint: Color) -> void:
	ribbon_tint = tint
	if _mat != null:
		_mat.set_shader_parameter("ribbon_tint", ribbon_tint)
		_mat.set_shader_parameter("edge_hdr", Vector3(
			maxf(ribbon_tint.r * 2.8, 1.4),
			maxf(ribbon_tint.g * 2.1, 1.0),
			maxf(ribbon_tint.b * 1.6, 0.7)
		))


func push_sample(base_world: Vector3, tip_world: Vector3, emitting: bool) -> void:
	if not emitting:
		return
	if _samples.size() > 0:
		var newest: Dictionary = _samples[0]
		var prev_tip: Vector3 = newest["tip"]
		var prev_base: Vector3 = newest["base"]
		if prev_tip.distance_squared_to(tip_world) < 0.0002 and prev_base.distance_squared_to(base_world) < 0.0002:
			return
	_samples.push_front({"base": base_world, "tip": tip_world, "age": 0.0})
	while _samples.size() > MAX_SAMPLES:
		_samples.pop_back()
	_dirty = true


func _process(delta: float) -> void:
	if _samples.is_empty():
		if _dirty:
			_dirty = false
			if not _headless:
				_rebuild_ribbon()
		return
	var i := _samples.size() - 1
	while i >= 0:
		var a := float(_samples[i]["age"]) + delta / SAMPLE_LIFETIME
		if a >= 1.0:
			_samples.remove_at(i)
		else:
			_samples[i]["age"] = a
		i -= 1
	_dirty = false
	if not _headless:
		_rebuild_ribbon()


static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _rebuild_ribbon() -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	var n := _samples.size()
	if n < 2:
		return

	var bases: Array[Vector3] = []
	var tips: Array[Vector3] = []
	var ages: Array[float] = []

	for idx in range(n - 1):
		var i0 := maxi(idx - 1, 0)
		var i1 := idx
		var i2 := idx + 1
		var i3 := mini(idx + 2, n - 1)
		var b0: Vector3 = _samples[i0]["base"]
		var b1: Vector3 = _samples[i1]["base"]
		var b2: Vector3 = _samples[i2]["base"]
		var b3: Vector3 = _samples[i3]["base"]
		var t0: Vector3 = _samples[i0]["tip"]
		var t1: Vector3 = _samples[i1]["tip"]
		var t2: Vector3 = _samples[i2]["tip"]
		var t3: Vector3 = _samples[i3]["tip"]
		var a1: float = _samples[i1]["age"]
		var a2: float = _samples[i2]["age"]

		var steps := SUBDIVISIONS if n >= 3 else 1
		for s in range(steps):
			var frac := float(s) / float(steps)
			bases.append(_catmull_rom(b0, b1, b2, b3, frac))
			tips.append(_catmull_rom(t0, t1, t2, t3, frac))
			ages.append(lerpf(a1, a2, frac))

	bases.append(_samples[n - 1]["base"])
	tips.append(_samples[n - 1]["tip"])
	ages.append(float(_samples[n - 1]["age"]))

	var total := bases.size()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for k in range(total):
		var rank_u := float(k) / float(maxi(total - 1, 1))
		var u := clampf(maxf(rank_u, ages[k]), 0.0, 1.0)
		var col := Color(1.0, 1.0, 1.0, 1.0 - u * 0.65)
		_mesh.surface_set_color(col)
		_mesh.surface_set_uv(Vector2(u, 0.0))
		_mesh.surface_add_vertex(bases[k])
		_mesh.surface_set_color(col)
		_mesh.surface_set_uv(Vector2(u, 1.0))
		_mesh.surface_add_vertex(tips[k])
	_mesh.surface_end()
