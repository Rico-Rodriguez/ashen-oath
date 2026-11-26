class_name VfxManager
extends Node3D

const VFX_NOISE_TEX_PATH := "res://assets/textures/vfx_noise_tile.png"
const ARMOR_VORONOI_TEX_PATH := "res://assets/textures/armor_voronoi_tile.png"
const MAX_DYNAMIC_VFX_LIGHTS := 2

static var _shared_noise_tex: Texture2D = null
static var _shared_soot_tex: GradientTexture2D = null
static var _shared_soot_mat_tpl: StandardMaterial3D = null
static var _shared_ring_mat_tpl: ShaderMaterial = null
static var _shared_pillar_outer_mat_tpl: ShaderMaterial = null
static var _shared_pillar_core_mat_tpl: ShaderMaterial = null
static var _shared_pyre_smoke_mat: ShaderMaterial = null
static var _shared_pyre_fire_mat: ShaderMaterial = null
static var _shared_unit_plane: PlaneMesh = null
static var _shared_unit_quad: QuadMesh = null
static var _shared_torus: TorusMesh = null
static var _shared_pyre_smoke_quad: QuadMesh = null
static var _shared_pyre_fire_quad: QuadMesh = null
static var _shared_cinder_mesh: ArrayMesh = null
static var _shared_bolt_corona_mat: ShaderMaterial = null
static var _shared_bolt_trail_mat: ShaderMaterial = null
static var _shared_bolt_corona_quad: QuadMesh = null
static var _shared_bolt_trail_quad: QuadMesh = null
static var _shared_loot_orb_mesh: SphereMesh = null
static var _shaders_prewarmed: bool = false

var _headless: bool = false
var _flame_shader: Shader
var _ribbon_shader: Shader
var _energy_shader: Shader
var _spark_shader: Shader
var _active_vfx_lights: Array[OmniLight3D] = []


func _ready() -> void:
	_ensure_cached()


func _ensure_cached() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	if _flame_shader == null:
		_flame_shader = load("res://shaders/vfx_smokey_flame.gdshader") as Shader
	if _ribbon_shader == null:
		_ribbon_shader = load("res://shaders/vfx_ribbon.gdshader") as Shader
	if _energy_shader == null:
		_energy_shader = load("res://shaders/vfx_energy.gdshader") as Shader
	if _spark_shader == null:
		_spark_shader = load("res://shaders/vfx_spark.gdshader") as Shader
	_ensure_shared_templates()


func _ensure_shared_templates() -> void:
	if _shared_noise_tex == null and ResourceLoader.exists(VFX_NOISE_TEX_PATH):
		_shared_noise_tex = load(VFX_NOISE_TEX_PATH) as Texture2D

	if _shared_unit_plane == null:
		_shared_unit_plane = PlaneMesh.new()
		_shared_unit_plane.size = Vector2.ONE

	if _shared_unit_quad == null:
		_shared_unit_quad = QuadMesh.new()
		_shared_unit_quad.size = Vector2.ONE

	if _shared_torus == null:
		_shared_torus = TorusMesh.new()
		_shared_torus.inner_radius = 0.92
		_shared_torus.outer_radius = 1.0
		_shared_torus.rings = 24
		_shared_torus.ring_segments = 8

	if _shared_loot_orb_mesh == null:
		_shared_loot_orb_mesh = SphereMesh.new()
		_shared_loot_orb_mesh.radius = 1.0
		_shared_loot_orb_mesh.height = 2.0
		_shared_loot_orb_mesh.radial_segments = 12
		_shared_loot_orb_mesh.rings = 6

	if _shared_soot_tex == null:
		var soot_grad := Gradient.new()
		soot_grad.offsets = PackedFloat32Array([0.0, 0.65, 0.92, 1.0])
		soot_grad.colors = PackedColorArray([
			Color(1, 1, 1, 0.96),
			Color(1, 1, 1, 0.85),
			Color(1, 1, 1, 0.25),
			Color(1, 1, 1, 0.0),
		])
		_shared_soot_tex = GradientTexture2D.new()
		_shared_soot_tex.width = 64
		_shared_soot_tex.height = 64
		_shared_soot_tex.gradient = soot_grad
		_shared_soot_tex.fill = GradientTexture2D.FILL_RADIAL
		_shared_soot_tex.fill_from = Vector2(0.5, 0.5)
		_shared_soot_tex.fill_to = Vector2(1.0, 0.5)

	if _shared_soot_mat_tpl == null:
		_shared_soot_mat_tpl = StandardMaterial3D.new()
		_shared_soot_mat_tpl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_soot_mat_tpl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_soot_mat_tpl.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shared_soot_mat_tpl.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_shared_soot_mat_tpl.albedo_color = Color(0.015, 0.012, 0.018, 0.86)
		_shared_soot_mat_tpl.albedo_texture = _shared_soot_tex

	if _shared_ring_mat_tpl == null and _energy_shader != null:
		_shared_ring_mat_tpl = ShaderMaterial.new()
		_shared_ring_mat_tpl.shader = _energy_shader
		_shared_ring_mat_tpl.set_shader_parameter("beam_mode", 1)
		_shared_ring_mat_tpl.set_shader_parameter("energy_color", Color(1.0, 0.40, 0.08, 1.0))
		_shared_ring_mat_tpl.set_shader_parameter("hdr_gain", 2.35)

	if _flame_shader != null:
		if _shared_pillar_outer_mat_tpl == null:
			_shared_pillar_outer_mat_tpl = _make_flame_mat(0.50, Vector3(4.2, 1.65, 0.30), Vector3(2.4, 0.55, 0.10), 2.8, 4.5, 0.85, 0)
		if _shared_pillar_core_mat_tpl == null:
			_shared_pillar_core_mat_tpl = _make_flame_mat(0.14, Vector3(8.2, 4.1, 1.05), Vector3(2.4, 0.55, 0.10), 3.9, 5.4, 1.20, 1)
		if _shared_pyre_smoke_mat == null:
			_shared_pyre_smoke_mat = _make_flame_mat(0.62, Vector3(3.6, 1.3, 0.22), Vector3(1.5, 0.35, 0.06), 2.8, 4.6, 0.55, 0)
		if _shared_pyre_fire_mat == null:
			_shared_pyre_fire_mat = _make_flame_mat(0.34, Vector3(7.2, 3.3, 0.78), Vector3(2.4, 0.55, 0.10), 3.6, 4.6, 1.22, 1)
		if _shared_pyre_smoke_quad == null:
			_shared_pyre_smoke_quad = QuadMesh.new()
			_shared_pyre_smoke_quad.size = Vector2(2.3, 2.8)
			_shared_pyre_smoke_quad.material = _shared_pyre_smoke_mat
		if _shared_pyre_fire_quad == null:
			_shared_pyre_fire_quad = QuadMesh.new()
			_shared_pyre_fire_quad.size = Vector2(1.8, 2.55)
			_shared_pyre_fire_quad.material = _shared_pyre_fire_mat
		if _shared_bolt_corona_mat == null:
			_shared_bolt_corona_mat = _make_flame_mat(0.52, Vector3(5.8, 2.5, 0.55), Vector3(2.4, 0.55, 0.10), 4.2, 4.6, 1.22, 1)
		if _shared_bolt_trail_mat == null:
			_shared_bolt_trail_mat = _make_flame_mat(0.76, Vector3(4.0, 1.5, 0.28), Vector3(2.4, 0.55, 0.10), 2.8, 4.6, 1.0, 0)
		if _shared_bolt_corona_quad == null:
			_shared_bolt_corona_quad = QuadMesh.new()
			_shared_bolt_corona_quad.size = Vector2(0.85, 0.95)
		if _shared_bolt_trail_quad == null:
			_shared_bolt_trail_quad = QuadMesh.new()
			_shared_bolt_trail_quad.size = Vector2(0.52, 0.52)
			_shared_bolt_trail_quad.material = _shared_bolt_trail_mat

	if _shared_cinder_mesh == null:
		_shared_cinder_mesh = _make_spark_draw_mesh(0.082, 0.30, Vector4(5.8, 2.4, 0.42, 1.0))


func _make_flame_mat(
	soot: float,
	core_hdr: Vector3,
	mid_flame: Vector3,
	scroll_spd: float,
	n_scale: float,
	a_boost: float,
	prio: int
) -> ShaderMaterial:
	var fmat := ShaderMaterial.new()
	fmat.shader = _flame_shader
	fmat.render_priority = prio
	if _shared_noise_tex != null:
		fmat.set_shader_parameter("noise_tex", _shared_noise_tex)
	fmat.set_shader_parameter("billboard_mode", true)
	fmat.set_shader_parameter("soot_dominance", soot)
	fmat.set_shader_parameter("soot_color", Color(0.055, 0.042, 0.052))
	fmat.set_shader_parameter("core_hdr", core_hdr)
	fmat.set_shader_parameter("mid_flame", mid_flame)
	fmat.set_shader_parameter("scroll_speed", scroll_spd)
	fmat.set_shader_parameter("noise_scale", n_scale)
	fmat.set_shader_parameter("alpha_boost", a_boost)
	return fmat


func _can_spawn_vfx_light() -> bool:
	var i := _active_vfx_lights.size() - 1
	while i >= 0:
		var l := _active_vfx_lights[i]
		if l == null or not is_instance_valid(l) or not l.is_inside_tree():
			_active_vfx_lights.remove_at(i)
		i -= 1
	return _active_vfx_lights.size() < MAX_DYNAMIC_VFX_LIGHTS


func _track_vfx_light(light: OmniLight3D) -> void:
	if light != null:
		_active_vfx_lights.append(light)


static func prewarm_shaders(parent: Node3D) -> void:
	if _shaders_prewarmed or DisplayServer.get_name() == "headless":
		return
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	_shaders_prewarmed = true

	var noise_tex := load(VFX_NOISE_TEX_PATH) as Texture2D if ResourceLoader.exists(VFX_NOISE_TEX_PATH) else null
	var vor_tex := load(ARMOR_VORONOI_TEX_PATH) as Texture2D if ResourceLoader.exists(ARMOR_VORONOI_TEX_PATH) else null

	# Keep prewarm geometry tiny and far below the arena with large cull margin so Metal compiles PSOs without visual pop.
	var prewarm := VfxOneshot3D.new()
	prewarm.name = "VfxShaderPrewarm"
	prewarm.position = Vector3(0.0, -40.0, 0.0)
	prewarm.scale = Vector3(0.001, 0.001, 0.001)
	parent.add_child(prewarm)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)

	var shader_paths := [
		"res://shaders/vfx_smokey_flame.gdshader",
		"res://shaders/vfx_ribbon.gdshader",
		"res://shaders/vfx_energy.gdshader",
		"res://shaders/vfx_spark.gdshader",
		"res://shaders/vfx_telegraph.gdshader",
		"res://shaders/armor_forge.gdshader",
		"res://shaders/cloak_sway.gdshader",
		"res://shaders/discard_alpha.gdshader",
	]
	var flame_mat: ShaderMaterial = null
	var spark_mat: ShaderMaterial = null
	for path in shader_paths:
		var sh := load(path) as Shader
		if sh == null:
			continue
		var smat := ShaderMaterial.new()
		smat.shader = sh
		if path.ends_with("vfx_smokey_flame.gdshader"):
			if noise_tex != null:
				smat.set_shader_parameter("noise_tex", noise_tex)
			flame_mat = smat
		elif path.ends_with("vfx_spark.gdshader"):
			spark_mat = smat
		elif path.ends_with("armor_forge.gdshader"):
			smat.set_shader_parameter("armor_tier", 4)
			if vor_tex != null:
				smat.set_shader_parameter("voronoi_tex", vor_tex)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = smat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16384.0
		prewarm.add_child(mi)

	var pmat := ParticleProcessMaterial.new()
	for mat_ref in [flame_mat, spark_mat]:
		if mat_ref == null:
			continue
		var pq := QuadMesh.new()
		pq.size = Vector2(0.05, 0.05)
		pq.material = mat_ref
		var gp := GPUParticles3D.new()
		gp.amount = 1
		gp.lifetime = 0.05
		gp.one_shot = true
		gp.emitting = true
		gp.process_material = pmat
		gp.draw_pass_1 = pq
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gp.extra_cull_margin = 16384.0
		prewarm.add_child(gp)

	prewarm.configure(0.05)


func _attach_target(preferred: Node3D) -> Node3D:
	if preferred != null and is_instance_valid(preferred):
		return preferred
	return self


func _make_spark_draw_mesh(width: float, length: float, hdr_col: Vector4) -> ArrayMesh:
	var mesh := BladeScrapeVfx.make_crossed_spark_mesh(width, length)
	if _spark_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = _spark_shader
		sm.render_priority = 3
		sm.set_shader_parameter("spark_hdr", hdr_col)
		mesh.surface_set_material(0, sm)
	else:
		var std := StandardMaterial3D.new()
		std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
		std.vertex_color_use_as_albedo = true
		std.albedo_color = Color(hdr_col.x, hdr_col.y, hdr_col.z, hdr_col.w)
		mesh.surface_set_material(0, std)
	return mesh


func create_blade_scrape(parent_root: Node3D) -> Node3D:
	_ensure_cached()
	var scrape := BladeScrapeVfx.new()
	scrape.name = "BladeScrapeVfx"
	_attach_target(parent_root).add_child(scrape)
	return scrape


func create_weapon_ribbon(parent_root: Node3D, tint: Color = Color(0.85, 0.88, 0.96, 0.85)) -> Node3D:
	_ensure_cached()
	var ribbon := WeaponRibbon3D.new()
	ribbon.name = "WeaponRibbon3D"
	ribbon.ribbon_tint = tint
	_attach_target(parent_root).add_child(ribbon)
	ribbon.set_tint(tint)
	return ribbon


func spawn_hit_sparks(pos: Vector3, color: Color = Color(1.0, 0.65, 0.22), is_crit: bool = false) -> void:
	_ensure_cached()
	if _headless:
		return

	var fx := VfxOneshot3D.new()
	fx.name = "HitSparksVfx"
	fx.position = pos
	add_child(fx)

	var proc := ParticleProcessMaterial.new()
	proc.particle_flag_align_y = true
	proc.direction = Vector3(0.0, 0.65, 0.0)
	proc.spread = 155.0
	proc.initial_velocity_min = 5.0 if is_crit else 3.4
	proc.initial_velocity_max = 10.8 if is_crit else 7.4
	proc.gravity = Vector3(0.0, -16.0, 0.0)
	proc.damping_min = 2.2
	proc.damping_max = 4.8

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.98, 0.90, 1.0),
		Color(color.r, color.g, color.b, 0.92),
		Color(color.r * 0.35, color.g * 0.2, color.b * 0.12, 0.0),
	])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	proc.color_ramp = gtex

	var boost := 4.8 if is_crit else 3.6
	var draw_mesh := _make_spark_draw_mesh(
		0.105 if is_crit else 0.075,
		0.42 if is_crit else 0.30,
		Vector4(maxf(color.r, 0.2) * boost, maxf(color.g, 0.2) * boost, maxf(color.b, 0.2) * boost, 1.0)
	)

	var gp := GPUParticles3D.new()
	gp.amount = 24 if is_crit else 14
	gp.lifetime = 0.32 if is_crit else 0.24
	gp.one_shot = true
	gp.explosiveness = 0.95
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.process_material = proc
	gp.draw_pass_1 = draw_mesh
	fx.add_child(gp)
	gp.emitting = true

	fx.configure(0.38)


func spawn_blackflame_pyre(pos: Vector3, radius: float = 3.2) -> void:
	_ensure_cached()
	if _headless:
		return

	var r := maxf(radius, 0.8)
	var r_scale := r / 3.2
	var pyre := VfxOneshot3D.new()
	pyre.name = "BlackflamePyreVfx"
	pyre.position = pos
	add_child(pyre)

	var soot_disc := MeshInstance3D.new()
	soot_disc.mesh = _shared_unit_plane
	soot_disc.scale = Vector3(r * 2.15, 1.0, r * 2.15)
	soot_disc.position = Vector3(0.0, 0.025, 0.0)
	soot_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var soot_mat := _shared_soot_mat_tpl.duplicate() as StandardMaterial3D
	soot_disc.material_override = soot_mat
	pyre.add_child(soot_disc)

	var ring_mat: ShaderMaterial = null
	if _shared_ring_mat_tpl != null:
		ring_mat = _shared_ring_mat_tpl.duplicate() as ShaderMaterial
		var ring_mi := MeshInstance3D.new()
		ring_mi.mesh = _shared_unit_plane
		ring_mi.scale = Vector3(r * 2.02, 1.0, r * 2.02)
		ring_mi.position = Vector3(0.0, 0.036, 0.0)
		ring_mi.material_override = ring_mat
		ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pyre.add_child(ring_mi)

	var pillar_layers: Array[Dictionary] = []
	if _flame_shader != null and _shared_pillar_outer_mat_tpl != null and _shared_pillar_core_mat_tpl != null:
		var specs := [
			{"w": r * 1.12, "h": 4.25, "y": 2.08, "alpha_boost": 0.85, "tpl": _shared_pillar_outer_mat_tpl},
			{"w": r * 0.68, "h": 3.35, "y": 1.62, "alpha_boost": 1.20, "tpl": _shared_pillar_core_mat_tpl},
		]
		for sp in specs:
			var fmat := (sp["tpl"] as ShaderMaterial).duplicate() as ShaderMaterial
			var fmi := MeshInstance3D.new()
			fmi.mesh = _shared_unit_quad
			var bw := float(sp["w"])
			var bh := float(sp["h"])
			fmi.scale = Vector3(bw, bh, 1.0)
			fmi.position = Vector3(0.0, float(sp["y"]), 0.0)
			fmi.material_override = fmat
			fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pyre.add_child(fmi)
			pillar_layers.append({
				"mi": fmi,
				"mat": fmat,
				"base_w": bw,
				"base_h": bh,
				"base_y": float(sp["y"]),
				"alpha_boost": float(sp["alpha_boost"]),
			})

		var smoke_proc := ParticleProcessMaterial.new()
		smoke_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		smoke_proc.emission_ring_radius = r * 0.44
		smoke_proc.emission_ring_inner_radius = 0.0
		smoke_proc.emission_ring_height = 0.6
		smoke_proc.emission_ring_axis = Vector3.UP
		smoke_proc.direction = Vector3.UP
		smoke_proc.spread = 14.0
		smoke_proc.initial_velocity_min = 3.2
		smoke_proc.initial_velocity_max = 5.8
		smoke_proc.gravity = Vector3(0.0, 1.5, 0.0)
		smoke_proc.damping_min = 0.6
		smoke_proc.damping_max = 1.4
		smoke_proc.angle_min = -180.0
		smoke_proc.angle_max = 180.0
		smoke_proc.angular_velocity_min = -48.0
		smoke_proc.angular_velocity_max = 48.0
		smoke_proc.scale_min = 0.85 * r_scale
		smoke_proc.scale_max = 1.45 * r_scale

		var smoke_gp := GPUParticles3D.new()
		smoke_gp.position = Vector3(0.0, 0.55, 0.0)
		smoke_gp.amount = 8
		smoke_gp.lifetime = 1.30
		smoke_gp.explosiveness = 0.24
		smoke_gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke_gp.process_material = smoke_proc
		smoke_gp.draw_pass_1 = _shared_pyre_smoke_quad
		pyre.add_child(smoke_gp)

		var fire_proc := ParticleProcessMaterial.new()
		fire_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		fire_proc.emission_sphere_radius = r * 0.34
		fire_proc.direction = Vector3.UP
		fire_proc.spread = 18.0
		fire_proc.initial_velocity_min = 2.6
		fire_proc.initial_velocity_max = 5.4
		fire_proc.gravity = Vector3(0.0, 1.8, 0.0)
		fire_proc.angle_min = -60.0
		fire_proc.angle_max = 60.0
		fire_proc.scale_min = 0.75 * r_scale
		fire_proc.scale_max = 1.25 * r_scale

		var fire_gp := GPUParticles3D.new()
		fire_gp.position = Vector3(0.0, 0.35, 0.0)
		fire_gp.amount = 8
		fire_gp.lifetime = 0.72
		fire_gp.explosiveness = 0.30
		fire_gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire_gp.process_material = fire_proc
		fire_gp.draw_pass_1 = _shared_pyre_fire_quad
		pyre.add_child(fire_gp)

		var cinder_proc := ParticleProcessMaterial.new()
		cinder_proc.particle_flag_align_y = true
		cinder_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		cinder_proc.emission_ring_radius = r * 0.82
		cinder_proc.emission_ring_inner_radius = r * 0.10
		cinder_proc.emission_ring_height = 0.3
		cinder_proc.emission_ring_axis = Vector3.UP
		cinder_proc.direction = Vector3.UP
		cinder_proc.spread = 24.0
		cinder_proc.initial_velocity_min = 3.8
		cinder_proc.initial_velocity_max = 8.4
		cinder_proc.gravity = Vector3(0.0, -1.6, 0.0)

		var cinder_gp := GPUParticles3D.new()
		cinder_gp.position = Vector3(0.0, 0.15, 0.0)
		cinder_gp.amount = 16
		cinder_gp.lifetime = 1.15
		cinder_gp.explosiveness = 0.20
		cinder_gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cinder_gp.process_material = cinder_proc
		cinder_gp.draw_pass_1 = _shared_cinder_mesh
		pyre.add_child(cinder_gp)

	var light: OmniLight3D = null
	if _can_spawn_vfx_light():
		light = OmniLight3D.new()
		light.position = Vector3(0.0, 1.85, 0.0)
		light.light_color = Color(1.0, 0.50, 0.15)
		light.light_energy = 4.2
		light.omni_range = minf(maxf(r * 2.4, 7.0), 8.0)
		light.shadow_enabled = false
		pyre.add_child(light)
		_track_vfx_light(light)

	spawn_shockwave_ring(pos, r, Color(1.0, 0.44, 0.10))

	pyre.configure(1.95, func(t01: float, el: float) -> void:
		var erupt := clampf(el / 0.14, 0.0, 1.0)
		var decay := clampf((1.0 - t01) / 0.32, 0.0, 1.0)
		var env_curve := erupt * decay
		if light != null and is_instance_valid(light):
			var flk := 0.85 + 0.30 * absf(sin(el * 23.0 + cos(el * 13.0)))
			light.light_energy = 4.2 * env_curve * flk
		if ring_mat != null:
			ring_mat.set_shader_parameter("fade_alpha", env_curve)
		soot_mat.albedo_color.a = 0.86 * decay
		for layer in pillar_layers:
			var mi := layer["mi"] as MeshInstance3D
			var mat := layer["mat"] as ShaderMaterial
			if is_instance_valid(mi):
				mi.scale = Vector3(float(layer["base_w"]) * lerpf(0.55, 1.08, erupt), float(layer["base_h"]) * lerpf(0.25, 1.05, erupt), 1.0)
				mi.position.y = float(layer["base_y"]) * lerpf(0.3, 1.0, erupt)
				mat.set_shader_parameter("alpha_boost", float(layer["alpha_boost"]) * env_curve)
	)


func spawn_blackflame_bolt_vfx(projectile_parent: Node3D) -> void:
	_ensure_cached()
	if _headless or projectile_parent == null or not is_instance_valid(projectile_parent):
		return

	var holder := Node3D.new()
	holder.name = "BlackflameBoltVfx"
	projectile_parent.add_child(holder)

	if _flame_shader != null and _shared_bolt_corona_mat != null:
		var corona_mi := MeshInstance3D.new()
		corona_mi.mesh = _shared_bolt_corona_quad
		corona_mi.material_override = _shared_bolt_corona_mat
		corona_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(corona_mi)

		var trail_proc := ParticleProcessMaterial.new()
		trail_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		trail_proc.emission_sphere_radius = 0.08
		trail_proc.direction = Vector3(0.0, 0.4, 0.0)
		trail_proc.spread = 45.0
		trail_proc.initial_velocity_min = 0.5
		trail_proc.initial_velocity_max = 1.6
		trail_proc.gravity = Vector3(0.0, 1.2, 0.0)
		trail_proc.scale_min = 0.55
		trail_proc.scale_max = 1.05

		var trail_gp := GPUParticles3D.new()
		trail_gp.amount = 6
		trail_gp.lifetime = 0.42
		trail_gp.local_coords = false
		trail_gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail_gp.process_material = trail_proc
		trail_gp.draw_pass_1 = _shared_bolt_trail_quad
		holder.add_child(trail_gp)


func spawn_chain_lightning(points: PackedVector3Array, is_primary: bool = true) -> void:
	_ensure_cached()
	if points.size() < 2:
		return
	var arc := LightningArc3D.new()
	arc.name = "LightningArc3D"
	arc.chain_points = points
	arc.enable_flash_light = is_primary and (not _headless) and _can_spawn_vfx_light()
	add_child(arc)
	if arc.enable_flash_light and arc._flash_light != null:
		_track_vfx_light(arc._flash_light)

	if not _headless:
		var bolt_spark_col := Color(0.38, 0.72, 1.0)
		for i in range(points.size()):
			spawn_hit_sparks(points[i], bolt_spark_col, false)


func spawn_shockwave_ring(pos: Vector3, radius: float, color: Color = Color(1.0, 0.55, 0.18)) -> void:
	_ensure_cached()
	if _headless:
		return

	var r := maxf(radius, 0.5)
	var fx := VfxOneshot3D.new()
	fx.name = "ShockwaveRingVfx"
	fx.position = pos + Vector3(0.0, 0.05, 0.0)
	add_child(fx)

	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	tmat.albedo_color = Color(color.r * 2.4, color.g * 2.2, color.b * 2.0, 0.90)

	var mi := MeshInstance3D.new()
	mi.mesh = _shared_torus
	mi.scale = Vector3(r * 0.2, 0.18, r * 0.2)
	mi.material_override = tmat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)

	fx.configure(0.38, func(t01: float, _el: float) -> void:
		var ease_out := 1.0 - pow(1.0 - t01, 2.4)
		var fade := clampf(1.0 - t01, 0.0, 1.0)
		if is_instance_valid(mi):
			var cur_r := lerpf(r * 0.18, r, ease_out)
			mi.scale = Vector3(cur_r, lerpf(0.22, 0.06, t01), cur_r)
			tmat.albedo_color.a = fade * 0.90
	)


func spawn_slash_arc(pos: Vector3, forward: Vector3, radius: float, arc_deg: float, color: Color = Color(0.92, 0.86, 0.78)) -> void:
	_ensure_cached()
	if _headless:
		return

	var r := maxf(radius, 0.8)
	var half_arc := deg_to_rad(clampf(arc_deg, 25.0, 340.0) * 0.5)
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	var fx := VfxOneshot3D.new()
	fx.name = "SlashArcVfx"
	fx.position = pos + Vector3(0.0, 1.02, 0.0)
	fx.basis = Basis.looking_at(fwd, Vector3.UP)
	add_child(fx)

	var smat: ShaderMaterial = null
	if _ribbon_shader != null:
		smat = ShaderMaterial.new()
		smat.shader = _ribbon_shader
		smat.set_shader_parameter("ribbon_tint", Color(color.r, color.g, color.b, 0.92))
		smat.set_shader_parameter("edge_hdr", Vector3(color.r * 2.8, color.g * 2.2, color.b * 1.8))

	var im := ImmediateMesh.new()
	var steps := 18
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, smat)
	for i in range(steps + 1):
		var frac := float(i) / float(steps)
		var ang := lerpf(-half_arc, half_arc, frac)
		var dir := Vector3(sin(ang), 0.0, -cos(ang))
		var taper := sin(frac * PI)
		var inner_r := r * lerpf(0.72, 0.46, taper)
		var outer_r := r * lerpf(0.94, 1.04, taper)
		var u_age := 1.0 - frac
		var col := Color(1.0, 1.0, 1.0, clampf(taper * 1.25, 0.15, 1.0))
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(u_age * 0.75, 0.0))
		im.surface_add_vertex(dir * inner_r)
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(u_age * 0.75, 1.0))
		im.surface_add_vertex(dir * outer_r)
	im.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if smat != null:
		mi.material_override = smat
	fx.add_child(mi)

	fx.configure(0.24, func(t01: float, _el: float) -> void:
		if is_instance_valid(mi):
			var expand := lerpf(0.86, 1.12, t01)
			mi.scale = Vector3(expand, 1.0, expand)
			if smat != null:
				var alpha := clampf(1.0 - t01 * t01, 0.0, 1.0)
				smat.set_shader_parameter("ribbon_tint", Color(color.r, color.g, color.b, 0.92 * alpha))
	)


func spawn_telegraph_circle(pos: Vector3, radius: float, duration: float, color: Color = Color(0.92, 0.16, 0.12, 0.75)) -> Node3D:
	var tg := VfxTelegraph3D.new()
	tg.name = "TelegraphCircle"
	tg.configure_circle(pos, radius, duration, color)
	add_child(tg)
	return tg


func spawn_telegraph_cone(
	pos: Vector3,
	forward: Vector3,
	range_m: float,
	angle_deg: float,
	duration: float,
	color: Color = Color(0.92, 0.16, 0.12, 0.78)
) -> Node3D:
	var tg := VfxTelegraph3D.new()
	tg.name = "TelegraphCone"
	tg.configure_cone(pos, forward, range_m, angle_deg, duration, color)
	add_child(tg)
	return tg


func spawn_telegraph_line(
	pos: Vector3,
	forward: Vector3,
	length_m: float,
	width_m: float,
	duration: float,
	color: Color = Color(0.92, 0.16, 0.12, 0.78)
) -> Node3D:
	var tg := VfxTelegraph3D.new()
	tg.name = "TelegraphLine"
	tg.configure_line(pos, forward, length_m, width_m, duration, color)
	add_child(tg)
	return tg


func spawn_loot_beam(drop_parent: Node3D, color: Color, is_high_tier: bool = false) -> void:
	_ensure_cached()
	if _headless or drop_parent == null or not is_instance_valid(drop_parent):
		return

	var root_beam := Node3D.new()
	root_beam.name = "LootBeamVfx"
	drop_parent.add_child(root_beam)

	var height := 3.8 if is_high_tier else 2.35
	var width := 0.36 if is_high_tier else 0.22
	var gain := 3.4 if is_high_tier else 2.2

	if _energy_shader != null:
		var bmat := ShaderMaterial.new()
		bmat.shader = _energy_shader
		bmat.set_shader_parameter("beam_mode", 0)
		bmat.set_shader_parameter("energy_color", color)
		bmat.set_shader_parameter("hdr_gain", gain)

		var crossed := BladeScrapeVfx.make_crossed_spark_mesh(width, height)
		var beam_mi := MeshInstance3D.new()
		beam_mi.mesh = crossed
		beam_mi.position = Vector3(0.0, height * 0.5 + 0.02, 0.0)
		beam_mi.material_override = bmat
		beam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root_beam.add_child(beam_mi)

		var disc_mat := ShaderMaterial.new()
		disc_mat.shader = _energy_shader
		disc_mat.set_shader_parameter("beam_mode", 1)
		disc_mat.set_shader_parameter("energy_color", color)
		disc_mat.set_shader_parameter("hdr_gain", gain * 0.75)

		var disc_mi := MeshInstance3D.new()
		var dr := 1.05 if is_high_tier else 0.68
		disc_mi.mesh = _shared_unit_plane
		disc_mi.scale = Vector3(dr, 1.0, dr)
		disc_mi.position = Vector3(0.0, 0.03, 0.0)
		disc_mi.material_override = disc_mat
		disc_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root_beam.add_child(disc_mi)

	var orb := MeshInstance3D.new()
	var orb_r := 0.11 if is_high_tier else 0.08
	orb.mesh = _shared_loot_orb_mesh
	orb.scale = Vector3.ONE * orb_r
	orb.position = Vector3(0.0, 0.22, 0.0)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var orb_mat := StandardMaterial3D.new()
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mat.albedo_color = Color(color.r * 2.8 + 0.35, color.g * 2.8 + 0.35, color.b * 2.8 + 0.35, 1.0)
	orb.material_override = orb_mat
	root_beam.add_child(orb)

	if is_high_tier:
		var mote_proc := ParticleProcessMaterial.new()
		mote_proc.particle_flag_align_y = true
		mote_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		mote_proc.emission_ring_radius = 0.32
		mote_proc.emission_ring_inner_radius = 0.05
		mote_proc.emission_ring_height = 0.2
		mote_proc.emission_ring_axis = Vector3.UP
		mote_proc.direction = Vector3.UP
		mote_proc.spread = 8.0
		mote_proc.initial_velocity_min = 1.2
		mote_proc.initial_velocity_max = 2.6
		mote_proc.gravity = Vector3.ZERO

		var mote_mesh := _make_spark_draw_mesh(0.032, 0.18, Vector4(color.r * 3.8 + 0.4, color.g * 3.8 + 0.4, color.b * 3.8 + 0.4, 0.9))
		var gp := GPUParticles3D.new()
		gp.position = Vector3(0.0, 0.12, 0.0)
		gp.amount = 14
		gp.lifetime = 1.35
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gp.process_material = mote_proc
		gp.draw_pass_1 = mote_mesh
		root_beam.add_child(gp)
