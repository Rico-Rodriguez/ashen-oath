class_name CombatStats
extends RefCounted

var max_hp: float = 200.0
var armor: float = 20.0
var move_speed: float = 5.5
var attack_damage: float = 25.0
var attack_interval: float = 0.8
var attack_range: float = 2.5
var cleave_arc_deg: float = 120.0
var crit_chance: float = 0.08
var crit_mult: float = 1.75
var is_ranged: bool = false
var projectile_speed: float = 0.0
var drags_on_ground: bool = false
var cleave_size_mult: float = 1.0
var spark_burn_dps: float = 0.0
var chain_bonus_targets: int = 0
var life_on_hit: float = 0.0
var cooldown_scale: float = 1.0
var crit_shockwave_damage: float = 0.0
var ward_on_dash_hp: float = 0.0
var lantern_aspect: GameEnums.LanternAspect = GameEnums.LanternAspect.EMBER_GOLD
var lantern_color: Color = Color(1.0, 0.66, 0.20, 1.0)
var lantern_aura_dps: float = 0.0
var armor_tier: int = 1
var helm_tier: int = 1
var has_plume: bool = false
var weapon_mesh_key: String = "zweihander"
var offhand_mesh_key: String = ""
var weapon_vfx_profile: String = ""
var weapon_sfx_event: String = "swing"


func damage_taken_multiplier() -> float:
	return 100.0 / (100.0 + maxf(0.0, armor))
