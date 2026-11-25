extends SceneTree

var _out_dir: String = ""
var _checks_passed: int = 0
var _checks_failed: int = 0
var _had_save_before: bool = false
var _prior_save_bytes: PackedByteArray = PackedByteArray()


func _init() -> void:
	var user_args := OS.get_cmdline_user_args()
	_out_dir = str(user_args[0]).strip_edges() if (not user_args.is_empty() and str(user_args[0]).strip_edges() != "") else ProjectSettings.globalize_path("user://ui_shots")
	_had_save_before = FileAccess.file_exists("user://ashen_oath_save.json")
	if _had_save_before:
		_prior_save_bytes = FileAccess.get_file_as_bytes("user://ashen_oath_save.json")
	DirAccess.make_dir_recursive_absolute(_out_dir)


func _initialize() -> void:
	call_deferred("_run_gate4")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_checks_failed += 1
		printerr("GATE 4 FAIL: ", msg)
		push_error("GATE 4 FAIL: " + msg)
		return
	_checks_passed += 1


func _restore_save() -> void:
	if _had_save_before:
		var f := FileAccess.open("user://ashen_oath_save.json", FileAccess.WRITE)
		if f != null:
			f.store_buffer(_prior_save_bytes)
			f.close()
	elif FileAccess.file_exists("user://ashen_oath_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ashen_oath_save.json"))


func _wait_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame
		await RenderingServer.frame_post_draw


func _capture_viewport_image() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != 720 or img.get_height() != 1280:
		img.resize(720, 1280, Image.INTERPOLATE_LANCZOS)
	return img


func _run_gate4() -> void:
	root.content_scale_size = Vector2i(720, 1280)

	var ad := root.get_node_or_null("AudioDirector")
	if ad == null:
		ad = (load("res://scripts/audio_director.gd") as GDScript).new()
		ad.name = "AudioDirector"
		root.add_child(ad)

	var gs := root.get_node_or_null("GameState")
	if gs == null:
		gs = (load("res://scripts/core/game_state.gd") as GDScript).new()
		gs.name = "GameState"
		root.add_child(gs)

	gs.call("reset_to_fresh", false)
	await _wait_frames(2)

	for cid in ["oathbreaker", "battlemage", "revenant"]:
		_check(UiThemeBuilder.get_portrait(cid) != null, "Baked hero portrait loaded: " + cid)
	for eid in ["hollow_ghoul", "crypt_batlord", "ash_scorpion", "stone_gargoyle", "dread_golem", "infernal_minotaur", "barrow_troll", "blight_werewolf"]:
		_check(UiThemeBuilder.get_portrait(eid) != null, "Baked enemy portrait loaded: " + eid)
	for ikey in ["zweihander", "halberd", "bastardsword", "blade_oarimaar", "runed_staff", "shield_round", "shield_heater", "shield_tower", "helm_iron", "helm_plume", "cuirass_plate", "waist_lantern"]:
		_check(UiThemeBuilder.get_item_icon_by_key(ikey) != null, "Baked item icon loaded: " + ikey)

	var shell_ps := load("res://scenes/ui/main_shell.tscn") as PackedScene
	_check(shell_ps != null, "main_shell.tscn loads cleanly")
	var shell := shell_ps.instantiate() as MainShell
	root.add_child(shell)
	await _wait_frames(4)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var showcase_helm := LootEngine.forge_item(rng, GameEnums.Slot.HELM, 3)
	var showcase_cuirass := LootEngine.forge_item(rng, GameEnums.Slot.CUIRASS, 3)
	var showcase_sword := LootEngine.forge_item(rng, GameEnums.Slot.WEAPON, 3, GameEnums.WeaponType.GREATSWORD)
	gs.call("add_item_to_inventory", showcase_helm)
	gs.call("add_item_to_inventory", showcase_cuirass)
	gs.call("add_item_to_inventory", showcase_sword)
	gs.call("equip_item", "oathbreaker", showcase_helm.uid)
	gs.call("equip_item", "oathbreaker", showcase_cuirass.uid)
	gs.call("equip_item", "oathbreaker", showcase_sword.uid)
	gs.set("inventory", [] as Array[EquipmentItem])

	gs.set("unlocked_zones", ["fringe", "weald", "catacombs"] as Array[String])
	gs.set("cleared_zones", {"fringe": [0, 1], "weald": [0]})
	gs.set("gold", 840)
	gs.set("scrap", 96)
	gs.call("select_zone", "weald")
	gs.call("select_difficulty", GameEnums.Difficulty.VETERAN)
	shell.refresh_header()
	shell.hunt_tab.refresh_ui()
	await _wait_frames(6)

	var embark_rect := shell.hunt_tab.embark_btn.get_global_rect()
	var nav_rect := shell.nav_panel.get_global_rect()
	_check(embark_rect.end.y <= nav_rect.position.y + 1.0, "Embark CTA fits cleanly above bottom dock without overlap")

	var shot1 := await _capture_viewport_image()
	shot1.save_png(_out_dir.path_join("01_sanctum_hunt_tab.png"))
	print("Saved 01_sanctum_hunt_tab.png")

	shell.nav_armory_btn.pressed.emit()
	await _wait_frames(3)

	var granted: Array[EquipmentItem] = []
	var rarities := [
		GameEnums.Rarity.SOVEREIGN,
		GameEnums.Rarity.EPIC,
		GameEnums.Rarity.RARE,
		GameEnums.Rarity.EPIC,
		GameEnums.Rarity.RARE,
		GameEnums.Rarity.COMMON,
	]
	var slots := [
		GameEnums.Slot.WEAPON,
		GameEnums.Slot.HELM,
		GameEnums.Slot.CUIRASS,
		GameEnums.Slot.LANTERN,
		GameEnums.Slot.WEAPON,
		GameEnums.Slot.CUIRASS,
	]
	for i in range(6):
		var item := LootEngine.roll_item(
			rng,
			4 if i == 0 else 3,
			GameEnums.Difficulty.NIGHTMARE,
			[GameEnums.WeaponType.GREATSWORD, GameEnums.WeaponType.SWORD_SHIELD],
			rarities[i]
		)
		item.slot = slots[i]
		if item.slot == GameEnums.Slot.WEAPON:
			item.weapon_type = GameEnums.WeaponType.GREATSWORD if i == 0 else GameEnums.WeaponType.SWORD_SHIELD
			item.base_id = GameRegistry.get_weapon_by_type_and_tier(item.weapon_type, item.tier).weapon_id
		elif item.slot == GameEnums.Slot.HELM:
			item.base_id = "helm_t%d" % item.tier
			item.has_plume = true
		elif item.slot == GameEnums.Slot.CUIRASS:
			item.base_id = "cuirass_t%d" % item.tier
		elif item.slot == GameEnums.Slot.LANTERN:
			item.base_id = "lantern_t%d" % item.tier
			item.lantern_aspect = GameEnums.LanternAspect.BLOOD_CRIMSON
		gs.call("add_item_to_inventory", item)
		granted.append(item)

	shell.armory_tab.select_item_uid(showcase_sword.uid)
	shell.armory_tab.temper_btn.pressed.emit()
	_check(showcase_sword.temper_level == 1, "Armory temper button upgraded weapon to +1")

	shell.armory_tab.select_item_uid(granted[0].uid)
	await _wait_frames(5)

	var left_rect := shell.armory_tab.left_sockets_box.get_global_rect()
	var stage_rect := shell.armory_tab.stage_3d.get_global_rect()
	var right_rect := shell.armory_tab.right_sockets_box.get_global_rect()
	_check(left_rect.end.x <= stage_rect.position.x + 1.0, "Left sockets do not overlap 3D Sanctuary stage")
	_check(stage_rect.end.x <= right_rect.position.x + 1.0, "Right sockets do not overlap 3D Sanctuary stage")

	var shot2 := await _capture_viewport_image()
	shot2.save_png(_out_dir.path_join("02_armory_tab.png"))
	print("Saved 02_armory_tab.png")

	shell.nav_forge_btn.pressed.emit()
	gs.set("unlocked_zones", ["fringe", "weald", "catacombs", "rift"] as Array[String])
	gs.set("gold", 2400)
	gs.set("scrap", 380)
	shell.forge_tab.set_subview(false)
	shell.forge_tab.set_forge_selection(GameEnums.Slot.WEAPON, 4, GameEnums.WeaponType.GREATSWORD)

	var forged_pick: EquipmentItem = null
	for attempt in range(18):
		gs.set("gold", 2400)
		gs.set("scrap", 380)
		var candidate := shell.forge_tab.trigger_forge()
		if candidate != null and int(candidate.rarity) >= int(GameEnums.Rarity.EPIC):
			forged_pick = candidate
			break
		if candidate != null:
			forged_pick = candidate
	_check(forged_pick != null, "Soul Forge created targeted Greatsword relic")
	await _wait_frames(4)
	var shot_forge := await _capture_viewport_image()

	for pair in [
		["barrow_troll", 4],
		["blight_werewolf", 2],
		["dread_golem", 1],
		["hollow_ghoul", 64],
		["crypt_batlord", 31],
		["ash_scorpion", 22],
		["stone_gargoyle", 15],
	]:
		for _c in range(int(pair[1])):
			UiThemeBuilder.record_bestiary_kill(gs, str(pair[0]))

	shell.forge_tab.bestiary_toggle_btn.pressed.emit()
	await _wait_frames(4)
	_check(shell.forge_tab.bestiary_list.get_child_count() == 8, "Bestiary renders all 8 monsters & guardian bosses")
	var shot_bestiary := await _capture_viewport_image()

	var pair_img := Image.create(1440, 1280, false, Image.FORMAT_RGBA8)
	pair_img.blit_rect(shot_forge, Rect2i(0, 0, 720, 1280), Vector2i(0, 0))
	pair_img.blit_rect(shot_bestiary, Rect2i(0, 0, 720, 1280), Vector2i(720, 0))
	pair_img.save_png(_out_dir.path_join("03_forge_and_bestiary.png"))
	print("Saved 03_forge_and_bestiary.png")

	shell.nav_sanctum_btn.pressed.emit()
	gs.call("select_zone", "fringe")
	gs.call("select_difficulty", GameEnums.Difficulty.VETERAN)
	await _wait_frames(2)

	var arena := shell.start_expedition("oathbreaker", "fringe", int(GameEnums.Difficulty.VETERAN), 2026)
	_check(arena != null and shell.active_hud != null, "MainShell mounted ArenaRun + CombatHud")
	var hud := shell.active_hud
	await _wait_frames(6)

	var boss := arena.spawn_boss_encounter()
	_check(boss != null, "Guardian boss spawned in arena")
	if arena.hero != null:
		arena.hero.global_position = boss.global_position + Vector3(0.0, 0.0, 3.2)
		arena._snap_camera_to_hero()
		arena.hero.ward_hp = 65.0
		arena.collected_gold = 148
		arena.press_skill_1()
	boss.current_hp = boss.max_hp * 0.68
	boss.is_enraged = true
	arena.boss_updated.emit(boss.enemy_def.display_name, boss.enemy_def.title, boss.current_hp, boss.max_hp, true)
	arena.hud_updated.emit(arena.get_hud_state())

	await _wait_frames(4)
	arena.damage_floated.emit(boss.global_position + Vector3(-0.4, 0.6, 0.0), 184, true, false, false)
	arena.damage_floated.emit(boss.global_position + Vector3(0.7, 0.3, 0.2), 76, false, false, false)
	if arena.hero != null:
		arena.damage_floated.emit(arena.hero.global_position + Vector3(0.2, 0.4, 0.0), 22, false, true, false)
	await _wait_frames(3)

	_check(hud.boss_panel.visible, "Guardian Boss HP bar visible during boss fight")
	_check(hud.floaters_layer.get_child_count() >= 2, "Floating 2D damage numbers active on HUD")

	var shot4 := await _capture_viewport_image()
	shot4.save_png(_out_dir.path_join("04_live_combat_hud.png"))
	print("Saved 04_live_combat_hud.png")

	var shrine_choices := GameRegistry.roll_shrine_choices(arena.rng, 3)
	arena._on_shrine_triggered(shrine_choices)
	await _wait_frames(4)
	_check(hud.shrine_modal.visible and arena.is_shrine_open, "Dark Shrine modal opened and paused combat AI")
	_check(hud.shrine_choices_box.get_child_count() == 3, "Dark Shrine displays 3 blessing cards")

	var shot5 := await _capture_viewport_image()
	shot5.save_png(_out_dir.path_join("05_dark_shrine_modal.png"))
	print("Saved 05_dark_shrine_modal.png")

	var first_blessing_btn := hud.shrine_choices_box.get_child(0) as Button
	first_blessing_btn.pressed.emit()
	await _wait_frames(2)
	_check(not hud.shrine_modal.visible and not arena.is_shrine_open, "Picking Dark Shrine card resumes combat")
	_check(arena.hero.active_blessings.size() == 1, "Chosen Dark Shrine blessing applied to hero")

	hud.open_pause_modal()
	_check(hud.pause_modal.visible and paused, "Pause modal pauses SceneTree")
	hud.pause_lefty_toggle.button_pressed = true
	hud.pause_lefty_toggle.button_pressed = false
	hud.close_pause_modal()
	_check(not hud.pause_modal.visible and not paused, "Closing Pause modal unpauses SceneTree")

	arena.run_elapsed_sec = 84.5
	arena.enemies_slain = 18
	arena._on_enemy_died(boss)
	arena.finalize_pending_run()
	await _wait_frames(4)
	_check(hud.summary_modal.visible, "Victory summary modal opened upon boss defeat")
	_check(hud.summary_loot_list.get_child_count() >= 2, "Victory summary modal lists dropped relics")

	var shot6 := await _capture_viewport_image()
	shot6.save_png(_out_dir.path_join("06_victory_loot_modal.png"))
	print("Saved 06_victory_loot_modal.png")

	hud.summary_sanctum_btn.pressed.emit()
	await _wait_frames(3)
	_check(shell.active_arena == null and shell.active_hud == null and shell.hub_layer.visible, "Arena cleanly torn down on Return to Sanctum")

	shell.queue_free()
	await _wait_frames(2)
	if ad != null and ad.has_method("_exit_tree"):
		ad.call("_exit_tree")
	if gs != null and is_instance_valid(gs):
		root.remove_child(gs)
		gs.free()
	if ad != null and is_instance_valid(ad):
		root.remove_child(ad)
		ad.free()
	await create_timer(0.05).timeout
	_restore_save()

	if _checks_failed > 0:
		printerr("GATE 4 FAILED: %d failed, %d passed" % [_checks_failed, _checks_passed])
		quit(1)
		return

	print("GATE 4 PASSED: %d checks verified cleanly." % _checks_passed)
	quit(0)
