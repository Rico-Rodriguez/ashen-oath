extends SceneTree

const CELL_SIZE := Vector2i(640, 480)

var _out_path: String = ""


func _init() -> void:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty() and str(user_args[0]).strip_edges() != "":
		var arg := str(user_args[0]).strip_edges()
		_out_path = arg if arg.to_lower().ends_with(".png") else arg.path_join("phase2_vfx_showcase.png")
	else:
		_out_path = ProjectSettings.globalize_path("user://shots").path_join("phase2_vfx_showcase.png")
	DirAccess.make_dir_recursive_absolute(_out_path.get_base_dir())
	call_deferred("_run")


func _make_arena_cell(zone_id: String, seed_val: int) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = CELL_SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)

	var arena := Node3D.new()
	arena.name = "ArenaRoot"
	vp.add_child(arena)

	var zdef := GameRegistry.get_zone(zone_id)
	var layout := BarrowArenaBuilder.build_zone(arena, zdef, seed_val)

	var vfx := VfxManager.new()
	vfx.name = "VfxManager"
	vp.add_child(vfx)

	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.current = true
	vp.add_child(cam)

	return {"vp": vp, "arena": arena, "layout": layout, "vfx": vfx, "cam": cam}


func _spawn_hero(parent: Node3D, scene_path: String, cid: String, tier: int, wpn: String, off: String, plume: bool, lantern: Color) -> ActorVisual:
	var ps := load(scene_path) as PackedScene
	var actor := ps.instantiate() as ActorVisual
	parent.add_child(actor)
	actor.ensure_initialized()
	HeroRigDresser.dress(actor, cid, tier, wpn, off, plume, lantern)
	return actor


func _spawn_enemy_vis(parent: Node3D, scene_path: String, pos: Vector3, yaw_deg: float = 0.0) -> ActorVisual:
	var ps := load(scene_path) as PackedScene
	var actor := ps.instantiate() as ActorVisual
	parent.add_child(actor)
	actor.position = pos
	actor.rotation_degrees.y = yaw_deg
	actor.ensure_initialized()
	return actor


func _verify_arena_contracts(layout: Dictionary) -> void:
	assert(layout.get("spawn_pos") == Vector3(0.0, 0.0, 36.0), "spawn_pos contract")
	assert(layout.get("shrine_pos") == Vector3(0.0, 0.0, -8.5), "shrine_pos contract")
	assert(is_equal_approx(float(layout.get("boss_gate_z")), -32.0), "boss_gate_z contract")
	assert(bool(layout.get("boss_gate_locked")) == true, "boss_gate_locked initial true")
	assert(layout.get("boss_center") == Vector3(0.0, 0.0, -45.0), "boss_center contract")
	assert(is_equal_approx(float(layout.get("boss_radius")), 14.0), "boss_radius contract")

	var clearings: Array = layout.get("clearings", [])
	assert(clearings.size() == 3, "3 clearings expected")
	assert((clearings[0]["spawn_points"] as Array).size() == 6, "clearing 0 has 6 spawn points")
	assert((clearings[1]["spawn_points"] as Array).size() == 7, "clearing 1 has 7 spawn points")
	assert((clearings[2]["spawn_points"] as Array).size() == 8, "clearing 2 has 8 spawn points")

	var blocked := BarrowArenaBuilder.clamp_position(Vector3(0.0, 0.0, -40.0), layout)
	assert(is_equal_approx(blocked.z, -31.2), "locked gate blocks at z >= -31.2")

	var clamped_x := BarrowArenaBuilder.clamp_position(Vector3(30.0, 0.0, 22.0), layout)
	assert(clamped_x.x <= 13.501, "clearing x clamped <= 13.5")

	(layout["unlock_boss_gate"] as Callable).call()
	assert(bool(layout.get("boss_gate_locked")) == false, "unlock_boss_gate flips boss_gate_locked false")
	var passed := BarrowArenaBuilder.clamp_position(Vector3(18.0, 0.0, -45.0), layout)
	assert(is_equal_approx(passed.z, -45.0) and is_equal_approx(passed.x, 14.5), "unlocked boss arena clamp")


func _run() -> void:
	await process_frame
	await process_frame

	var contract_node := Node3D.new()
	root.add_child(contract_node)
	var contract_layout := BarrowArenaBuilder.build_zone(contract_node, GameRegistry.get_zone("fringe"), 999)
	_verify_arena_contracts(contract_layout)
	contract_layout.clear()
	contract_node.queue_free()

	var stages: Array[Dictionary] = []

	var c0 := _make_arena_cell("fringe", 1337)
	var oath_drag := _spawn_hero(
		c0["arena"], "res://scenes/actors/heroes/oathbreaker.tscn",
		"oathbreaker", 3, "zweihander", "", true, Color(1.0, 0.74, 0.26)
	)
	oath_drag.position = Vector3(-0.3, 0.0, 24.4)
	oath_drag.rotation_degrees.y = -18.0
	oath_drag.play_anim("run", 1.15, true)
	oath_drag.set_move_blend(0.92)
	var scrape := (c0["vfx"] as VfxManager).create_blade_scrape(oath_drag) as BladeScrapeVfx
	(c0["cam"] as Camera3D).look_at_from_position(Vector3(3.1, 2.45, 25.6), Vector3(0.2, 0.65, 22.7), Vector3.UP)
	stages.append(c0)

	var c1 := _make_arena_cell("fringe", 2026)
	var oath_cleave := _spawn_hero(
		c1["arena"], "res://scenes/actors/heroes/oathbreaker.tscn",
		"oathbreaker", 4, "zweihander", "", true, Color(0.98, 0.24, 0.20)
	)
	oath_cleave.position = Vector3(0.0, 0.0, 22.0)
	oath_cleave.rotation_degrees.y = 32.0
	oath_cleave.play_anim("attack", 1.0, true)
	var _ghoul_hit_a := _spawn_enemy_vis(c1["arena"], "res://scenes/actors/enemies/hollow_ghoul.tscn", Vector3(-1.55, 0.0, 19.9), 155.0)
	var _ghoul_hit_b := _spawn_enemy_vis(c1["arena"], "res://scenes/actors/enemies/hollow_ghoul.tscn", Vector3(1.55, 0.0, 20.1), -155.0)
	var ribbon := (c1["vfx"] as VfxManager).create_weapon_ribbon(oath_cleave, Color(0.95, 0.78, 0.42, 0.94)) as WeaponRibbon3D
	(c1["cam"] as Camera3D).look_at_from_position(Vector3(-2.4, 3.8, 26.4), Vector3(0.0, 1.05, 21.3), Vector3.UP)
	stages.append(c1)

	var c2 := _make_arena_cell("catacombs", 3030)
	var mage_pyre := _spawn_hero(
		c2["arena"], "res://scenes/actors/heroes/battlemage.tscn",
		"battlemage", 3, "runed_staff", "", true, Color(0.32, 0.72, 1.0)
	)
	mage_pyre.position = Vector3(-1.8, 0.0, 5.4)
	mage_pyre.rotation_degrees.y = -24.0
	mage_pyre.play_anim("skill_cast", 1.0, true)
	var _pyre_ghoul_1 := _spawn_enemy_vis(c2["arena"], "res://scenes/actors/enemies/hollow_ghoul.tscn", Vector3(1.2, 0.0, 1.1), 160.0)
	var _pyre_ghoul_2 := _spawn_enemy_vis(c2["arena"], "res://scenes/actors/enemies/crypt_batlord.tscn", Vector3(-1.3, 0.0, 0.5), 175.0)
	(c2["vfx"] as VfxManager).spawn_blackflame_pyre(Vector3(0.2, 0.0, 0.8), 3.1)
	var bolt_dummy := Node3D.new()
	bolt_dummy.position = Vector3(-0.9, 1.35, 3.4)
	(c2["arena"] as Node3D).add_child(bolt_dummy)
	(c2["vfx"] as VfxManager).spawn_blackflame_bolt_vfx(bolt_dummy)
	(c2["cam"] as Camera3D).look_at_from_position(Vector3(-4.4, 4.1, 9.2), Vector3(0.1, 2.0, 0.9), Vector3.UP)
	stages.append(c2)

	var c3 := _make_arena_cell("catacombs", 4040)
	var mage_arc := _spawn_hero(
		c3["arena"], "res://scenes/actors/heroes/battlemage.tscn",
		"battlemage", 4, "runed_staff", "", true, Color(0.98, 0.24, 0.22)
	)
	mage_arc.position = Vector3(-2.7, 0.0, 3.8)
	mage_arc.rotation_degrees.y = -48.0
	mage_arc.play_anim("skill_cast", 1.0, true)
	var g1 := _spawn_enemy_vis(c3["arena"], "res://scenes/actors/enemies/hollow_ghoul.tscn", Vector3(-0.7, 0.0, 1.8), 145.0)
	var g2 := _spawn_enemy_vis(c3["arena"], "res://scenes/actors/enemies/hollow_ghoul.tscn", Vector3(1.5, 0.0, 0.5), 170.0)
	var g3 := _spawn_enemy_vis(c3["arena"], "res://scenes/actors/enemies/hollow_ghoul.tscn", Vector3(3.3, 0.0, 2.3), -145.0)
	(c3["cam"] as Camera3D).look_at_from_position(Vector3(-0.8, 4.9, 8.2), Vector3(0.6, 1.15, 1.8), Vector3.UP)
	stages.append(c3)

	var c4 := _make_arena_cell("fringe", 5050)
	(c4["layout"]["unlock_boss_gate"] as Callable).call()
	var troll := _spawn_enemy_vis(c4["arena"], "res://scenes/actors/enemies/barrow_troll.tscn", Vector3(0.0, 0.0, -47.2), 180.0)
	troll.play_anim("skill_cast", 0.8, true)
	var rev_target := _spawn_hero(
		c4["arena"], "res://scenes/actors/heroes/oathbreaker.tscn",
		"oathbreaker", 2, "bastardsword", "shield_heater", true, Color(1.0, 0.74, 0.28)
	)
	rev_target.position = Vector3(0.4, 0.0, -40.5)
	var crimson_tg := Color(0.88, 0.08, 0.08, 0.82)
	var tg_cone := (c4["vfx"] as VfxManager).spawn_telegraph_cone(Vector3(0.0, 0.0, -46.2), Vector3(0.0, 0.0, 1.0), 4.9, 88.0, 0.45) as VfxTelegraph3D
	var tg_circ := (c4["vfx"] as VfxManager).spawn_telegraph_circle(Vector3(-4.9, 0.0, -43.4), 2.3, 0.45, crimson_tg) as VfxTelegraph3D
	var tg_line := (c4["vfx"] as VfxManager).spawn_telegraph_line(Vector3(4.3, 0.0, -47.0), Vector3(-0.08, 0.0, 1.0), 6.8, 1.5, 0.45) as VfxTelegraph3D
	(c4["cam"] as Camera3D).look_at_from_position(Vector3(-1.8, 9.4, -34.8), Vector3(0.0, 1.0, -44.2), Vector3.UP)
	stages.append(c4)

	var c5 := _make_arena_cell("weald", 6060)
	var shrine := DarkShrine3D.new()
	(c5["arena"] as Node3D).add_child(shrine)
	shrine.setup(null, c5["layout"]["shrine_pos"] as Vector3)
	var rev_loot := _spawn_hero(
		c5["arena"], "res://scenes/actors/heroes/revenant.tscn",
		"revenant", 3, "halberd", "", true, Color(0.28, 0.92, 0.48)
	)
	rev_loot.position = Vector3(-2.9, 0.0, -6.8)
	rev_loot.rotation_degrees.y = -135.0
	var drop_specs := [
		{"pos": Vector3(-1.8, 0.0, -5.8), "col": Color(0.76, 0.78, 0.84), "high": false},
		{"pos": Vector3(-0.2, 0.0, -5.4), "col": Color(0.28, 0.64, 1.0), "high": false},
		{"pos": Vector3(1.5, 0.0, -5.7), "col": Color(0.76, 0.32, 1.0), "high": true},
		{"pos": Vector3(2.8, 0.0, -6.9), "col": Color(1.0, 0.72, 0.20), "high": true},
	]
	for ds in drop_specs:
		var dnode := Node3D.new()
		dnode.position = ds["pos"] as Vector3
		(c5["arena"] as Node3D).add_child(dnode)
		(c5["vfx"] as VfxManager).spawn_loot_beam(dnode, ds["col"] as Color, bool(ds["high"]))
	(c5["cam"] as Camera3D).look_at_from_position(Vector3(0.2, 4.8, -0.4), Vector3(0.1, 1.55, -7.4), Vector3.UP)
	stages.append(c5)

	var drag_dir := Vector3(0.32, 0.0, -1.0).normalized()
	for step in range(14):
		oath_drag.position += drag_dir * 0.19
		if oath_drag.anim_player != null:
			oath_drag.anim_player.advance(0.016)
		oath_drag._update_weapon_drag_pose(0.0)
		scrape.update_scrape(oath_drag.get_blade_tip_global(), 0.0, true, drag_dir * 6.2)

		var cleave_frac := float(step) / 13.0
		var ang := lerpf(1.65, -1.45, cleave_frac)
		var c_dir := Vector3(sin(ang), lerpf(0.22, -0.05, cleave_frac), -cos(ang)).normalized()
		var c_origin := Vector3(0.0, 1.05, 22.0)
		ribbon.push_sample(c_origin + c_dir * 0.60, c_origin + c_dir * 2.75, true)
		oath_cleave.rotation.y = ang * 0.65
		if step == 11:
			(c1["vfx"] as VfxManager).spawn_slash_arc(Vector3(0.0, 0.0, 22.0), Vector3(-0.15, 0.0, -1.0), 2.85, 175.0, Color(1.0, 0.76, 0.36))
			(c1["vfx"] as VfxManager).spawn_hit_sparks(Vector3(-1.45, 1.15, 20.0), Color(1.0, 0.68, 0.24), true)

		bolt_dummy.position += Vector3(0.08, -0.02, -0.14)

		if step == 11:
			var chain_pts := PackedVector3Array([
				mage_arc.get_cast_origin_global(),
				g1.global_position + Vector3(0.0, 1.12, 0.0),
				g2.global_position + Vector3(0.0, 1.12, 0.0),
				g3.global_position + Vector3(0.0, 1.12, 0.0),
			])
			(c3["vfx"] as VfxManager).spawn_chain_lightning(chain_pts)

		await RenderingServer.frame_post_draw

	if is_instance_valid(tg_cone):
		tg_cone.set_progress(0.62)
	if is_instance_valid(tg_circ):
		tg_circ.set_progress(0.76)
	if is_instance_valid(tg_line):
		tg_line.set_progress(0.55)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var composite := Image.create(CELL_SIZE.x * 3, CELL_SIZE.y * 2, false, Image.FORMAT_RGBA8)
	for idx in stages.size():
		var r := idx / 3
		var c := idx % 3
		var vp: SubViewport = stages[idx]["vp"]
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		composite.blit_rect(img, Rect2i(Vector2i.ZERO, CELL_SIZE), Vector2i(c * CELL_SIZE.x, r * CELL_SIZE.y))

	composite.save_png(_out_path)
	print("Saved Phase 2 VFX showcase: ", _out_path)

	for st in stages:
		var l: Dictionary = st["layout"]
		l.clear()
		(st["vp"] as Node).free()
		st.clear()
	stages.clear()
	c0.clear()
	c1.clear()
	c2.clear()
	c3.clear()
	c4.clear()
	c5.clear()
	await process_frame
	quit(0)
