class_name HeroRigDresser
extends RefCounted

const ARMOR_SHADER_PATH := "res://shaders/armor_forge.gdshader"
const CLOAK_SHADER_PATH := "res://shaders/cloak_sway.gdshader"

const FORGED_WEAPONS := {
	"zweihander": {"path": "res://assets/models/forged/zweihander.glb", "tip_y": 1.46, "pitch_deg": 42.0, "spin_y_deg": 90.0},
	"greatsword": {"path": "res://assets/models/forged/zweihander.glb", "tip_y": 1.46, "pitch_deg": 42.0, "spin_y_deg": 90.0},
	"halberd": {"path": "res://assets/models/forged/halberd.glb", "tip_y": 1.55, "pitch_deg": 66.0, "spin_y_deg": 90.0},
	"poleaxe": {"path": "res://assets/models/forged/halberd.glb", "tip_y": 1.55, "pitch_deg": 66.0, "spin_y_deg": 90.0},
	"runed_staff": {"path": "res://assets/models/forged/runed_staff.glb", "tip_y": 1.35, "pitch_deg": 72.0, "spin_y_deg": 0.0},
	"staff": {"path": "res://assets/models/forged/runed_staff.glb", "tip_y": 1.35, "pitch_deg": 72.0, "spin_y_deg": 0.0},
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
	"oathbreaker": Color(0.14, 0.11, 0.12),
	"battlemage": Color(0.10, 0.12, 0.15),
	"revenant": Color(0.11, 0.09, 0.12),
}


static func dress(
	visual: ActorVisual,
	class_id: String,
	armor_tier: int,
	weapon_key: String,
	offhand_key: String,
	has_plume: bool,
	lantern_color: Color
) -> void:
	if visual == null:
		return
	visual.ensure_initialized()
	if visual.skeleton == null or visual.model_instance == null:
		return

	var cid := class_id if CLASS_BONES.has(class_id) else "oathbreaker"
	var tier := clampi(armor_tier, 1, 4)
	visual.hero_class_id = cid
	visual.armor_tier = tier
	visual.weapon_key = weapon_key
	visual.offhand_key = offhand_key
	visual.has_plume = has_plume
	visual.lantern_color = lantern_color

	var skel := visual.skeleton
	_clear_previous_attachments(skel)
	visual.blade_tip_marker = null
	visual.cast_origin_marker = null
	visual.main_weapon_node = null

	if visual.anim_player != null and visual.anim_player.has_animation("idle"):
		visual.anim_player.play("idle")
		visual.anim_player.seek(0.0, true)
		visual.anim_player.advance(0.0)

	if cid == "battlemage":
		_suppress_plague_builtin_staff(
			skel,
			weapon_key != "" and weapon_key != "none",
			offhand_key != "" and offhand_key != "none"
		)

	var armor_mats := _apply_armor_forge_shader(visual.model_instance, tier)
	var cloth_mats: Array[ShaderMaterial] = []

	var skel_world_scale := maxf(skel.global_transform.basis.get_scale().y, 0.0001)
	var inv_skel_scale := 1.0 / skel_world_scale
	var bones: Dictionary = CLASS_BONES[cid]
	var sockets := _extract_sockets(visual.anim_player)

	if weapon_key != "" and weapon_key != "none":
		_mount_weapon(visual, skel, bones, sockets, weapon_key, lantern_color, inv_skel_scale)

	if offhand_key != "" and offhand_key != "none":
		_mount_offhand(visual, skel, bones, sockets, offhand_key, inv_skel_scale)

	var cloak_mat := _mount_cloak(skel, cid, bones, tier, inv_skel_scale)
	if cloak_mat != null:
		cloth_mats.append(cloak_mat)

	if has_plume:
		var plume_mat := _mount_plume(skel, cid, bones, tier, inv_skel_scale)
		if plume_mat != null:
			cloth_mats.append(plume_mat)

	_mount_waist_lantern(skel, cid, bones, lantern_color, inv_skel_scale)
	_mount_fallback_cast_origin(visual, skel, bones, sockets, inv_skel_scale)

	visual.register_shader_materials(armor_mats, cloth_mats)


static func _clear_previous_attachments(skel: Skeleton3D) -> void:
	var to_remove: Array[Node] = []
	for child in skel.get_children():
		if String(child.name).begins_with("ForgedAttach_"):
			to_remove.append(child)
	for n in to_remove:
		n.name = "_FreedAttach_" + str(n.get_instance_id())
		if n is Node3D:
			(n as Node3D).visible = false
		n.queue_free()


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
			var smat := ShaderMaterial.new()
			smat.shader = shader
			smat.set_shader_parameter("armor_tier", tier)
			smat.set_shader_parameter("hit_flash", 0.0)

			if orig_mat is StandardMaterial3D:
				var std := orig_mat as StandardMaterial3D
				smat.set_shader_parameter("albedo_color", std.albedo_color)
				if std.albedo_texture != null:
					smat.set_shader_parameter("albedo_tex", std.albedo_texture)
				smat.set_shader_parameter("has_normal", std.normal_enabled and std.normal_texture != null)
				if std.normal_texture != null:
					smat.set_shader_parameter("normal_tex", std.normal_texture)
					smat.set_shader_parameter("normal_scale", std.normal_scale)
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
				smat.set_shader_parameter("has_emission_tex", std.emission_enabled and std.emission_texture != null)
				if std.emission_texture != null:
					smat.set_shader_parameter("emission_tex", std.emission_texture)

			mi.set_surface_override_material(s, smat)
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


static func _mount_weapon(
	visual: ActorVisual,
	skel: Skeleton3D,
	bones: Dictionary,
	sockets: Dictionary,
	weapon_key: String,
	lantern_color: Color,
	inv_skel_scale: float
) -> void:
	var sock: Dictionary = sockets.get("hand_r", {})
	var bone_name: String = str(sock.get("bone", bones.get("hand_r", "")))
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

	var tip_y_meters := 1.35
	var pitch_deg := 42.0
	var spin_y_deg := 90.0

	if FORGED_WEAPONS.has(weapon_key):
		var spec: Dictionary = FORGED_WEAPONS[weapon_key]
		var ps := load(str(spec["path"])) as PackedScene
		if ps == null:
			return
		var inst := ps.instantiate() as Node3D
		inst.scale = Vector3.ONE * inv_skel_scale
		weapon_holder.add_child(inst)
		tip_y_meters = float(spec["tip_y"])
		pitch_deg = float(spec["pitch_deg"])
		spin_y_deg = float(spec["spin_y_deg"])
		if "staff" in weapon_key:
			_tint_staff_crystal(inst, lantern_color)
	elif weapon_key in ["bastardsword", "longsword", "sword"]:
		var sword_mesh := _get_bastardsword_mesh(visual.model_instance)
		if sword_mesh == null:
			return
		var mi := MeshInstance3D.new()
		mi.name = "BastardSwordClone"
		mi.mesh = sword_mesh
		mi.scale = Vector3.ONE * (0.01 * inv_skel_scale)
		weapon_holder.add_child(mi)
		tip_y_meters = 1.11
		pitch_deg = 38.0
		spin_y_deg = 90.0
	else:
		var relic_mesh := load("res://assets/models/gear/blade_oarimaar.res") as Mesh
		if relic_mesh == null:
			return
		var rmi := MeshInstance3D.new()
		rmi.name = "RelicBlade"
		rmi.mesh = relic_mesh
		rmi.scale = Vector3.ONE * (0.01 * inv_skel_scale)
		weapon_holder.add_child(rmi)
		tip_y_meters = 1.14
		pitch_deg = 38.0
		spin_y_deg = 0.0

	var pitch_basis := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(pitch_deg))
	var roll_deg := 14.0 if visual.hero_class_id == "battlemage" else 0.0
	var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(roll_deg))
	var spin_basis := Basis(Vector3(0.0, 1.0, 0.0), deg_to_rad(spin_y_deg))
	weapon_holder.basis = roll_basis * pitch_basis * spin_basis
	weapon_holder.set_meta("_base_basis", weapon_holder.basis)
	if visual.hero_class_id == "battlemage":
		weapon_holder.position = Vector3(0.0, 0.04, 0.08) * inv_skel_scale

	var tip := Marker3D.new()
	tip.name = "BladeTip"
	tip.position = Vector3(0.0, tip_y_meters * inv_skel_scale, 0.0)
	weapon_holder.add_child(tip)

	visual.main_weapon_node = weapon_holder
	visual.blade_tip_marker = tip
	if "staff" in weapon_key:
		var cast_m := Marker3D.new()
		cast_m.name = "CastOrigin"
		cast_m.position = Vector3(0.0, (tip_y_meters - 0.18) * inv_skel_scale, 0.0)
		weapon_holder.add_child(cast_m)
		visual.cast_origin_marker = cast_m


static func _tint_staff_crystal(staff_inst: Node3D, col: Color) -> void:
	for n in staff_inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat != null and mat.resource_name == "CoreCrystal" and mat is StandardMaterial3D:
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.albedo_color = col.lightened(0.25)
				dup.emission_enabled = true
				dup.emission = col
				dup.emission_energy_multiplier = 3.6
				mi.set_surface_override_material(s, dup)


static func _get_bastardsword_mesh(model_root: Node3D) -> Mesh:
	if model_root != null and model_root.has_meta("_cached_bastardsword_mesh"):
		return model_root.get_meta("_cached_bastardsword_mesh") as Mesh
	var found: Mesh = null
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


static func _mount_offhand(
	visual: ActorVisual,
	skel: Skeleton3D,
	bones: Dictionary,
	sockets: Dictionary,
	offhand_key: String,
	inv_skel_scale: float
) -> void:
	if not GEAR_SHIELD_PATHS.has(offhand_key):
		return
	var shield_mesh := load(str(GEAR_SHIELD_PATHS[offhand_key])) as Mesh
	if shield_mesh == null:
		return

	var sock: Dictionary = sockets.get("hand_l", {})
	var bone_name: String = str(sock.get("bone", bones.get("hand_l", "")))
	var ba := _make_bone_attachment(skel, "OffhandL", bone_name)
	if ba == null:
		return

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

	var mi := MeshInstance3D.new()
	mi.name = "ShieldMesh"
	mi.mesh = shield_mesh
	mi.scale = Vector3.ONE * (0.01 * inv_skel_scale)
	shield_holder.add_child(mi)


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
	var cloak_ps := load("res://assets/models/forged/cloak_tattered.glb") as PackedScene
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

	var smat := ShaderMaterial.new()
	smat.shader = cloak_shader
	var base_col: Color = CLASS_CLOAK_COLORS.get(class_id, Color(0.12, 0.11, 0.13))
	if tier == 3:
		base_col = base_col.lerp(Color(0.24, 0.08, 0.10), 0.55)
		smat.set_shader_parameter("trim_color", Color(0.82, 0.62, 0.20))
	elif tier == 4:
		base_col = Color(0.07, 0.065, 0.07)
		smat.set_shader_parameter("trim_color", Color(0.85, 0.30, 0.08))
	smat.set_shader_parameter("cloth_color", base_col)

	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
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
	var plume_ps := load("res://assets/models/forged/helm_plume.glb") as PackedScene
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

	var smat := ShaderMaterial.new()
	smat.shader = cloak_shader
	var pcol := Color(0.76, 0.73, 0.67) if tier < 4 else Color(0.42, 0.08, 0.07)
	smat.set_shader_parameter("cloth_color", pcol)
	smat.set_shader_parameter("hem_ash_color", pcol.darkened(0.52))
	smat.set_shader_parameter("trim_color", pcol.darkened(0.32))
	smat.set_shader_parameter("sway_amplitude", 0.055)

	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
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
	inv_skel_scale: float
) -> void:
	var hips_name: String = str(bones.get("hips", ""))
	var hips_idx := skel.find_bone(hips_name)
	if hips_idx < 0:
		return
	var lantern_ps := load("res://assets/models/forged/waist_lantern.glb") as PackedScene
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

	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat != null and mat.resource_name == "LanternCore":
				var core_mat := StandardMaterial3D.new()
				core_mat.albedo_color = lantern_color.lightened(0.35)
				core_mat.roughness = 0.15
				core_mat.emission_enabled = true
				core_mat.emission = lantern_color
				core_mat.emission_energy_multiplier = 4.2
				mi.set_surface_override_material(s, core_mat)

	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = lantern_color
	light.omni_range = 4.5
	light.light_energy = 1.6
	light.shadow_enabled = false
	light.position = Vector3(0.0, -0.15 * inv_skel_scale, 0.02 * inv_skel_scale)
	mount.add_child(light)


static func _mount_fallback_cast_origin(
	visual: ActorVisual,
	skel: Skeleton3D,
	bones: Dictionary,
	sockets: Dictionary,
	inv_skel_scale: float
) -> void:
	if visual.cast_origin_marker != null:
		return
	var sock: Dictionary = sockets.get("hand_l", {})
	var bone_name: String = str(sock.get("bone", bones.get("hand_l", "")))
	var ba := _make_bone_attachment(skel, "CastHandL", bone_name)
	if ba == null:
		return
	var m := Marker3D.new()
	m.name = "CastOrigin"
	if sock.has("xf"):
		m.position = (sock["xf"] as Transform3D).origin + Vector3(0.0, 0.08 * inv_skel_scale, 0.0)
	ba.add_child(m)
	visual.cast_origin_marker = m
