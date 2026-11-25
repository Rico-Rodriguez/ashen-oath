class_name CombatDirector
extends Node3D

signal hud_updated(state: Dictionary)
signal boss_updated(boss_name: String, boss_title: String, current_hp: float, max_hp: float, is_enraged: bool)
signal damage_floated(world_pos: Vector3, amount: int, is_crit: bool, is_hero_hurt: bool, is_heal: bool)
signal shrine_offered(choices: Array[ShrineBlessingDef])
signal run_completed(victory: bool, summary: Dictionary)

const CAMERA_FOV_DEG: float = 42.0
const CAMERA_PITCH_DEG: float = 52.0
const CAMERA_DIST_NORMAL: float = 15.5
const CAMERA_DIST_BOSS: float = 17.5

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
var _clearings: Array[Dictionary] = []
var _all_clearings_cleared: bool = false
var _boss_spawned: bool = false
var _boss_fight_active: bool = false
var _pending_end_timer: float = -1.0
var _pending_victory: bool = false

var _cam_focus: Vector3 = Vector3.ZERO
var _cam_dist: float = CAMERA_DIST_NORMAL
var _camera_trauma: float = 0.0
var _shake_time: float = 0.0
var _hud_emit_accum: float = 0.0


func _ready() -> void:
	process_physics_priority = 10
	_ensure_scene_nodes()
	if auto_start_from_game_state or (get_tree() != null and get_tree().current_scene == self):
		call_deferred("_auto_start_if_needed")


func _exit_tree() -> void:
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
	_pending_end_timer = -1.0
	_pending_victory = false
	_camera_trauma = 0.0

	var vfx_mgr := VfxManager.new()
	vfx_mgr.name = "VfxManager"
	vfx_root.add_child(vfx_mgr)
	vfx = vfx_mgr
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


func _physics_process(delta: float) -> void:
	if not run_started:
		return

	if not is_shrine_open and not run_finished:
		run_elapsed_sec += delta
		_check_clearing_activations()
		_check_boss_trigger()

	if _pending_end_timer >= 0.0 and not run_finished:
		_pending_end_timer -= delta
		if _pending_end_timer <= 0.0:
			finalize_pending_run()

	_update_camera(delta)

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

	var boss_center: Vector3 = arena_layout.get("boss_center", Vector3(0.0, 0.0, -44.0))
	var spawn_p := Vector3(boss_center.x, 0.0, boss_center.z)
	if hero != null and is_instance_valid(hero):
		if Vector2(hero.global_position.x - spawn_p.x, hero.global_position.z - spawn_p.z).length() < 3.5:
			spawn_p.z -= 5.0

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


func get_alive_enemies() -> Array[EnemyController3D]:
	var out: Array[EnemyController3D] = []
	var i := _enemies.size() - 1
	while i >= 0:
		var e := _enemies[i]
		if e == null or not is_instance_valid(e):
			_enemies.remove_at(i)
		elif not e.is_dead():
			out.append(e)
		i -= 1
	return out


func get_camera() -> Camera3D:
	return run_camera


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
		var b_center: Vector3 = arena_layout.get("boss_center", Vector3(0.0, 0.0, -44.0))
		var b_rad := float(arena_layout.get("boss_radius", 14.0))
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
	var gate_z := float(arena_layout.get("boss_gate_z", -28.0))
	var trigger_z := minf(-33.0, gate_z - 0.8)
	if hero.global_position.z < trigger_z:
		spawn_boss_encounter()


func _on_enemy_died(enemy: EnemyController3D) -> void:
	if enemy == null:
		return
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
	for e in get_alive_enemies():
		if e != boss and e.is_boss_summon:
			e.kill_silently()

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
	if run_finished or _pending_end_timer >= 0.0:
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
	run_camera.rotation_degrees = Vector3(-CAMERA_PITCH_DEG, 0.0, 0.0)
	_cam_focus = hero.global_position + Vector3(0.0, 0.95, -0.65)
	var pitch_rad := deg_to_rad(CAMERA_PITCH_DEG)
	var offset := Vector3(0.0, sin(pitch_rad), cos(pitch_rad)) * _cam_dist
	run_camera.global_position = _cam_focus + offset


func _update_camera(delta: float) -> void:
	if run_camera == null or hero == null or not is_instance_valid(hero):
		return

	var target_dist := CAMERA_DIST_BOSS if _boss_fight_active else CAMERA_DIST_NORMAL
	_cam_dist = lerpf(_cam_dist, target_dist, 1.0 - exp(-5.5 * delta))

	var desired_focus := hero.global_position + Vector3(0.0, 0.95, -0.65)
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


func _ensure_group_node(node_name: String) -> Node3D:
	var n := get_node_or_null(node_name) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = node_name
		add_child(n)
	return n


func _clear_run_world() -> void:
	hero = null
	active_boss = null
	dark_shrine = null
	vfx = null
	arena_layout.clear()
	_enemies.clear()
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
