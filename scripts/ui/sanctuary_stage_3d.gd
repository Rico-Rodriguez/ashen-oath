class_name SanctuaryStage3D
extends PanelContainer

@export var camera_distance: float = 4.65
@export var camera_height: float = 1.62
@export var look_height: float = 1.24

@onready var viewport_container: SubViewportContainer = $ViewportStack/SubViewportContainer
@onready var sub_viewport: SubViewport = $ViewportStack/SubViewportContainer/SubViewport
@onready var turntable_pivot: Node3D = $ViewportStack/SubViewportContainer/SubViewport/StageRoot/TurntablePivot
@onready var stage_camera: Camera3D = $ViewportStack/SubViewportContainer/SubViewport/StageCamera

var _hero_visual: ActorVisual = null
var _loaded_class_id: String = ""
var _target_yaw: float = 0.28
var _current_yaw: float = 0.28
var _dragging: bool = false
var _last_drag_x: float = 0.0
var _flicker_time: float = 0.0
var _built_props: bool = false
var _brazier_lights: Array[OmniLight3D] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_BRONZE, 1, 5, 2, 2))
	_build_sanctuary_props()
	_configure_camera()

	var gs := _game_state()
	if gs != null:
		if not gs.class_selected.is_connected(_on_state_changed_str):
			gs.class_selected.connect(_on_state_changed_str)
		if not gs.equipment_changed.is_connected(_on_state_changed_str):
			gs.equipment_changed.connect(_on_state_changed_str)
		if not gs.profile_changed.is_connected(refresh_hero):
			gs.profile_changed.connect(refresh_hero)

	refresh_hero()
	_sync_viewport_mode()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_viewport_mode()


func _sync_viewport_mode() -> void:
	if sub_viewport == null:
		return
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_flicker_time += delta
	for i in range(_brazier_lights.size()):
		var bl := _brazier_lights[i]
		if bl != null and is_instance_valid(bl):
			var phase := float(i) * 2.1
			bl.light_energy = 2.45 + sin(_flicker_time * 7.3 + phase) * 0.24 + cos(_flicker_time * 13.1 + phase) * 0.14
	if not _dragging:
		_target_yaw += delta * 0.14
	_current_yaw = lerp_angle(_current_yaw, _target_yaw, 1.0 - exp(-12.0 * delta))
	if turntable_pivot != null:
		turntable_pivot.rotation.y = _current_yaw


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_last_drag_x = mb.position.x
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var dx := mm.position.x - _last_drag_x
		_last_drag_x = mm.position.x
		_target_yaw += dx * 0.014
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_dragging = st.pressed
		_last_drag_x = st.position.x
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_target_yaw += sd.relative.x * 0.014
		accept_event()


func _on_state_changed_str(_id: String) -> void:
	refresh_hero()


func refresh_hero() -> void:
	if turntable_pivot == null:
		return
	var gs := _game_state()
	var cid := str(gs.get("selected_class_id")) if gs != null else "oathbreaker"
	if GameRegistry.get_class_def(cid) == null:
		cid = "oathbreaker"
	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null:
		return

	if _hero_visual == null or not is_instance_valid(_hero_visual) or _loaded_class_id != cid:
		if _hero_visual != null and is_instance_valid(_hero_visual):
			turntable_pivot.remove_child(_hero_visual)
			_hero_visual.queue_free()
			_hero_visual = null
		var ps := load(hdef.actor_scene_path) as PackedScene
		if ps != null:
			_hero_visual = ps.instantiate() as ActorVisual
			turntable_pivot.add_child(_hero_visual)
			_hero_visual.ensure_initialized()
			_loaded_class_id = cid

	if _hero_visual == null:
		return

	var cstats: CombatStats = null
	if gs != null and gs.has_method("get_combat_stats"):
		cstats = gs.call("get_combat_stats", cid)
	else:
		var eq := {
			GameEnums.Slot.WEAPON: LootEngine.make_starter_item(GameEnums.Slot.WEAPON, hdef),
			GameEnums.Slot.HELM: LootEngine.make_starter_item(GameEnums.Slot.HELM, hdef),
			GameEnums.Slot.CUIRASS: LootEngine.make_starter_item(GameEnums.Slot.CUIRASS, hdef),
			GameEnums.Slot.LANTERN: LootEngine.make_starter_item(GameEnums.Slot.LANTERN, hdef),
		}
		cstats = LootEngine.compute_combat_stats(hdef, eq)

	HeroRigDresser.dress(
		_hero_visual,
		cid,
		cstats.armor_tier,
		cstats.weapon_mesh_key,
		cstats.offhand_mesh_key,
		cstats.has_plume,
		cstats.lantern_color,
		cstats.to_slot_overrides()
	)
	_hero_visual.play_anim("idle", 1.0, false)
	_center_hero_on_plinth()


func _center_hero_on_plinth() -> void:
	if _hero_visual == null or _hero_visual.skeleton == null:
		return
	_hero_visual.position = Vector3.ZERO
	var hips_idx := _hero_visual.skeleton.find_bone("hips")
	if hips_idx < 0:
		return
	var hips_pose := _hero_visual.skeleton.get_bone_global_pose(hips_idx).origin
	var local_hips := _hero_visual.transform.affine_inverse() * (_hero_visual.model_pivot.transform * _hero_visual.model_instance.transform * _hero_visual.skeleton.transform * hips_pose)
	_hero_visual.position = Vector3(-local_hips.x, 0.0, -local_hips.z)


func _configure_camera() -> void:
	if stage_camera == null:
		return
	stage_camera.fov = 34.0
	stage_camera.look_at_from_position(
		Vector3(0.0, camera_height, -camera_distance),
		Vector3(0.0, look_height, 0.0),
		Vector3.UP
	)


func _build_sanctuary_props() -> void:
	if _built_props or sub_viewport == null:
		return
	_built_props = true
	_brazier_lights.clear()
	_configure_sanctuary_environment()
	var stage_root := sub_viewport.get_node_or_null("StageRoot") as Node3D
	if stage_root == null:
		return

	turntable_pivot.position = Vector3(0.0, 0.33, 0.0)

	var stone_mat := _make_cathedral_stone_material(Color(0.56, 0.58, 0.63))
	var dark_stone_mat := _make_cathedral_stone_material(Color(0.32, 0.34, 0.40))

	var ground_sh := load("res://shaders/vfx_barrow_ground.gdshader") as Shader
	if ground_sh != null:
		var gmat := ShaderMaterial.new()
		gmat.shader = ground_sh
		gmat.set_shader_parameter("ground_tint", Color(0.22, 0.23, 0.27, 1.0))
		var tex_map := {
			"forest_albedo": "res://assets/textures/ground_forest_color.jpg",
			"forest_normal": "res://assets/textures/ground_forest_normal.jpg",
			"dirt_albedo": "res://assets/textures/ground_dirt_color.jpg",
			"dirt_normal": "res://assets/textures/ground_dirt_normal.jpg",
			"stone_albedo": "res://assets/textures/rock_color.jpg",
			"stone_normal": "res://assets/textures/rock_normal.jpg",
		}
		for param in tex_map:
			var tex := load(str(tex_map[param])) as Texture2D
			if tex != null:
				gmat.set_shader_parameter(param, tex)
		var floor_mi := MeshInstance3D.new()
		floor_mi.name = "CathedralFloor"
		var pm := PlaneMesh.new()
		pm.size = Vector2(28.0, 28.0)
		pm.subdivide_width = 12
		pm.subdivide_depth = 12
		floor_mi.mesh = pm
		floor_mi.position = Vector3(0.0, 0.0, 2.0)
		floor_mi.material_override = gmat
		stage_root.add_child(floor_mi)

	var plinth_ps := load("res://assets/models/kit/kit_sanctum_plinth.glb") as PackedScene
	if plinth_ps != null:
		var plinth := plinth_ps.instantiate() as Node3D
		plinth.name = "SanctumPlinth"
		plinth.position = Vector3.ZERO
		_apply_cathedral_stone_materials(plinth, stone_mat, dark_stone_mat)
		stage_root.add_child(plinth)

	var brazier_ps := load("res://assets/models/kit/kit_wrought_brazier.glb") as PackedScene
	var flame_sh := load("res://shaders/vfx_smokey_flame.gdshader") as Shader
	var flame_quad := QuadMesh.new()
	flame_quad.size = Vector2(0.56, 0.84)
	var flame_mat: ShaderMaterial = null
	if flame_sh != null:
		flame_mat = ShaderMaterial.new()
		flame_mat.shader = flame_sh
		flame_mat.set_shader_parameter("billboard_mode", true)
		flame_mat.set_shader_parameter("soot_dominance", 0.38)
		flame_mat.set_shader_parameter("core_hdr", Vector3(5.6, 2.5, 0.52))
		flame_mat.set_shader_parameter("mid_flame", Vector3(2.2, 0.48, 0.08))
		flame_mat.set_shader_parameter("scroll_speed", 2.8)

	for side in [-1.0, 1.0]:
		var b_node := Node3D.new()
		b_node.name = "SanctumBrazierL" if side < 0.0 else "SanctumBrazierR"
		b_node.position = Vector3(side * 1.56, 0.0, 1.48)
		b_node.rotation.y = side * -0.45
		stage_root.add_child(b_node)
		if brazier_ps != null:
			var b_inst := brazier_ps.instantiate() as Node3D
			b_inst.scale = Vector3.ONE * 0.94
			b_node.add_child(b_inst)
		if flame_mat != null:
			var f_mi := MeshInstance3D.new()
			f_mi.mesh = flame_quad
			f_mi.position = Vector3(0.0, 1.54, 0.0)
			f_mi.material_override = flame_mat
			f_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b_node.add_child(f_mi)
		var blight := OmniLight3D.new()
		blight.position = Vector3(0.0, 1.84, -0.10)
		blight.light_color = Color(1.0, 0.56, 0.18)
		blight.light_energy = 2.45
		blight.omni_range = 6.8
		blight.shadow_enabled = false
		b_node.add_child(blight)
		_brazier_lights.append(blight)

	var arch_ps := load("res://assets/models/kit/kit_gothic_arch.glb") as PackedScene
	if arch_ps != null:
		var arch := arch_ps.instantiate() as Node3D
		arch.name = "CathedralArch"
		arch.position = Vector3(0.0, 0.0, 4.15)
		arch.scale = Vector3.ONE * 0.56
		_apply_cathedral_stone_materials(arch, stone_mat, dark_stone_mat)
		stage_root.add_child(arch)

	var pillar_ps := load("res://assets/models/kit/kit_gothic_pillar.glb") as PackedScene
	if pillar_ps != null:
		for side in [-1.0, 1.0]:
			var pil := pillar_ps.instantiate() as Node3D
			pil.name = "CathedralPillarL" if side < 0.0 else "CathedralPillarR"
			pil.position = Vector3(side * 2.65, 0.0, 2.75)
			pil.scale = Vector3.ONE * 0.62
			_apply_cathedral_stone_materials(pil, stone_mat, dark_stone_mat)
			stage_root.add_child(pil)

	var rim_back := OmniLight3D.new()
	rim_back.name = "CathedralBackRim"
	rim_back.position = Vector3(0.0, 3.1, 5.2)
	rim_back.light_color = Color(0.36, 0.50, 0.84)
	rim_back.light_energy = 2.35
	rim_back.omni_range = 10.5
	rim_back.shadow_enabled = false
	stage_root.add_child(rim_back)

	_build_moonlight_shafts(stage_root)
	_build_cathedral_motes(stage_root)


func _configure_sanctuary_environment() -> void:
	if sub_viewport == null:
		return
	var we := sub_viewport.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		sub_viewport.add_child(we)

	var sky := Sky.new()
	if ResourceLoader.exists("res://assets/textures/cathedral_ibl_panorama.png"):
		var pmat := PanoramaSkyMaterial.new()
		pmat.panorama = load("res://assets/textures/cathedral_ibl_panorama.png") as Texture2D
		sky.sky_material = pmat
	else:
		var sky_sh := load("res://shaders/sky_cathedral_ibl.gdshader") as Shader
		if sky_sh != null:
			var smat := ShaderMaterial.new()
			smat.shader = sky_sh
			smat.set_shader_parameter("clerestory_hdr", 2.2)
			smat.set_shader_parameter("brazier_hdr", 3.2)
			smat.set_shader_parameter("direct_bg_scale", 0.44)
			sky.sky_material = smat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = 0.82
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.15
	env.fog_enabled = true
	env.fog_density = 0.014
	env.fog_light_color = Color(0.07, 0.08, 0.12)
	env.fog_sky_affect = 0.45
	we.environment = env


static func _make_cathedral_stone_material(albedo: Color) -> StandardMaterial3D:
	var sm := StandardMaterial3D.new()
	sm.albedo_color = albedo
	var r_col := load("res://assets/textures/rock_color.jpg") as Texture2D
	var r_nrm := load("res://assets/textures/rock_normal.jpg") as Texture2D
	if r_col != null:
		sm.albedo_texture = r_col
	if r_nrm != null:
		sm.normal_enabled = true
		sm.normal_texture = r_nrm
		sm.normal_scale = 0.85
	sm.uv1_triplanar = true
	sm.uv1_scale = Vector3(0.45, 0.45, 0.45)
	sm.roughness = 0.82
	sm.metallic = 0.04
	return sm


static func _apply_cathedral_stone_materials(root_node: Node3D, stone_mat: StandardMaterial3D, dark_stone_mat: StandardMaterial3D) -> void:
	for n in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var mname := mat.resource_name if mat != null else ""
			if "ObsidianStone" in mname:
				mi.set_surface_override_material(s, dark_stone_mat)
			elif "GothicAshlarStone" in mname:
				mi.set_surface_override_material(s, stone_mat)
			elif "AntiqueGoldTrim" in mname and mat is StandardMaterial3D:
				var gold_mat := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				gold_mat.albedo_color = Color(0.76, 0.60, 0.30)
				gold_mat.roughness_texture = null
				gold_mat.metallic_texture = null
				gold_mat.roughness = 0.54
				gold_mat.metallic = 0.66
				mi.set_surface_override_material(s, gold_mat)


func _build_moonlight_shafts(stage_root: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var shaft_sh := Shader.new()
	shaft_sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 shaft_color : source_color = vec3(0.44, 0.64, 1.0);
uniform float shaft_alpha : hint_range(0.0, 0.5) = 0.12;
void fragment() {
	float x_fade = pow(clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0), 2.3);
	float y_fade = smoothstep(0.0, 0.24, UV.y) * smoothstep(1.0, 0.16, UV.y);
	float view_fade = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.35);
	float shimmer = 0.88 + 0.12 * sin(UV.y * 12.0 + UV.x * 4.5 + TIME * 0.4);
	ALBEDO = shaft_color;
	ALPHA = x_fade * y_fade * view_fade * shimmer * shaft_alpha;
}
"""
	var shafts_root := Node3D.new()
	shafts_root.name = "CathedralMoonShafts"
	stage_root.add_child(shafts_root)

	var specs := [
		{"pos": Vector3(-0.68, 2.55, 3.65), "size": Vector2(1.55, 5.6), "rot": Vector3(10.0, 12.0, -24.0), "alpha": 0.20},
		{"pos": Vector3(0.28, 2.75, 3.95), "size": Vector2(2.05, 6.1), "rot": Vector3(11.0, -8.0, -22.0), "alpha": 0.24},
		{"pos": Vector3(1.12, 2.40, 3.55), "size": Vector2(1.40, 5.3), "rot": Vector3(9.0, -16.0, -25.0), "alpha": 0.17},
	]
	for sp in specs:
		var smat := ShaderMaterial.new()
		smat.shader = shaft_sh
		smat.set_shader_parameter("shaft_alpha", float(sp["alpha"]))
		var qm := QuadMesh.new()
		qm.size = sp["size"] as Vector2
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.position = sp["pos"] as Vector3
		mi.rotation_degrees = sp["rot"] as Vector3
		mi.material_override = smat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shafts_root.add_child(mi)


func _build_cathedral_motes(stage_root: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mote_sh := Shader.new()
	mote_sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void vertex() {
	mat4 mat_world = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0]),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2]),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float soft = pow(clamp(1.0 - d, 0.0, 1.0), 3.1);
	ALBEDO = COLOR.rgb * 1.45;
	ALPHA = soft * COLOR.a;
}
"""
	var mote_mat := ShaderMaterial.new()
	mote_mat.shader = mote_sh
	var mote_quad := QuadMesh.new()
	mote_quad.size = Vector2(0.044, 0.044)
	mote_quad.surface_set_material(0, mote_mat)

	var ember_grad := Gradient.new()
	ember_grad.offsets = PackedFloat32Array([0.0, 0.20, 0.72, 1.0])
	ember_grad.colors = PackedColorArray([
		Color(1.0, 0.56, 0.18, 0.0),
		Color(1.0, 0.62, 0.22, 0.75),
		Color(0.92, 0.34, 0.08, 0.52),
		Color(0.45, 0.10, 0.02, 0.0),
	])
	var ember_ramp := GradientTexture1D.new()
	ember_ramp.gradient = ember_grad

	var ember_proc := ParticleProcessMaterial.new()
	ember_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ember_proc.emission_box_extents = Vector3(2.2, 1.3, 1.9)
	ember_proc.direction = Vector3(0.08, 1.0, -0.06).normalized()
	ember_proc.spread = 32.0
	ember_proc.initial_velocity_min = 0.16
	ember_proc.initial_velocity_max = 0.44
	ember_proc.gravity = Vector3(0.03, 0.12, 0.0)
	ember_proc.scale_min = 0.55
	ember_proc.scale_max = 1.25
	ember_proc.color_ramp = ember_ramp

	var embers := GPUParticles3D.new()
	embers.name = "CathedralEmberMotes"
	embers.position = Vector3(0.0, 1.35, 1.25)
	embers.amount = 30
	embers.lifetime = 4.4
	embers.preprocess = 2.6
	embers.randomness = 0.6
	embers.visibility_aabb = AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 7.0, 8.0))
	embers.process_material = ember_proc
	embers.draw_pass_1 = mote_quad
	embers.emitting = true
	stage_root.add_child(embers)

	var ash_grad := Gradient.new()
	ash_grad.offsets = PackedFloat32Array([0.0, 0.22, 0.76, 1.0])
	ash_grad.colors = PackedColorArray([
		Color(0.68, 0.76, 0.94, 0.0),
		Color(0.72, 0.80, 0.96, 0.44),
		Color(0.56, 0.64, 0.80, 0.30),
		Color(0.32, 0.38, 0.50, 0.0),
	])
	var ash_ramp := GradientTexture1D.new()
	ash_ramp.gradient = ash_grad

	var ash_proc := ParticleProcessMaterial.new()
	ash_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ash_proc.emission_box_extents = Vector3(2.5, 1.6, 2.3)
	ash_proc.direction = Vector3(-0.14, 0.65, -0.10).normalized()
	ash_proc.spread = 42.0
	ash_proc.initial_velocity_min = 0.10
	ash_proc.initial_velocity_max = 0.28
	ash_proc.gravity = Vector3(-0.02, 0.04, 0.0)
	ash_proc.scale_min = 0.45
	ash_proc.scale_max = 1.05
	ash_proc.color_ramp = ash_ramp

	var ash := GPUParticles3D.new()
	ash.name = "CathedralAshMotes"
	ash.position = Vector3(0.0, 1.75, 1.85)
	ash.amount = 26
	ash.lifetime = 5.4
	ash.preprocess = 3.2
	ash.randomness = 0.65
	ash.visibility_aabb = AABB(Vector3(-4.5, -2.0, -4.5), Vector3(9.0, 8.0, 9.0))
	ash.process_material = ash_proc
	ash.draw_pass_1 = mote_quad
	ash.emitting = true
	stage_root.add_child(ash)


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")
