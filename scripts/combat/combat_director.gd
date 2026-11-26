class_name CombatDirector
extends Node3D

signal hud_updated(state: Dictionary)
signal boss_updated(boss_name: String, boss_title: String, current_hp: float, max_hp: float, is_enraged: bool)
signal damage_floated(world_pos: Vector3, amount: int, is_crit: bool, is_hero_hurt: bool, is_heal: bool)
signal shrine_offered(choices: Array[ShrineBlessingDef])
signal run_completed(victory: bool, summary: Dictionary)

const CAMERA_FOV_DEG: float = 56.0
const CAMERA_PITCH_DEG: float = 54.0
const CAMERA_DIST_NORMAL: float = 17.8
const CAMERA_DIST_BOSS: float = 20.5
const CAMERA_FOCUS_OFFSET := Vector3(0.0, 0.72, -1.9)
const HITSTOP_COOLDOWN_SEC: float = 0.38
const HITSTOP_TIME_SCALE: float = 0.25
const HITSTOP_DEFAULT_DURATION: float = 0.028

@export var auto_start_from_game_state: bool = false

var world_env: WorldEnvironment = null
var moon_light: DirectionalLight3D = null
var arena_root: Node3D = null
var actors_root: Node3D = null
var projectiles_root: Node3D = null
var drops_root: Node3D = null
var vfx_root: Node3D = null
var run_camera: Camera3D = null
var vfx: Node3D = null

var hero: HeroController3D = null
var active_boss: EnemyController3D = null
var dark_shrine: DarkShrine3D = null

var class_def: HeroClassDef = null
var zone_def: ZoneDef = null
var run_difficulty: GameEnums.Difficulty = GameEnums.Difficulty.NORMAL
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var arena_layout: Dictionary = {}

var is_shrine_open: bool = false
var run_started: bool = false
var run_finished: bool = false

var collected_gold: int = 0
var collected_items: Array[EquipmentItem] = []
var enemies_slain: int = 0
var total_damage_dealt: float = 0.0
var run_elapsed_sec: float = 0.0

var _enemies: Array[EnemyController3D] = []
var _alive_enemies_cache: Array[EnemyController3D] = []
var _alive_cache_tick: int = -1
var _alive_cache_source_size: int = -1
var _alive_cache_dirty: bool = true
var _clearings: Array[Dictionary] = []
var _all_clearings_cleared: bool = false
var _boss_spawned: bool = false
var _boss_fight_active: bool = false
var _boss_gate_arch_hidden: bool = false
var _boss_entry_radius: float = 14.0
var _pending_end_timer: float = -1.0
var _pending_victory: bool = false

var _cam_focus: Vector3 = Vector3.ZERO
var _cam_dist: float = CAMERA_DIST_NORMAL
var _cam_lead: Vector3 = Vector3.ZERO
var _cam_kick: Vector3 = Vector3.ZERO
var _camera_trauma: float = 0.0
var _shake_time: float = 0.0
var _hud_emit_accum: float = 0.0
var _hitstop_end_usec: int = 0
var _hitstop_cd_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 10
	_ensure_scene_nodes()
	if auto_start_from_game_state or (get_tree() != null and get_tree().current_scene == self):
		call_deferred("_auto_start_if_needed")


func _exit_tree() -> void:
	if _hitstop_end_usec > 0:
		_hitstop_end_usec = 0
		Engine.time_scale = 1.0
	arena_layout.clear()


func _auto_start_if_needed() -> void:
	if run_started:
		return
	var gs := _game_state()
	var cid := str(gs.get("selected_class_id")) if gs != null else "oathbreaker"
	var zid := str(gs.get("selected_zone_id")) if gs != null else "fringe"
	var diff := int(gs.get("selected_difficulty")) if gs != null else int(GameEnums.Difficulty.NORMAL)
	start_run(cid, zid, diff, 0)


func start_run(
	p_class_id: String,
	p_zone_id: String,
	p_difficulty: int,
	seed_val: int = 0
) -> void:
	_ensure_scene_nodes()
	_clear_run_world()

	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	class_def = GameRegistry.get_class_def(p_class_id)
	if class_def == null:
		class_def = GameRegistry.get_class_def("oathbreaker")

	zone_def = GameRegistry.get_zone(p_zone_id)
	if zone_def == null:
		zone_def = GameRegistry.get_zone("fringe")

	run_difficulty = clampi(p_difficulty, 0, GameEnums.Difficulty.size() - 1) as GameEnums.Difficulty

	is_shrine_open = false
	run_started = true
	run_finished = false
	collected_gold = 0
	collected_items.clear()
	enemies_slain = 0
	total_damage_dealt = 0.0
	run_elapsed_sec = 0.0
	_all_clearings_cleared = false
	_boss_spawned = false
	_boss_fight_active = false
	_boss_gate_arch_hidden = false
	_boss_entry_radius = 14.0
	_pending_end_timer = -1.0
	_pending_victory = false
	_camera_trauma = 0.0
	_hitstop_cd_timer = 0.0

	var vfx_mgr := VfxManager.new()
	vfx_mgr.name = "VfxManager"
	vfx_root.add_child(vfx_mgr)
	vfx = vfx_mgr
	VfxManager.prewarm_shaders(vfx_root)
	arena_layout = BarrowArenaBuilder.build_zone(arena_root, zone_def, int(rng.seed))
	_init_clearings_from_layout()

	var gs := _game_state()
	var equipped: Dictionary = {}
	var initial_stats: CombatStats = null
	if gs != null and gs.has_method("get_equipped"):
		equipped = gs.call("get_equipped", class_def.class_id)
		initial_stats = gs.call("get_combat_stats", class_def.class_id, [])
	else:
		for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
			equipped[slot] = LootEngine.make_starter_item(slot, class_def, rng)
		initial_stats = LootEngine.compute_combat_stats(class_def, equipped, [])

	hero = HeroController3D.new()
	hero.name = "Hero"
	actors_root.add_child(hero)
	var spawn_pos: Vector3 = arena_layout.get("spawn_pos", Vector3(0.0, 0.0, 38.0))
	hero.global_position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	hero.setup(self, vfx, class_def, initial_stats, equipped, rng)
	hero.health_changed.connect(_on_hero_health_changed)
	hero.died.connect(_on_hero_died)
	hero.dealt_damage.connect(_on_hero_dealt_damage)
	hero.took_damage.connect(_on_hero_took_damage)

	var shrine_pos: Vector3 = arena_layout.get("shrine_pos", Vector3(-4.5, 0.0, -4.0))
	dark_shrine = DarkShrine3D.new()
	dark_shrine.name = "DarkShrine"
	drops_root.add_child(dark_shrine)
	dark_shrine.setup(self, shrine_pos, rng)
	dark_shrine.shrine_triggered.connect(_on_shrine_triggered)

	_cam_dist = CAMERA_DIST_NORMAL
	_snap_camera_to_hero()

	var ad := _audio()
	if ad != null:
		ad.call("music", "hunt")
		ad.call("sfx", "hunt_start")

	_check_clearing_activations()
	hud_updated.emit(get_hud_state())


func _process(delta: float) -> void:
	if _hitstop_end_usec > 0 and Time.get_ticks_usec() >= _hitstop_end_usec:
		_hitstop_end_usec = 0
		Engine.time_scale = 1.0
	var unscaled_dt := minf(delta / maxf(Engine.time_scale, 0.05), 0.1)
	if _hitstop_cd_timer > 0.0:
		_hitstop_cd_timer = maxf(0.0, _hitstop_cd_timer - unscaled_dt)
	if run_started:
		_update_camera(minf(delta, 0.05))


func _physics_process(delta: float) -> void:
	if not run_started:
		return
	_refresh_alive_enemies_cache()

	if not is_shrine_open and not run_finished:
		run_elapsed_sec += delta
		_check_clearing_activations()
		_check_boss_trigger()
		_tick_boss_entry_radius(delta)
		_update_boss_gate_sightline()

	if _pending_end_timer >= 0.0 and not run_finished:
		_pending_end_timer -= delta
		if _pending_end_timer <= 0.0:
			finalize_pending_run()

	_hud_emit_accum += delta
	if _hud_emit_accum >= 0.10:
		_hud_emit_accum = 0.0
		hud_updated.emit(get_hud_state())


func set_virtual_move(v: Vector2) -> void:
	if hero != null and is_instance_valid(hero):
		hero.external_move_input = v


func press_attack(pressed: bool = true) -> void:
	if hero != null and is_instance_valid(hero):
		hero.manual_attack_held = pressed
		if pressed:
			hero.manual_attack_requested = true


func press_dash() -> bool:
	if hero != null and is_instance_valid(hero) and not is_shrine_open:
		return hero.trigger_dash()
	return false


func press_skill_1() -> bool:
	if hero != null and is_instance_valid(hero) and not is_shrine_open:
		return hero.trigger_skill_1()
	return false


func press_skill_2() -> bool:
	if hero != null and is_instance_valid(hero) and not is_shrine_open:
		return hero.trigger_skill_2()
	return false


func press_skill_3() -> bool:
	if hero != null and is_instance_valid(hero) and not is_shrine_open:
		return hero.trigger_skill_3()
	return false


func apply_shrine_choice(blessing_id: String) -> bool:
	if hero == null or not is_instance_valid(hero):
		is_shrine_open = false
		return false
	var bdef := GameRegistry.get_blessing(blessing_id)
	if bdef == null:
		if dark_shrine != null and not dark_shrine.offered_choices.is_empty():
			bdef = dark_shrine.offered_choices[0]
		else:
			is_shrine_open = false
			return false

	if not hero.active_blessings.has(bdef.blessing_id):
		hero.active_blessings.append(bdef.blessing_id)

	var new_stats := LootEngine.compute_combat_stats(class_def, hero.equipped_items, hero.active_blessings)
	hero.refresh_combat_stats(new_stats, 0.25)

	if dark_shrine != null and is_instance_valid(dark_shrine):
		dark_shrine.mark_consumed()

	is_shrine_open = false
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "card_pick")
		ad.call("sfx", "skill_level")
	hud_updated.emit(get_hud_state())
	return true


func spawn_enemy_at(
	enemy_id: String,
	world_pos: Vector3,
	is_elite: bool = false,
	clearing_idx: int = -1,
	is_summon: bool = false
) -> EnemyController3D:
	var edef := GameRegistry.get_enemy(enemy_id)
	if edef == null:
		edef = GameRegistry.get_enemy("hollow_ghoul")
	var enemy := EnemyController3D.new()
	enemy.name = "%s_%d" % [edef.enemy_id, _enemies.size()]
	enemy.is_boss_summon = is_summon
	actors_root.add_child(enemy)
	var clamped := clamp_arena_position(world_pos)
	enemy.global_position = Vector3(clamped.x, 0.0, clamped.z)
	enemy.setup(self, vfx, edef, run_difficulty, is_elite, clearing_idx, rng)
	enemy.died.connect(_on_enemy_died)
	enemy.took_damage.connect(_on_enemy_took_damage)
	_enemies.append(enemy)
	_alive_cache_dirty = true
	return enemy


func spawn_boss_adds(boss_pos: Vector3, count: int = 3) -> Array[EnemyController3D]:
	var spawned: Array[EnemyController3D] = []
	for i in range(maxi(1, count)):
		var angle := (TAU / float(maxi(1, count))) * float(i) + 0.4
		var p := boss_pos + Vector3(cos(angle) * 3.8, 0.0, sin(angle) * 3.8)
		var add := spawn_enemy_at("hollow_ghoul", p, false, -1, true)
		add.state = EnemyController3D.State.CHASE
		spawned.append(add)
	return spawned


func spawn_boss_encounter() -> EnemyController3D:
	if _boss_spawned and active_boss != null and is_instance_valid(active_boss):
		return active_boss

	_unlock_boss_gate()
	_boss_spawned = true
	_boss_fight_active = true

	var boss_center: Vector3 = arena_layout.get("boss_center", Vector3(0.0, 0.0, -45.0))
	var b_rad := float(arena_layout.get("boss_radius", 14.0))
	_boss_entry_radius = b_rad
	var spawn_p := Vector3(boss_center.x, 0.0, boss_center.z)
	if hero != null and is_instance_valid(hero):
		var hero_rel := Vector2(hero.global_position.x - boss_center.x, hero.global_position.z - boss_center.z).length()
		if hero_rel > b_rad:
			_boss_entry_radius = hero_rel
		if Vector2(hero.global_position.x - spawn_p.x, hero.global_position.z - spawn_p.z).length() < 3.5:
			spawn_p.z -= 5.0

	_update_boss_gate_sightline()

	active_boss = spawn_enemy_at(zone_def.boss_id, spawn_p, false, -1, false)
	active_boss.state = EnemyController3D.State.CHASE
	active_boss.health_changed.connect(_on_boss_health_changed)
	active_boss.enraged.connect(_on_boss_enraged)

	var ad := _audio()
	if ad != null:
		ad.call("music", "boss")
		ad.call("sfx", "boss_roar")

	boss_updated.emit(
		active_boss.enemy_def.display_name,
		active_boss.enemy_def.title,
		active_boss.current_hp,
		active_boss.max_hp,
		active_boss.is_enraged
	)
	hud_updated.emit(get_hud_state())
	return active_boss


func _refresh_alive_enemies_cache() -> void:
	var next_alive: Array[EnemyController3D] = []
	var i := _enemies.size() - 1
	while i >= 0:
		var e := _enemies[i]
		if e == null or not is_instance_valid(e):
			_enemies.remove_at(i)
		elif not e.is_dead():
			next_alive.append(e)
		i -= 1
	# Swap snapshot reference instead of mutating in place so active iterators stay safe.
	_alive_enemies_cache = next_alive
	_alive_cache_tick = Engine.get_physics_frames()
	_alive_cache_source_size = _enemies.size()
	_alive_cache_dirty = false


func get_alive_enemies() -> Array[EnemyController3D]:
	var cur_tick := Engine.get_physics_frames()
	if _alive_cache_dirty or _alive_cache_tick != cur_tick or _alive_cache_source_size != _enemies.size():
		_refresh_alive_enemies_cache()
		return _alive_enemies_cache
	for e in _alive_enemies_cache:
		if e == null or not is_instance_valid(e) or e.is_dead():
			_refresh_alive_enemies_cache()
			break
	return _alive_enemies_cache


func get_camera() -> Camera3D:
	return run_camera


func get_hud_tracked_enemies() -> Array:
	var tracked: Array = []
	for e in get_alive_enemies():
		if e == active_boss or (e.enemy_def != null and e.enemy_def.is_boss):
			continue
		if e.is_elite or e.current_hp < e.max_hp - 0.5:
			tracked.append(e)
	if tracked.size() > 1 and hero != null and is_instance_valid(hero):
		var hpos := hero.global_position
		tracked.sort_custom(func(a: EnemyController3D, b: EnemyController3D) -> bool:
			if a.is_elite != b.is_elite:
				return a.is_elite
			var da := Vector2(a.global_position.x - hpos.x, a.global_position.z - hpos.z).length_squared()
			var db := Vector2(b.global_position.x - hpos.x, b.global_position.z - hpos.z).length_squared()
			return da < db
		)
	return tracked


func get_objective_target_world_pos() -> Vector3:
	if _boss_fight_active and active_boss != null and is_instance_valid(active_boss) and not active_boss.is_dead():
		return active_boss.global_position

	var ref_pos := hero.global_position if hero != null and is_instance_valid(hero) else Vector3.ZERO
	var alive := get_alive_enemies()
	if not alive.is_empty():
		var best_e: EnemyController3D = null
		var best_d_sq := INF
		for e in alive:
			var d_sq := Vector2(e.global_position.x - ref_pos.x, e.global_position.z - ref_pos.z).length_squared()
			if d_sq < best_d_sq:
				best_d_sq = d_sq
				best_e = e
		if best_e != null:
			return best_e.global_position

	var shrine_available := dark_shrine != null and is_instance_valid(dark_shrine) and not dark_shrine.is_consumed
	var gate_z := float(arena_layout.get("boss_gate_z", -32.0))
	var gate_target := Vector3(0.0, 0.0, gate_z - 2.0)

	if not _all_clearings_cleared:
		var next_clearing := Vector3.ZERO
		var found_clearing := false
		var best_cl_d_sq := INF
		for c in _clearings:
			if bool(c["cleared"]):
				continue
			var cp: Vector3 = c["center"]
			var d_sq := Vector2(cp.x - ref_pos.x, cp.z - ref_pos.z).length_squared()
			if d_sq < best_cl_d_sq:
				best_cl_d_sq = d_sq
				next_clearing = cp
				found_clearing = true
		if shrine_available:
			var sd_sq := Vector2(dark_shrine.global_position.x - ref_pos.x, dark_shrine.global_position.z - ref_pos.z).length_squared()
			if not found_clearing or sd_sq < best_cl_d_sq:
				return dark_shrine.global_position
		if found_clearing:
			return next_clearing

	if shrine_available:
		var sd_sq := Vector2(dark_shrine.global_position.x - ref_pos.x, dark_shrine.global_position.z - ref_pos.z).length_squared()
		var gd_sq := Vector2(gate_target.x - ref_pos.x, gate_target.z - ref_pos.z).length_squared()
		if sd_sq < gd_sq:
			return dark_shrine.global_position

	return gate_target


func get_hud_state() -> Dictionary:
	var cleared_count := 0
	for c in _clearings:
		if bool(c["cleared"]):
			cleared_count += 1

	var hp := hero.current_hp if hero != null and is_instance_valid(hero) else 0.0
	var mhp := hero.stats.max_hp if hero != null and is_instance_valid(hero) and hero.stats != null else 1.0
	var ward := hero.ward_hp if hero != null and is_instance_valid(hero) else 0.0

	return {
		"class_id": class_def.class_id if class_def != null else "oathbreaker",
		"class_name": class_def.display_name if class_def != null else "Oathbreaker Knight",
		"zone_id": zone_def.zone_id if zone_def != null else "fringe",
		"zone_name": zone_def.display_name if zone_def != null else "Barrow Fringe",
		"difficulty": int(run_difficulty),
		"difficulty_name": GameEnums.difficulty_name(run_difficulty),
		"hp": hp,
		"max_hp": mhp,
		"ward_hp": ward,
		"gold": collected_gold,
		"items_collected": collected_items.size(),
		"enemies_slain": enemies_slain,
		"enemies_alive": get_alive_enemies().size(),
		"clearings_cleared": cleared_count,
		"clearings_total": _clearings.size(),
		"boss_gate_unlocked": not bool(arena_layout.get("boss_gate_locked", true)),
		"boss_active": _boss_fight_active and active_boss != null and is_instance_valid(active_boss) and not active_boss.is_dead(),
		"dash_cd": hero.dash_cooldown_left if hero != null else 0.0,
		"dash_max": hero.dash_cooldown_max if hero != null else 3.0,
		"skill_1_cd": hero.skill_1_cooldown_left if hero != null else 0.0,
		"skill_1_max": hero.skill_1_cooldown_max if hero != null else 6.0,
		"skill_1_name": class_def.skill_1.display_name if class_def != null and class_def.skill_1 != null else "Skill 1",
		"skill_2_cd": hero.skill_2_cooldown_left if hero != null else 0.0,
		"skill_2_max": hero.skill_2_cooldown_max if hero != null else 8.0,
		"skill_2_name": class_def.skill_2.display_name if class_def != null and class_def.skill_2 != null else "Skill 2",
		"skill_3_cd": hero.skill_3_cooldown_left if hero != null else 0.0,
		"skill_3_max": hero.skill_3_cooldown_max if hero != null else 8.0,
		"skill_3_name": class_def.skill_3.display_name if class_def != null and class_def.skill_3 != null else "",
		"blessings": hero.active_blessings.duplicate() if hero != null else [],
		"elapsed_sec": run_elapsed_sec,
	}


func clamp_arena_position(pos: Vector3) -> Vector3:
	var out := BarrowArenaBuilder.clamp_position(pos, arena_layout)

	var gate_z := float(arena_layout.get("boss_gate_z", -28.0))
	if bool(arena_layout.get("boss_gate_locked", false)):
		if out.z < gate_z + 0.75:
			out.z = gate_z + 0.75
	elif _boss_fight_active:
		if out.z > gate_z - 0.5:
			out.z = gate_z - 0.5
		var b_center: Vector3 = arena_layout.get("boss_center", Vector3(0.0, 0.0, -45.0))
		var b_rad := maxf(float(arena_layout.get("boss_radius", 14.0)), _boss_entry_radius)
		var rel := Vector2(out.x - b_center.x, out.z - b_center.z)
		if rel.length() > b_rad:
			rel = rel.normalized() * b_rad
			out.x = b_center.x + rel.x
			out.z = b_center.z + rel.y

	out.y = 0.0
	return out


func is_outside_arena_bounds(pos: Vector3) -> bool:
	var clamped := clamp_arena_position(pos)
	return Vector2(pos.x - clamped.x, pos.z - clamped.z).length_squared() > 0.25


func add_camera_trauma(amount: float) -> void:
	_camera_trauma = clampf(_camera_trauma + amount, 0.0, 1.0)


func add_camera_kick(dir: Vector3, strength: float = 0.24) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0001:
		_cam_kick = (_cam_kick + flat.normalized() * strength).limit_length(0.55)


func trigger_hitstop(duration_sec: float = HITSTOP_DEFAULT_DURATION) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_shrine_open or run_finished or Engine.time_scale > 1.2 or _hitstop_end_usec > 0 or _hitstop_cd_timer > 0.0:
		return
	_hitstop_cd_timer = HITSTOP_COOLDOWN_SEC
	_hitstop_end_usec = Time.get_ticks_usec() + roundi(clampf(duration_sec, 0.012, 0.036) * 1_000_000.0)
	Engine.time_scale = HITSTOP_TIME_SCALE


func notify_heal_floated(world_pos: Vector3, amount: int) -> void:
	if amount > 0:
		damage_floated.emit(world_pos, amount, false, false, true)


func finalize_pending_run() -> void:
	if run_finished:
		return
	run_finished = true
	_pending_end_timer = -1.0

	if _pending_victory:
		_sweep_all_remaining_drops()

	var gs := _game_state()
	if gs != null:
		if _pending_victory and gs.has_method("record_run_victory"):
			gs.call("record_run_victory", zone_def.zone_id, run_difficulty, collected_gold, collected_items)
		elif not _pending_victory and gs.has_method("record_run_defeat"):
			gs.call("record_run_defeat", collected_gold, collected_items)

	var summary := {
		"victory": _pending_victory,
		"class_id": class_def.class_id if class_def != null else "oathbreaker",
		"zone_id": zone_def.zone_id if zone_def != null else "fringe",
		"zone_name": zone_def.display_name if zone_def != null else "Barrow Fringe",
		"difficulty": int(run_difficulty),
		"difficulty_name": GameEnums.difficulty_name(run_difficulty),
		"gold_earned": collected_gold,
		"items_dropped": collected_items.duplicate(),
		"enemies_slain": enemies_slain,
		"damage_dealt": roundi(total_damage_dealt),
		"duration_sec": snappedf(run_elapsed_sec, 0.1),
		"blessings": hero.active_blessings.duplicate() if hero != null and is_instance_valid(hero) else [],
	}
	hud_updated.emit(get_hud_state())
	run_completed.emit(_pending_victory, summary)


func _check_clearing_activations() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	for i in range(_clearings.size()):
		var cl: Dictionary = _clearings[i]
		if bool(cl["activated"]):
			continue
		var center: Vector3 = cl["center"]
		var d := Vector2(hero.global_position.x - center.x, hero.global_position.z - center.z).length()
		if d <= 15.0:
			cl["activated"] = true
			_clearings[i] = cl
			_spawn_clearing_wave(i, center)


func _spawn_clearing_wave(idx: int, center: Vector3) -> void:
	var pool := zone_def.enemy_pool
	if pool.is_empty():
		pool = ["hollow_ghoul"]

	var regular_count := 4 + idx
	for k in range(regular_count):
		var angle := (TAU / float(regular_count)) * float(k) + rng.randf_range(-0.22, 0.22)
		var rad := rng.randf_range(4.2, 6.8)
		var pos := center + Vector3(cos(angle) * rad, 0.0, sin(angle) * rad)
		var eid := pool[rng.randi_range(0, pool.size() - 1)]
		var e := spawn_enemy_at(eid, pos, false, idx, false)
		e.state = EnemyController3D.State.CHASE

	if idx == 2 and zone_def.elite_id != "":
		var elite_pos := center + Vector3(0.0, 0.0, -3.5)
		var elite := spawn_enemy_at(zone_def.elite_id, elite_pos, true, idx, false)
		elite.state = EnemyController3D.State.CHASE


func _check_clearings_progress() -> void:
	if _all_clearings_cleared:
		return
	var all_done := true
	for i in range(_clearings.size()):
		var cl: Dictionary = _clearings[i]
		if not bool(cl["activated"]):
			all_done = false
			continue
		if bool(cl["cleared"]):
			continue
		var alive_in_clearing := 0
		for e in get_alive_enemies():
			if e.clearing_index == i:
				alive_in_clearing += 1
		if alive_in_clearing == 0:
			cl["cleared"] = true
			_clearings[i] = cl
		else:
			all_done = false

	if all_done and not _clearings.is_empty():
		_all_clearings_cleared = true
		_unlock_boss_gate()
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "banner")
		hud_updated.emit(get_hud_state())


func _unlock_boss_gate() -> void:
	arena_layout["boss_gate_locked"] = false
	var cb: Variant = arena_layout.get("unlock_boss_gate")
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()


func _check_boss_trigger() -> void:
	if _boss_spawned or hero == null or not is_instance_valid(hero):
		return
	if bool(arena_layout.get("boss_gate_locked", false)):
		return
	var gate_z := float(arena_layout.get("boss_gate_z", -32.0))
	var trigger_z := minf(-33.5, gate_z - 1.5)
	if hero.global_position.z <= trigger_z:
		spawn_boss_encounter()


func _tick_boss_entry_radius(delta: float) -> void:
	if not _boss_fight_active or hero == null or not is_instance_valid(hero):
		return
	var b_rad := float(arena_layout.get("boss_radius", 14.0))
	if _boss_entry_radius <= b_rad:
		return
	var b_center: Vector3 = arena_layout.get("boss_center", Vector3(0.0, 0.0, -45.0))
	var hero_rel := Vector2(hero.global_position.x - b_center.x, hero.global_position.z - b_center.z).length()
	_boss_entry_radius = minf(_boss_entry_radius, maxf(b_rad, hero_rel))
	_boss_entry_radius = move_toward(_boss_entry_radius, b_rad, 4.5 * delta)


func _update_boss_gate_sightline() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var should_hide := _boss_fight_active or hero.global_position.z < -31.5
	if should_hide == _boss_gate_arch_hidden:
		return
	_boss_gate_arch_hidden = should_hide
	var cb: Variant = arena_layout.get("set_boss_gate_arch_visible")
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(not should_hide)
	elif arena_root != null:
		var arch_vis := arena_root.get_node_or_null("BossGate/GateArchVisuals") as Node3D
		if arch_vis != null:
			arch_vis.visible = not should_hide


func _on_enemy_died(enemy: EnemyController3D) -> void:
	if enemy == null:
		return
	_alive_cache_dirty = true
	enemies_slain += 1

	if enemy == active_boss:
		_handle_boss_slain(enemy)
		return

	if not enemy.is_boss_summon:
		_spawn_gold_drop(enemy.global_position, enemy.gold_reward, false)
		var diff_bonus := int(EnemyController3D.difficulty_multipliers(run_difficulty)["bonus_rolls"])
		var item_chance := 1.0 if enemy.is_elite else (0.14 + 0.07 * float(diff_bonus))
		if rng.randf() < item_chance:
			var min_rar := GameEnums.Rarity.RARE if enemy.is_elite else GameEnums.Rarity.COMMON
			var rolled := LootEngine.roll_item(
				rng,
				zone_def.max_drop_tier,
				run_difficulty,
				class_def.allowed_weapons,
				min_rar
			)
			_spawn_item_drop(enemy.global_position, rolled, false)

	_check_clearings_progress()
	hud_updated.emit(get_hud_state())


func _handle_boss_slain(boss: EnemyController3D) -> void:
	if hero != null and is_instance_valid(hero) and not hero.is_dead():
		hero.grant_iframes(5.0)

	for e in get_alive_enemies().duplicate():
		if e != boss and is_instance_valid(e):
			e.kill_silently()
	_alive_cache_dirty = true

	if projectiles_root != null:
		for proj in projectiles_root.get_children():
			if proj != null and is_instance_valid(proj):
				proj.set_physics_process(false)
				proj.visible = false
				proj.queue_free()

	if drops_root != null:
		for ch in drops_root.get_children():
			if ch is LootDrop3D:
				(ch as LootDrop3D).force_vacuum = true

	boss_updated.emit(boss.enemy_def.display_name, boss.enemy_def.title, 0.0, boss.max_hp, boss.is_enraged)

	var coin_piles := 6
	var per_pile := maxi(2, boss.gold_reward / coin_piles)
	for i in range(coin_piles):
		_spawn_gold_drop(boss.global_position, per_pile, true)

	var diff_bonus := int(EnemyController3D.difficulty_multipliers(run_difficulty)["bonus_rolls"])
	var drop_count := clampi(2 + diff_bonus + (1 if diff_bonus == 0 and rng.randf() < 0.35 else 0), 2, 4)
	for i in range(drop_count):
		var min_rar := GameEnums.Rarity.COMMON
		if i == 0:
			min_rar = GameEnums.Rarity.EPIC if run_difficulty == GameEnums.Difficulty.NIGHTMARE else GameEnums.Rarity.RARE
		elif run_difficulty == GameEnums.Difficulty.NIGHTMARE and i == 1:
			min_rar = GameEnums.Rarity.RARE
		var item := LootEngine.roll_item(
			rng,
			zone_def.max_drop_tier,
			run_difficulty,
			class_def.allowed_weapons,
			min_rar
		)
		_spawn_item_drop(boss.global_position, item, true)

	var ad := _audio()
	if ad != null and ad.has_method("sting"):
		ad.call("sting", true)

	_pending_victory = true
	_pending_end_timer = 0.75


func _spawn_gold_drop(origin: Vector3, amount: int, vacuum: bool) -> LootDrop3D:
	var drop := LootDrop3D.new()
	drop.force_vacuum = vacuum
	drops_root.add_child(drop)
	drop.setup_gold(self, origin, amount, rng)
	drop.collected_gold.connect(_on_gold_collected)
	return drop


func _spawn_item_drop(origin: Vector3, item: EquipmentItem, vacuum: bool) -> LootDrop3D:
	var drop := LootDrop3D.new()
	drop.force_vacuum = vacuum
	drops_root.add_child(drop)
	drop.setup_item(self, vfx, origin, item, rng)
	drop.collected_item.connect(_on_item_collected)
	return drop


func _sweep_all_remaining_drops() -> void:
	if drops_root == null:
		return
	for child in drops_root.get_children():
		if child is LootDrop3D:
			var ld := child as LootDrop3D
			if not ld.is_collected():
				ld.collect_immediately()


func _on_gold_collected(amount: int) -> void:
	collected_gold += maxi(0, amount)
	hud_updated.emit(get_hud_state())


func _on_item_collected(item: EquipmentItem) -> void:
	if item != null and not collected_items.has(item):
		collected_items.append(item)
	hud_updated.emit(get_hud_state())


func _on_shrine_triggered(choices: Array[ShrineBlessingDef]) -> void:
	is_shrine_open = true
	shrine_offered.emit(choices)


func _on_hero_health_changed(_hp: float, _mhp: float, _ward: float) -> void:
	hud_updated.emit(get_hud_state())


func _on_hero_died() -> void:
	if run_finished or _pending_end_timer >= 0.0 or _pending_victory:
		return
	var ad := _audio()
	if ad != null and ad.has_method("sting"):
		ad.call("sting", false)
	_pending_victory = false
	_pending_end_timer = 0.75


func _on_hero_dealt_damage(_target: Node3D, ev: DamageEvent) -> void:
	if ev == null:
		return
	total_damage_dealt += ev.final_damage
	damage_floated.emit(ev.hit_position, maxi(1, roundi(ev.final_damage)), ev.is_crit, false, false)


func _on_hero_took_damage(ev: DamageEvent) -> void:
	if ev != null and ev.final_damage > 0.0:
		damage_floated.emit(ev.hit_position, maxi(1, roundi(ev.final_damage)), false, true, false)


func _on_enemy_took_damage(_enemy: EnemyController3D, ev: DamageEvent) -> void:
	if ev != null and ev.is_dot and ev.attacker == null:
		total_damage_dealt += ev.final_damage
		damage_floated.emit(ev.hit_position, maxi(1, roundi(ev.final_damage)), false, false, false)


func _on_boss_health_changed(boss: EnemyController3D, cur_hp: float, m_hp: float) -> void:
	boss_updated.emit(boss.enemy_def.display_name, boss.enemy_def.title, cur_hp, m_hp, boss.is_enraged)


func _on_boss_enraged(boss: EnemyController3D) -> void:
	boss_updated.emit(boss.enemy_def.display_name, boss.enemy_def.title, boss.current_hp, boss.max_hp, true)


func _snap_camera_to_hero() -> void:
	if run_camera == null or hero == null:
		return
	run_camera.fov = CAMERA_FOV_DEG
	run_camera.far = 75.0
	run_camera.rotation_degrees = Vector3(-CAMERA_PITCH_DEG, 0.0, 0.0)
	_cam_lead = Vector3.ZERO
	_cam_kick = Vector3.ZERO
	_cam_focus = hero.global_position + CAMERA_FOCUS_OFFSET
	var pitch_rad := deg_to_rad(CAMERA_PITCH_DEG)
	var offset := Vector3(0.0, sin(pitch_rad), cos(pitch_rad)) * _cam_dist
	run_camera.global_position = _cam_focus + offset


func _update_camera(delta: float) -> void:
	if run_camera == null or hero == null or not is_instance_valid(hero):
		return

	var target_dist := CAMERA_DIST_BOSS if _boss_fight_active else CAMERA_DIST_NORMAL
	_cam_dist = lerpf(_cam_dist, target_dist, 1.0 - exp(-5.5 * delta))

	var hero_pos := hero.get_global_transform_interpolated().origin if hero.is_inside_tree() else hero.global_position
	var vel_xz := Vector3(hero.velocity.x, 0.0, hero.velocity.z)
	var target_lead := vel_xz.limit_length(5.5) * 0.12
	_cam_lead = _cam_lead.lerp(target_lead, 1.0 - exp(-6.5 * delta))
	_cam_kick = _cam_kick.lerp(Vector3.ZERO, 1.0 - exp(-18.0 * delta))

	var boss_pull := Vector3.ZERO
	if _boss_fight_active and active_boss != null and is_instance_valid(active_boss) and not active_boss.is_dead():
		var boss_pos := active_boss.get_global_transform_interpolated().origin if active_boss.is_inside_tree() else active_boss.global_position
		boss_pull = (Vector3(boss_pos.x - hero_pos.x, 0.0, boss_pos.z - hero_pos.z) * 0.22).limit_length(3.2)

	var desired_focus := hero_pos + CAMERA_FOCUS_OFFSET + boss_pull + _cam_lead + _cam_kick
	var alpha := 1.0 - exp(-14.0 * delta)
	_cam_focus = _cam_focus.lerp(desired_focus, alpha)

	var pitch_rad := deg_to_rad(CAMERA_PITCH_DEG)
	var offset := Vector3(0.0, sin(pitch_rad), cos(pitch_rad)) * _cam_dist

	var shake_offset := Vector3.ZERO
	if _camera_trauma > 0.0:
		_camera_trauma = maxf(0.0, _camera_trauma - 1.9 * delta)
		_shake_time += delta * 34.0
		var ad := _audio()
		var shake_mult := float(ad.call("shake_scale")) if ad != null and ad.has_method("shake_scale") else 1.0
		var mag := _camera_trauma * _camera_trauma * 0.42 * shake_mult
		shake_offset = Vector3(sin(_shake_time * 1.7) * mag, cos(_shake_time * 2.3) * mag * 0.5, sin(_shake_time * 1.1) * mag)

	run_camera.rotation_degrees = Vector3(-CAMERA_PITCH_DEG, 0.0, 0.0)
	run_camera.global_position = _cam_focus + offset + shake_offset


func _init_clearings_from_layout() -> void:
	_clearings.clear()
	var raw_list: Variant = arena_layout.get("clearings", [])
	if raw_list is Array:
		for entry in raw_list:
			_clearings.append({
				"center": _extract_clearing_pos(entry),
				"activated": false,
				"cleared": false,
			})
	if _clearings.is_empty():
		for pos in [Vector3(0.0, 0.0, 24.0), Vector3(-3.0, 0.0, 6.0), Vector3(2.5, 0.0, -14.0)]:
			_clearings.append({"center": pos, "activated": false, "cleared": false})


func _ensure_scene_nodes() -> void:
	world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)

	moon_light = get_node_or_null("MoonLight") as DirectionalLight3D
	if moon_light == null:
		moon_light = DirectionalLight3D.new()
		moon_light.name = "MoonLight"
		moon_light.rotation_degrees = Vector3(-54.0, 28.0, 0.0)
		moon_light.light_color = Color(0.78, 0.84, 0.96, 1.0)
		moon_light.light_energy = 1.35
		moon_light.shadow_enabled = true
		add_child(moon_light)

	arena_root = _ensure_group_node("ArenaRoot")
	actors_root = _ensure_group_node("ActorsRoot")
	projectiles_root = _ensure_group_node("ProjectilesRoot")
	drops_root = _ensure_group_node("DropsRoot")
	vfx_root = _ensure_group_node("VfxRoot")

	run_camera = get_node_or_null("RunCamera") as Camera3D
	if run_camera == null:
		run_camera = Camera3D.new()
		run_camera.name = "RunCamera"
		run_camera.fov = CAMERA_FOV_DEG
		run_camera.current = true
		add_child(run_camera)
	run_camera.fov = CAMERA_FOV_DEG
	run_camera.far = 75.0
	# Camera tracks interpolated hero transforms in _process; disable physics interpolation on the camera itself to avoid double-buffering jitter.
	run_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ensure_group_node(node_name: String) -> Node3D:
	var n := get_node_or_null(node_name) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = node_name
		add_child(n)
	return n


func _clear_run_world() -> void:
	if _hitstop_end_usec > 0:
		_hitstop_end_usec = 0
		Engine.time_scale = 1.0
	_hitstop_cd_timer = 0.0
	_boss_gate_arch_hidden = false
	_boss_entry_radius = 14.0
	hero = null
	active_boss = null
	dark_shrine = null
	vfx = null
	arena_layout.clear()
	_enemies.clear()
	_alive_enemies_cache = []
	_alive_cache_tick = -1
	_alive_cache_source_size = -1
	_alive_cache_dirty = true
	_clearings.clear()
	for container in [arena_root, actors_root, projectiles_root, drops_root, vfx_root]:
		if container == null:
			continue
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


static func _extract_clearing_pos(entry: Variant) -> Vector3:
	if entry is Vector3:
		return entry as Vector3
	if entry is Dictionary:
		var d := entry as Dictionary
		for key in ["center", "pos", "position"]:
			if d.has(key) and d[key] is Vector3:
				return d[key] as Vector3
	return Vector3.ZERO
