class_name BarrowArenaBuilder
extends RefCounted

const SPAWN_POS := Vector3(0.0, 0.0, 36.0)
const SHRINE_POS := Vector3(0.0, 0.0, -8.5)
const BOSS_GATE_Z := -32.0
const BOSS_CENTER := Vector3(0.0, 0.0, -45.0)
const BOSS_RADIUS := 14.0
const FLANK_SIDES: Array[float] = [-1.0, 1.0]
const VFX_NOISE_TEX_PATH := "res://assets/textures/vfx_noise_tile.png"
const CATHEDRAL_IBL_PANORAMA_PATH := "res://assets/textures/cathedral_ibl_panorama.png"

static var _cached_panorama_sky: Sky = null

const CLEARING_SPECS := [
	{"center": Vector3(0.0, 0.0, 22.0), "radius": 10.5, "count": 6},
	{"center": Vector3(0.0, 0.0, 2.0), "radius": 11.5, "count": 7},
	{"center": Vector3(0.0, 0.0, -19.0), "radius": 12.0, "count": 8},
]


static func build_zone(parent: Node3D, zone_def: ZoneDef, seed_val: int = 1337) -> Dictionary:
	var zd := zone_def
	if zd == null:
		zd = ZoneDef.new()
		zd.zone_id = "fringe"
		zd.fog_color = Color(0.09, 0.11, 0.14, 1.0)
		zd.ambient_color = Color(0.26, 0.30, 0.36, 1.0)
		zd.ground_tint = Color(0.28, 0.27, 0.25, 1.0)

	var profile := _biome_profile(zd)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 1337
	var headless := DisplayServer.get_name() == "headless"

	var clearings := _build_clearings_data(rng)
	var gate_refs := {"root": null, "arch_visuals": null, "bars": null, "ward": null, "ground_seal_mat": null, "collider": null, "light": null}

	if parent != null and is_instance_valid(parent):
		var cache := _make_build_cache(profile, headless)
		_configure_or_create_lighting(parent, profile)
		_build_ground(parent, profile, headless)
		_build_boss_gate(parent, gate_refs, profile, cache, headless)
		if not headless:
			_build_shrine_sanctuary(parent, profile, cache)
			_build_ruins_and_braziers(parent, profile, cache, rng)
			_build_perimeter_biome(parent, profile, cache, rng)
			if str(profile["id"]) == "rift":
				_build_rift_ember_ash(parent)

	var layout := {
		"spawn_pos": SPAWN_POS,
		"clearings": clearings,
		"shrine_pos": SHRINE_POS,
		"boss_gate_z": BOSS_GATE_Z,
		"boss_gate_locked": true,
		"boss_center": BOSS_CENTER,
		"boss_radius": BOSS_RADIUS,
		"biome_id": str(profile["id"]),
	}

	var layout_owner: Node = gate_refs["root"] as Node
	if layout_owner == null and parent != null and is_instance_valid(parent):
		layout_owner = parent
	var wr_owner: WeakRef = weakref(layout_owner) if layout_owner != null else null
	if layout_owner != null:
		layout_owner.set_meta("_barrow_layout_ref", layout)
	var wr_parent: WeakRef = weakref(parent) if parent != null and is_instance_valid(parent) else null
	var wr_arch: WeakRef = weakref(gate_refs["arch_visuals"]) if gate_refs["arch_visuals"] != null else null
	var wr_col: WeakRef = weakref(gate_refs["collider"]) if gate_refs["collider"] != null else null
	var wr_ward: WeakRef = weakref(gate_refs["ward"]) if gate_refs["ward"] != null else null
	var wr_ground_seal_mat: WeakRef = weakref(gate_refs["ground_seal_mat"]) if gate_refs["ground_seal_mat"] != null else null
	var wr_light: WeakRef = weakref(gate_refs["light"]) if gate_refs["light"] != null else null
	var wr_bars: WeakRef = weakref(gate_refs["bars"]) if gate_refs["bars"] != null else null

	layout["set_boss_gate_arch_visible"] = func(is_vis: bool) -> void:
		if wr_arch != null:
			var arch_node := wr_arch.get_ref() as Node3D
			if arch_node != null and is_instance_valid(arch_node):
				arch_node.visible = is_vis

	layout["unlock_boss_gate"] = func() -> void:
		if wr_owner != null:
			var owner_node := wr_owner.get_ref() as Node
			if owner_node != null and owner_node.has_meta("_barrow_layout_ref"):
				var d: Dictionary = owner_node.get_meta("_barrow_layout_ref")
				if not bool(d.get("boss_gate_locked", false)):
					return
				d["boss_gate_locked"] = false
		if wr_col != null:
			var col_shape := wr_col.get_ref() as CollisionShape3D
			if col_shape != null and is_instance_valid(col_shape):
				col_shape.disabled = true
				var sb := col_shape.get_parent() as StaticBody3D
				if sb != null:
					sb.collision_layer = 0
		if wr_ward != null:
			var ward := wr_ward.get_ref() as Node3D
			if ward != null and is_instance_valid(ward):
				ward.visible = false
		if wr_ground_seal_mat != null:
			var gmat := wr_ground_seal_mat.get_ref() as ShaderMaterial
			if gmat != null:
				gmat.set_shader_parameter("energy_color", Color(0.42, 0.78, 1.0, 1.0))
				gmat.set_shader_parameter("hdr_gain", 1.35)
		if wr_light != null:
			var glight := wr_light.get_ref() as OmniLight3D
			if glight != null and is_instance_valid(glight):
				glight.light_color = Color(0.42, 0.78, 1.0)
				glight.light_energy = 1.4
		if wr_bars != null:
			var bars := wr_bars.get_ref() as Node3D
			if bars != null and is_instance_valid(bars):
				var open_y := 4.35 if bars.name == "PortcullisBars" else -4.4
				if bars.is_inside_tree() and not headless:
					var tw := bars.create_tween()
					tw.tween_property(bars, "position:y", open_y, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				else:
					bars.position.y = open_y
					bars.visible = false
		if wr_parent != null:
			var p_node := wr_parent.get_ref() as Node3D
			if p_node != null and is_instance_valid(p_node) and p_node.is_inside_tree():
				var ad := p_node.get_tree().root.get_node_or_null("AudioDirector")
				if ad != null and ad.has_method("sfx"):
					ad.call("sfx", "unlock_start")
					ad.call("sfx", "boss_roar")

	return layout


static func clamp_position(pos: Vector3, layout: Dictionary) -> Vector3:
	var z := clampf(pos.z, -58.0, 40.0)
	var gate_z := float(layout.get("boss_gate_z", BOSS_GATE_Z))
	var locked := bool(layout.get("boss_gate_locked", false))
	if locked and z < -31.2:
		z = -31.2

	var max_x := 13.5
	if z < gate_z:
		max_x = 14.5
		var b_center: Vector3 = layout.get("boss_center", BOSS_CENTER)
		var b_rad := maxf(float(layout.get("boss_radius", BOSS_RADIUS)), 14.0)
		var x_clamped := clampf(pos.x, -max_x, max_x)
		if z < b_center.z:
			var dz := z - b_center.z
			var rad_cap := b_rad + 0.5
			if x_clamped * x_clamped + dz * dz > rad_cap * rad_cap:
				var vec := Vector2(x_clamped, dz).normalized() * rad_cap
				return Vector3(clampf(vec.x, -max_x, max_x), 0.0, clampf(b_center.z + vec.y, -58.0, 40.0))
		return Vector3(x_clamped, 0.0, z)

	var c_boost := 0.0
	for spec in CLEARING_SPECS:
		var cz: float = (spec["center"] as Vector3).z
		var cr: float = float(spec["radius"])
		var d := absf(z - cz)
		c_boost = maxf(c_boost, 1.0 - smoothstep(cr * 0.55, cr * 1.15, d))
	var corridor_half_w := lerpf(10.5, 13.5, c_boost)
	return Vector3(clampf(pos.x, -corridor_half_w, corridor_half_w), 0.0, z)


static func _biome_profile(zd: ZoneDef) -> Dictionary:
	var zid := zd.zone_id if zd != null and zd.zone_id != "" else "fringe"
	match zid:
		"weald":
			return {
				"id": "weald",
				"fog_color": Color(0.055, 0.135, 0.085, 1.0),
				"fog_density": 0.0155,
				"fog_energy": 0.96,
				"ambient_color": Color(0.19, 0.34, 0.23, 1.0),
				"ambient_energy": 0.88,
				"moon_color": Color(0.60, 0.90, 0.68, 1.0),
				"moon_energy": 1.38,
				"moon_rot": Vector3(-50.0, -24.0, 0.0),
				"ground_tint": Color(0.22, 0.35, 0.22, 1.0),
				"tex_forest_c": "res://assets/textures/moss_color.jpg",
				"tex_forest_n": "res://assets/textures/moss_normal.jpg",
				"tex_dirt_c": "res://assets/textures/ground_dirt_color.jpg",
				"tex_dirt_n": "res://assets/textures/ground_dirt_normal.jpg",
				"tex_stone_c": "res://assets/textures/lush_color.jpg",
				"tex_stone_n": "res://assets/textures/lush_normal.jpg",
				"stone_albedo": Color(0.32, 0.42, 0.33, 1.0),
				"iron_albedo": Color(0.10, 0.14, 0.11, 1.0),
				"sky_clerestory": Color(0.48, 0.92, 0.64, 1.0),
				"sky_brazier": Color(0.76, 0.88, 0.28, 1.0),
				"shrine_rune": Color(0.38, 0.95, 0.54, 1.0),
				"gate_ward": Color(0.46, 0.96, 0.34, 1.0),
				"brazier_primary": {
					"light": Color(0.42, 0.96, 0.44, 1.0),
					"coals": Color(0.95, 3.4, 0.85, 1.0),
					"core_hdr": Vector3(2.2, 6.4, 2.0),
					"mid_flame": Vector3(0.50, 2.4, 0.62),
					"soot": 0.42,
				},
				"brazier_secondary": {
					"light": Color(0.88, 0.76, 0.24, 1.0),
					"coals": Color(2.9, 2.3, 0.36, 1.0),
					"core_hdr": Vector3(4.9, 4.3, 0.85),
					"mid_flame": Vector3(1.85, 1.45, 0.18),
					"soot": 0.46,
				},
			}
		"catacombs":
			return {
				"id": "catacombs",
				"fog_color": Color(0.055, 0.072, 0.165, 1.0),
				"fog_density": 0.0145,
				"fog_energy": 0.94,
				"ambient_color": Color(0.22, 0.25, 0.44, 1.0),
				"ambient_energy": 0.90,
				"moon_color": Color(0.62, 0.72, 1.0, 1.0),
				"moon_energy": 1.48,
				"moon_rot": Vector3(-55.0, 32.0, 0.0),
				"ground_tint": Color(0.22, 0.24, 0.40, 1.0),
				"tex_forest_c": "res://assets/textures/path_color.jpg",
				"tex_forest_n": "res://assets/textures/path_normal.jpg",
				"tex_dirt_c": "res://assets/textures/rock_color.jpg",
				"tex_dirt_n": "res://assets/textures/rock_normal.jpg",
				"tex_stone_c": "res://assets/textures/path_color.jpg",
				"tex_stone_n": "res://assets/textures/path_normal.jpg",
				"stone_albedo": Color(0.35, 0.38, 0.54, 1.0),
				"iron_albedo": Color(0.11, 0.12, 0.19, 1.0),
				"sky_clerestory": Color(0.44, 0.66, 1.0, 1.0),
				"sky_brazier": Color(0.34, 0.62, 1.0, 1.0),
				"shrine_rune": Color(0.46, 0.62, 1.0, 1.0),
				"gate_ward": Color(0.36, 0.56, 1.0, 1.0),
				"brazier_primary": {
					"light": Color(0.28, 0.62, 1.0, 1.0),
					"coals": Color(0.62, 1.9, 4.4, 1.0),
					"core_hdr": Vector3(1.45, 3.9, 7.4),
					"mid_flame": Vector3(0.30, 1.05, 2.9),
					"soot": 0.30,
				},
				"brazier_secondary": {
					"light": Color(0.44, 0.48, 1.0, 1.0),
					"coals": Color(1.1, 1.3, 4.2, 1.0),
					"core_hdr": Vector3(2.4, 2.9, 7.0),
					"mid_flame": Vector3(0.62, 0.72, 2.6),
					"soot": 0.34,
				},
			}
		"rift":
			return {
				"id": "rift",
				"fog_color": Color(0.16, 0.052, 0.045, 1.0),
				"fog_density": 0.0150,
				"fog_energy": 0.96,
				"ambient_color": Color(0.42, 0.19, 0.15, 1.0),
				"ambient_energy": 0.88,
				"moon_color": Color(1.0, 0.60, 0.42, 1.0),
				"moon_energy": 1.58,
				"moon_rot": Vector3(-48.0, -28.0, 0.0),
				"ground_tint": Color(0.40, 0.21, 0.18, 1.0),
				"tex_forest_c": "res://assets/textures/rock_color.jpg",
				"tex_forest_n": "res://assets/textures/rock_normal.jpg",
				"tex_dirt_c": "res://assets/textures/ground_dirt_color.jpg",
				"tex_dirt_n": "res://assets/textures/ground_dirt_normal.jpg",
				"tex_stone_c": "res://assets/textures/rock_color.jpg",
				"tex_stone_n": "res://assets/textures/rock_normal.jpg",
				"stone_albedo": Color(0.32, 0.22, 0.21, 1.0),
				"iron_albedo": Color(0.14, 0.09, 0.09, 1.0),
				"sky_clerestory": Color(0.95, 0.50, 0.32, 1.0),
				"sky_brazier": Color(1.0, 0.36, 0.10, 1.0),
				"shrine_rune": Color(1.0, 0.42, 0.14, 1.0),
				"gate_ward": Color(1.0, 0.24, 0.08, 1.0),
				"brazier_primary": {
					"light": Color(1.0, 0.34, 0.08, 1.0),
					"coals": Color(5.2, 1.35, 0.18, 1.0),
					"core_hdr": Vector3(8.4, 2.8, 0.44),
					"mid_flame": Vector3(3.5, 0.62, 0.08),
					"soot": 0.38,
				},
				"brazier_secondary": {
					"light": Color(1.0, 0.48, 0.12, 1.0),
					"coals": Color(4.8, 1.8, 0.24, 1.0),
					"core_hdr": Vector3(7.6, 3.4, 0.58),
					"mid_flame": Vector3(3.0, 0.85, 0.12),
					"soot": 0.32,
				},
			}
		_:
			return {
				"id": "fringe",
				"fog_color": Color(0.07, 0.08, 0.12, 1.0),
				"fog_density": 0.014,
				"fog_energy": 0.88,
				"ambient_color": Color(0.26, 0.31, 0.40, 1.0),
				"ambient_energy": 0.84,
				"moon_color": Color(0.74, 0.84, 0.98, 1.0),
				"moon_energy": 1.60,
				"moon_rot": Vector3(-52.0, 28.0, 0.0),
				"ground_tint": Color(0.24, 0.25, 0.28, 1.0),
				"tex_forest_c": "res://assets/textures/ground_forest_color.jpg",
				"tex_forest_n": "res://assets/textures/ground_forest_normal.jpg",
				"tex_dirt_c": "res://assets/textures/ground_dirt_color.jpg",
				"tex_dirt_n": "res://assets/textures/ground_dirt_normal.jpg",
				"tex_stone_c": "res://assets/textures/rock_color.jpg",
				"tex_stone_n": "res://assets/textures/rock_normal.jpg",
				"stone_albedo": Color(0.42, 0.45, 0.50, 1.0),
				"iron_albedo": Color(0.11, 0.12, 0.14, 1.0),
				"sky_clerestory": Color(0.45, 0.62, 1.0, 1.0),
				"sky_brazier": Color(1.0, 0.50, 0.16, 1.0),
				"shrine_rune": Color(0.32, 0.72, 1.0, 1.0),
				"gate_ward": Color(0.96, 0.18, 0.14, 1.0),
				"brazier_primary": {
					"light": Color(1.0, 0.58, 0.22, 1.0),
					"coals": Color(3.6, 1.35, 0.24, 1.0),
					"core_hdr": Vector3(5.8, 2.7, 0.62),
					"mid_flame": Vector3(2.4, 0.55, 0.10),
					"soot": 0.35,
				},
				"brazier_secondary": {
					"light": Color(1.0, 0.52, 0.18, 1.0),
					"coals": Color(3.4, 1.20, 0.20, 1.0),
					"core_hdr": Vector3(5.4, 2.4, 0.52),
					"mid_flame": Vector3(2.2, 0.48, 0.09),
					"soot": 0.38,
				},
			}


static func _make_build_cache(profile: Dictionary, headless: bool) -> Dictionary:
	var cache := {"prop_mats": {}}
	if headless:
		return cache

	var base_stone := profile["stone_albedo"] as Color
	cache["stone_mat"] = _make_stone_material(base_stone, 0.82, 0.85)
	cache["dark_stone_mat"] = _make_stone_material(base_stone.darkened(0.42), 0.78, 0.90)
	cache["iron_mat"] = _make_iron_material(profile["iron_albedo"] as Color)

	cache["kit_pillar"] = load("res://assets/models/kit/kit_gothic_pillar.glb") as PackedScene
	cache["kit_arch"] = load("res://assets/models/kit/kit_gothic_arch.glb") as PackedScene
	cache["kit_brazier"] = load("res://assets/models/kit/kit_wrought_brazier.glb") as PackedScene
	cache["kit_boss_gate"] = load("res://assets/models/kit/kit_boss_gate.glb") as PackedScene

	var flame_quad := QuadMesh.new()
	flame_quad.size = Vector2(0.76, 1.08)
	cache["brazier_flame_mesh"] = flame_quad

	var flame_sh := load("res://shaders/vfx_smokey_flame.gdshader") as Shader
	var noise_tex := load(VFX_NOISE_TEX_PATH) as Texture2D
	for slot_key in ["brazier_primary", "brazier_secondary"]:
		var bspec: Dictionary = profile[slot_key]
		if flame_sh != null:
			var fmat := ShaderMaterial.new()
			fmat.shader = flame_sh
			if noise_tex != null:
				fmat.set_shader_parameter("noise_tex", noise_tex)
			fmat.set_shader_parameter("billboard_mode", true)
			fmat.set_shader_parameter("soot_dominance", float(bspec["soot"]))
			fmat.set_shader_parameter("core_hdr", bspec["core_hdr"] as Vector3)
			fmat.set_shader_parameter("mid_flame", bspec["mid_flame"] as Vector3)
			fmat.set_shader_parameter("scroll_speed", 2.9)
			cache[slot_key + "_flame_mat"] = fmat

	return cache


static func _build_clearings_data(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for idx in CLEARING_SPECS.size():
		var spec: Dictionary = CLEARING_SPECS[idx]
		var center: Vector3 = spec["center"]
		var radius := float(spec["radius"])
		var count := int(spec["count"])
		var spawn_points: Array[Vector3] = []
		var phase_offset := rng.randf_range(0.0, TAU)
		for k in range(count):
			var ang := phase_offset + (TAU * float(k)) / float(count) + rng.randf_range(-0.16, 0.16)
			var dist := radius * rng.randf_range(0.52, 0.76)
			spawn_points.append(Vector3(center.x + cos(ang) * dist, 0.0, center.z + sin(ang) * dist))
		result.append({
			"index": idx,
			"center": center,
			"pos": center,
			"radius": radius,
			"spawn_points": spawn_points,
		})
	return result


static func _configure_or_create_lighting(parent: Node3D, profile: Dictionary) -> void:
	var search_root: Node = parent.get_parent() if parent.get_parent() != null else parent
	var we: WorldEnvironment = null
	var moon: DirectionalLight3D = null

	if search_root != null:
		we = search_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if we == null:
			var found_we := search_root.find_children("*", "WorldEnvironment", true, false)
			if not found_we.is_empty():
				we = found_we[0] as WorldEnvironment
		moon = search_root.get_node_or_null("MoonLight") as DirectionalLight3D
		if moon == null:
			var found_dl := search_root.find_children("*", "DirectionalLight3D", true, false)
			if not found_dl.is_empty():
				moon = found_dl[0] as DirectionalLight3D

	if we == null:
		we = WorldEnvironment.new()
		we.name = "BarrowWorldEnvironment"
		parent.add_child(we)

	var env := Environment.new()
	we.environment = env

	var fog_col: Color = profile["fog_color"]

	var sky := _get_cached_panorama_sky()
	if sky == null:
		sky = Sky.new()
		var sky_sh := load("res://shaders/sky_cathedral_ibl.gdshader") as Shader
		if sky_sh != null:
			var smat := ShaderMaterial.new()
			smat.shader = sky_sh
			smat.set_shader_parameter("vault_color", fog_col.darkened(0.68))
			smat.set_shader_parameter("horizon_color", fog_col.darkened(0.32))
			smat.set_shader_parameter("clerestory_color", profile.get("sky_clerestory", Color(0.45, 0.62, 1.0)) as Color)
			smat.set_shader_parameter("brazier_color", profile.get("sky_brazier", Color(1.0, 0.50, 0.16)) as Color)
			smat.set_shader_parameter("clerestory_hdr", 2.2)
			smat.set_shader_parameter("brazier_hdr", 3.2)
			smat.set_shader_parameter("direct_bg_scale", 0.44)
			sky.sky_material = smat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = float(profile["ambient_energy"])
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.15
	env.fog_enabled = true
	env.fog_light_color = fog_col
	env.fog_light_energy = float(profile["fog_energy"])
	env.fog_density = float(profile["fog_density"])
	env.fog_aerial_perspective = 0.42
	env.fog_sky_affect = 0.45

	if moon == null:
		moon = DirectionalLight3D.new()
		moon.name = "BarrowMoonLight"
		parent.add_child(moon)

	moon.light_color = profile["moon_color"] as Color
	moon.light_energy = float(profile["moon_energy"])
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 36.0
	moon.rotation_degrees = profile["moon_rot"] as Vector3


static func _get_cached_panorama_sky() -> Sky:
	if _cached_panorama_sky != null:
		return _cached_panorama_sky
	if ResourceLoader.exists(CATHEDRAL_IBL_PANORAMA_PATH):
		var pano := load(CATHEDRAL_IBL_PANORAMA_PATH) as Texture2D
		if pano != null:
			var pmat := PanoramaSkyMaterial.new()
			pmat.panorama = pano
			pmat.energy_multiplier = 1.25
			var sky := Sky.new()
			sky.sky_material = pmat
			_cached_panorama_sky = sky
			return _cached_panorama_sky
	return null


static func _build_ground(parent: Node3D, profile: Dictionary, headless: bool) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "BarrowGroundBody"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(120.0, 1.0, 150.0)
	floor_col.shape = box_shape
	floor_col.position = Vector3(0.0, -0.5, -10.0)
	floor_body.add_child(floor_col)
	parent.add_child(floor_body)

	if headless:
		return

	var ground_sh := load("res://shaders/vfx_barrow_ground.gdshader") as Shader
	var gmat := ShaderMaterial.new()
	gmat.shader = ground_sh
	gmat.set_shader_parameter("ground_tint", profile["ground_tint"] as Color)
	var noise_tex := load(VFX_NOISE_TEX_PATH) as Texture2D
	if noise_tex != null:
		gmat.set_shader_parameter("noise_tex", noise_tex)

	var f_alb := load(str(profile["tex_forest_c"])) as Texture2D
	var f_nrm := load(str(profile["tex_forest_n"])) as Texture2D
	var d_alb := load(str(profile["tex_dirt_c"])) as Texture2D
	var d_nrm := load(str(profile["tex_dirt_n"])) as Texture2D
	var s_alb := load(str(profile["tex_stone_c"])) as Texture2D
	var s_nrm := load(str(profile["tex_stone_n"])) as Texture2D
	if f_alb != null:
		gmat.set_shader_parameter("forest_albedo", f_alb)
	if f_nrm != null:
		gmat.set_shader_parameter("forest_normal", f_nrm)
	if d_alb != null:
		gmat.set_shader_parameter("dirt_albedo", d_alb)
	if d_nrm != null:
		gmat.set_shader_parameter("dirt_normal", d_nrm)
	if s_alb != null:
		gmat.set_shader_parameter("stone_albedo", s_alb)
	if s_nrm != null:
		gmat.set_shader_parameter("stone_normal", s_nrm)

	var ground_mi := MeshInstance3D.new()
	ground_mi.name = "BarrowGroundMesh"
	var pm := PlaneMesh.new()
	pm.size = Vector2(104.0, 150.0)
	pm.subdivide_width = 48
	pm.subdivide_depth = 72
	ground_mi.mesh = pm
	ground_mi.position = Vector3(0.0, 0.0, -10.0)
	ground_mi.material_override = gmat
	ground_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground_mi)


static func _make_stone_material(albedo: Color = Color(0.32, 0.33, 0.37), rough_val: float = 0.82, nrm_scale: float = 0.85) -> StandardMaterial3D:
	var sm := StandardMaterial3D.new()
	sm.albedo_color = albedo
	var r_col := load("res://assets/textures/rock_color.jpg") as Texture2D
	var r_nrm := load("res://assets/textures/rock_normal.jpg") as Texture2D
	if r_col != null:
		sm.albedo_texture = r_col
	if r_nrm != null:
		sm.normal_enabled = true
		sm.normal_texture = r_nrm
		sm.normal_scale = nrm_scale
	sm.uv1_triplanar = true
	sm.uv1_scale = Vector3(0.45, 0.45, 0.45)
	sm.roughness = rough_val
	sm.metallic = 0.06
	return sm


static func _apply_gothic_stone_materials(root_node: Node3D, cache: Dictionary) -> void:
	var stone_mat := cache.get("stone_mat") as Material
	var dark_stone_mat := cache.get("dark_stone_mat") as Material
	if stone_mat == null:
		return
	for n in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var mname := mat.resource_name if mat != null else ""
			if "ObsidianStone" in mname and dark_stone_mat != null:
				mi.set_surface_override_material(s, dark_stone_mat)
			elif "GothicAshlarStone" in mname:
				mi.set_surface_override_material(s, stone_mat)


static func _make_iron_material(albedo: Color = Color(0.11, 0.12, 0.14)) -> StandardMaterial3D:
	var im := StandardMaterial3D.new()
	im.albedo_color = albedo
	im.metallic = 0.86
	im.roughness = 0.36
	return im


static func _build_boss_gate(parent: Node3D, gate_refs: Dictionary, profile: Dictionary, cache: Dictionary, headless: bool) -> void:
	var gate_root := Node3D.new()
	gate_root.name = "BossGate"
	gate_root.position = Vector3(0.0, 0.0, BOSS_GATE_Z)
	parent.add_child(gate_root)
	gate_refs["root"] = gate_root

	var sb := StaticBody3D.new()
	sb.name = "GateBlockerBody"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var col := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(30.0, 5.0, 0.7)
	col.shape = bshape
	col.position = Vector3(0.0, 2.5, 0.0)
	sb.add_child(col)
	gate_root.add_child(sb)
	gate_refs["collider"] = col

	var arch_visuals := Node3D.new()
	arch_visuals.name = "GateArchVisuals"
	gate_root.add_child(arch_visuals)
	gate_refs["arch_visuals"] = arch_visuals

	var bars_holder := Node3D.new()
	bars_holder.name = "IronPortcullis"
	arch_visuals.add_child(bars_holder)
	gate_refs["bars"] = bars_holder

	if headless:
		return

	var stone_mat := cache["stone_mat"] as Material
	var gate_ps := cache.get("kit_boss_gate") as PackedScene
	if gate_ps != null:
		var gate_inst := gate_ps.instantiate() as Node3D
		gate_inst.name = "KitBossGateModel"
		gate_inst.scale = Vector3(1.95, 1.38, 1.38)
		_apply_gothic_stone_materials(gate_inst, cache)
		arch_visuals.add_child(gate_inst)
		var port_bars := gate_inst.find_child("PortcullisBars", true, false) as Node3D
		if port_bars != null:
			gate_refs["bars"] = port_bars

	var wing_box := BoxMesh.new()
	wing_box.size = Vector3(6.2, 5.1, 1.65)
	for side_s: float in FLANK_SIDES:
		var wing := MeshInstance3D.new()
		wing.mesh = wing_box
		wing.position = Vector3(side_s * 13.4, 2.55, 0.0)
		wing.material_override = stone_mat
		arch_visuals.add_child(wing)

	var ward_root := Node3D.new()
	ward_root.name = "RuneWardSeal"
	gate_root.add_child(ward_root)
	gate_refs["ward"] = ward_root

	var ward_col: Color = profile["gate_ward"]
	var energy_sh := load("res://shaders/vfx_energy.gdshader") as Shader
	if energy_sh != null:
		var wmat := ShaderMaterial.new()
		wmat.shader = energy_sh
		wmat.set_shader_parameter("beam_mode", 1)
		wmat.set_shader_parameter("energy_color", ward_col)
		wmat.set_shader_parameter("hdr_gain", 1.85)

		var seal_mi := MeshInstance3D.new()
		var seal_q := PlaneMesh.new()
		seal_q.size = Vector2(3.8, 3.8)
		seal_mi.mesh = seal_q
		seal_mi.rotation_degrees.x = 90.0
		seal_mi.position = Vector3(0.0, 2.65, 0.22)
		seal_mi.material_override = wmat
		seal_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ward_root.add_child(seal_mi)

		var ground_seal_root := Node3D.new()
		ground_seal_root.name = "GroundWardSeal"
		gate_root.add_child(ground_seal_root)

		var gmat := ShaderMaterial.new()
		gmat.shader = energy_sh
		gmat.set_shader_parameter("beam_mode", 1)
		gmat.set_shader_parameter("energy_color", ward_col)
		gmat.set_shader_parameter("hdr_gain", 1.65)
		gmat.set_shader_parameter("fade_alpha", 0.85)
		gate_refs["ground_seal_mat"] = gmat

		var gseal_mi := MeshInstance3D.new()
		gseal_mi.name = "GroundWardRing"
		var gq := PlaneMesh.new()
		gq.size = Vector2(7.6, 7.6)
		gseal_mi.mesh = gq
		gseal_mi.position = Vector3(0.0, 0.036, 0.0)
		gseal_mi.material_override = gmat
		gseal_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ground_seal_root.add_child(gseal_mi)

	var glight := OmniLight3D.new()
	glight.position = Vector3(0.0, 2.8, 1.0)
	glight.light_color = ward_col
	glight.light_energy = 2.2
	glight.omni_range = 7.5
	glight.shadow_enabled = false
	gate_root.add_child(glight)
	gate_refs["light"] = glight


static func _build_shrine_sanctuary(parent: Node3D, profile: Dictionary, cache: Dictionary) -> void:
	var s_root := Node3D.new()
	s_root.name = "ShrineSanctuary"
	s_root.position = SHRINE_POS
	parent.add_child(s_root)

	for side_s: float in FLANK_SIDES:
		_spawn_ruin_pillar(s_root, Vector3(side_s * 5.2, 0.0, -1.2), 5.6, cache)
		_spawn_brazier(s_root, Vector3(side_s * 3.8, 0.0, 1.4), "brazier_primary", profile, cache, side_s < 0.0)


static func _build_ruins_and_braziers(parent: Node3D, profile: Dictionary, cache: Dictionary, rng: RandomNumberGenerator) -> void:
	var props := Node3D.new()
	props.name = "GothicRuinsAndBraziers"
	parent.add_child(props)

	var zid := str(profile["id"])

	for side_s: float in FLANK_SIDES:
		_spawn_brazier(props, Vector3(side_s * 5.2, 0.0, 33.0), "brazier_primary", profile, cache, side_s < 0.0)
		_spawn_ruin_pillar(props, Vector3(side_s * 7.8, 0.0, 34.4), 6.2, cache)

	if zid == "fringe":
		for az: float in [28.5, 11.5, -3.0, -20.5]:
			for side_s: float in FLANK_SIDES:
				_spawn_gothic_arch(props, Vector3(side_s * 14.2, 0.0, az), Vector3(1.18, 1.24, 1.15), cache, PI * 0.5)
		for side_s: float in FLANK_SIDES:
			_spawn_gothic_arch(props, Vector3(side_s * 12.8, 0.0, -53.8), Vector3(1.12, 1.18, 1.12), cache, side_s * 0.65)

	var idx := 0
	for spec in CLEARING_SPECS:
		var c: Vector3 = spec["center"]
		var r := float(spec["radius"])
		for side_s: float in FLANK_SIDES:
			var slot := "brazier_secondary" if (idx + (1 if side_s > 0.0 else 0)) % 2 == 1 else "brazier_primary"
			_spawn_brazier(props, Vector3(side_s * 5.6, 0.0, c.z + r * 0.88), slot, profile, cache, idx == 1 and side_s > 0.0)
			_spawn_ruin_pillar(props, Vector3(side_s * (r + 1.6), 0.0, c.z - 2.2), rng.randf_range(5.2, 6.8), cache)
			_spawn_ruin_pillar(props, Vector3(side_s * (r + 1.9), 0.0, c.z + 3.4), rng.randf_range(4.6, 6.4), cache)
		if zid == "catacombs":
			_spawn_catacomb_arch(props, Vector3(0.0, 0.0, c.z + r * 0.95), 25.5, 6.6, cache)
		idx += 1

	for side_s: float in FLANK_SIDES:
		var b_slot := "brazier_secondary" if side_s > 0.0 else "brazier_primary"
		_spawn_brazier(props, Vector3(side_s * 5.2, 0.0, BOSS_GATE_Z + 1.8), "brazier_primary", profile, cache, false)
		_spawn_brazier(props, Vector3(side_s * 8.6, 0.0, -38.5), b_slot, profile, cache, false)
		_spawn_brazier(props, Vector3(side_s * 10.6, 0.0, -45.5), "brazier_primary", profile, cache, true)
		_spawn_brazier(props, Vector3(side_s * 8.4, 0.0, -52.5), b_slot, profile, cache, false)

	if zid == "catacombs":
		_spawn_catacomb_arch(props, Vector3(0.0, 0.0, -35.8), 24.0, 6.4, cache)
		_spawn_catacomb_arch(props, Vector3(0.0, 0.0, -51.6), 18.8, 5.4, cache)

	for i in range(8):
		var ang := lerpf(-PI * 0.84, -PI * 0.16, float(i) / 7.0)
		var px := cos(ang) * (BOSS_RADIUS + 1.8)
		var pz := BOSS_CENTER.z + sin(ang) * (BOSS_RADIUS + 1.8)
		_spawn_ruin_pillar(props, Vector3(px, 0.0, pz), rng.randf_range(5.4, 7.0), cache)


static func _spawn_gothic_arch(parent: Node3D, pos: Vector3, scale_vec: Vector3, cache: Dictionary, yaw_rad: float = 0.0) -> void:
	var arch_ps := cache.get("kit_arch") as PackedScene
	if arch_ps == null:
		return
	var arch := arch_ps.instantiate() as Node3D
	arch.name = "GothicColonnadeArch"
	arch.position = pos
	arch.rotation.y = yaw_rad
	arch.scale = scale_vec
	_apply_gothic_stone_materials(arch, cache)
	parent.add_child(arch)


static func _spawn_ruin_pillar(parent: Node3D, pos: Vector3, height: float, cache: Dictionary) -> void:
	var pillar_ps := cache.get("kit_pillar") as PackedScene
	if pillar_ps != null:
		var holder := pillar_ps.instantiate() as Node3D
		holder.name = "GothicPillar"
		holder.position = pos
		var h_scale := clampf(height / 6.2, 0.72, 1.25)
		holder.scale = Vector3(1.05, h_scale, 1.05)
		_apply_gothic_stone_materials(holder, cache)
		parent.add_child(holder)
		return

	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var stone_mat := cache["stone_mat"] as Material
	var shaft := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.38
	cmesh.bottom_radius = 0.46
	cmesh.height = height
	cmesh.radial_segments = 8
	shaft.mesh = cmesh
	shaft.position = Vector3(0.0, height * 0.5, 0.0)
	shaft.material_override = stone_mat
	holder.add_child(shaft)


static func _spawn_standing_monolith(parent: Node3D, pos: Vector3, height: float, tilt_z: float, cache: Dictionary) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = atan2(-pos.x, -(pos.z - BOSS_CENTER.z))
	holder.rotation.z = tilt_z
	parent.add_child(holder)

	var stone_mat := cache["stone_mat"] as Material
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.55, height, 0.62)
	slab.mesh = box
	slab.position = Vector3(0.0, height * 0.48, 0.0)
	slab.material_override = stone_mat
	holder.add_child(slab)

	var cap := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.58, 0.85, 0.64)
	cap.mesh = prism
	cap.position = Vector3(0.0, height * 0.98 + 0.38, 0.0)
	cap.material_override = stone_mat
	holder.add_child(cap)


static func _spawn_catacomb_arch(parent: Node3D, pos: Vector3, span_w: float, arch_h: float, cache: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "CatacombFlankFrame"
	holder.position = pos
	parent.add_child(holder)

	var half_span := maxf(span_w * 0.5, 10.4)
	var stone_mat := cache["stone_mat"] as Material
	var col_box := BoxMesh.new()
	col_box.size = Vector3(1.9, arch_h, 1.9)
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(2.5, 0.85, 2.5)
	for side_s: float in FLANK_SIDES:
		var flank_x := side_s * half_span
		var col := MeshInstance3D.new()
		col.mesh = col_box
		col.position = Vector3(flank_x, arch_h * 0.5, 0.0)
		col.material_override = stone_mat
		holder.add_child(col)

		var cap := MeshInstance3D.new()
		cap.mesh = cap_box
		cap.position = Vector3(flank_x, arch_h + 0.42, 0.0)
		cap.material_override = stone_mat
		holder.add_child(cap)

		_spawn_gothic_arch(holder, Vector3(flank_x + side_s * 0.65, 0.0, 0.0), Vector3(1.02, clampf(arch_h / 6.2, 0.82, 1.15), 1.05), cache, PI * 0.5)


static func _spawn_brazier(parent: Node3D, pos: Vector3, slot_key: String, profile: Dictionary, cache: Dictionary, with_light: bool = false) -> void:
	var b_root := Node3D.new()
	b_root.name = "TorchBrazier"
	b_root.position = pos
	parent.add_child(b_root)

	var bspec: Dictionary = profile[slot_key]
	var brazier_ps := cache.get("kit_brazier") as PackedScene
	if brazier_ps != null:
		var inst := brazier_ps.instantiate() as Node3D
		inst.scale = Vector3.ONE * 1.15
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b_root.add_child(inst)

	if cache.has(slot_key + "_flame_mat"):
		var fmi := MeshInstance3D.new()
		fmi.mesh = cache["brazier_flame_mesh"] as Mesh
		fmi.position = Vector3(0.0, 1.94, 0.0)
		fmi.material_override = cache[slot_key + "_flame_mat"] as Material
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b_root.add_child(fmi)

	if with_light:
		var light := OmniLight3D.new()
		light.position = Vector3(0.0, 2.08, 0.0)
		light.light_color = bspec["light"] as Color
		light.light_energy = 2.25
		light.omni_range = 7.2
		light.shadow_enabled = false
		b_root.add_child(light)


static func _build_perimeter_biome(parent: Node3D, profile: Dictionary, cache: Dictionary, rng: RandomNumberGenerator) -> void:
	var biome_root := Node3D.new()
	biome_root.name = "PerimeterForest"
	parent.add_child(biome_root)

	var zid := str(profile["id"])
	match zid:
		"weald":
			_populate_weald_biome(biome_root, cache, rng)
		"catacombs":
			_populate_catacombs_biome(biome_root, cache, rng)
		"rift":
			_populate_rift_biome(biome_root, cache, rng)
		_:
			_populate_fringe_biome(biome_root, cache, rng)


static func _populate_fringe_biome(biome_root: Node3D, cache: Dictionary, rng: RandomNumberGenerator) -> void:
	var trees := _load_scenes(["res://assets/models/tree_dead.glb", "res://assets/models/tree_pine.glb", "res://assets/models/tree_pine_b.glb"])
	var rocks := _load_scenes(["res://assets/models/rock_a.glb", "res://assets/models/rock_b.glb", "res://assets/models/rock_c.glb"])
	var wood_tint := Color(0.28, 0.30, 0.34)
	var rock_tint := Color(0.30, 0.34, 0.39)

	var z_cursor := 43.0
	while z_cursor >= -62.0:
		var min_edge := 15.8 if z_cursor >= BOSS_GATE_Z else 17.0
		for side_s: float in FLANK_SIDES:
			if not trees.is_empty() and rng.randf() < 0.65:
				var t_inst := trees[0].instantiate() as Node3D
				t_inst.position = Vector3(side_s * (min_edge + rng.randf_range(3.2, 8.8)), 0.0, z_cursor + rng.randf_range(-1.6, 1.6))
				t_inst.rotation.y = rng.randf_range(0.0, TAU)
				t_inst.scale = Vector3.ONE * rng.randf_range(1.65, 2.55)
				_style_prop(t_inst, "fringe_tree", wood_tint, Color.BLACK, 0.0, cache)
				biome_root.add_child(t_inst)

			if not rocks.is_empty() and rng.randf() < 0.78:
				var r_inst := rocks[rng.randi_range(0, rocks.size() - 1)].instantiate() as Node3D
				r_inst.position = Vector3(side_s * (min_edge + rng.randf_range(-0.6, 2.4)), -0.08, z_cursor + rng.randf_range(-1.8, 1.8))
				r_inst.rotation.y = rng.randf_range(0.0, TAU)
				r_inst.scale = Vector3(rng.randf_range(1.3, 2.2), rng.randf_range(1.1, 2.0), rng.randf_range(1.3, 2.2))
				_style_prop(r_inst, "fringe_rock", rock_tint, Color.BLACK, 0.0, cache)
				biome_root.add_child(r_inst)
		z_cursor -= 4.8

	for i in range(9):
		var ang := lerpf(-PI * 0.88, -PI * 0.12, float(i) / 8.0)
		if not trees.is_empty():
			var bt := trees[i % trees.size()].instantiate() as Node3D
			var dist := BOSS_RADIUS + rng.randf_range(3.8, 7.5)
			bt.position = Vector3(cos(ang) * dist, 0.0, BOSS_CENTER.z + sin(ang) * dist)
			bt.rotation.y = rng.randf_range(0.0, TAU)
			bt.scale = Vector3.ONE * rng.randf_range(1.7, 2.6)
			_style_prop(bt, "fringe_tree", wood_tint, Color.BLACK, 0.0, cache)
			biome_root.add_child(bt)


static func _populate_weald_biome(biome_root: Node3D, cache: Dictionary, rng: RandomNumberGenerator) -> void:
	var twist_ps := load("res://assets/models/tree_twist.glb") as PackedScene
	var dead_ps := load("res://assets/models/tree_dead.glb") as PackedScene
	var mushrooms := _load_scenes(["res://assets/models/mushroom.glb", "res://assets/models/mushroom_shelf.glb"])
	var fern_ps := load("res://assets/models/fern.glb") as PackedScene
	var rock_ps := load("res://assets/models/rock_a.glb") as PackedScene

	var bark_tint := Color(0.22, 0.30, 0.21)
	var mush_tint := Color(0.28, 0.48, 0.34)
	var mush_glow := Color(0.22, 0.88, 0.42)
	var fern_tint := Color(0.20, 0.38, 0.22)

	var z_cursor := 43.0
	while z_cursor >= -62.0:
		var min_edge := 15.2 if z_cursor >= BOSS_GATE_Z else 16.8
		for side_s: float in FLANK_SIDES:
			if twist_ps != null:
				var t_inst := twist_ps.instantiate() as Node3D
				t_inst.position = Vector3(side_s * (min_edge + rng.randf_range(2.2, 6.4)), 0.0, z_cursor + rng.randf_range(-1.6, 1.6))
				t_inst.rotation.y = rng.randf_range(0.0, TAU)
				t_inst.scale = Vector3.ONE * rng.randf_range(0.78, 1.18)
				_style_prop(t_inst, "weald_tree", bark_tint, Color.BLACK, 0.0, cache)
				biome_root.add_child(t_inst)

			if dead_ps != null and rng.randf() < 0.55:
				var d_inst := dead_ps.instantiate() as Node3D
				d_inst.position = Vector3(side_s * (min_edge + rng.randf_range(7.0, 12.5)), 0.0, z_cursor + rng.randf_range(-2.0, 2.0))
				d_inst.rotation.y = rng.randf_range(0.0, TAU)
				d_inst.scale = Vector3.ONE * rng.randf_range(1.6, 2.4)
				_style_prop(d_inst, "weald_tree", bark_tint, Color.BLACK, 0.0, cache)
				biome_root.add_child(d_inst)

			if not mushrooms.is_empty():
				var m_inst := mushrooms[rng.randi_range(0, mushrooms.size() - 1)].instantiate() as Node3D
				m_inst.position = Vector3(side_s * (min_edge + rng.randf_range(-1.1, 1.8)), 0.0, z_cursor + rng.randf_range(-1.5, 1.5))
				m_inst.rotation.y = rng.randf_range(0.0, TAU)
				m_inst.scale = Vector3.ONE * rng.randf_range(2.8, 4.8)
				_style_prop(m_inst, "weald_mushroom", mush_tint, mush_glow, 1.05, cache)
				biome_root.add_child(m_inst)

			if fern_ps != null:
				var f_inst := fern_ps.instantiate() as Node3D
				f_inst.position = Vector3(side_s * (min_edge + rng.randf_range(-1.4, 1.2)), 0.0, z_cursor + rng.randf_range(-2.0, 2.0))
				f_inst.rotation.y = rng.randf_range(0.0, TAU)
				f_inst.scale = Vector3.ONE * rng.randf_range(0.95, 1.55)
				_style_prop(f_inst, "weald_fern", fern_tint, Color.BLACK, 0.0, cache)
				biome_root.add_child(f_inst)

			if rock_ps != null and rng.randf() < 0.45:
				var r_inst := rock_ps.instantiate() as Node3D
				r_inst.position = Vector3(side_s * (min_edge + rng.randf_range(-0.4, 2.2)), -0.10, z_cursor + rng.randf_range(-1.8, 1.8))
				r_inst.rotation.y = rng.randf_range(0.0, TAU)
				r_inst.scale = Vector3.ONE * rng.randf_range(1.0, 1.6)
				_style_prop(r_inst, "weald_rock", bark_tint, Color.BLACK, 0.0, cache)
				biome_root.add_child(r_inst)
		z_cursor -= 5.2

	for i in range(10):
		var ang := lerpf(-PI * 0.92, -PI * 0.08, float(i) / 9.0)
		var ring_pos := Vector3(cos(ang) * (BOSS_RADIUS + 0.9), 0.0, BOSS_CENTER.z + sin(ang) * (BOSS_RADIUS + 0.9))
		if not mushrooms.is_empty():
			var bm := mushrooms[i % mushrooms.size()].instantiate() as Node3D
			bm.position = ring_pos
			bm.rotation.y = rng.randf_range(0.0, TAU)
			bm.scale = Vector3.ONE * rng.randf_range(3.2, 5.2)
			_style_prop(bm, "weald_mushroom", mush_tint, mush_glow, 1.15, cache)
			biome_root.add_child(bm)
		if fern_ps != null:
			var bf := fern_ps.instantiate() as Node3D
			bf.position = Vector3(cos(ang + 0.14) * (BOSS_RADIUS + 0.4), 0.0, BOSS_CENTER.z + sin(ang + 0.14) * (BOSS_RADIUS + 0.4))
			bf.rotation.y = rng.randf_range(0.0, TAU)
			bf.scale = Vector3.ONE * rng.randf_range(1.15, 1.65)
			_style_prop(bf, "weald_fern", fern_tint, Color.BLACK, 0.0, cache)
			biome_root.add_child(bf)
		if twist_ps != null and i % 2 == 1:
			var bt := twist_ps.instantiate() as Node3D
			var back_pos := Vector3(cos(ang) * (BOSS_RADIUS + 3.1), 0.0, BOSS_CENTER.z + sin(ang) * (BOSS_RADIUS + 3.1))
			bt.position = back_pos
			bt.rotation.y = rng.randf_range(0.0, TAU)
			bt.scale = Vector3.ONE * rng.randf_range(0.76, 1.04)
			_style_prop(bt, "weald_tree", bark_tint, Color.BLACK, 0.0, cache)
			biome_root.add_child(bt)


static func _populate_catacombs_biome(biome_root: Node3D, cache: Dictionary, rng: RandomNumberGenerator) -> void:
	var den_ps := load("res://assets/models/den.glb") as PackedScene
	var crystal_ps := load("res://assets/models/crystal.glb") as PackedScene
	var flat_ps := load("res://assets/models/rock_flat.glb") as PackedScene
	var rock_ps := load("res://assets/models/rock_b.glb") as PackedScene

	var slate_tint := Color(0.14, 0.15, 0.21)
	var crystal_albedo := Color(0.18, 0.30, 0.68)
	var crystal_glow := Color(0.30, 0.58, 1.0)

	var z_cursor := 42.0
	while z_cursor >= -62.0:
		var min_edge := 15.0 if z_cursor >= BOSS_GATE_Z else 16.5
		for side_s: float in FLANK_SIDES:
			if den_ps != null and int(absf(z_cursor)) % 2 == 0:
				var crypt := den_ps.instantiate() as Node3D
				crypt.position = Vector3(side_s * (min_edge + rng.randf_range(2.2, 4.6)), 0.0, z_cursor + rng.randf_range(-1.2, 1.2))
				crypt.rotation.y = -side_s * PI * 0.5 + rng.randf_range(-0.22, 0.22)
				crypt.scale = Vector3.ONE * rng.randf_range(1.55, 2.15)
				_style_prop(crypt, "catacombs_crypt", slate_tint, crystal_glow, 1.4, cache)
				biome_root.add_child(crypt)

			if crystal_ps != null:
				_spawn_crystal_cluster(
					biome_root,
					Vector3(side_s * (min_edge + rng.randf_range(-1.1, 1.4)), 0.0, z_cursor + rng.randf_range(-1.6, 1.6)),
					crystal_ps,
					crystal_albedo,
					crystal_glow,
					cache,
					rng
				)

			if flat_ps != null:
				var slab := flat_ps.instantiate() as Node3D
				slab.position = Vector3(side_s * (min_edge + rng.randf_range(-1.5, 1.0)), 0.02, z_cursor + rng.randf_range(-2.0, 2.0))
				slab.rotation.y = rng.randf_range(0.0, TAU)
				slab.scale = Vector3(rng.randf_range(2.2, 3.6), rng.randf_range(1.2, 2.0), rng.randf_range(2.2, 3.6))
				_style_prop(slab, "catacombs_flat", slate_tint, Color.BLACK, 0.0, cache, true)
				biome_root.add_child(slab)

			if rock_ps != null and rng.randf() < 0.55:
				var rk := rock_ps.instantiate() as Node3D
				rk.position = Vector3(side_s * (min_edge + rng.randf_range(4.5, 8.8)), -0.1, z_cursor + rng.randf_range(-1.8, 1.8))
				rk.rotation.y = rng.randf_range(0.0, TAU)
				rk.scale = Vector3(rng.randf_range(1.4, 2.2), rng.randf_range(1.8, 3.0), rng.randf_range(1.4, 2.2))
				_style_prop(rk, "catacombs_slate", slate_tint, Color.BLACK, 0.0, cache)
				biome_root.add_child(rk)
		z_cursor -= 5.6

	for i in range(10):
		var ang := lerpf(-PI * 0.92, -PI * 0.08, float(i) / 9.0)
		if crystal_ps != null:
			var cp := Vector3(cos(ang) * (BOSS_RADIUS + 0.9), 0.0, BOSS_CENTER.z + sin(ang) * (BOSS_RADIUS + 0.9))
			_spawn_crystal_cluster(biome_root, cp, crystal_ps, crystal_albedo, crystal_glow, cache, rng)
		if den_ps != null and i in [2, 5, 7]:
			var dp := Vector3(cos(ang) * (BOSS_RADIUS + 5.2), 0.0, BOSS_CENTER.z + sin(ang) * (BOSS_RADIUS + 5.2))
			var back_crypt := den_ps.instantiate() as Node3D
			back_crypt.position = dp
			back_crypt.rotation.y = atan2(-dp.x, -(dp.z - BOSS_CENTER.z))
			back_crypt.scale = Vector3.ONE * 1.95
			_style_prop(back_crypt, "catacombs_crypt", slate_tint, crystal_glow, 1.4, cache)
			biome_root.add_child(back_crypt)


static func _spawn_crystal_cluster(
	parent: Node3D,
	pos: Vector3,
	crystal_ps: PackedScene,
	albedo: Color,
	glow: Color,
	cache: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var cluster := Node3D.new()
	cluster.position = pos
	parent.add_child(cluster)
	for k in range(3):
		var c := crystal_ps.instantiate() as Node3D
		var ang := float(k) * (TAU / 3.0) + rng.randf_range(-0.3, 0.3)
		c.position = Vector3(cos(ang) * 0.38, -0.04, sin(ang) * 0.38)
		c.rotation = Vector3(rng.randf_range(-0.26, 0.26), rng.randf_range(0.0, TAU), rng.randf_range(-0.26, 0.26))
		var h_sc := rng.randf_range(4.2, 6.6) if k == 0 else rng.randf_range(2.6, 4.4)
		c.scale = Vector3(h_sc * 0.85, h_sc, h_sc * 0.85)
		_style_prop(c, "catacombs_crystal", albedo, glow, 2.4, cache)
		cluster.add_child(c)


static func _populate_rift_biome(biome_root: Node3D, cache: Dictionary, rng: RandomNumberGenerator) -> void:
	var lava_rock_ps := load("res://assets/models/rock_lava.glb") as PackedScene
	var lava_flower_ps := load("res://assets/models/flower_lava.glb") as PackedScene
	var vent_ps := load("res://assets/models/vent.glb") as PackedScene
	var dead_tree_ps := load("res://assets/models/tree_dead.glb") as PackedScene

	var basalt_tint := Color(0.20, 0.13, 0.12)
	var magma_glow := Color(1.0, 0.32, 0.06)

	var z_cursor := 43.0
	while z_cursor >= -62.0:
		var min_edge := 15.0 if z_cursor >= BOSS_GATE_Z else 16.5
		for side_s: float in FLANK_SIDES:
			if lava_rock_ps != null:
				var lr := lava_rock_ps.instantiate() as Node3D
				lr.position = Vector3(side_s * (min_edge + rng.randf_range(0.4, 3.8)), -0.12, z_cursor + rng.randf_range(-1.5, 1.5))
				lr.rotation.y = rng.randf_range(0.0, TAU)
				lr.scale = Vector3(rng.randf_range(1.3, 2.2), rng.randf_range(1.6, 3.0), rng.randf_range(1.3, 2.2))
				_style_prop(lr, "rift_basalt", basalt_tint, magma_glow, 0.35, cache)
				biome_root.add_child(lr)

				var lr_back := lava_rock_ps.instantiate() as Node3D
				lr_back.position = Vector3(side_s * (min_edge + rng.randf_range(5.8, 11.5)), -0.2, z_cursor + rng.randf_range(-2.0, 2.0))
				lr_back.rotation.y = rng.randf_range(0.0, TAU)
				lr_back.scale = Vector3(rng.randf_range(2.0, 3.2), rng.randf_range(2.6, 4.4), rng.randf_range(2.0, 3.2))
				_style_prop(lr_back, "rift_basalt", basalt_tint, magma_glow, 0.25, cache)
				biome_root.add_child(lr_back)

			if vent_ps != null and rng.randf() < 0.78:
				var vt := vent_ps.instantiate() as Node3D
				vt.position = Vector3(side_s * (min_edge + rng.randf_range(-2.2, 0.6)), 0.02, z_cursor + rng.randf_range(-1.8, 1.8))
				vt.rotation.y = rng.randf_range(0.0, TAU)
				vt.scale = Vector3(rng.randf_range(2.0, 3.2), rng.randf_range(1.5, 2.4), rng.randf_range(2.0, 3.2))
				_style_prop(vt, "rift_vent", basalt_tint, magma_glow, 3.6, cache, true)
				biome_root.add_child(vt)

			if lava_flower_ps != null and rng.randf() < 0.72:
				var fl := lava_flower_ps.instantiate() as Node3D
				fl.position = Vector3(side_s * (min_edge + rng.randf_range(-1.2, 1.6)), 0.0, z_cursor + rng.randf_range(-1.8, 1.8))
				fl.rotation.y = rng.randf_range(0.0, TAU)
				fl.scale = Vector3.ONE * rng.randf_range(0.95, 1.55)
				_style_prop(fl, "rift_flower", basalt_tint, magma_glow, 2.4, cache)
				biome_root.add_child(fl)

			if dead_tree_ps != null and rng.randf() < 0.42:
				var ct := dead_tree_ps.instantiate() as Node3D
				ct.position = Vector3(side_s * (min_edge + rng.randf_range(3.6, 8.2)), 0.0, z_cursor + rng.randf_range(-1.8, 1.8))
				ct.rotation.y = rng.randf_range(0.0, TAU)
				ct.scale = Vector3.ONE * rng.randf_range(1.4, 2.1)
				_style_prop(ct, "rift_charred_tree", Color(0.12, 0.09, 0.09), magma_glow, 0.22, cache)
				biome_root.add_child(ct)
		z_cursor -= 5.0

	for i in range(10):
		var ang := lerpf(-PI * 0.92, -PI * 0.08, float(i) / 9.0)
		if vent_ps != null:
			var vp := Vector3(cos(ang) * (BOSS_RADIUS + 0.3), 0.02, BOSS_CENTER.z + sin(ang) * (BOSS_RADIUS + 0.3))
			var bv := vent_ps.instantiate() as Node3D
			bv.position = vp
			bv.rotation.y = rng.randf_range(0.0, TAU)
			bv.scale = Vector3(2.5, 1.9, 2.5)
			_style_prop(bv, "rift_vent", basalt_tint, magma_glow, 3.8, cache, true)
			biome_root.add_child(bv)
		if lava_flower_ps != null and i % 2 == 0:
			var fp := Vector3(cos(ang + 0.14) * (BOSS_RADIUS + 0.8), 0.0, BOSS_CENTER.z + sin(ang + 0.14) * (BOSS_RADIUS + 0.8))
			var bf := lava_flower_ps.instantiate() as Node3D
			bf.position = fp
			bf.rotation.y = rng.randf_range(0.0, TAU)
			bf.scale = Vector3.ONE * rng.randf_range(1.15, 1.6)
			_style_prop(bf, "rift_flower", basalt_tint, magma_glow, 2.6, cache)
			biome_root.add_child(bf)
		if lava_rock_ps != null:
			var rp := Vector3(cos(ang) * (BOSS_RADIUS + 2.8), -0.15, BOSS_CENTER.z + sin(ang) * (BOSS_RADIUS + 2.8))
			var br := lava_rock_ps.instantiate() as Node3D
			br.position = rp
			br.rotation.y = rng.randf_range(0.0, TAU)
			br.scale = Vector3(2.0, 3.1, 2.0)
			_style_prop(br, "rift_basalt", basalt_tint, magma_glow, 0.35, cache)
			biome_root.add_child(br)


static func _build_rift_ember_ash(parent: Node3D) -> void:
	var ash_root := Node3D.new()
	ash_root.name = "RiftEmberAshVfx"
	parent.add_child(ash_root)

	var spark_mesh := BladeScrapeVfx.make_crossed_spark_mesh(0.075, 0.19)
	var spark_sh := load("res://shaders/vfx_spark.gdshader") as Shader
	if spark_sh != null:
		var sm := ShaderMaterial.new()
		sm.shader = spark_sh
		sm.render_priority = 2
		sm.set_shader_parameter("spark_hdr", Vector4(5.4, 1.85, 0.34, 0.92))
		spark_mesh.surface_set_material(0, sm)
	else:
		var std := StandardMaterial3D.new()
		std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
		std.vertex_color_use_as_albedo = true
		std.albedo_color = Color(4.5, 1.5, 0.3, 0.9)
		spark_mesh.surface_set_material(0, std)

	var proc := ParticleProcessMaterial.new()
	proc.particle_flag_align_y = true
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(16.0, 1.4, 28.0)
	proc.direction = Vector3(0.24, 1.0, -0.16).normalized()
	proc.spread = 28.0
	proc.initial_velocity_min = 1.35
	proc.initial_velocity_max = 3.10
	proc.gravity = Vector3(0.32, 0.78, -0.18)
	proc.scale_min = 0.75
	proc.scale_max = 1.55

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.45, 0.12, 0.0),
		Color(1.0, 0.62, 0.18, 0.95),
		Color(0.95, 0.26, 0.06, 0.78),
		Color(0.35, 0.06, 0.02, 0.0),
	])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	proc.color_ramp = gtex

	for spec in [
		{"name": "CorridorEmbers", "pos": Vector3(0.0, 0.4, 8.0), "amount": 30},
		{"name": "BossSanctumEmbers", "pos": Vector3(0.0, 0.4, -44.0), "amount": 30},
	]:
		var gp := GPUParticles3D.new()
		gp.name = str(spec["name"])
		gp.position = spec["pos"] as Vector3
		gp.amount = int(spec["amount"])
		gp.lifetime = 3.2
		gp.preprocess = 1.6
		gp.randomness = 0.45
		gp.local_coords = false
		gp.visibility_aabb = AABB(Vector3(-26.0, -2.0, -36.0), Vector3(52.0, 18.0, 72.0))
		gp.process_material = proc
		gp.draw_pass_1 = spark_mesh
		gp.emitting = true
		ash_root.add_child(gp)


static func _load_scenes(paths: Array[String]) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for p in paths:
		var ps := load(p) as PackedScene
		if ps != null:
			out.append(ps)
	return out


static func _style_prop(
	root_node: Node3D,
	role_key: String,
	tint: Color,
	glow_color: Color,
	glow_energy: float,
	cache: Dictionary,
	replace_clay_with_stone: bool = false
) -> void:
	var mat_map: Dictionary = cache["prop_mats"]
	for n in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var mname := mat.resource_name if mat != null else "default"
			var ckey := "%s|%s|%d" % [role_key, mname, mat.get_instance_id() if mat != null else 0]
			if mat_map.has(ckey):
				mi.set_surface_override_material(s, mat_map[ckey] as Material)
				continue

			var is_glow_surf := mname in ["Glow", "Flowers", "Flag", "Mushrooms"] and glow_energy > 0.0
			var out_mat: StandardMaterial3D = null

			if replace_clay_with_stone and mname == "Clay" and cache.has("stone_mat"):
				out_mat = (cache["stone_mat"] as StandardMaterial3D).duplicate() as StandardMaterial3D
				out_mat.albedo_color = tint
			elif mat is StandardMaterial3D:
				out_mat = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				if mname in ["Glow", "Flag"] and glow_energy > 0.0:
					out_mat.albedo_color = glow_color.darkened(0.25)
				else:
					out_mat.albedo_color = Color(
						out_mat.albedo_color.r * tint.r,
						out_mat.albedo_color.g * tint.g,
						out_mat.albedo_color.b * tint.b,
						out_mat.albedo_color.a
					)
				out_mat.roughness = 0.28 if mname == "Glow" else maxf(out_mat.roughness, 0.84)
			else:
				out_mat = StandardMaterial3D.new()
				out_mat.albedo_color = glow_color if is_glow_surf else tint
				out_mat.roughness = 0.85

			if is_glow_surf or (glow_energy > 0.0 and role_key == "catacombs_crystal"):
				out_mat.emission_enabled = true
				out_mat.emission = glow_color
				out_mat.emission_energy_multiplier = glow_energy
			elif glow_energy > 0.0 and role_key in ["rift_basalt", "rift_charred_tree"]:
				out_mat.emission_enabled = true
				out_mat.emission = glow_color
				out_mat.emission_energy_multiplier = glow_energy

			mat_map[ckey] = out_mat
			mi.set_surface_override_material(s, out_mat)
