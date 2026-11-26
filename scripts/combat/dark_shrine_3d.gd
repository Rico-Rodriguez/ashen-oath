class_name DarkShrine3D
extends Node3D

signal shrine_triggered(choices: Array[ShrineBlessingDef])

const SHRINE_GLB_PATH := "res://assets/models/kit/kit_dark_shrine.glb"
const ENERGY_SHADER_PATH := "res://shaders/vfx_energy.gdshader"

var director: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var trigger_radius: float = 2.8
var is_offering: bool = false
var is_consumed: bool = false
var offered_choices: Array[ShrineBlessingDef] = []

var _crystal_pivot: Node3D = null
var _crystal_base_y: float = 0.0
var _crystal_mats: Array[StandardMaterial3D] = []
var _ring_shader_mat: ShaderMaterial = null
var _shrine_light: OmniLight3D = null
var _pulse_time: float = 0.0
var _built_visuals: bool = false


func _ready() -> void:
	_build_shrine_geometry()


func setup(p_director: Node, p_pos: Vector3, p_rng: RandomNumberGenerator = null) -> void:
	director = p_director
	global_position = Vector3(p_pos.x, 0.0, p_pos.z)
	if p_rng != null:
		rng = p_rng
	else:
		rng.randomize()
	is_offering = false
	is_consumed = false
	offered_choices.clear()


func _physics_process(delta: float) -> void:
	_pulse_time += delta
	if _crystal_pivot != null and is_instance_valid(_crystal_pivot):
		_crystal_pivot.position.y = _crystal_base_y + sin(_pulse_time * 2.4) * 0.08
		_crystal_pivot.rotation.y = wrapf(_crystal_pivot.rotation.y + 1.05 * delta, -PI, PI)
	if _shrine_light != null and not is_consumed:
		_shrine_light.light_energy = 2.1 + sin(_pulse_time * 3.1) * 0.30

	if is_consumed or is_offering:
		return

	var hero := _get_hero()
	if hero == null or (hero.has_method("is_dead") and bool(hero.call("is_dead"))):
		return

	var d_xz := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	if d_xz <= trigger_radius:
		_trigger_offer(hero)


func _trigger_offer(hero: Node3D) -> void:
	is_offering = true
	var exclude: Array = []
	var active_b: Variant = hero.get("active_blessings")
	if active_b is Array:
		exclude = active_b
	offered_choices = GameRegistry.roll_shrine_choices(rng, 3, exclude)
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "sparkle")
	shrine_triggered.emit(offered_choices)


func mark_consumed() -> void:
	is_consumed = true
	is_offering = false
	if _ring_shader_mat != null:
		_ring_shader_mat.set_shader_parameter("energy_color", Color(0.92, 0.62, 0.24, 1.0))
		_ring_shader_mat.set_shader_parameter("hdr_gain", 0.65)
		_ring_shader_mat.set_shader_parameter("fade_alpha", 0.45)
	for cm in _crystal_mats:
		if cm != null:
			cm.albedo_color = Color(0.95, 0.68, 0.28, 1.0)
			cm.emission = Color(0.95, 0.56, 0.18, 1.0)
			cm.emission_energy_multiplier = 0.85
	if _shrine_light != null:
		_shrine_light.light_color = Color(0.96, 0.64, 0.24, 1.0)
		_shrine_light.light_energy = 0.85


func _build_shrine_geometry() -> void:
	if _built_visuals:
		return
	_built_visuals = true
	if DisplayServer.get_name() == "headless":
		return

	var shrine_ps := load(SHRINE_GLB_PATH) as PackedScene
	if shrine_ps != null:
		var inst := shrine_ps.instantiate() as Node3D
		inst.name = "DarkShrineModel"
		inst.scale = Vector3.ONE * 1.10
		_apply_shrine_stone_materials(inst)
		add_child(inst)
		var crystal := inst.find_child("ShrineCrystal", true, false) as Node3D
		if crystal != null:
			_crystal_pivot = crystal
			_crystal_base_y = crystal.position.y
			for n in crystal.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi.mesh == null:
					continue
				for s in mi.mesh.get_surface_count():
					var mat := mi.get_active_material(s)
					if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
						var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
						dup.emission_energy_multiplier = 1.35
						mi.set_surface_override_material(s, dup)
						_crystal_mats.append(dup)
			if crystal is MeshInstance3D:
				var cmi := crystal as MeshInstance3D
				if cmi.mesh != null:
					for s in cmi.mesh.get_surface_count():
						var mat := cmi.get_active_material(s)
						if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
							var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
							dup.emission_energy_multiplier = 1.35
							cmi.set_surface_override_material(s, dup)
							_crystal_mats.append(dup)

	var energy_sh := load(ENERGY_SHADER_PATH) as Shader
	if energy_sh != null:
		_ring_shader_mat = ShaderMaterial.new()
		_ring_shader_mat.shader = energy_sh
		_ring_shader_mat.set_shader_parameter("beam_mode", 1)
		_ring_shader_mat.set_shader_parameter("energy_color", Color(0.28, 0.68, 1.0, 1.0))
		_ring_shader_mat.set_shader_parameter("hdr_gain", 1.28)
		_ring_shader_mat.set_shader_parameter("fade_alpha", 0.78)
		var ring_mi := MeshInstance3D.new()
		ring_mi.name = "EtchedRuneRing"
		var rpm := PlaneMesh.new()
		rpm.size = Vector2(4.6, 4.6)
		ring_mi.mesh = rpm
		ring_mi.position = Vector3(0.0, 0.032, 0.0)
		ring_mi.material_override = _ring_shader_mat
		ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring_mi)

	_shrine_light = OmniLight3D.new()
	_shrine_light.light_color = Color(0.32, 0.74, 1.0, 1.0)
	_shrine_light.omni_range = 6.8
	_shrine_light.light_energy = 2.1
	_shrine_light.position = Vector3(0.0, 2.95, 0.0)
	_shrine_light.shadow_enabled = false
	add_child(_shrine_light)


static func _make_shrine_stone_material(albedo: Color, rough_val: float) -> StandardMaterial3D:
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
	sm.roughness = rough_val
	sm.metallic = 0.06
	return sm


static func _apply_shrine_stone_materials(root_node: Node3D) -> void:
	var stone_mat := _make_shrine_stone_material(Color(0.44, 0.46, 0.52), 0.82)
	var dark_stone_mat := _make_shrine_stone_material(Color(0.24, 0.26, 0.32), 0.78)
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


func _get_hero() -> Node3D:
	if director != null and director.get("hero") is Node3D:
		var h := director.get("hero") as Node3D
		if is_instance_valid(h):
			return h
	if not is_inside_tree():
		return null
	var list := get_tree().get_nodes_in_group("combat_hero")
	return list[0] as Node3D if not list.is_empty() else null


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
