class_name AffixRoll
extends Resource

@export var kind: GameEnums.AffixKind = GameEnums.AffixKind.CLEAVE_SIZE
@export var value: float = 0.0


func _init(p_kind: GameEnums.AffixKind = GameEnums.AffixKind.CLEAVE_SIZE, p_value: float = 0.0) -> void:
	kind = p_kind
	value = p_value


func format_line() -> String:
	match kind:
		GameEnums.AffixKind.CLEAVE_SIZE:
			return "+%d%% Cleave Area" % roundi(value * 100.0)
		GameEnums.AffixKind.SPARK_BURN:
			return "+%d Spark Burn DPS" % roundi(value)
		GameEnums.AffixKind.CHAIN_COUNT:
			var n := maxi(1, roundi(value))
			return "+%d Chain Target%s" % [n, "" if n == 1 else "s"]
		GameEnums.AffixKind.LIFE_ON_HIT:
			return "+%d Life on Hit" % roundi(value)
		GameEnums.AffixKind.COOLDOWN_HASTE:
			return "+%d%% Cooldown Haste" % roundi(value * 100.0)
		GameEnums.AffixKind.CRIT_SHOCKWAVE:
			return "+%d Crit Shockwave Damage" % roundi(value)
		GameEnums.AffixKind.MOVE_SPEED:
			return "+%d%% Move Speed" % roundi(value * 100.0)
		GameEnums.AffixKind.WARD_ON_DASH:
			return "+%d Ward on Dash" % roundi(value)
	return "+%.1f" % value


func to_dict() -> Dictionary:
	return {
		"kind": int(kind),
		"value": value,
	}


static func from_dict(d: Dictionary) -> AffixRoll:
	var raw_kind := clampi(int(d.get("kind", 0)), 0, GameEnums.AffixKind.size() - 1)
	return AffixRoll.new(raw_kind as GameEnums.AffixKind, float(d.get("value", 0.0)))
