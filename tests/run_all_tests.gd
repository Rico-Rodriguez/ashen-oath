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
	call_deferred("_execute_suite")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_checks_failed += 1
		push_error("ASSERTION FAILED: %s" % msg)
		printerr("ASSERTION FAILED: %s" % msg)
		return
	_checks_passed += 1


func _tick_physics(frames: int) -> void:
	for _i in range(maxi(1, frames)):
		await physics_frame


func _restore_disk_state() -> void:
	if _had_save_before:
		var f := FileAccess.open("user://ashen_oath_save.json", FileAccess.WRITE)
		if f != null:
			f.store_buffer(_prior_save_bytes)
			f.close()
	elif FileAccess.file_exists("user://ashen_oath_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ashen_oath_save.json"))


func _spawn_arena(class_id: String, zone_id: String, diff: int, seed_val: int) -> CombatDirector:
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


func _clear_projectiles(arena: CombatDirector) -> void:
	for p in arena.projectiles_root.get_children():
		arena.projectiles_root.remove_child(p)
		p.free()


func _clear_enemies_and_projectiles(arena: CombatDirector, keep_boss: EnemyController3D = null) -> void:
	for child in arena.actors_root.get_children():
		if child is EnemyController3D and child != keep_boss:
			arena.actors_root.remove_child(child)
			child.free()
	arena._enemies.clear()
	if keep_boss != null and is_instance_valid(keep_boss):
		arena._enemies.append(keep_boss)
	_clear_projectiles(arena)
	for i in range(arena._clearings.size()):
		var cl: Dictionary = arena._clearings[i]
		cl["activated"] = true
		cl["cleared"] = true
		arena._clearings[i] = cl


func _execute_suite() -> void:
	Engine.physics_ticks_per_second = 360
	Engine.time_scale = 6.0
	var ad: Node = root.get_node_or_null("AudioDirector")
	var gs: Node = root.get_node_or_null("GameState")
	if ad == null:
		var ad_script: GDScript = load("res://scripts/audio_director.gd")
		ad = ad_script.new()
		ad.name = "AudioDirector"
		root.add_child(ad)
	if gs == null:
		var gs_script: GDScript = load("res://scripts/core/game_state.gd")
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)

	gs.reset_to_fresh(false)

	_test_audio_director(ad, gs)
	_test_registry_classes_weapons_zones_enemies()
	_test_loot_and_affixes()
	_test_all_eight_affixes_and_lanterns_and_blessings()
	_test_weapon_swap_and_economy_and_roundtrip(gs)

	await _test_all_four_zones_arena_builder()

	_arena_scene = load("res://scenes/combat/arena_run.tscn") as PackedScene
	_check(_arena_scene != null, "arena_run.tscn loads cleanly for boss suite")
	await _test_all_four_bosses_across_three_difficulties(gs)
	await _test_differentiated_boss_signature_mechanics(gs)
	_arena_scene = null

	if ad != null and ad.has_method("_exit_tree"):
		ad.call("_exit_tree")
	if gs != null and is_instance_valid(gs):
		root.remove_child(gs)
		gs.free()
	if ad != null and is_instance_valid(ad):
		root.remove_child(ad)
		ad.free()

	await process_frame
	await process_frame
	await process_frame

	var orphans := roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(orphans == 0, "Zero orphan nodes at suite teardown (got %d)" % orphans)

	_restore_disk_state()
	if _checks_failed > 0:
		printerr("FAILED %d assertions (%d passed)." % [_checks_failed, _checks_passed])
		quit(1)
		return
	print("Verified %d assertions cleanly." % _checks_passed)
	print("ALL ASHEN OATH REGRESSION & PHASE 5 TESTS PASSED")
	quit(0)


func _test_audio_director(ad: Node, gs: Node) -> void:
	_check(ad != null, "AudioDirector autoload present")
	_check(ad.EVENTS.has("blade_scrape"), "AudioDirector EVENTS includes blade_scrape")
	ad.refresh_variants()
	_check(ad._variants.size() >= 40, "AudioDirector scanned sfx variants from assets/audio/sfx")
	_check(int(ad._variants.get("swing", 0)) >= 1, "swing sfx variants detected")
	_check(int(ad._variants.get("hit", 0)) >= 1, "hit sfx variants detected")
	ad.sfx("blade_scrape")
	ad.sfx("swing")
	ad.set_setting("sfx_vol", 0.65)
	_check(is_equal_approx(float(ad.settings["sfx_vol"]), 0.65), "AudioDirector normalized sfx_vol")
	_check(is_equal_approx(float(gs.settings["sfx_vol"]), 0.65), "AudioDirector synced setting to GameState")


func _test_registry_classes_weapons_zones_enemies() -> void:
	var classes := GameRegistry.get_all_classes()
	_check(classes.size() == 3, "Exactly 3 playable classes")

	var oath := GameRegistry.get_class_def("oathbreaker")
	var mage := GameRegistry.get_class_def("battlemage")
	var rev := GameRegistry.get_class_def("revenant")
	_check(oath != null and oath.display_name == "Oathbreaker Knight", "Oathbreaker registered")
	_check(mage != null and mage.display_name == "Ashen Battlemage", "Battlemage registered")
	_check(rev != null and rev.display_name == "Dread Revenant", "Revenant registered")

	for c in classes:
		_check(c.actor_scene_path == "res://scenes/actors/heroes/%s.tscn" % c.class_id, "Hero actor path for %s" % c.class_id)
		_check(c.portrait_path == "res://assets/sprites/ui/portraits/%s.png" % c.class_id, "Hero portrait path for %s" % c.class_id)
		_check(c.skill_1 != null and c.skill_1.ability_id != "", "Hero skill_1 present for %s" % c.class_id)
		_check(c.skill_2 != null and c.skill_2.ability_id != "", "Hero skill_2 present for %s" % c.class_id)
		_check(c.dash_ability != null and c.dash_ability.ability_id != "", "Hero dash present for %s" % c.class_id)
		_check(GameRegistry.get_weapon(c.starter_weapon_id) != null, "Starter weapon valid for %s" % c.class_id)

	var weapons := GameRegistry.get_all_weapons()
	_check(weapons.size() == 16, "Exactly 16 weapons across 4 types x 4 tiers")

	for wt_idx in range(GameEnums.WeaponType.size()):
		var wt := wt_idx as GameEnums.WeaponType
		var prev_dmg := 0.0
		for t in range(1, 5):
			var w := GameRegistry.get_weapon_by_type_and_tier(wt, t)
			_check(w != null and w.tier == t and w.weapon_type == wt, "Weapon exists for type %d tier %d" % [wt_idx, t])
			_check(w.base_damage > prev_dmg, "Weapon damage scales upward with tier")
			prev_dmg = w.base_damage
			match wt:
				GameEnums.WeaponType.GREATSWORD:
					_check(w.drags_on_ground, "Greatsword drags on ground")
					_check(w.mesh_key == ("blade_oarimaar" if t == 4 else "zweihander"), "Greatsword mesh key")
					_check(is_equal_approx(w.cleave_arc_deg, 150.0), "Greatsword 150 deg arc")
				GameEnums.WeaponType.HALBERD:
					_check(w.drags_on_ground, "Halberd drags on ground")
					_check(w.mesh_key == "halberd", "Halberd mesh key")
					_check(is_equal_approx(w.range_m, 3.4), "Halberd 3.4m reach")
					_check(is_equal_approx(w.cleave_arc_deg, 125.0), "Halberd 125 deg sweep")
				GameEnums.WeaponType.SWORD_SHIELD:
					_check(not w.drags_on_ground, "Sword & Shield does not drag")
					_check(w.mesh_key == "bastardsword", "Sword & Shield mainhand key")
					var expected_shield := "shield_round" if t == 1 else ("shield_heater" if t == 2 else "shield_tower")
					_check(w.offhand_key == expected_shield, "Sword & Shield offhand key for tier %d" % t)
					_check(is_equal_approx(w.attack_interval, 0.48), "Sword & Shield 0.48s interval")
					_check(w.bonus_armor > 0.0, "Sword & Shield grants bonus armor")
				GameEnums.WeaponType.WAR_STAFF:
					_check(w.is_ranged and w.projectile_speed > 0.0, "War-Staff is ranged")
					_check(w.mesh_key == "runed_staff", "War-Staff mesh key")

	var zones := GameRegistry.get_all_zones()
	_check(zones.size() == 4, "Exactly 4 zones")
	var expected_zone_ids := ["fringe", "weald", "catacombs", "rift"]
	var expected_boss_ids := ["barrow_troll", "blight_werewolf", "dread_golem", "infernal_minotaur"]
	for i in range(4):
		var z := zones[i]
		_check(z.zone_id == expected_zone_ids[i], "Zone %d id matches" % i)
		_check(z.depth_index == i, "Zone depth index %d" % i)
		_check(z.max_drop_tier == i + 1, "Zone max_drop_tier %d" % (i + 1))
		_check(z.boss_id == expected_boss_ids[i], "Zone %d boss id matches" % i)
		_check(not z.enemy_pool.is_empty(), "Zone %d has enemy pool" % i)
		_check(GameRegistry.get_enemy(z.elite_id) != null, "Zone %d elite exists" % i)
		var boss := GameRegistry.get_enemy(z.boss_id)
		_check(boss != null and boss.is_boss and boss.archetype == GameEnums.EnemyArchetype.BOSS, "Zone %d boss valid" % i)

	var enemies := GameRegistry.get_all_enemies()
	_check(enemies.size() == 8, "Exactly 8 enemies/bosses total")
	_check(GameRegistry.get_regular_enemies().size() == 4, "4 regular/elite enemies")
	_check(GameRegistry.get_boss_enemies().size() == 4, "4 guardian bosses")
	for e in enemies:
		_check(e.actor_scene_path == "res://scenes/actors/enemies/%s.tscn" % e.enemy_id, "Enemy actor path for %s" % e.enemy_id)

	var blessings := GameRegistry.get_all_blessings()
	_check(blessings.size() == 6, "Exactly 6 Dark Shrine blessings")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var shrine_pick := GameRegistry.roll_shrine_choices(rng, 3)
	_check(shrine_pick.size() == 3, "Shrine rolls 3 choices")
	_check(shrine_pick[0].blessing_id != shrine_pick[1].blessing_id and shrine_pick[1].blessing_id != shrine_pick[2].blessing_id and shrine_pick[0].blessing_id != shrine_pick[2].blessing_id, "Shrine choices are unique")


func _test_loot_and_affixes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var saw_plume_t2_plus := false

	for i in range(180):
		var max_t := (i % 4) + 1
		var diff := (i % 3) as GameEnums.Difficulty
		var min_rar := GameEnums.Rarity.COMMON if i < 140 else GameEnums.Rarity.EPIC
		var item := LootEngine.roll_item(rng, max_t, diff, [GameEnums.WeaponType.GREATSWORD, GameEnums.WeaponType.HALBERD], min_rar)
		_check(item.tier >= 1 and item.tier <= max_t, "Rolled tier within max_tier")
		_check(int(item.rarity) >= int(min_rar), "Guaranteed min rarity respected")
		_check(item.affixes.size() == GameEnums.affix_count_for_rarity(item.rarity), "Affix count matches rarity")
		_check(item.display_name() != "", "Item display_name non-empty")

		var seen_kinds: Dictionary = {}
		for a in item.affixes:
			_check(not seen_kinds.has(a.kind), "Unique AffixKind per item")
			seen_kinds[a.kind] = true
			_check(a.value > 0.0 and a.format_line() != "", "Affix roll positive and formatted")

		if item.slot == GameEnums.Slot.WEAPON:
			_check(item.weapon_type == GameEnums.WeaponType.GREATSWORD or item.weapon_type == GameEnums.WeaponType.HALBERD, "Preferred weapons respected")
		if item.slot == GameEnums.Slot.HELM:
			if item.tier == 1:
				_check(not item.has_plume, "Tier 1 helm has no plume")
			elif item.has_plume:
				saw_plume_t2_plus = true

	_check(saw_plume_t2_plus, "Tier 2+ helms roll has_plume")

	var forged_helm := LootEngine.forge_item(rng, GameEnums.Slot.HELM, 3)
	_check(forged_helm.slot == GameEnums.Slot.HELM and forged_helm.tier == 3, "Forged helm slot and tier")
	_check(int(forged_helm.rarity) >= int(GameEnums.Rarity.RARE), "Forged item minimum RARE rarity")
	_check(forged_helm.has_plume, "Forged Tier 3 helm has plume")


func _test_all_eight_affixes_and_lanterns_and_blessings() -> void:
	var hero := GameRegistry.get_class_def("oathbreaker")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var base_kit: Dictionary = {
		GameEnums.Slot.WEAPON: LootEngine.make_starter_item(GameEnums.Slot.WEAPON, hero, rng),
		GameEnums.Slot.HELM: LootEngine.make_starter_item(GameEnums.Slot.HELM, hero, rng),
		GameEnums.Slot.CUIRASS: LootEngine.make_starter_item(GameEnums.Slot.CUIRASS, hero, rng),
		GameEnums.Slot.LANTERN: LootEngine.make_starter_item(GameEnums.Slot.LANTERN, hero, rng),
	}
	var base_stats := LootEngine.compute_combat_stats(hero, base_kit)

	for kind_idx in range(GameEnums.AffixKind.size()):
		var kind := kind_idx as GameEnums.AffixKind
		var test_val := 2.0 if kind == GameEnums.AffixKind.CHAIN_COUNT else (0.25 if kind in [GameEnums.AffixKind.CLEAVE_SIZE, GameEnums.AffixKind.COOLDOWN_HASTE, GameEnums.AffixKind.MOVE_SPEED] else 20.0)
		var mod_weapon := LootEngine.make_starter_item(GameEnums.Slot.WEAPON, hero, rng)
		mod_weapon.rarity = GameEnums.Rarity.RARE
		mod_weapon.affixes = [AffixRoll.new(kind, test_val)]
		var kit_copy := base_kit.duplicate()
		kit_copy[GameEnums.Slot.WEAPON] = mod_weapon
		var mod_stats := LootEngine.compute_combat_stats(hero, kit_copy)

		match kind:
			GameEnums.AffixKind.CLEAVE_SIZE:
				_check(mod_stats.cleave_size_mult > base_stats.cleave_size_mult, "CLEAVE_SIZE increases cleave_size_mult")
			GameEnums.AffixKind.SPARK_BURN:
				_check(mod_stats.spark_burn_dps > base_stats.spark_burn_dps, "SPARK_BURN increases spark_burn_dps")
			GameEnums.AffixKind.CHAIN_COUNT:
				_check(mod_stats.chain_bonus_targets == base_stats.chain_bonus_targets + 2, "CHAIN_COUNT increases chain_bonus_targets")
			GameEnums.AffixKind.LIFE_ON_HIT:
				_check(mod_stats.life_on_hit > base_stats.life_on_hit, "LIFE_ON_HIT increases life_on_hit")
			GameEnums.AffixKind.COOLDOWN_HASTE:
				_check(mod_stats.cooldown_scale < base_stats.cooldown_scale, "COOLDOWN_HASTE reduces cooldown_scale")
			GameEnums.AffixKind.CRIT_SHOCKWAVE:
				_check(mod_stats.crit_shockwave_damage > base_stats.crit_shockwave_damage, "CRIT_SHOCKWAVE increases crit_shockwave_damage")
			GameEnums.AffixKind.MOVE_SPEED:
				_check(mod_stats.move_speed > base_stats.move_speed, "MOVE_SPEED increases move_speed")
			GameEnums.AffixKind.WARD_ON_DASH:
				_check(mod_stats.ward_on_dash_hp > base_stats.ward_on_dash_hp, "WARD_ON_DASH increases ward_on_dash_hp")

	for aspect_idx in range(GameEnums.LanternAspect.size()):
		var aspect := aspect_idx as GameEnums.LanternAspect
		var lantern := LootEngine.make_starter_item(GameEnums.Slot.LANTERN, hero, rng)
		lantern.tier = 3
		lantern.lantern_aspect = aspect
		var l_kit := base_kit.duplicate()
		l_kit[GameEnums.Slot.LANTERN] = lantern
		var l_stats := LootEngine.compute_combat_stats(hero, l_kit)
		match aspect:
			GameEnums.LanternAspect.EMBER_GOLD:
				_check(l_stats.lantern_aura_dps > 0.0, "EMBER_GOLD grants burning aura DPS")
			GameEnums.LanternAspect.SOUL_BLUE:
				_check(l_stats.cooldown_scale < 1.0, "SOUL_BLUE grants cooldown haste")
			GameEnums.LanternAspect.BLIGHT_GREEN:
				_check(l_stats.life_on_hit > 0.0, "BLIGHT_GREEN grants life on hit")
			GameEnums.LanternAspect.BLOOD_CRIMSON:
				_check(l_stats.crit_chance > hero.base_crit and l_stats.crit_mult > 1.75, "BLOOD_CRIMSON grants crit chance & mult")

	var blessed_stats := LootEngine.compute_combat_stats(hero, base_kit, ["cinder_covenant", "iron_vow", "sovereign_wrath"])
	_check(blessed_stats.attack_damage > base_stats.attack_damage, "Shrine blessing boosts attack_damage")
	_check(blessed_stats.max_hp > base_stats.max_hp and blessed_stats.armor > base_stats.armor, "Shrine blessing boosts HP & armor")
	_check(blessed_stats.crit_shockwave_damage > 0.0 and blessed_stats.ward_on_dash_hp > 0.0, "Shrine blessings grant shockwave & ward")


func _test_weapon_swap_and_economy_and_roundtrip(gs: Node) -> void:
	gs.reset_to_fresh(false)
	var signals_seen := {"profile": 0, "class": 0, "equip": 0}
	var on_profile := func() -> void: signals_seen["profile"] += 1
	var on_class := func(_cid: String) -> void: signals_seen["class"] += 1
	var on_equip := func(_cid: String) -> void: signals_seen["equip"] += 1
	gs.profile_changed.connect(on_profile)
	gs.class_selected.connect(on_class)
	gs.equipment_changed.connect(on_equip)

	for cid in ["oathbreaker", "battlemage", "revenant"]:
		var eq: Dictionary = gs.get_equipped(cid)
		_check(eq.size() == 4, "Starter kit has 4 slots for %s" % cid)

	_check(gs.select_class("revenant") and gs.selected_class_id == "revenant", "select_class switches to revenant")
	_check(signals_seen["class"] == 1, "class_selected signal emitted")

	var oath_stats_initial: CombatStats = gs.get_combat_stats("oathbreaker")
	_check(oath_stats_initial.drags_on_ground and oath_stats_initial.weapon_mesh_key == "zweihander", "Oathbreaker starts with dragging zweihander")

	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var sns_item := LootEngine.forge_item(rng, GameEnums.Slot.WEAPON, 2, GameEnums.WeaponType.SWORD_SHIELD)
	var staff_item := LootEngine.forge_item(rng, GameEnums.Slot.WEAPON, 2, GameEnums.WeaponType.WAR_STAFF)
	gs.add_item_to_inventory(sns_item)
	gs.add_item_to_inventory(staff_item)

	_check(not gs.equip_item("oathbreaker", staff_item.uid), "Oathbreaker cannot equip War-Staff")
	_check(gs.equip_item("oathbreaker", sns_item.uid), "Oathbreaker equips Sword & Shield")
	_check(signals_seen["equip"] >= 1, "equipment_changed signal emitted")

	var oath_stats_sns: CombatStats = gs.get_combat_stats("oathbreaker")
	_check(not oath_stats_sns.drags_on_ground, "Sword & Shield disables drags_on_ground")
	_check(oath_stats_sns.weapon_mesh_key == "bastardsword" and oath_stats_sns.offhand_mesh_key == "shield_heater", "Sword & Shield updates mainhand & offhand mesh keys")
	_check(oath_stats_sns.armor > oath_stats_initial.armor, "Sword & Shield increases armor")

	_check(gs.equip_item("battlemage", staff_item.uid), "Battlemage equips War-Staff")
	var mage_stats: CombatStats = gs.get_combat_stats("battlemage")
	_check(mage_stats.is_ranged and mage_stats.weapon_mesh_key == "runed_staff", "Battlemage War-Staff stats active")

	gs.gold = 3500
	gs.scrap = 300
	var pre_gold: int = gs.gold
	var pre_scrap: int = gs.scrap
	var forged_t3: EquipmentItem = gs.forge_targeted(GameEnums.Slot.WEAPON, 3, GameEnums.WeaponType.GREATSWORD)
	_check(forged_t3 != null, "forge_targeted succeeds with sufficient funds")
	var cost_t3 := LootEngine.forge_cost(3)
	_check(gs.gold == pre_gold - int(cost_t3["gold"]) and gs.scrap == pre_scrap - int(cost_t3["scrap"]), "forge_targeted deducts exact gold & scrap")
	_check(int(forged_t3.rarity) >= int(GameEnums.Rarity.RARE) and forged_t3.tier == 3, "Forged T3 greatsword valid")

	var saved_gold_for_temper: int = gs.gold
	gs.gold = 0
	_check(not gs.temper_item(forged_t3.uid), "Temper fails with insufficient gold")
	_check(gs.forge_targeted(GameEnums.Slot.HELM, 2) == null, "forge_targeted fails with insufficient gold")
	gs.gold = saved_gold_for_temper

	var base_power := forged_t3.power_score()
	for lvl in range(1, 6):
		var g_before: int = gs.gold
		var step_cost := forged_t3.temper_gold_cost()
		_check(gs.temper_item(forged_t3.uid), "Temper step %d succeeds" % lvl)
		_check(forged_t3.temper_level == lvl, "Temper level updated to %d" % lvl)
		_check(gs.gold == g_before - step_cost, "Temper step %d deducted exact gold" % lvl)
	_check(is_equal_approx(forged_t3.temper_multiplier(), 1.40), "Max temper multiplier is 1.40")
	_check(forged_t3.power_score() > base_power, "Tempering increases power_score")
	_check(not gs.temper_item(forged_t3.uid), "Cannot temper past level 5")

	_check(gs.salvage_item(sns_item.uid) == 0, "Cannot salvage currently equipped item")
	var inv_before: int = gs.inventory.size()
	var scrap_before: int = gs.scrap
	var expected_scrap := forged_t3.salvage_scrap_value()
	var gained_scrap: int = gs.salvage_item(forged_t3.uid)
	_check(gained_scrap == expected_scrap and gained_scrap > 0, "Salvage returns exact scrap value")
	_check(gs.scrap == scrap_before + expected_scrap, "Salvage adds scrap to profile")
	_check(gs.inventory.size() == inv_before - 1, "Salvaged item removed from inventory")

	var boss_drop := LootEngine.roll_item(rng, 2, GameEnums.Difficulty.VETERAN, [GameEnums.WeaponType.HALBERD], GameEnums.Rarity.SOVEREIGN)
	gs.record_run_victory("fringe", GameEnums.Difficulty.VETERAN, 320, [boss_drop])
	_check(gs.is_zone_unlocked("weald"), "Clearing fringe unlocks weald")
	_check(int(gs.run_stats["victories"]) == 1, "Victory recorded")
	_check(gs.get_item(boss_drop.uid) != null, "Boss drop added to inventory")

	var defeat_drop := LootEngine.roll_item(rng, 1, GameEnums.Difficulty.NORMAL, [GameEnums.WeaponType.GREATSWORD], GameEnums.Rarity.RARE)
	gs.record_run_defeat(45, [defeat_drop])
	_check(int(gs.run_stats["defeats"]) == 1 and int(gs.run_stats["runs_played"]) == 2, "Defeat recorded")

	var expected_gold: int = gs.gold
	var expected_scrap_final: int = gs.scrap
	var expected_inv_count: int = gs.inventory.size()
	var expected_oath_dmg: float = gs.get_combat_stats("oathbreaker").attack_damage

	var json_text := JSON.stringify(gs.to_dict())
	var parsed: Variant = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "Save dictionary serializes cleanly to JSON")

	gs.reset_to_fresh(false)
	_check(gs.selected_class_id == "oathbreaker" and not gs.is_zone_unlocked("weald"), "Fresh reset clears state")

	gs.load_from_dict(parsed, false)
	_check(gs.selected_class_id == "revenant", "Roundtrip preserved selected_class_id")
	_check(gs.gold == expected_gold and gs.scrap == expected_scrap_final, "Roundtrip preserved gold and scrap")
	_check(gs.inventory.size() == expected_inv_count, "Roundtrip preserved inventory count")
	_check(gs.is_zone_unlocked("weald"), "Roundtrip preserved unlocked zones")
	_check(gs.cleared_zones.get("fringe", []).has(int(GameEnums.Difficulty.VETERAN)), "Roundtrip preserved cleared zone difficulty")
	var restored_drop: EquipmentItem = gs.get_item(boss_drop.uid)
	_check(restored_drop != null and restored_drop.rarity == GameEnums.Rarity.SOVEREIGN and restored_drop.affixes.size() == 3, "Roundtrip preserved Sovereign item & affixes")
	_check(is_equal_approx(gs.get_combat_stats("oathbreaker").attack_damage, expected_oath_dmg), "Roundtrip preserved equipped combat stats")

	gs.profile_changed.disconnect(on_profile)
	gs.class_selected.disconnect(on_class)
	gs.equipment_changed.disconnect(on_equip)


func _test_all_four_zones_arena_builder() -> void:
	var baseline_nodes := roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var seen_fog_colors: Array[Color] = []

	for zid in ["fringe", "weald", "catacombs", "rift"]:
		var zdef := GameRegistry.get_zone(zid)
		_check(zdef != null, "ZoneDef exists for %s" % zid)

		var stage := Node3D.new()
		stage.name = "Stage_" + zid
		var arena_parent := Node3D.new()
		arena_parent.name = "ArenaParent"
		stage.add_child(arena_parent)
		root.add_child(stage)

		var layout := BarrowArenaBuilder.build_zone(arena_parent, zdef, 4242)
		_check(str(layout.get("biome_id", "")) == zid, "BarrowArenaBuilder built biome_id %s" % zid)
		_check((layout.get("spawn_pos") as Vector3).is_equal_approx(BarrowArenaBuilder.SPAWN_POS), "%s spawn_pos matches contract" % zid)
		_check((layout.get("shrine_pos") as Vector3).is_equal_approx(BarrowArenaBuilder.SHRINE_POS), "%s shrine_pos matches contract" % zid)
		_check(is_equal_approx(float(layout.get("boss_gate_z", 0.0)), BarrowArenaBuilder.BOSS_GATE_Z), "%s boss_gate_z matches contract" % zid)
		_check(bool(layout.get("boss_gate_locked", false)), "%s boss_gate starts locked" % zid)

		var clearings: Array = layout.get("clearings", [])
		_check(clearings.size() == 3, "%s has 3 clearings" % zid)
		for c_idx in range(clearings.size()):
			var cl: Dictionary = clearings[c_idx]
			var sp: Array = cl.get("spawn_points", [])
			_check(sp.size() == 6 + c_idx, "%s clearing %d has %d spawn points" % [zid, c_idx, 6 + c_idx])

		var we := arena_parent.get_node_or_null("BarrowWorldEnvironment") as WorldEnvironment
		_check(we != null and we.environment != null, "%s created isolated WorldEnvironment" % zid)
		if we != null and we.environment != null:
			var fog_c := we.environment.fog_light_color
			for prev_c in seen_fog_colors:
				_check(not fog_c.is_equal_approx(prev_c), "%s has distinct atmospheric fog color" % zid)
			seen_fog_colors.append(fog_c)

		var ground_body := arena_parent.get_node_or_null("BarrowGroundBody") as StaticBody3D
		var gate_node := arena_parent.get_node_or_null("BossGate") as Node3D
		_check(ground_body != null and gate_node != null, "%s created ground physics body and BossGate" % zid)
		_check(arena_parent.get_node_or_null("RiftEmberAshVfx") == null, "%s guards GPU ember particles in headless mode" % zid)

		var blocked := BarrowArenaBuilder.clamp_position(Vector3(0.0, 0.0, -45.0), layout)
		_check(blocked.z >= -31.25, "%s locked gate clamps z >= -31.2" % zid)

		var unlock_cb := layout.get("unlock_boss_gate") as Callable
		_check(unlock_cb.is_valid(), "%s unlock_boss_gate callable valid" % zid)
		unlock_cb.call()
		_check(not bool(layout.get("boss_gate_locked", true)), "%s unlock_boss_gate unlocks layout flag" % zid)

		var unblocked := BarrowArenaBuilder.clamp_position(Vector3(0.0, 0.0, -45.0), layout)
		_check(is_equal_approx(unblocked.z, -45.0), "%s unlocked gate permits boss sanctum entry" % zid)

		layout.clear()
		root.remove_child(stage)
		stage.free()
		await process_frame
		await process_frame

		var orphans := roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		_check(orphans == 0, "%s build & teardown left 0 orphan nodes" % zid)

	var post_nodes := roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check(post_nodes == baseline_nodes, "All 4 zone builds returned node count cleanly to baseline (%d == %d)" % [post_nodes, baseline_nodes])


func _test_all_four_bosses_across_three_difficulties(gs: Node) -> void:
	var zone_boss_pairs := [
		{"zone": "fringe", "boss": "barrow_troll"},
		{"zone": "weald", "boss": "blight_werewolf"},
		{"zone": "catacombs", "boss": "dread_golem"},
		{"zone": "rift", "boss": "infernal_minotaur"},
	]
	var diffs: Array[GameEnums.Difficulty] = [
		GameEnums.Difficulty.NORMAL,
		GameEnums.Difficulty.VETERAN,
		GameEnums.Difficulty.NIGHTMARE,
	]

	var seed_idx := 7100
	for pair in zone_boss_pairs:
		var zid: String = pair["zone"]
		var bid: String = pair["boss"]
		var edef := GameRegistry.get_enemy(bid)

		for diff in diffs:
			seed_idx += 1
			gs.reset_to_fresh(false)
			var arena := _spawn_arena("oathbreaker", zid, int(diff), seed_idx)
			_clear_enemies_and_projectiles(arena)
			arena.hero.auto_attack_enabled = false
			arena._unlock_boss_gate()

			var scales := EnemyController3D.difficulty_multipliers(diff)
			arena.hero.global_position = Vector3(0.0, 0.0, -42.0)
			var boss := arena.spawn_boss_encounter()
			_check(boss != null and boss.enemy_def.enemy_id == bid, "%s [%s] spawned cleanly" % [bid, GameEnums.difficulty_name(diff)])
			_check(is_equal_approx(boss.max_hp, edef.max_hp * float(scales["hp"])), "%s [%s] max_hp scaled accurately" % [bid, GameEnums.difficulty_name(diff)])
			_check(is_equal_approx(boss.attack_damage, edef.damage * float(scales["dmg"])), "%s [%s] attack_damage scaled accurately" % [bid, GameEnums.difficulty_name(diff)])
			_check(boss.gold_reward == roundi(float(edef.gold_drop) * float(scales["gold"])), "%s [%s] gold_reward scaled accurately" % [bid, GameEnums.difficulty_name(diff)])

			arena.hero.current_hp = arena.hero.stats.max_hp
			var start_hp := arena.hero.current_hp
			boss.global_position = arena.hero.global_position + Vector3(0.0, 0.0, -0.35)
			boss.state = EnemyController3D.State.CHASE

			await _tick_physics(4)
			_check(is_equal_approx(arena.hero.current_hp, start_hp), "%s [%s] deals zero frame-0 contact damage on overlap" % [bid, GameEnums.difficulty_name(diff)])
			_check(boss.state == EnemyController3D.State.WINDUP, "%s [%s] enters telegraphed WINDUP before executing" % [bid, GameEnums.difficulty_name(diff)])
			_check(boss._active_telegraphs.size() >= 1 or boss._pending_eruptions.size() >= 1, "%s [%s] spawns telegraph decal during WINDUP" % [bid, GameEnums.difficulty_name(diff)])

			arena.hero.grant_iframes(25.0)
			await _tick_physics(135)
			_check(boss.signature_exec_counts.size() >= 1, "%s [%s] executed normal-phase signature moves" % [bid, GameEnums.difficulty_name(diff)])

			var enrage_dmg := DamageEvent.make_hero_hit(arena.hero, boss.max_hp * 0.48, "enrage_push", DamageEvent.Kind.PHYSICAL, false)
			boss.receive_damage(enrage_dmg)
			_check(boss.is_enraged, "%s [%s] triggers Enrage at <= 55%% HP" % [bid, GameEnums.difficulty_name(diff)])

			var summoned_count := 0
			for alive_e in arena.get_alive_enemies():
				if alive_e != boss and alive_e.is_boss_summon:
					summoned_count += 1
					alive_e.kill_silently()
			_check(summoned_count >= 3, "%s [%s] Enrage summoned pack adds (got %d)" % [bid, GameEnums.difficulty_name(diff), summoned_count])

			await _tick_physics(150)
			_check(boss.signature_exec_counts.size() >= 2, "%s [%s] cycled multiple signature moves across normal & Enrage" % [bid, GameEnums.difficulty_name(diff)])

			await _teardown_arena(arena)
			var orphans := roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
			_check(orphans == 0, "%s [%s] teardown left 0 orphan nodes" % [bid, GameEnums.difficulty_name(diff)])


func _test_differentiated_boss_signature_mechanics(gs: Node) -> void:
	gs.reset_to_fresh(false)

	var arena_troll := _spawn_arena("oathbreaker", "fringe", GameEnums.Difficulty.NORMAL, 8101)
	_clear_enemies_and_projectiles(arena_troll)
	arena_troll.hero.auto_attack_enabled = false
	arena_troll._unlock_boss_gate()
	arena_troll.hero.global_position = Vector3(0.0, 0.0, -41.5)
	var troll := arena_troll.spawn_boss_encounter()
	troll.global_position = Vector3(0.0, 0.0, -45.0)
	troll._boss_move_index = 0
	troll.state = EnemyController3D.State.CHASE
	var hp_pre := arena_troll.hero.current_hp
	await _tick_physics(65)
	_check(int(troll.signature_exec_counts.get("troll_seismic_slam", 0)) >= 1, "Gravemaw executed 115 deg seismic slam")
	_check(arena_troll.hero.current_hp < hp_pre, "Gravemaw seismic slam damaged hero after telegraph")

	arena_troll.hero.current_hp = arena_troll.hero.stats.max_hp
	hp_pre = arena_troll.hero.current_hp
	troll._boss_move_index = 1
	troll.state = EnemyController3D.State.CHASE
	await _tick_physics(4)
	_check(troll._pending_eruptions.size() == 3, "Gravemaw scheduled 3 staggered boulder/tremor circles")
	await _tick_physics(90)
	_check(arena_troll.hero.current_hp < hp_pre, "Gravemaw staggered boulder tremors damaged stationary hero")

	var troll_proj_counter := {"count": 0}
	arena_troll.projectiles_root.child_entered_tree.connect(func(_n: Node) -> void:
		troll_proj_counter["count"] = int(troll_proj_counter["count"]) + 1
	)
	troll.receive_damage(DamageEvent.make_hero_hit(arena_troll.hero, troll.max_hp * 0.50, "enrage", DamageEvent.Kind.PHYSICAL, false))
	_clear_enemies_and_projectiles(arena_troll, troll)
	arena_troll.hero.grant_iframes(5.0)
	troll._boss_move_index = 2
	troll.state = EnemyController3D.State.CHASE
	troll.global_position = Vector3(0.0, 0.0, -49.0)
	arena_troll.hero.global_position = Vector3(0.0, 0.0, -39.0)
	await _tick_physics(100)
	_check(int(troll.signature_exec_counts.get("troll_bull_charge", 0)) >= 1, "Gravemaw executed bull charge")
	_check(int(troll_proj_counter["count"]) >= 5, "Enraged Gravemaw fired 5-ember spread after charge (got %d)" % int(troll_proj_counter["count"]))
	await _teardown_arena(arena_troll)

	var arena_wolf := _spawn_arena("oathbreaker", "weald", GameEnums.Difficulty.NORMAL, 8102)
	_clear_enemies_and_projectiles(arena_wolf)
	arena_wolf.hero.auto_attack_enabled = false
	arena_wolf._unlock_boss_gate()
	arena_wolf.hero.grant_iframes(10.0)
	arena_wolf.hero.global_position = Vector3(0.0, 0.0, -40.0)
	var wolf := arena_wolf.spawn_boss_encounter()
	wolf.global_position = Vector3(0.0, 0.0, -47.5)
	wolf._boss_move_index = 0
	wolf.state = EnemyController3D.State.CHASE
	await _tick_physics(125)
	_check(int(wolf.signature_exec_counts.get("werewolf_double_pounce", 0)) >= 2, "Nightmaw chained 2 back-to-back telegraphed pounces")

	_clear_enemies_and_projectiles(arena_wolf, wolf)
	var wolf_proj_counter := {"count": 0}
	arena_wolf.projectiles_root.child_entered_tree.connect(func(_n: Node) -> void:
		wolf_proj_counter["count"] = int(wolf_proj_counter["count"]) + 1
	)
	wolf.global_position = Vector3(0.0, 0.0, -45.0)
	arena_wolf.hero.global_position = Vector3(0.0, 0.0, -41.2)
	wolf._boss_move_index = 1
	wolf.state = EnemyController3D.State.CHASE
	await _tick_physics(55)
	_check(int(wolf.signature_exec_counts.get("werewolf_claw_blight_fan", 0)) >= 1, "Nightmaw executed 130 deg venomous claw rend")
	_check(int(wolf_proj_counter["count"]) == 5, "Nightmaw claw rend fired 5 blood_orb blight projectiles (got %d)" % int(wolf_proj_counter["count"]))

	_clear_projectiles(arena_wolf)
	arena_wolf.hero._iframe_timer = 0.0
	arena_wolf.hero.current_hp = arena_wolf.hero.stats.max_hp
	hp_pre = arena_wolf.hero.current_hp
	arena_wolf.hero.global_position = Vector3(3.5, 0.0, -41.0)
	wolf.global_position = Vector3(-3.5, 0.0, -48.0)
	wolf._boss_move_index = 2
	wolf.state = EnemyController3D.State.CHASE
	await _tick_physics(10)
	_check(is_equal_approx(arena_wolf.hero.current_hp, hp_pre), "Nightmaw shadow leap deals zero damage during windup")
	await _tick_physics(60)
	_check(int(wolf.signature_exec_counts.get("werewolf_shadow_leap", 0)) >= 1, "Nightmaw executed shadow leap circle slam")
	_check(Vector2(wolf.global_position.x - 3.5, wolf.global_position.z - (-41.0)).length() < 0.6, "Nightmaw shadow leap landed onto hero target position")
	_check(arena_wolf.hero.current_hp < hp_pre, "Nightmaw shadow leap slam damaged stationary hero on landing")
	await _teardown_arena(arena_wolf)

	var arena_golem := _spawn_arena("oathbreaker", "catacombs", GameEnums.Difficulty.NORMAL, 8103)
	_clear_enemies_and_projectiles(arena_golem)
	arena_golem.hero.auto_attack_enabled = false
	arena_golem._unlock_boss_gate()
	arena_golem.hero.global_position = Vector3(0.0, 0.0, -39.0)
	var golem := arena_golem.spawn_boss_encounter()
	golem.global_position = Vector3(0.0, 0.0, -45.0)
	golem._boss_move_index = 0
	golem.state = EnemyController3D.State.CHASE
	arena_golem.hero.current_hp = arena_golem.hero.stats.max_hp
	hp_pre = arena_golem.hero.current_hp
	await _tick_physics(54)
	_check(int(golem.signature_exec_counts.get("golem_concentric_ring", 0)) >= 1, "Obsidian Warden executed inner concentric slam")
	_check(is_equal_approx(arena_golem.hero.current_hp, hp_pre), "Hero at 6.0m avoided 3.6m inner concentric slam")
	await _tick_physics(35)
	_check(arena_golem.hero.current_hp < hp_pre, "Hero at 6.0m hit by delayed 4.5m..8.0m outer concentric ring")

	_clear_projectiles(arena_golem)
	var golem_proj_counter := {"count": 0}
	arena_golem.projectiles_root.child_entered_tree.connect(func(_n: Node) -> void:
		golem_proj_counter["count"] = int(golem_proj_counter["count"]) + 1
	)
	arena_golem.hero.grant_iframes(10.0)
	arena_golem.hero.global_position = Vector3(0.0, 0.0, -36.0)
	golem.global_position = Vector3(0.0, 0.0, -45.0)
	golem._boss_move_index = 1
	golem.state = EnemyController3D.State.CHASE
	await _tick_physics(56)
	_check(int(golem_proj_counter["count"]) == 8, "Obsidian Warden fired 8-way Crystalline Nova (got %d)" % int(golem_proj_counter["count"]))

	_clear_projectiles(arena_golem)
	golem_proj_counter["count"] = 0
	golem.receive_damage(DamageEvent.make_hero_hit(arena_golem.hero, golem.max_hp * 0.50, "enrage", DamageEvent.Kind.PHYSICAL, false))
	_clear_enemies_and_projectiles(arena_golem, golem)
	golem.global_position = Vector3(0.0, 0.0, -45.0)
	arena_golem.hero.global_position = Vector3(0.0, 0.0, -34.5)
	golem._boss_move_index = 1
	golem.state = EnemyController3D.State.CHASE
	await _tick_physics(75)
	_check(int(golem_proj_counter["count"]) == 16, "Enraged Obsidian Warden fired 8 + 8 rotated Crystalline Nova volleys (got %d)" % int(golem_proj_counter["count"]))
	await _teardown_arena(arena_golem)

	var arena_bull := _spawn_arena("oathbreaker", "rift", GameEnums.Difficulty.NORMAL, 8104)
	_clear_enemies_and_projectiles(arena_bull)
	arena_bull.hero.auto_attack_enabled = false
	arena_bull._unlock_boss_gate()
	arena_bull.hero.grant_iframes(15.0)
	arena_bull.hero.global_position = Vector3(0.0, 0.0, -38.0)
	var bull := arena_bull.spawn_boss_encounter()
	bull.global_position = Vector3(0.0, 0.0, -50.0)
	bull._boss_move_index = 0
	bull.state = EnemyController3D.State.CHASE
	await _tick_physics(95)
	_check(int(bull.signature_exec_counts.get("minotaur_hellfire_stampede", 0)) >= 1, "Khorvath executed 14m Hellfire Stampede")
	_check(bull._boss_stampede_pyres_spawned == 3, "Khorvath Hellfire Stampede left 3 blackflame pyre pillars along its wake")

	await _tick_physics(30)
	arena_bull.hero._iframe_timer = 0.0
	arena_bull.hero.current_hp = arena_bull.hero.stats.max_hp
	hp_pre = arena_bull.hero.current_hp
	bull.global_position = Vector3(0.0, 0.0, -45.0)
	var flank_angle := deg_to_rad(62.0)
	arena_bull.hero.global_position = Vector3(sin(flank_angle) * 4.4, 0.0, -45.0 + cos(flank_angle) * 4.4)
	bull._boss_move_index = 1
	bull.state = EnemyController3D.State.CHASE
	bull._locked_dir = Vector3(0.0, 0.0, 1.0)
	await _tick_physics(62)
	_check(int(bull.signature_exec_counts.get("minotaur_executioner_cleave", 0)) >= 1, "Khorvath executed 150 deg Executioner Cleave")
	_check(arena_bull.hero.current_hp < hp_pre, "Khorvath 150 deg Executioner Cleave hit wide-flank target within 5.6m")

	arena_bull.hero.grant_iframes(10.0)
	bull.global_position = Vector3(0.0, 0.0, -47.0)
	arena_bull.hero.global_position = Vector3(0.0, 0.0, -39.0)
	bull._boss_move_index = 2
	bull.state = EnemyController3D.State.CHASE
	await _tick_physics(4)
	_check(bull._pending_eruptions.size() == 5, "Khorvath scheduled 5-Circle Hellfire Meteor Barrage")
	await _tick_physics(95)
	_check(int(bull.signature_exec_counts.get("minotaur_meteor_barrage", 0)) >= 1, "Khorvath completed Hellfire Meteor Barrage")
	await _teardown_arena(arena_bull)
