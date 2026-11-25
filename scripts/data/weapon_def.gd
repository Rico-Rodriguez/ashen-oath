class_name WeaponDef
extends Resource

@export var weapon_id: String = ""
@export var display_name: String = ""
@export var weapon_type: GameEnums.WeaponType = GameEnums.WeaponType.GREATSWORD
@export var tier: int = 1
@export var mesh_key: String = ""
@export var offhand_key: String = ""
@export var drags_on_ground: bool = false
@export var base_damage: float = 20.0
@export var attack_interval: float = 0.8
@export var range_m: float = 2.5
@export var cleave_arc_deg: float = 120.0
@export var is_ranged: bool = false
@export var projectile_speed: float = 0.0
@export var vfx_profile: String = ""
@export var sfx_event: String = "swing"
@export var bonus_armor: float = 0.0
