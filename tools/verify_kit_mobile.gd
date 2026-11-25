extends SceneTree

const KIT_DIR := "res://assets/models/kit/"
const ARMOR_SHADER_PATH := "res://shaders/armor_forge.gdshader"

var _out_dir := ""


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0 and str(user_args[0]) != "":
		_out_dir = str(user_args[0])
	else:
		_out_dir = ProjectSettings.globalize_path("user://kit_mobile")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	call_deferred("_run_verification")


func _run_verification() -> void:
	print("[verify_kit_mobile] Starting Mobile renderer verification -> ", _out_dir)
	var char_ok := await _render_characters_sheet()
	var prop_ok := await _render_arena_props_sheet()
	print("[verify_kit_mobile] Done. characters=", char_ok, " props=", prop_ok)
	quit(0 if (char_ok and prop_ok) else 1)


func _load_glb_scene(filename: String) -> Node3D:
	var res_path := KIT_DIR + filename
	var abs_path := ProjectSettings.globalize_path(res_path)
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file(abs_path, state)
	if err != OK:
		push_error("Failed to load GLB: %s (err=%d)" % [abs_path, err])
		return null
	var scene := gltf.generate_scene(state) as Node3D
	return scene


func _make_stage_viewport(w: int, h: int) -> Dictionary:
	var sv := SubViewport.new()
	sv.size = Vector2i(w, h)
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.062, 0.082, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.42, 0.54, 1.0)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.25
	env_node.environment = env
	sv.add_child(env_node)

	# Cool moon directional light (cast shadow)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.70, 0.82, 1.0)
	moon.light_energy = 1.65
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	sv.add_child(moon)

	# Warm torch key light from front-left
	var torch := DirectionalLight3D.new()
	torch.light_color = Color(1.0, 0.74, 0.46)
	torch.light_energy = 1.35
	torch.shadow_enabled = false
	torch.rotation_degrees = Vector3(-28.0, 42.0, 0.0)
	sv.add_child(torch)

	# Cool rim back light for crisp metallic silhouette edge reads
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.46, 0.66, 0.96)
	rim.light_energy = 1.15
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(-18.0, 165.0, 0.0)
	sv.add_child(rim)

	# Stone floor slab at Y = 0
	var floor_mi := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 12.0
	pm.bottom_radius = 12.0
	pm.height = 0.1
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0.0, -0.05, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.14, 0.15, 0.18, 1.0)
	fmat.roughness = 0.90
	fmat.metallic = 0.04
	floor_mi.material_override = fmat
	sv.add_child(floor_mi)

	var cam := Camera3D.new()
	cam.fov = 36.0
	sv.add_child(cam)

	var content := Node3D.new()
	content.name = "CellContent"
	sv.add_child(content)

	var cl := CanvasLayer.new()
	var pill := ColorRect.new()
	pill.color = Color(0.03, 0.035, 0.045, 0.80)
	pill.position = Vector2(8, 8)
	pill.size = Vector2(w - 16, 28)
	cl.add_child(pill)

	var lbl := Label.new()
	lbl.position = Vector2(14, 10)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1.0))
	cl.add_child(lbl)
	sv.add_child(cl)

	root.add_child(sv)
	return {"sv": sv, "cam": cam, "content": content, "label": lbl}


func _clear_content(content: Node3D) -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func _apply_armor_tier(model_root: Node3D, tier: int) -> void:
	var shader := load(ARMOR_SHADER_PATH) as Shader
	var cloak_sh := load("res://shaders/cloak_sway.gdshader") as Shader
	if shader == null:
		return
	var cape_base := Color(0.11, 0.12, 0.16)
	var cape_trim := Color(0.32, 0.28, 0.23)
	var plume_col := Color(0.60, 0.57, 0.52)
	var trim_col := Color(0.52, 0.50, 0.46)
	var trim_metal := 0.80
	var trim_rough := 0.36
	match tier:
		2:
			cape_base = Color(0.08, 0.10, 0.14)
			cape_trim = Color(0.34, 0.38, 0.46)
			plume_col = Color(0.70, 0.68, 0.64)
			trim_col = Color(0.54, 0.58, 0.64)
			trim_metal = 0.90
			trim_rough = 0.24
		3:
			cape_base = Color(0.18, 0.06, 0.08)
			cape_trim = Color(0.84, 0.64, 0.22)
			plume_col = Color(0.80, 0.74, 0.62)
			trim_col = Color(0.94, 0.72, 0.24)
			trim_metal = 0.94
			trim_rough = 0.20
		4:
			cape_base = Color(0.065, 0.058, 0.062)
			cape_trim = Color(0.74, 0.28, 0.08)
			plume_col = Color(0.46, 0.10, 0.08)
			trim_col = Color(0.86, 0.48, 0.16)
			trim_metal = 0.92
			trim_rough = 0.24

	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := mi.get_active_material(s)
			var mname := orig.resource_name if orig != null else ""
			if mname == "ArmorPlate":
				var smat := ShaderMaterial.new()
				smat.shader = shader
				smat.set_shader_parameter("armor_tier", tier)
				smat.set_shader_parameter("hit_flash", 0.0)
				if orig is StandardMaterial3D:
					var std := orig as StandardMaterial3D
					smat.set_shader_parameter("albedo_color", std.albedo_color)
					if std.albedo_texture != null:
						smat.set_shader_parameter("albedo_tex", std.albedo_texture)
					smat.set_shader_parameter("has_rough_tex", std.roughness_texture != null)
					if std.roughness_texture != null:
						smat.set_shader_parameter("rough_tex", std.roughness_texture)
						smat.set_shader_parameter("rough_channel", _ch_vec(std.roughness_texture_channel))
					smat.set_shader_parameter("base_roughness", std.roughness)
					smat.set_shader_parameter("has_metal_tex", std.metallic_texture != null)
					if std.metallic_texture != null:
						smat.set_shader_parameter("metal_tex", std.metallic_texture)
						smat.set_shader_parameter("metal_channel", _ch_vec(std.metallic_texture_channel))
					smat.set_shader_parameter("base_metallic", std.metallic)
				mi.set_surface_override_material(s, smat)
			elif mname in ["CapeCloth", "TabardCloth", "HelmPlume"] and cloak_sh != null:
				var cmat := ShaderMaterial.new()
				cmat.shader = cloak_sh
				var base_c := cape_base if mname != "HelmPlume" else plume_col
				cmat.set_shader_parameter("cloth_color", base_c)
				cmat.set_shader_parameter("hem_ash_color", base_c.darkened(0.55))
				cmat.set_shader_parameter("trim_color", cape_trim if mname != "HelmPlume" else plume_col.darkened(0.28))
				cmat.set_shader_parameter("sway_amplitude", 0.085 if mname == "CapeCloth" else 0.0)
				mi.set_surface_override_material(s, cmat)
			elif mname == "ArmorTrim":
				var tmat := StandardMaterial3D.new()
				tmat.albedo_color = trim_col
				tmat.metallic = trim_metal
				tmat.roughness = trim_rough
				mi.set_surface_override_material(s, tmat)


func _ch_vec(ch: BaseMaterial3D.TextureChannel) -> Vector4:
	match ch:
		BaseMaterial3D.TEXTURE_CHANNEL_RED:
			return Vector4(1.0, 0.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0.0, 1.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0.0, 0.0, 1.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0.0, 0.0, 0.0, 1.0)
		_:
			return Vector4(0.3333, 0.3333, 0.3333, 0.0)


func _pose_model(model: Node3D, clip: String, seek_sec: float) -> PackedStringArray:
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return PackedStringArray()
	var ap := aps[0] as AnimationPlayer
	var list := ap.get_animation_list()
	if ap.has_animation(clip):
		ap.play(clip)
		ap.seek(seek_sec, true)
		ap.advance(0.0)
		ap.pause()
	return list


func _render_characters_sheet() -> bool:
	var cw := 450
	var ch := 450
	var sheet := Image.create(cw * 4, ch * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.04, 0.045, 0.06, 1.0))

	var stage := _make_stage_viewport(cw, ch)
	var sv: SubViewport = stage["sv"]
	var cam: Camera3D = stage["cam"]
	var content: Node3D = stage["content"]
	var lbl: Label = stage["label"]

	var cells := [
		# Row 0: Oathbreaker poses
		{"glb": "oathbreaker_knight.glb", "title": "Oathbreaker: Idle (3/4)", "clip": "idle", "t": 0.0, "cam": Vector3(1.65, 1.28, 3.15), "look": Vector3(0.0, 1.02, 0.0), "tier": 0},
		{"glb": "oathbreaker_knight.glb", "title": "Oathbreaker: Run Blade-Drag", "clip": "run", "t": 0.16, "cam": Vector3(-3.05, 1.05, 1.35), "look": Vector3(0.0, 0.90, -0.25), "tier": 0},
		{"glb": "oathbreaker_knight.glb", "title": "Oathbreaker: Attack 1 Cleave", "clip": "attack_1", "t": 0.26, "cam": Vector3(1.95, 1.42, 3.65), "look": Vector3(0.12, 1.05, 0.30), "tier": 0},
		{"glb": "oathbreaker_knight.glb", "title": "Oathbreaker: Back Silhouette", "clip": "idle", "t": 0.45, "cam": Vector3(-1.45, 1.32, -3.15), "look": Vector3(0.0, 1.02, -0.1), "tier": 0},
		# Row 1: Armor Tiers 1..4 with armor_forge.gdshader
		{"glb": "oathbreaker_knight.glb", "title": "Armor Tier 1: Worn Iron", "clip": "idle", "t": 0.0, "cam": Vector3(1.55, 1.28, 3.05), "look": Vector3(0.0, 1.02, 0.0), "tier": 1},
		{"glb": "oathbreaker_knight.glb", "title": "Armor Tier 2: Blackened Steel", "clip": "idle", "t": 0.0, "cam": Vector3(1.55, 1.28, 3.05), "look": Vector3(0.0, 1.02, 0.0), "tier": 2},
		{"glb": "oathbreaker_knight.glb", "title": "Armor Tier 3: Sovereign Plate", "clip": "idle", "t": 0.0, "cam": Vector3(1.55, 1.28, 3.05), "look": Vector3(0.0, 1.02, 0.0), "tier": 3},
		{"glb": "oathbreaker_knight.glb", "title": "Armor Tier 4: Ashen Barrows", "clip": "idle", "t": 0.0, "cam": Vector3(1.55, 1.28, 3.05), "look": Vector3(0.0, 1.02, 0.0), "tier": 4},
		# Row 2: All 4 enemies & boss in idle pose
		{"glb": "ashen_thrall.glb", "title": "Ashen Thrall (1.72m)", "clip": "idle", "t": 0.0, "cam": Vector3(1.45, 1.18, 2.95), "look": Vector3(0.0, 0.92, 0.0), "tier": 0},
		{"glb": "cinder_acolyte.glb", "title": "Cinder Acolyte (1.82m)", "clip": "idle", "t": 0.0, "cam": Vector3(1.65, 1.38, 3.65), "look": Vector3(-0.22, 1.12, 0.15), "tier": 0},
		{"glb": "barrow_halberdier.glb", "title": "Barrow Halberdier (2.25m)", "clip": "idle", "t": 0.0, "cam": Vector3(2.30, 1.80, 4.55), "look": Vector3(-0.22, 1.42, 0.10), "tier": 0},
		{"glb": "ashen_warden_boss.glb", "title": "Ashen Warden Boss (3.15m)", "clip": "idle", "t": 0.0, "cam": Vector3(2.85, 2.25, 5.55), "look": Vector3(0.0, 1.75, 0.0), "tier": 0},
	]

	for idx in cells.size():
		var spec: Dictionary = cells[idx]
		_clear_content(content)
		var scene := _load_glb_scene(str(spec["glb"]))
		if scene == null:
			return false
		content.add_child(scene)
		var anims := _pose_model(scene, str(spec["clip"]), float(spec["t"]))
		if idx in [0, 8, 9, 10, 11]:
			print("[verify_kit_mobile] ", spec["glb"], " anims=", anims)
		var tier := int(spec["tier"])
		if tier > 0:
			_apply_armor_tier(scene, tier)

		cam.look_at_from_position(spec["cam"] as Vector3, spec["look"] as Vector3, Vector3.UP)
		lbl.text = str(spec["title"])

		await process_frame
		await process_frame
		await process_frame

		var img := sv.get_texture().get_image()
		if img.get_format() != sheet.get_format():
			img.convert(sheet.get_format())
		var col := idx % 4
		var row := idx / 4
		sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i(col * cw, row * ch))

	sv.queue_free()
	var out_path := _out_dir.path_join("kit_characters_mobile.png")
	var err := sheet.save_png(out_path)
	print("[verify_kit_mobile] Saved ", out_path, " err=", err)
	return err == OK


func _render_arena_props_sheet() -> bool:
	var cw := 600
	var ch := 600
	var sheet := Image.create(cw * 3, ch * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.04, 0.045, 0.06, 1.0))

	var stage := _make_stage_viewport(cw, ch)
	var sv: SubViewport = stage["sv"]
	var cam: Camera3D = stage["cam"]
	var content: Node3D = stage["content"]
	var lbl: Label = stage["label"]

	var props := [
		{"glb": "kit_sanctum_plinth.glb", "title": "Sanctum Plinth (3.4m dia)", "cam": Vector3(3.4, 2.5, 3.8), "look": Vector3(0.0, 0.25, 0.0), "light_pos": Vector3(0.0, 2.2, 0.0), "light_col": Color(1.0, 0.72, 0.36)},
		{"glb": "kit_wrought_brazier.glb", "title": "Wrought Brazier (1.65m)", "cam": Vector3(1.85, 1.60, 2.35), "look": Vector3(0.0, 0.85, 0.0), "light_pos": Vector3(0.0, 1.75, 0.0), "light_col": Color(1.0, 0.45, 0.14)},
		{"glb": "kit_dark_shrine.glb", "title": "Dark Shrine (3.2m)", "cam": Vector3(3.6, 2.6, 4.6), "look": Vector3(0.0, 1.65, 0.0), "light_pos": Vector3(0.0, 2.95, 0.0), "light_col": Color(0.32, 0.74, 1.0)},
		{"glb": "kit_gothic_pillar.glb", "title": "Gothic Pillar (7.0m)", "cam": Vector3(6.8, 4.4, 9.8), "look": Vector3(0.0, 3.5, 0.0), "light_pos": Vector3(1.8, 4.5, 2.2), "light_col": Color(1.0, 0.72, 0.42)},
		{"glb": "kit_gothic_arch.glb", "title": "Gothic Arch (8.5m x 7.5m)", "cam": Vector3(4.8, 4.4, 12.2), "look": Vector3(0.0, 3.7, 0.0), "light_pos": Vector3(0.0, 5.2, 2.5), "light_col": Color(1.0, 0.72, 0.42)},
		{"glb": "kit_boss_gate.glb", "title": "Boss Gate + PortcullisBars (11m x 6.5m)", "cam": Vector3(5.6, 4.0, 14.2), "look": Vector3(0.0, 3.2, 0.0), "light_pos": Vector3(0.0, 3.5, 2.5), "light_col": Color(0.96, 0.56, 0.24)},
	]

	for idx in props.size():
		var spec: Dictionary = props[idx]
		_clear_content(content)
		var scene := _load_glb_scene(str(spec["glb"]))
		if scene == null:
			return false
		content.add_child(scene)

		if str(spec["glb"]) == "kit_boss_gate.glb":
			var bars := scene.find_child("PortcullisBars", true, false)
			print("[verify_kit_mobile] kit_boss_gate PortcullisBars found=", bars != null)

		var pt := OmniLight3D.new()
		pt.position = spec["light_pos"] as Vector3
		pt.light_color = spec["light_col"] as Color
		pt.light_energy = 2.6
		pt.omni_range = 8.5
		content.add_child(pt)

		cam.look_at_from_position(spec["cam"] as Vector3, spec["look"] as Vector3, Vector3.UP)
		lbl.text = str(spec["title"])

		await process_frame
		await process_frame
		await process_frame

		var img := sv.get_texture().get_image()
		if img.get_format() != sheet.get_format():
			img.convert(sheet.get_format())
		var col := idx % 3
		var row := idx / 3
		sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i(col * cw, row * ch))

	sv.queue_free()
	var out_path := _out_dir.path_join("kit_arena_props_mobile.png")
	var err := sheet.save_png(out_path)
	print("[verify_kit_mobile] Saved ", out_path, " err=", err)
	return err == OK
