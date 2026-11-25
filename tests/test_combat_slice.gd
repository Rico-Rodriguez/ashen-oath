extends SceneTree

var _checks_passed: int = 0
var _checks_failed: int = 0
var _had_save_before: bool = false
var _prior_save_bytes: PackedByteArray = PackedByteArray()
var _arena_scene: PackedScene = null


func _init() -> void:
	_had_save_before = FileAccess.file_exists("user://ashen_oath_save.json")
	if _had_save_before:
		_prior_save_bytes = FileAccess.get_file_as_bytes("user://ashen_oath_save.json")


func _initialize() -> void:
	call_deferred("_run_all")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_checks_failed += 1
		push_error("ASSERTION FAILED: %s" % msg)
		printerr("ASSERTION FAILED: %s" % msg)
		return
	_checks_passed += 1


func _restore_disk_state() -> void:
	if _had_save_before:
		var f := FileAccess.open("user://ashen_oath_save.json", FileAccess.WRITE)
		if f != null:
			f.store_buffer(_prior_save_bytes)
			f.close()
	elif FileAccess.file_exists("user://ashen_oath_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ashen_oath_save.json"))


func _tick_physics(frames: int) -> void:
	for _i in range(maxi(1, frames)):
		await physics_frame


func _spawn_arena(class_id: String, zone_id: String = "fringe", diff: int = 0, seed_val: int = 1337) -> CombatDirector:
	var arena := _arena_scene.instantiate() as CombatDirector
	root.add_child(arena)
	arena.start_run(class_id, zone_id, diff, seed_val)
	return arena


func _teardown_arena(arena: CombatDirector) -> void:
	if arena != null and is_instance_valid(arena):
		root.remove_child(arena)
		arena.free()
	await process_frame
	await process_frame


func _clear_enemies(arena: CombatDirector) -> void:
	for child in arena.actors_root.get_children():
		if child is EnemyController3D:
			arena.actors_root.remove_child(child)
			child.free()
	arena._enemies.clear()
	for i in range(arena._clearings.size()):
		var cl: Dictionary = arena._clearings[i]
		cl["activated"] = true
		cl["cleared"] = false
		arena._clearings[i] = cl


func _run_all() -> void:
	var ad: Node = root.get_node_or_null("AudioDirector")
	var gs: Node = root.get_node_or_null("GameState")
	if ad == null:
		var ad_script := load("res://scripts/audio_director.gd") as GDScript
		ad = ad_script.new()
		ad.name = "AudioDirector"
		root.add_child(ad)
	if gs == null:
		var gs_script := load("res://scripts/core/game_state.gd") as GDScript
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)

	gs.call("reset_to_fresh", false)
	_arena_scene = load("res://scenes/combat/arena_run.tscn") as PackedScene
	_check(_arena_scene != null, "arena_run.tscn loads cleanly")

	await _test_move_while_attacking_all_classes(gs)
	await _test_all_six_class_skills_and_affixes(gs)
	await _test_dash_iframes_and_ward(gs)
	await _test_enemy_zero_instant_contact_damage_and_boss_enrage(gs)
	await _test_dark_shrine_and_boss_victory_flow(gs)

	if ad != null and ad.has_method("_exit_tree"):
		ad.call("_exit_tree")
	root.remove_child(gs)
	gs.free()
	root.remove_child(ad)
	ad.free()
	_arena_scene = null
	await process_frame
	await process_frame

	_restore_disk_state()
	if _checks_failed > 0:
		printerr("FAILED %d assertions (%d passed)." % [_checks_failed, _checks_passed])
		quit(1)
		return
	print("Verified %d 3D combat assertions cleanly." % _checks_passed)
	print("ALL UNIT 2B COMBAT TESTS PASSED")
	quit(0)


func _test_move_while_attacking_all_classes(gs: Node) -> void:
	for cid in ["oathbreaker", "battlemage", "revenant"]:
		gs.call("reset_to_fresh", false)
		var arena := _spawn_arena(cid, "fringe", GameEnums.Difficulty.NORMAL, 2026)
		_clear_enemies(arena)

		var cam := arena.get_camera()
		_check(cam != null and is_equal_approx(cam.fov, 42.0), "%s camera FOV is 42 deg" % cid)

		arena.hero.global_position = Vector3(0.0, 0.0, 10.0)
		var dummy_dist := 4.5 if cid == "battlemage" else 1.8
		var dummy := arena.spawn_enemy_at("stone_gargoyle", Vector3(0.0, 0.0, 10.0 - dummy_dist), false, -1, false)
		dummy.max_hp = 2000.0
		dummy.current_hp = 2000.0
		dummy.move_speed = 0.0
		dummy.attack_damage = 0.0

		var rec := {"hits": 0, "max_speed_on_hit": 0.0}
		var hero_ref := arena.hero
		arena.hero.dealt_damage.connect(func(_t: Node3D, ev: DamageEvent) -> void:
			if ev != null and ev.final_damage > 0.0:
				rec["hits"] = int(rec["hits"]) + 1
				var spd := Vector2(hero_ref.velocity.x, hero_ref.velocity.z).length()
				if spd > float(rec["max_speed_on_hit"]):
					rec["max_speed_on_hit"] = spd
		)

		for step in range(42):
			var angle := float(step) * 0.14
			var orbit_pos := dummy.global_position + Vector3(cos(angle) * dummy_dist, 0.0, sin(angle) * dummy_dist)
			var tangent := Vector2(-sin(angle), cos(angle)).normalized()
			var pull := Vector2(orbit_pos.x - hero_ref.global_position.x, orbit_pos.z - hero_ref.global_position.z)
			arena.set_virtual_move((tangent + pull * 0.5).normalized())
			await physics_frame

		_check(int(rec["hits"]) >= 1, "%s dealt primary attack damage while moving" % cid)
		_check(float(rec["max_speed_on_hit"]) > 2.0, "%s velocity.length() > 2.0 during active attack (got %.2f)" % [cid, float(rec["max_speed_on_hit"])])
		_check(dummy.current_hp < 2000.0, "%s reduced target HP while weaving" % cid)

		await _teardown_arena(arena)


func _test_all_six_class_skills_and_affixes(gs: Node) -> void:
	gs.call("reset_to_fresh", false)

	var arena_oath := _spawn_arena("oathbreaker", "fringe", GameEnums.Difficulty.NORMAL, 3001)
	_clear_enemies(arena_oath)
	arena_oath.hero.auto_attack_enabled = false
	arena_oath.hero.global_position = Vector3(0.0, 0.0, 12.0)
	arena_oath.hero.stats.spark_burn_dps = 24.0
	arena_oath.hero.stats.crit_chance = 1.0
	arena_oath.hero.stats.crit_shockwave_damage = 35.0
	arena_oath.hero.stats.life_on_hit = 10.0
	arena_oath.hero.current_hp = arena_oath.hero.stats.max_hp - 30.0

	var e1 := arena_oath.spawn_enemy_at("stone_gargoyle", Vector3(1.8, 0.0, 12.0), false, -1, false)
	var e2 := arena_oath.spawn_enemy_at("stone_gargoyle", Vector3(3.2, 0.0, 12.0), false, -1, false)
	for e in [e1, e2]:
		e.max_hp = 1500.0
		e.current_hp = 1500.0
		e.move_speed = 0.0

	var hp_before_lifesteal := arena_oath.hero.current_hp
	arena_oath.set_virtual_move(Vector2(0.0, -1.0))
	_check(arena_oath.press_skill_1(), "Oathbreaker iron_tempest triggers")
	_check(arena_oath.hero.skill_1_cooldown_left > 0.0, "iron_tempest goes on cooldown")
	await _tick_physics(22)
	_check(e1.current_hp < 1500.0 and e2.current_hp < 1500.0, "iron_tempest + crit_shockwave damaged nearby foes")
	_check(Vector2(arena_oath.hero.velocity.x, arena_oath.hero.velocity.z).length() > arena_oath.hero.stats.move_speed * 1.03, "iron_tempest moves at ~110% speed")
	_check(arena_oath.hero.current_hp > hp_before_lifesteal, "life_on_hit restored hero HP")
	_check(e1._burn_timer > 0.0, "spark_burn_dps applied burning DoT")

	arena_oath.set_virtual_move(Vector2.ZERO)
	arena_oath.hero._whirlwind_timer = 0.0
	_clear_enemies(arena_oath)
	arena_oath.hero.global_position = Vector3(0.0, 0.0, 12.0)
	var charge_target := arena_oath.spawn_enemy_at("stone_gargoyle", Vector3(0.0, 0.0, 5.0), false, -1, false)
	charge_target.max_hp = 1500.0
	charge_target.current_hp = 1500.0
	charge_target.move_speed = 0.0
	_check(arena_oath.press_skill_2(), "Oathbreaker bulwark_charge triggers")
	_check(arena_oath.hero.skill_2_cooldown_left > 0.0, "bulwark_charge goes on cooldown")
	await _tick_physics(18)
	_check(charge_target.current_hp < 1500.0, "bulwark_charge dealt slam damage")
	_check(charge_target.state == EnemyController3D.State.STAGGER, "bulwark_charge staggered target")

	_clear_enemies(arena_oath)
	var aura_target := arena_oath.spawn_enemy_at("hollow_ghoul", arena_oath.hero.global_position + Vector3(2.0, 0.0, 0.0), false, -1, false)
	aura_target.max_hp = 500.0
	aura_target.current_hp = 500.0
	aura_target.move_speed = 0.0
	aura_target.attack_damage = 0.0
	await _tick_physics(35)
	_check(aura_target.current_hp < 500.0, "Ember Gold lantern_aura_dps pulsed radiant burn damage")
	await _teardown_arena(arena_oath)

	var arena_mage := _spawn_arena("battlemage", "fringe", GameEnums.Difficulty.NORMAL, 3002)
	_clear_enemies(arena_mage)
	arena_mage.hero.auto_attack_enabled = false
	arena_mage.hero.global_position = Vector3(0.0, 0.0, 12.0)
	arena_mage.hero.stats.chain_bonus_targets = 1

	var cluster: Array[EnemyController3D] = []
	for k in range(5):
		var ce := arena_mage.spawn_enemy_at("stone_gargoyle", Vector3(-2.0 + float(k) * 1.1, 0.0, 6.0), false, -1, false)
		ce.max_hp = 1200.0
		ce.current_hp = 1200.0
		ce.move_speed = 0.0
		cluster.append(ce)

	_check(arena_mage.press_skill_1(), "Battlemage blackflame_pyre triggers")
	_check(arena_mage.hero.skill_1_cooldown_left > 0.0, "blackflame_pyre goes on cooldown")
	var hp_after_blast := cluster[2].current_hp
	_check(hp_after_blast < 1200.0, "blackflame_pyre dealt initial AoE blast damage")
	await _tick_physics(34)
	_check(cluster[2].current_hp < hp_after_blast, "blackflame_pyre ground zone dealt burning tick damage")

	var pre_arc_hps: Array[float] = []
	for ce in cluster:
		pre_arc_hps.append(ce.current_hp)
	_check(arena_mage.press_skill_2(), "Battlemage stormbrand_arc triggers")
	_check(arena_mage.hero.skill_2_cooldown_left > 0.0, "stormbrand_arc goes on cooldown")
	var chained_hits := 0
	for k in range(cluster.size()):
		if cluster[k].current_hp < pre_arc_hps[k]:
			chained_hits += 1
	_check(chained_hits == 5, "stormbrand_arc chained across 4 + 1 chain_bonus_targets enemies (got %d)" % chained_hits)

	var bolt_t1 := arena_mage.spawn_enemy_at("stone_gargoyle", Vector3(0.0, 0.0, 8.0), false, -1, false)
	var bolt_t2 := arena_mage.spawn_enemy_at("stone_gargoyle", Vector3(2.2, 0.0, 7.5), false, -1, false)
	for bt in [bolt_t1, bolt_t2]:
		bt.max_hp = 800.0
		bt.current_hp = 800.0
		bt.move_speed = 0.0
	for ce in cluster:
		ce.kill_silently()
	arena_mage.hero._attack_cooldown = 0.0
	arena_mage.press_attack(true)
	await _tick_physics(2)
	arena_mage.press_attack(false)
	await _tick_physics(26)
	_check(bolt_t1.current_hp < 800.0 and bolt_t2.current_hp < 800.0, "War-Staff primary bolt ricocheted via chain_bonus_targets")
	await _teardown_arena(arena_mage)

	var arena_rev := _spawn_arena("revenant", "fringe", GameEnums.Difficulty.NORMAL, 3003)
	_clear_enemies(arena_rev)
	arena_rev.hero.auto_attack_enabled = false
	arena_rev.hero.global_position = Vector3(0.0, 0.0, 12.0)
	arena_rev.hero.current_hp = 100.0

	var rev_t1 := arena_rev.spawn_enemy_at("stone_gargoyle", Vector3(-1.2, 0.0, 9.5), false, -1, false)
	var rev_t2 := arena_rev.spawn_enemy_at("stone_gargoyle", Vector3(1.2, 0.0, 9.5), false, -1, false)
	for rt in [rev_t1, rev_t2]:
		rt.max_hp = 1200.0
		rt.current_hp = 1200.0
		rt.move_speed = 0.0

	_check(arena_rev.press_skill_1(), "Revenant reaping_sweep triggers")
	_check(arena_rev.hero.skill_1_cooldown_left > 0.0, "reaping_sweep goes on cooldown")
	_check(rev_t1.current_hp < 1200.0 and rev_t2.current_hp < 1200.0, "reaping_sweep cleaved wide front arc")
	_check(arena_rev.hero.current_hp > 100.0, "reaping_sweep healed missing HP per enemy hit")
	var post_sweep_hp := rev_t1.current_hp
	await _tick_physics(34)
	_check(rev_t1.current_hp < post_sweep_hp, "reaping_sweep bleed DoT dealt tick damage")

	var line_targets: Array[EnemyController3D] = []
	for idx in range(3):
		var lt := arena_rev.spawn_enemy_at("stone_gargoyle", Vector3(0.0, 0.0, 8.5 - float(idx) * 2.0), false, -1, false)
		lt.max_hp = 1200.0
		lt.current_hp = 1200.0
		lt.move_speed = 0.0
		line_targets.append(lt)

	_check(arena_rev.press_skill_2(), "Revenant wraith_lances triggers")
	_check(arena_rev.hero.skill_2_cooldown_left > 0.0, "wraith_lances goes on cooldown")
	_check(arena_rev.projectiles_root.get_child_count() == 5, "wraith_lances spawned 5 spectral lance projectiles")
	await _tick_physics(28)
	_check(line_targets[0].current_hp < 1200.0 and line_targets[1].current_hp < 1200.0 and line_targets[2].current_hp < 1200.0, "wraith_lances pierced through 3 lined-up enemies")
	await _teardown_arena(arena_rev)


func _test_dash_iframes_and_ward(gs: Node) -> void:
	gs.call("reset_to_fresh", false)
	var arena := _spawn_arena("oathbreaker", "fringe", GameEnums.Difficulty.NORMAL, 4001)
	_clear_enemies(arena)
	arena.hero.auto_attack_enabled = false
	arena.hero.stats.ward_on_dash_hp = 45.0

	var hp_start := arena.hero.current_hp
	_check(arena.press_dash(), "Dash triggered")
	_check(arena.hero.is_invulnerable(), "Dash grants i-frames immediately")
	_check(is_equal_approx(arena.hero.ward_hp, 45.0), "Dash grants ward_on_dash_hp")
	_check(arena.hero.dash_cooldown_left > 0.0, "Dash enters cooldown")

	var incoming_during_iframe := DamageEvent.make_enemy_hit(null, 60.0, "test_strike")
	arena.hero.receive_damage(incoming_during_iframe)
	_check(incoming_during_iframe.negated_by_iframe, "Enemy hit negated during dash i-frames")
	_check(is_equal_approx(arena.hero.current_hp, hp_start), "Hero HP unchanged during dash i-frames")
	_check(is_equal_approx(arena.hero.ward_hp, 45.0), "Ward HP untouched when i-frame negates attack")

	await _tick_physics(20)
	_check(not arena.hero.is_invulnerable(), "Dash i-frames expire after 0.26s")
	var incoming_after_iframe := DamageEvent.make_enemy_hit(null, 30.0, "test_post_iframe")
	arena.hero.receive_damage(incoming_after_iframe)
	_check(incoming_after_iframe.absorbed_ward > 0.0, "Ward shield absorbed damage after i-frames ended")
	_check(is_equal_approx(arena.hero.current_hp, hp_start), "Ward shield protected HP pool completely")

	await _teardown_arena(arena)


func _test_enemy_zero_instant_contact_damage_and_boss_enrage(gs: Node) -> void:
	gs.call("reset_to_fresh", false)
	var arena := _spawn_arena("oathbreaker", "fringe", GameEnums.Difficulty.VETERAN, 5001)
	_clear_enemies(arena)
	arena.hero.auto_attack_enabled = false
	arena.hero.global_position = Vector3(0.0, 0.0, 10.0)
	var start_hp := arena.hero.current_hp

	var ghoul := arena.spawn_enemy_at("hollow_ghoul", Vector3(0.0, 0.0, 9.6), false, -1, false)
	ghoul.state = EnemyController3D.State.CHASE

	await _tick_physics(12)
	_check(is_equal_approx(arena.hero.current_hp, start_hp), "Zero instant contact damage during overlap & windup telegraph")
	_check(ghoul.state == EnemyController3D.State.WINDUP, "Enemy is in WINDUP state during telegraph window")

	await _tick_physics(20)
	_check(arena.hero.current_hp < start_hp, "Enemy deals melee damage ONLY after windup telegraph elapses")

	for arch_id in ["crypt_batlord", "ash_scorpion", "stone_gargoyle"]:
		_clear_enemies(arena)
		arena.hero.current_hp = arena.hero.stats.max_hp
		var spawn_z := 3.0 if arch_id == "crypt_batlord" else 8.2
		var mob := arena.spawn_enemy_at(arch_id, Vector3(0.0, 0.0, spawn_z), false, -1, false)
		mob.state = EnemyController3D.State.CHASE
		await _tick_physics(6)
		_check(is_equal_approx(arena.hero.current_hp, arena.hero.stats.max_hp), "%s deals zero instant contact damage" % arch_id)
		_check(mob.state == EnemyController3D.State.WINDUP, "%s enters telegraphed WINDUP" % arch_id)

	_clear_enemies(arena)
	arena.hero.global_position = Vector3(0.0, 0.0, -40.0)
	arena.hero.current_hp = arena.hero.stats.max_hp
	var boss := arena.spawn_boss_encounter()
	var base_troll := GameRegistry.get_enemy("barrow_troll")
	_check(is_equal_approx(boss.max_hp, base_troll.max_hp * 1.45), "Veteran difficulty scales Boss HP by 1.45x")
	_check(not boss.is_enraged, "Boss starts unenraged")

	var enrage_hit := DamageEvent.make_hero_hit(arena.hero, boss.max_hp * 0.50, "test_burst", DamageEvent.Kind.PHYSICAL, false)
	boss.receive_damage(enrage_hit)
	_check(boss.is_enraged, "Boss enrages at <= 55% HP")
	var alive := arena.get_alive_enemies()
	_check(alive.size() == 4, "Boss enrage summoned 3 hollow_ghoul adds (1 boss + 3 adds = 4)")

	for e in alive:
		if e != boss:
			e.kill_silently()

	boss._boss_move_index = 2
	boss.state = EnemyController3D.State.CHASE
	boss.global_position = Vector3(0.0, 0.0, -48.0)
	arena.hero.global_position = Vector3(0.0, 0.0, -39.0)
	arena.hero.grant_iframes(5.0)
	await _tick_physics(90)
	_check(arena.projectiles_root.get_child_count() >= 5, "Enraged Boss charge finishes with 5-projectile dark-ember fan")

	await _teardown_arena(arena)


func _test_dark_shrine_and_boss_victory_flow(gs: Node) -> void:
	gs.call("reset_to_fresh", false)
	var gold_before := int(gs.get("gold"))
	var inv_before := (gs.get("inventory") as Array).size()

	var arena := _spawn_arena("revenant", "fringe", GameEnums.Difficulty.NORMAL, 6001)
	_clear_enemies(arena)
	arena.hero.auto_attack_enabled = false

	var shrine_events := {"offered": 0, "choices": []}
	arena.shrine_offered.connect(func(choices: Array[ShrineBlessingDef]) -> void:
		shrine_events["offered"] = int(shrine_events["offered"]) + 1
		shrine_events["choices"] = choices
	)

	var dmg_before_shrine := arena.hero.stats.attack_damage
	arena.hero.current_hp = arena.hero.stats.max_hp * 0.50
	var hp_before_shrine := arena.hero.current_hp

	arena.hero.global_position = arena.dark_shrine.global_position + Vector3(1.0, 0.0, 0.0)
	await _tick_physics(3)
	_check(int(shrine_events["offered"]) == 1, "Approaching Dark Shrine within 2.8m emits shrine_offered")
	_check((shrine_events["choices"] as Array).size() == 3, "Dark Shrine offers 3 unique blessings")
	_check(arena.is_shrine_open, "Dark Shrine pauses arena combat while choosing")

	_check(arena.apply_shrine_choice("cinder_covenant"), "apply_shrine_choice succeeds")
	_check(not arena.is_shrine_open, "apply_shrine_choice resumes combat")
	_check(arena.hero.stats.attack_damage > dmg_before_shrine, "Dark Shrine blessing immediately updates hero.stats")
	_check(arena.hero.current_hp > hp_before_shrine, "Dark Shrine heals 25% HP")

	for i in range(arena._clearings.size()):
		var cl: Dictionary = arena._clearings[i]
		cl["activated"] = true
		cl["cleared"] = true
		arena._clearings[i] = cl
	arena._check_clearings_progress()
	_check(not bool(arena.arena_layout.get("boss_gate_locked", true)), "Clearing waves 0-2 unlocks Boss Gate")

	var completion := {"fired": false, "victory": false, "summary": {}}
	arena.run_completed.connect(func(victory: bool, summary: Dictionary) -> void:
		completion["fired"] = true
		completion["victory"] = victory
		completion["summary"] = summary
	)

	arena.hero.global_position = Vector3(0.0, 0.0, -34.5)
	await _tick_physics(3)
	_check(arena.active_boss != null and not arena.active_boss.is_dead(), "Crossing z < -33.0 triggers Zone Guardian Boss")

	var lethal := DamageEvent.make_hero_hit(arena.hero, arena.active_boss.max_hp + 500.0, "coup_de_grace", DamageEvent.Kind.PHYSICAL, true)
	arena.active_boss.receive_damage(lethal)
	_check(arena.active_boss.is_dead(), "Zone Guardian Boss defeated")
	_check(arena.drops_root.get_child_count() >= 7, "Boss death spawned gold shower + EquipmentItem drops")

	await _tick_physics(55)
	_check(bool(completion["fired"]) and bool(completion["victory"]), "run_completed(true, summary) emitted after Boss defeat")
	var summary: Dictionary = completion["summary"]
	var dropped_items: Array = summary.get("items_dropped", [])
	_check(int(summary.get("gold_earned", 0)) > 0, "Boss run summary earned gold > 0")
	_check(dropped_items.size() >= 2 and dropped_items.size() <= 4, "Boss guaranteed 2..4 EquipmentItem drops (got %d)" % dropped_items.size())

	var has_rare_plus := false
	for item_v in dropped_items:
		if item_v is EquipmentItem and int((item_v as EquipmentItem).rarity) >= int(GameEnums.Rarity.RARE):
			has_rare_plus = true
	_check(has_rare_plus, "Boss drops include at least 1 RARE+ EquipmentItem")

	_check(int(gs.get("gold")) > gold_before, "Victory gold committed to GameState")
	_check((gs.get("inventory") as Array).size() >= inv_before + 2, "Victory EquipmentItems committed to GameState inventory")
	_check(int((gs.get("run_stats") as Dictionary).get("victories", 0)) == 1, "Victory recorded in GameState.run_stats")
	_check(bool(gs.call("is_zone_unlocked", "weald")), "Clearing fringe unlocked weald in GameState")

	await _teardown_arena(arena)
