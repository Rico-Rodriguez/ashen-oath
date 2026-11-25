class_name DarkShrine3D
extends Node3D

signal shrine_triggered(choices: Array[ShrineBlessingDef])

var director: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var trigger_radius: float = 2.8
var is_offering: bool = false
var is_consumed: bool = false
var offered_choices: Array[ShrineBlessingDef] = []

var _crystal_pivot: Node3D = null
var _rune_mat: StandardMaterial3D = null
var _shrine_light: OmniLight3D = null
var _pulse_time: float = 0.0


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
	if _crystal_pivot != null:
		_crystal_pivot.position.y = 2.35 + sin(_pulse_time * 2.4) * 0.10
		_crystal_pivot.rotation.y = wrapf(_crystal_pivot.rotation.y + 1.15 * delta, -PI, PI)
	if _shrine_light != null and not is_consumed:
		_shrine_light.light_energy = 2.2 + sin(_pulse_time * 3.1) * 0.35

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
	if _rune_mat != null:
		_rune_mat.albedo_color = Color(0.95, 0.68, 0.28, 1.0)
		_rune_mat.emission = Color(0.95, 0.56, 0.18, 1.0)
		_rune_mat.emission_energy_multiplier = 1.1
	if _shrine_light != null:
		_shrine_light.light_color = Color(0.96, 0.64, 0.24, 1.0)
		_shrine_light.light_energy = 0.85


func _build_shrine_geometry() -> void:
	if _crystal_pivot != null:
		return

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.16, 0.17, 0.20, 1.0)
	stone_mat.roughness = 0.86
	stone_mat.metallic = 0.12

	var plinth := MeshInstance3D.new()
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.top_radius = 1.15
	plinth_mesh.bottom_radius = 1.40
	plinth_mesh.height = 0.36
	plinth_mesh.radial_segments = 8
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0.0, 0.18, 0.0)
	plinth.material_override = stone_mat
	add_child(plinth)

	var obelisk := MeshInstance3D.new()
	var ob_mesh := CylinderMesh.new()
	ob_mesh.top_radius = 0.32
	ob_mesh.bottom_radius = 0.52
	ob_mesh.height = 1.75
	ob_mesh.radial_segments = 6
	obelisk.mesh = ob_mesh
	obelisk.position = Vector3(0.0, 1.18, 0.0)
	obelisk.material_override = stone_mat
	add_child(obelisk)

	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.36, 0.78, 1.0, 1.0)
	_rune_mat.roughness = 0.20
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(0.28, 0.68, 1.0, 1.0)
	_rune_mat.emission_energy_multiplier = 3.4

	var band := MeshInstance3D.new()
	var band_mesh := TorusMesh.new()
	band_mesh.inner_radius = 0.44
	band_mesh.outer_radius = 0.52
	band_mesh.rings = 12
	band_mesh.ring_segments = 8
	band.mesh = band_mesh
	band.position = Vector3(0.0, 1.35, 0.0)
	band.material_override = _rune_mat
	add_child(band)

	_crystal_pivot = Node3D.new()
	_crystal_pivot.position = Vector3(0.0, 2.35, 0.0)
	add_child(_crystal_pivot)

	var crystal := MeshInstance3D.new()
	var c_mesh := PrismMesh.new()
	c_mesh.size = Vector3(0.42, 0.62, 0.42)
	crystal.mesh = c_mesh
	crystal.material_override = _rune_mat
	_crystal_pivot.add_child(crystal)

	_shrine_light = OmniLight3D.new()
	_shrine_light.light_color = Color(0.34, 0.74, 1.0, 1.0)
	_shrine_light.omni_range = 6.5
	_shrine_light.light_energy = 2.2
	_shrine_light.position = Vector3(0.0, 2.25, 0.0)
	add_child(_shrine_light)


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
