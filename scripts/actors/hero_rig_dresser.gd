class_name HeroRigDresser
extends RefCounted

const ARMOR_SHADER_PATH := "res://shaders/armor_forge.gdshader"
const CLOAK_SHADER_PATH := "res://shaders/cloak_sway.gdshader"
const DISCARD_SHADER_PATH := "res://shaders/discard_alpha.gdshader"
const ARMOR_VORONOI_TEX_PATH := "res://assets/textures/armor_voronoi_tile.png"
const WAIST_LANTERN_PATH := "res://assets/models/forged/waist_lantern.glb"
const CLOAK_TATTERED_PATH := "res://assets/models/forged/cloak_tattered.glb"
const HELM_PLUME_PATH := "res://assets/models/forged/helm_plume.glb"

const FORGED_WEAPONS := {
	"zweihander": {
		"path": "res://assets/models/forged/zweihander.glb",
		"tip_y": 1.28,
		"grip_y": 0.0,
		"pitch_deg": 42.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
	},
	"greatsword": {
		"path": "res://assets/models/forged/zweihander.glb",
		"tip_y": 1.28,
		"grip_y": 0.0,
		"pitch_deg": 42.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
	},
	"blade_oarimaar": {
		"path": "res://assets/models/forged/warden_greatsword.glb",
		"fallback_path": "res://assets/models/forged/zweihander.glb",
		"tip_y": 1.34,
		"grip_y": 0.0,
		"pitch_deg": 42.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
		"cursed_ember": true,
	},
	"warden_greatsword": {
		"path": "res://assets/models/forged/warden_greatsword.glb",
		"fallback_path": "res://assets/models/forged/zweihander.glb",
		"tip_y": 1.34,
		"grip_y": 0.0,
		"pitch_deg": 42.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
		"cursed_ember": true,
	},
	"halberd": {
		"path": "res://assets/models/forged/halberd.glb",
		"tip_y": 1.37,
		"grip_y": 0.0,
		"pitch_deg": 66.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
	},
	"poleaxe": {
		"path": "res://assets/models/forged/halberd.glb",
		"tip_y": 1.37,
		"grip_y": 0.0,
		"pitch_deg": 66.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
	},
	"bastardsword": {
		"path": "res://assets/models/forged/bastardsword.glb",
		"fallback_legacy_sword": true,
		"tip_y": 0.99,
		"grip_y": 0.0,
		"pitch_deg": 38.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
	},
	"longsword": {
		"path": "res://assets/models/forged/bastardsword.glb",
		"fallback_legacy_sword": true,
		"tip_y": 0.99,
		"grip_y": 0.0,
		"pitch_deg": 38.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
	},
	"sword": {
		"path": "res://assets/models/forged/bastardsword.glb",
		"fallback_legacy_sword": true,
		"tip_y": 0.99,
		"grip_y": 0.0,
		"pitch_deg": 38.0,
		"spin_y_deg": 90.0,
		"kit_spin_y_deg": 0.0,
	},
	"runed_staff": {
		"path": "res://assets/models/forged/runed_staff.glb",
		"tip_y": 1.08,
		"cast_y": 0.73,
		"grip_y": 0.0,
		"pitch_deg": 72.0,
		"spin_y_deg": 0.0,
		"kit_spin_y_deg": 0.0,
		"is_staff": true,
	},
	"staff": {
		"path": "res://assets/models/forged/runed_staff.glb",
		"tip_y": 1.08,
		"cast_y": 0.73,
		"grip_y": 0.0,
		"pitch_deg": 72.0,
		"spin_y_deg": 0.0,
		"kit_spin_y_deg": 0.0,
		"is_staff": true,
	},
}

const GEAR_SHIELD_PATHS := {
	"shield_round": "res://assets/models/gear/shield_round.res",
	"round_shield": "res://assets/models/gear/shield_round.res",
	"shield_heater": "res://assets/models/gear/shield_heater.res",
	"heater_shield": "res://assets/models/gear/shield_heater.res",
	"shield": "res://assets/models/gear/shield_heater.res",
	"shield_tower": "res://assets/models/gear/shield_tower.res",
	"tower_shield": "res://assets/models/gear/shield_tower.res",
}

const MODULAR_SHIELDS := {
	"shield_round": {"path": "res://assets/models/forged/gothic_shield.glb", "fallback_res": "res://assets/models/gear/shield_round.res", "scale": 0.90},
	"round_shield": {"path": "res://assets/models/forged/gothic_shield.glb", "fallback_res": "res://assets/models/gear/shield_round.res", "scale": 0.90},
	"shield_heater": {"path": "res://assets/models/forged/gothic_shield.glb", "fallback_res": "res://assets/models/gear/shield_heater.res", "scale": 1.00},
	"heater_shield": {"path": "res://assets/models/forged/gothic_shield.glb", "fallback_res": "res://assets/models/gear/shield_heater.res", "scale": 1.00},
	"shield": {"path": "res://assets/models/forged/gothic_shield.glb", "fallback_res": "res://assets/models/gear/shield_heater.res", "scale": 1.00},
	"shield_tower": {"path": "res://assets/models/forged/gothic_shield.glb", "fallback_res": "res://assets/models/gear/shield_tower.res", "scale": 1.12},
	"tower_shield": {"path": "res://assets/models/forged/gothic_shield.glb", "fallback_res": "res://assets/models/gear/shield_tower.res", "scale": 1.12},
}

const MODULAR_HELMS := {
	"helm_t2": "res://assets/models/gear/helm_t2_sallet.glb",
	"helm_t3": "res://assets/models/gear/helm_t3_sovereign.glb",
	"helm_t4": "res://assets/models/gear/helm_t4_ashen.glb",
}

const MODULAR_SLOTS := {
	"helm": {"node": "Slot_Helm", "bone": "head", "kind": "armor", "override_key": "helm_key"},
	"plume": {"node": "Slot_Plume", "bone": "head", "kind": "plume", "override_key": ""},
	"pauldrons": {"node": "Slot_Pauldrons", "bone": "chest", "kind": "armor", "override_key": "pauldron_key"},
	"cuirass": {"node": "Slot_Cuirass", "bone": "chest", "kind": "armor", "override_key": "cuirass_key"},
	"gauntlets": {"node": "Slot_Gauntlets", "bone": "hand_r", "kind": "armor", "override_key": "gauntlet_key"},
	"greaves": {"node": "Slot_Greaves", "bone": "hips", "kind": "armor", "override_key": "greaves_key"},
	"cloak": {"node": "Slot_Cloak", "bone": "cape_0", "kind": "cloak", "override_key": "cloak_key"},
}

const CLASS_BONES := {
	"oathbreaker": {
		"hips": "hips_01",
		"chest": "chest_013",
		"neck": "neck_061",
		"head": "head_062",
		"crown": "tip_063",
		"hand_r": "R_wrist_041",
		"hand_l": "L_wrist_017",
	},
	"revenant": {
		"hips": "hips_01",
		"chest": "chest_035",
		"neck": "neck_084",
		"head": "head_085",
		"crown": "top_086",
		"hand_r": "R_wrist_063",
		"hand_l": "L_wrist_039",
	},
	"battlemage": {
		"hips": "b_Pelvis_03",
		"chest": "b_Chest_011",
		"neck": "b_Neck_012",
		"head": "b_Face_013",
		"crown": "",
		"hand_r": "b_Hand_Right_025",
		"hand_l": "b_Hand_Left_00",
	},
}

const CLASS_CLOAK_COLORS := {
	"oathbreaker": Color(0.11, 0.12, 0.16),
	"battlemage": Color(0.08, 0.10, 0.17),
	"revenant": Color(0.24, 0.04, 0.05),
}

static var _discard_mat: ShaderMaterial = null
static var _voronoi_tex: Texture2D = null


static func dress(
	visual: ActorVisual,
	class_id: String,
	armor_tier: int,
	weapon_key: String,
	offhand_key: String,
	has_plume: bool,
	lantern_color: Color,
	slot_overrides: Dictionary = {}
) -> void:
	if visual == null:
		return
	visual.ensure_initialized()
	if visual.skeleton == null or visual.model_instance == null:
		return

	var cid := class_id if CLASS_BONES.has(class_id) else (class_id if class_id != "" else "oathbreaker")
	var base_tier := clampi(armor_tier, 1, 4)
	var raw_cuirass_tier := int(slot_overrides.get("cuirass_tier", 0))
	var cuirass_tier := clampi(raw_cuirass_tier, 1, 4) if raw_cuirass_tier > 0 else base_tier
	var raw_helm_tier := int(slot_overrides.get("helm_tier", 0))
	var helm_tier := clampi(raw_helm_tier, 1, 4) if raw_helm_tier > 0 else cuirass_tier
	var lantern_tier := clampi(int(slot_overrides.get("lantern_tier", 1)), 1, 4)
	var helm_key := str(slot_overrides.get("helm_key", ""))

	var resolved_overrides := {
		"helm_tier": helm_tier,
		"cuirass_tier": cuirass_tier,
		"lantern_tier": lantern_tier,
		"helm_key": helm_key,
		"cuirass_key": str(slot_overrides.get("cuirass_key", "")),
		"pauldron_key": str(slot_overrides.get("pauldron_key", "")),
		"gauntlet_key": str(slot_overrides.get("gauntlet_key", "")),
		"greaves_key": str(slot_overrides.get("greaves_key", "")),
		"cloak_key": str(slot_overrides.get("cloak_key", "")),
	}

	visual.hero_class_id = cid
	visual.armor_tier = cuirass_tier
	visual.cuirass_tier = cuirass_tier
	visual.helm_tier = helm_tier
	visual.lantern_tier = lantern_tier
	visual.weapon_key = weapon_key
	visual.offhand_key = offhand_key
	visual.helm_key = helm_key
	visual.has_plume = has_plume
	visual.lantern_color = lantern_color
	visual.slot_overrides = resolved_overrides

	var skel := visual.skeleton
	_clear_previous_attachments(skel)
	_restore_base_slot_visibility(visual.model_instance)
	visual.blade_tip_marker = null
	visual.cast_origin_marker = null
	visual.main_weapon_node = null

	if visual.anim_player != null and visual.anim_player.has_animation("idle"):
		visual.anim_player.play("idle")
		visual.anim_player.seek(0.0, true)
		visual.anim_player.advance(0.0)

	if cid == "battlemage" and skel.find_bone("weapon_r") < 0:
		_suppress_plague_builtin_staff(
			skel,
			weapon_key != "" and weapon_key != "none",
			true
		)

	var skel_world_scale := maxf(skel.global_transform.basis.get_scale().y, 0.0001)
	var inv_skel_scale := 1.0 / skel_world_scale

	if skel.find_bone("weapon_r") >= 0:
		_dress_unified_kit(
			visual,
			skel,
			cid,
			cuirass_tier,
			helm_tier,
			lantern_tier,
			weapon_key,
			offhand_key,
			has_plume,
			lantern_color,
			resolved_overrides,
			inv_skel_scale
		)
		return

	var armor_mats := _apply_armor_forge_shader(visual.model_instance, cuirass_tier)
	var cloth_mats: Array[ShaderMaterial] = []
	var bones: Dictionary = CLASS_BONES.get(cid, CLASS_BONES["oathbreaker"])
	var sockets := _extract_sockets(visual.anim_player)

	if weapon_key != "" and weapon_key != "none":
		_mount_weapon(visual, skel, bones, sockets, weapon_key, cuirass_tier, lantern_color, inv_skel_scale)

	if offhand_key != "" and offhand_key != "none":
		var sh_mats := _mount_offhand(visual, skel, bones, sockets, offhand_key, cuirass_tier, inv_skel_scale)
		armor_mats.append_array(sh_mats)

	var cloak_mat := _mount_cloak(skel, cid, bones, cuirass_tier, inv_skel_scale)
	if cloak_mat != null:
		cloth_mats.append(cloak_mat)

	if has_plume:
		var plume_mat := _mount_plume(skel, cid, bones, helm_tier, inv_skel_scale)
		if plume_mat != null:
			cloth_mats.append(plume_mat)

	_mount_waist_lantern(skel, cid, bones, lantern_color, lantern_tier, inv_skel_scale)
	_mount_fallback_cast_origin(visual, skel, bones, sockets, inv_skel_scale)

	visual.register_shader_materials(armor_mats, cloth_mats)


static func equip_modular_slot(
	visual: ActorVisual,
	slot_name: String,
	scene_path: String,
	tier: int = 1
) -> bool:
	if visual == null:
		return false
	visual.ensure_initialized()
	if visual.skeleton == null or visual.model_instance == null:
		return false
	if not MODULAR_SLOTS.has(slot_name):
		return false

	var spec: Dictionary = MODULAR_SLOTS[slot_name]
	var skel := visual.skeleton
	var clamped_tier := clampi(tier, 1, 4)
	var attach_name := "ModularSlot_" + slot_name

	var old_attach := skel.get_node_or_null(attach_name)
	if old_attach != null:
		skel.remove_child(old_attach)
		old_attach.free()

	var base_nodes := _find_slot_meshes(visual.model_instance, str(spec["node"]))
	if scene_path == "":
		for bmi in base_nodes:
			bmi.visible = visual.has_plume if slot_name == "plume" else true
		return true

	var loaded_root := _load_modular_asset_node(scene_path)
	if loaded_root == null:
		return false

	var skinned_meshes: Array[MeshInstance3D] = []
	var rigid_meshes: Array[MeshInstance3D] = []
	for n in loaded_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		if mi.skin != null or not mi.skeleton.is_empty():
			skinned_meshes.append(mi)
		else:
			rigid_meshes.append(mi)
	if loaded_root is MeshInstance3D:
		var root_mi := loaded_root as MeshInstance3D
		if root_mi.mesh != null:
			if root_mi.skin != null or not root_mi.skeleton.is_empty():
				skinned_meshes.append(root_mi)
			else:
				rigid_meshes.append(root_mi)

	var container: Node3D = null
	var new_armor_mats: Array[ShaderMaterial] = []
	var new_cloth_mats: Array[ShaderMaterial] = []

	if not skinned_meshes.is_empty():
		var holder := Node3D.new()
		holder.name = attach_name
		skel.add_child(holder)
		for src_mi in skinned_meshes:
			var dup_mi := MeshInstance3D.new()
			dup_mi.name = src_mi.name
			dup_mi.mesh = src_mi.mesh
			dup_mi.transform = Transform3D.IDENTITY
			holder.add_child(dup_mi)
			dup_mi.skeleton = dup_mi.get_path_to(skel)
			if src_mi.skin != null:
				dup_mi.skin = _remap_skin_to_skeleton(src_mi.skin, skel)
			_style_modular_mesh(dup_mi, str(spec["kind"]), clamped_tier, visual.hero_class_id, new_armor_mats, new_cloth_mats, slot_name)
		loaded_root.free()
		container = holder
	elif not rigid_meshes.is_empty():
		var bone_name := str(spec["bone"])
		var bone_idx := skel.find_bone(bone_name)
		if bone_idx < 0:
			bone_idx = skel.find_bone("head" if slot_name in ["helm", "plume"] else "chest")
		if bone_idx < 0:
			loaded_root.free()
			return false
		var ba := BoneAttachment3D.new()
		ba.name = attach_name
		ba.bone_name = skel.get_bone_name(bone_idx)
		ba.bone_idx = bone_idx
		skel.add_child(ba)

		var mount := Node3D.new()
		mount.name = "SocketMount"
		var rest_global := skel.get_bone_global_rest(bone_idx)
		var rest_inv := rest_global.affine_inverse()
		var local_box := _compute_local_aabb(loaded_root)
		if local_box.size.length() > 0.001 and local_box.get_center().y > 0.75:
			mount.transform = rest_inv
		else:
			mount.transform = rest_inv * Transform3D(Basis.IDENTITY, rest_global.origin)
		ba.add_child(mount)
		mount.add_child(loaded_root)
		for rmi in rigid_meshes:
			_style_modular_mesh(rmi, str(spec["kind"]), clamped_tier, visual.hero_class_id, new_armor_mats, new_cloth_mats, slot_name)
		container = ba
	else:
		loaded_root.free()
		return false

	for bmi in base_nodes:
		bmi.visible = false

	visual.append_shader_materials(new_armor_mats, new_cloth_mats)
	return container != null


static func _clear_previous_attachments(skel: Skeleton3D) -> void:
	var to_remove: Array[Node] = []
	for child in skel.get_children():
		var cname := String(child.name)
		if cname.begins_with("ForgedAttach_") or cname.begins_with("ModularSlot_"):
			to_remove.append(child)
	for n in to_remove:
		skel.remove_child(n)
		n.free()


static func _restore_base_slot_visibility(model_root: Node3D) -> void:
	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.begins_with("Slot_") or "weapon" in nm.to_lower():
			mi.visible = true


static func _find_slot_meshes(model_root: Node3D, slot_node_name: String) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm == slot_node_name or nm.begins_with(slot_node_name + "_") or nm.begins_with(slot_node_name + "."):
			found.append(mi)
	return found


static func _slot_name_for_mesh(mi: MeshInstance3D) -> String:
	var nm := String(mi.name)
	for slot_key in MODULAR_SLOTS:
		var prefix := str(MODULAR_SLOTS[slot_key]["node"])
		if nm == prefix or nm.begins_with(prefix + "_") or nm.begins_with(prefix + "."):
			return slot_key
	return ""


static func _load_modular_asset_node(scene_path: String) -> Node3D:
	if scene_path.begins_with("res://"):
		if not ResourceLoader.exists(scene_path):
			return null
		var res := load(scene_path)
		if res is PackedScene:
			return (res as PackedScene).instantiate() as Node3D
		if res is Mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = res as Mesh
			return mi
		return null
	if FileAccess.file_exists(scene_path) and scene_path.to_lower().ends_with(".glb"):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		if gltf.append_from_file(scene_path, state) == OK:
			return gltf.generate_scene(state) as Node3D
	return null


static func _remap_skin_to_skeleton(src_skin: Skin, target_skel: Skeleton3D) -> Skin:
	var out := src_skin.duplicate() as Skin
	for i in out.get_bind_count():
		var bname := out.get_bind_name(i)
		if bname != "":
			var idx := target_skel.find_bone(bname)
			if idx >= 0:
				out.set_bind_bone(i, idx)
	return out


static func _compute_local_aabb(root_node: Node3D) -> AABB:
	var has_pt := false
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for n in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n as MeshInstance3D)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var box := mi.transform * mi.mesh.get_aabb()
		min_v = min_v.min(box.position)
		max_v = max_v.max(box.end)
		has_pt = true
	return AABB(min_v, max_v - min_v) if has_pt else AABB()


static func _style_modular_mesh(
	mi: MeshInstance3D,
	kind: String,
	tier: int,
	class_id: String,
	armor_mats: Array[ShaderMaterial],
	cloth_mats: Array[ShaderMaterial],
	slot_name: String = ""
) -> void:
	if mi.mesh == null:
		return
	var armor_shader := load(ARMOR_SHADER_PATH) as Shader
	var cloak_shader := load(CLOAK_SHADER_PATH) as Shader
	var pal := _tier_cloth_palette(tier, class_id)
	for s in mi.mesh.get_surface_count():
		var orig_mat := mi.get_active_material(s)
		if kind == "cloak" and cloak_shader != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var cmat := _make_cloak_shader_mat(cloak_shader, pal["cape_base"], pal["cape_trim"], 0.085)
			mi.set_surface_override_material(s, cmat)
			cloth_mats.append(cmat)
		elif kind == "plume" and cloak_shader != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var pmat := _make_cloak_shader_mat(cloak_shader, pal["plume_col"], (pal["plume_col"] as Color).darkened(0.28), 0.035)
			mi.set_surface_override_material(s, pmat)
			cloth_mats.append(pmat)
		elif armor_shader != null:
			var is_bespoke_helm := (
				kind == "armor"
				and slot_name == "helm"
				and orig_mat is StandardMaterial3D
				and (orig_mat as StandardMaterial3D).albedo_texture != null
			)
			var smat := _apply_armor_shader(mi, s, orig_mat, armor_shader, tier, not is_bespoke_helm)
			armor_mats.append(smat)


static func _get_discard_mat() -> ShaderMaterial:
	if _discard_mat == null:
		var sh := load(DISCARD_SHADER_PATH) as Shader
		_discard_mat = ShaderMaterial.new()
		if sh != null:
			_discard_mat.shader = sh
	return _discard_mat


static func _tier_cloth_palette(tier: int, class_id: String = "oathbreaker") -> Dictionary:
	var base_cls: Color = CLASS_CLOAK_COLORS.get(class_id, Color(0.11, 0.12, 0.16))
	var cape_base := base_cls
	var cape_trim := Color(0.32, 0.28, 0.23)
	var plume_col := Color(0.60, 0.57, 0.52)
	var trim_col := Color(0.52, 0.50, 0.46)
	var trim_metal := 0.80
	var trim_rough := 0.36
	match clampi(tier, 1, 4):
		2:
			cape_base = base_cls.lerp(Color(0.08, 0.10, 0.14), 0.65)
			cape_trim = Color(0.34, 0.38, 0.46)
			plume_col = Color(0.70, 0.68, 0.64)
			trim_col = Color(0.54, 0.58, 0.64)
			trim_metal = 0.90
			trim_rough = 0.24
		3:
			cape_base = base_cls.lerp(Color(0.22, 0.06, 0.08), 0.65)
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
	return {
		"cape_base": cape_base,
		"cape_trim": cape_trim,
		"plume_col": plume_col,
		"trim_col": trim_col,
		"trim_metal": trim_metal,
		"trim_rough": trim_rough,
	}


static func _make_cloak_shader_mat(
	cloak_shader: Shader,
	base_c: Color,
	trim_c: Color,
	sway_amp: float,
	billow_sign: float = 1.0
) -> ShaderMaterial:
	var cmat := ShaderMaterial.new()
	cmat.shader = cloak_shader
	cmat.set_shader_parameter("cloth_color", base_c)
	cmat.set_shader_parameter("hem_ash_color", base_c.darkened(0.55))
	cmat.set_shader_parameter("trim_color", trim_c)
	cmat.set_shader_parameter("sway_amplitude", sway_amp)
	cmat.set_shader_parameter("billow_sign", billow_sign)
	cmat.set_shader_parameter("hit_flash", 0.0)
	return cmat


static func _suppress_plague_builtin_staff(skel: Skeleton3D, suppress_staff: bool, suppress_censer: bool = false) -> void:
	for bname in ["b_Staff_017", "b_Whisp1_020", "b_Whisp2_018", "b_Whisp3_019", "b_Whisp4_021"]:
		var idx := skel.find_bone(bname)
		if idx >= 0:
			skel.set_bone_pose_scale(idx, Vector3.ONE * (0.0001 if suppress_staff else 1.0))
	for bname in ["b_Accesoire_026", "b_Whisp005_027", "b_Smoke2.1_028", "b_Smoke1.1_029", "b_Smoke1.2_030", "b_Whisp006_031", "b_Smoke2.2_032", "b_Whisp007_033", "b_Bell_036"]:
		var idx := skel.find_bone(bname)
		if idx >= 0:
			skel.set_bone_pose_scale(idx, Vector3.ONE * (0.0001 if suppress_censer else 1.0))


static func _extract_sockets(ap: AnimationPlayer) -> Dictionary:
	if ap == null or not ap.has_animation_library(&""):
		return {}
	var lib := ap.get_animation_library(&"")
	if lib != null and lib.has_meta("sockets"):
		return lib.get_meta("sockets") as Dictionary
	return {}


static func _channel_vec(ch: BaseMaterial3D.TextureChannel) -> Vector4:
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


static func _apply_armor_forge_shader(model_root: Node3D, tier: int) -> Array[ShaderMaterial]:
	var shader := load(ARMOR_SHADER_PATH) as Shader
	var out: Array[ShaderMaterial] = []
	if shader == null:
		return out

	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not ActorVisual._is_visible_in_hierarchy(mi, model_root) or mi.mesh == null:
			continue

		if not mi.has_meta("_orig_std_mats"):
			var cached := []
			for s in mi.mesh.get_surface_count():
				cached.append(mi.get_active_material(s))
			mi.set_meta("_orig_std_mats", cached)

		var orig_list: Array = mi.get_meta("_orig_std_mats")
		for s in mi.mesh.get_surface_count():
			var orig_mat: Material = orig_list[s] if s < orig_list.size() else null
			var mname_low := orig_mat.resource_name.to_lower() if orig_mat != null else ""
			var is_plate := not ("cloth" in mname_low or "cape" in mname_low or "tabard" in mname_low or "plume" in mname_low or "cloak" in mname_low)
			var smat := _apply_armor_shader(mi, s, orig_mat, shader, tier, is_plate)
			out.append(smat)
	return out


static func _make_bone_attachment(skel: Skeleton3D, attach_name: String, bone_name: String) -> BoneAttachment3D:
	var idx := skel.find_bone(bone_name)
	if idx < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "ForgedAttach_" + attach_name
	ba.bone_name = bone_name
	ba.bone_idx = idx
	skel.add_child(ba)
	return ba


static func _instantiate_weapon_visual(
	visual: ActorVisual,
	weapon_key: String,
	tier: int,
	lantern_color: Color,
	inv_skel_scale: float
) -> Dictionary:
	var tip_y_meters := 1.35
	var cast_y_meters := -1.0
	var grip_y_meters := 0.0
	var pitch_deg := 42.0
	var spin_y_deg := 90.0
	var kit_spin_y_deg := 0.0
	var is_staff := "staff" in weapon_key
	var node: Node3D = null

	if FORGED_WEAPONS.has(weapon_key):
		var spec: Dictionary = FORGED_WEAPONS[weapon_key]
		tip_y_meters = float(spec.get("tip_y", 1.35))
		cast_y_meters = float(spec.get("cast_y", -1.0))
		grip_y_meters = float(spec.get("grip_y", 0.0))
		pitch_deg = float(spec.get("pitch_deg", 42.0))
		spin_y_deg = float(spec.get("spin_y_deg", 90.0))
		kit_spin_y_deg = float(spec.get("kit_spin_y_deg", 0.0))
		is_staff = bool(spec.get("is_staff", is_staff))

		var chosen_path := str(spec.get("path", ""))
		if chosen_path == "" or not ResourceLoader.exists(chosen_path):
			var fb := str(spec.get("fallback_path", ""))
			if fb != "" and ResourceLoader.exists(fb):
				chosen_path = fb
			else:
				chosen_path = ""

		if chosen_path != "":
			var ps := load(chosen_path) as PackedScene
			if ps != null:
				var inst := ps.instantiate() as Node3D
				inst.scale = Vector3.ONE * inv_skel_scale
				node = inst
				if is_staff:
					_tint_staff_crystal(inst, lantern_color)
				elif bool(spec.get("cursed_ember", false)) or tier >= 3:
					_style_weapon_tier(inst, tier, bool(spec.get("cursed_ember", false)))
		elif bool(spec.get("fallback_legacy_sword", false)):
			var sword_mesh := _get_bastardsword_mesh(visual.model_instance)
			if sword_mesh != null:
				var mi := MeshInstance3D.new()
				mi.name = "BastardSwordClone"
				mi.mesh = sword_mesh
				mi.scale = Vector3.ONE * (0.01 * inv_skel_scale)
				node = mi
	elif ResourceLoader.exists("res://assets/models/gear/blade_oarimaar.res"):
		var relic_mesh := load("res://assets/models/gear/blade_oarimaar.res") as Mesh
		if relic_mesh != null:
			var rmi := MeshInstance3D.new()
			rmi.name = "RelicBlade"
			rmi.mesh = relic_mesh
			rmi.scale = Vector3.ONE * (0.01 * inv_skel_scale)
			node = rmi
			tip_y_meters = 1.14
			pitch_deg = 38.0
			spin_y_deg = 0.0
			kit_spin_y_deg = 0.0

	if cast_y_meters < 0.0:
		cast_y_meters = maxf(0.25, tip_y_meters - 0.18)

	return {
		"node": node,
		"tip_y": tip_y_meters,
		"cast_y": cast_y_meters,
		"grip_y": grip_y_meters,
		"pitch_deg": pitch_deg,
		"spin_y_deg": spin_y_deg,
		"kit_spin_y_deg": kit_spin_y_deg,
		"is_staff": is_staff,
	}


static func _style_weapon_tier(weapon_inst: Node3D, tier: int, cursed_ember: bool) -> void:
	for n in weapon_inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if not (mat is StandardMaterial3D):
				continue
			var src := mat as StandardMaterial3D
			var mname := src.resource_name.to_lower()
			if "grip" in mname or "leather" in mname or "wood" in mname:
				continue
			var dup := src.duplicate() as StandardMaterial3D
			if src.albedo_texture != null:
				if src.emission_texture != null:
					dup.emission_enabled = true
					dup.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					dup.emission = Color(1.0, 0.94, 0.88) if cursed_ember else Color.WHITE
					dup.emission_energy_multiplier = maxf(src.emission_energy_multiplier, 2.8 if cursed_ember else 2.2)
				elif tier == 3:
					dup.albedo_color = Color(1.04, 1.00, 0.92)
				elif tier >= 4 and cursed_ember:
					dup.albedo_color = Color(0.88, 0.86, 0.90)
				mi.set_surface_override_material(s, dup)
				continue
			if cursed_ember:
				dup.albedo_color = Color(0.20, 0.19, 0.23)
				dup.metallic = 0.96
				dup.roughness = 0.22
				dup.emission_enabled = true
				dup.emission = Color(0.88, 0.24, 0.05)
				dup.emission_energy_multiplier = 0.12
			elif tier == 3:
				dup.albedo_color = dup.albedo_color.lerp(Color(0.88, 0.72, 0.36), 0.22)
				dup.roughness = minf(dup.roughness, 0.24)
			elif tier >= 4:
				dup.albedo_color = dup.albedo_color.lerp(Color(0.32, 0.30, 0.35), 0.45)
				dup.emission_enabled = true
				dup.emission = Color(0.86, 0.28, 0.08)
				dup.emission_energy_multiplier = 0.20
			mi.set_surface_override_material(s, dup)


static func _mount_weapon(
	visual: ActorVisual,
	skel: Skeleton3D,
	bones: Dictionary,
	sockets: Dictionary,
	weapon_key: String,
	tier: int,
	lantern_color: Color,
	inv_skel_scale: float
) -> void:
	# Plague Doctor rig has mirrored L/R bone names; b_Hand_Left_00 (+X) is the visible staff-holding hand (parent of native b_Staff_017).
	var use_plague_staff_hand := visual.hero_class_id == "battlemage" and skel.find_bone("b_Hand_Left_00") >= 0
	var sock_key := "hand_l" if use_plague_staff_hand else "hand_r"
	var sock: Dictionary = sockets.get(sock_key, {})
	var bone_name: String = str(sock.get("bone", bones.get(sock_key, "")))
	var ba := _make_bone_attachment(skel, "WeaponR", bone_name)
	if ba == null:
		return

	var socket_pivot := Node3D.new()
	socket_pivot.name = "HandSocketR"
	if sock.has("xf"):
		socket_pivot.transform = sock["xf"] as Transform3D
	ba.add_child(socket_pivot)

	var weapon_holder := Node3D.new()
	weapon_holder.name = "WeaponHolder"
	socket_pivot.add_child(weapon_holder)

	var built := _instantiate_weapon_visual(visual, weapon_key, tier, lantern_color, inv_skel_scale)
	var inst := built["node"] as Node3D
	if inst == null:
		return
	weapon_holder.add_child(inst)

	var tip_y_meters := float(built["tip_y"])
	var cast_y_meters := float(built["cast_y"])
	var pitch_deg := float(built["pitch_deg"])
	var spin_y_deg := float(built["spin_y_deg"])
	var is_staff := bool(built["is_staff"])

	var pitch_basis := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(pitch_deg))
	var spin_basis := Basis(Vector3(0.0, 1.0, 0.0), deg_to_rad(spin_y_deg))
	var holder_basis := pitch_basis * spin_basis
	if use_plague_staff_hand:
		# In b_Hand_Left_00 socket space: +X is world +Y (up), +Y is world forward (-Z), -Z is world right (+X).
		var staff_up := Vector3(0.95, 0.14, -0.26).normalized() if is_staff else Vector3(0.45, 0.86, -0.22).normalized()
		var ref_fwd := Vector3(0.0, 1.0, 0.0)
		var staff_right := staff_up.cross(ref_fwd).normalized()
		var staff_fwd := staff_right.cross(staff_up).normalized()
		holder_basis = Basis(staff_right, staff_up, staff_fwd)
		weapon_holder.position = Vector3(-0.02, 0.06, -0.07) * inv_skel_scale
	weapon_holder.basis = holder_basis
	weapon_holder.set_meta("_base_basis", weapon_holder.basis)

	var tip := Marker3D.new()
	tip.name = "BladeTip"
	tip.position = Vector3(0.0, tip_y_meters * inv_skel_scale, 0.0)
	weapon_holder.add_child(tip)

	visual.main_weapon_node = weapon_holder
	visual.blade_tip_marker = tip
	if is_staff:
		var cast_m := Marker3D.new()
		cast_m.name = "CastOrigin"
		cast_m.position = Vector3(0.0, cast_y_meters * inv_skel_scale, 0.0)
		weapon_holder.add_child(cast_m)
		visual.cast_origin_marker = cast_m


static func _tint_staff_crystal(staff_inst: Node3D, col: Color) -> void:
	for n in staff_inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if not (mat is StandardMaterial3D):
				continue
			var src := mat as StandardMaterial3D
			if src.emission_texture != null:
				var dup := src.duplicate() as StandardMaterial3D
				dup.emission_enabled = true
				dup.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				dup.emission = col
				dup.emission_energy_multiplier = maxf(src.emission_energy_multiplier, 3.0)
				mi.set_surface_override_material(s, dup)
			elif src.resource_name == "CoreCrystal":
				var dup := src.duplicate() as StandardMaterial3D
				dup.albedo_color = col.lightened(0.25)
				dup.emission_enabled = true
				dup.emission = col
				dup.emission_energy_multiplier = 3.6
				mi.set_surface_override_material(s, dup)


static func _get_bastardsword_mesh(model_root: Node3D) -> Mesh:
	if model_root != null and model_root.has_meta("_cached_bastardsword_mesh"):
		return model_root.get_meta("_cached_bastardsword_mesh") as Mesh
	var found: Mesh = null
	if ResourceLoader.exists("res://assets/models/heroes/paladin/paladin.glb"):
		var pal_ps := load("res://assets/models/heroes/paladin/paladin.glb") as PackedScene
		if pal_ps != null:
			var tmp := pal_ps.instantiate()
			for n in tmp.find_children("bastardsword_weapons_0", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi.mesh != null:
					found = mi.mesh
					break
			tmp.free()
	if found != null and model_root != null:
		model_root.set_meta("_cached_bastardsword_mesh", found)
	return found


static func _instantiate_shield_visual(
	offhand_key: String,
	tier: int,
	inv_skel_scale: float,
	armor_mats: Array[ShaderMaterial]
) -> Node3D:
	if not MODULAR_SHIELDS.has(offhand_key):
		return null
	var spec: Dictionary = MODULAR_SHIELDS[offhand_key]
	var scale_mult := float(spec.get("scale", 1.0))
	var glb_path := str(spec.get("path", ""))
	var shield_node: Node3D = null

	var is_sculpted_glb := false
	if glb_path != "" and ResourceLoader.exists(glb_path):
		var ps := load(glb_path) as PackedScene
		if ps != null:
			shield_node = ps.instantiate() as Node3D
			shield_node.name = "ShieldGlb"
			shield_node.scale = Vector3.ONE * (scale_mult * inv_skel_scale)
			is_sculpted_glb = true
	else:
		var res_path := str(spec.get("fallback_res", GEAR_SHIELD_PATHS.get(offhand_key, "")))
		if res_path != "" and ResourceLoader.exists(res_path):
			var shield_mesh := load(res_path) as Mesh
			if shield_mesh != null:
				var mi := MeshInstance3D.new()
				mi.name = "ShieldMesh"
				mi.mesh = shield_mesh
				mi.scale = Vector3.ONE * (0.01 * inv_skel_scale)
				shield_node = mi

	if shield_node == null:
		return null

	var armor_shader := load(ARMOR_SHADER_PATH) as Shader
	if armor_shader != null:
		var meshes: Array[MeshInstance3D] = []
		if shield_node is MeshInstance3D:
			meshes.append(shield_node as MeshInstance3D)
		for n in shield_node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(n as MeshInstance3D)
		var shield_tint := Color.WHITE
		match clampi(tier, 1, 4):
			2:
				shield_tint = Color(0.88, 0.91, 0.97)
			3:
				shield_tint = Color(1.03, 0.98, 0.89)
			4:
				shield_tint = Color(0.76, 0.74, 0.80)
		for mi in meshes:
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				# Keep sculpted shield hammered steel and rear leather straps authentic across Tiers 1-4 while retaining tier rim and hit flash.
				var smat := _apply_armor_shader(mi, s, mi.get_active_material(s), armor_shader, tier, not is_sculpted_glb)
				if is_sculpted_glb:
					smat.set_shader_parameter("albedo_color", shield_tint)
				armor_mats.append(smat)
	return shield_node


static func _mount_offhand(
	visual: ActorVisual,
	skel: Skeleton3D,
	bones: Dictionary,
	sockets: Dictionary,
	offhand_key: String,
	tier: int,
	inv_skel_scale: float
) -> Array[ShaderMaterial]:
	var armor_mats: Array[ShaderMaterial] = []
	var shield_node := _instantiate_shield_visual(offhand_key, tier, inv_skel_scale, armor_mats)
	if shield_node == null:
		return armor_mats

	var use_plague_offhand := visual != null and visual.hero_class_id == "battlemage" and skel.find_bone("b_Hand_Right_025") >= 0
	var off_sock_key := "hand_r" if use_plague_offhand else "hand_l"
	var sock: Dictionary = sockets.get(off_sock_key, {})
	var bone_name: String = str(sock.get("bone", bones.get(off_sock_key, "")))
	var ba := _make_bone_attachment(skel, "OffhandL", bone_name)
	if ba == null:
		shield_node.free()
		return armor_mats

	var socket_pivot := Node3D.new()
	socket_pivot.name = "HandSocketL"
	if sock.has("xf"):
		socket_pivot.transform = sock["xf"] as Transform3D
	ba.add_child(socket_pivot)

	var shield_holder := Node3D.new()
	shield_holder.name = "ShieldHolder"
	var shield_up := Vector3(1.0, 0.12, 0.0).normalized()
	var shield_front := Vector3(0.0, 0.50, 0.86).normalized()
	var shield_right := shield_up.cross(shield_front).normalized()
	shield_front = shield_right.cross(shield_up).normalized()
	shield_holder.basis = Basis(shield_right, shield_up, shield_front)
	if visual != null and visual.hero_class_id == "battlemage":
		shield_holder.position = Vector3(0.22, 0.14, 0.18) * inv_skel_scale
	else:
		shield_holder.position = Vector3(0.04, 0.02, 0.09) * inv_skel_scale
	socket_pivot.add_child(shield_holder)
	shield_holder.add_child(shield_node)
	return armor_mats


static func _mount_cloak(
	skel: Skeleton3D,
	class_id: String,
	bones: Dictionary,
	tier: int,
	inv_skel_scale: float
) -> ShaderMaterial:
	var chest_name: String = str(bones.get("chest", ""))
	var chest_idx := skel.find_bone(chest_name)
	if chest_idx < 0:
		return null
	if not ResourceLoader.exists(CLOAK_TATTERED_PATH):
		return null
	var cloak_ps := load(CLOAK_TATTERED_PATH) as PackedScene
	var cloak_shader := load(CLOAK_SHADER_PATH) as Shader
	if cloak_ps == null or cloak_shader == null:
		return null

	var ba := _make_bone_attachment(skel, "Cloak", chest_name)
	var chest_pose := skel.get_bone_global_pose(chest_idx)
	var neck_idx := skel.find_bone(str(bones.get("neck", "")))
	var shoulder_y := chest_pose.origin.y + 0.16 * inv_skel_scale
	if neck_idx >= 0:
		shoulder_y = skel.get_bone_global_pose(neck_idx).origin.y - 0.02 * inv_skel_scale

	var back_offset := -0.25
	var tilt_x_deg := 8.0
	if class_id == "revenant":
		back_offset = -0.18
		tilt_x_deg = 6.0
	elif class_id == "battlemage":
		back_offset = -0.35
		tilt_x_deg = 12.0
	var desired_rig_xf := Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(tilt_x_deg), PI, 0.0)),
		Vector3(chest_pose.origin.x, shoulder_y, chest_pose.origin.z + back_offset * inv_skel_scale)
	)

	var mount := Node3D.new()
	mount.name = "CloakMount"
	mount.transform = chest_pose.affine_inverse() * desired_rig_xf
	ba.add_child(mount)

	var inst := cloak_ps.instantiate() as Node3D
	inst.scale = Vector3.ONE * inv_skel_scale
	mount.add_child(inst)

	var pal := _tier_cloth_palette(tier, class_id)
	var smat := _make_cloak_shader_mat(cloak_shader, pal["cape_base"], pal["cape_trim"], 0.09)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, smat)
	return smat


static func _mount_plume(
	skel: Skeleton3D,
	class_id: String,
	bones: Dictionary,
	tier: int,
	inv_skel_scale: float
) -> ShaderMaterial:
	var head_name: String = str(bones.get("head", ""))
	var head_idx := skel.find_bone(head_name)
	if head_idx < 0:
		return null
	if not ResourceLoader.exists(HELM_PLUME_PATH):
		return null
	var plume_ps := load(HELM_PLUME_PATH) as PackedScene
	var cloak_shader := load(CLOAK_SHADER_PATH) as Shader
	if plume_ps == null or cloak_shader == null:
		return null

	var ba := _make_bone_attachment(skel, "HelmPlume", head_name)
	var head_pose := skel.get_bone_global_pose(head_idx)
	var crown_pos := head_pose.origin + Vector3(0.0, 0.19 * inv_skel_scale, -0.02 * inv_skel_scale)
	var crown_name: String = str(bones.get("crown", ""))
	if crown_name != "":
		var crown_idx := skel.find_bone(crown_name)
		if crown_idx >= 0:
			crown_pos = skel.get_bone_global_pose(crown_idx).origin + Vector3(0.0, 0.01 * inv_skel_scale, -0.02 * inv_skel_scale)
	elif class_id == "battlemage":
		crown_pos = head_pose.origin + Vector3(0.0, 0.21 * inv_skel_scale, -0.03 * inv_skel_scale)

	var desired_rig_xf := Transform3D(Basis.from_euler(Vector3(0.0, PI, 0.0)), crown_pos)
	var mount := Node3D.new()
	mount.name = "PlumeMount"
	mount.transform = head_pose.affine_inverse() * desired_rig_xf
	ba.add_child(mount)

	var inst := plume_ps.instantiate() as Node3D
	inst.scale = Vector3.ONE * inv_skel_scale
	mount.add_child(inst)

	var pal := _tier_cloth_palette(tier, class_id)
	var pcol: Color = pal["plume_col"]
	var smat := _make_cloak_shader_mat(cloak_shader, pcol, pcol.darkened(0.32), 0.055)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat != null and mat.resource_name == "CrimsonAshenPlume":
				mi.set_surface_override_material(s, smat)
	return smat


static func _mount_waist_lantern(
	skel: Skeleton3D,
	class_id: String,
	bones: Dictionary,
	lantern_color: Color,
	lantern_tier: int,
	inv_skel_scale: float
) -> void:
	var hips_name: String = str(bones.get("hips", ""))
	var hips_idx := skel.find_bone(hips_name)
	if hips_idx < 0:
		return
	if not ResourceLoader.exists(WAIST_LANTERN_PATH):
		return
	var lantern_ps := load(WAIST_LANTERN_PATH) as PackedScene
	if lantern_ps == null:
		return

	var ba := _make_bone_attachment(skel, "WaistLantern", hips_name)
	var hips_pose := skel.get_bone_global_pose(hips_idx)
	var hip_x := 0.25 if class_id != "battlemage" else 0.21
	var hip_z := 0.14 if class_id != "battlemage" else 0.16
	var lantern_pos := hips_pose.origin + Vector3(hip_x, -0.02, hip_z) * inv_skel_scale
	var cant_basis := Basis.from_euler(Vector3(deg_to_rad(-4.0), 0.0, deg_to_rad(8.0)))
	var desired_rig_xf := Transform3D(cant_basis, lantern_pos)

	var mount := Node3D.new()
	mount.name = "LanternMount"
	mount.transform = hips_pose.affine_inverse() * desired_rig_xf
	ba.add_child(mount)

	var inst := lantern_ps.instantiate() as Node3D
	inst.scale = Vector3.ONE * inv_skel_scale
	mount.add_child(inst)

	var emit_energy := 3.8 + 0.45 * float(clampi(lantern_tier, 1, 4) - 1)
	_tint_lantern_core(inst, lantern_color, emit_energy)

	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = lantern_color
	light.omni_range = 4.5 + 0.35 * float(clampi(lantern_tier, 1, 4) - 1)
	light.light_energy = 1.6 + 0.18 * float(clampi(lantern_tier, 1, 4) - 1)
	light.shadow_enabled = false
	light.position = Vector3(0.0, -0.15 * inv_skel_scale, 0.02 * inv_skel_scale)
	mount.add_child(light)


static func _tint_lantern_core(root_node: Node3D, lantern_color: Color, energy: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for n in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n as MeshInstance3D)
	for mi in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_texture != null:
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.emission_enabled = true
				dup.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				dup.emission = lantern_color
				dup.emission_energy_multiplier = energy
				mi.set_surface_override_material(s, dup)
			elif mat != null and mat.resource_name == "LanternCore":
				var core_mat := StandardMaterial3D.new()
				core_mat.albedo_color = lantern_color.lightened(0.35)
				core_mat.roughness = 0.15
				core_mat.emission_enabled = true
				core_mat.emission = lantern_color
				core_mat.emission_energy_multiplier = energy
				mi.set_surface_override_material(s, core_mat)


static func _mount_fallback_cast_origin(
	visual: ActorVisual,
	skel: Skeleton3D,
	bones: Dictionary,
	sockets: Dictionary,
	inv_skel_scale: float
) -> void:
	if visual.cast_origin_marker != null:
		return
	var use_plague_offhand := visual != null and visual.hero_class_id == "battlemage" and skel.find_bone("b_Hand_Right_025") >= 0
	var off_sock_key := "hand_r" if use_plague_offhand else "hand_l"
	var sock: Dictionary = sockets.get(off_sock_key, {})
	var bone_name: String = str(sock.get("bone", bones.get(off_sock_key, "")))
	var ba := _make_bone_attachment(skel, "CastHandL", bone_name)
	if ba == null:
		return
	var m := Marker3D.new()
	m.name = "CastOrigin"
	if sock.has("xf"):
		m.position = (sock["xf"] as Transform3D).origin + Vector3(0.0, 0.08 * inv_skel_scale, 0.0)
	ba.add_child(m)
	visual.cast_origin_marker = m


static func _dress_unified_kit(
	visual: ActorVisual,
	skel: Skeleton3D,
	class_id: String,
	cuirass_tier: int,
	helm_tier: int,
	lantern_tier: int,
	weapon_key: String,
	offhand_key: String,
	has_plume: bool,
	lantern_color: Color,
	slot_overrides: Dictionary,
	inv_skel_scale: float
) -> void:
	var armor_shader := load(ARMOR_SHADER_PATH) as Shader
	var cloak_shader := load(CLOAK_SHADER_PATH) as Shader
	var armor_mats: Array[ShaderMaterial] = []
	var cloth_mats: Array[ShaderMaterial] = []
	var std_mats: Array[StandardMaterial3D] = []

	var body_pal := _tier_cloth_palette(cuirass_tier, class_id)
	var helm_pal := _tier_cloth_palette(helm_tier, class_id)
	var cape_base: Color = body_pal["cape_base"]
	var cape_trim: Color = body_pal["cape_trim"]
	var plume_col: Color = helm_pal["plume_col"]
	var trim_col: Color = body_pal["trim_col"]
	var trim_metal := float(body_pal["trim_metal"])
	var trim_rough := float(body_pal["trim_rough"])

	var has_builtin_cloak := false
	var has_builtin_lantern := false
	var has_slot_plume := false
	var mount_dynamic_weapon := weapon_key != "" and weapon_key != "none"

	for n in visual.model_instance.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue

		var nm := String(mi.name)
		var nm_low := nm.to_lower()
		if mount_dynamic_weapon and "weapon" in nm_low and not nm.begins_with("Slot_"):
			mi.visible = false
			continue

		if not mi.has_meta("_orig_std_mats"):
			var cached := []
			for s in mi.mesh.get_surface_count():
				cached.append(mi.get_active_material(s))
			mi.set_meta("_orig_std_mats", cached)

		var slot_key := _slot_name_for_mesh(mi)
		if slot_key == "plume":
			has_slot_plume = true
			mi.visible = has_plume
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if cloak_shader != null:
				var pmat := _make_cloak_shader_mat(cloak_shader, plume_col, plume_col.darkened(0.28), 0.035, -1.0)
				for s in mi.mesh.get_surface_count():
					mi.set_surface_override_material(s, pmat)
				cloth_mats.append(pmat)
			continue
		if slot_key == "cloak":
			has_builtin_cloak = true
			mi.visible = true
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if cloak_shader != null:
				var cmat := _make_cloak_shader_mat(cloak_shader, cape_base, cape_trim, 0.085, -1.0)
				for s in mi.mesh.get_surface_count():
					mi.set_surface_override_material(s, cmat)
				cloth_mats.append(cmat)
			continue
		if slot_key in ["helm", "pauldrons", "cuirass", "gauntlets", "greaves"]:
			mi.visible = true
			var slot_tier := helm_tier if slot_key == "helm" else cuirass_tier
			var orig_list_slot: Array = mi.get_meta("_orig_std_mats")
			for s in mi.mesh.get_surface_count():
				var orig_mat: Material = orig_list_slot[s] if s < orig_list_slot.size() else null
				var mname_low := orig_mat.resource_name.to_lower() if orig_mat != null else ""
				if "neckcap" in mname_low or "undersuit" in mname_low:
					if orig_mat is StandardMaterial3D:
						var dup_u := (orig_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
						mi.set_surface_override_material(s, dup_u)
						std_mats.append(dup_u)
				elif armor_shader != null:
					var smat := _apply_armor_shader(mi, s, orig_mat, armor_shader, slot_tier, true)
					armor_mats.append(smat)
			continue

		if not ActorVisual._is_visible_in_hierarchy(mi, visual.model_instance):
			continue

		var orig_list: Array = mi.get_meta("_orig_std_mats")
		for s in mi.mesh.get_surface_count():
			var orig_mat: Material = orig_list[s] if s < orig_list.size() else null
			var mname := orig_mat.resource_name if orig_mat != null else ""

			if mname in ["WeaponSteel", "WeaponGuard", "WeaponGrip"]:
				if mount_dynamic_weapon:
					mi.set_surface_override_material(s, _get_discard_mat())
				else:
					var wmat: StandardMaterial3D = (orig_mat as StandardMaterial3D).duplicate() as StandardMaterial3D if orig_mat is StandardMaterial3D else StandardMaterial3D.new()
					mi.set_surface_override_material(s, wmat)
					std_mats.append(wmat)
			elif mname == "ArmorPlate" and armor_shader != null:
				var smat := _apply_armor_shader(mi, s, orig_mat, armor_shader, cuirass_tier, true)
				armor_mats.append(smat)
			elif mname == "CapeCloth" and cloak_shader != null:
				has_builtin_cloak = true
				var cmat := _make_cloak_shader_mat(cloak_shader, cape_base, cape_trim, 0.085)
				mi.set_surface_override_material(s, cmat)
				cloth_mats.append(cmat)
			elif mname == "TabardCloth" and cloak_shader != null:
				var t_cmat := _make_cloak_shader_mat(cloak_shader, cape_base, cape_trim, 0.0)
				mi.set_surface_override_material(s, t_cmat)
				cloth_mats.append(t_cmat)
			elif mname == "HelmPlume":
				has_slot_plume = true
				if not has_plume:
					mi.set_surface_override_material(s, _get_discard_mat())
				elif cloak_shader != null:
					var hpmat := _make_cloak_shader_mat(cloak_shader, plume_col, plume_col.darkened(0.28), 0.0)
					mi.set_surface_override_material(s, hpmat)
					cloth_mats.append(hpmat)
			elif mname == "LanternCore":
				has_builtin_lantern = true
				var lmat := StandardMaterial3D.new()
				lmat.albedo_color = lantern_color.lightened(0.35)
				lmat.roughness = 0.16
				lmat.emission_enabled = true
				lmat.emission = lantern_color
				lmat.emission_energy_multiplier = 3.2 + 0.45 * float(lantern_tier - 1)
				mi.set_surface_override_material(s, lmat)
			elif mname == "ArmorTrim":
				var tmat := StandardMaterial3D.new()
				tmat.albedo_color = trim_col
				tmat.metallic = trim_metal
				tmat.roughness = trim_rough
				if cuirass_tier == 4:
					tmat.emission_enabled = true
					tmat.emission = Color(0.85, 0.32, 0.08)
					tmat.emission_energy_multiplier = 0.16
				mi.set_surface_override_material(s, tmat)
				std_mats.append(tmat)
			elif orig_mat is StandardMaterial3D:
				if armor_shader != null and not ("eye" in mname.to_lower() or "emit" in mname.to_lower()):
					var fallback_smat := _apply_armor_shader(mi, s, orig_mat, armor_shader, cuirass_tier, true)
					armor_mats.append(fallback_smat)
				else:
					var dup := (orig_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					mi.set_surface_override_material(s, dup)
					if not dup.emission_enabled:
						std_mats.append(dup)

	visual.register_shader_materials(armor_mats, cloth_mats, std_mats)

	var replaced_helm := false
	var helm_key := str(slot_overrides.get("helm_key", ""))
	if helm_key != "":
		var helm_path := str(MODULAR_HELMS.get(helm_key, helm_key if helm_key.begins_with("res://") else ""))
		if helm_path != "" and ResourceLoader.exists(helm_path):
			replaced_helm = equip_modular_slot(visual, "helm", helm_path, helm_tier)

	for slot_name in ["cuirass", "pauldrons", "gauntlets", "greaves", "cloak"]:
		var ov_key := str(MODULAR_SLOTS[slot_name]["override_key"])
		var ov_val := str(slot_overrides.get(ov_key, ""))
		if ov_val != "" and ov_val.begins_with("res://") and ResourceLoader.exists(ov_val):
			if equip_modular_slot(visual, slot_name, ov_val, cuirass_tier) and slot_name == "cloak":
				has_builtin_cloak = true

	if replaced_helm or helm_key != "":
		for pmi in _find_slot_meshes(visual.model_instance, "Slot_Plume"):
			pmi.visible = false
	elif has_plume and not has_slot_plume:
		var pmat_fb := _mount_unified_plume(skel, class_id, helm_tier, inv_skel_scale)
		if pmat_fb != null:
			visual.append_shader_materials([], [pmat_fb])

	if not has_builtin_cloak:
		var fallback_cloak_mat := _mount_unified_cloak(skel, class_id, cuirass_tier, inv_skel_scale)
		if fallback_cloak_mat != null:
			visual.append_shader_materials([], [fallback_cloak_mat])

	if mount_dynamic_weapon:
		mount_kit_weapon(
			visual,
			skel,
			weapon_key,
			cuirass_tier,
			lantern_color,
			inv_skel_scale,
			clampf(visual.height_meters / 1.95, 0.72, 2.20)
		)

	if offhand_key != "" and offhand_key != "none":
		var sh_mats := _mount_unified_offhand(skel, offhand_key, cuirass_tier, inv_skel_scale)
		if not sh_mats.is_empty():
			visual.append_shader_materials(sh_mats)

	if visual.cast_origin_marker == null:
		var hand_l_idx := skel.find_bone("hand_l")
		if hand_l_idx >= 0:
			var ba_l := _make_bone_attachment(skel, "KitCastHandL", "hand_l")
			if ba_l != null:
				var cast_m := Marker3D.new()
				cast_m.name = "CastOrigin"
				cast_m.position = Vector3(0.0, 0.08 * inv_skel_scale, 0.0)
				ba_l.add_child(cast_m)
				visual.cast_origin_marker = cast_m

	_mount_unified_lantern(skel, has_builtin_lantern, lantern_color, lantern_tier, inv_skel_scale)


static func mount_kit_weapon(
	visual: ActorVisual,
	skel: Skeleton3D,
	weapon_key: String,
	tier: int = 1,
	lantern_color: Color = Color(1.0, 0.74, 0.30, 1.0),
	inv_skel_scale: float = 1.0,
	weapon_scale_mult: float = 1.0
) -> void:
	if visual == null or skel == null or weapon_key == "" or weapon_key == "none":
		return
	var weapon_idx := skel.find_bone("weapon_r")
	if weapon_idx < 0:
		return
	var old_w := skel.get_node_or_null("ForgedAttach_KitWeaponR")
	if old_w != null:
		skel.remove_child(old_w)
		old_w.free()
	var ba_w := _make_bone_attachment(skel, "KitWeaponR", "weapon_r")
	if ba_w == null:
		return

	var holder := Node3D.new()
	holder.name = "WeaponHolder"
	ba_w.add_child(holder)

	var eff_scale := inv_skel_scale * maxf(weapon_scale_mult, 0.25)
	var built := _instantiate_weapon_visual(visual, weapon_key, tier, lantern_color, eff_scale)
	var inst := built["node"] as Node3D
	var tip_y := float(built["tip_y"])
	var cast_y := float(built["cast_y"])
	var grip_y := float(built["grip_y"])
	var spin_y_deg := float(built["kit_spin_y_deg"])
	var is_staff := bool(built["is_staff"])

	# weapon_r bone +Y points along blade axis, +Z up, -X along horizontal attack_1 cleave direction; blade edges sit on +-X.
	var holder_basis := Basis(Vector3.UP, deg_to_rad(spin_y_deg))
	if is_staff and visual.is_hero:
		# Greatsword-style hero rigs aim weapon_r downward in idle; pitch war-staff upright toward bone +Z so the glowing censer rides high.
		var w_pose := skel.get_bone_global_pose(weapon_idx)
		if w_pose.basis.y.y < 0.0:
			holder_basis = Basis(Vector3.RIGHT, deg_to_rad(82.0)) * holder_basis
	holder.basis = holder_basis
	holder.position = Vector3(0.0, grip_y * eff_scale, 0.0)
	holder.set_meta("_base_basis", holder.basis)
	if inst != null:
		holder.add_child(inst)

	var tip_m := Marker3D.new()
	tip_m.name = "BladeTip"
	tip_m.position = Vector3(0.0, tip_y * eff_scale, 0.0)
	holder.add_child(tip_m)

	visual.main_weapon_node = holder
	visual.blade_tip_marker = tip_m
	if is_staff:
		var cast_m := Marker3D.new()
		cast_m.name = "CastOrigin"
		cast_m.position = Vector3(0.0, cast_y * eff_scale, 0.0)
		holder.add_child(cast_m)
		visual.cast_origin_marker = cast_m


static func _mount_unified_weapon(
	visual: ActorVisual,
	skel: Skeleton3D,
	weapon_key: String,
	tier: int,
	lantern_color: Color,
	inv_skel_scale: float
) -> void:
	mount_kit_weapon(
		visual,
		skel,
		weapon_key,
		tier,
		lantern_color,
		inv_skel_scale,
		clampf(visual.height_meters / 1.95, 0.72, 2.20)
	)


static func _mount_unified_offhand(
	skel: Skeleton3D,
	offhand_key: String,
	tier: int,
	inv_skel_scale: float
) -> Array[ShaderMaterial]:
	var armor_mats: Array[ShaderMaterial] = []
	var shield_node := _instantiate_shield_visual(offhand_key, tier, inv_skel_scale, armor_mats)
	if shield_node == null:
		return armor_mats

	var bone_name := "offhand_l" if skel.find_bone("offhand_l") >= 0 else "hand_l"
	var ba := _make_bone_attachment(skel, "KitOffhandL", bone_name)
	if ba == null:
		shield_node.free()
		return armor_mats

	var shield_holder := Node3D.new()
	shield_holder.name = "ShieldHolder"
	# In offhand_l bone space: -X points outward-left, +Y forward-up, +Z up-back; align shield +Z outward-forward and +Y vertical below wolf fur.
	var sh_up := Vector3(0.07, 0.23, 0.97).normalized()
	var sh_front := Vector3(-0.76, 0.64, -0.10).normalized()
	var sh_right := sh_up.cross(sh_front).normalized()
	sh_front = sh_right.cross(sh_up).normalized()
	shield_holder.basis = Basis(sh_right, sh_up, sh_front)
	shield_holder.position = Vector3(-0.04, -0.04, 0.04) * inv_skel_scale
	ba.add_child(shield_holder)
	shield_holder.add_child(shield_node)
	return armor_mats


static func _mount_unified_cloak(
	skel: Skeleton3D,
	class_id: String,
	tier: int,
	inv_skel_scale: float
) -> ShaderMaterial:
	var bone_name := "cape_0" if skel.find_bone("cape_0") >= 0 else "chest"
	var bone_idx := skel.find_bone(bone_name)
	if bone_idx < 0:
		return null
	if not ResourceLoader.exists(CLOAK_TATTERED_PATH):
		return null
	var cloak_ps := load(CLOAK_TATTERED_PATH) as PackedScene
	var cloak_shader := load(CLOAK_SHADER_PATH) as Shader
	if cloak_ps == null or cloak_shader == null:
		return null

	var ba := _make_bone_attachment(skel, "KitCloak", bone_name)
	var rest_xf := skel.get_bone_global_rest(bone_idx)
	var desired_rest := Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(6.0), PI, 0.0)),
		rest_xf.origin + Vector3(0.0, 0.02, -0.02) * inv_skel_scale
	)
	var mount := Node3D.new()
	mount.name = "CloakMount"
	mount.transform = rest_xf.affine_inverse() * desired_rest
	ba.add_child(mount)

	var inst := cloak_ps.instantiate() as Node3D
	inst.scale = Vector3.ONE * inv_skel_scale
	mount.add_child(inst)

	var pal := _tier_cloth_palette(tier, class_id)
	var smat := _make_cloak_shader_mat(cloak_shader, pal["cape_base"], pal["cape_trim"], 0.085)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, smat)
	return smat


static func _mount_unified_plume(
	skel: Skeleton3D,
	class_id: String,
	helm_tier: int,
	inv_skel_scale: float
) -> ShaderMaterial:
	var head_idx := skel.find_bone("head")
	if head_idx < 0 or not ResourceLoader.exists(HELM_PLUME_PATH):
		return null
	var plume_ps := load(HELM_PLUME_PATH) as PackedScene
	var cloak_shader := load(CLOAK_SHADER_PATH) as Shader
	if plume_ps == null or cloak_shader == null:
		return null

	var ba := _make_bone_attachment(skel, "KitHelmPlume", "head")
	var head_rest := skel.get_bone_global_rest(head_idx)
	var desired_rest := Transform3D(
		Basis.from_euler(Vector3(0.0, PI, 0.0)),
		head_rest.origin + Vector3(0.0, 0.22, -0.02) * inv_skel_scale
	)
	var mount := Node3D.new()
	mount.name = "PlumeMount"
	mount.transform = head_rest.affine_inverse() * desired_rest
	ba.add_child(mount)

	var inst := plume_ps.instantiate() as Node3D
	inst.scale = Vector3.ONE * inv_skel_scale
	mount.add_child(inst)

	var pal := _tier_cloth_palette(helm_tier, class_id)
	var pcol: Color = pal["plume_col"]
	var smat := _make_cloak_shader_mat(cloak_shader, pcol, pcol.darkened(0.30), 0.05)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat != null and mat.resource_name == "CrimsonAshenPlume":
				mi.set_surface_override_material(s, smat)
	return smat


static func _mount_unified_lantern(
	skel: Skeleton3D,
	has_builtin_lantern: bool,
	lantern_color: Color,
	lantern_tier: int,
	inv_skel_scale: float
) -> void:
	var lantern_idx := skel.find_bone("lantern_bone")
	if lantern_idx < 0:
		return
	var ba_lt := _make_bone_attachment(skel, "KitLantern", "lantern_bone")
	if ba_lt == null:
		return

	var rest_xf := skel.get_bone_global_rest(lantern_idx)
	var rest_inv := rest_xf.affine_inverse()
	var cant_basis := Basis.from_euler(Vector3(deg_to_rad(-3.0), 0.0, deg_to_rad(6.0)))
	var desired_rest := Transform3D(
		cant_basis,
		rest_xf.origin + Vector3(0.022, 0.012, 0.018) * inv_skel_scale
	)
	var mount := Node3D.new()
	mount.name = "LanternMount"
	mount.transform = rest_inv * desired_rest
	ba_lt.add_child(mount)

	var emit_energy := 3.8 + 0.45 * float(lantern_tier - 1)
	if not has_builtin_lantern and ResourceLoader.exists(WAIST_LANTERN_PATH):
		var lantern_ps := load(WAIST_LANTERN_PATH) as PackedScene
		if lantern_ps != null:
			var inst := lantern_ps.instantiate() as Node3D
			inst.scale = Vector3.ONE * inv_skel_scale
			mount.add_child(inst)
			_tint_lantern_core(inst, lantern_color, emit_energy)

	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = lantern_color
	light.omni_range = 4.6 + 0.35 * float(lantern_tier - 1)
	light.light_energy = 1.65 + 0.18 * float(lantern_tier - 1)
	light.shadow_enabled = false
	light.position = Vector3(0.0, -0.14 * inv_skel_scale, 0.02 * inv_skel_scale)
	mount.add_child(light)


static func _apply_armor_shader(
	mi: MeshInstance3D,
	surface_idx: int,
	orig_mat: Material,
	shader: Shader,
	tier: int,
	is_plate: bool = true
) -> ShaderMaterial:
	var smat := _make_armor_shader_mat(shader, orig_mat, tier, is_plate)
	mi.set_surface_override_material(surface_idx, smat)
	return smat


static func _make_armor_shader_mat(shader: Shader, orig_mat: Material, tier: int, is_plate: bool = true) -> ShaderMaterial:
	var smat := ShaderMaterial.new()
	smat.shader = shader
	smat.set_shader_parameter("armor_tier", tier)
	smat.set_shader_parameter("is_armor_plate", is_plate)
	smat.set_shader_parameter("hit_flash", 0.0)
	if _voronoi_tex == null and ResourceLoader.exists(ARMOR_VORONOI_TEX_PATH):
		_voronoi_tex = load(ARMOR_VORONOI_TEX_PATH) as Texture2D
	if _voronoi_tex != null:
		smat.set_shader_parameter("voronoi_tex", _voronoi_tex)
	if orig_mat is StandardMaterial3D:
		var std := orig_mat as StandardMaterial3D
		smat.set_shader_parameter("albedo_color", std.albedo_color)
		if std.albedo_texture != null:
			smat.set_shader_parameter("albedo_tex", std.albedo_texture)
		var use_nrm := std.normal_texture != null and std.normal_enabled
		smat.set_shader_parameter("has_normal_tex", use_nrm)
		if std.normal_texture != null:
			smat.set_shader_parameter("normal_tex", std.normal_texture)
			smat.set_shader_parameter("normal_scale", std.normal_scale)
		var is_orm := (
			std.roughness_texture != null
			and std.metallic_texture != null
			and std.roughness_texture == std.metallic_texture
			and std.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			and std.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		)
		smat.set_shader_parameter("has_orm_tex", is_orm)
		if is_orm:
			smat.set_shader_parameter("orm_tex", std.roughness_texture)
		smat.set_shader_parameter("has_rough_tex", std.roughness_texture != null)
		if std.roughness_texture != null:
			smat.set_shader_parameter("rough_tex", std.roughness_texture)
			smat.set_shader_parameter("rough_channel", _channel_vec(std.roughness_texture_channel))
		smat.set_shader_parameter("base_roughness", std.roughness)
		smat.set_shader_parameter("has_metal_tex", std.metallic_texture != null)
		if std.metallic_texture != null:
			smat.set_shader_parameter("metal_tex", std.metallic_texture)
			smat.set_shader_parameter("metal_channel", _channel_vec(std.metallic_texture_channel))
		smat.set_shader_parameter("base_metallic", std.metallic)
		var use_ao := std.ao_enabled and std.ao_texture != null
		smat.set_shader_parameter("has_ao_tex", use_ao)
		if use_ao:
			smat.set_shader_parameter("ao_tex", std.ao_texture)
			smat.set_shader_parameter("ao_channel", _channel_vec(std.ao_texture_channel))
		smat.set_shader_parameter("has_emission_tex", std.emission_enabled and std.emission_texture != null)
		if std.emission_texture != null:
			smat.set_shader_parameter("emission_tex", std.emission_texture)
	return smat
