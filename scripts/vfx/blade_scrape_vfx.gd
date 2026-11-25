class_name BladeScrapeVfx
extends Node3D

const SFX_INTERVAL := 0.18
const STREAK_LIFETIME := 0.58
const MAX_STREAK_POINTS := 28

var _headless: bool = false
var _sparks: GPUParticles3D
var _proc_mat: ParticleProcessMaterial
var _light: OmniLight3D
var _contact_flare: MeshInstance3D
var _streak_mi: MeshInstance3D
var _streak_mesh: ImmediateMesh
var _streak_mat: StandardMaterial3D
var _streak_points: Array[Dictionary] = []

var _prev_tip: Vector3 = Vector3.ZERO
var _has_prev_tip: bool = false
var _last_update_usec: int = 0
var _sfx_cooldown: float = 0.0
var _active_scraping: bool = false
var _time_acc: float = 0.0


static func make_crossed_spark_mesh(width: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hl := length * 0.5
	var planes: Array[Vector3] = [Vector3(hw, 0.0, 0.0), Vector3(0.0, 0.0, hw)]
	for axis in planes:
		var p0 := -axis + Vector3(0.0, hl, 0.0)
		var p1 := axis + Vector3(0.0, hl, 0.0)
		var p2 := axis - Vector3(0.0, hl, 0.0)
		var p3 := -axis - Vector3(0.0, hl, 0.0)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(p1)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p2)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p2)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p3)
	return st.commit()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_headless = DisplayServer.get_name() == "headless"

	_light = OmniLight3D.new()
	_light.name = "ScrapeLight"
	_light.light_color = Color(1.0, 0.58, 0.20)
	_light.light_energy = 0.0
	_light.omni_range = 3.2
	_light.shadow_enabled = false
	add_child(_light)

	if _headless:
		return

	_proc_mat = ParticleProcessMaterial.new()
	_proc_mat.particle_flag_align_y = true
	_proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_proc_mat.emission_sphere_radius = 0.06
	_proc_mat.direction = Vector3(0.0, 0.65, 1.0).normalized()
	_proc_mat.spread = 38.0
	_proc_mat.initial_velocity_min = 4.6
	_proc_mat.initial_velocity_max = 10.6
	_proc_mat.gravity = Vector3(0.0, -13.5, 0.0)
	_proc_mat.damping_min = 1.2
	_proc_mat.damping_max = 2.6
	_proc_mat.scale_min = 0.85
	_proc_mat.scale_max = 1.55

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.80, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.96, 0.82, 1.0),
		Color(1.0, 0.62, 0.16, 0.95),
		Color(0.95, 0.24, 0.04, 0.65),
		Color(0.4, 0.05, 0.01, 0.0),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	_proc_mat.color_ramp = grad_tex

	var spark_mesh := make_crossed_spark_mesh(0.095, 0.44)
	var spark_sh := load("res://shaders/vfx_spark.gdshader") as Shader
	var spark_mat: Material
	if spark_sh != null:
		var sm := ShaderMaterial.new()
		sm.shader = spark_sh
		sm.render_priority = 3
		sm.set_shader_parameter("spark_hdr", Vector4(5.5, 2.3, 0.45, 1.0))
		spark_mat = sm
	else:
		var std := StandardMaterial3D.new()
		std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
		std.vertex_color_use_as_albedo = true
		std.albedo_color = Color(5.5, 2.3, 0.45, 1.0)
		spark_mat = std
	spark_mesh.surface_set_material(0, spark_mat)

	_sparks = GPUParticles3D.new()
	_sparks.name = "ScrapeSparks"
	_sparks.amount = 160
	_sparks.lifetime = 0.45
	_sparks.explosiveness = 0.0
	_sparks.randomness = 0.45
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.process_material = _proc_mat
	_sparks.draw_pass_1 = spark_mesh
	add_child(_sparks)

	_contact_flare = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.08
	sphere.radial_segments = 10
	sphere.rings = 6
	_contact_flare.mesh = sphere
	var flare_mat := StandardMaterial3D.new()
	flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flare_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flare_mat.albedo_color = Color(5.5, 2.3, 0.45, 0.88)
	_contact_flare.material_override = flare_mat
	_contact_flare.visible = false
	add_child(_contact_flare)

	_streak_mesh = ImmediateMesh.new()
	_streak_mi = MeshInstance3D.new()
	_streak_mi.name = "EmberGroundStreaks"
	_streak_mi.mesh = _streak_mesh
	_streak_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_streak_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_streak_mat.vertex_color_use_as_albedo = true
	_streak_mi.material_override = _streak_mat
	add_child(_streak_mi)


func update_scrape(blade_tip_world: Vector3, ground_y: float, is_dragging: bool, velocity_world: Vector3) -> void:
	var now_usec := Time.get_ticks_usec()
	var dt := clampf(float(now_usec - _last_update_usec) * 0.000001, 0.004, 0.1) if _last_update_usec > 0 else 0.016
	_last_update_usec = now_usec

	var tip_vel := Vector3.ZERO
	if _has_prev_tip:
		tip_vel = (blade_tip_world - _prev_tip) / dt
	_prev_tip = blade_tip_world
	_has_prev_tip = true

	var horiz_vel := Vector3(velocity_world.x, 0.0, velocity_world.z)
	var tip_horiz := Vector3(tip_vel.x, 0.0, tip_vel.z)
	var effective_horiz := horiz_vel if horiz_vel.length() >= tip_horiz.length() else tip_horiz
	var speed := effective_horiz.length()

	var scraping := is_dragging and speed > 0.4 and blade_tip_world.y <= ground_y + 0.85
	_active_scraping = scraping

	if scraping:
		var contact := Vector3(blade_tip_world.x, ground_y + 0.04, blade_tip_world.z)
		if _light != null:
			_light.global_position = contact + Vector3(0.0, 0.18, 0.0)
			var flicker := 0.84 + 0.32 * absf(sin(_time_acc * 31.0 + cos(_time_acc * 17.0)))
			_light.light_energy = 2.2 * flicker

		if not _headless and _sparks != null:
			_sparks.global_position = contact
			var spray_dir := (-effective_horiz.normalized() + Vector3(0.0, 0.56, 0.0)).normalized()
			_proc_mat.direction = spray_dir
			var spd_scale := clampf(speed / 5.2, 0.75, 1.85)
			_proc_mat.initial_velocity_min = 3.6 * spd_scale
			_proc_mat.initial_velocity_max = 8.2 * spd_scale
			_sparks.emitting = true
			if _contact_flare != null:
				_contact_flare.visible = true
				_contact_flare.global_position = contact
			_push_ground_streak(Vector3(contact.x, ground_y + 0.026, contact.z), effective_horiz.normalized())

		if _sfx_cooldown <= 0.0:
			_sfx_cooldown = SFX_INTERVAL
			var ad := get_node_or_null("/root/AudioDirector")
			if ad != null and ad.has_method("sfx"):
				ad.sfx("blade_scrape", -3.0)
	else:
		if not _headless and _sparks != null:
			_sparks.emitting = false
		if _contact_flare != null:
			_contact_flare.visible = false


func _push_ground_streak(pos: Vector3, move_dir: Vector3) -> void:
	if _streak_points.size() > 0:
		var last_p: Vector3 = _streak_points[_streak_points.size() - 1]["pos"]
		if last_p.distance_to(pos) < 0.07:
			return
	var side := move_dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	_streak_points.append({"pos": pos, "side": side, "age": 0.0})
	while _streak_points.size() > MAX_STREAK_POINTS:
		_streak_points.pop_front()


func _process(delta: float) -> void:
	_time_acc += delta
	if _sfx_cooldown > 0.0:
		_sfx_cooldown = maxf(0.0, _sfx_cooldown - delta)
	if not _active_scraping and _light != null and _light.light_energy > 0.001:
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 14.0)

	if _headless or _streak_mesh == null:
		return

	var i := _streak_points.size() - 1
	while i >= 0:
		var age := float(_streak_points[i]["age"]) + delta
		if age >= STREAK_LIFETIME:
			_streak_points.remove_at(i)
		else:
			_streak_points[i]["age"] = age
		i -= 1

	_streak_mesh.clear_surfaces()
	var n := _streak_points.size()
	if n < 2:
		return

	_streak_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _streak_mat)
	for idx in n:
		var pt: Dictionary = _streak_points[idx]
		var life_01 := clampf(float(pt["age"]) / STREAK_LIFETIME, 0.0, 1.0)
		var heat := 1.0 - life_01
		var half_w := lerpf(0.010, 0.036, heat)
		var col := Color(3.1 * heat, 0.92 * heat * heat, 0.14 * heat * heat, heat * 0.88)
		var p: Vector3 = pt["pos"]
		var s: Vector3 = pt["side"]
		_streak_mesh.surface_set_color(col)
		_streak_mesh.surface_add_vertex(p - s * half_w)
		_streak_mesh.surface_set_color(col)
		_streak_mesh.surface_add_vertex(p + s * half_w)
	_streak_mesh.surface_end()
