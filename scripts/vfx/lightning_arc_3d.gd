class_name LightningArc3D
extends Node3D

const DURATION := 0.28
const REGEN_INTERVAL := 1.0 / 45.0
const SUBDIV_DEPTH := 4

var chain_points: PackedVector3Array = PackedVector3Array()

var _headless: bool = false
var _elapsed: float = 0.0
var _regen_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _mesh: ImmediateMesh
var _mesh_inst: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _flash_light: OmniLight3D


func setup(points: PackedVector3Array) -> void:
	chain_points = points
	if is_inside_tree() and not _headless and chain_points.size() >= 2:
		_regenerate_bolts()
		_position_flash_light()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_headless = DisplayServer.get_name() == "headless"
	_rng.randomize()

	_flash_light = OmniLight3D.new()
	_flash_light.name = "LightningFlash"
	_flash_light.light_color = Color(0.52, 0.76, 1.0)
	_flash_light.light_energy = 3.8
	_flash_light.omni_range = 7.5
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	_position_flash_light()

	if _headless:
		return

	_mesh = ImmediateMesh.new()
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "BoltMesh"
	_mesh_inst.mesh = _mesh
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_bolt_mat.vertex_color_use_as_albedo = true
	_mesh_inst.material_override = _bolt_mat
	add_child(_mesh_inst)

	if chain_points.size() >= 2:
		_regenerate_bolts()


func _position_flash_light() -> void:
	if _flash_light == null or chain_points.is_empty():
		return
	var sum := Vector3.ZERO
	for p in chain_points:
		sum += p
	_flash_light.global_position = (sum / float(chain_points.size())) + Vector3(0.0, 0.6, 0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return

	var fade := clampf(1.0 - (_elapsed / DURATION), 0.0, 1.0)
	if _flash_light != null:
		var flicker := 0.75 + 0.50 * _rng.randf()
		_flash_light.light_energy = 3.8 * fade * fade * flicker

	if _headless or chain_points.size() < 2:
		return

	_regen_timer += delta
	if _regen_timer >= REGEN_INTERVAL:
		_regen_timer = fmod(_regen_timer, REGEN_INTERVAL)
		_regenerate_bolts()


func _regenerate_bolts() -> void:
	if _mesh == null or chain_points.size() < 2:
		return
	_mesh.clear_surfaces()
	var fade := clampf(1.0 - (_elapsed / DURATION) * 0.72, 0.15, 1.0)
	var trunk_core := Color(1.8 * fade, 3.2 * fade, 6.2 * fade, 0.96 * fade)
	var trunk_halo := Color(0.16 * fade, 0.78 * fade, 4.4 * fade, 0.58 * fade)
	var branch_col := Color(0.65 * fade, 1.95 * fade, 5.8 * fade, 0.92 * fade)

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _bolt_mat)
	for i in range(chain_points.size() - 1):
		var a := chain_points[i]
		var b := chain_points[i + 1]
		var dist := a.distance_to(b)
		if dist < 0.02:
			continue
		var trunk := _subdivide_segment(a, b, dist * 0.20, SUBDIV_DEPTH)
		_emit_polyline_crossed(trunk, 0.019, trunk_core)
		_emit_polyline_crossed(trunk, 0.088, trunk_halo)

		var branch_count := _rng.randi_range(2, 3)
		for _b_i in range(branch_count):
			var pick_idx := _rng.randi_range(2, maxi(trunk.size() - 3, 2))
			if pick_idx >= trunk.size():
				continue
			var origin := trunk[pick_idx]
			var main_dir := (b - a).normalized()
			var fork_offset := Vector3(
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-0.45, 0.65),
				_rng.randf_range(-1.0, 1.0)
			).normalized()
			var fork_end := origin + (main_dir * 0.48 + fork_offset * 0.82).normalized() * (dist * _rng.randf_range(0.32, 0.58))
			var branch_pts := _subdivide_segment(origin, fork_end, dist * 0.12, 3)
			_emit_tapered_branch(branch_pts, 0.018, branch_col)
	_mesh.surface_end()


func _subdivide_segment(a: Vector3, b: Vector3, jitter: float, depth: int) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var disp := jitter
	for _d in range(depth):
		var next_pts := PackedVector3Array()
		for i in range(pts.size() - 1):
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var seg := p1 - p0
			var axis := seg.normalized()
			var ref := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
			var perp1 := axis.cross(ref).normalized()
			var perp2 := axis.cross(perp1).normalized()
			var mid := (p0 + p1) * 0.5 + perp1 * _rng.randf_range(-disp, disp) + perp2 * _rng.randf_range(-disp, disp)
			next_pts.append(p0)
			next_pts.append(mid)
		next_pts.append(pts[pts.size() - 1])
		pts = next_pts
		disp *= 0.52
	return pts


func _emit_polyline_crossed(pts: PackedVector3Array, half_w: float, col: Color) -> void:
	for i in range(pts.size() - 1):
		_emit_crossed_segment(pts[i], pts[i + 1], half_w, half_w, col, col)


func _emit_tapered_branch(pts: PackedVector3Array, start_w: float, col: Color) -> void:
	var cnt := pts.size() - 1
	if cnt <= 0:
		return
	for i in range(cnt):
		var t0 := 1.0 - float(i) / float(cnt)
		var t1 := 1.0 - float(i + 1) / float(cnt)
		var c0 := Color(col.r * t0, col.g * t0, col.b * t0, col.a * t0)
		var c1 := Color(col.r * t1, col.g * t1, col.b * t1, col.a * t1)
		_emit_crossed_segment(pts[i], pts[i + 1], start_w * t0, start_w * maxf(t1, 0.12), c0, c1)


func _emit_crossed_segment(p0: Vector3, p1: Vector3, w0: float, w1: float, c0: Color, c1: Color) -> void:
	var dir := p1 - p0
	var len_sq := dir.length_squared()
	if len_sq < 0.00001:
		return
	var axis := dir / sqrt(len_sq)
	var ref := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
	var s1 := axis.cross(ref).normalized()
	var s2 := axis.cross(s1).normalized()

	var sides: Array[Vector3] = [s1, s2]
	for side in sides:
		var a0 := p0 - side * w0
		var a1 := p0 + side * w0
		var b0 := p1 - side * w1
		var b1 := p1 + side * w1
		_mesh.surface_set_color(c0)
		_mesh.surface_add_vertex(a0)
		_mesh.surface_set_color(c0)
		_mesh.surface_add_vertex(a1)
		_mesh.surface_set_color(c1)
		_mesh.surface_add_vertex(b1)

		_mesh.surface_set_color(c0)
		_mesh.surface_add_vertex(a0)
		_mesh.surface_set_color(c1)
		_mesh.surface_add_vertex(b1)
		_mesh.surface_set_color(c1)
		_mesh.surface_add_vertex(b0)
