class_name ZoneDef
extends Resource

@export var zone_id: String = ""
@export var depth_index: int = 0
@export var display_name: String = ""
@export var subtitle: String = ""
@export var recommended_power: int = 120
@export var enemy_pool: Array[String] = []
@export var elite_id: String = ""
@export var boss_id: String = ""
@export var fog_color: Color = Color(0.08, 0.09, 0.12, 1.0)
@export var ambient_color: Color = Color(0.24, 0.26, 0.32, 1.0)
@export var ground_tint: Color = Color(0.25, 0.24, 0.22, 1.0)
@export var max_drop_tier: int = 1
