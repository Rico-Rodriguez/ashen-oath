class_name VfxTelegraph3D
extends Node3D

var duration: float = 0.65
var _elapsed: float = 0.0
var _mat: ShaderMaterial
var _headless: bool = false


func configure_circle(pos: Vector3, radius: float, dur: float, color: Color) -> void:
	duration = maxf(dur, 0.05)
	position = Vector3(pos.x, pos.y + 0.03, pos.z)
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	var r := maxf(radius, 0.25)
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2.15, r * 2.15)
	_build_mesh(pm, 0, color)
	if _mat != null:
		_mat.set_shader_parameter("radius_m", r)


func configure_cone(pos: Vector3, forward: Vector3, range_m: float, angle_deg: float, dur: float, color: Color) -> void:
	duration = maxf(dur, 0.05)
	position = Vector3(pos.x, pos.y + 0.03, pos.z)
	_orient_forward(forward)
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	var r := maxf(range_m, 0.4)
	var half_rad := deg_to_rad(clampf(angle_deg * 0.5, 5.0, 175.0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2.2, r * 2.2)
	_build_mesh(pm, 1, color)
	if _mat != null:
		_mat.set_shader_parameter("radius_m", r)
		_mat.set_shader_parameter("cone_half_angle_rad", half_rad)


func configure_line(pos: Vector3, forward: Vector3, length_m: float, width_m: float, dur: float, color: Color) -> void:
	duration = maxf(dur, 0.05)
	position = Vector3(pos.x, pos.y + 0.03, pos.z)
	_orient_forward(forward)
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	var len_clamped := maxf(length_m, 0.4)
	var wid_clamped := maxf(width_m, 0.25)
	var pm := PlaneMesh.new()
	pm.size = Vector2(wid_clamped + 0.3, len_clamped + 0.3)
	pm.center_offset = Vector3(0.0, 0.0, -len_clamped * 0.5)
	_build_mesh(pm, 2, color)
	if _mat != null:
		_mat.set_shader_parameter("line_size", Vector2(wid_clamped, len_clamped))


func set_progress(p: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress", clampf(p, 0.0, 1.0))


func _orient_forward(forward: Vector3) -> void:
	var f := Vector3(forward.x, 0.0, forward.z)
	if f.length_squared() < 0.0001:
		f = Vector3.FORWARD
	else:
		f = f.normalized()
	basis = Basis.looking_at(f, Vector3.UP)


func _build_mesh(pm: PlaneMesh, kind: int, color: Color) -> void:
	var sh := load("res://shaders/vfx_telegraph.gdshader") as Shader
	if sh == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("shape_kind", kind)
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("base_color", color)

	var mi := MeshInstance3D.new()
	mi.name = "TelegraphDecal"
	mi.mesh = pm
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(delta: float) -> void:
	_elapsed += delta
	var p := clampf(_elapsed / duration, 0.0, 1.0)
	if _mat != null:
		_mat.set_shader_parameter("progress", p)
	if _elapsed >= duration + 0.05:
		queue_free()
