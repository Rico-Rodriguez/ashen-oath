extends SceneTree

const GOLD := Color(1.0, 0.74, 0.26, 1.0)
const BLUE := Color(0.26, 0.68, 1.0, 1.0)
const GREEN := Color(0.28, 0.92, 0.46, 1.0)
const CRIMSON := Color(0.98, 0.22, 0.20, 1.0)

var _out_dir: String = ""

const HERO_GRID := [
	[
		{"scene": "res://scenes/actors/heroes/oathbreaker.tscn", "class": "oathbreaker", "tier": 1, "wpn": "bastardsword", "off": "shield_round", "plume": false, "lantern": GOLD, "back": false, "move": 0.0},
		{"scene": "res://scenes/actors/heroes/oathbreaker.tscn", "class": "oathbreaker", "tier": 2, "wpn": "zweihander", "off": "", "plume": true, "lantern": BLUE, "back": false, "move": 0.25},
		{"scene": "res://scenes/actors/heroes/oathbreaker.tscn", "class": "oathbreaker", "tier": 3, "wpn": "bastardsword", "off": "shield_tower", "plume": true, "lantern": GOLD, "back": false, "move": 0.35},
		{"scene": "res://scenes/actors/heroes/oathbreaker.tscn", "class": "oathbreaker", "tier": 4, "wpn": "zweihander", "off": "", "plume": true, "lantern": CRIMSON, "back": false, "move": 0.5},
		{"scene": "res://scenes/actors/heroes/oathbreaker.tscn", "class": "oathbreaker", "tier": 4, "wpn": "zweihander", "off": "shield_heater", "plume": true, "lantern": GOLD, "back": true, "move": 0.65},
	],
	[
		{"scene": "res://scenes/actors/heroes/battlemage.tscn", "class": "battlemage", "tier": 1, "wpn": "runed_staff", "off": "", "plume": false, "lantern": BLUE, "back": false, "move": 0.0},
		{"scene": "res://scenes/actors/heroes/battlemage.tscn", "class": "battlemage", "tier": 2, "wpn": "runed_staff", "off": "shield_round", "plume": true, "lantern": GREEN, "back": false, "move": 0.25},
		{"scene": "res://scenes/actors/heroes/battlemage.tscn", "class": "battlemage", "tier": 3, "wpn": "runed_staff", "off": "", "plume": true, "lantern": GOLD, "back": false, "move": 0.35},
		{"scene": "res://scenes/actors/heroes/battlemage.tscn", "class": "battlemage", "tier": 4, "wpn": "runed_staff", "off": "", "plume": true, "lantern": CRIMSON, "back": false, "move": 0.5},
		{"scene": "res://scenes/actors/heroes/battlemage.tscn", "class": "battlemage", "tier": 3, "wpn": "runed_staff", "off": "", "plume": true, "lantern": BLUE, "back": true, "move": 0.65},
	],
	[
		{"scene": "res://scenes/actors/heroes/revenant.tscn", "class": "revenant", "tier": 1, "wpn": "bastardsword", "off": "shield_heater", "plume": false, "lantern": GREEN, "back": false, "move": 0.0},
		{"scene": "res://scenes/actors/heroes/revenant.tscn", "class": "revenant", "tier": 2, "wpn": "halberd", "off": "", "plume": true, "lantern": BLUE, "back": false, "move": 0.25},
		{"scene": "res://scenes/actors/heroes/revenant.tscn", "class": "revenant", "tier": 3, "wpn": "halberd", "off": "", "plume": true, "lantern": GOLD, "back": false, "move": 0.35},
		{"scene": "res://scenes/actors/heroes/revenant.tscn", "class": "revenant", "tier": 4, "wpn": "zweihander", "off": "", "plume": true, "lantern": CRIMSON, "back": false, "move": 0.5},
		{"scene": "res://scenes/actors/heroes/revenant.tscn", "class": "revenant", "tier": 4, "wpn": "halberd", "off": "shield_heater", "plume": true, "lantern": CRIMSON, "back": true, "move": 0.65},
	],
]

const ENEMY_LIST := [
	"res://scenes/actors/enemies/hollow_ghoul.tscn",
	"res://scenes/actors/enemies/crypt_batlord.tscn",
	"res://scenes/actors/enemies/ash_scorpion.tscn",
	"res://scenes/actors/enemies/stone_gargoyle.tscn",
	"res://scenes/actors/enemies/dread_golem.tscn",
	"res://scenes/actors/enemies/infernal_minotaur.tscn",
	"res://scenes/actors/enemies/barrow_troll.tscn",
	"res://scenes/actors/enemies/blight_werewolf.tscn",
]

const LOGICAL_ANIMS := ["idle", "run", "walk", "attack", "attack2", "skill_cast", "dash", "hit", "death"]


func _make_stage_world(cell_size: Vector2i) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = cell_size
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.058, 0.072)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.26, 0.33)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.12

	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.95, 0.88)
	key_light.light_energy = 2.1
	key_light.shadow_enabled = true
	key_light.look_at_from_position(Vector3(-2.4, 4.2, -3.5), Vector3(0.0, 1.0, 0.0), Vector3.UP)
	vp.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.light_color = Color(0.55, 0.68, 0.92)
	rim_light.light_energy = 1.15
	rim_light.shadow_enabled = false
	rim_light.look_at_from_position(Vector3(2.5, 3.2, 3.4), Vector3(0.0, 1.1, 0.0), Vector3.UP)
	vp.add_child(rim_light)

	var floor_mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.3
	cyl.height = 0.08
	cyl.radial_segments = 32
	floor_mi.mesh = cyl
	floor_mi.position = Vector3(0.0, -0.04, 0.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.11, 0.11, 0.13)
	floor_mat.roughness = 0.82
	floor_mat.metallic = 0.08
	floor_mi.material_override = floor_mat
	vp.add_child(floor_mi)

	var fwd_mark := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.28, 0.02, 0.32)
	fwd_mark.mesh = prism
	fwd_mark.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	fwd_mark.position = Vector3(0.0, 0.01, -1.15)
	var fwd_mat := StandardMaterial3D.new()
	fwd_mat.albedo_color = Color(0.42, 0.34, 0.20)
	fwd_mat.roughness = 0.65
	fwd_mark.material_override = fwd_mat
	vp.add_child(fwd_mark)

	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)

	return {"vp": vp, "cam": cam, "key": key_light, "rim": rim_light}


func _init() -> void:
	var user_args := OS.get_cmdline_user_args()
	_out_dir = str(user_args[0]).strip_edges() if (not user_args.is_empty() and str(user_args[0]).strip_edges() != "") else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	call_deferred("_run_verification")


func _run_verification() -> void:
	await process_frame
	await process_frame

	var h_cell := Vector2i(400, 480)
	var hero_sheet := Image.create(h_cell.x * 5, h_cell.y * 3, false, Image.FORMAT_RGBA8)
	var hero_stages: Array = []

	for r in range(3):
		for c in range(5):
			var cfg: Dictionary = HERO_GRID[r][c]
			var st := _make_stage_world(h_cell)
			var ps := load(str(cfg["scene"])) as PackedScene
			var actor := ps.instantiate() as ActorVisual
			st["vp"].add_child(actor)
			actor.ensure_initialized()
			HeroRigDresser.dress(
				actor,
				str(cfg["class"]),
				int(cfg["tier"]),
				str(cfg["wpn"]),
				str(cfg["off"]),
				bool(cfg["plume"]),
				cfg["lantern"] as Color
			)
			actor.set_move_blend(float(cfg["move"]))
			actor.play_anim("idle", 1.0, true)

			var cam: Camera3D = st["cam"]
			var back_view := bool(cfg["back"])
			if not back_view:
				cam.look_at_from_position(Vector3(-1.45, 1.62, -3.35), Vector3(0.0, 1.12, 0.0), Vector3.UP)
			else:
				cam.look_at_from_position(Vector3(1.45, 1.65, 3.35), Vector3(0.0, 1.12, 0.0), Vector3.UP)
				(st["key"] as DirectionalLight3D).look_at_from_position(Vector3(2.2, 4.2, 3.5), Vector3(0.0, 1.0, 0.0), Vector3.UP)
				(st["rim"] as DirectionalLight3D).look_at_from_position(Vector3(-2.4, 3.0, -3.2), Vector3(0.0, 1.0, 0.0), Vector3.UP)

			if c == 1 or c == 4:
				print("HERO [%s T%d %s] tip=%s cast=%s" % [
					cfg["class"], cfg["tier"], cfg["wpn"],
					actor.get_blade_tip_global().snappedf(0.01),
					actor.get_cast_origin_global().snappedf(0.01),
				])
			hero_stages.append({"st": st, "r": r, "c": c, "actor": actor})

	var e_cell := Vector2i(480, 540)
	var enemy_sheet := Image.create(e_cell.x * 4, e_cell.y * 2, false, Image.FORMAT_RGBA8)
	var enemy_stages: Array = []

	for idx in ENEMY_LIST.size():
		var r := idx / 4
		var c := idx % 4
		var st := _make_stage_world(e_cell)
		var ps := load(ENEMY_LIST[idx]) as PackedScene
		var actor := ps.instantiate() as ActorVisual
		st["vp"].add_child(actor)
		actor.ensure_initialized()

		for anim_key in LOGICAL_ANIMS:
			actor.play_anim(anim_key, 1.0, true)
		actor.play_anim("idle", 1.0, true)

		var h := actor.height_meters
		var dist := maxf(3.3, h * 1.62)
		var cam: Camera3D = st["cam"]
		cam.look_at_from_position(Vector3(-dist * 0.36, h * 0.72, -dist), Vector3(0.0, h * 0.48, 0.0), Vector3.UP)
		print("ENEMY [%s] h=%.2f pos=%s" % [actor.actor_id, h, actor.global_position.snappedf(0.01)])
		enemy_stages.append({"st": st, "r": r, "c": c, "actor": actor})

	for _frame in range(6):
		await RenderingServer.frame_post_draw

	for item in hero_stages:
		var vp: SubViewport = item["st"]["vp"]
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		hero_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, h_cell), Vector2i(int(item["c"]) * h_cell.x, int(item["r"]) * h_cell.y))

	for item in enemy_stages:
		var vp: SubViewport = item["st"]["vp"]
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		enemy_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, e_cell), Vector2i(int(item["c"]) * e_cell.x, int(item["r"]) * e_cell.y))

	var hero_out := _out_dir.path_join("phase1_heroes_tiers.png")
	var enemy_out := _out_dir.path_join("phase1_enemies.png")
	hero_sheet.save_png(hero_out)
	enemy_sheet.save_png(enemy_out)
	print("Saved ", hero_out)
	print("Saved ", enemy_out)

	for item in hero_stages:
		(item["st"]["vp"] as Node).queue_free()
	for item in enemy_stages:
		(item["st"]["vp"] as Node).queue_free()
	await process_frame
	quit(0)
