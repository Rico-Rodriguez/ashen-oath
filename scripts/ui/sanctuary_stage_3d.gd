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
	var cid := "oathbreaker"
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
		cstats.lantern_color
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
	var stage_root := sub_viewport.get_node_or_null("StageRoot") as Node3D
	if stage_root == null:
		return

	turntable_pivot.position = Vector3(0.0, 0.33, 0.0)

	var ground_sh := load("res://shaders/vfx_barrow_ground.gdshader") as Shader
	if ground_sh != null:
		var gmat := ShaderMaterial.new()
		gmat.shader = ground_sh
		gmat.set_shader_parameter("ground_tint", Color(0.24, 0.25, 0.28, 1.0))
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
		stage_root.add_child(arch)

	var pillar_ps := load("res://assets/models/kit/kit_gothic_pillar.glb") as PackedScene
	if pillar_ps != null:
		for side in [-1.0, 1.0]:
			var pil := pillar_ps.instantiate() as Node3D
			pil.name = "CathedralPillarL" if side < 0.0 else "CathedralPillarR"
			pil.position = Vector3(side * 2.65, 0.0, 2.75)
			pil.scale = Vector3.ONE * 0.62
			stage_root.add_child(pil)

	var rim_back := OmniLight3D.new()
	rim_back.name = "CathedralBackRim"
	rim_back.position = Vector3(0.0, 3.1, 5.2)
	rim_back.light_color = Color(0.36, 0.50, 0.84)
	rim_back.light_energy = 2.35
	rim_back.omni_range = 10.5
	rim_back.shadow_enabled = false
	stage_root.add_child(rim_back)


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")
