extends SceneTree

var _checks_passed: int = 0
var _checks_failed: int = 0
var _had_save_before: bool = false
var _prior_save_bytes: PackedByteArray = PackedByteArray()


func _init() -> void:
	_had_save_before = FileAccess.file_exists("user://ashen_oath_save.json")
	if _had_save_before:
		_prior_save_bytes = FileAccess.get_file_as_bytes("user://ashen_oath_save.json")


func _initialize() -> void:
	call_deferred("_run_suite")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_checks_failed += 1
		push_error("ASSERTION FAILED: %s" % msg)
		printerr("ASSERTION FAILED: %s" % msg)
		return
	_checks_passed += 1


func _restore_disk_state() -> void:
	if _had_save_before:
		var f := FileAccess.open("user://ashen_oath_save.json", FileAccess.WRITE)
		if f != null:
			f.store_buffer(_prior_save_bytes)
			f.close()
	elif FileAccess.file_exists("user://ashen_oath_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ashen_oath_save.json"))


func _run_suite() -> void:
	var gs_script: GDScript = load("res://scripts/core/game_state.gd")
	var gs: Node = gs_script.new()
	gs.name = "GameState"
	root.add_child(gs)
	gs.reset_to_fresh(false)

	_test_combat_stats_descriptors(gs)
	await _test_all_classes_weapon_and_offhand_swaps()
	await _test_modular_slots_and_independent_tiers()
	await _test_sculpted_modular_helms_on_oathbreaker()
	await _test_sculpted_waist_lantern_all_classes()

	root.remove_child(gs)
	gs.free()

	await process_frame
	await process_frame

	var orphans := roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(orphans == 0, "Zero orphan nodes at modular equipment suite teardown (got %d)" % orphans)

	_restore_disk_state()
	if _checks_failed > 0:
		printerr("FAILED %d assertions (%d passed)." % [_checks_failed, _checks_passed])
		quit(1)
		return
	print("Verified %d modular equipment assertions cleanly." % _checks_passed)
	print("ALL MODULAR EQUIPMENT TESTS PASSED")
	quit(0)


func _test_combat_stats_descriptors(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	var base_stats: CombatStats = gs.compute_stats("oathbreaker")
	_check(base_stats.armor_tier == 1 and base_stats.cuirass_tier == 1, "Starter cuirass_tier == 1")
	_check(base_stats.helm_tier == 1 and base_stats.helm_key == "", "Starter T1 helm uses base Slot_Helm (helm_key empty)")
	_check(base_stats.lantern_tier == 1, "Starter lantern_tier == 1")
	_check(base_stats.cuirass_key == "" and base_stats.pauldron_key == "" and base_stats.gauntlet_key == "" and base_stats.greaves_key == "" and base_stats.cloak_key == "", "Future modular slot keys default empty")

	var helm_t3 := LootEngine.forge_item(rng, GameEnums.Slot.HELM, 3)
	var cuirass_t2 := LootEngine.forge_item(rng, GameEnums.Slot.CUIRASS, 2)
	var lantern_t4 := LootEngine.forge_item(rng, GameEnums.Slot.LANTERN, 4)
	lantern_t4.lantern_aspect = GameEnums.LanternAspect.SOUL_BLUE

	gs.add_item_to_inventory(helm_t3)
	gs.add_item_to_inventory(cuirass_t2)
	gs.add_item_to_inventory(lantern_t4)
	_check(gs.equip_item("oathbreaker", helm_t3.uid), "Equipped T3 helm")
	_check(gs.equip_item("oathbreaker", cuirass_t2.uid), "Equipped T2 cuirass")
	_check(gs.equip_item("oathbreaker", lantern_t4.uid), "Equipped T4 lantern")

	var mixed_stats: CombatStats = gs.compute_stats("oathbreaker")
	_check(mixed_stats.helm_tier == 3 and mixed_stats.helm_key == "helm_t3", "T3 helm populates helm_tier=3 and helm_key=helm_t3")
	_check(mixed_stats.has_plume, "Forged T3 helm enables has_plume")
	_check(mixed_stats.cuirass_tier == 2 and mixed_stats.armor_tier == 2, "T2 cuirass populates cuirass_tier=2 and armor_tier=2")
	_check(mixed_stats.lantern_tier == 4, "T4 lantern populates lantern_tier=4")
	_check(mixed_stats.lantern_color.is_equal_approx(GameEnums.lantern_color(GameEnums.LanternAspect.SOUL_BLUE)), "Lantern color matches Soul Blue aspect")

	var ov := mixed_stats.to_slot_overrides()
	_check(int(ov["helm_tier"]) == 3 and int(ov["cuirass_tier"]) == 2 and int(ov["lantern_tier"]) == 4 and str(ov["helm_key"]) == "helm_t3", "to_slot_overrides exports all slot descriptors")


func _test_all_classes_weapon_and_offhand_swaps() -> void:
	var weapon_cases := [
		{"w": "zweihander", "off": "", "staff": false},
		{"w": "blade_oarimaar", "off": "", "staff": false},
		{"w": "halberd", "off": "", "staff": false},
		{"w": "bastardsword", "off": "shield_heater", "staff": false},
		{"w": "runed_staff", "off": "", "staff": true},
	]

	for cid in GameRegistry.CLASS_ORDER:
		var hdef := GameRegistry.get_class_def(cid)
		var ps := load(hdef.actor_scene_path) as PackedScene
		_check(ps != null, "Hero scene loads for %s" % cid)
		var vis := ps.instantiate() as ActorVisual
		root.add_child(vis)
		vis.ensure_initialized()

		for tc in weapon_cases:
			var wkey := str(tc["w"])
			var okey := str(tc["off"])
			HeroRigDresser.dress(
				vis,
				cid,
				2,
				wkey,
				okey,
				true,
				Color(0.32, 0.72, 1.0, 1.0),
				{"helm_tier": 3, "cuirass_tier": 2, "lantern_tier": 2, "helm_key": "helm_t3"}
			)
			_check(vis.main_weapon_node != null and is_instance_valid(vis.main_weapon_node), "%s mounted main_weapon_node for %s" % [cid, wkey])
			_check(vis.blade_tip_marker != null and is_instance_valid(vis.blade_tip_marker), "%s mounted BladeTip for %s" % [cid, wkey])
			_check(vis.cast_origin_marker != null and is_instance_valid(vis.cast_origin_marker), "%s has CastOrigin for %s" % [cid, wkey])
			if bool(tc["staff"]):
				_check(vis.cast_origin_marker.get_parent() == vis.main_weapon_node, "%s mounts staff CastOrigin on WeaponHolder" % cid)
			var has_shield := (
				vis.skeleton.get_node_or_null("ForgedAttach_KitOffhandL") != null
				or vis.skeleton.get_node_or_null("ForgedAttach_OffhandL") != null
			)
			_check(has_shield == (okey != ""), "%s offhand shield state matches offhand_key=%s" % [cid, okey])

		HeroRigDresser.dress(vis, cid, 4, "zweihander", "", false, Color(1.0, 0.66, 0.20, 1.0))
		_check(vis.armor_tier == 4 and vis.helm_tier == 4 and vis.cuirass_tier == 4 and not vis.has_plume, "%s 7-arg dress backwards compatibility sets tiers and plume=false" % cid)

		root.remove_child(vis)
		vis.free()
		await process_frame


func _make_synthetic_modular_hero() -> ActorVisual:
	var vis := ActorVisual.new()
	vis.actor_id = "oathbreaker"
	vis.hero_class_id = "oathbreaker"
	vis.is_hero = true
	vis.height_meters = 1.95

	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	vis.add_child(pivot)

	var model := Node3D.new()
	model.name = "SyntheticModularKit"
	pivot.add_child(model)

	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	model.add_child(skel)

	var bones := [
		["root", -1, Vector3(0.0, 0.0, 0.0)],
		["hips", 0, Vector3(0.0, 0.95, 0.0)],
		["chest", 1, Vector3(0.0, 1.35, 0.0)],
		["neck", 2, Vector3(0.0, 1.56, 0.0)],
		["head", 3, Vector3(0.0, 1.65, 0.0)],
		["hand_l", 2, Vector3(0.32, 0.90, 0.06)],
		["offhand_l", 5, Vector3(0.32, 0.86, 0.07)],
		["hand_r", 2, Vector3(-0.32, 0.90, 0.06)],
		["weapon_r", 7, Vector3(-0.32, 0.86, 0.07)],
		["cape_0", 2, Vector3(0.0, 1.50, -0.14)],
		["lantern_bone", 1, Vector3(0.21, 0.96, 0.08)],
	]
	for b in bones:
		var idx := skel.add_bone(str(b[0]))
		if int(b[1]) >= 0:
			skel.set_bone_parent(idx, int(b[1]))
		var parent_pos := Vector3.ZERO
		if int(b[1]) >= 0:
			parent_pos = bones[int(b[1])][2] as Vector3
		skel.set_bone_rest(idx, Transform3D(Basis.IDENTITY, (b[2] as Vector3) - parent_pos))

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.22, 0.28, 0.22)
	var std_mat := StandardMaterial3D.new()
	std_mat.resource_name = "Oathbreaker_PBR"
	std_mat.metallic = 0.85
	std_mat.roughness = 0.35
	box_mesh.surface_set_material(0, std_mat)

	for slot_node in ["Slot_Helm", "Slot_Plume", "Slot_Pauldrons", "Slot_Cuirass", "Slot_Gauntlets", "Slot_Greaves", "Slot_Cloak"]:
		var mi := MeshInstance3D.new()
		mi.name = slot_node
		mi.mesh = box_mesh.duplicate() as Mesh
		if slot_node == "Slot_Helm":
			mi.position = Vector3(0.0, 1.72, 0.0)
		elif slot_node == "Slot_Plume":
			mi.position = Vector3(0.0, 1.88, -0.05)
		elif slot_node == "Slot_Greaves":
			mi.position = Vector3(0.0, 0.14, 0.0)
		else:
			mi.position = Vector3(0.0, 1.15, 0.0)
		skel.add_child(mi)

	return vis


func _test_modular_slots_and_independent_tiers() -> void:
	var vis := _make_synthetic_modular_hero()
	root.add_child(vis)
	vis.ensure_initialized()

	HeroRigDresser.dress(
		vis,
		"oathbreaker",
		2,
		"halberd",
		"shield_tower",
		true,
		Color(0.36, 0.92, 0.46, 1.0),
		{"helm_tier": 4, "cuirass_tier": 2, "lantern_tier": 3, "helm_key": ""}
	)

	var helm_mi := vis.model_instance.find_child("Slot_Helm", true, false) as MeshInstance3D
	var plume_mi := vis.model_instance.find_child("Slot_Plume", true, false) as MeshInstance3D
	var cuirass_mi := vis.model_instance.find_child("Slot_Cuirass", true, false) as MeshInstance3D
	var pauldrons_mi := vis.model_instance.find_child("Slot_Pauldrons", true, false) as MeshInstance3D
	var gauntlets_mi := vis.model_instance.find_child("Slot_Gauntlets", true, false) as MeshInstance3D
	var greaves_mi := vis.model_instance.find_child("Slot_Greaves", true, false) as MeshInstance3D
	var cloak_mi := vis.model_instance.find_child("Slot_Cloak", true, false) as MeshInstance3D

	var helm_mat := helm_mi.get_surface_override_material(0) as ShaderMaterial
	var cuirass_mat := cuirass_mi.get_surface_override_material(0) as ShaderMaterial
	var pauldrons_mat := pauldrons_mi.get_surface_override_material(0) as ShaderMaterial
	var gauntlets_mat := gauntlets_mi.get_surface_override_material(0) as ShaderMaterial
	var greaves_mat := greaves_mi.get_surface_override_material(0) as ShaderMaterial
	var plume_mat := plume_mi.get_surface_override_material(0) as ShaderMaterial
	var cloak_mat := cloak_mi.get_surface_override_material(0) as ShaderMaterial

	_check(helm_mat != null and int(helm_mat.get_shader_parameter("armor_tier")) == 4, "Slot_Helm styled independently with helm_tier=4")
	_check(cuirass_mat != null and int(cuirass_mat.get_shader_parameter("armor_tier")) == 2, "Slot_Cuirass styled independently with cuirass_tier=2")
	_check(pauldrons_mat != null and int(pauldrons_mat.get_shader_parameter("armor_tier")) == 2, "Slot_Pauldrons styled with cuirass_tier=2")
	_check(gauntlets_mat != null and int(gauntlets_mat.get_shader_parameter("armor_tier")) == 2, "Slot_Gauntlets styled with cuirass_tier=2")
	_check(greaves_mat != null and int(greaves_mat.get_shader_parameter("armor_tier")) == 2, "Slot_Greaves styled with cuirass_tier=2")
	_check(plume_mi.visible and plume_mat != null and plume_mat.shader.resource_path == HeroRigDresser.CLOAK_SHADER_PATH, "Slot_Plume visible and uses matte cloak_sway shader")
	_check(cloak_mi.visible and cloak_mat != null and cloak_mat.shader.resource_path == HeroRigDresser.CLOAK_SHADER_PATH, "Slot_Cloak uses cloak_sway shader")

	var lantern_attach := vis.skeleton.get_node_or_null("ForgedAttach_KitLantern") as BoneAttachment3D
	_check(lantern_attach != null and lantern_attach.bone_name == "lantern_bone", "Dynamic waist lantern mounted on lantern_bone")
	var lantern_light := lantern_attach.find_child("LanternLight", true, false) as OmniLight3D if lantern_attach != null else null
	_check(lantern_light != null and lantern_light.light_color.is_equal_approx(Color(0.36, 0.92, 0.46, 1.0)), "LanternLight uses live lantern_color")

	HeroRigDresser.dress(
		vis,
		"oathbreaker",
		2,
		"zweihander",
		"",
		false,
		Color(1.0, 0.66, 0.20, 1.0),
		{"helm_tier": 1, "cuirass_tier": 2}
	)
	_check(not plume_mi.visible, "has_plume=false hides Slot_Plume")
	_check(vis.skeleton.get_node_or_null("ForgedAttach_KitOffhandL") == null, "Removing offhand_key clears shield attachment")

	var swapped_ok := HeroRigDresser.equip_modular_slot(vis, "helm", "res://assets/models/forged/helm_plume.glb", 3)
	_check(swapped_ok, "equip_modular_slot mounts rigid replacement onto head BoneAttachment3D")
	_check(not helm_mi.visible, "equip_modular_slot hides base Slot_Helm")
	var mod_helm := vis.skeleton.get_node_or_null("ModularSlot_helm") as BoneAttachment3D
	_check(mod_helm != null and mod_helm.bone_name == "head", "ModularSlot_helm attached to head bone")

	var restored_ok := HeroRigDresser.equip_modular_slot(vis, "helm", "")
	_check(restored_ok and helm_mi.visible, "equip_modular_slot with empty path restores base Slot_Helm")
	_check(vis.skeleton.get_node_or_null("ModularSlot_helm") == null, "Clearing modular slot removes ModularSlot_helm cleanly")

	var skinned_ok := HeroRigDresser.equip_modular_slot(vis, "cuirass", "res://assets/models/kit/oathbreaker_knight.glb", 4)
	_check(skinned_ok, "equip_modular_slot mounts skinned replacement mesh")
	_check(not cuirass_mi.visible, "equip_modular_slot hides base Slot_Cuirass on skinned swap")
	var mod_cuirass := vis.skeleton.get_node_or_null("ModularSlot_cuirass") as Node3D
	_check(mod_cuirass != null and mod_cuirass.get_child_count() >= 1, "ModularSlot_cuirass created under hero Skeleton3D")
	var rebound_mi := mod_cuirass.get_child(0) as MeshInstance3D if mod_cuirass != null else null
	_check(rebound_mi != null and rebound_mi.get_node_or_null(rebound_mi.skeleton) == vis.skeleton, "Skinned replacement re-bound mi.skeleton to hero Skeleton3D")
	_check(HeroRigDresser.equip_modular_slot(vis, "cuirass", "") and cuirass_mi.visible, "Clearing skinned cuirass restores base Slot_Cuirass")

	root.remove_child(vis)
	vis.free()
	await process_frame


func _test_sculpted_modular_helms_on_oathbreaker() -> void:
	var ps := load(GameRegistry.get_class_def("oathbreaker").actor_scene_path) as PackedScene
	_check(ps != null, "Oathbreaker hero scene loads for sculpted helm checks")
	var vis := ps.instantiate() as ActorVisual
	root.add_child(vis)
	vis.ensure_initialized()

	var helm_mi := vis.model_instance.find_child("Slot_Helm", true, false) as MeshInstance3D
	var plume_mi := vis.model_instance.find_child("Slot_Plume", true, false) as MeshInstance3D
	var cuirass_mi := vis.model_instance.find_child("Slot_Cuirass", true, false) as MeshInstance3D
	_check(helm_mi != null and plume_mi != null and cuirass_mi != null, "Oathbreaker kit exposes Slot_Helm, Slot_Plume, Slot_Cuirass")

	HeroRigDresser.dress(
		vis,
		"oathbreaker",
		1,
		"zweihander",
		"",
		true,
		GameEnums.lantern_color(GameEnums.LanternAspect.EMBER_GOLD),
		{"helm_tier": 3, "cuirass_tier": 1, "lantern_tier": 1, "helm_key": ""}
	)
	_check(helm_mi.visible and plume_mi.visible, "Starter T1 helm (helm_key empty) keeps Slot_Helm and Slot_Plume visible")
	_check(vis.skeleton.get_node_or_null("ModularSlot_helm") == null, "Starter T1 helm does not mount ModularSlot_helm")
	var base_helm_mat := helm_mi.get_surface_override_material(0) as ShaderMaterial
	var base_cuirass_mat := cuirass_mi.get_surface_override_material(0) as ShaderMaterial
	_check(base_helm_mat != null and int(base_helm_mat.get_shader_parameter("armor_tier")) == 3, "Base Slot_Helm keeps independent helm_tier=3")
	_check(base_cuirass_mat != null and int(base_cuirass_mat.get_shader_parameter("armor_tier")) == 1, "Base Slot_Cuirass keeps independent cuirass_tier=1")

	var helm_cases := [
		{"key": "helm_t2", "tier": 2, "expect_emit": false},
		{"key": "helm_t3", "tier": 3, "expect_emit": false},
		{"key": "helm_t4", "tier": 4, "expect_emit": true},
	]
	for hc in helm_cases:
		var hkey := str(hc["key"])
		var htier := int(hc["tier"])
		var expect_emit := bool(hc["expect_emit"])
		HeroRigDresser.dress(
			vis,
			"oathbreaker",
			htier,
			"zweihander",
			"",
			true,
			GameEnums.lantern_color(GameEnums.LanternAspect.EMBER_GOLD),
			{"helm_tier": htier, "cuirass_tier": htier, "lantern_tier": htier, "helm_key": hkey}
		)
		_check(not helm_mi.visible, "%s hides base Slot_Helm" % hkey)
		_check(not plume_mi.visible, "%s hides base Slot_Plume" % hkey)
		_check(vis.skeleton.get_node_or_null("ForgedAttach_KitHelmPlume") == null, "%s does not mount legacy procedural plume" % hkey)
		var mod_helm := vis.skeleton.get_node_or_null("ModularSlot_helm") as BoneAttachment3D
		_check(mod_helm != null and mod_helm.bone_name == "head", "%s mounts ModularSlot_helm on head bone" % hkey)
		var mod_meshes := mod_helm.find_children("*", "MeshInstance3D", true, false) if mod_helm != null else []
		_check(mod_meshes.size() >= 1, "%s ModularSlot_helm has mounted MeshInstance3D" % hkey)
		if mod_meshes.size() >= 1:
			var rmi := mod_meshes[0] as MeshInstance3D
			var smat := rmi.get_surface_override_material(0) as ShaderMaterial
			_check(smat != null and smat.shader.resource_path == HeroRigDresser.ARMOR_SHADER_PATH, "%s uses armor_forge shader" % hkey)
			if smat != null:
				_check(not bool(smat.get_shader_parameter("is_armor_plate")), "%s preserves bespoke PBR paint (is_armor_plate == false)" % hkey)
				_check(bool(smat.get_shader_parameter("has_emission_tex")) == expect_emit, "%s has_emission_tex == %s" % [hkey, str(expect_emit)])

	HeroRigDresser.dress(
		vis,
		"oathbreaker",
		1,
		"zweihander",
		"",
		true,
		GameEnums.lantern_color(GameEnums.LanternAspect.EMBER_GOLD),
		{"helm_tier": 1, "cuirass_tier": 1, "lantern_tier": 1, "helm_key": ""}
	)
	_check(vis.skeleton.get_node_or_null("ModularSlot_helm") == null, "Switching back to T1 frees ModularSlot_helm")
	_check(helm_mi.visible and plume_mi.visible, "Switching back to T1 restores Slot_Helm and Slot_Plume")

	root.remove_child(vis)
	vis.free()
	await process_frame


func _test_sculpted_waist_lantern_all_classes() -> void:
	var aspects := [
		GameEnums.LanternAspect.EMBER_GOLD,
		GameEnums.LanternAspect.SOUL_BLUE,
		GameEnums.LanternAspect.BLIGHT_GREEN,
		GameEnums.LanternAspect.BLOOD_CRIMSON,
	]
	for cid in GameRegistry.CLASS_ORDER:
		var ps := load(GameRegistry.get_class_def(cid).actor_scene_path) as PackedScene
		var vis := ps.instantiate() as ActorVisual
		root.add_child(vis)
		vis.ensure_initialized()

		for asp in aspects:
			var lcol := GameEnums.lantern_color(asp)
			HeroRigDresser.dress(
				vis,
				cid,
				2,
				"zweihander" if cid == "oathbreaker" else ("runed_staff" if cid == "battlemage" else "halberd"),
				"",
				false,
				lcol,
				{"helm_tier": 2, "cuirass_tier": 2, "lantern_tier": 3, "helm_key": ""}
			)
			var attach_name := "ForgedAttach_KitLantern" if vis.is_unified_kit() else "ForgedAttach_WaistLantern"
			var ba := vis.skeleton.get_node_or_null(attach_name) as BoneAttachment3D
			_check(ba != null, "%s mounts sculpted waist lantern (%s)" % [cid, attach_name])
			var light := ba.find_child("LanternLight", true, false) as OmniLight3D if ba != null else null
			_check(light != null and light.light_color.is_equal_approx(lcol), "%s LanternLight matches aspect %d" % [cid, asp])
			var found_tinted_pbr := false
			if ba != null:
				for n in ba.find_children("*", "MeshInstance3D", true, false):
					var lmi := n as MeshInstance3D
					if lmi.mesh == null:
						continue
					for s in lmi.mesh.get_surface_count():
						var ov := lmi.get_surface_override_material(s)
						if ov is StandardMaterial3D:
							var sm := ov as StandardMaterial3D
							if (
								sm.emission_texture != null
								and sm.emission_enabled
								and sm.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY
								and sm.emission.is_equal_approx(lcol)
							):
								found_tinted_pbr = true
			_check(found_tinted_pbr, "%s sculpted waist_lantern.glb emission_texture tints dynamically to aspect %d" % [cid, asp])

		root.remove_child(vis)
		vis.free()
		await process_frame
