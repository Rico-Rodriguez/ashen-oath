class_name SanctuaryStage3D
extends PanelContainer

@export var camera_distance: float = 3.65
@export var camera_height: float = 1.48
@export var look_height: float = 1.04

@onready var viewport_container: SubViewportContainer = $ViewportStack/SubViewportContainer
@onready var sub_viewport: SubViewport = $ViewportStack/SubViewportContainer/SubViewport
@onready var turntable_pivot: Node3D = $ViewportStack/SubViewportContainer/SubViewport/StageRoot/TurntablePivot
@onready var brazier_light: OmniLight3D = $ViewportStack/SubViewportContainer/SubViewport/StageRoot/BrazierRoot/BrazierLight
@onready var stage_camera: Camera3D = $ViewportStack/SubViewportContainer/SubViewport/StageCamera

var _hero_visual: ActorVisual = null
var _loaded_class_id: String = ""
var _target_yaw: float = 0.28
var _current_yaw: float = 0.28
var _dragging: bool = false
var _last_drag_x: float = 0.0
var _flicker_time: float = 0.0
var _built_props: bool = false


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
	if brazier_light != null:
		brazier_light.light_energy = 2.35 + sin(_flicker_time * 7.3) * 0.24 + cos(_flicker_time * 13.1) * 0.14
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
	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null:
		hdef = GameRegistry.get_class_def("oathbreaker")
		cid = "oathbreaker"

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


func _configure_camera() -> void:
	if stage_camera == null:
		return
	stage_camera.fov = 33.0
	stage_camera.look_at_from_position(
		Vector3(0.0, camera_height, -camera_distance),
		Vector3(0.0, look_height, 0.0),
		Vector3.UP
	)


func _build_sanctuary_props() -> void:
	if _built_props or sub_viewport == null:
		return
	_built_props = true
	var stage_root := sub_viewport.get_node_or_null("StageRoot") as Node3D
	if stage_root == null:
		return

	var stone_dark := StandardMaterial3D.new()
	stone_dark.albedo_color = Color(0.11, 0.12, 0.15)
	stone_dark.roughness = 0.86
	stone_dark.metallic = 0.08

	var stone_step := StandardMaterial3D.new()
	stone_step.albedo_color = Color(0.15, 0.16, 0.20)
	stone_step.roughness = 0.78
	stone_step.metallic = 0.12

	var bronze_trim := StandardMaterial3D.new()
	bronze_trim.albedo_color = Color(0.58, 0.45, 0.24)
	bronze_trim.metallic = 0.85
	bronze_trim.roughness = 0.30

	var floor_slab := MeshInstance3D.new()
	var fcyl := CylinderMesh.new()
	fcyl.top_radius = 4.6
	fcyl.bottom_radius = 4.8
	fcyl.height = 0.12
	fcyl.radial_segments = 32
	floor_slab.mesh = fcyl
	floor_slab.position = Vector3(0.0, -0.26, 0.0)
	floor_slab.material_override = stone_dark
	stage_root.add_child(floor_slab)

	var lower_plinth := MeshInstance3D.new()
	var lcyl := CylinderMesh.new()
	lcyl.top_radius = 1.42
	lcyl.bottom_radius = 1.56
	lcyl.height = 0.14
	lcyl.radial_segments = 24
	lower_plinth.mesh = lcyl
	lower_plinth.position = Vector3(0.0, -0.15, 0.0)
	lower_plinth.material_override = stone_dark
	stage_root.add_child(lower_plinth)

	var upper_plinth := MeshInstance3D.new()
	var ucyl := CylinderMesh.new()
	ucyl.top_radius = 1.15
	ucyl.bottom_radius = 1.24
	ucyl.height = 0.10
	ucyl.radial_segments = 24
	upper_plinth.mesh = ucyl
	upper_plinth.position = Vector3(0.0, -0.05, 0.0)
	upper_plinth.material_override = stone_step
	stage_root.add_child(upper_plinth)

	var rune_ring := MeshInstance3D.new()
	var rtor := TorusMesh.new()
	rtor.inner_radius = 1.11
	rtor.outer_radius = 1.16
	rune_ring.mesh = rtor
	rune_ring.scale = Vector3(1.0, 0.35, 1.0)
	rune_ring.position = Vector3(0.0, -0.005, 0.0)
	rune_ring.material_override = bronze_trim
	stage_root.add_child(rune_ring)

	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pbox := CylinderMesh.new()
		pbox.top_radius = 0.24
		pbox.bottom_radius = 0.28
		pbox.height = 3.8
		pbox.radial_segments = 12
		pillar.mesh = pbox
		pillar.position = Vector3(side * 2.15, 1.65, 2.35)
		pillar.material_override = stone_dark
		stage_root.add_child(pillar)

	var brazier_root := stage_root.get_node_or_null("BrazierRoot") as Node3D
	if brazier_root != null:
		var iron_mat := StandardMaterial3D.new()
		iron_mat.albedo_color = Color(0.14, 0.14, 0.16)
		iron_mat.metallic = 0.82
		iron_mat.roughness = 0.40

		var stand := MeshInstance3D.new()
		var scyl := CylinderMesh.new()
		scyl.top_radius = 0.10
		scyl.bottom_radius = 0.22
		scyl.height = 0.78
		scyl.radial_segments = 12
		stand.mesh = scyl
		stand.position = Vector3(0.0, 0.38, 0.0)
		stand.material_override = iron_mat
		brazier_root.add_child(stand)

		var bowl := MeshInstance3D.new()
		var bcyl := CylinderMesh.new()
		bcyl.top_radius = 0.30
		bcyl.bottom_radius = 0.14
		bcyl.height = 0.22
		bcyl.radial_segments = 16
		bowl.mesh = bcyl
		bowl.position = Vector3(0.0, 0.82, 0.0)
		bowl.material_override = iron_mat
		brazier_root.add_child(bowl)

		var coals := MeshInstance3D.new()
		var csph := SphereMesh.new()
		csph.radius = 0.23
		csph.height = 0.18
		coals.mesh = csph
		coals.position = Vector3(0.0, 0.92, 0.0)
		var coal_mat := StandardMaterial3D.new()
		coal_mat.albedo_color = Color(1.0, 0.52, 0.14)
		coal_mat.emission_enabled = true
		coal_mat.emission = Color(1.0, 0.42, 0.08)
		coal_mat.emission_energy_multiplier = 3.6
		coals.material_override = coal_mat
		brazier_root.add_child(coals)


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")
