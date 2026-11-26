class_name HeroController3D
extends CharacterBody3D

signal health_changed(current_hp: float, max_hp: float, ward_hp: float)
signal cooldowns_changed(dash_cd: float, dash_max: float, s1_cd: float, s1_max: float, s2_cd: float, s2_max: float)
signal died()
signal dodged_attack(world_pos: Vector3)
signal dealt_damage(target: Node3D, event: DamageEvent)
signal took_damage(event: DamageEvent)

var director: Node = null
var vfx: Node3D = null
var class_id: String = "oathbreaker"
var class_def: HeroClassDef = null
var stats: CombatStats = null
var visual: ActorVisual = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var current_hp: float = 200.0
var ward_hp: float = 0.0
var body_radius: float = 0.48
var external_move_input: Vector2 = Vector2.ZERO
var manual_attack_requested: bool = false
var manual_attack_held: bool = false
var auto_attack_enabled: bool = true
var active_blessings: Array[String] = []
var equipped_items: Dictionary = {}

var dash_cooldown_left: float = 0.0
var dash_cooldown_max: float = 3.0
var skill_1_cooldown_left: float = 0.0
var skill_1_cooldown_max: float = 6.0
var skill_2_cooldown_left: float = 0.0
var skill_2_cooldown_max: float = 8.0
var skill_3_cooldown_left: float = 0.0
var skill_3_cooldown_max: float = 8.0

var _is_dead: bool = false
var _combo_toggle: bool = false
var _attack_cooldown: float = 0.0
var _attack_strike_window: float = 0.0
var _attack_anim_timer: float = 0.0
var _skill_anim_timer: float = 0.0
var _skill_slash_ribbon_timer: float = 0.0
var _locked_attack_dir: Vector3 = Vector3.FORWARD

var _iframe_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_speed: float = 34.444
var _ward_hold_timer: float = 0.0

var _whirlwind_timer: float = 0.0
var _whirlwind_tick_timer: float = 0.0

var _charge_timer: float = 0.0
var _charge_dir: Vector3 = Vector3.FORWARD
var _charge_speed: float = 36.364
var _charge_hit_ids: Dictionary = {}

var _pyre_zones: Array[Dictionary] = []
var _lantern_aura_timer: float = 0.5
var _scrape_sfx_timer: float = 0.0

var _blade_scrape: Node3D = null
var _weapon_ribbon: Node3D = null


func _ready() -> void:
	add_to_group("combat_hero")
	collision_layer = 2
	collision_mask = 1
	_ensure_collider()


func _exit_tree() -> void:
	if _blade_scrape != null and is_instance_valid(_blade_scrape) and _blade_scrape.get_parent() != self:
		_blade_scrape.queue_free()
	if _weapon_ribbon != null and is_instance_valid(_weapon_ribbon) and _weapon_ribbon.get_parent() != self:
		_weapon_ribbon.queue_free()


func setup(
	p_director: Node,
	p_vfx: Node3D,
	p_class_def: HeroClassDef,
	p_stats: CombatStats,
	p_equipped: Dictionary = {},
	p_rng: RandomNumberGenerator = null
) -> void:
	director = p_director
	vfx = p_vfx
	class_def = p_class_def if p_class_def != null else GameRegistry.get_class_def("oathbreaker")
	class_id = class_def.class_id
	equipped_items = p_equipped.duplicate()
	stats = p_stats if p_stats != null else LootEngine.compute_combat_stats(class_def, equipped_items, active_blessings)
	if p_rng != null:
		rng = p_rng
	else:
		rng.randomize()

	_is_dead = false
	current_hp = stats.max_hp
	ward_hp = 0.0
	_recompute_cooldown_caps()
	dash_cooldown_left = 0.0
	skill_1_cooldown_left = 0.0
	skill_2_cooldown_left = 0.0
	skill_3_cooldown_left = 0.0

	_mount_visual()
	_setup_weapon_vfx()
	health_changed.emit(current_hp, stats.max_hp, ward_hp)
	_emit_cooldowns()


func is_dead() -> bool:
	return _is_dead


func is_invulnerable() -> bool:
	return _iframe_timer > 0.0


func grant_iframes(duration: float) -> void:
	_iframe_timer = maxf(_iframe_timer, duration)


func refresh_combat_stats(new_stats: CombatStats, heal_pct_of_max: float = 0.0) -> void:
	if new_stats == null:
		return
	var old_max := stats.max_hp if stats != null else new_stats.max_hp
	var old_mesh := stats.weapon_mesh_key if stats != null else ""
	var old_offhand := stats.offhand_mesh_key if stats != null else ""
	var old_armor_tier := stats.armor_tier if stats != null else 1
	var old_plume := stats.has_plume if stats != null else false
	var old_lantern := stats.lantern_color if stats != null else Color.WHITE
	var old_overrides := stats.to_slot_overrides() if stats != null else {}

	stats = new_stats
	if stats.max_hp > old_max:
		current_hp += (stats.max_hp - old_max)
	if heal_pct_of_max > 0.0:
		current_hp += stats.max_hp * heal_pct_of_max
	current_hp = clampf(current_hp, 0.0, stats.max_hp)
	_recompute_cooldown_caps()

	var new_overrides := stats.to_slot_overrides()
	if visual != null and (
		old_mesh != stats.weapon_mesh_key
		or old_offhand != stats.offhand_mesh_key
		or old_armor_tier != stats.armor_tier
		or old_plume != stats.has_plume
		or not old_lantern.is_equal_approx(stats.lantern_color)
		or old_overrides != new_overrides
	):
		HeroRigDresser.dress(
			visual,
			class_id,
			stats.armor_tier,
			stats.weapon_mesh_key,
			stats.offhand_mesh_key,
			stats.has_plume,
			stats.lantern_color,
			new_overrides
		)

	health_changed.emit(current_hp, stats.max_hp, ward_hp)
	_emit_cooldowns()


func heal(amount: float) -> float:
	if _is_dead or amount <= 0.0 or stats == null:
		return 0.0
	var before := current_hp
	current_hp = minf(stats.max_hp, current_hp + amount)
	var gained := current_hp - before
	if gained > 0.05:
		health_changed.emit(current_hp, stats.max_hp, ward_hp)
		if director != null and director.has_method("notify_heal_floated"):
			director.call("notify_heal_floated", global_position + Vector3(0.0, 1.8, 0.0), roundi(gained))
	return gained


func _physics_process(delta: float) -> void:
	if _is_dead or stats == null:
		velocity = Vector3.ZERO
		return
	if director != null and bool(director.get("is_shrine_open")):
		velocity = Vector3.ZERO
		return

	_tick_timers(delta)
	_poll_action_triggers()

	var move_dir := _read_move_direction()

	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)
		velocity = _dash_dir * _dash_speed
		_face_direction_instant(_dash_dir)
		move_and_slide()
		_constrain_to_ground_and_bounds()
		_update_vfx_attachments(delta)
		return

	if _charge_timer > 0.0:
		_charge_timer = maxf(0.0, _charge_timer - delta)
		velocity = _charge_dir * _charge_speed
		_face_direction_instant(_charge_dir)
		move_and_slide()
		_constrain_to_ground_and_bounds()
		_sweep_bulwark_charge_path()
		if _charge_timer <= 0.0:
			_finish_bulwark_charge_slam()
		_update_vfx_attachments(delta)
		return

	var speed_mult := 1.0
	if _whirlwind_timer > 0.0:
		speed_mult = 1.10
	elif _attack_strike_window > 0.0:
		speed_mult = 0.88 if stats.is_ranged else 0.82

	velocity = move_dir * (stats.move_speed * speed_mult)
	move_and_slide()
	if move_dir.length_squared() > 0.0004:
		_enforce_enemy_soft_separation()
	_constrain_to_ground_and_bounds()

	if _whirlwind_timer > 0.0:
		_tick_whirlwind(delta)
	else:
		if visual != null and absf(visual.rotation.y) > 0.001:
			visual.rotation.y = lerp_angle(visual.rotation.y, 0.0, 1.0 - exp(-18.0 * delta))
			if absf(visual.rotation.y) < 0.01:
				visual.rotation.y = 0.0
		var was_striking := _attack_strike_window > 0.0
		_try_auto_or_manual_attack()
		if not was_striking and _attack_strike_window > 0.0:
			velocity = move_dir * (stats.move_speed * (0.88 if stats.is_ranged else 0.82))

	if _attack_strike_window > 0.0 or _skill_anim_timer > 0.0:
		_face_direction_smooth(_locked_attack_dir, 26.0, delta)
	elif move_dir.length_squared() > 0.0004:
		_face_direction_smooth(move_dir, 16.0, delta)

	_update_locomotion_animation()
	_tick_pyre_zones(delta)
	_tick_lantern_aura(delta)
	_update_vfx_attachments(delta)


func _tick_timers(delta: float) -> void:
	var cd_dirty := false
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
		cd_dirty = true
	if skill_1_cooldown_left > 0.0:
		skill_1_cooldown_left = maxf(0.0, skill_1_cooldown_left - delta)
		cd_dirty = true
	if skill_2_cooldown_left > 0.0:
		skill_2_cooldown_left = maxf(0.0, skill_2_cooldown_left - delta)
		cd_dirty = true
	if skill_3_cooldown_left > 0.0:
		skill_3_cooldown_left = maxf(0.0, skill_3_cooldown_left - delta)
		cd_dirty = true
	if cd_dirty:
		_emit_cooldowns()

	if _iframe_timer > 0.0:
		_iframe_timer = maxf(0.0, _iframe_timer - delta)
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _attack_strike_window > 0.0:
		_attack_strike_window = maxf(0.0, _attack_strike_window - delta)
	if _attack_anim_timer > 0.0:
		_attack_anim_timer = maxf(0.0, _attack_anim_timer - delta)
	if _skill_anim_timer > 0.0:
		_skill_anim_timer = maxf(0.0, _skill_anim_timer - delta)
	if _skill_slash_ribbon_timer > 0.0:
		_skill_slash_ribbon_timer = maxf(0.0, _skill_slash_ribbon_timer - delta)

	if ward_hp > 0.0:
		if _ward_hold_timer > 0.0:
			_ward_hold_timer = maxf(0.0, _ward_hold_timer - delta)
		else:
			var decay := maxf(6.0, stats.max_hp * 0.05) * delta
			ward_hp = maxf(0.0, ward_hp - decay)
			health_changed.emit(current_hp, stats.max_hp, ward_hp)


func _poll_action_triggers() -> void:
	if Input.is_action_just_pressed("dash"):
		trigger_dash()
	if Input.is_action_just_pressed("skill_1"):
		trigger_skill_1()
	if Input.is_action_just_pressed("skill_2"):
		trigger_skill_2()
	if Input.is_action_just_pressed("skill_3"):
		trigger_skill_3()


func _read_move_direction() -> Vector3:
	var v2 := external_move_input
	if v2.length_squared() <= 0.0004:
		v2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v2.length_squared() <= 0.0004:
		return Vector3.ZERO
	v2 = v2.limit_length(1.0)
	return Vector3(v2.x, 0.0, v2.y)


func _try_auto_or_manual_attack() -> void:
	if _attack_cooldown > 0.0:
		manual_attack_requested = false
		return

	var range_factor := 1.15 if stats.is_ranged else (1.05 * stats.cleave_size_mult)
	var acquire_range := stats.attack_range * range_factor
	var nearest := _find_nearest_enemy(acquire_range)
	var manual := manual_attack_requested or manual_attack_held or Input.is_action_pressed("attack")
	manual_attack_requested = false

	if (auto_attack_enabled and nearest != null) or manual:
		_perform_primary_attack(nearest)


func _perform_primary_attack(target: Node3D) -> void:
	_attack_cooldown = stats.attack_interval
	_attack_strike_window = 0.14
	_attack_anim_timer = minf(0.46, stats.attack_interval * 0.78)

	var forward := _forward_dir()
	if target != null and is_instance_valid(target):
		var to_t := Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z)
		if to_t.length_squared() > 0.0001:
			forward = to_t.normalized()
	_locked_attack_dir = forward
	_face_direction_instant(forward)

	if visual != null:
		var clip := "attack2" if _combo_toggle else "attack"
		var anim_spd := clampf(0.68 / maxf(stats.attack_interval, 0.2), 1.0, 2.0)
		visual.play_anim(clip, anim_spd, true)
	_combo_toggle = not _combo_toggle
	_play_sfx(stats.weapon_sfx_event if stats.weapon_sfx_event != "" else "swing")

	if stats.is_ranged:
		var origin := visual.get_cast_origin_global() if visual != null else (global_position + Vector3(0.0, 1.15, 0.0))
		var style := stats.weapon_vfx_profile if stats.weapon_vfx_profile != "" else "blackflame_bolt"
		_spawn_hero_projectile(
			origin,
			forward,
			maxf(12.0, stats.projectile_speed),
			stats.attack_damage,
			"primary",
			style,
			0,
			stats.chain_bonus_targets,
			DamageEvent.Kind.FIRE
		)
		return

	var strike_range := stats.attack_range * stats.cleave_size_mult
	var strike_arc := clampf(stats.cleave_arc_deg * minf(stats.cleave_size_mult, 1.35), 45.0, 360.0)
	if vfx != null and vfx.has_method("spawn_slash_arc"):
		vfx.call("spawn_slash_arc", global_position + Vector3(0.0, 1.0, 0.0), forward, strike_range, strike_arc, _weapon_tint())

	var hit_reach := strike_range * 1.08
	for enemy in _get_alive_enemies():
		var e_rad := _enemy_radius(enemy)
		if _is_in_cone_xz(global_position, forward, enemy.global_position, hit_reach + e_rad, strike_arc, 0.90 + e_rad * 0.5):
			deliver_hit_to_enemy(enemy, stats.attack_damage, "primary", DamageEvent.Kind.PHYSICAL)


func trigger_dash() -> bool:
	if _is_dead or stats == null or class_def == null or class_def.dash_ability == null:
		return false
	if dash_cooldown_left > 0.0 or _dash_timer > 0.0:
		return false

	_recompute_cooldown_caps()
	dash_cooldown_left = dash_cooldown_max
	_attack_strike_window = 0.0
	_attack_anim_timer = 0.0
	_charge_timer = 0.0

	var move_dir := _read_move_direction()
	_dash_dir = move_dir.normalized() if move_dir.length_squared() > 0.001 else _forward_dir()
	_dash_timer = 0.18
	_dash_speed = 6.2 / 0.18
	_iframe_timer = maxf(_iframe_timer, 0.26)
	_face_direction_instant(_dash_dir)

	if stats.ward_on_dash_hp > 0.0:
		ward_hp = maxf(ward_hp, stats.ward_on_dash_hp)
		_ward_hold_timer = 4.0
		health_changed.emit(current_hp, stats.max_hp, ward_hp)

	if visual != null:
		visual.rotation.y = 0.0
		visual.play_anim("dash", 1.35, true)
	if vfx != null and vfx.has_method("spawn_hit_sparks"):
		vfx.call("spawn_hit_sparks", global_position + Vector3(0.0, 0.72, 0.0), Color(1.0, 0.48, 0.14), true)
	var sfx_ev := class_def.dash_ability.sfx_event if class_def.dash_ability.sfx_event != "" else "dodge"
	_play_sfx(sfx_ev)
	_emit_cooldowns()
	return true


func trigger_skill_1() -> bool:
	if _is_dead or stats == null or class_def == null or class_def.skill_1 == null:
		return false
	if skill_1_cooldown_left > 0.0 or _dash_timer > 0.0 or _charge_timer > 0.0:
		return false

	_recompute_cooldown_caps()
	skill_1_cooldown_left = skill_1_cooldown_max
	_execute_ability(class_def.skill_1)
	_emit_cooldowns()
	return true


func trigger_skill_2() -> bool:
	if _is_dead or stats == null or class_def == null or class_def.skill_2 == null:
		return false
	if skill_2_cooldown_left > 0.0 or _dash_timer > 0.0 or _charge_timer > 0.0:
		return false

	_recompute_cooldown_caps()
	skill_2_cooldown_left = skill_2_cooldown_max
	_execute_ability(class_def.skill_2)
	_emit_cooldowns()
	return true


func trigger_skill_3() -> bool:
	if _is_dead or stats == null or class_def == null or class_def.skill_3 == null:
		return false
	if skill_3_cooldown_left > 0.0 or _dash_timer > 0.0 or _charge_timer > 0.0:
		return false

	_recompute_cooldown_caps()
	skill_3_cooldown_left = skill_3_cooldown_max
	_execute_ability(class_def.skill_3)
	_emit_cooldowns()
	return true


func _execute_ability(ab: AbilityDef) -> void:
	match ab.ability_id:
		"iron_tempest":
			_whirlwind_timer = 2.0
			_whirlwind_tick_timer = 0.0
			_attack_strike_window = 0.0
			_attack_anim_timer = 0.0
			if visual != null and visual.is_unified_kit():
				visual.rotation.y = 0.0
				visual.play_anim("attack_whirl", 1.65, true)
			_play_sfx("blades")
			_whirlwind_pulse_cleave()
			_whirlwind_tick_timer = 0.28
		"bulwark_charge":
			var dir := _aim_direction_for_skill(10.0)
			_charge_dir = dir
			_charge_timer = 0.22
			_charge_speed = 8.0 / 0.22
			_charge_hit_ids.clear()
			_iframe_timer = maxf(_iframe_timer, 0.22)
			_whirlwind_timer = 0.0
			_face_direction_instant(dir)
			if visual != null:
				visual.rotation.y = 0.0
				visual.play_anim("skill_cast", 1.35, true)
			_play_sfx("charge")
			_sweep_bulwark_charge_path()
		"blackflame_pyre":
			var radius := 3.5 * stats.cleave_size_mult
			var is_slam := ab.anim_clip == "skill_slam"
			var target_pos := _find_best_cluster_pos(10.0, radius)
			var to_p := Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
			if to_p.length_squared() > 0.0001:
				_locked_attack_dir = to_p.normalized()
				_face_direction_instant(_locked_attack_dir)
			_skill_anim_timer = 0.44 if is_slam else 0.34
			if visual != null:
				visual.play_anim("skill_slam" if is_slam else "skill_cast", 1.25, true)
			_play_sfx("meteor")
			if is_slam and director != null:
				if director.has_method("add_camera_trauma"):
					director.call("add_camera_trauma", 0.36)
				if director.has_method("add_camera_kick"):
					director.call("add_camera_kick", _locked_attack_dir, 0.28)
			if vfx != null and vfx.has_method("spawn_blackflame_pyre"):
				vfx.call("spawn_blackflame_pyre", target_pos, radius)
			var blast_dmg := stats.attack_damage * ab.damage_mult
			var slam_stagger := 0.85 if is_slam else 0.0
			for enemy in _get_alive_enemies():
				if _dist_xz(target_pos, enemy.global_position) <= radius + _enemy_radius(enemy):
					deliver_hit_to_enemy(enemy, blast_dmg, "blackflame_pyre", DamageEvent.Kind.FIRE, slam_stagger)
			_pyre_zones.append({
				"pos": target_pos,
				"radius": radius,
				"remaining": 3.0,
				"tick_timer": 0.5,
				"tick_damage": stats.attack_damage * 0.55,
			})
		"stormbrand_arc":
			var max_targets := 4 + stats.chain_bonus_targets
			var origin := visual.get_cast_origin_global() if visual != null else (global_position + Vector3(0.0, 1.2, 0.0))
			var chained := _collect_chain_targets(global_position, 9.5, max_targets)
			var points := PackedVector3Array([origin])
			if not chained.is_empty():
				var first_dir := Vector3(chained[0].global_position.x - global_position.x, 0.0, chained[0].global_position.z - global_position.z)
				if first_dir.length_squared() > 0.0001:
					_locked_attack_dir = first_dir.normalized()
					_face_direction_instant(_locked_attack_dir)
				for e in chained:
					points.append(e.global_position + Vector3(0.0, 1.05, 0.0))
			else:
				points.append(origin + _forward_dir() * 6.0)
			_skill_anim_timer = 0.34
			if visual != null:
				visual.play_anim("skill_cast", 1.35, true)
			_play_sfx("chain")
			if director != null and director.has_method("add_camera_trauma"):
				director.call("add_camera_trauma", 0.22)
			if vfx != null and vfx.has_method("spawn_chain_lightning"):
				vfx.call("spawn_chain_lightning", points)
			var arc_dmg := stats.attack_damage * ab.damage_mult
			for e in chained:
				deliver_hit_to_enemy(e, arc_dmg, "stormbrand_arc", DamageEvent.Kind.LIGHTNING)
		"reaping_sweep":
			var sweep_dir := _aim_direction_for_skill(5.5)
			_locked_attack_dir = sweep_dir
			_face_direction_instant(sweep_dir)
			_skill_anim_timer = 0.34
			_skill_slash_ribbon_timer = 0.30
			if visual != null:
				visual.play_anim("attack2", 1.25, true)
			_play_sfx("cleave")
			var sweep_radius := 4.4 * stats.cleave_size_mult
			var sweep_arc := 190.0
			if vfx != null and vfx.has_method("spawn_slash_arc"):
				vfx.call("spawn_slash_arc", global_position + Vector3(0.0, 1.0, 0.0), sweep_dir, sweep_radius, sweep_arc, Color(0.92, 0.12, 0.22, 1.0))
			var rend_dmg := stats.attack_damage * ab.damage_mult
			var bleed_dps := stats.attack_damage * 0.45
			var hits := 0
			for enemy in _get_alive_enemies():
				var e_rad := _enemy_radius(enemy)
				if _is_in_cone_xz(global_position, sweep_dir, enemy.global_position, sweep_radius + e_rad, sweep_arc, 1.1 + e_rad * 0.5):
					deliver_hit_to_enemy(enemy, rend_dmg, "reaping_sweep", DamageEvent.Kind.BLEED, 0.0, bleed_dps, 3.0)
					var missing := maxf(0.0, stats.max_hp - current_hp)
					if missing > 0.0:
						heal(missing * 0.08)
					hits += 1
			if hits > 0:
				_play_sfx("lifesteal")
		"wraith_lances":
			var aim_dir := _aim_direction_for_skill(12.0)
			_locked_attack_dir = aim_dir
			_face_direction_instant(aim_dir)
			_skill_anim_timer = 0.28
			if visual != null:
				visual.play_anim("attack", 1.35, true)
			_play_sfx("volley")
			var origin := global_position + aim_dir * 0.55 + Vector3(0.0, 1.05, 0.0)
			var lance_dmg := stats.attack_damage * ab.damage_mult
			var base_yaw := atan2(-aim_dir.x, -aim_dir.z)
			var spread_angles := [-22.0, -11.0, 0.0, 11.0, 22.0]
			for deg in spread_angles:
				var yaw := base_yaw + deg_to_rad(float(deg))
				var fan_dir := Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
				_spawn_hero_projectile(
					origin,
					fan_dir,
					18.0,
					lance_dmg,
					"wraith_lances",
					"wraith_lance",
					3,
					0,
					DamageEvent.Kind.SHADOW
				)


func _tick_whirlwind(delta: float) -> void:
	_whirlwind_timer = maxf(0.0, _whirlwind_timer - delta)
	if visual != null:
		if visual.is_unified_kit():
			visual.rotation.y = 0.0
			visual.play_anim("attack_whirl", 1.65, false)
		else:
			visual.rotation.y = wrapf(visual.rotation.y + TAU * 3.0 * delta, -PI, PI)
			visual.play_anim("attack", 1.75, false)

	_whirlwind_tick_timer -= delta
	if _whirlwind_tick_timer <= 0.0:
		_whirlwind_tick_timer += 0.28
		_whirlwind_pulse_cleave()


func _whirlwind_pulse_cleave() -> void:
	var radius := 3.6 * stats.cleave_size_mult
	var tick_dmg := stats.attack_damage * (class_def.skill_1.damage_mult if class_def != null and class_def.skill_1 != null else 2.1) * 0.42
	if vfx != null:
		if vfx.has_method("spawn_shockwave_ring"):
			vfx.call("spawn_shockwave_ring", global_position, radius * 0.85, Color(1.0, 0.52, 0.16, 0.9))
		if vfx.has_method("spawn_hit_sparks"):
			var tip_p := visual.get_blade_tip_global() if visual != null else (global_position + Vector3(1.5, 0.4, 0.0))
			vfx.call("spawn_hit_sparks", Vector3(tip_p.x, 0.25, tip_p.z), Color(1.0, 0.62, 0.18), true)
	_play_sfx("swing", -3.0, 1.12)
	for enemy in _get_alive_enemies():
		if _dist_xz(global_position, enemy.global_position) <= radius + _enemy_radius(enemy):
			deliver_hit_to_enemy(enemy, tick_dmg, "iron_tempest", DamageEvent.Kind.PHYSICAL)


func _sweep_bulwark_charge_path() -> void:
	var lane_radius := 1.65 * stats.cleave_size_mult
	var rush_dmg := stats.attack_damage * (class_def.skill_2.damage_mult if class_def != null and class_def.skill_2 != null else 2.6) * 0.65
	for enemy in _get_alive_enemies():
		var iid := enemy.get_instance_id()
		if _charge_hit_ids.has(iid):
			continue
		if _dist_xz(global_position, enemy.global_position) <= lane_radius + _enemy_radius(enemy):
			_charge_hit_ids[iid] = true
			deliver_hit_to_enemy(enemy, rush_dmg, "bulwark_charge", DamageEvent.Kind.PHYSICAL, 0.35)


func _finish_bulwark_charge_slam() -> void:
	var slam_radius := 3.8 * stats.cleave_size_mult
	var slam_dmg := stats.attack_damage * (class_def.skill_2.damage_mult if class_def != null and class_def.skill_2 != null else 2.6)
	if vfx != null and vfx.has_method("spawn_shockwave_ring"):
		vfx.call("spawn_shockwave_ring", global_position, slam_radius, Color(1.0, 0.64, 0.22, 1.0))
	_play_sfx("charge_land")
	if director != null and director.has_method("add_camera_trauma"):
		director.call("add_camera_trauma", 0.38)
	for enemy in _get_alive_enemies():
		if _dist_xz(global_position, enemy.global_position) <= slam_radius + _enemy_radius(enemy):
			deliver_hit_to_enemy(enemy, slam_dmg, "bulwark_charge", DamageEvent.Kind.PHYSICAL, 0.9)


func _tick_pyre_zones(delta: float) -> void:
	if _pyre_zones.is_empty():
		return
	var i := _pyre_zones.size() - 1
	while i >= 0:
		var z: Dictionary = _pyre_zones[i]
		var rem := float(z["remaining"]) - delta
		var tt := float(z["tick_timer"]) - delta
		if tt <= 0.0:
			tt += 0.5
			var pos: Vector3 = z["pos"]
			var rad := float(z["radius"])
			var tdmg := float(z["tick_damage"])
			for enemy in _get_alive_enemies():
				if _dist_xz(pos, enemy.global_position) <= rad + _enemy_radius(enemy):
					deliver_hit_to_enemy(enemy, tdmg, "blackflame_pyre_dot", DamageEvent.Kind.FIRE, 0.0, 0.0, 0.0, false)
		if rem <= 0.0:
			_pyre_zones.remove_at(i)
		else:
			z["remaining"] = rem
			z["tick_timer"] = tt
			_pyre_zones[i] = z
		i -= 1


func _tick_lantern_aura(delta: float) -> void:
	if stats.lantern_aura_dps <= 0.0:
		return
	_lantern_aura_timer -= delta
	if _lantern_aura_timer > 0.0:
		return
	_lantern_aura_timer += 0.5
	var pulse_dmg := stats.lantern_aura_dps * 0.5
	for enemy in _get_alive_enemies():
		if _dist_xz(global_position, enemy.global_position) <= 3.5 + _enemy_radius(enemy):
			deliver_hit_to_enemy(enemy, pulse_dmg, "lantern_aura", DamageEvent.Kind.RADIANT, 0.0, 0.0, 0.0, false)


func deliver_hit_to_enemy(
	enemy: Node3D,
	base_damage: float,
	source_id: String,
	kind: DamageEvent.Kind = DamageEvent.Kind.PHYSICAL,
	stagger_sec: float = 0.0,
	bleed_dps: float = 0.0,
	bleed_dur: float = 0.0,
	triggers_on_hit: bool = true
) -> DamageEvent:
	if enemy == null or not is_instance_valid(enemy) or stats == null:
		return null
	if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
		return null

	var is_crit := triggers_on_hit and (rng.randf() < stats.crit_chance)
	var dmg := base_damage * (stats.crit_mult if is_crit else 1.0)
	var ev := DamageEvent.make_hero_hit(self, dmg, source_id, kind, is_crit)
	ev.triggers_on_hit = triggers_on_hit
	ev.is_dot = not triggers_on_hit and source_id in ["blackflame_pyre_dot", "lantern_aura"]
	ev.hit_position = enemy.global_position + Vector3(0.0, 1.05, 0.0)
	ev.stagger_sec = stagger_sec
	ev.bleed_dps = bleed_dps
	ev.bleed_duration = bleed_dur

	var kb_dir := Vector3(enemy.global_position.x - global_position.x, 0.0, enemy.global_position.z - global_position.z)
	kb_dir = kb_dir.normalized() if kb_dir.length_squared() > 0.0001 else _forward_dir()
	var kb_speed := 0.0
	if triggers_on_hit:
		match source_id:
			"bulwark_charge":
				kb_speed = 6.4
			"blackflame_pyre", "reaping_sweep":
				kb_speed = 5.6
			"iron_tempest":
				kb_speed = 4.2
			"primary":
				kb_speed = 5.2
	if kb_speed > 0.0:
		ev.knockback_impulse = kb_dir * kb_speed

	if triggers_on_hit and stats.spark_burn_dps > 0.0:
		ev.burn_dps += stats.spark_burn_dps
		ev.burn_duration = maxf(ev.burn_duration, 2.5)

	if enemy.has_method("receive_damage"):
		enemy.call("receive_damage", ev)

	if triggers_on_hit:
		if vfx != null and vfx.has_method("spawn_hit_sparks"):
			vfx.call("spawn_hit_sparks", ev.hit_position, _weapon_tint(), is_crit)
		_play_sfx("crit" if is_crit else "hit")
		var ad := _audio()
		if ad != null:
			ad.call("haptic", "heavy" if is_crit else "medium")

		var killed := enemy.has_method("is_dead") and bool(enemy.call("is_dead"))
		var heavy_skill := source_id in ["blackflame_pyre", "stormbrand_arc", "reaping_sweep", "bulwark_charge"]
		if director != null:
			if is_crit or heavy_skill or killed:
				if director.has_method("trigger_hitstop"):
					director.call("trigger_hitstop", 0.036)
				if director.has_method("add_camera_kick"):
					director.call("add_camera_kick", kb_dir, 0.24 if (is_crit or heavy_skill) else 0.16)

		if stats.life_on_hit > 0.0:
			heal(stats.life_on_hit)

		if is_crit and stats.crit_shockwave_damage > 0.0:
			var sw_radius := 2.8 * stats.cleave_size_mult
			if vfx != null and vfx.has_method("spawn_shockwave_ring"):
				vfx.call("spawn_shockwave_ring", enemy.global_position, sw_radius, Color(1.0, 0.78, 0.28, 1.0))
			for other in _get_alive_enemies():
				if _dist_xz(enemy.global_position, other.global_position) <= sw_radius + _enemy_radius(other):
					deliver_hit_to_enemy(other, stats.crit_shockwave_damage, "crit_shockwave", DamageEvent.Kind.PHYSICAL, 0.0, 0.0, 0.0, false)

	dealt_damage.emit(enemy, ev)
	return ev


func receive_damage(ev: DamageEvent) -> DamageEvent:
	if _is_dead or ev == null or stats == null:
		return ev

	if is_invulnerable():
		ev.negated_by_iframe = true
		ev.final_damage = 0.0
		dodged_attack.emit(global_position + Vector3(0.0, 1.15, 0.0))
		_play_sfx("block", -3.0, 1.18)
		return ev

	var mitigated := maxf(1.0, ev.raw_damage * stats.damage_taken_multiplier())
	if ward_hp > 0.0:
		var absorbed := minf(ward_hp, mitigated)
		ward_hp -= absorbed
		mitigated -= absorbed
		ev.absorbed_ward = absorbed
		if ward_hp <= 0.01:
			ward_hp = 0.0
			_play_sfx("shield_break")

	ev.final_damage = mitigated
	if mitigated > 0.0:
		current_hp = maxf(0.0, current_hp - mitigated)
		if visual != null:
			visual.trigger_hit_flash(0.12)
		_play_sfx("hero_hurt")
		var ad := _audio()
		if ad != null:
			ad.call("haptic", "heavy")
		if director != null and director.has_method("add_camera_trauma"):
			director.call("add_camera_trauma", 0.30)

	health_changed.emit(current_hp, stats.max_hp, ward_hp)
	took_damage.emit(ev)

	if current_hp <= 0.0 and not _is_dead:
		_is_dead = true
		velocity = Vector3.ZERO
		if visual != null:
			visual.rotation.y = 0.0
			visual.play_anim("death", 1.0, true)
		died.emit()

	return ev


func _spawn_hero_projectile(
	origin: Vector3,
	dir: Vector3,
	spd: float,
	dmg: float,
	src_id: String,
	style: String,
	pierce: int,
	chains: int,
	kind: DamageEvent.Kind
) -> CombatProjectile:
	var proj := CombatProjectile.new()
	var container: Node = self.get_parent()
	if director != null and director.get("projectiles_root") is Node3D:
		container = director.get("projectiles_root") as Node3D
	if container != null:
		container.add_child(proj)
	proj.setup(director, vfx, self, DamageEvent.Team.HERO, origin, dir, spd, dmg, src_id, style, pierce, chains, kind)
	return proj


func _mount_visual() -> void:
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
		visual = null

	var ps := load(class_def.actor_scene_path) as PackedScene
	if ps == null:
		return
	var slot_ov := stats.to_slot_overrides()
	visual = ps.instantiate() as ActorVisual
	visual.hero_class_id = class_id
	visual.armor_tier = stats.armor_tier
	visual.helm_tier = stats.helm_tier
	visual.cuirass_tier = stats.cuirass_tier
	visual.lantern_tier = stats.lantern_tier
	visual.weapon_key = stats.weapon_mesh_key
	visual.offhand_key = stats.offhand_mesh_key
	visual.helm_key = stats.helm_key
	visual.has_plume = stats.has_plume
	visual.lantern_color = stats.lantern_color
	visual.slot_overrides = slot_ov
	add_child(visual)
	HeroRigDresser.dress(
		visual,
		class_id,
		stats.armor_tier,
		stats.weapon_mesh_key,
		stats.offhand_mesh_key,
		stats.has_plume,
		stats.lantern_color,
		slot_ov
	)


func _setup_weapon_vfx() -> void:
	if _blade_scrape != null and is_instance_valid(_blade_scrape):
		_blade_scrape.queue_free()
		_blade_scrape = null
	if _weapon_ribbon != null and is_instance_valid(_weapon_ribbon):
		_weapon_ribbon.queue_free()
		_weapon_ribbon = null

	if vfx == null:
		return
	var vfx_parent: Node3D = self
	if director != null and director.get("vfx_root") is Node3D:
		vfx_parent = director.get("vfx_root") as Node3D
	elif get_parent() is Node3D:
		vfx_parent = get_parent() as Node3D

	if vfx.has_method("create_blade_scrape"):
		_blade_scrape = vfx.call("create_blade_scrape", vfx_parent) as Node3D
	if vfx.has_method("create_weapon_ribbon"):
		_weapon_ribbon = vfx.call("create_weapon_ribbon", vfx_parent, _weapon_tint()) as Node3D


func _update_vfx_attachments(delta: float) -> void:
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var is_dragging := stats.drags_on_ground and (
		(horiz_speed > 1.2 and _attack_anim_timer <= 0.0)
		or _whirlwind_timer > 0.0
	)
	if _blade_scrape != null and is_instance_valid(_blade_scrape) and _blade_scrape.has_method("update_scrape"):
		var tip_world := visual.get_blade_tip_global() if visual != null else global_position
		_blade_scrape.call("update_scrape", tip_world, 0.0, is_dragging, velocity)

	if is_dragging:
		_scrape_sfx_timer -= delta
		if _scrape_sfx_timer <= 0.0:
			_scrape_sfx_timer = 0.28
			_play_sfx("blade_scrape")
	else:
		_scrape_sfx_timer = 0.0

	if _weapon_ribbon != null and is_instance_valid(_weapon_ribbon) and _weapon_ribbon.has_method("push_sample"):
		var base_world := global_position + Vector3(0.0, 1.05, 0.0)
		var tip_world := base_world + _forward_dir() * 1.2
		if visual != null:
			tip_world = visual.get_blade_tip_global()
			if visual.main_weapon_node != null and is_instance_valid(visual.main_weapon_node):
				base_world = visual.main_weapon_node.global_position
		var emitting := (
			(_attack_anim_timer > 0.0 and not stats.is_ranged)
			or _whirlwind_timer > 0.0
			or _charge_timer > 0.0
			or _skill_slash_ribbon_timer > 0.0
		)
		_weapon_ribbon.call("push_sample", base_world, tip_world, emitting)


func _update_locomotion_animation() -> void:
	if visual == null:
		return
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var blend := clampf(horiz_speed / maxf(stats.move_speed, 0.1), 0.0, 1.0)
	visual.set_move_blend(blend)

	if _whirlwind_timer > 0.0 or _attack_anim_timer > 0.0 or _skill_anim_timer > 0.0:
		return
	if horiz_speed > 0.25:
		visual.play_anim("run", clampf(0.85 + 0.30 * blend, 0.8, 1.35), false)
	else:
		visual.play_anim("idle", 1.0, false)


func _constrain_to_ground_and_bounds() -> void:
	velocity.y = 0.0
	var p := global_position
	p.y = 0.0
	if director != null and director.has_method("clamp_arena_position"):
		p = director.call("clamp_arena_position", p)
		p.y = 0.0
	global_position = p


func _recompute_cooldown_caps() -> void:
	var scale_cd := stats.cooldown_scale if stats != null else 1.0
	dash_cooldown_max = (class_def.dash_ability.cooldown_sec if class_def != null and class_def.dash_ability != null else 3.0) * scale_cd
	skill_1_cooldown_max = (class_def.skill_1.cooldown_sec if class_def != null and class_def.skill_1 != null else 6.5) * scale_cd
	skill_2_cooldown_max = (class_def.skill_2.cooldown_sec if class_def != null and class_def.skill_2 != null else 8.0) * scale_cd
	skill_3_cooldown_max = (class_def.skill_3.cooldown_sec if class_def != null and class_def.skill_3 != null else 8.0) * scale_cd


func _enforce_enemy_soft_separation() -> void:
	for enemy in _get_alive_enemies():
		var min_sep := body_radius + _enemy_radius(enemy) + 0.15
		var delta_xz := Vector3(global_position.x - enemy.global_position.x, 0.0, global_position.z - enemy.global_position.z)
		var d := delta_xz.length()
		if d > 0.001 and d < min_sep:
			var push := (delta_xz / d) * (min_sep - d) * 0.55
			global_position.x += push.x
			global_position.z += push.z


func _emit_cooldowns() -> void:
	cooldowns_changed.emit(
		dash_cooldown_left,
		dash_cooldown_max,
		skill_1_cooldown_left,
		skill_1_cooldown_max,
		skill_2_cooldown_left,
		skill_2_cooldown_max
	)


func _ensure_collider() -> void:
	if get_node_or_null("BodyCollider") != null:
		return
	var col := CollisionShape3D.new()
	col.name = "BodyCollider"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.85
	col.shape = cap
	col.position = Vector3(0.0, 0.925, 0.0)
	add_child(col)


func _get_alive_enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if director != null and director.has_method("get_alive_enemies"):
		var raw_list: Variant = director.call("get_alive_enemies")
		if raw_list is Array:
			for item in raw_list:
				if item is Node3D and is_instance_valid(item):
					out.append(item as Node3D)
		return out
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group("combat_enemies"):
		if n is Node3D and is_instance_valid(n):
			if not n.has_method("is_dead") or not bool(n.call("is_dead")):
				out.append(n as Node3D)
	return out


func _find_nearest_enemy(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_range
	for raw in _get_alive_enemies():
		var e := raw as Node3D
		var d := _dist_xz(global_position, e.global_position) - _enemy_radius(e) * 0.5
		if d <= best_d:
			best_d = d
			best = e
	return best


func _aim_direction_for_skill(search_range: float) -> Vector3:
	var nearest := _find_nearest_enemy(search_range)
	if nearest != null:
		var to_e := Vector3(nearest.global_position.x - global_position.x, 0.0, nearest.global_position.z - global_position.z)
		if to_e.length_squared() > 0.0001:
			return to_e.normalized()
	var mv := _read_move_direction()
	if mv.length_squared() > 0.001:
		return mv.normalized()
	return _forward_dir()


func _find_best_cluster_pos(max_range: float, cluster_radius: float) -> Vector3:
	var enemies := _get_alive_enemies()
	var best_pos := global_position + _forward_dir() * 4.5
	best_pos.y = 0.0
	var best_score := -1
	var best_dist := INF
	for raw_a in enemies:
		var a := raw_a as Node3D
		var d_hero := _dist_xz(global_position, a.global_position)
		if d_hero > max_range:
			continue
		var count := 0
		for raw_b in enemies:
			var b := raw_b as Node3D
			if _dist_xz(a.global_position, b.global_position) <= cluster_radius:
				count += 1
		if count > best_score or (count == best_score and d_hero < best_dist):
			best_score = count
			best_dist = d_hero
			best_pos = Vector3(a.global_position.x, 0.0, a.global_position.z)
	return best_pos


func _collect_chain_targets(start_pos: Vector3, max_hop_range: float, max_count: int) -> Array[Node3D]:
	var enemies := _get_alive_enemies()
	var chosen: Array[Node3D] = []
	var used: Dictionary = {}
	var cur_pos := start_pos
	for _step in range(maxi(1, max_count)):
		var best: Node3D = null
		var best_d := max_hop_range
		for raw_e in enemies:
			var e := raw_e as Node3D
			if used.has(e.get_instance_id()):
				continue
			var d := _dist_xz(cur_pos, e.global_position)
			if d <= best_d:
				best_d = d
				best = e
		if best == null:
			break
		used[best.get_instance_id()] = true
		chosen.append(best)
		cur_pos = best.global_position
	return chosen


func _forward_dir() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _face_direction_instant(dir: Vector3) -> void:
	if dir.length_squared() <= 0.0001:
		return
	rotation.y = atan2(-dir.x, -dir.z)


func _face_direction_smooth(dir: Vector3, turn_rate: float, delta: float) -> void:
	if dir.length_squared() <= 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_rate * delta))


func _weapon_tint() -> Color:
	match class_id:
		"battlemage":
			return Color(0.46, 0.72, 1.0, 1.0)
		"revenant":
			return Color(0.95, 0.22, 0.30, 1.0)
		_:
			return Color(1.0, 0.62, 0.22, 1.0)


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


func _play_sfx(ev: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", ev, db, pitch)


static func _enemy_radius(enemy: Node3D) -> float:
	var r: Variant = enemy.get("body_radius")
	return float(r) if r != null else 0.60


static func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _is_in_cone_xz(
	origin: Vector3,
	forward: Vector3,
	target_pos: Vector3,
	max_dist: float,
	arc_deg: float,
	close_grace_dist: float = 0.85
) -> bool:
	var delta_v := Vector2(target_pos.x - origin.x, target_pos.z - origin.z)
	var dist := delta_v.length()
	if dist > max_dist:
		return false
	if dist <= close_grace_dist or arc_deg >= 359.0:
		return true
	var fwd_2d := Vector2(forward.x, forward.z).normalized()
	var dir_2d := delta_v / maxf(dist, 0.0001)
	var cos_half := cos(deg_to_rad(arc_deg * 0.5))
	return fwd_2d.dot(dir_2d) >= cos_half
