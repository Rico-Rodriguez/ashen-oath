extends SceneTree

const OUT_PATH := "res://icon.png"
const OUT_128_PATH := "res://icon_128.png"
const RENDER_SIZE := 1536
const FINAL_SIZE := 1024


func _init() -> void:
	call_deferred("_bake_icon")


func _bake_icon() -> void:
	await process_frame
	await process_frame

	var vp := SubViewport.new()
	vp.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.24, 0.32)
	env.ambient_light_energy = 0.56
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.20
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.25

	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.88, 0.72)
	key_light.light_energy = 1.10
	key_light.shadow_enabled = true
	key_light.look_at_from_position(Vector3(-2.6, 2.3, -3.0), Vector3(0.0, 1.55, 0.0), Vector3.UP)
	vp.add_child(key_light)

	var cool_rim := DirectionalLight3D.new()
	cool_rim.light_color = Color(0.46, 0.62, 0.94)
	cool_rim.light_energy = 0.68
	cool_rim.shadow_enabled = false
	cool_rim.look_at_from_position(Vector3(2.8, 2.4, 2.6), Vector3(0.0, 1.55, 0.0), Vector3.UP)
	vp.add_child(cool_rim)

	var ember_rim := OmniLight3D.new()
	ember_rim.light_color = Color(1.0, 0.44, 0.12)
	ember_rim.light_energy = 1.45
	ember_rim.omni_range = 6.5
	ember_rim.position = Vector3(-1.55, 1.48, 1.25)
	vp.add_child(ember_rim)

	var ember_under := OmniLight3D.new()
	ember_under.light_color = Color(0.98, 0.42, 0.12)
	ember_under.light_energy = 1.35
	ember_under.omni_range = 4.5
	ember_under.position = Vector3(1.05, 1.30, -1.15)
	vp.add_child(ember_under)

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 26.5
	vp.add_child(cam)

	var ps := load("res://scenes/actors/heroes/oathbreaker.tscn") as PackedScene
	if ps == null:
		printerr("Failed to load res://scenes/actors/heroes/oathbreaker.tscn")
		quit(1)
		return

	var actor := ps.instantiate() as ActorVisual
	vp.add_child(actor)
	actor.ensure_initialized()
	HeroRigDresser.dress(
		actor,
		"oathbreaker",
		3,
		"zweihander",
		"",
		true,
		Color(1.0, 0.74, 0.26, 1.0)
	)
	for n in actor.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var nm := String(mi.name)
		if nm == "Slot_Plume":
			var pm := mi.get_surface_override_material(0)
			if pm is ShaderMaterial:
				(pm as ShaderMaterial).set_shader_parameter("cloth_color", Color(0.60, 0.48, 0.36))
				(pm as ShaderMaterial).set_shader_parameter("trim_color", Color(0.42, 0.32, 0.22))
		elif nm == "Slot_Cloak":
			mi.visible = false
	actor.play_anim("idle", 1.0, true)
	if actor.anim_player != null:
		actor.anim_player.play(actor.anim_player.current_animation, 0.0)
		actor.anim_player.advance(0.15)

	var focus := Vector3(0.0, 1.54, 0.0)
	if actor.skeleton != null:
		var c_idx := actor.skeleton.find_bone("chest")
		var h_idx := actor.skeleton.find_bone("head")
		if c_idx >= 0 and h_idx >= 0:
			var cp := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(c_idx).origin
			var hp := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(h_idx).origin
			focus = cp.lerp(hp, 0.68)

	ember_rim.position = focus + Vector3(-1.45, -0.08, 1.15)
	ember_under.position = focus + Vector3(1.05, -0.22, -1.15)
	cam.look_at_from_position(focus + Vector3(-0.34, 0.09, -1.90), focus + Vector3(0.0, 0.04, 0.0), Vector3.UP)

	for _i in range(8):
		await RenderingServer.frame_post_draw

	var fg := vp.get_texture().get_image()
	fg.convert(Image.FORMAT_RGBA8)
	fg.resize(FINAL_SIZE, FINAL_SIZE, Image.INTERPOLATE_LANCZOS)

	var out := _compose_obsidian_icon(fg)
	var abs_out := ProjectSettings.globalize_path(OUT_PATH)
	var err := out.save_png(abs_out)
	if err != OK:
		printerr("Failed to save %s: %d" % [abs_out, err])
		quit(1)
		return

	var out_128 := out.duplicate() as Image
	out_128.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var abs_128 := ProjectSettings.globalize_path(OUT_128_PATH)
	var err_128 := out_128.save_png(abs_128)
	if err_128 != OK:
		printerr("Failed to save %s: %d" % [abs_128, err_128])
		quit(1)
		return

	print("Baked app icon: %s (%dx%d, format=%d) and %s (128x128)" % [OUT_PATH, out.get_width(), out.get_height(), out.get_format(), OUT_128_PATH])

	root.remove_child(vp)
	vp.free()
	await process_frame
	quit(0)


static func _compose_obsidian_icon(fg: Image) -> Image:
	var w := fg.get_width()
	var h := fg.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var center := Color(0.11, 0.095, 0.125)
	var edge := Color(0.026, 0.026, 0.038)
	var ember := Color(0.86, 0.32, 0.08)
	var ember_core := Color(1.0, 0.54, 0.16)
	var inv_w := 1.0 / float(w)
	var inv_h := 1.0 / float(h)

	for y in range(h):
		var ny := (float(y) + 0.5) * inv_h
		var vy := (ny - 0.5) * 2.0
		var ey := (ny - 0.48) * 2.0
		for x in range(w):
			var nx := (float(x) + 0.5) * inv_w
			var vx := (nx - 0.5) * 2.0
			var ex := (nx - 0.50) * 2.0

			var rad := sqrt(vx * vx + vy * vy)
			var vig := clampf(rad / 1.32, 0.0, 1.0)
			vig = vig * vig
			var bg := center.lerp(edge, vig)

			var ember_dist := sqrt(ex * ex + ey * ey)
			var halo := clampf(1.0 - ember_dist / 1.08, 0.0, 1.0)
			var halo_soft := halo * halo * 0.64
			var halo_inner := pow(clampf(1.0 - ember_dist / 0.62, 0.0, 1.0), 2.2) * 0.34
			bg = Color(
				minf(1.0, bg.r + ember.r * halo_soft + ember_core.r * halo_inner),
				minf(1.0, bg.g + ember.g * halo_soft + ember_core.g * halo_inner),
				minf(1.0, bg.b + ember.b * halo_soft + ember_core.b * halo_inner)
			)

			var px := fg.get_pixel(x, y)
			var a := px.a
			var blended := bg.lerp(Color(px.r, px.g, px.b), a)

			var outer_vig := clampf((rad - 0.72) / 0.68, 0.0, 1.0)
			outer_vig = outer_vig * outer_vig * 0.44
			blended = blended.lerp(Color(0.022, 0.022, 0.032), outer_vig)
			blended.a = 1.0
			out.set_pixel(x, y, blended)

	return out
