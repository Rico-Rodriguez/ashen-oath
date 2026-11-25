extends SceneTree

const WARMUP_FRAMES := 30
const BENCH_FRAMES := 180
const MAX_AVG_MS := 8.0

var _showcase_out_path: String = ""
var _had_save_before: bool = false
var _prior_save_bytes: PackedByteArray = PackedByteArray()
var _arena_scene: PackedScene = null


func _init() -> void:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty() and str(user_args[0]).strip_edges() != "":
		var arg := str(user_args[0]).strip_edges()
		_showcase_out_path = arg if arg.to_lower().ends_with(".png") else arg.path_join("phase5_zones_bosses.png")
	else:
		_showcase_out_path = ProjectSettings.globalize_path("user://shots").path_join("phase5_zones_bosses.png")
	_had_save_before = FileAccess.file_exists("user://ashen_oath_save.json")
	if _had_save_before:
		_prior_save_bytes = FileAccess.get_file_as_bytes("user://ashen_oath_save.json")


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.msaa_2d = Viewport.MSAA_DISABLED
	call_deferred("_run_showcase_and_benchmark")


func _restore_disk_state() -> void:
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


func _teardown_arena(arena: CombatDirector) -> void:
	if arena != null and is_instance_valid(arena):
		root.remove_child(arena)
		arena.free()
	await _wait_frames(3)


func _equip_hero_tier(arena: CombatDirector, tier: int, wtype: GameEnums.WeaponType, aspect: GameEnums.LanternAspect) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + tier * 37
	var weapon := LootEngine.forge_item(rng, GameEnums.Slot.WEAPON, tier, wtype)
	weapon.rarity = GameEnums.Rarity.SOVEREIGN if tier >= 4 else GameEnums.Rarity.EPIC
	var helm := LootEngine.forge_item(rng, GameEnums.Slot.HELM, tier)
	helm.has_plume = tier >= 2
	var cuirass := LootEngine.forge_item(rng, GameEnums.Slot.CUIRASS, tier)
	var lantern := LootEngine.forge_item(rng, GameEnums.Slot.LANTERN, tier)
	lantern.lantern_aspect = aspect
	var kit := {
		GameEnums.Slot.WEAPON: weapon,
		GameEnums.Slot.HELM: helm,
		GameEnums.Slot.CUIRASS: cuirass,
		GameEnums.Slot.LANTERN: lantern,
	}
	arena.hero.equipped_items = kit
	var blessings: Array[String] = ["cinder_covenant", "storm_conduit", "sovereign_wrath"]
	arena.hero.active_blessings = blessings
	var new_stats := LootEngine.compute_combat_stats(arena.class_def, kit, blessings)
	arena.hero.refresh_combat_stats(new_stats, 1.0)


func _run_showcase_and_benchmark() -> void:
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

	await _wait_frames(1)
	gs.call("reset_to_fresh", false)
	ad.set("settings", {"music_on": false, "sfx_on": false, "haptics_on": false, "music_vol": 0.0, "sfx_vol": 0.0, "screen_shake": 1.0, "reduce_flashing": false, "damage_numbers": true, "text_size": 100, "left_handed": false})

	_arena_scene = load("res://scenes/combat/arena_run.tscn") as PackedScene
	if _arena_scene == null:
		printerr("FATAL: Failed to load res://scenes/combat/arena_run.tscn")
		_restore_disk_state()
		quit(1)
		return

	var showcase_ok := await _capture_four_zone_showcase()
	if not showcase_ok:
		printerr("FATAL: Failed to capture 2x2 zone/boss showcase")
		_restore_disk_state()
		quit(1)
		return

	var bench_ok := await _run_rift_peak_stress_benchmark()

	if ad != null and ad.has_method("_exit_tree"):
		ad.call("_exit_tree")
	if gs != null and is_instance_valid(gs):
		root.remove_child(gs)
		gs.free()
	if ad != null and is_instance_valid(ad):
		root.remove_child(ad)
		ad.free()
	_arena_scene = null
	await _wait_frames(3)
	_restore_disk_state()

	if not bench_ok:
		quit(1)
		return
	quit(0)


func _capture_four_zone_showcase() -> bool:
	var specs := [
		{
			"zone": "fringe",
			"class_id": "oathbreaker",
			"tier": 2,
			"wtype": GameEnums.WeaponType.GREATSWORD,
			"aspect": GameEnums.LanternAspect.EMBER_GOLD,
			"title": "I. THE BLIGHTED FRINGE",
			"sub": "Gravemaw, Barrow Troll  |  115° Seismic Slam & Boulder Tremors",
			"accent": Color(0.96, 0.68, 0.30),
		},
		{
			"zone": "weald",
			"class_id": "revenant",
			"tier": 3,
			"wtype": GameEnums.WeaponType.HALBERD,
			"aspect": GameEnums.LanternAspect.BLIGHT_GREEN,
			"title": "II. THE WEEPING WEALD",
			"sub": "Nightmaw, Blight Stalker  |  Double-Pounce & Venomous Blight Fan",
			"accent": Color(0.50, 0.96, 0.46),
		},
		{
			"zone": "catacombs",
			"class_id": "battlemage",
			"tier": 3,
			"wtype": GameEnums.WeaponType.WAR_STAFF,
			"aspect": GameEnums.LanternAspect.SOUL_BLUE,
			"title": "III. THE SUNKEN CATACOMBS",
			"sub": "Obsidian Warden  |  Concentric Arcane Ring & 8-Way Crystal Nova",
			"accent": Color(0.46, 0.72, 1.0),
		},
		{
			"zone": "rift",
			"class_id": "oathbreaker",
			"tier": 4,
			"wtype": GameEnums.WeaponType.GREATSWORD,
			"aspect": GameEnums.LanternAspect.BLOOD_CRIMSON,
			"title": "IV. THE ASHEN RIFT",
			"sub": "Khorvath, Ashen Bull  |  Hellfire Stampede & Blackflame Pyres",
			"accent": Color(1.0, 0.42, 0.20),
		},
	]

	var tile_w := 720
	var tile_h := 920
	var border := 6
	var canvas_w := tile_w * 2 + border * 3
	var canvas_h := tile_h * 2 + border * 3
	var atlas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.05, 0.05, 0.07, 1.0))

	for idx in range(specs.size()):
		var sp: Dictionary = specs[idx]
		var zid: String = sp["zone"]
		var arena := _arena_scene.instantiate() as CombatDirector
		root.add_child(arena)
		arena.start_run(str(sp["class_id"]), zid, GameEnums.Difficulty.VETERAN, 5100 + idx * 17)
		_equip_hero_tier(arena, int(sp["tier"]), sp["wtype"] as GameEnums.WeaponType, sp["aspect"] as GameEnums.LanternAspect)

		for child in arena.actors_root.get_children():
			if child is EnemyController3D:
				arena.actors_root.remove_child(child)
				child.free()
		arena._enemies.clear()
		arena._unlock_boss_gate()

		var hero := arena.hero
		hero.auto_attack_enabled = false
		hero.grant_iframes(30.0)
		hero.global_position = Vector3(-1.75, 0.0, -39.4)
		var boss_pos := Vector3(1.15, 0.0, -45.6)
		var to_boss := (boss_pos - hero.global_position).normalized()
		hero.rotation.y = atan2(-to_boss.x, -to_boss.z)

		var boss := arena.spawn_boss_encounter()
		boss.global_position = boss_pos
		var to_hero := (hero.global_position - boss_pos).normalized()
		boss.rotation.y = atan2(-to_hero.x, -to_hero.z)

		await _wait_frames(3)
		arena.set_physics_process(false)
		hero.set_physics_process(false)
		boss.set_physics_process(false)

		if hero.visual != null:
			hero.visual.play_anim("attack", 0.6, true)
		if boss.visual != null:
			boss.visual.play_anim("attack2" if zid in ["weald", "rift"] else "attack", 0.5, true)

		_stage_boss_signature_vfx(arena, boss, hero, zid, to_hero)

		var overlay := _build_panel_overlay(str(sp["title"]), str(sp["sub"]), sp["accent"] as Color)
		arena.add_child(overlay)

		var cam := arena.get_camera()
		cam.fov = 48.0
		cam.current = true
		cam.look_at_from_position(Vector3(-4.1, 5.2, -32.2), Vector3(0.35, 1.55, -45.6), Vector3.UP)

		await _wait_frames(12)
		await RenderingServer.frame_post_draw

		var snap := root.get_texture().get_image()
		if snap != null:
			snap.convert(Image.FORMAT_RGBA8)
			var crop_y := maxi(0, (snap.get_height() - tile_h) / 2 - 40)
			var src_rect := Rect2i(0, crop_y, mini(tile_w, snap.get_width()), mini(tile_h, snap.get_height() - crop_y))
			var gx := idx % 2
			var gy := idx / 2
			var dst_pos := Vector2i(border + gx * (tile_w + border), border + gy * (tile_h + border))
			atlas.blit_rect(snap, src_rect, dst_pos)

		await _teardown_arena(arena)

	var out_dir := _showcase_out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var err := atlas.save_png(_showcase_out_path)
	if err != OK:
		printerr("Failed to save showcase PNG: %d" % err)
		return false
	print("Saved 2x2 biome & guardian boss showcase -> %s (%dx%d)" % [_showcase_out_path, atlas.get_width(), atlas.get_height()])
	return true


func _stage_boss_signature_vfx(arena: CombatDirector, boss: EnemyController3D, hero: HeroController3D, zid: String, to_hero: Vector3) -> void:
	var vfx_mgr := arena.vfx
	if vfx_mgr == null:
		return

	match zid:
		"fringe":
			var tg_cone := vfx_mgr.call("spawn_telegraph_cone", boss.global_position, to_hero, 5.2, 115.0, 4.0) as VfxTelegraph3D
			if tg_cone != null:
				tg_cone.set_progress(0.62)
			for off in [Vector3(2.4, 0.0, 1.8), Vector3(-2.6, 0.0, -1.2)]:
				var tc := vfx_mgr.call("spawn_telegraph_circle", hero.global_position + off, 2.6, 4.0, Color(0.95, 0.42, 0.14, 0.80)) as VfxTelegraph3D
				if tc != null:
					tc.set_progress(0.55)
			vfx_mgr.call("spawn_shockwave_ring", boss.global_position + to_hero * 2.0, 3.6, Color(0.96, 0.46, 0.16))
			vfx_mgr.call("spawn_slash_arc", hero.global_position, -to_hero, 3.0, 140.0, Color(1.0, 0.72, 0.30))

		"weald":
			var tg_line := vfx_mgr.call("spawn_telegraph_line", boss.global_position, to_hero, 9.5, 1.9, 4.0, Color(0.45, 0.94, 0.24, 0.84)) as VfxTelegraph3D
			if tg_line != null:
				tg_line.set_progress(0.68)
			var tg_leap := vfx_mgr.call("spawn_telegraph_circle", hero.global_position + Vector3(1.8, 0.0, 0.8), 3.2, 4.0, Color(0.42, 0.94, 0.28, 0.78)) as VfxTelegraph3D
			if tg_leap != null:
				tg_leap.set_progress(0.58)
			boss._fire_boss_fan_from_dir(to_hero, [-36.0, -18.0, 0.0, 18.0, 36.0], 11.5, 20.0, "blood_orb", DamageEvent.Kind.SHADOW)
			for p in arena.projectiles_root.get_children():
				if p is CombatProjectile:
					var cp := p as CombatProjectile
					cp.set_physics_process(false)
					cp.global_position += cp.direction * 2.6
			vfx_mgr.call("spawn_slash_arc", boss.global_position, to_hero, 4.6, 130.0, Color(0.46, 0.96, 0.28))

		"catacombs":
			var inner_c := vfx_mgr.call("spawn_telegraph_circle", boss.global_position, 3.6, 4.0, Color(0.36, 0.62, 1.0, 0.85)) as VfxTelegraph3D
			if inner_c != null:
				inner_c.set_progress(0.74)
			var outer_c := vfx_mgr.call("spawn_telegraph_circle", boss.global_position, 7.8, 4.0, Color(0.34, 0.52, 1.0, 0.52)) as VfxTelegraph3D
			if outer_c != null:
				outer_c.set_progress(0.45)
			boss._fire_radial_nova(0.25, 8, 10.5, 24.0, "voidpyre_bolt", DamageEvent.Kind.SHADOW)
			for p in arena.projectiles_root.get_children():
				if p is CombatProjectile:
					var cp := p as CombatProjectile
					cp.set_physics_process(false)
					cp.global_position += cp.direction * 2.5
			vfx_mgr.call("spawn_shockwave_ring", boss.global_position, 3.6, Color(0.38, 0.66, 1.0))
			var arc_pts := PackedVector3Array([
				hero.global_position + Vector3(0.0, 1.2, 0.0),
				boss.global_position + Vector3(-1.2, 1.6, 1.2),
				boss.global_position + Vector3(0.2, 2.1, 0.0),
			])
			vfx_mgr.call("spawn_chain_lightning", arc_pts)

		"rift":
			var stamp_line := vfx_mgr.call("spawn_telegraph_line", boss.global_position, to_hero, 11.5, 2.8, 4.0, Color(1.0, 0.28, 0.08, 0.86)) as VfxTelegraph3D
			if stamp_line != null:
				stamp_line.set_progress(0.70)
			vfx_mgr.call("spawn_blackflame_pyre", boss.global_position + Vector3(-3.4, 0.0, 2.2), 2.4)
			vfx_mgr.call("spawn_blackflame_pyre", boss.global_position + Vector3(3.6, 0.0, 3.4), 2.2)
			var met_c := vfx_mgr.call("spawn_telegraph_circle", hero.global_position + Vector3(2.2, 0.0, -1.0), 2.8, 4.0, Color(1.0, 0.30, 0.08, 0.82)) as VfxTelegraph3D
			if met_c != null:
				met_c.set_progress(0.64)
			vfx_mgr.call("spawn_slash_arc", hero.global_position, to_hero * -1.0, 3.2, 150.0, Color(1.0, 0.44, 0.12))


func _build_panel_overlay(title_txt: String, sub_txt: String, accent: Color) -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = 20

	var panel := PanelContainer.new()
	panel.position = Vector2(20.0, 196.0)
	panel.custom_minimum_size = Vector2(680.0, 74.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.06, 0.82)
	sb.border_color = accent
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var t_lbl := Label.new()
	t_lbl.text = title_txt
	t_lbl.add_theme_font_size_override("font_size", 22)
	t_lbl.add_theme_color_override("font_color", accent.lightened(0.22))
	vbox.add_child(t_lbl)

	var s_lbl := Label.new()
	s_lbl.text = sub_txt
	s_lbl.add_theme_font_size_override("font_size", 15)
	s_lbl.add_theme_color_override("font_color", Color(0.84, 0.84, 0.88, 0.95))
	vbox.add_child(s_lbl)

	cl.add_child(panel)
	return cl


func _run_rift_peak_stress_benchmark() -> bool:
	var arena := _arena_scene.instantiate() as CombatDirector
	root.add_child(arena)
	arena.start_run("oathbreaker", "rift", GameEnums.Difficulty.NIGHTMARE, 9999)
	_equip_hero_tier(arena, 4, GameEnums.WeaponType.GREATSWORD, GameEnums.LanternAspect.EMBER_GOLD)

	for child in arena.actors_root.get_children():
		if child is EnemyController3D:
			arena.actors_root.remove_child(child)
			child.free()
	arena._enemies.clear()
	for i in range(arena._clearings.size()):
		var cl: Dictionary = arena._clearings[i]
		cl["activated"] = true
		cl["cleared"] = true
		arena._clearings[i] = cl
	arena._unlock_boss_gate()

	var center := BarrowArenaBuilder.BOSS_CENTER
	var hero := arena.hero
	hero.global_position = center + Vector3(0.0, 0.0, 4.5)
	hero.grant_iframes(120.0)
	hero.auto_attack_enabled = true

	var boss := arena.spawn_boss_encounter()
	boss.global_position = center + Vector3(0.0, 0.0, -3.5)
	boss.max_hp = 999999.0
	boss.current_hp = 500000.0
	boss.is_enraged = true
	boss._windup_scale = 0.82
	boss.state = EnemyController3D.State.CHASE

	var pool: Array[String] = ["hollow_ghoul", "crypt_batlord", "ash_scorpion", "stone_gargoyle"]
	var monsters: Array[EnemyController3D] = []
	for m_idx in range(20):
		var ang := (TAU * float(m_idx)) / 20.0
		var rad := 4.8 + float(m_idx % 4) * 1.65
		var m_pos := center + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var eid := pool[m_idx % pool.size()]
		var mob := arena.spawn_enemy_at(eid, m_pos, m_idx % 5 == 0, -1, false)
		mob.max_hp = 999999.0
		mob.current_hp = 999999.0
		mob.state = EnemyController3D.State.CHASE
		monsters.append(mob)

	arena._snap_camera_to_hero()

	var stress_scrape := arena.vfx.call("create_blade_scrape", arena.vfx_root) as BladeScrapeVfx
	var stress_ribbon := arena.vfx.call("create_weapon_ribbon", arena.vfx_root, Color(1.0, 0.48, 0.16, 0.92)) as WeaponRibbon3D

	arena.vfx.call("spawn_blackflame_pyre", center + Vector3(-2.6, 0.0, 1.2), 3.0)
	arena.vfx.call("spawn_blackflame_pyre", center + Vector3(2.8, 0.0, -0.8), 2.8)
	_trigger_stress_chain_lightning(arena, hero, monsters, 0)

	var total_steps := WARMUP_FRAMES + BENCH_FRAMES
	var frame_times_ms: PackedFloat64Array = PackedFloat64Array()
	frame_times_ms.resize(BENCH_FRAMES)

	var prev_usec := Time.get_ticks_usec()
	for step in range(total_steps):
		var orbit_a := float(step) * 0.085
		var target_p := center + Vector3(cos(orbit_a) * 4.2, 0.0, sin(orbit_a) * 4.2)
		var mv := Vector2(target_p.x - hero.global_position.x, target_p.z - hero.global_position.z)
		arena.set_virtual_move(mv.normalized() if mv.length_squared() > 0.01 else Vector2(1.0, 0.0))
		arena.press_attack(true)
		hero.grant_iframes(10.0)

		var tip_a := float(step) * 0.26
		var scrape_pos := hero.global_position + Vector3(cos(tip_a) * 2.2, 0.04, sin(tip_a) * 2.2)
		var scrape_vel := Vector3(-sin(tip_a) * 9.5, 0.0, cos(tip_a) * 9.5)
		if stress_scrape != null:
			stress_scrape.update_scrape(scrape_pos, 0.0, true, scrape_vel)
		if stress_ribbon != null:
			var r_base := hero.global_position + Vector3(cos(tip_a) * 0.9, 1.05, sin(tip_a) * 0.9)
			var r_tip := hero.global_position + Vector3(cos(tip_a) * 3.1, 0.95, sin(tip_a) * 3.1)
			stress_ribbon.push_sample(r_base, r_tip, true)

		if step % 36 == 18:
			var pyre_off := Vector3(cos(orbit_a + 1.4) * 3.2, 0.0, sin(orbit_a + 1.4) * 3.2)
			arena.vfx.call("spawn_blackflame_pyre", hero.global_position + pyre_off, 2.9)
		if step % 12 == 0:
			_trigger_stress_chain_lightning(arena, hero, monsters, step)

		await process_frame
		var now_usec := Time.get_ticks_usec()
		if step >= WARMUP_FRAMES:
			frame_times_ms[step - WARMUP_FRAMES] = float(now_usec - prev_usec) * 0.001
		prev_usec = now_usec

	var alive_total := arena.get_alive_enemies().size()
	var sum_ms := 0.0
	var sorted_ms: Array[float] = []
	for i in range(BENCH_FRAMES):
		var ms := float(frame_times_ms[i])
		sum_ms += ms
		sorted_ms.append(ms)
	sorted_ms.sort()

	var avg_ms := sum_ms / float(BENCH_FRAMES)
	var p95_idx := clampi(int(ceil(float(BENCH_FRAMES) * 0.95)) - 1, 0, BENCH_FRAMES - 1)
	var p95_ms := sorted_ms[p95_idx]
	var equiv_fps := 1000.0 / maxf(avg_ms, 0.0001)

	print("STRESS_ACTIVE_ENEMIES=%d (20 monsters + 1 boss + summons)" % alive_total)
	print("AVG_FRAME_MS=%.3f" % avg_ms)
	print("P95_FRAME_MS=%.3f" % p95_ms)
	print("EQUIV_FPS=%.1f" % equiv_fps)

	await _teardown_arena(arena)

	if alive_total < 21:
		printerr("BENCHMARK FAILED: Expected >= 21 active enemies, got %d" % alive_total)
		return false
	if avg_ms > MAX_AVG_MS:
		printerr("BENCHMARK FAILED: AVG_FRAME_MS %.3f > %.1f ms target" % [avg_ms, MAX_AVG_MS])
		return false

	print("BENCHMARK PASSED (AVG_FRAME_MS %.3f <= %.1f ms)" % [avg_ms, MAX_AVG_MS])
	return true


func _trigger_stress_chain_lightning(arena: CombatDirector, hero: HeroController3D, monsters: Array[EnemyController3D], seed_step: int) -> void:
	var pts := PackedVector3Array()
	pts.append(hero.global_position + Vector3(0.0, 1.15, 0.0))
	for k in range(4):
		var m := monsters[(seed_step + k * 5) % monsters.size()]
		if m != null and is_instance_valid(m):
			pts.append(m.global_position + Vector3(0.0, 1.1, 0.0))
	if pts.size() >= 2:
		arena.vfx.call("spawn_chain_lightning", pts)
