class_name DamageEvent
extends RefCounted

enum Team {
	HERO,
	ENEMY,
}

enum Kind {
	PHYSICAL,
	FIRE,
	LIGHTNING,
	BLEED,
	SHADOW,
	RADIANT,
}

var raw_damage: float = 0.0
var final_damage: float = 0.0
var absorbed_ward: float = 0.0
var is_crit: bool = false
var is_dot: bool = false
var negated_by_iframe: bool = false
var triggers_on_hit: bool = true
var team: Team = Team.HERO
var kind: Kind = Kind.PHYSICAL
var source_id: String = ""
var attacker: Node3D = null
var hit_position: Vector3 = Vector3.ZERO
var stagger_sec: float = 0.0
var knockback_impulse: Vector3 = Vector3.ZERO
var burn_dps: float = 0.0
var burn_duration: float = 0.0
var bleed_dps: float = 0.0
var bleed_duration: float = 0.0
var life_on_hit: float = 0.0


static func make_hero_hit(
	p_attacker: Node3D,
	p_raw_damage: float,
	p_source_id: String,
	p_kind: Kind = Kind.PHYSICAL,
	p_is_crit: bool = false
) -> DamageEvent:
	var ev := DamageEvent.new()
	ev.team = Team.HERO
	ev.attacker = p_attacker
	ev.raw_damage = p_raw_damage
	ev.final_damage = p_raw_damage
	ev.source_id = p_source_id
	ev.kind = p_kind
	ev.is_crit = p_is_crit
	return ev


static func make_enemy_hit(
	p_attacker: Node3D,
	p_raw_damage: float,
	p_source_id: String,
	p_kind: Kind = Kind.PHYSICAL
) -> DamageEvent:
	var ev := DamageEvent.new()
	ev.team = Team.ENEMY
	ev.attacker = p_attacker
	ev.raw_damage = p_raw_damage
	ev.final_damage = p_raw_damage
	ev.source_id = p_source_id
	ev.kind = p_kind
	return ev
