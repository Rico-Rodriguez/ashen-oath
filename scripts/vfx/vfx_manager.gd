class_name VfxManager
extends Node3D

var _headless: bool = false
var _flame_shader: Shader
var _ribbon_shader: Shader
var _energy_shader: Shader
var _spark_shader: Shader


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
	gp.amount = 34 if is_crit else 18
	gp.lifetime = 0.32 if is_crit else 0.24
	gp.one_shot = true
	gp.explosiveness = 0.95
	gp.process_material = proc
	gp.draw_pass_1 = draw_mesh
	fx.add_child(gp)
	gp.emitting = true

	var flash := OmniLight3D.new()
	flash.light_color = color.lightened(0.20)
	flash.light_energy = 2.2 if is_crit else 1.15
	flash.omni_range = 3.2 if is_crit else 2.1
	flash.shadow_enabled = false
	fx.add_child(flash)

	var peak_e := flash.light_energy
	fx.configure(0.38, func(t01: float, _el: float) -> void:
		var fast_fade := clampf(1.0 - t01 * 3.2, 0.0, 1.0)
		if is_instance_valid(flash):
			flash.light_energy = peak_e * fast_fade * fast_fade
	)


func spawn_blackflame_pyre(pos: Vector3, radius: float = 3.2) -> void:
	_ensure_cached()
	if _headless:
		return

	var r := maxf(radius, 0.8)
	var pyre := VfxOneshot3D.new()
	pyre.name = "BlackflamePyreVfx"
	pyre.position = pos
	add_child(pyre)

	var soot_disc := MeshInstance3D.new()
	var soot_plane := PlaneMesh.new()
	soot_plane.size = Vector2(r * 2.15, r * 2.15)
	soot_disc.mesh = soot_plane
	soot_disc.position = Vector3(0.0, 0.025, 0.0)
	var soot_mat := StandardMaterial3D.new()
	soot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	soot_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	soot_mat.albedo_color = Color(0.015, 0.012, 0.018, 0.86)
	var soot_grad := Gradient.new()
	soot_grad.offsets = PackedFloat32Array([0.0, 0.65, 0.92, 1.0])
	soot_grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.96),
		Color(1, 1, 1, 0.85),
		Color(1, 1, 1, 0.25),
		Color(1, 1, 1, 0.0),
	])
	var soot_tex := GradientTexture2D.new()
	soot_tex.gradient = soot_grad
	soot_tex.fill = GradientTexture2D.FILL_RADIAL
	soot_tex.fill_from = Vector2(0.5, 0.5)
	soot_tex.fill_to = Vector2(1.0, 0.5)
	soot_mat.albedo_texture = soot_tex
	soot_disc.material_override = soot_mat
	pyre.add_child(soot_disc)

	var ring_mat: ShaderMaterial = null
	if _energy_shader != null:
		ring_mat = ShaderMaterial.new()
		ring_mat.shader = _energy_shader
		ring_mat.set_shader_parameter("beam_mode", 1)
		ring_mat.set_shader_parameter("energy_color", Color(1.0, 0.40, 0.08, 1.0))
		ring_mat.set_shader_parameter("hdr_gain", 2.35)
		var ring_mi := MeshInstance3D.new()
		var ring_pm := PlaneMesh.new()
		ring_pm.size = Vector2(r * 2.02, r * 2.02)
		ring_mi.mesh = ring_pm
		ring_mi.position = Vector3(0.0, 0.036, 0.0)
		ring_mi.material_override = ring_mat
		pyre.add_child(ring_mi)

	var pillar_layers: Array[Dictionary] = []
	if _flame_shader != null:
		var specs := [
			{"w": r * 1.32, "h": 5.8, "y": 2.85, "soot": 0.84, "core": Vector3(3.8, 1.45, 0.24), "spd": 2.6, "nsc": 4.4, "prio": 0},
			{"w": r * 0.90, "h": 4.3, "y": 2.08, "soot": 0.36, "core": Vector3(6.8, 3.1, 0.68), "spd": 3.3, "nsc": 5.0, "prio": 1},
			{"w": r * 0.58, "h": 2.85, "y": 1.38, "soot": 0.08, "core": Vector3(8.8, 4.6, 1.25), "spd": 4.1, "nsc": 5.6, "prio": 2},
		]
		for s_i in specs.size():
			var sp: Dictionary = specs[s_i]
			var fmat := ShaderMaterial.new()
			fmat.shader = _flame_shader
			fmat.render_priority = int(sp["prio"])
			fmat.set_shader_parameter("billboard_mode", true)
			fmat.set_shader_parameter("soot_dominance", float(sp["soot"]))
			fmat.set_shader_parameter("core_hdr", sp["core"] as Vector3)
			fmat.set_shader_parameter("scroll_speed", float(sp["spd"]))
			fmat.set_shader_parameter("noise_scale", float(sp["nsc"]))
			var qm := QuadMesh.new()
			qm.size = Vector2(float(sp["w"]), float(sp["h"]))
			var fmi := MeshInstance3D.new()
			fmi.mesh = qm
			fmi.position = Vector3(0.0, float(sp["y"]), 0.0)
			fmi.material_override = fmat
			pyre.add_child(fmi)
			pillar_layers.append({"mi": fmi, "mat": fmat, "base_y": float(sp["y"])})

		var smoke_mat := ShaderMaterial.new()
		smoke_mat.shader = _flame_shader
		smoke_mat.set_shader_parameter("billboard_mode", true)
		smoke_mat.set_shader_parameter("soot_dominance", 0.84)
		smoke_mat.set_shader_parameter("core_hdr", Vector3(3.6, 1.3, 0.22))
		smoke_mat.set_shader_parameter("mid_flame", Vector3(1.5, 0.35, 0.06))
		smoke_mat.set_shader_parameter("soot_color", Color(0.014, 0.012, 0.018))
		smoke_mat.set_shader_parameter("alpha_boost", 1.35)

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
		smoke_proc.scale_min = 0.85
		smoke_proc.scale_max = 1.45

		var smoke_quad := QuadMesh.new()
		smoke_quad.size = Vector2(r * 0.72, r * 0.88)
		smoke_quad.material = smoke_mat
		var smoke_gp := GPUParticles3D.new()
		smoke_gp.position = Vector3(0.0, 0.55, 0.0)
		smoke_gp.amount = 30
		smoke_gp.lifetime = 1.30
		smoke_gp.explosiveness = 0.24
		smoke_gp.process_material = smoke_proc
		smoke_gp.draw_pass_1 = smoke_quad
		pyre.add_child(smoke_gp)

		var fire_mat := ShaderMaterial.new()
		fire_mat.shader = _flame_shader
		fire_mat.set_shader_parameter("billboard_mode", true)
		fire_mat.set_shader_parameter("soot_dominance", 0.34)
		fire_mat.set_shader_parameter("core_hdr", Vector3(7.2, 3.3, 0.78))
		fire_mat.set_shader_parameter("scroll_speed", 3.6)

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
		fire_proc.scale_min = 0.75
		fire_proc.scale_max = 1.25

		var fire_quad := QuadMesh.new()
		fire_quad.size = Vector2(r * 0.56, r * 0.80)
		fire_quad.material = fire_mat
		var fire_gp := GPUParticles3D.new()
		fire_gp.position = Vector3(0.0, 0.35, 0.0)
		fire_gp.amount = 26
		fire_gp.lifetime = 0.72
		fire_gp.explosiveness = 0.30
		fire_gp.process_material = fire_proc
		fire_gp.draw_pass_1 = fire_quad
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

		var cinder_mesh := _make_spark_draw_mesh(0.082, 0.30, Vector4(5.8, 2.4, 0.42, 1.0))
		var cinder_gp := GPUParticles3D.new()
		cinder_gp.position = Vector3(0.0, 0.15, 0.0)
		cinder_gp.amount = 52
		cinder_gp.lifetime = 1.15
		cinder_gp.explosiveness = 0.20
		cinder_gp.process_material = cinder_proc
		cinder_gp.draw_pass_1 = cinder_mesh
		pyre.add_child(cinder_gp)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.85, 0.0)
	light.light_color = Color(1.0, 0.50, 0.15)
	light.light_energy = 4.2
	light.omni_range = maxf(r * 2.8, 8.5)
	light.shadow_enabled = false
	pyre.add_child(light)

	spawn_shockwave_ring(pos, r, Color(1.0, 0.44, 0.10))

	pyre.configure(1.95, func(t01: float, el: float) -> void:
		var erupt := clampf(el / 0.14, 0.0, 1.0)
		var decay := clampf((1.0 - t01) / 0.32, 0.0, 1.0)
		var env_curve := erupt * decay
		if is_instance_valid(light):
			var flk := 0.85 + 0.30 * absf(sin(el * 23.0 + cos(el * 13.0)))
			light.light_energy = 4.2 * env_curve * flk
		if ring_mat != null:
			ring_mat.set_shader_parameter("fade_alpha", env_curve)
		soot_mat.albedo_color.a = 0.86 * decay
		for layer in pillar_layers:
			var mi := layer["mi"] as MeshInstance3D
			var mat := layer["mat"] as ShaderMaterial
			if is_instance_valid(mi):
				mi.scale = Vector3(lerpf(0.55, 1.08, erupt), lerpf(0.25, 1.05, erupt), 1.0)
				mi.position.y = float(layer["base_y"]) * lerpf(0.3, 1.0, erupt)
				mat.set_shader_parameter("alpha_boost", 1.22 * env_curve)
	)


func spawn_blackflame_bolt_vfx(projectile_parent: Node3D) -> void:
	_ensure_cached()
	if _headless or projectile_parent == null or not is_instance_valid(projectile_parent):
		return

	var holder := Node3D.new()
	holder.name = "BlackflameBoltVfx"
	projectile_parent.add_child(holder)

	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.30
	core.mesh = sph
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(5.2, 2.3, 0.52, 1.0)
	core.material_override = core_mat
	holder.add_child(core)

	if _flame_shader != null:
		var corona_mat := ShaderMaterial.new()
		corona_mat.shader = _flame_shader
		corona_mat.set_shader_parameter("billboard_mode", true)
		corona_mat.set_shader_parameter("soot_dominance", 0.52)
		corona_mat.set_shader_parameter("core_hdr", Vector3(5.8, 2.5, 0.55))
		corona_mat.set_shader_parameter("scroll_speed", 4.2)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.85, 0.95)
		var corona_mi := MeshInstance3D.new()
		corona_mi.mesh = qm
		corona_mi.material_override = corona_mat
		holder.add_child(corona_mi)

		var trail_mat := ShaderMaterial.new()
		trail_mat.shader = _flame_shader
		trail_mat.set_shader_parameter("billboard_mode", true)
		trail_mat.set_shader_parameter("soot_dominance", 0.76)
		trail_mat.set_shader_parameter("core_hdr", Vector3(4.0, 1.5, 0.28))

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

		var tq := QuadMesh.new()
		tq.size = Vector2(0.52, 0.52)
		tq.material = trail_mat
		var trail_gp := GPUParticles3D.new()
		trail_gp.amount = 24
		trail_gp.lifetime = 0.42
		trail_gp.local_coords = false
		trail_gp.process_material = trail_proc
		trail_gp.draw_pass_1 = tq
		holder.add_child(trail_gp)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.50, 0.16)
	light.light_energy = 1.8
	light.omni_range = 3.8
	light.shadow_enabled = false
	holder.add_child(light)


func spawn_chain_lightning(points: PackedVector3Array) -> void:
	_ensure_cached()
	if points.size() < 2:
		return
	var arc := LightningArc3D.new()
	arc.name = "LightningArc3D"
	arc.chain_points = points
	add_child(arc)

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

	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 10

	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	tmat.albedo_color = Color(color.r * 2.4, color.g * 2.2, color.b * 2.0, 0.90)

	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.scale = Vector3(r * 0.2, 0.18, r * 0.2)
	mi.material_override = tmat
	fx.add_child(mi)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.4, 0.0)
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = r * 1.8
	light.shadow_enabled = false
	fx.add_child(light)

	fx.configure(0.38, func(t01: float, _el: float) -> void:
		var ease_out := 1.0 - pow(1.0 - t01, 2.4)
		var fade := clampf(1.0 - t01, 0.0, 1.0)
		if is_instance_valid(mi):
			var cur_r := lerpf(r * 0.18, r, ease_out)
			mi.scale = Vector3(cur_r, lerpf(0.22, 0.06, t01), cur_r)
			tmat.albedo_color.a = fade * 0.90
		if is_instance_valid(light):
			light.light_energy = 2.0 * fade * fade
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
	var steps := 24
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
		var pm := PlaneMesh.new()
		var dr := 1.05 if is_high_tier else 0.68
		pm.size = Vector2(dr, dr)
		disc_mi.mesh = pm
		disc_mi.position = Vector3(0.0, 0.03, 0.0)
		disc_mi.material_override = disc_mat
		disc_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root_beam.add_child(disc_mi)

	var orb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.11 if is_high_tier else 0.08
	sph.height = sph.radius * 2.0
	orb.mesh = sph
	orb.position = Vector3(0.0, 0.22, 0.0)
	var orb_mat := StandardMaterial3D.new()
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mat.albedo_color = Color(color.r * 2.8 + 0.35, color.g * 2.8 + 0.35, color.b * 2.8 + 0.35, 1.0)
	orb.material_override = orb_mat
	root_beam.add_child(orb)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.55, 0.0)
	light.light_color = color
	light.light_energy = 1.65 if is_high_tier else 0.85
	light.omni_range = 3.5 if is_high_tier else 2.2
	light.shadow_enabled = false
	root_beam.add_child(light)

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
		gp.amount = 18
		gp.lifetime = 1.35
		gp.process_material = mote_proc
		gp.draw_pass_1 = mote_mesh
		root_beam.add_child(gp)
