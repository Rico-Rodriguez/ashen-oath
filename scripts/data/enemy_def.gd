class_name EnemyDef
extends Resource

@export var enemy_id: String = ""
@export var display_name: String = ""
@export var title: String = ""
@export var is_boss: bool = false
@export var archetype: GameEnums.EnemyArchetype = GameEnums.EnemyArchetype.SWARMER
@export var actor_scene_path: String = ""
@export var portrait_path: String = ""
@export var max_hp: float = 60.0
@export var move_speed: float = 4.0
@export var damage: float = 12.0
@export var attack_range: float = 1.8
@export var windup_sec: float = 0.45
@export var recovery_sec: float = 0.55
@export var scale_m: float = 1.0
@export var xp_value: int = 10
@export var gold_drop: int = 5
