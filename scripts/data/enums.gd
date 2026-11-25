class_name GameEnums
extends RefCounted

enum Slot {
	WEAPON,
	HELM,
	CUIRASS,
	LANTERN,
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	SOVEREIGN,
}

enum WeaponType {
	GREATSWORD,
	HALBERD,
	SWORD_SHIELD,
	WAR_STAFF,
}

enum AffixKind {
	CLEAVE_SIZE,
	SPARK_BURN,
	CHAIN_COUNT,
	LIFE_ON_HIT,
	COOLDOWN_HASTE,
	CRIT_SHOCKWAVE,
	MOVE_SPEED,
	WARD_ON_DASH,
}

enum Difficulty {
	NORMAL,
	VETERAN,
	NIGHTMARE,
}

enum LanternAspect {
	EMBER_GOLD,
	SOUL_BLUE,
	BLIGHT_GREEN,
	BLOOD_CRIMSON,
}

enum EnemyArchetype {
	SWARMER,
	RANGED,
	BRUISER,
	CHARGER,
	BOSS,
}


static func slot_key(slot: Slot) -> String:
	match slot:
		Slot.WEAPON:
			return "weapon"
		Slot.HELM:
			return "helm"
		Slot.CUIRASS:
			return "cuirass"
		Slot.LANTERN:
			return "lantern"
	return "weapon"


static func slot_name(slot: Slot) -> String:
	match slot:
		Slot.WEAPON:
			return "Weapon"
		Slot.HELM:
			return "Helm"
		Slot.CUIRASS:
			return "Cuirass"
		Slot.LANTERN:
			return "Waist Lantern"
	return "Gear"


static func rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.SOVEREIGN:
			return "Sovereign"
	return "Common"


static func rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.72, 0.73, 0.76, 1.0)
		Rarity.RARE:
			return Color(0.32, 0.64, 0.96, 1.0)
		Rarity.EPIC:
			return Color(0.74, 0.38, 0.96, 1.0)
		Rarity.SOVEREIGN:
			return Color(0.96, 0.72, 0.24, 1.0)
	return Color.WHITE


static func weapon_type_name(weapon_type: WeaponType) -> String:
	match weapon_type:
		WeaponType.GREATSWORD:
			return "Greatsword"
		WeaponType.HALBERD:
			return "Halberd"
		WeaponType.SWORD_SHIELD:
			return "Sword & Shield"
		WeaponType.WAR_STAFF:
			return "War-Staff"
	return "Weapon"


static func difficulty_name(difficulty: Difficulty) -> String:
	match difficulty:
		Difficulty.NORMAL:
			return "Normal"
		Difficulty.VETERAN:
			return "Veteran"
		Difficulty.NIGHTMARE:
			return "Nightmare"
	return "Normal"


static func lantern_name(aspect: LanternAspect) -> String:
	match aspect:
		LanternAspect.EMBER_GOLD:
			return "Ember Lantern"
		LanternAspect.SOUL_BLUE:
			return "Soulfire Lantern"
		LanternAspect.BLIGHT_GREEN:
			return "Blightglass Lantern"
		LanternAspect.BLOOD_CRIMSON:
			return "Bloodward Lantern"
	return "Lantern"


static func lantern_color(aspect: LanternAspect) -> Color:
	match aspect:
		LanternAspect.EMBER_GOLD:
			return Color(1.0, 0.66, 0.20, 1.0)
		LanternAspect.SOUL_BLUE:
			return Color(0.32, 0.72, 1.0, 1.0)
		LanternAspect.BLIGHT_GREEN:
			return Color(0.36, 0.92, 0.46, 1.0)
		LanternAspect.BLOOD_CRIMSON:
			return Color(0.95, 0.20, 0.28, 1.0)
	return Color(1.0, 0.66, 0.20, 1.0)


static func tier_prefix(tier: int) -> String:
	match clampi(tier, 1, 4):
		1:
			return "Worn Iron"
		2:
			return "Blackened Steel"
		3:
			return "Sovereign Gilded"
		4:
			return "Ashen Barrows"
	return "Worn Iron"


static func affix_count_for_rarity(rarity: Rarity) -> int:
	match rarity:
		Rarity.COMMON:
			return 0
		Rarity.RARE:
			return 1
		Rarity.EPIC:
			return 2
		Rarity.SOVEREIGN:
			return 3
	return 0
