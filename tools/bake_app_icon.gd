extends SceneTree

const OUT_PATH := "res://icon.png"
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
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.38
	env.glow_bloom = 0.08

	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.88, 0.72)
	key_light.light_energy = 2.45
	key_light.shadow_enabled = true
	key_light.look_at_from_position(Vector3(-2.4, 3.6, -3.2), Vector3(0.0, 1.55, 0.0), Vector3.UP)
	vp.add_child(key_light)

	var cool_rim := DirectionalLight3D.new()
	cool_rim.light_color = Color(0.46, 0.62, 0.94)
	cool_rim.light_energy = 1.45
	cool_rim.shadow_enabled = false
	cool_rim.look_at_from_position(Vector3(2.8, 2.8, 2.6), Vector3(0.0, 1.55, 0.0), Vector3.UP)
	vp.add_child(cool_rim)

	var ember_rim := OmniLight3D.new()
	ember_rim.light_color = Color(1.0, 0.50, 0.14)
	ember_rim.light_energy = 2.65
	ember_rim.omni_range = 6.5
	ember_rim.position = Vector3(-1.55, 1.48, 1.25)
	vp.add_child(ember_rim)

	var ember_under := OmniLight3D.new()
	ember_under.light_color = Color(0.98, 0.42, 0.12)
	ember_under.light_energy = 1.85
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
	actor.play_anim("idle", 1.0, true)
	if actor.anim_player != null:
		actor.anim_player.advance(0.05)

	cam.look_at_from_position(Vector3(-0.46, 1.72, -1.94), Vector3(0.01, 1.67, 0.0), Vector3.UP)

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

	print("Baked app icon: %s (%dx%d, format=%d)" % [OUT_PATH, out.get_width(), out.get_height(), out.get_format()])

	root.remove_child(vp)
	vp.free()
	await process_frame
	quit(0)


static func _compose_obsidian_icon(fg: Image) -> Image:
	var w := fg.get_width()
	var h := fg.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var center := Color(0.11, 0.10, 0.13)
	var edge := Color(0.032, 0.032, 0.044)
	var ember := Color(0.68, 0.28, 0.08)
	var inv_w := 1.0 / float(w)
	var inv_h := 1.0 / float(h)

	for y in range(h):
		var ny := (float(y) + 0.5) * inv_h
		var vy := (ny - 0.5) * 2.0
		var ey := (ny - 0.44) * 2.0
		for x in range(w):
			var nx := (float(x) + 0.5) * inv_w
			var vx := (nx - 0.5) * 2.0
			var ex := (nx - 0.50) * 2.0

			var rad := sqrt(vx * vx + vy * vy)
			var vig := clampf(rad / 1.32, 0.0, 1.0)
			vig = vig * vig
			var bg := center.lerp(edge, vig)

			var ember_dist := sqrt(ex * ex + ey * ey)
			var halo := clampf(1.0 - ember_dist / 0.92, 0.0, 1.0)
			halo = halo * halo * 0.56
			bg = Color(
				minf(1.0, bg.r + ember.r * halo),
				minf(1.0, bg.g + ember.g * halo),
				minf(1.0, bg.b + ember.b * halo)
			)

			var px := fg.get_pixel(x, y)
			var a := px.a
			var blended := bg.lerp(Color(px.r, px.g, px.b), a)

			var outer_vig := clampf((rad - 0.72) / 0.68, 0.0, 1.0)
			outer_vig = outer_vig * outer_vig * 0.42
			blended = blended.lerp(Color(0.025, 0.025, 0.035), outer_vig)
			blended.a = 1.0
			out.set_pixel(x, y, blended)

	return out
