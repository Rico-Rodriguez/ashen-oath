class_name CombatProjectile
extends Node3D

const VFX_NOISE_TEX_PATH := "res://assets/textures/vfx_noise_tile.png"

static var _cached_flame_sh: Shader = null
static var _cached_energy_sh: Shader = null
static var _cached_spark_sh: Shader = null
static var _cached_noise_tex: Texture2D = null
static var _cached_tail_quad: QuadMesh = null
static var _cached_head_quad: QuadMesh = null
static var _cached_lance_mesh: CylinderMesh = null

var director: Node = null
var vfx: Node3D = null
var attacker: Node3D = null
var team: DamageEvent.Team = DamageEvent.Team.HERO
var direction: Vector3 = Vector3.FORWARD
var speed: float = 16.0
var damage: float = 20.0
var source_id: String = "projectile"
var damage_kind: DamageEvent.Kind = DamageEvent.Kind.PHYSICAL
var hit_radius: float = 0.45
var pierce_count: int = 0
var chain_remaining: int = 0
var chain_range: float = 7.5
var max_lifetime: float = 2.8
var visual_style: String = "blackflame_bolt"

var _elapsed: float = 0.0
var _pierces_used: int = 0
var _hit_instance_ids: Dictionary = {}
var _expired: bool = false


func setup(
	p_director: Node,
	p_vfx: Node3D,
	p_attacker: Node3D,
	p_team: DamageEvent.Team,
	p_origin: Vector3,
	p_direction: Vector3,
	p_speed: float,
	p_damage: float,
	p_source_id: String,
	p_visual_style: String = "blackflame_bolt",
	p_pierce_count: int = 0,
	p_chain_remaining: int = 0,
	p_kind: DamageEvent.Kind = DamageEvent.Kind.PHYSICAL
) -> void:
	director = p_director
	vfx = p_vfx
	attacker = p_attacker
	team = p_team
	var flat_dir := Vector3(p_direction.x, 0.0, p_direction.z)
	direction = flat_dir.normalized() if flat_dir.length_squared() > 0.0001 else Vector3.FORWARD
	speed = maxf(1.0, p_speed)
	damage = maxf(0.0, p_damage)
	source_id = p_source_id
	visual_style = p_visual_style
	pierce_count = maxi(0, p_pierce_count)
	chain_remaining = maxi(0, p_chain_remaining)
	damage_kind = p_kind

	global_position = Vector3(p_origin.x, clampf(p_origin.y, 0.75, 1.45), p_origin.z)
	rotation.y = atan2(-direction.x, -direction.z)
	_build_visual()


func _physics_process(delta: float) -> void:
	if _expired:
		return
	if director != null and bool(director.get("is_shrine_open")):
		return

	_elapsed += delta
	if _elapsed >= max_lifetime:
		_expire()
		return

	var prev_pos := global_position
	var next_pos := prev_pos + direction * (speed * delta)
	global_position = next_pos

	if director != null and director.has_method("is_outside_arena_bounds"):
		if bool(director.call("is_outside_arena_bounds", next_pos)):
			_expire()
			return

	if team == DamageEvent.Team.HERO:
		_sweep_enemies(prev_pos, next_pos)
	else:
		_sweep_hero(prev_pos, next_pos)


func _sweep_enemies(prev_pos: Vector3, next_pos: Vector3) -> void:
	var enemies: Array = []
	if director != null and director.has_method("get_alive_enemies"):
		enemies = director.call("get_alive_enemies")
	elif is_inside_tree():
		enemies = get_tree().get_nodes_in_group("combat_enemies")

	for raw_enemy in enemies:
		if _expired:
			return
		var enemy := raw_enemy as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var iid := enemy.get_instance_id()
		if _hit_instance_ids.has(iid):
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue

		var target_radius := float(enemy.get("body_radius")) if enemy.get("body_radius") != null else 0.65
		if _segment_hits_circle_xz(prev_pos, next_pos, enemy.global_position, hit_radius + target_radius):
			_hit_instance_ids[iid] = true
			_apply_hero_projectile_hit(enemy)

			if _pierces_used < pierce_count:
				_pierces_used += 1
				continue

			if chain_remaining > 0 and _try_ricochet_to_next_enemy(enemy.global_position, enemies):
				return

			_expire()
			return


func _try_ricochet_to_next_enemy(from_pos: Vector3, enemies: Array) -> bool:
	var best_enemy: Node3D = null
	var best_dist_sq := chain_range * chain_range
	for raw_enemy in enemies:
		var cand := raw_enemy as Node3D
		if cand == null or not is_instance_valid(cand):
			continue
		if _hit_instance_ids.has(cand.get_instance_id()):
			continue
		if cand.has_method("is_dead") and bool(cand.call("is_dead")):
			continue
		var d_sq := Vector2(cand.global_position.x - from_pos.x, cand.global_position.z - from_pos.z).length_squared()
		if d_sq <= best_dist_sq:
			best_dist_sq = d_sq
			best_enemy = cand

	if best_enemy == null:
		return false

	chain_remaining -= 1
	var to_next := Vector3(best_enemy.global_position.x - global_position.x, 0.0, best_enemy.global_position.z - global_position.z)
	if to_next.length_squared() > 0.0001:
		direction = to_next.normalized()
		rotation.y = atan2(-direction.x, -direction.z)
	speed *= 1.12
	_elapsed = maxf(0.0, _elapsed - 0.35)

	if vfx != null and vfx.has_method("spawn_chain_lightning"):
		var pts := PackedVector3Array([
			from_pos + Vector3(0.0, 1.0, 0.0),
			best_enemy.global_position + Vector3(0.0, 1.0, 0.0),
		])
		vfx.call("spawn_chain_lightning", pts, false)

	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ricochet")
	return true


func _apply_hero_projectile_hit(enemy: Node3D) -> void:
	if attacker != null and is_instance_valid(attacker) and attacker.has_method("deliver_hit_to_enemy"):
		attacker.call("deliver_hit_to_enemy", enemy, damage, source_id, damage_kind)
	elif enemy.has_method("receive_damage"):
		var ev := DamageEvent.make_hero_hit(attacker, damage, source_id, damage_kind, false)
		ev.hit_position = global_position
		enemy.call("receive_damage", ev)


func _sweep_hero(prev_pos: Vector3, next_pos: Vector3) -> void:
	var hero: Node3D = null
	if director != null and director.get("hero") is Node3D:
		hero = director.get("hero") as Node3D
	elif is_inside_tree():
		var heroes := get_tree().get_nodes_in_group("combat_hero")
		if not heroes.is_empty():
			hero = heroes[0] as Node3D

	if hero == null or not is_instance_valid(hero):
		return
	if hero.has_method("is_dead") and bool(hero.call("is_dead")):
		return

	var hero_radius := float(hero.get("body_radius")) if hero.get("body_radius") != null else 0.48
	if _segment_hits_circle_xz(prev_pos, next_pos, hero.global_position, hit_radius + hero_radius):
		if hero.has_method("receive_damage"):
			var ev := DamageEvent.make_enemy_hit(attacker, damage, source_id, damage_kind)
			ev.hit_position = global_position
			hero.call("receive_damage", ev)
		_expire()


func _build_visual() -> void:
	match visual_style:
		"wraith_lance":
			hit_radius = 0.52
		"blood_orb":
			hit_radius = 0.46
		"boss_ember":
			hit_radius = 0.50
		_:
			hit_radius = 0.48

	if DisplayServer.get_name() == "headless":
		return

	if visual_style == "wraith_lance":
		_build_energy_shard_visual(Color(0.96, 0.22, 0.36, 1.0))
	elif visual_style == "voidpyre_bolt":
		_build_flame_bolt_visual(Vector3(3.8, 1.1, 5.4), Vector3(1.5, 0.30, 2.4), Color(0.62, 0.34, 1.0), 0.52)
	elif visual_style == "blood_orb":
		_build_flame_bolt_visual(Vector3(4.6, 0.52, 0.72), Vector3(2.0, 0.14, 0.24), Color(0.95, 0.16, 0.28), 0.54)
	else:
		_build_flame_bolt_visual(Vector3(5.2, 2.2, 0.48), Vector3(2.3, 0.48, 0.09), Color(1.0, 0.48, 0.14), 0.56)


func _build_flame_bolt_visual(core_hdr: Vector3, mid_flame: Vector3, light_col: Color, soot: float) -> void:
	var holder := Node3D.new()
	holder.name = "VolumetricBoltVfx"
	add_child(holder)

	if _cached_flame_sh == null:
		_cached_flame_sh = load("res://shaders/vfx_smokey_flame.gdshader") as Shader
	if _cached_noise_tex == null and ResourceLoader.exists(VFX_NOISE_TEX_PATH):
		_cached_noise_tex = load(VFX_NOISE_TEX_PATH) as Texture2D
	if _cached_tail_quad == null:
		_cached_tail_quad = QuadMesh.new()
		_cached_tail_quad.size = Vector2(0.54, 1.32)
	if _cached_head_quad == null:
		_cached_head_quad = QuadMesh.new()
		_cached_head_quad.size = Vector2(0.70, 0.84)

	if _cached_flame_sh != null:
		var tail_mat := ShaderMaterial.new()
		tail_mat.shader = _cached_flame_sh
		if _cached_noise_tex != null:
			tail_mat.set_shader_parameter("noise_tex", _cached_noise_tex)
		tail_mat.set_shader_parameter("billboard_mode", false)
		tail_mat.set_shader_parameter("soot_dominance", soot)
		tail_mat.set_shader_parameter("core_hdr", core_hdr)
		tail_mat.set_shader_parameter("mid_flame", mid_flame)
		tail_mat.set_shader_parameter("scroll_speed", 4.8)
		tail_mat.set_shader_parameter("noise_scale", 5.2)

		var tmi := MeshInstance3D.new()
		tmi.mesh = _cached_tail_quad
		tmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		tmi.position = Vector3(0.0, 0.0, 0.22)
		tmi.material_override = tail_mat
		tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(tmi)

		var head_mat := ShaderMaterial.new()
		head_mat.shader = _cached_flame_sh
		head_mat.render_priority = 1
		if _cached_noise_tex != null:
			head_mat.set_shader_parameter("noise_tex", _cached_noise_tex)
		head_mat.set_shader_parameter("billboard_mode", true)
		head_mat.set_shader_parameter("soot_dominance", maxf(0.18, soot - 0.22))
		head_mat.set_shader_parameter("core_hdr", core_hdr * 1.15)
		head_mat.set_shader_parameter("mid_flame", mid_flame)
		head_mat.set_shader_parameter("scroll_speed", 4.4)
		var hmi := MeshInstance3D.new()
		hmi.mesh = _cached_head_quad
		hmi.position = Vector3(0.0, 0.0, -0.14)
		hmi.material_override = head_mat
		hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(hmi)

	_attach_bolt_trail_sparks(holder, light_col)


func _build_energy_shard_visual(energy_col: Color) -> void:
	var holder := Node3D.new()
	holder.name = "EnergyShardVfx"
	add_child(holder)

	if _cached_energy_sh == null:
		_cached_energy_sh = load("res://shaders/vfx_energy.gdshader") as Shader
	if _cached_lance_mesh == null:
		_cached_lance_mesh = CylinderMesh.new()
		_cached_lance_mesh.top_radius = 0.0
		_cached_lance_mesh.bottom_radius = 0.12
		_cached_lance_mesh.height = 1.38
		_cached_lance_mesh.radial_segments = 4

	var shard_mat: Material
	if _cached_energy_sh != null:
		var sm := ShaderMaterial.new()
		sm.shader = _cached_energy_sh
		sm.set_shader_parameter("beam_mode", 0)
		sm.set_shader_parameter("energy_color", energy_col)
		sm.set_shader_parameter("hdr_gain", 2.65)
		shard_mat = sm
	else:
		var std := StandardMaterial3D.new()
		std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std.albedo_color = energy_col * 2.2
		shard_mat = std

	var mi := MeshInstance3D.new()
	mi.mesh = _cached_lance_mesh
	mi.rotation_degrees.x = -90.0
	mi.material_override = shard_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)

	_attach_bolt_trail_sparks(holder, energy_col)


func _attach_bolt_trail_sparks(holder: Node3D, col: Color) -> void:
	var proc := ParticleProcessMaterial.new()
	proc.particle_flag_align_y = true
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.08
	proc.direction = Vector3(0.0, 0.35, 1.0).normalized()
	proc.spread = 32.0
	proc.initial_velocity_min = 1.4
	proc.initial_velocity_max = 3.2
	proc.gravity = Vector3(0.0, -2.5, 0.0)
	proc.scale_min = 0.65
	proc.scale_max = 1.25

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.96, 0.88, 1.0),
		Color(col.r, col.g, col.b, 0.90),
		Color(col.r * 0.3, col.g * 0.2, col.b * 0.15, 0.0),
	])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	proc.color_ramp = gtex

	if _cached_spark_sh == null:
		_cached_spark_sh = load("res://shaders/vfx_spark.gdshader") as Shader
	var spark_mesh := BladeScrapeVfx.make_crossed_spark_mesh(0.055, 0.24)
	if _cached_spark_sh != null:
		var sm := ShaderMaterial.new()
		sm.shader = _cached_spark_sh
		sm.render_priority = 2
		sm.set_shader_parameter("spark_hdr", Vector4(col.r * 4.2, col.g * 3.8, col.b * 3.2, 1.0))
		spark_mesh.surface_set_material(0, sm)

	var gp := GPUParticles3D.new()
	gp.amount = 6
	gp.lifetime = 0.30
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.process_material = proc
	gp.draw_pass_1 = spark_mesh
	holder.add_child(gp)


func _expire() -> void:
	if _expired:
		return
	_expired = true
	visible = false
	set_physics_process(false)
	queue_free()


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


static func _segment_hits_circle_xz(a: Vector3, b: Vector3, center: Vector3, radius: float) -> bool:
	var p0 := Vector2(a.x, a.z)
	var p1 := Vector2(b.x, b.z)
	var c := Vector2(center.x, center.z)
	var ab := p1 - p0
	var len_sq := ab.length_squared()
	var closest := p0
	if len_sq > 0.000001:
		var t := clampf((c - p0).dot(ab) / len_sq, 0.0, 1.0)
		closest = p0 + ab * t
	return closest.distance_squared_to(c) <= radius * radius
