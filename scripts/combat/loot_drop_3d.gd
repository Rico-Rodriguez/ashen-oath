class_name LootDrop3D
extends Node3D

enum DropKind {
	GOLD,
	ITEM,
}

signal collected_gold(amount: int)
signal collected_item(item: EquipmentItem)

var director: Node = null
var vfx: Node3D = null
var drop_kind: DropKind = DropKind.GOLD
var gold_amount: int = 5
var equipment_item: EquipmentItem = null
var force_vacuum: bool = false

var _collected: bool = false
var _age: float = 0.0
var _hop_timer: float = 0.0
var _hop_duration: float = 0.24
var _hop_start: Vector3 = Vector3.ZERO
var _hop_end: Vector3 = Vector3.ZERO
var _magnet_speed: float = 7.5
var _visual_pivot: Node3D = null


func setup_gold(
	p_director: Node,
	p_origin: Vector3,
	p_amount: int,
	rng: RandomNumberGenerator = null
) -> void:
	director = p_director
	drop_kind = DropKind.GOLD
	gold_amount = maxi(1, p_amount)
	_init_hop(p_origin, rng, 1.35)
	_build_gold_visual()


func setup_item(
	p_director: Node,
	p_vfx: Node3D,
	p_origin: Vector3,
	p_item: EquipmentItem,
	rng: RandomNumberGenerator = null
) -> void:
	director = p_director
	vfx = p_vfx
	drop_kind = DropKind.ITEM
	equipment_item = p_item
	_init_hop(p_origin, rng, 1.85)
	_build_item_visual()

	var rarity := equipment_item.rarity if equipment_item != null else GameEnums.Rarity.COMMON
	var beam_col := GameEnums.rarity_color(rarity)
	var high_tier := int(rarity) >= int(GameEnums.Rarity.EPIC)
	if vfx != null and vfx.has_method("spawn_loot_beam"):
		vfx.call("spawn_loot_beam", self, beam_col, high_tier)

	var ad := _audio()
	if ad != null:
		ad.call("sfx", "rare_chime" if int(rarity) >= int(GameEnums.Rarity.RARE) else "gear_drop")


func is_collected() -> bool:
	return _collected


func collect_immediately() -> void:
	if _collected:
		return
	_collected = true
	var ad := _audio()
	if drop_kind == DropKind.GOLD:
		if ad != null:
			ad.call("sfx", "coin")
		collected_gold.emit(gold_amount)
	elif equipment_item != null:
		if ad != null:
			ad.call("sfx", "gear_pickup")
			ad.call("haptic", "rare" if int(equipment_item.rarity) >= int(GameEnums.Rarity.EPIC) else "light")
		collected_item.emit(equipment_item)
	visible = false
	set_physics_process(false)
	queue_free()


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if director != null and bool(director.get("is_shrine_open")):
		return

	_age += delta
	if _visual_pivot != null:
		_visual_pivot.rotation.y = wrapf(_visual_pivot.rotation.y + 2.4 * delta, -PI, PI)
		_visual_pivot.position.y = 0.28 + sin(_age * 3.5) * 0.06

	if _hop_timer < _hop_duration:
		_hop_timer = minf(_hop_duration, _hop_timer + delta)
		var t := _hop_timer / _hop_duration
		var pos := _hop_start.lerp(_hop_end, t)
		pos.y = sin(t * PI) * 0.85
		global_position = pos
		return

	global_position.y = 0.0
	var hero := _get_hero()
	if hero == null or (hero.has_method("is_dead") and bool(hero.call("is_dead"))):
		return

	var to_hero := Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)
	var dist := Vector2(to_hero.x, to_hero.z).length()

	if drop_kind == DropKind.GOLD:
		if force_vacuum or dist <= 5.5:
			_magnet_speed = minf(30.0, _magnet_speed + 42.0 * delta)
			var step := _magnet_speed * delta
			if dist <= maxf(0.65, step):
				collect_immediately()
				return
			global_position += (to_hero / maxf(dist, 0.0001)) * step
	else:
		if dist <= 2.4:
			collect_immediately()
			return
		if force_vacuum:
			_magnet_speed = minf(28.0, _magnet_speed + 38.0 * delta)
			var step := _magnet_speed * delta
			if dist <= maxf(1.2, step):
				collect_immediately()
				return
			global_position += (to_hero / maxf(dist, 0.0001)) * step


func _init_hop(origin: Vector3, rng: RandomNumberGenerator, spread: float) -> void:
	_hop_start = Vector3(origin.x, 0.0, origin.z)
	var angle := rng.randf_range(0.0, TAU) if rng != null else randf_range(0.0, TAU)
	var rad := rng.randf_range(0.35, spread) if rng != null else randf_range(0.35, spread)
	var target := _hop_start + Vector3(cos(angle) * rad, 0.0, sin(angle) * rad)
	if director != null and director.has_method("clamp_arena_position"):
		target = director.call("clamp_arena_position", target)
		target.y = 0.0
	_hop_end = target
	global_position = _hop_start


func _build_gold_visual() -> void:
	_visual_pivot = Node3D.new()
	_visual_pivot.position = Vector3(0.0, 0.26, 0.0)
	add_child(_visual_pivot)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.24, 1.0)
	mat.metallic = 0.85
	mat.roughness = 0.22
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.70, 0.16, 1.0)
	mat.emission_energy_multiplier = 1.6

	var coin := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.20
	cm.bottom_radius = 0.20
	cm.height = 0.07
	cm.radial_segments = 12
	coin.mesh = cm
	coin.rotation_degrees.x = 68.0
	coin.material_override = mat
	_visual_pivot.add_child(coin)


func _build_item_visual() -> void:
	_visual_pivot = Node3D.new()
	_visual_pivot.position = Vector3(0.0, 0.34, 0.0)
	add_child(_visual_pivot)

	var rarity := equipment_item.rarity if equipment_item != null else GameEnums.Rarity.COMMON
	var col := GameEnums.rarity_color(rarity)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.lightened(0.18)
	mat.metallic = 0.65
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.6

	var relic := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.34, 0.34)
	relic.mesh = box
	relic.rotation_degrees = Vector3(35.0, 0.0, 45.0)
	relic.material_override = mat
	_visual_pivot.add_child(relic)


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
