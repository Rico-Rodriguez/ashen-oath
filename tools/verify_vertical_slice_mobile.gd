extends SceneTree

const SAVE_SUBPATH := "vertical_slice_combat_mobile.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_dir := _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var save_path := out_dir.path_join(SAVE_SUBPATH)

	root.size = Vector2i(1280, 720)

	var arena_ps := load("res://scenes/combat/arena_run.tscn") as PackedScene
	var hud_ps := load("res://scenes/ui/combat_hud.tscn") as PackedScene
	var arena := arena_ps.instantiate() as CombatDirector
	var hud := hud_ps.instantiate() as CombatHud
	root.add_child(arena)
	root.add_child(hud)
	await process_frame

	arena.start_run("oathbreaker", "fringe", GameEnums.Difficulty.NORMAL, 1337)
	hud.bind_director(arena)
	arena.hero.auto_attack_enabled = false

	for e in arena._enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	arena._enemies.clear()
	await process_frame

	var hero := arena.hero
	HeroRigDresser.dress(
		hero.visual,
		"oathbreaker",
		3,
		hero.stats.weapon_mesh_key,
		hero.stats.offhand_mesh_key,
		true,
		Color(0.28, 0.80, 1.0)
	)
	hero.global_position = Vector3(-0.35, 0.0, -2.5)
	hero.velocity = Vector3.ZERO

	var thrall := arena.spawn_enemy_at("hollow_ghoul", Vector3(-2.35, 0.0, -4.3), false, -1, false)
	var halberdier := arena.spawn_enemy_at("stone_gargoyle", Vector3(-2.75, 0.0, -6.1), true, -1, false)
	var acolyte := arena.spawn_enemy_at("crypt_batlord", Vector3(3.85, 0.0, -3.9), false, -1, false)
	var warden := arena.spawn_boss_encounter()
	warden.global_position = Vector3(1.95, 0.0, -5.8)
	warden.is_enraged = true
	warden.current_hp = warden.max_hp * 0.42
	if warden.visual != null:
		warden.visual.set_enrage_embers(true)

	var enemies: Array[EnemyController3D] = [thrall, halberdier, acolyte, warden]
	for e in enemies:
		e.set_physics_process(false)
		e.state = EnemyController3D.State.WINDUP
		var to_hero := hero.global_position - e.global_position
		e.rotation.y = atan2(-to_hero.x, -to_hero.z)

	var to_boss := warden.global_position - hero.global_position
	var hero_yaw := atan2(-to_boss.x, -to_boss.z)
	hero.rotation.y = hero_yaw
	hero.set_physics_process(false)

	hero.visual.play_anim("attack_1", 1.0, false)
	thrall.visual.play_anim("run", 1.0, true)
	halberdier.visual.play_anim("attack_1", 1.0, false)
	acolyte.visual.play_anim("skill_cast", 1.0, false)
	warden.visual.play_anim("attack_2", 0.9, false)

	arena.boss_updated.emit(
		warden.enemy_def.display_name,
		warden.enemy_def.title,
		warden.current_hp,
		warden.max_hp,
		true
	)
	arena.hud_updated.emit(arena.get_hud_state())

	var hero_fwd := Vector3(-sin(hero_yaw), 0.0, -cos(hero_yaw)).normalized()
	arena.vfx.spawn_blackflame_pyre(Vector3(3.35, 0.0, -7.85), 1.65)

	arena.set_process(false)
	arena._cam_dist = 14.2
	arena._cam_focus = hero.global_position + Vector3(0.15, 0.85, -1.65)
	var pitch_rad := deg_to_rad(CombatDirector.CAMERA_PITCH_DEG)
	var offset := Vector3(0.0, sin(pitch_rad) * arena._cam_dist, cos(pitch_rad) * arena._cam_dist)
	arena.run_camera.position = arena._cam_focus + offset
	arena.run_camera.look_at(arena._cam_focus, Vector3.UP)

	var bolt := CombatProjectile.new()
	arena.projectiles_root.add_child(bolt)
	var acolyte_cast_origin := acolyte.global_position + Vector3(-0.35, 1.32, 0.15)
	var bolt_dir := (hero.global_position - acolyte_cast_origin).normalized()
	bolt.setup(
		arena,
		arena.vfx,
		acolyte,
		DamageEvent.Team.ENEMY,
		acolyte_cast_origin,
		bolt_dir,
		9.0,
		0.0,
		"crypt_batlord",
		"blackflame_bolt",
		0,
		0,
		DamageEvent.Kind.FIRE
	)

	var scrape_pos := hero.global_position + Vector3(-0.55, 0.05, 0.35)
	for tick in range(8):
		await physics_frame
		scrape_pos += hero_fwd * 0.14
		if hero._blade_scrape != null:
			hero._blade_scrape.update_scrape(scrape_pos, 0.0, true, hero_fwd * 8.2)

	arena.vfx.spawn_slash_arc(hero.global_position, hero_fwd, 3.15, 128.0, Color(1.0, 0.72, 0.30, 0.96))
	arena.vfx.spawn_hit_sparks(Vector3(0.75, 1.15, -4.15), Color(1.0, 0.65, 0.22), true)
	arena.vfx.spawn_chain_lightning(PackedVector3Array([
		hero.global_position + Vector3(0.25, 1.15, -0.25),
		thrall.global_position + Vector3(0.0, 1.05, 0.0),
		halberdier.global_position + Vector3(0.0, 1.25, 0.0),
		warden.global_position + Vector3(0.0, 1.55, 0.0),
	]))

	for _t in range(2):
		await physics_frame
	for _f in range(2):
		await process_frame
	await RenderingServer.frame_post_draw

	var img := root.get_texture().get_image()
	var err := img.save_png(save_path)
	print("[verify_vertical_slice_mobile] Saved %s err=%d size=%dx%d" % [save_path, err, img.get_width(), img.get_height()])

	arena._clear_run_world()
	arena.queue_free()
	hud.queue_free()
	for _q in range(3):
		await process_frame
	quit(0 if err == OK else 1)


func _resolve_out_dir() -> String:
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0 and not String(user_args[0]).is_empty():
		return String(user_args[0])
	return ProjectSettings.globalize_path("res://tmp_verify")
