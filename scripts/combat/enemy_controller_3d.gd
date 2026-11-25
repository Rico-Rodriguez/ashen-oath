class_name EnemyController3D
extends CharacterBody3D

enum State {
	IDLE,
	CHASE,
	WINDUP,
	EXECUTE,
	RECOVER,
	STAGGER,
	DEAD,
}

signal health_changed(enemy: EnemyController3D, current_hp: float, max_hp: float)
signal enraged(enemy: EnemyController3D)
signal died(enemy: EnemyController3D)
signal took_damage(enemy: EnemyController3D, event: DamageEvent)

var director: Node = null
var vfx: Node3D = null
var enemy_def: EnemyDef = null
var visual: ActorVisual = null
var difficulty: GameEnums.Difficulty = GameEnums.Difficulty.NORMAL
var is_elite: bool = false
var is_boss_summon: bool = false
var clearing_index: int = -1

var state: State = State.IDLE
var max_hp: float = 60.0
var current_hp: float = 60.0
var move_speed: float = 4.0
var attack_damage: float = 12.0
var gold_reward: int = 5
var body_radius: float = 0.60
var is_enraged: bool = false

var last_signature_tag: String = ""
var signature_exec_counts: Dictionary = {}

var _state_timer: float = 0.0
var _execute_duration: float = 0.24
var _locked_dir: Vector3 = Vector3.FORWARD
var _executed_hit: bool = false
var _windup_cast_anim: bool = false
var _strafe_sign: float = 1.0
var _windup_scale: float = 1.0
var _boss_move_index: int = 0
var _active_boss_move: int = 0
var _boss_chain_remaining: int = 0
var _boss_leap_start: Vector3 = Vector3.ZERO
var _boss_leap_target: Vector3 = Vector3.ZERO
var _boss_stampede_origin: Vector3 = Vector3.ZERO
var _boss_stampede_pyres_spawned: int = 0
var _pending_eruptions: Array[Dictionary] = []
var _active_telegraphs: Array[Node3D] = []

var _burn_dps: float = 0.0
var _burn_timer: float = 0.0
var _burn_tick_accum: float = 0.0
var _bleed_dps: float = 0.0
var _bleed_timer: float = 0.0
var _bleed_tick_accum: float = 0.0

var _death_cleanup_timer: float = 0.75


func _ready() -> void:
	add_to_group("combat_enemies")
	collision_layer = 4
	collision_mask = 1
	_ensure_collider()


func _exit_tree() -> void:
	_cancel_telegraphs_and_pending()


func setup(
	p_director: Node,
	p_vfx: Node3D,
	p_enemy_def: EnemyDef,
	p_difficulty: GameEnums.Difficulty = GameEnums.Difficulty.NORMAL,
	p_is_elite: bool = false,
	p_clearing_index: int = -1,
	rng: RandomNumberGenerator = null
) -> void:
	director = p_director
	vfx = p_vfx
	enemy_def = p_enemy_def if p_enemy_def != null else GameRegistry.get_enemy("hollow_ghoul")
	difficulty = p_difficulty
	is_elite = p_is_elite
	clearing_index = p_clearing_index

	var scales := difficulty_multipliers(difficulty)
	var hp_mult := float(scales["hp"]) * (1.85 if is_elite else 1.0)
	var dmg_mult := float(scales["dmg"]) * (1.25 if is_elite else 1.0)
	var gold_mult := float(scales["gold"]) * (2.5 if is_elite else 1.0)

	max_hp = maxf(1.0, enemy_def.max_hp * hp_mult)
	current_hp = max_hp
	move_speed = enemy_def.move_speed * (1.08 if is_elite else 1.0)
	attack_damage = maxf(1.0, enemy_def.damage * dmg_mult)
	gold_reward = maxi(1, roundi(float(enemy_def.gold_drop) * gold_mult))
	body_radius = 1.25 if enemy_def.is_boss else (0.78 if is_elite else (0.70 if enemy_def.archetype == GameEnums.EnemyArchetype.BRUISER else 0.56))
	_strafe_sign = -1.0 if (rng != null and rng.randf() < 0.5) else 1.0
	_windup_scale = 1.0
	is_enraged = false
	state = State.IDLE
	_state_timer = 0.0
	_boss_move_index = 0
	_active_boss_move = 0
	_boss_chain_remaining = 0
	_boss_stampede_pyres_spawned = 0
	last_signature_tag = ""
	signature_exec_counts.clear()
	_cancel_telegraphs_and_pending()

	_mount_visual()
	_update_collider_radius()


static func difficulty_multipliers(diff: GameEnums.Difficulty) -> Dictionary:
	match diff:
		GameEnums.Difficulty.VETERAN:
			return {"hp": 1.45, "dmg": 1.25, "gold": 1.35, "bonus_rolls": 1}
		GameEnums.Difficulty.NIGHTMARE:
			return {"hp": 2.10, "dmg": 1.55, "gold": 1.75, "bonus_rolls": 2}
		_:
			return {"hp": 1.00, "dmg": 1.00, "gold": 1.00, "bonus_rolls": 0}


func is_dead() -> bool:
	return state == State.DEAD


func kill_silently() -> void:
	if state == State.DEAD:
		return
	current_hp = 0.0
	state = State.DEAD
	velocity = Vector3.ZERO
	_reset_boss_motion_state()
	_cancel_telegraphs_and_pending()
	if visual != null:
		visual.play_anim("death", 1.2, true)
	_death_cleanup_timer = 0.45


func _physics_process(delta: float) -> void:
	if director != null and bool(director.get("is_shrine_open")):
		velocity = Vector3.ZERO
		return

	if state == State.DEAD:
		velocity = Vector3.ZERO
		_death_cleanup_timer -= delta
		if _death_cleanup_timer <= 0.0:
			queue_free()
		return

	_tick_dots(delta)
	if state == State.DEAD:
		return

	_tick_pending_eruptions(delta)

	var hero := _get_hero()
	if hero == null or (hero.has_method("is_dead") and bool(hero.call("is_dead"))):
		velocity = Vector3.ZERO
		if visual != null:
			visual.position.y = 0.0
			visual.set_move_blend(0.0)
			visual.play_anim("idle", 1.0, false)
		return

	match state:
		State.IDLE:
			_process_idle(hero)
		State.CHASE:
			_process_chase(hero, delta)
		State.WINDUP:
			_process_windup(hero, delta)
		State.EXECUTE:
			_process_execute(hero, delta)
		State.RECOVER:
			_process_recover(hero, delta)
		State.STAGGER:
			_process_stagger(delta)

	move_and_slide()
	_constrain_to_ground_and_bounds()
	_update_locomotion_visual()


func _process_idle(hero: Node3D) -> void:
	velocity = Vector3.ZERO
	var aggro_dist := 42.0 if enemy_def.is_boss or clearing_index >= 0 else 24.0
	if _dist_xz(global_position, hero.global_position) <= aggro_dist:
		state = State.CHASE


func _process_chase(hero: Node3D, delta: float) -> void:
	var to_hero := Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)
	var dist := Vector2(to_hero.x, to_hero.z).length()
	var dir_to_hero := to_hero / maxf(dist, 0.0001) if dist > 0.0001 else _forward_dir()
	_face_direction_smooth(dir_to_hero, 12.0, delta)

	match enemy_def.archetype:
		GameEnums.EnemyArchetype.SWARMER:
			if dist <= 1.9:
				_begin_windup(dir_to_hero, 0.38 * _windup_scale)
				_register_telegraph_line(dir_to_hero, 2.2, 0.9, _state_timer)
				_play_sfx("enemy_windup")
				return
			velocity = (dir_to_hero + _separation_push() * 0.45).normalized() * move_speed

		GameEnums.EnemyArchetype.RANGED:
			var perp := Vector3(-dir_to_hero.z, 0.0, dir_to_hero.x) * _strafe_sign
			if dist < 6.5:
				velocity = (-dir_to_hero * 0.65 + perp * 0.55).normalized() * move_speed
			elif dist > 8.5:
				velocity = (dir_to_hero * 0.85 + perp * 0.35).normalized() * move_speed
			else:
				velocity = perp * (move_speed * 0.55)
			if dist <= 9.2:
				_begin_windup(dir_to_hero, 0.55 * _windup_scale)
				_register_telegraph_line(dir_to_hero, 10.5, 0.55, _state_timer)
				_play_sfx("enemy_windup")
				return

		GameEnums.EnemyArchetype.CHARGER:
			if dist <= 9.5:
				_begin_windup(dir_to_hero, 0.68 * _windup_scale)
				_register_telegraph_line(dir_to_hero, 10.5, 1.6, _state_timer)
				_play_sfx("enemy_windup")
				return
			velocity = (dir_to_hero + _separation_push() * 0.35).normalized() * move_speed

		GameEnums.EnemyArchetype.BRUISER:
			if dist <= 3.2:
				_begin_windup(dir_to_hero, 0.75 * _windup_scale)
				_register_telegraph_cone(dir_to_hero, 3.6, 95.0, _state_timer)
				_play_sfx("enemy_windup")
				return
			velocity = (dir_to_hero + _separation_push() * 0.30).normalized() * move_speed

		GameEnums.EnemyArchetype.BOSS:
			_process_boss_chase(hero, dir_to_hero, dist)


func _boss_id() -> String:
	return enemy_def.enemy_id if enemy_def != null else "barrow_troll"


func _record_signature(tag: String) -> void:
	last_signature_tag = tag
	signature_exec_counts[tag] = int(signature_exec_counts.get(tag, 0)) + 1


func _process_boss_chase(hero: Node3D, dir_to_hero: Vector3, dist: float) -> void:
	_active_boss_move = _boss_move_index % 3
	match _boss_id():
		"blight_werewolf":
			_process_werewolf_chase(hero, dir_to_hero, dist)
		"dread_golem":
			_process_golem_chase(hero, dir_to_hero, dist)
		"infernal_minotaur":
			_process_minotaur_chase(hero, dir_to_hero, dist)
		_:
			_process_troll_chase(hero, dir_to_hero, dist)


func _process_troll_chase(hero: Node3D, dir_to_hero: Vector3, dist: float) -> void:
	match _active_boss_move:
		0:
			if dist <= 4.8:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.85 * _windup_scale
				_begin_windup(dir_to_hero, w_dur)
				_register_telegraph_cone(dir_to_hero, 5.2, 115.0, w_dur)
				_play_sfx("boss_windup")
				return
		1:
			if dist <= 12.5:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.90 * _windup_scale
				_begin_windup(dir_to_hero, w_dur, true)
				_play_sfx("boss_windup")
				_schedule_staggered_circles(
					hero,
					w_dur,
					4 if is_enraged else 3,
					0.18,
					2.8,
					attack_damage * 1.10,
					"barrow_troll_tremor",
					DamageEvent.Kind.PHYSICAL,
					Color(0.95, 0.42, 0.14, 0.82),
					false
				)
				return
		2:
			if dist <= 13.0:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.75 * _windup_scale
				_begin_windup(dir_to_hero, w_dur)
				_register_telegraph_line(dir_to_hero, 13.0, 2.6, w_dur)
				_play_sfx("boss_windup")
				return
	velocity = dir_to_hero * move_speed


func _process_werewolf_chase(hero: Node3D, dir_to_hero: Vector3, dist: float) -> void:
	var tox_col := Color(0.45, 0.94, 0.24, 0.82)
	match _active_boss_move:
		0:
			if dist <= 9.5:
				_boss_move_index = (_boss_move_index + 1) % 3
				_boss_chain_remaining = 1
				var w_dur := 0.52 * _windup_scale
				_begin_windup(dir_to_hero, w_dur)
				_register_telegraph_line(dir_to_hero, 9.5, 1.9, w_dur, tox_col)
				_play_sfx("boss_windup")
				return
		1:
			if dist <= 5.6:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.56 * _windup_scale
				_begin_windup(dir_to_hero, w_dur)
				_register_telegraph_cone(dir_to_hero, 4.8, 130.0, w_dur, tox_col)
				_play_sfx("boss_windup")
				return
		2:
			if dist <= 13.5:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.62 * _windup_scale
				_boss_leap_start = global_position
				_boss_leap_target = _clamp_pos(Vector3(hero.global_position.x, 0.0, hero.global_position.z))
				var leap_vec := _boss_leap_target - global_position
				var leap_dir := leap_vec.normalized() if leap_vec.length_squared() > 0.0001 else dir_to_hero
				_begin_windup(leap_dir, w_dur, true)
				_register_telegraph_circle(_boss_leap_target, 3.4, w_dur + 0.26, tox_col)
				_play_sfx("howl")
				return
	velocity = dir_to_hero * move_speed


func _process_golem_chase(_hero: Node3D, dir_to_hero: Vector3, dist: float) -> void:
	var arcane_col := Color(0.36, 0.60, 1.0, 0.82)
	match _active_boss_move:
		0:
			if dist <= 8.5:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.80 * _windup_scale
				_begin_windup(dir_to_hero, w_dur, true)
				_register_telegraph_circle(global_position, 3.6, w_dur, arcane_col)
				_play_sfx("boss_windup")
				return
		1:
			if dist <= 13.0:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.75 * _windup_scale
				_begin_windup(dir_to_hero, w_dur, true)
				_register_telegraph_circle(global_position, 3.2, w_dur, Color(0.46, 0.52, 1.0, 0.82))
				_play_sfx("boss_windup")
				return
		2:
			if dist <= 5.2:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.85 * _windup_scale
				_begin_windup(dir_to_hero, w_dur)
				_register_telegraph_cone(dir_to_hero, 5.4, 105.0, w_dur, arcane_col)
				_play_sfx("boss_windup")
				return
	velocity = dir_to_hero * move_speed


func _process_minotaur_chase(hero: Node3D, dir_to_hero: Vector3, dist: float) -> void:
	var hell_col := Color(1.0, 0.28, 0.08, 0.86)
	match _active_boss_move:
		0:
			if dist <= 14.0:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.70 * _windup_scale
				_begin_windup(dir_to_hero, w_dur)
				_register_telegraph_line(dir_to_hero, 14.0, 2.8, w_dur, hell_col)
				_play_sfx("boss_windup")
				return
		1:
			if dist <= 5.5:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.76 * _windup_scale
				_begin_windup(dir_to_hero, w_dur)
				_register_telegraph_cone(dir_to_hero, 5.6, 150.0, w_dur, hell_col)
				_play_sfx("boss_windup")
				return
		2:
			if dist <= 14.0:
				_boss_move_index = (_boss_move_index + 1) % 3
				var w_dur := 0.84 * _windup_scale
				_begin_windup(dir_to_hero, w_dur, true)
				_play_sfx("meteor")
				_play_sfx("boss_windup")
				_schedule_staggered_circles(
					hero,
					w_dur,
					6 if is_enraged else 5,
					0.14,
					3.0,
					attack_damage * 1.15,
					"infernal_minotaur_meteor",
					DamageEvent.Kind.FIRE,
					hell_col,
					true
				)
				return
	velocity = dir_to_hero * move_speed


func _schedule_staggered_circles(
	hero: Node3D,
	base_delay: float,
	count: int,
	step_delay: float,
	radius: float,
	dmg: float,
	src_id: String,
	kind: DamageEvent.Kind,
	color: Color,
	spawn_pyre: bool
) -> void:
	var center := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	var hero_vel := Vector3.ZERO
	if hero is CharacterBody3D:
		var hv := (hero as CharacterBody3D).velocity
		hero_vel = Vector3(hv.x, 0.0, hv.z)
	var lead_dir := hero_vel.normalized() if hero_vel.length_squared() > 0.25 else _locked_dir
	var side_dir := Vector3(-lead_dir.z, 0.0, lead_dir.x)

	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		lead_dir * 3.2 + side_dir * 1.5,
		-lead_dir * 2.0 - side_dir * 3.0,
		lead_dir * 1.8 - side_dir * 3.4,
		-lead_dir * 3.4 + side_dir * 2.4,
		lead_dir * 4.6,
	]
	for idx in range(maxi(1, count)):
		var off := offsets[idx % offsets.size()]
		var p := center if idx == 0 else _clamp_pos(center + off)
		var d := base_delay + float(idx) * step_delay
		_register_telegraph_circle(p, radius, d, color)
		_pending_eruptions.append({
			"shape": "circle",
			"pos": p,
			"radius": radius,
			"timer": d,
			"damage": dmg,
			"source_id": src_id,
			"kind": kind,
			"color": color,
			"pyre": spawn_pyre,
		})


func _begin_windup(dir: Vector3, duration: float, play_cast_anim: bool = false) -> void:
	state = State.WINDUP
	_locked_dir = dir.normalized() if dir.length_squared() > 0.0001 else _forward_dir()
	_face_direction_instant(_locked_dir)
	_state_timer = maxf(0.05, duration)
	_executed_hit = false
	_windup_cast_anim = play_cast_anim
	velocity = Vector3.ZERO
	if play_cast_anim and visual != null:
		visual.play_anim("skill_cast", 1.1, true)


func _process_windup(_hero: Node3D, delta: float) -> void:
	velocity = Vector3.ZERO
	_face_direction_instant(_locked_dir)
	_state_timer -= delta
	if _state_timer > 0.0:
		return

	state = State.EXECUTE
	_executed_hit = false
	_windup_cast_anim = false

	match enemy_def.archetype:
		GameEnums.EnemyArchetype.SWARMER:
			_state_timer = 0.16
			if visual != null:
				visual.play_anim("attack", 1.35, true)
			_play_sfx("atk_enemy")
		GameEnums.EnemyArchetype.RANGED:
			_state_timer = 0.16
			if visual != null:
				visual.play_anim("attack", 1.25, true)
			_play_sfx("atk_enemy")
			_fire_enemy_projectile(_locked_dir, 11.5, attack_damage, "blood_orb", DamageEvent.Kind.SHADOW)
			_executed_hit = true
		GameEnums.EnemyArchetype.CHARGER:
			_state_timer = 10.5 / 14.5
			if visual != null:
				visual.play_anim("dash", 1.4, true)
			_play_sfx("charge")
		GameEnums.EnemyArchetype.BRUISER:
			_state_timer = 0.20
			if visual != null:
				visual.play_anim("attack2", 1.2, true)
			_play_sfx("impact")
		GameEnums.EnemyArchetype.BOSS:
			_enter_boss_execute()


func _enter_boss_execute() -> void:
	match _boss_id():
		"blight_werewolf":
			match _active_boss_move:
				0:
					_execute_duration = 9.5 / 21.0
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("dash", 1.65, true)
					_play_sfx("wolf_bite")
					_record_signature("werewolf_double_pounce")
				1:
					_execute_duration = 0.24
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("attack2", 1.35, true)
					_play_sfx("cleave")
					_record_signature("werewolf_claw_blight_fan")
				2:
					_execute_duration = 0.26
					_state_timer = _execute_duration
					_boss_leap_start = global_position
					if visual != null:
						visual.play_anim("dash", 1.45, true)
					_play_sfx("charge")
					_record_signature("werewolf_shadow_leap")

		"dread_golem":
			match _active_boss_move:
				0:
					_execute_duration = 0.32
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("attack", 1.05, true)
					_record_signature("golem_concentric_ring")
				1:
					_execute_duration = 0.36
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("skill_cast", 1.15, true)
					_record_signature("golem_crystalline_nova")
				2:
					_execute_duration = 0.28
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("attack2", 1.05, true)
					_record_signature("golem_monolith_slam")

		"infernal_minotaur":
			match _active_boss_move:
				0:
					_execute_duration = 14.0 / 18.5
					_state_timer = _execute_duration
					_boss_stampede_origin = global_position
					_boss_stampede_pyres_spawned = 0
					if visual != null:
						visual.play_anim("dash", 1.55, true)
					_play_sfx("charge")
					_record_signature("minotaur_hellfire_stampede")
				1:
					_execute_duration = 0.28
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("attack2", 1.18, true)
					_record_signature("minotaur_executioner_cleave")
				2:
					_execute_duration = 0.42
					_state_timer = _execute_duration
					_record_signature("minotaur_meteor_barrage")

		_:
			match _active_boss_move:
				0:
					_execute_duration = 0.24
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("attack", 1.15, true)
					_record_signature("troll_seismic_slam")
				1:
					_execute_duration = 0.40
					_state_timer = _execute_duration
					_record_signature("troll_boulder_tremors")
				2:
					_execute_duration = 13.0 / 16.0
					_state_timer = _execute_duration
					if visual != null:
						visual.play_anim("dash", 1.5, true)
					_play_sfx("charge")
					_record_signature("troll_bull_charge")


func _process_execute(hero: Node3D, delta: float) -> void:
	var h_rad := _hero_radius(hero)

	match enemy_def.archetype:
		GameEnums.EnemyArchetype.SWARMER:
			velocity = _locked_dir * (1.4 / 0.16)
			if not _executed_hit:
				if _is_in_cone_xz(global_position, _locked_dir, hero.global_position, 1.55 + h_rad, 115.0, 0.95 + h_rad):
					_executed_hit = true
					_deal_damage_to_hero(hero, attack_damage, enemy_def.enemy_id)

		GameEnums.EnemyArchetype.RANGED:
			velocity = Vector3.ZERO

		GameEnums.EnemyArchetype.CHARGER:
			velocity = _locked_dir * 14.5
			if not _executed_hit:
				if _dist_xz(global_position, hero.global_position) <= 0.85 + h_rad:
					_executed_hit = true
					_deal_damage_to_hero(hero, attack_damage, enemy_def.enemy_id)

		GameEnums.EnemyArchetype.BRUISER:
			velocity = Vector3.ZERO
			if not _executed_hit:
				_executed_hit = true
				if vfx != null and vfx.has_method("spawn_slash_arc"):
					vfx.call("spawn_slash_arc", global_position + Vector3(0.0, 1.0, 0.0), _locked_dir, 3.6, 95.0, Color(0.95, 0.35, 0.18, 0.95))
				if _is_in_cone_xz(global_position, _locked_dir, hero.global_position, 3.6 + h_rad, 95.0, 0.95 + h_rad):
					_deal_damage_to_hero(hero, attack_damage, enemy_def.enemy_id)

		GameEnums.EnemyArchetype.BOSS:
			_process_boss_execute(hero, h_rad, delta)

	_state_timer -= delta
	if _state_timer <= 0.0:
		velocity = Vector3.ZERO
		if enemy_def.archetype == GameEnums.EnemyArchetype.BOSS:
			if _finish_boss_execute(hero, h_rad):
				return
		state = State.RECOVER
		_state_timer = _recovery_duration()


func _process_boss_execute(hero: Node3D, h_rad: float, _delta: float) -> void:
	match _boss_id():
		"blight_werewolf":
			match _active_boss_move:
				0:
					velocity = _locked_dir * 21.0
					if not _executed_hit and _dist_xz(global_position, hero.global_position) <= 1.22 + h_rad:
						_executed_hit = true
						_deal_damage_to_hero(hero, attack_damage * 0.95, "blight_werewolf_pounce", DamageEvent.Kind.BLEED)
				1:
					velocity = Vector3.ZERO
					if not _executed_hit:
						_executed_hit = true
						var rend_col := Color(0.46, 0.96, 0.28, 0.95)
						if vfx != null and vfx.has_method("spawn_slash_arc"):
							vfx.call("spawn_slash_arc", global_position, _locked_dir, 4.8, 130.0, rend_col)
						if _is_in_cone_xz(global_position, _locked_dir, hero.global_position, 4.8 + h_rad, 130.0, 1.30 + h_rad):
							_deal_damage_to_hero(hero, attack_damage * 1.05, "blight_werewolf_rend", DamageEvent.Kind.SHADOW)
						_fire_boss_fan_from_dir(_locked_dir, [-36.0, -18.0, 0.0, 18.0, 36.0], 13.5, attack_damage * 0.72, "blood_orb", DamageEvent.Kind.SHADOW)
				2:
					var dur := maxf(_execute_duration, 0.05)
					var t01 := clampf(1.0 - (_state_timer / dur), 0.0, 1.0)
					var target_xz := _boss_leap_start.lerp(_boss_leap_target, t01)
					velocity = Vector3.ZERO
					global_position = Vector3(target_xz.x, 0.0, target_xz.z)
					if visual != null:
						visual.position.y = sin(t01 * PI) * 2.8

		"dread_golem":
			velocity = Vector3.ZERO
			match _active_boss_move:
				0:
					if not _executed_hit:
						_executed_hit = true
						_play_sfx("boss_slam")
						_add_trauma(0.50)
						var arc_col := Color(0.36, 0.62, 1.0, 1.0)
						if vfx != null and vfx.has_method("spawn_shockwave_ring"):
							vfx.call("spawn_shockwave_ring", global_position, 3.6, arc_col)
						if _dist_xz(global_position, hero.global_position) <= 3.6 + h_rad:
							_deal_damage_to_hero(hero, attack_damage * 1.15, "dread_golem_inner_ring", DamageEvent.Kind.LIGHTNING)
						_schedule_concentric_outer_ring(global_position, 4.5, 8.0, 0.45, attack_damage * 1.15)
				1:
					if not _executed_hit:
						_executed_hit = true
						var base_yaw := atan2(-_locked_dir.x, -_locked_dir.z)
						_fire_radial_nova(base_yaw, 8, 12.5, attack_damage * 0.88, "voidpyre_bolt", DamageEvent.Kind.SHADOW)
						if vfx != null and vfx.has_method("spawn_shockwave_ring"):
							vfx.call("spawn_shockwave_ring", global_position, 2.8, Color(0.48, 0.40, 1.0, 1.0))
						if is_enraged:
							_register_telegraph_circle(global_position, 2.8, 0.32, Color(0.54, 0.42, 1.0, 0.78))
							_pending_eruptions.append({
								"shape": "nova",
								"timer": 0.32,
								"base_yaw": base_yaw + deg_to_rad(22.5),
								"count": 8,
								"speed": 12.5,
								"damage": attack_damage * 0.85,
								"style": "voidpyre_bolt",
								"kind": DamageEvent.Kind.SHADOW,
							})
				2:
					if not _executed_hit:
						_executed_hit = true
						_play_sfx("boss_slam")
						_add_trauma(0.52)
						if vfx != null:
							if vfx.has_method("spawn_shockwave_ring"):
								vfx.call("spawn_shockwave_ring", global_position + _locked_dir * 2.4, 3.8, Color(0.38, 0.62, 1.0, 1.0))
							if vfx.has_method("spawn_slash_arc"):
								vfx.call("spawn_slash_arc", global_position, _locked_dir, 5.4, 105.0, Color(0.42, 0.66, 1.0, 0.95))
						if _is_in_cone_xz(global_position, _locked_dir, hero.global_position, 5.4 + h_rad, 105.0, 1.35 + h_rad):
							_deal_damage_to_hero(hero, attack_damage * 1.25, "dread_golem_monolith_slam", DamageEvent.Kind.PHYSICAL)

		"infernal_minotaur":
			match _active_boss_move:
				0:
					velocity = _locked_dir * 18.5
					if not _executed_hit and _dist_xz(global_position, hero.global_position) <= 1.38 + h_rad:
						_executed_hit = true
						_deal_damage_to_hero(hero, attack_damage * 1.22, "infernal_minotaur_stampede", DamageEvent.Kind.FIRE)
					var dur := maxf(_execute_duration, 0.05)
					var p01 := clampf(1.0 - (_state_timer / dur), 0.0, 1.0)
					var thresholds: Array[float] = [0.22, 0.52, 0.82]
					while _boss_stampede_pyres_spawned < 3 and p01 >= thresholds[_boss_stampede_pyres_spawned]:
						_spawn_stampede_wake_pyre(_boss_stampede_pyres_spawned)
						_boss_stampede_pyres_spawned += 1
				1:
					velocity = Vector3.ZERO
					if not _executed_hit:
						_executed_hit = true
						_play_sfx("cleave")
						_play_sfx("boss_slam")
						_add_trauma(0.58)
						if vfx != null:
							if vfx.has_method("spawn_slash_arc"):
								vfx.call("spawn_slash_arc", global_position, _locked_dir, 5.6, 150.0, Color(1.0, 0.36, 0.10, 0.98))
							if vfx.has_method("spawn_shockwave_ring"):
								vfx.call("spawn_shockwave_ring", global_position + _locked_dir * 2.4, 4.2, Color(1.0, 0.30, 0.08, 1.0))
						if _is_in_cone_xz(global_position, _locked_dir, hero.global_position, 5.6 + h_rad, 150.0, 1.45 + h_rad):
							_deal_damage_to_hero(hero, attack_damage * 1.28, "infernal_minotaur_cleave", DamageEvent.Kind.FIRE)
						if is_enraged:
							_fire_boss_fan_from_dir(_locked_dir, [-50.0, -25.0, 0.0, 25.0, 50.0], 13.5, attack_damage * 0.78, "boss_ember", DamageEvent.Kind.FIRE)
				2:
					velocity = Vector3.ZERO

		_:
			match _active_boss_move:
				0:
					velocity = Vector3.ZERO
					if not _executed_hit:
						_executed_hit = true
						_play_sfx("boss_slam")
						_add_trauma(0.45)
						if vfx != null:
							if vfx.has_method("spawn_shockwave_ring"):
								vfx.call("spawn_shockwave_ring", global_position + _locked_dir * 2.0, 3.8, Color(0.95, 0.34, 0.12, 1.0))
							if vfx.has_method("spawn_slash_arc"):
								vfx.call("spawn_slash_arc", global_position, _locked_dir, 5.2, 115.0, Color(0.96, 0.42, 0.16, 0.95))
						if _is_in_cone_xz(global_position, _locked_dir, hero.global_position, 5.2 + h_rad, 115.0, 1.35 + h_rad):
							_deal_damage_to_hero(hero, attack_damage * 1.15, enemy_def.enemy_id + "_slam")
				1:
					velocity = Vector3.ZERO
				2:
					velocity = _locked_dir * 16.0
					if not _executed_hit and _dist_xz(global_position, hero.global_position) <= 1.30 + h_rad:
						_executed_hit = true
						_deal_damage_to_hero(hero, attack_damage * 1.20, enemy_def.enemy_id + "_charge")


func _finish_boss_execute(hero: Node3D, h_rad: float) -> bool:
	var bid := _boss_id()
	if bid == "blight_werewolf":
		if _active_boss_move == 0 and _boss_chain_remaining > 0:
			_boss_chain_remaining -= 1
			var to_h := Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)
			var next_dir := to_h.normalized() if to_h.length_squared() > 0.0001 else _locked_dir
			var w_dur := 0.52 * _windup_scale
			_begin_windup(next_dir, w_dur)
			_register_telegraph_line(next_dir, 9.5, 1.9, w_dur, Color(0.45, 0.94, 0.24, 0.82))
			_play_sfx("boss_windup")
			return true
		if _active_boss_move == 2:
			global_position = Vector3(_boss_leap_target.x, 0.0, _boss_leap_target.z)
			if visual != null:
				visual.position.y = 0.0
			_play_sfx("boss_slam")
			_add_trauma(0.42)
			if vfx != null and vfx.has_method("spawn_shockwave_ring"):
				vfx.call("spawn_shockwave_ring", _boss_leap_target, 3.4, Color(0.45, 0.96, 0.28, 1.0))
			if _dist_xz(_boss_leap_target, hero.global_position) <= 3.4 + h_rad:
				_deal_damage_to_hero(hero, attack_damage * 1.18, "blight_werewolf_leap_slam", DamageEvent.Kind.SHADOW)

	elif bid == "infernal_minotaur":
		if _active_boss_move == 0:
			while _boss_stampede_pyres_spawned < 3:
				_spawn_stampede_wake_pyre(_boss_stampede_pyres_spawned)
				_boss_stampede_pyres_spawned += 1

	elif bid == "barrow_troll":
		if _active_boss_move == 2 and is_enraged:
			_fire_boss_ember_fan(hero)

	return false


func _schedule_concentric_outer_ring(center: Vector3, inner_r: float, outer_r: float, delay: float, dmg: float) -> void:
	var ring_col := Color(0.36, 0.58, 1.0, 0.72)
	_register_telegraph_circle(center, outer_r, delay, Color(0.30, 0.50, 0.98, 0.42))
	var mid_r := (inner_r + outer_r) * 0.5
	var sub_r := (outer_r - inner_r) * 0.5
	for i in range(8):
		var ang := (TAU * float(i)) / 8.0
		var sub_p := center + Vector3(cos(ang) * mid_r, 0.0, sin(ang) * mid_r)
		_register_telegraph_circle(sub_p, sub_r, delay, ring_col)

	_pending_eruptions.append({
		"shape": "ring",
		"pos": center,
		"inner_radius": inner_r,
		"radius": outer_r,
		"timer": delay,
		"damage": dmg,
		"source_id": "dread_golem_outer_ring",
		"kind": DamageEvent.Kind.LIGHTNING,
		"color": Color(0.36, 0.62, 1.0, 1.0),
	})


func _spawn_stampede_wake_pyre(idx: int) -> void:
	var dist_along := 3.2 + float(idx) * 4.2
	var wake_pos := _clamp_pos(_boss_stampede_origin + _locked_dir * dist_along)
	var delay := 0.36 + float(idx) * 0.06
	var col := Color(1.0, 0.30, 0.08, 0.84)
	_register_telegraph_circle(wake_pos, 2.5, delay, col)
	_pending_eruptions.append({
		"shape": "circle",
		"pos": wake_pos,
		"radius": 2.5,
		"timer": delay,
		"damage": attack_damage * 0.95,
		"source_id": "infernal_minotaur_wake_pyre",
		"kind": DamageEvent.Kind.FIRE,
		"color": col,
		"pyre": true,
	})


func _fire_boss_ember_fan(hero: Node3D) -> void:
	var to_h := Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)
	var center_dir := to_h.normalized() if to_h.length_squared() > 0.0001 else _locked_dir
	_fire_boss_fan_from_dir(center_dir, [-32.0, -16.0, 0.0, 16.0, 32.0], 12.5, attack_damage * 0.80, "boss_ember", DamageEvent.Kind.FIRE)


func _fire_boss_fan_from_dir(
	center_dir: Vector3,
	angles_deg: Array,
	spd: float,
	dmg: float,
	style: String,
	kind: DamageEvent.Kind
) -> void:
	var base_yaw := atan2(-center_dir.x, -center_dir.z)
	_play_sfx("volley")
	for deg in angles_deg:
		var yaw := base_yaw + deg_to_rad(float(deg))
		var dir := Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
		_fire_enemy_projectile(dir, spd, dmg, style, kind)


func _fire_radial_nova(
	base_yaw: float,
	count: int,
	spd: float,
	dmg: float,
	style: String,
	kind: DamageEvent.Kind
) -> void:
	_play_sfx("volley")
	var n := maxi(1, count)
	for i in range(n):
		var yaw := base_yaw + (TAU * float(i)) / float(n)
		var dir := Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
		_fire_enemy_projectile(dir, spd, dmg, style, kind)


func _tick_pending_eruptions(delta: float) -> void:
	if _pending_eruptions.is_empty():
		return
	var hero := _get_hero()
	var i := _pending_eruptions.size() - 1
	while i >= 0:
		var er: Dictionary = _pending_eruptions[i]
		var rem := float(er["timer"]) - delta
		if rem <= 0.0:
			var shape := str(er.get("shape", "circle"))
			if shape == "nova":
				_fire_radial_nova(
					float(er.get("base_yaw", 0.0)),
					int(er.get("count", 8)),
					float(er.get("speed", 12.5)),
					float(er.get("damage", attack_damage * 0.85)),
					str(er.get("style", "voidpyre_bolt")),
					er.get("kind", DamageEvent.Kind.SHADOW) as DamageEvent.Kind
				)
			elif shape == "ring":
				var rp: Vector3 = er["pos"]
				var in_r := float(er["inner_radius"])
				var out_r := float(er["radius"])
				var rdmg := float(er["damage"])
				var rcol: Color = er.get("color", Color(0.36, 0.62, 1.0, 1.0))
				if vfx != null and vfx.has_method("spawn_shockwave_ring"):
					vfx.call("spawn_shockwave_ring", rp, out_r, rcol)
					vfx.call("spawn_shockwave_ring", rp, in_r, rcol)
				_play_sfx("boom")
				if hero != null and is_instance_valid(hero):
					var hd := _dist_xz(rp, hero.global_position)
					var h_rad := _hero_radius(hero)
					if hd >= in_r - h_rad and hd <= out_r + h_rad:
						_deal_damage_to_hero(
							hero,
							rdmg,
							str(er.get("source_id", "dread_golem_outer_ring")),
							er.get("kind", DamageEvent.Kind.LIGHTNING) as DamageEvent.Kind
						)
			else:
				var p: Vector3 = er["pos"]
				var rad := float(er["radius"])
				var dmg := float(er["damage"])
				var col: Color = er.get("color", Color(0.95, 0.22, 0.12, 1.0))
				if vfx != null:
					if bool(er.get("pyre", true)) and vfx.has_method("spawn_blackflame_pyre"):
						vfx.call("spawn_blackflame_pyre", p, rad)
					if vfx.has_method("spawn_shockwave_ring"):
						vfx.call("spawn_shockwave_ring", p, rad, col)
				_play_sfx("boom")
				if hero != null and is_instance_valid(hero):
					if _dist_xz(p, hero.global_position) <= rad + _hero_radius(hero):
						_deal_damage_to_hero(
							hero,
							dmg,
							str(er.get("source_id", enemy_def.enemy_id + "_eruption")),
							er.get("kind", DamageEvent.Kind.FIRE) as DamageEvent.Kind
						)
			_pending_eruptions.remove_at(i)
		else:
			er["timer"] = rem
			_pending_eruptions[i] = er
		i -= 1


func _process_recover(hero: Node3D, delta: float) -> void:
	velocity = Vector3.ZERO
	var to_h := Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)
	if to_h.length_squared() > 0.0001:
		_face_direction_smooth(to_h.normalized(), 6.0, delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_strafe_sign = -_strafe_sign
		state = State.CHASE


func _process_stagger(delta: float) -> void:
	velocity = Vector3.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.CHASE


func _recovery_duration() -> float:
	match enemy_def.archetype:
		GameEnums.EnemyArchetype.SWARMER:
			return 0.45
		GameEnums.EnemyArchetype.RANGED:
			return 0.65
		GameEnums.EnemyArchetype.CHARGER:
			return 0.85
		GameEnums.EnemyArchetype.BRUISER:
			return 0.70
		GameEnums.EnemyArchetype.BOSS:
			match _boss_id():
				"blight_werewolf":
					return 0.58 * _windup_scale
				"dread_golem":
					return 0.88 * _windup_scale
				"infernal_minotaur":
					return 0.72 * _windup_scale
				_:
					return (0.85 if _active_boss_move != 0 else 0.80) * _windup_scale
	return enemy_def.recovery_sec


func receive_damage(ev: DamageEvent) -> DamageEvent:
	if state == State.DEAD or ev == null:
		return ev

	var dmg := maxf(0.0, ev.raw_damage)
	ev.final_damage = dmg
	current_hp = maxf(0.0, current_hp - dmg)

	if ev.burn_dps > 0.0 and ev.burn_duration > 0.0:
		_burn_dps = maxf(_burn_dps, ev.burn_dps)
		_burn_timer = maxf(_burn_timer, ev.burn_duration)
	if ev.bleed_dps > 0.0 and ev.bleed_duration > 0.0:
		_bleed_dps = maxf(_bleed_dps, ev.bleed_dps)
		_bleed_timer = maxf(_bleed_timer, ev.bleed_duration)

	if visual != null:
		visual.trigger_hit_flash(0.10)

	if enemy_def.is_boss and not ev.is_dot:
		_play_sfx("boss_hit")

	health_changed.emit(self, current_hp, max_hp)
	took_damage.emit(self, ev)

	if current_hp <= 0.0:
		_enter_dead_state()
		return ev

	if enemy_def.is_boss and not is_enraged and current_hp <= max_hp * 0.55:
		_trigger_boss_enrage()

	if ev.stagger_sec > 0.0:
		var applied_stagger := ev.stagger_sec * (0.45 if enemy_def.is_boss else 1.0)
		if not enemy_def.is_boss or state != State.EXECUTE:
			_reset_boss_motion_state()
			_cancel_telegraphs_and_pending()
			var prev_stagger := _state_timer if state == State.STAGGER else 0.0
			state = State.STAGGER
			_state_timer = maxf(prev_stagger, applied_stagger)
			velocity = Vector3.ZERO
			if visual != null:
				visual.play_anim("hit", 1.0, true)

	if state == State.IDLE:
		state = State.CHASE

	return ev


func _trigger_boss_enrage() -> void:
	is_enraged = true
	_windup_scale = 0.82
	move_speed *= 1.15
	if visual != null:
		visual.play_anim("skill_cast", 1.15, true)
	_play_sfx("boss_roar")
	var ad := _audio()
	if ad != null and ad.has_method("duck"):
		ad.call("duck", -7.0, 0.7, 0.9)
	_add_trauma(0.55)
	_summon_boss_enrage_pack()
	enraged.emit(self)
	health_changed.emit(self, current_hp, max_hp)


func _summon_boss_enrage_pack() -> void:
	if director == null:
		return
	var bid := _boss_id()
	if bid == "barrow_troll" or not director.has_method("spawn_enemy_at"):
		if director.has_method("spawn_boss_adds"):
			director.call("spawn_boss_adds", global_position, 3)
		return

	var pack_ids: Array[String] = ["hollow_ghoul", "hollow_ghoul", "hollow_ghoul"]
	match bid:
		"blight_werewolf":
			pack_ids = ["crypt_batlord", "hollow_ghoul", "crypt_batlord", "hollow_ghoul"]
		"dread_golem":
			pack_ids = ["stone_gargoyle", "crypt_batlord", "crypt_batlord"]
		"infernal_minotaur":
			pack_ids = ["ash_scorpion", "hollow_ghoul", "ash_scorpion"]

	for i in range(pack_ids.size()):
		var ang := (TAU / float(pack_ids.size())) * float(i) + 0.45
		var spawn_p := global_position + Vector3(cos(ang) * 4.0, 0.0, sin(ang) * 4.0)
		var add := director.call("spawn_enemy_at", pack_ids[i], spawn_p, false, -1, true) as EnemyController3D
		if add != null:
			add.state = State.CHASE


func _tick_dots(delta: float) -> void:
	if _burn_timer > 0.0:
		_burn_timer = maxf(0.0, _burn_timer - delta)
		_burn_tick_accum += delta
		while _burn_tick_accum >= 0.5 and state != State.DEAD:
			_burn_tick_accum -= 0.5
			var bev := DamageEvent.make_hero_hit(null, _burn_dps * 0.5, "spark_burn", DamageEvent.Kind.FIRE, false)
			bev.is_dot = true
			bev.triggers_on_hit = false
			bev.hit_position = global_position + Vector3(0.0, 1.1, 0.0)
			receive_damage(bev)
		if _burn_timer <= 0.0:
			_burn_dps = 0.0
			_burn_tick_accum = 0.0

	if _bleed_timer > 0.0 and state != State.DEAD:
		_bleed_timer = maxf(0.0, _bleed_timer - delta)
		_bleed_tick_accum += delta
		while _bleed_tick_accum >= 0.5 and state != State.DEAD:
			_bleed_tick_accum -= 0.5
			var blev := DamageEvent.make_hero_hit(null, _bleed_dps * 0.5, "bleed", DamageEvent.Kind.BLEED, false)
			blev.is_dot = true
			blev.triggers_on_hit = false
			blev.hit_position = global_position + Vector3(0.0, 1.1, 0.0)
			receive_damage(blev)
		if _bleed_timer <= 0.0:
			_bleed_dps = 0.0
			_bleed_tick_accum = 0.0


func _enter_dead_state() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_reset_boss_motion_state()
	_cancel_telegraphs_and_pending()
	collision_layer = 0
	collision_mask = 0
	if visual != null:
		visual.play_anim("death", 1.1, true)
	_play_sfx("boss_die" if enemy_def.is_boss else "enemy_die")
	_death_cleanup_timer = 1.15 if enemy_def.is_boss else 0.65
	died.emit(self)


func _reset_boss_motion_state() -> void:
	_boss_chain_remaining = 0
	_windup_cast_anim = false
	if visual != null:
		visual.position.y = 0.0


func _add_trauma(amount: float) -> void:
	if director != null and director.has_method("add_camera_trauma"):
		director.call("add_camera_trauma", amount)


func _deal_damage_to_hero(
	hero: Node3D,
	dmg: float,
	src_id: String,
	kind: DamageEvent.Kind = DamageEvent.Kind.PHYSICAL
) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if hero.has_method("receive_damage"):
		var ev := DamageEvent.make_enemy_hit(self, dmg, src_id, kind)
		ev.hit_position = hero.global_position + Vector3(0.0, 1.0, 0.0)
		hero.call("receive_damage", ev)


func _fire_enemy_projectile(
	dir: Vector3,
	spd: float,
	dmg: float,
	style: String,
	kind: DamageEvent.Kind
) -> void:
	var proj := CombatProjectile.new()
	var container: Node = get_parent()
	if director != null and director.get("projectiles_root") is Node3D:
		container = director.get("projectiles_root") as Node3D
	if container != null:
		container.add_child(proj)
	var origin := global_position + dir * 0.65 + Vector3(0.0, 1.05, 0.0)
	proj.setup(director, vfx, self, DamageEvent.Team.ENEMY, origin, dir, spd, dmg, enemy_def.enemy_id, style, 0, 0, kind)


func _register_telegraph_circle(pos: Vector3, radius_m: float, duration: float, color: Color = Color(0.92, 0.16, 0.12, 0.78)) -> void:
	if vfx == null or not vfx.has_method("spawn_telegraph_circle"):
		return
	var node := vfx.call("spawn_telegraph_circle", pos, radius_m, duration, color) as Node3D
	if node != null:
		_active_telegraphs.append(node)


func _register_telegraph_line(
	forward: Vector3,
	length_m: float,
	width_m: float,
	duration: float,
	color: Color = Color(0.92, 0.16, 0.12, 0.78)
) -> void:
	if vfx == null or not vfx.has_method("spawn_telegraph_line"):
		return
	var node := vfx.call("spawn_telegraph_line", global_position, forward, length_m, width_m, duration, color) as Node3D
	if node != null:
		_active_telegraphs.append(node)


func _register_telegraph_cone(
	forward: Vector3,
	range_m: float,
	angle_deg: float,
	duration: float,
	color: Color = Color(0.92, 0.16, 0.12, 0.78)
) -> void:
	if vfx == null or not vfx.has_method("spawn_telegraph_cone"):
		return
	var node := vfx.call("spawn_telegraph_cone", global_position, forward, range_m, angle_deg, duration, color) as Node3D
	if node != null:
		_active_telegraphs.append(node)


func _cancel_telegraphs_and_pending() -> void:
	_pending_eruptions.clear()
	for t in _active_telegraphs:
		if t != null and is_instance_valid(t):
			t.queue_free()
	_active_telegraphs.clear()


func _mount_visual() -> void:
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
		visual = null
	var ps := load(enemy_def.actor_scene_path) as PackedScene
	if ps == null:
		return
	visual = ps.instantiate() as ActorVisual
	add_child(visual)
	var scale_factor := 1.0
	if enemy_def.is_boss and visual.height_meters < 3.0:
		scale_factor = 1.55
	elif is_elite:
		scale_factor = 1.24
	visual.scale = Vector3.ONE * scale_factor


func _update_locomotion_visual() -> void:
	if visual == null or state == State.DEAD:
		return
	var h_spd := Vector2(velocity.x, velocity.z).length()
	visual.set_move_blend(clampf(h_spd / maxf(move_speed, 0.1), 0.0, 1.0))
	if state in [State.EXECUTE, State.STAGGER] or (state == State.WINDUP and _windup_cast_anim):
		return
	if h_spd > 0.25:
		visual.play_anim("run", 1.0, false)
	else:
		visual.play_anim("idle", 1.0, false)


func _separation_push() -> Vector3:
	if director == null or not director.has_method("get_alive_enemies"):
		return Vector3.ZERO
	var push := Vector3.ZERO
	var desired := body_radius * 2.1
	for raw in director.call("get_alive_enemies"):
		var other := raw as Node3D
		if other == null or other == self or not is_instance_valid(other):
			continue
		var diff := Vector3(global_position.x - other.global_position.x, 0.0, global_position.z - other.global_position.z)
		var d := diff.length()
		if d > 0.001 and d < desired:
			push += (diff / d) * ((desired - d) / desired)
	return push


func _constrain_to_ground_and_bounds() -> void:
	velocity.y = 0.0
	var p := _clamp_pos(global_position)
	p.y = 0.0
	global_position = p


func _clamp_pos(p: Vector3) -> Vector3:
	var out := Vector3(p.x, 0.0, p.z)
	if director != null and director.has_method("clamp_arena_position"):
		out = director.call("clamp_arena_position", out)
		out.y = 0.0
	return out


func _ensure_collider() -> void:
	if get_node_or_null("BodyCollider") != null:
		return
	var col := CollisionShape3D.new()
	col.name = "BodyCollider"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.50
	cap.height = 1.9
	col.shape = cap
	col.position = Vector3(0.0, 0.95, 0.0)
	add_child(col)


func _update_collider_radius() -> void:
	var col := get_node_or_null("BodyCollider") as CollisionShape3D
	if col != null and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.radius = body_radius * 0.85
		cap.height = maxf(1.8, body_radius * 2.6)
		col.position.y = cap.height * 0.5


func _get_hero() -> Node3D:
	if director != null and director.get("hero") is Node3D:
		var h := director.get("hero") as Node3D
		if is_instance_valid(h):
			return h
	if not is_inside_tree():
		return null
	var list := get_tree().get_nodes_in_group("combat_hero")
	return list[0] as Node3D if not list.is_empty() else null


func _forward_dir() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _face_direction_instant(dir: Vector3) -> void:
	if dir.length_squared() <= 0.0001:
		return
	rotation.y = atan2(-dir.x, -dir.z)


func _face_direction_smooth(dir: Vector3, rate: float, delta: float) -> void:
	if dir.length_squared() <= 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


func _play_sfx(ev: String) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", ev)


static func _hero_radius(hero: Node3D) -> float:
	var r: Variant = hero.get("body_radius")
	return float(r) if r != null else 0.48


static func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _is_in_cone_xz(
	origin: Vector3,
	forward: Vector3,
	target_pos: Vector3,
	max_dist: float,
	arc_deg: float,
	close_grace_dist: float = 0.90
) -> bool:
	var dv := Vector2(target_pos.x - origin.x, target_pos.z - origin.z)
	var dist := dv.length()
	if dist > max_dist:
		return false
	if dist <= close_grace_dist or arc_deg >= 359.0:
		return true
	var fwd := Vector2(forward.x, forward.z).normalized()
	var dir := dv / maxf(dist, 0.0001)
	return fwd.dot(dir) >= cos(deg_to_rad(arc_deg * 0.5))
