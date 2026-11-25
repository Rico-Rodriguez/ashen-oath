class_name CombatProjectile
extends Node3D

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
		vfx.call("spawn_chain_lightning", pts)

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
	if visual_style in ["blackflame_bolt", "voidpyre_bolt"] and vfx != null and vfx.has_method("spawn_blackflame_bolt_vfx"):
		vfx.call("spawn_blackflame_bolt_vfx", self)

	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true

	match visual_style:
		"wraith_lance":
			hit_radius = 0.52
			var lance := CylinderMesh.new()
			lance.top_radius = 0.02
			lance.bottom_radius = 0.11
			lance.height = 1.45
			lance.radial_segments = 6
			mi.mesh = lance
			mi.rotation_degrees.x = 90.0
			mat.albedo_color = Color(0.95, 0.24, 0.36, 0.92)
			mat.emission = Color(1.0, 0.18, 0.32, 1.0)
			mat.emission_energy_multiplier = 3.2
		"blood_orb":
			hit_radius = 0.44
			var orb := SphereMesh.new()
			orb.radius = 0.22
			orb.height = 0.44
			orb.radial_segments = 10
			orb.rings = 6
			mi.mesh = orb
			mat.albedo_color = Color(0.88, 0.10, 0.18, 1.0)
			mat.emission = Color(0.96, 0.12, 0.22, 1.0)
			mat.emission_energy_multiplier = 2.8
		"boss_ember":
			hit_radius = 0.50
			var ember := SphereMesh.new()
			ember.radius = 0.26
			ember.height = 0.52
			ember.radial_segments = 10
			ember.rings = 6
			mi.mesh = ember
			mat.albedo_color = Color(1.0, 0.42, 0.10, 1.0)
			mat.emission = Color(1.0, 0.32, 0.06, 1.0)
			mat.emission_energy_multiplier = 3.4
		_:
			hit_radius = 0.46
			var core := SphereMesh.new()
			core.radius = 0.19
			core.height = 0.38
			core.radial_segments = 10
			core.rings = 6
			mi.mesh = core
			var is_void := visual_style == "voidpyre_bolt"
			mat.albedo_color = Color(0.62, 0.24, 0.96, 1.0) if is_void else Color(1.0, 0.56, 0.18, 1.0)
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 3.0

	mi.material_override = mat
	add_child(mi)


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
