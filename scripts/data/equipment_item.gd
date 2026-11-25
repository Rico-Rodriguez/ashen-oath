class_name EquipmentItem
extends Resource

const MAX_TEMPER_LEVEL: int = 5

@export var uid: String = ""
@export var slot: GameEnums.Slot = GameEnums.Slot.WEAPON
@export var tier: int = 1
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
@export var base_id: String = ""
@export var weapon_type: GameEnums.WeaponType = GameEnums.WeaponType.GREATSWORD
@export var lantern_aspect: GameEnums.LanternAspect = GameEnums.LanternAspect.EMBER_GOLD
@export var has_plume: bool = false
@export var temper_level: int = 0
@export var affixes: Array[AffixRoll] = []


func display_name() -> String:
	var base_title := ""
	match slot:
		GameEnums.Slot.WEAPON:
			var wdef := GameRegistry.get_weapon(base_id)
			if wdef == null:
				wdef = GameRegistry.get_weapon_by_type_and_tier(weapon_type, tier)
			base_title = wdef.display_name if wdef != null else "%s %s" % [GameEnums.tier_prefix(tier), GameEnums.weapon_type_name(weapon_type)]
		GameEnums.Slot.HELM:
			base_title = str(GameRegistry.helm_stats(tier)["name"])
		GameEnums.Slot.CUIRASS:
			base_title = str(GameRegistry.cuirass_stats(tier)["name"])
		GameEnums.Slot.LANTERN:
			base_title = GameRegistry.lantern_display_name(tier, lantern_aspect)
	if temper_level > 0:
		return "%s +%d" % [base_title, temper_level]
	return base_title


func temper_multiplier() -> float:
	return 1.0 + 0.08 * float(temper_level)


func temper_gold_cost() -> int:
	if temper_level >= MAX_TEMPER_LEVEL:
		return 0
	return clampi(tier, 1, 4) * 40 * (temper_level + 1) + int(rarity) * 20


func salvage_scrap_value() -> int:
	return clampi(tier, 1, 4) * 6 + int(rarity) * 5 + temper_level * 4


func power_score() -> int:
	var raw := float(clampi(tier, 1, 4) * 35 + int(rarity) * 16 + affixes.size() * 10)
	return roundi(raw * temper_multiplier())


func to_dict() -> Dictionary:
	var affix_list: Array[Dictionary] = []
	for a in affixes:
		if a != null:
			affix_list.append(a.to_dict())
	return {
		"uid": uid,
		"slot": int(slot),
		"tier": clampi(tier, 1, 4),
		"rarity": int(rarity),
		"base_id": base_id,
		"weapon_type": int(weapon_type),
		"lantern_aspect": int(lantern_aspect),
		"has_plume": has_plume,
		"temper_level": clampi(temper_level, 0, MAX_TEMPER_LEVEL),
		"affixes": affix_list,
	}


static func from_dict(d: Dictionary) -> EquipmentItem:
	var item := EquipmentItem.new()
	item.uid = str(d.get("uid", ""))
	item.slot = clampi(int(d.get("slot", 0)), 0, GameEnums.Slot.size() - 1) as GameEnums.Slot
	item.tier = clampi(int(d.get("tier", 1)), 1, 4)
	item.rarity = clampi(int(d.get("rarity", 0)), 0, GameEnums.Rarity.size() - 1) as GameEnums.Rarity
	item.base_id = str(d.get("base_id", ""))
	item.weapon_type = clampi(int(d.get("weapon_type", 0)), 0, GameEnums.WeaponType.size() - 1) as GameEnums.WeaponType
	item.lantern_aspect = clampi(int(d.get("lantern_aspect", 0)), 0, GameEnums.LanternAspect.size() - 1) as GameEnums.LanternAspect
	item.has_plume = bool(d.get("has_plume", false))
	item.temper_level = clampi(int(d.get("temper_level", 0)), 0, MAX_TEMPER_LEVEL)
	item.affixes = []
	var raw_affixes: Variant = d.get("affixes", [])
	if raw_affixes is Array:
		for entry in raw_affixes:
			if entry is Dictionary:
				item.affixes.append(AffixRoll.from_dict(entry))
	return item
