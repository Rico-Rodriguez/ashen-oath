extends Node

signal profile_changed()
signal class_selected(class_id: String)
signal equipment_changed(class_id: String)

const SAVE_PATH: String = "user://ashen_oath_save.json"
const SAVE_VERSION: int = 2
const DEFAULT_SETTINGS: Dictionary = {
	"music_on": true,
	"sfx_on": true,
	"haptics_on": true,
	"music_vol": 0.8,
	"sfx_vol": 0.9,
	"screen_shake": 1.0,
	"reduce_flashing": false,
	"damage_numbers": true,
	"text_size": 100,
	"left_handed": false,
}

var persist_enabled: bool = true
var selected_class_id: String = "oathbreaker"
var selected_zone_id: String = "fringe"
var selected_difficulty: GameEnums.Difficulty = GameEnums.Difficulty.NORMAL
var gold: int = 120
var scrap: int = 24
var inventory: Array[EquipmentItem] = []
var unlocked_zones: Array[String] = ["fringe"]
var cleared_zones: Dictionary = {}
var run_stats: Dictionary = {"runs_played": 0, "victories": 0, "defeats": 0}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()

var _equipped: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	load_profile()


func reset_to_fresh(persist: bool = true) -> void:
	persist_enabled = persist
	selected_class_id = "oathbreaker"
	selected_zone_id = "fringe"
	selected_difficulty = GameEnums.Difficulty.NORMAL
	gold = 120
	scrap = 24
	inventory = []
	unlocked_zones = ["fringe"]
	cleared_zones = {}
	run_stats = {"runs_played": 0, "victories": 0, "defeats": 0}
	settings = DEFAULT_SETTINGS.duplicate()
	_equipped = {}
	for cid in GameRegistry.CLASS_ORDER:
		_provision_starter_kit(cid)
	_sync_audio_settings()
	if persist_enabled:
		save_profile()
	profile_changed.emit()


func _provision_starter_kit(class_id: String) -> void:
	var hdef := GameRegistry.get_class_def(class_id)
	if hdef == null:
		return
	var kit: Dictionary = {}
	kit[GameEnums.Slot.WEAPON] = LootEngine.make_starter_item(GameEnums.Slot.WEAPON, hdef, _rng)
	kit[GameEnums.Slot.HELM] = LootEngine.make_starter_item(GameEnums.Slot.HELM, hdef, _rng)
	kit[GameEnums.Slot.CUIRASS] = LootEngine.make_starter_item(GameEnums.Slot.CUIRASS, hdef, _rng)
	kit[GameEnums.Slot.LANTERN] = LootEngine.make_starter_item(GameEnums.Slot.LANTERN, hdef, _rng)
	_equipped[class_id] = kit


func _ensure_class_kit(class_id: String) -> void:
	var hdef := GameRegistry.get_class_def(class_id)
	if hdef == null:
		return
	if not _equipped.has(class_id) or not (_equipped[class_id] is Dictionary):
		_provision_starter_kit(class_id)
		return
	var kit: Dictionary = _equipped[class_id]
	for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
		if not kit.has(slot) or not (kit[slot] is EquipmentItem):
			kit[slot] = LootEngine.make_starter_item(slot, hdef, _rng)


func select_class(class_id: String) -> bool:
	if GameRegistry.get_class_def(class_id) == null:
		return false
	selected_class_id = class_id
	save_profile()
	class_selected.emit(class_id)
	profile_changed.emit()
	return true


func select_zone(zone_id: String) -> bool:
	if GameRegistry.get_zone(zone_id) == null or not unlocked_zones.has(zone_id):
		return false
	selected_zone_id = zone_id
	save_profile()
	profile_changed.emit()
	return true


func select_difficulty(difficulty: GameEnums.Difficulty) -> void:
	selected_difficulty = difficulty
	save_profile()
	profile_changed.emit()


func is_zone_unlocked(zone_id: String) -> bool:
	return unlocked_zones.has(zone_id)


func get_equipped(class_id: String = "") -> Dictionary:
	var cid := class_id if class_id != "" else selected_class_id
	_ensure_class_kit(cid)
	return (_equipped.get(cid, {}) as Dictionary).duplicate()


func get_equipped_item(class_id: String, slot: GameEnums.Slot) -> EquipmentItem:
	var cid := class_id if class_id != "" else selected_class_id
	_ensure_class_kit(cid)
	var src: Dictionary = _equipped.get(cid, {})
	var item: Variant = src.get(slot)
	return item if item is EquipmentItem else null


func get_class_power_score(class_id: String = "") -> int:
	var eq := get_equipped(class_id)
	var total := 0
	for k in eq:
		var item: Variant = eq[k]
		if item is EquipmentItem:
			total += item.power_score()
	return total


func get_combat_stats(class_id: String = "", blessings: Array = []) -> CombatStats:
	var cid := class_id if class_id != "" else selected_class_id
	var hdef := GameRegistry.get_class_def(cid)
	var eq := get_equipped(cid)
	return LootEngine.compute_combat_stats(hdef, eq, blessings)


func compute_stats(class_id: String = "", blessings: Array = []) -> CombatStats:
	return get_combat_stats(class_id, blessings)


func get_item(item_uid: String) -> EquipmentItem:
	if item_uid == "":
		return null
	for cid in _equipped:
		var kit: Dictionary = _equipped[cid]
		for slot in kit:
			var eq_item: Variant = kit[slot]
			if eq_item is EquipmentItem and eq_item.uid == item_uid:
				return eq_item
	for inv_item in inventory:
		if inv_item != null and inv_item.uid == item_uid:
			return inv_item
	return null


func is_item_equipped(item_uid: String) -> bool:
	for cid in _equipped:
		var kit: Dictionary = _equipped[cid]
		for slot in kit:
			var eq_item: Variant = kit[slot]
			if eq_item is EquipmentItem and eq_item.uid == item_uid:
				return true
	return false


func add_item_to_inventory(item: EquipmentItem) -> void:
	if item == null:
		return
	if get_item(item.uid) != null:
		item.uid = LootEngine.next_uid(_rng)
	inventory.append(item)
	save_profile()
	profile_changed.emit()


func equip_item(class_id: String, item_uid: String) -> bool:
	var cid := class_id if class_id != "" else selected_class_id
	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null or item_uid == "":
		return false
	_ensure_class_kit(cid)
	var kit: Dictionary = _equipped[cid]

	for slot in kit:
		var current: Variant = kit[slot]
		if current is EquipmentItem and current.uid == item_uid:
			return true

	var inv_idx := -1
	for i in range(inventory.size()):
		if inventory[i] != null and inventory[i].uid == item_uid:
			inv_idx = i
			break
	if inv_idx < 0:
		return false

	var candidate: EquipmentItem = inventory[inv_idx]
	if candidate.slot == GameEnums.Slot.WEAPON and not hdef.can_equip_weapon_type(candidate.weapon_type):
		return false

	inventory.remove_at(inv_idx)
	var displaced: Variant = kit.get(candidate.slot)
	kit[candidate.slot] = candidate
	if displaced is EquipmentItem:
		inventory.append(displaced)

	save_profile()
	equipment_changed.emit(cid)
	profile_changed.emit()
	return true


func temper_item(item_uid: String) -> bool:
	var item := get_item(item_uid)
	if item == null:
		return false
	if item.temper_level >= EquipmentItem.MAX_TEMPER_LEVEL:
		return false
	var cost := item.temper_gold_cost()
	if gold < cost:
		return false

	gold -= cost
	item.temper_level += 1

	var owner_class := _find_equipped_owner(item_uid)
	save_profile()
	if owner_class != "":
		equipment_changed.emit(owner_class)
	profile_changed.emit()
	return true


func salvage_item(item_uid: String) -> int:
	if item_uid == "":
		return 0
	var inv_idx := -1
	for i in range(inventory.size()):
		if inventory[i] != null and inventory[i].uid == item_uid:
			inv_idx = i
			break
	if inv_idx < 0:
		return 0

	var item: EquipmentItem = inventory[inv_idx]
	var gained := item.salvage_scrap_value()
	inventory.remove_at(inv_idx)
	scrap += gained
	save_profile()
	profile_changed.emit()
	return gained


func forge_targeted(
	slot: GameEnums.Slot,
	tier: int,
	weapon_type: GameEnums.WeaponType = GameEnums.WeaponType.GREATSWORD
) -> EquipmentItem:
	var clamped_tier := clampi(tier, 1, 4)
	var cost := LootEngine.forge_cost(clamped_tier)
	var gold_cost := int(cost["gold"])
	var scrap_cost := int(cost["scrap"])
	if gold < gold_cost or scrap < scrap_cost:
		return null

	gold -= gold_cost
	scrap -= scrap_cost
	var forged := LootEngine.forge_item(_rng, slot, clamped_tier, weapon_type)
	inventory.append(forged)
	save_profile()
	profile_changed.emit()
	return forged


func record_run_victory(
	zone_id: String,
	difficulty: GameEnums.Difficulty,
	gold_earned: int,
	items_dropped: Array
) -> void:
	gold += maxi(0, gold_earned)
	_ingest_drops(items_dropped)
	run_stats["runs_played"] = int(run_stats.get("runs_played", 0)) + 1
	run_stats["victories"] = int(run_stats.get("victories", 0)) + 1

	var diff_list: Array = cleared_zones.get(zone_id, [])
	if not diff_list.has(int(difficulty)):
		diff_list.append(int(difficulty))
	cleared_zones[zone_id] = diff_list

	var zdef := GameRegistry.get_zone(zone_id)
	if zdef != null and zdef.depth_index + 1 < GameRegistry.ZONE_ORDER.size():
		var next_zone := GameRegistry.get_zone_by_depth(zdef.depth_index + 1)
		if next_zone != null and not unlocked_zones.has(next_zone.zone_id):
			unlocked_zones.append(next_zone.zone_id)

	save_profile()
	profile_changed.emit()


func record_run_defeat(gold_earned: int, items_dropped: Array) -> void:
	gold += maxi(0, gold_earned)
	_ingest_drops(items_dropped)
	run_stats["runs_played"] = int(run_stats.get("runs_played", 0)) + 1
	run_stats["defeats"] = int(run_stats.get("defeats", 0)) + 1
	save_profile()
	profile_changed.emit()


func to_dict() -> Dictionary:
	var eq_out: Dictionary = {}
	for cid in GameRegistry.CLASS_ORDER:
		_ensure_class_kit(cid)
		var kit: Dictionary = _equipped[cid]
		var cid_dict: Dictionary = {}
		for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
			var item: Variant = kit.get(slot)
			if item is EquipmentItem:
				cid_dict[GameEnums.slot_key(slot)] = item.to_dict()
		eq_out[cid] = cid_dict

	var inv_out: Array[Dictionary] = []
	for item in inventory:
		if item != null:
			inv_out.append(item.to_dict())

	return {
		"version": SAVE_VERSION,
		"selected_class_id": selected_class_id,
		"selected_zone_id": selected_zone_id,
		"selected_difficulty": int(selected_difficulty),
		"gold": gold,
		"scrap": scrap,
		"equipped": eq_out,
		"inventory": inv_out,
		"unlocked_zones": unlocked_zones.duplicate(),
		"cleared_zones": cleared_zones.duplicate(true),
		"run_stats": run_stats.duplicate(true),
		"settings": settings.duplicate(true),
	}


func load_from_dict(d: Dictionary, persist: bool = false) -> void:
	persist_enabled = persist
	var cid := str(d.get("selected_class_id", "oathbreaker"))
	selected_class_id = cid if GameRegistry.get_class_def(cid) != null else "oathbreaker"

	var zid := str(d.get("selected_zone_id", "fringe"))
	selected_zone_id = zid if GameRegistry.get_zone(zid) != null else "fringe"

	selected_difficulty = clampi(int(d.get("selected_difficulty", 0)), 0, GameEnums.Difficulty.size() - 1) as GameEnums.Difficulty
	gold = maxi(0, int(d.get("gold", 120)))
	scrap = maxi(0, int(d.get("scrap", 24)))

	_equipped = {}
	var raw_eq: Variant = d.get("equipped", {})
	if raw_eq is Dictionary:
		for class_key in GameRegistry.CLASS_ORDER:
			var raw_kit: Variant = raw_eq.get(class_key, {})
			if raw_kit is Dictionary:
				var parsed_kit: Dictionary = {}
				for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
					var skey := GameEnums.slot_key(slot)
					var entry: Variant = raw_kit.get(skey)
					if entry is Dictionary:
						parsed_kit[slot] = EquipmentItem.from_dict(entry)
				_equipped[class_key] = parsed_kit
	for class_key in GameRegistry.CLASS_ORDER:
		_ensure_class_kit(class_key)

	inventory = []
	var raw_inv: Variant = d.get("inventory", [])
	if raw_inv is Array:
		for entry in raw_inv:
			if entry is Dictionary:
				var parsed_item := EquipmentItem.from_dict(entry)
				if parsed_item.uid == "":
					parsed_item.uid = LootEngine.next_uid(_rng)
				inventory.append(parsed_item)

	unlocked_zones = ["fringe"]
	var raw_unlocked: Variant = d.get("unlocked_zones", ["fringe"])
	if raw_unlocked is Array:
		for z in raw_unlocked:
			var z_str := str(z)
			if GameRegistry.get_zone(z_str) != null and not unlocked_zones.has(z_str):
				unlocked_zones.append(z_str)
	if not unlocked_zones.has(selected_zone_id):
		selected_zone_id = "fringe"

	cleared_zones = {}
	var raw_cleared: Variant = d.get("cleared_zones", {})
	if raw_cleared is Dictionary:
		for zk in raw_cleared:
			var arr_val: Variant = raw_cleared[zk]
			var norm_arr: Array[int] = []
			if arr_val is Array:
				for dv in arr_val:
					var di := int(dv)
					if not norm_arr.has(di):
						norm_arr.append(di)
			cleared_zones[str(zk)] = norm_arr

	run_stats = {"runs_played": 0, "victories": 0, "defeats": 0}
	var raw_stats: Variant = d.get("run_stats", {})
	if raw_stats is Dictionary:
		for k in ["runs_played", "victories", "defeats"]:
			run_stats[k] = maxi(0, int(raw_stats.get(k, 0)))

	settings = DEFAULT_SETTINGS.duplicate()
	var raw_settings: Variant = d.get("settings", {})
	if raw_settings is Dictionary:
		for k in raw_settings:
			settings[k] = raw_settings[k]

	_sync_audio_settings()
	if persist_enabled:
		save_profile()
	profile_changed.emit()


func save_profile() -> bool:
	if not persist_enabled:
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return true


func load_profile() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		reset_to_fresh(true)
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		reset_to_fresh(true)
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		reset_to_fresh(true)
		return false
	load_from_dict(parsed, true)
	return true


func _ingest_drops(items_dropped: Array) -> void:
	for drop in items_dropped:
		if drop is EquipmentItem:
			if drop.uid == "" or get_item(drop.uid) != null:
				drop.uid = LootEngine.next_uid(_rng)
			inventory.append(drop)


func _find_equipped_owner(item_uid: String) -> String:
	for cid in _equipped:
		var kit: Dictionary = _equipped[cid]
		for slot in kit:
			var eq_item: Variant = kit[slot]
			if eq_item is EquipmentItem and eq_item.uid == item_uid:
				return str(cid)
	return ""


func _sync_audio_settings() -> void:
	var ad: Node = get_node_or_null("/root/AudioDirector")
	if ad != null and ad.has_method("_load_settings"):
		ad.call("_load_settings")
