class_name HeroClassDef
extends Resource

@export var class_id: String = ""
@export var display_name: String = ""
@export var subtitle: String = ""
@export var lore: String = ""
@export var actor_scene_path: String = ""
@export var portrait_path: String = ""
@export var base_hp: float = 200.0
@export var base_armor: float = 20.0
@export var base_move_speed: float = 5.5
@export var base_crit: float = 0.08
@export var allowed_weapons: Array[GameEnums.WeaponType] = []
@export var starter_weapon_id: String = ""
@export var starter_lantern: GameEnums.LanternAspect = GameEnums.LanternAspect.EMBER_GOLD
@export var skill_1: AbilityDef
@export var skill_2: AbilityDef
@export var dash_ability: AbilityDef


func can_equip_weapon_type(wt: GameEnums.WeaponType) -> bool:
	return allowed_weapons.has(wt)
