class_name ActorVisual
extends Node3D

@export var actor_id: String = ""
@export var is_hero: bool = false
@export var hero_class_id: String = ""
@export var height_meters: float = 1.95
@export var yaw_offset_deg: float = 180.0
@export var armor_tier: int = 1
@export var weapon_key: String = ""
@export var offhand_key: String = ""
@export var has_plume: bool = false
@export var lantern_color: Color = Color(1.0, 0.74, 0.30, 1.0)
@export var anim_library_override: AnimationLibrary
@export var albedo_override: Texture2D
@export var emission_override: Texture2D
@export var emission_tint: Color = Color(1.0, 0.45, 0.16, 1.0)
@export var emission_energy: float = 1.8

var model_pivot: Node3D
var model_instance: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var blade_tip_marker: Marker3D
var cast_origin_marker: Marker3D
var main_weapon_node: Node3D

var _initialized: bool = false
var _hit_flash_timer: float = 0.0
var _hit_flash_duration: float = 0.11
var _flash_shaders: Array[ShaderMaterial] = []
var _flash_std_mats: Array[StandardMaterial3D] = []
var _flash_std_base_emit: Array[Color] = []
var _flash_std_base_energy: Array[float] = []
var _flash_std_had_emit: Array[bool] = []
var _cloth_shaders: Array[ShaderMaterial] = []
var _move_blend: float = 0.0
var _current_logical_anim: String = ""
var _drag_pose_weight: float = 0.0

const LOOPING_CLIPS := {
	"idle": true,
	"run": true,
	"walk": true,
	"Fly Forward In Place": true,
	"walkForward": true,
}

const RIG_CLIP_MAP := {
	"crypt_batlord": {
		"idle": "Fly Forward In Place",
		"run": "Fly Forward In Place",
		"walk": "Fly Forward In Place",
		"attack": "Bite Attack",
		"attack2": "Kick Attack",
		"skill_cast": "Kick Attack",
		"dash": "Fly Forward In Place",
		"hit": "Fly Forward In Place",
		"death": "Die",
	},
	"ash_scorpion": {
		"idle": "idle",
		"run": "walkForward",
		"walk": "walkForward",
		"attack": "clawAttackLeft",
		"attack2": "clawAttackRight",
		"skill_cast": "stingerAttack",
		"dash": "jump",
		"hit": "buff1",
		"death": "death",
	},
	"dread_golem": {
		"idle": "idle",
		"run": "walk",
		"walk": "walk",
		"attack": "hit",
		"attack2": "hit2",
		"skill_cast": "rage",
		"dash": "jump",
		"hit": "damage",
		"death": "die",
	},
	"barrow_troll": {
		"idle": "idle",
		"run": "run",
		"walk": "walk",
		"attack": "attack",
		"attack2": "swipe",
		"skill_cast": "roar",
		"dash": "run",
		"hit": "hit",
		"death": "death",
	},
	"blight_werewolf": {
		"idle": "idle",
		"run": "run",
		"walk": "walk",
		"attack": "attack",
		"attack2": "swipe",
		"skill_cast": "swipe",
		"dash": "run",
		"hit": "hit",
		"death": "death",
	},
	"stone_gargoyle": {
		"idle": "idle",
		"run": "run",
		"walk": "walk",
		"attack": "attack",
		"attack2": "bash",
		"skill_cast": "cast",
		"dash": "dodge",
		"hit": "hit",
		"death": "death",
	},
	"infernal_minotaur": {
		"idle": "idle",
		"run": "run",
		"walk": "walk",
		"attack": "attack",
		"attack2": "bash",
		"skill_cast": "cast",
		"dash": "dodge",
		"hit": "hit",
		"death": "death",
	},
}

const DEFAULT_HUMANOID_MAP := {
	"idle": "idle",
	"run": "run",
	"walk": "walk",
	"attack": "attack",
	"attack2": "attack2",
	"skill_cast": "cast",
	"dash": "dodge",
	"hit": "hit",
	"death": "death",
}


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	model_pivot = get_node_or_null("ModelPivot") as Node3D
	if model_pivot == null:
		model_pivot = Node3D.new()
		model_pivot.name = "ModelPivot"
		add_child(model_pivot)

	for child in model_pivot.get_children():
		if child is Node3D:
			model_instance = child as Node3D
			break

	if model_instance == null:
		return

	_hide_builtin_props()
	_bind_skeleton_and_animations()
	_pose_for_measurement()
	_normalize_pivot_transform()

	if is_hero:
		HeroRigDresser.dress(
			self,
			hero_class_id if hero_class_id != "" else actor_id,
			armor_tier,
			weapon_key,
			offhand_key,
			has_plume,
			lantern_color
		)
	else:
		_configure_enemy_materials()

	play_anim("idle", 1.0, true)


func _process(delta: float) -> void:
	_update_weapon_drag_pose(delta)
	if _hit_flash_timer <= 0.0:
		return
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	var ratio := _hit_flash_timer / maxf(_hit_flash_duration, 0.001)
	_apply_hit_flash_level(ratio)


func register_shader_materials(armor_mats: Array[ShaderMaterial], cloth_mats: Array[ShaderMaterial]) -> void:
	_flash_shaders.clear()
	_cloth_shaders.clear()
	for m in armor_mats:
		if m != null and not _flash_shaders.has(m):
			_flash_shaders.append(m)
	for cm in cloth_mats:
		if cm != null:
			if not _cloth_shaders.has(cm):
				_cloth_shaders.append(cm)
			if not _flash_shaders.has(cm):
				_flash_shaders.append(cm)
			cm.set_shader_parameter("move_speed_norm", _move_blend)


func play_anim(logical_name: String, speed_scale: float = 1.0, force_restart: bool = false) -> void:
	ensure_initialized()
	if anim_player == null:
		return
	var clip := _resolve_clip_name(logical_name)
	if clip == "" or not anim_player.has_animation(clip):
		return
	var anim_res := anim_player.get_animation(clip)
	if anim_res != null:
		anim_res.loop_mode = Animation.LOOP_LINEAR if LOOPING_CLIPS.has(logical_name) or LOOPING_CLIPS.has(clip) else Animation.LOOP_NONE
	if not force_restart and _current_logical_anim == logical_name and anim_player.current_animation == clip and anim_player.is_playing():
		anim_player.speed_scale = speed_scale
		return
	_current_logical_anim = logical_name
	anim_player.play(clip, 0.12, speed_scale)
	if force_restart:
		anim_player.seek(0.0, true)


func trigger_hit_flash(duration: float = 0.11) -> void:
	ensure_initialized()
	_hit_flash_duration = maxf(duration, 0.01)
	_hit_flash_timer = _hit_flash_duration
	_apply_hit_flash_level(1.0)


func set_move_blend(speed_01: float) -> void:
	_move_blend = clampf(speed_01, 0.0, 1.0)
	for cm in _cloth_shaders:
		if cm != null:
			cm.set_shader_parameter("move_speed_norm", _move_blend)
	_update_weapon_drag_pose(0.0)


func _update_weapon_drag_pose(delta: float) -> void:
	if not is_hero or main_weapon_node == null or not is_instance_valid(main_weapon_node):
		return
	if not main_weapon_node.has_meta("_base_basis"):
		return
	var base_b: Basis = main_weapon_node.get_meta("_base_basis")
	var drags := weapon_key in ["zweihander", "greatsword", "blade_oarimaar", "halberd", "poleaxe"]
	var wants_drag := drags and (_current_logical_anim in ["run", "walk"]) and _move_blend > 0.20
	var target_w := clampf((_move_blend - 0.20) / 0.35, 0.0, 1.0) if wants_drag else 0.0
	if delta <= 0.0:
		_drag_pose_weight = target_w
	else:
		_drag_pose_weight = move_toward(_drag_pose_weight, target_w, delta * 9.5)

	if _drag_pose_weight <= 0.001:
		main_weapon_node.basis = base_b
		return

	var parent_3d := main_weapon_node.get_parent() as Node3D
	if parent_3d == null or not is_inside_tree():
		return
	var wy := (global_transform.basis * Vector3(0.32, -0.54, 0.78)).normalized()
	var side_hint := (global_transform.basis * Vector3(0.92, 0.14, -0.34)).normalized()
	var wz := side_hint.cross(wy).normalized()
	var wx := wy.cross(wz).normalized()
	var desired_world_rot := Basis(wx, wy, wz).orthonormalized()
	var parent_rot := parent_3d.global_transform.basis.orthonormalized()
	var drag_local := (parent_rot.inverse() * desired_world_rot).orthonormalized()
	var q_base := base_b.orthonormalized().get_rotation_quaternion()
	var q_drag := drag_local.get_rotation_quaternion()
	main_weapon_node.basis = Basis(q_base.slerp(q_drag, _drag_pose_weight)) * Basis.from_scale(base_b.get_scale())


func get_blade_tip_global() -> Vector3:
	if blade_tip_marker != null and is_instance_valid(blade_tip_marker):
		return blade_tip_marker.global_position
	if main_weapon_node != null and is_instance_valid(main_weapon_node):
		return main_weapon_node.global_position
	return global_position + global_transform.basis * Vector3(0.0, height_meters * 0.55, -0.65)


func get_cast_origin_global() -> Vector3:
	if cast_origin_marker != null and is_instance_valid(cast_origin_marker):
		return cast_origin_marker.global_position
	if main_weapon_node != null and is_instance_valid(main_weapon_node) and ("staff" in weapon_key):
		return get_blade_tip_global()
	return global_position + global_transform.basis * Vector3(0.0, height_meters * 0.68, -0.45)


func _hide_builtin_props() -> void:
	var cid := hero_class_id if hero_class_id != "" else actor_id
	for n in model_instance.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		if nd.name in ["BastardScabbard", "swordscabbard", "shortsword", "bastardsword", "scabbard_2", "sword"]:
			if nd.name == "bastardsword":
				for sub in nd.find_children("*", "MeshInstance3D", true, false):
					var smi := sub as MeshInstance3D
					if smi.mesh != null and not model_instance.has_meta("_cached_bastardsword_mesh"):
						model_instance.set_meta("_cached_bastardsword_mesh", smi.mesh)
			nd.visible = false
		elif cid == "battlemage" and nd.name == "Object_8" and nd is MeshInstance3D:
			nd.visible = false


func _bind_skeleton_and_animations() -> void:
	var skels := model_instance.find_children("*", "Skeleton3D", true, false)
	if skels.size() > 0:
		skeleton = skels[0] as Skeleton3D

	var aps := model_instance.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		anim_player = aps[0] as AnimationPlayer
	elif anim_library_override != null:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		model_instance.add_child(anim_player)

	if anim_player != null and anim_library_override != null:
		if anim_player.has_animation_library(&""):
			anim_player.remove_animation_library(&"")
		anim_player.add_animation_library(&"", anim_library_override)


func _pose_for_measurement() -> void:
	if anim_player == null:
		return
	var idle_clip := _resolve_clip_name("idle")
	if idle_clip != "" and anim_player.has_animation(idle_clip):
		anim_player.play(idle_clip)
		anim_player.seek(0.0, true)
		anim_player.advance(0.0)


func _normalize_pivot_transform() -> void:
	model_pivot.position = Vector3.ZERO
	model_pivot.rotation = Vector3.ZERO
	model_pivot.scale = Vector3.ONE

	var raw_box := _compute_posed_model_aabb()
	if raw_box.size.y <= 0.0001:
		model_pivot.rotation_degrees = Vector3(0.0, yaw_offset_deg, 0.0)
		return

	var scale_factor := height_meters / raw_box.size.y
	var rot_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(yaw_offset_deg), 0.0))
	var scaled_rot := rot_basis.scaled(Vector3.ONE * scale_factor)

	var foot_center_local := Vector3(
		raw_box.position.x + raw_box.size.x * 0.5,
		raw_box.position.y,
		raw_box.position.z + raw_box.size.z * 0.5
	)
	var offset := scaled_rot * (model_instance.transform * foot_center_local)

	model_pivot.basis = scaled_rot
	model_pivot.position = -offset


func _compute_posed_model_aabb() -> AABB:
	var inv_model_root := model_instance.global_transform.affine_inverse()
	var has_pt := false
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)

	for n in model_instance.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not _is_visible_in_hierarchy(mi, model_instance) or mi.mesh == null:
			continue
		if String(mi.name).begins_with("Forged"):
			continue

		var skel_node := mi.get_node_or_null(mi.skeleton) as Skeleton3D if not mi.skeleton.is_empty() else skeleton
		if mi.skin != null and skel_node != null:
			var skel_to_model := inv_model_root * skel_node.global_transform
			var bind_count := mi.skin.get_bind_count()
			var palette: Array[Transform3D] = []
			palette.resize(bind_count)
			for b_i in bind_count:
				var bone_idx := mi.skin.get_bind_bone(b_i)
				if bone_idx < 0:
					bone_idx = skel_node.find_bone(mi.skin.get_bind_name(b_i))
				var pose_xf := skel_node.get_bone_global_pose(bone_idx) if bone_idx >= 0 else Transform3D.IDENTITY
				palette[b_i] = skel_to_model * (pose_xf * mi.skin.get_bind_pose(b_i))

			for s in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones_arr = arrays[Mesh.ARRAY_BONES]
				var weights_arr = arrays[Mesh.ARRAY_WEIGHTS]
				var vcount := verts.size()
				if vcount == 0:
					continue
				if bones_arr == null or weights_arr == null or bones_arr.size() < vcount * 4:
					var fallback_xf := inv_model_root * mi.global_transform
					var fb := fallback_xf * mi.mesh.get_aabb()
					min_v = min_v.min(fb.position)
					max_v = max_v.max(fb.end)
					has_pt = true
					continue

				var stride := maxi(1, vcount / 900)
				var bones_per_v: int = bones_arr.size() / vcount
				var i := 0
				while i < vcount:
					var v := verts[i]
					var base := i * bones_per_v
					var skinned := Vector3.ZERO
					var wsum := 0.0
					for k in mini(4, bones_per_v):
						var w := float(weights_arr[base + k])
						if w > 0.0001:
							var bi := int(bones_arr[base + k])
							if bi >= 0 and bi < bind_count:
								skinned += (palette[bi] * v) * w
								wsum += w
					if wsum <= 0.0001:
						skinned = (inv_model_root * mi.global_transform) * v
					elif absf(wsum - 1.0) > 0.01:
						skinned /= wsum
					min_v = min_v.min(skinned)
					max_v = max_v.max(skinned)
					has_pt = true
					i += stride
		else:
			var rel_xf := inv_model_root * mi.global_transform
			var m_box := rel_xf * mi.get_aabb()
			min_v = min_v.min(m_box.position)
			max_v = max_v.max(m_box.end)
			has_pt = true

	if not has_pt:
		return AABB()
	return AABB(min_v, max_v - min_v)


func _configure_enemy_materials() -> void:
	_flash_std_mats.clear()
	_flash_std_base_emit.clear()
	_flash_std_base_energy.clear()
	_flash_std_had_emit.clear()

	var troll_veins := {}
	if actor_id == "barrow_troll":
		troll_veins = {
			"MI_Troll_Body_Mountain01_Upper": load("res://assets/models/sketchfab/boss/troll_veins_upper.png"),
			"MI_Troll_Body_Mountain01_Lower": load("res://assets/models/sketchfab/boss/troll_veins_lower.png"),
			"MI_Troll_Heads_Cave": load("res://assets/models/sketchfab/boss/troll_veins_head.png"),
		}

	for n in model_instance.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var active := mi.get_active_material(s)
			var sm: StandardMaterial3D
			if active is StandardMaterial3D:
				sm = (active as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				sm = StandardMaterial3D.new()
			var orig_name := active.resource_name if active != null else ""

			if albedo_override != null:
				sm.albedo_texture = albedo_override
				sm.roughness = 0.72
				sm.metallic = 0.12

			if actor_id == "crypt_batlord":
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				sm.albedo_color = Color(0.28, 0.22, 0.26)
				sm.roughness = 0.78
				sm.metallic = 0.06
				sm.emission_enabled = true
				if sm.albedo_texture != null:
					sm.emission_texture = sm.albedo_texture
					sm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					sm.emission = Color(0.55, 0.08, 0.10)
					sm.emission_energy_multiplier = 0.35
				else:
					sm.emission_texture = null
					sm.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
					sm.emission = Color(0.55, 0.08, 0.10)
					sm.emission_energy_multiplier = 0.08
				sm.rim_enabled = true
				sm.rim = 0.42
				sm.rim_tint = 0.25
			elif actor_id == "infernal_minotaur":
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				sm.albedo_color = Color(0.30, 0.24, 0.21)
				sm.roughness = 0.72
				sm.metallic = 0.16
				sm.emission_enabled = true
				if sm.albedo_texture != null:
					sm.emission_texture = sm.albedo_texture
					sm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					sm.emission = Color(0.45, 0.12, 0.03)
					sm.emission_energy_multiplier = 0.25
				else:
					sm.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
					sm.emission = Color(0.45, 0.12, 0.03)
					sm.emission_energy_multiplier = 0.08

			if emission_override != null and (actor_id != "blight_werewolf" or orig_name == "Body"):
				sm.emission_enabled = true
				sm.emission_texture = emission_override
				sm.emission = emission_tint
				sm.emission_energy_multiplier = emission_energy
				sm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			elif troll_veins.has(orig_name) and troll_veins[orig_name] != null:
				sm.emission_enabled = true
				sm.emission_texture = troll_veins[orig_name]
				sm.emission = emission_tint
				sm.emission_energy_multiplier = emission_energy
				sm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY

			mi.set_surface_override_material(s, sm)
			_flash_std_mats.append(sm)
			_flash_std_had_emit.append(sm.emission_enabled)
			_flash_std_base_emit.append(sm.emission)
			_flash_std_base_energy.append(sm.emission_energy_multiplier)


func _apply_hit_flash_level(level: float) -> void:
	var lv := clampf(level, 0.0, 1.0)
	for smat in _flash_shaders:
		if smat != null:
			smat.set_shader_parameter("hit_flash", lv)
	for i in _flash_std_mats.size():
		var m := _flash_std_mats[i]
		if m == null:
			continue
		if lv > 0.001:
			m.emission_enabled = true
			m.emission = _flash_std_base_emit[i].lerp(Color(1.0, 0.90, 0.76), lv)
			m.emission_energy_multiplier = lerpf(_flash_std_base_energy[i], 2.6, lv)
		else:
			m.emission_enabled = _flash_std_had_emit[i]
			m.emission = _flash_std_base_emit[i]
			m.emission_energy_multiplier = _flash_std_base_energy[i]


func _resolve_clip_name(logical_name: String) -> String:
	if anim_player == null:
		return ""
	var map: Dictionary = RIG_CLIP_MAP.get(actor_id, DEFAULT_HUMANOID_MAP)
	var candidate: String = str(map.get(logical_name, logical_name))
	if anim_player.has_animation(candidate):
		return candidate
	if anim_player.has_animation(logical_name):
		return logical_name
	for fallback in ["idle", "Fly Forward In Place"]:
		if anim_player.has_animation(fallback):
			return fallback
	return ""


static func _is_visible_in_hierarchy(node: Node3D, stop_at: Node) -> bool:
	var cur: Node = node
	while cur != null:
		if cur is Node3D and not (cur as Node3D).visible:
			return false
		if cur == stop_at:
			break
		cur = cur.get_parent()
	return true
