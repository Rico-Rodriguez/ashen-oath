class_name LootEngine
extends RefCounted

static var _uid_seq: int = 0


static func next_uid(rng: RandomNumberGenerator = null) -> String:
	_uid_seq += 1
	var suffix := rng.randi() if rng != null else randi()
	return "itm_%d_%08x" % [_uid_seq, suffix & 0x7fffffff]


static func forge_cost(tier: int) -> Dictionary:
	match clampi(tier, 1, 4):
		1:
			return {"gold": 60, "scrap": 12}
		2:
			return {"gold": 140, "scrap": 28}
		3:
			return {"gold": 280, "scrap": 55}
		4:
			return {"gold": 500, "scrap": 95}
	return {"gold": 60, "scrap": 12}


static func roll_item(
	rng: RandomNumberGenerator,
	max_tier: int,
	difficulty: GameEnums.Difficulty = GameEnums.Difficulty.NORMAL,
	preferred_weapons: Array = [],
	guaranteed_min_rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
) -> EquipmentItem:
	var gen := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		gen.randomize()

	var cap_tier := clampi(max_tier, 1, 4)
	var tier := _roll_tier(gen, cap_tier, difficulty)
	var rarity := _roll_rarity(gen, difficulty, guaranteed_min_rarity)
	var slot := _roll_slot(gen)

	var item := EquipmentItem.new()
	item.uid = next_uid(gen)
	item.slot = slot
	item.tier = tier
	item.rarity = rarity
	item.temper_level = 0

	match slot:
		GameEnums.Slot.WEAPON:
			var wtype := _pick_weapon_type(gen, preferred_weapons)
			var wdef := GameRegistry.get_weapon_by_type_and_tier(wtype, tier)
			item.weapon_type = wtype
			item.base_id = wdef.weapon_id
			item.has_plume = false
		GameEnums.Slot.HELM:
			item.base_id = "helm_t%d" % tier
			if tier <= 1:
				item.has_plume = false
			elif tier >= 4:
				item.has_plume = true
			else:
				item.has_plume = gen.randf() < (0.65 if tier == 2 else 0.85)
		GameEnums.Slot.CUIRASS:
			item.base_id = "cuirass_t%d" % tier
			item.has_plume = false
		GameEnums.Slot.LANTERN:
			item.base_id = "lantern_t%d" % tier
			item.lantern_aspect = gen.randi_range(0, GameEnums.LanternAspect.size() - 1) as GameEnums.LanternAspect
			item.has_plume = false

	item.affixes = _roll_affixes(gen, tier, GameEnums.affix_count_for_rarity(rarity))
	return item


static func forge_item(
	rng: RandomNumberGenerator,
	slot: GameEnums.Slot,
	tier: int,
	weapon_type: GameEnums.WeaponType = GameEnums.WeaponType.GREATSWORD
) -> EquipmentItem:
	var gen := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		gen.randomize()

	var clamped_tier := clampi(tier, 1, 4)
	var rarity := _roll_rarity(gen, GameEnums.Difficulty.VETERAN, GameEnums.Rarity.RARE)

	var item := EquipmentItem.new()
	item.uid = next_uid(gen)
	item.slot = slot
	item.tier = clamped_tier
	item.rarity = rarity
	item.temper_level = 0

	match slot:
		GameEnums.Slot.WEAPON:
			var wdef := GameRegistry.get_weapon_by_type_and_tier(weapon_type, clamped_tier)
			item.weapon_type = weapon_type
			item.base_id = wdef.weapon_id
			item.has_plume = false
		GameEnums.Slot.HELM:
			item.base_id = "helm_t%d" % clamped_tier
			item.has_plume = clamped_tier >= 2
		GameEnums.Slot.CUIRASS:
			item.base_id = "cuirass_t%d" % clamped_tier
			item.has_plume = false
		GameEnums.Slot.LANTERN:
			item.base_id = "lantern_t%d" % clamped_tier
			item.lantern_aspect = gen.randi_range(0, GameEnums.LanternAspect.size() - 1) as GameEnums.LanternAspect
			item.has_plume = false

	item.affixes = _roll_affixes(gen, clamped_tier, GameEnums.affix_count_for_rarity(rarity))
	return item


static func make_starter_item(
	slot: GameEnums.Slot,
	hero_def: HeroClassDef,
	rng: RandomNumberGenerator = null
) -> EquipmentItem:
	var item := EquipmentItem.new()
	item.uid = next_uid(rng)
	item.slot = slot
	item.tier = 1
	item.rarity = GameEnums.Rarity.COMMON
	item.temper_level = 0
	item.has_plume = false
	item.affixes = []
	match slot:
		GameEnums.Slot.WEAPON:
			var wdef := GameRegistry.get_weapon(hero_def.starter_weapon_id)
			if wdef == null:
				wdef = GameRegistry.get_weapon("zweihander_t1")
			item.base_id = wdef.weapon_id
			item.weapon_type = wdef.weapon_type
		GameEnums.Slot.HELM:
			item.base_id = "helm_t1"
		GameEnums.Slot.CUIRASS:
			item.base_id = "cuirass_t1"
		GameEnums.Slot.LANTERN:
			item.base_id = "lantern_t1"
			item.lantern_aspect = hero_def.starter_lantern
	return item


static func compute_combat_stats(
	hero_def: HeroClassDef,
	equipped: Dictionary,
	active_blessings: Array = []
) -> CombatStats:
	var stats := CombatStats.new()
	var resolved_hero := hero_def if hero_def != null else GameRegistry.get_class_def("oathbreaker")

	var base_hp := resolved_hero.base_hp
	var armor := resolved_hero.base_armor
	var base_move_speed := resolved_hero.base_move_speed
	var crit_chance := resolved_hero.base_crit
	var crit_mult := 1.75
	var move_speed_mult_bonus := 0.0
	var cooldown_haste_total := 0.0

	var weapon_item := _extract_slot_item(equipped, GameEnums.Slot.WEAPON)
	var helm_item := _extract_slot_item(equipped, GameEnums.Slot.HELM)
	var cuirass_item := _extract_slot_item(equipped, GameEnums.Slot.CUIRASS)
	var lantern_item := _extract_slot_item(equipped, GameEnums.Slot.LANTERN)

	var wdef: WeaponDef = null
	var w_mult := 1.0
	if weapon_item != null:
		w_mult = weapon_item.temper_multiplier()
		wdef = GameRegistry.get_weapon(weapon_item.base_id)
		if wdef == null:
			wdef = GameRegistry.get_weapon_by_type_and_tier(weapon_item.weapon_type, weapon_item.tier)
	if wdef == null:
		wdef = GameRegistry.get_weapon(resolved_hero.starter_weapon_id)

	stats.attack_damage = wdef.base_damage * w_mult
	stats.attack_interval = wdef.attack_interval
	stats.attack_range = wdef.range_m
	stats.cleave_arc_deg = wdef.cleave_arc_deg
	stats.is_ranged = wdef.is_ranged
	stats.projectile_speed = wdef.projectile_speed
	stats.drags_on_ground = wdef.drags_on_ground
	stats.weapon_mesh_key = wdef.mesh_key
	stats.offhand_mesh_key = wdef.offhand_key
	stats.weapon_vfx_profile = wdef.vfx_profile
	stats.weapon_sfx_event = wdef.sfx_event
	armor += wdef.bonus_armor * w_mult

	if helm_item != null:
		var h_mult := helm_item.temper_multiplier()
		var h_stats := GameRegistry.helm_stats(helm_item.tier)
		armor += float(h_stats["armor"]) * h_mult
		base_hp += float(h_stats["hp"]) * h_mult
		stats.helm_tier = clampi(helm_item.tier, 1, 4)
		stats.has_plume = helm_item.has_plume
	else:
		stats.helm_tier = 0
		stats.has_plume = false

	if cuirass_item != null:
		var c_mult := cuirass_item.temper_multiplier()
		var c_stats := GameRegistry.cuirass_stats(cuirass_item.tier)
		armor += float(c_stats["armor"]) * c_mult
		base_hp += float(c_stats["hp"]) * c_mult
		stats.armor_tier = clampi(cuirass_item.tier, 1, 4)
	else:
		stats.armor_tier = 0

	if lantern_item != null:
		var l_mult := lantern_item.temper_multiplier()
		var l_tier := float(clampi(lantern_item.tier, 1, 4))
		stats.lantern_aspect = lantern_item.lantern_aspect
		stats.lantern_color = GameEnums.lantern_color(lantern_item.lantern_aspect)
		match lantern_item.lantern_aspect:
			GameEnums.LanternAspect.EMBER_GOLD:
				stats.lantern_aura_dps += (8.0 + 7.0 * l_tier) * l_mult
			GameEnums.LanternAspect.SOUL_BLUE:
				cooldown_haste_total += (0.06 + 0.04 * l_tier) * l_mult
			GameEnums.LanternAspect.BLIGHT_GREEN:
				stats.life_on_hit += (2.5 + 3.0 * l_tier) * l_mult
			GameEnums.LanternAspect.BLOOD_CRIMSON:
				crit_chance += (0.03 + 0.02 * l_tier) * l_mult
				crit_mult += (0.12 + 0.08 * l_tier) * l_mult
	else:
		stats.lantern_aspect = resolved_hero.starter_lantern
		stats.lantern_color = GameEnums.lantern_color(resolved_hero.starter_lantern)

	var items_list: Array[EquipmentItem] = [weapon_item, helm_item, cuirass_item, lantern_item]
	for item in items_list:
		if item == null:
			continue
		var t_mult := item.temper_multiplier()
		for affix in item.affixes:
			if affix == null:
				continue
			match affix.kind:
				GameEnums.AffixKind.CLEAVE_SIZE:
					stats.cleave_size_mult += affix.value * t_mult
				GameEnums.AffixKind.SPARK_BURN:
					stats.spark_burn_dps += affix.value * t_mult
				GameEnums.AffixKind.CHAIN_COUNT:
					stats.chain_bonus_targets += maxi(1, roundi(affix.value))
				GameEnums.AffixKind.LIFE_ON_HIT:
					stats.life_on_hit += affix.value * t_mult
				GameEnums.AffixKind.COOLDOWN_HASTE:
					cooldown_haste_total += affix.value * t_mult
				GameEnums.AffixKind.CRIT_SHOCKWAVE:
					stats.crit_shockwave_damage += affix.value * t_mult
				GameEnums.AffixKind.MOVE_SPEED:
					move_speed_mult_bonus += affix.value * t_mult
				GameEnums.AffixKind.WARD_ON_DASH:
					stats.ward_on_dash_hp += affix.value * t_mult

	var damage_mult_bonus := 0.0
	var attack_speed_bonus := 0.0
	var hp_mult_bonus := 0.0
	for b_entry in active_blessings:
		var bdef := GameRegistry.get_blessing(str(b_entry))
		if bdef == null:
			continue
		damage_mult_bonus += bdef.damage_mult_bonus
		attack_speed_bonus += bdef.attack_speed_bonus
		hp_mult_bonus += bdef.max_hp_mult_bonus
		armor += bdef.armor_bonus
		move_speed_mult_bonus += bdef.move_speed_bonus
		crit_chance += bdef.crit_chance_bonus
		crit_mult += bdef.crit_mult_bonus
		stats.cleave_size_mult += bdef.cleave_size_bonus
		stats.spark_burn_dps += bdef.spark_burn_dps_bonus
		stats.chain_bonus_targets += bdef.chain_targets_bonus
		stats.life_on_hit += bdef.life_on_hit_bonus
		cooldown_haste_total += bdef.cooldown_haste_bonus
		stats.crit_shockwave_damage += bdef.crit_shockwave_bonus
		stats.ward_on_dash_hp += bdef.ward_on_dash_bonus
		stats.lantern_aura_dps += bdef.lantern_aura_dps_bonus

	stats.max_hp = maxf(1.0, base_hp * (1.0 + hp_mult_bonus))
	stats.armor = maxf(0.0, armor)
	stats.move_speed = maxf(1.5, base_move_speed * (1.0 + move_speed_mult_bonus))
	stats.attack_damage = maxf(1.0, stats.attack_damage * (1.0 + damage_mult_bonus))
	stats.attack_interval = maxf(0.18, stats.attack_interval / maxf(0.25, 1.0 + attack_speed_bonus))
	stats.crit_chance = clampf(crit_chance, 0.0, 0.95)
	stats.crit_mult = maxf(1.1, crit_mult)
	stats.cooldown_scale = clampf(1.0 / (1.0 + maxf(0.0, cooldown_haste_total)), 0.30, 1.0)
	return stats


static func _extract_slot_item(equipped: Dictionary, slot: GameEnums.Slot) -> EquipmentItem:
	return equipped.get(slot) as EquipmentItem


static func _roll_tier(rng: RandomNumberGenerator, cap_tier: int, difficulty: GameEnums.Difficulty) -> int:
	if cap_tier <= 1:
		return 1
	var roll := rng.randf()
	var top_chance := 0.52 + float(int(difficulty)) * 0.12
	if roll < top_chance:
		return cap_tier
	if roll < top_chance + 0.34 or cap_tier == 2:
		return maxi(1, cap_tier - 1)
	return maxi(1, cap_tier - 2)


static func _roll_rarity(
	rng: RandomNumberGenerator,
	difficulty: GameEnums.Difficulty,
	min_rarity: GameEnums.Rarity
) -> GameEnums.Rarity:
	var p := rng.randf()
	var rolled: GameEnums.Rarity = GameEnums.Rarity.COMMON
	match difficulty:
		GameEnums.Difficulty.NORMAL:
			if p < 0.04:
				rolled = GameEnums.Rarity.SOVEREIGN
			elif p < 0.18:
				rolled = GameEnums.Rarity.EPIC
			elif p < 0.52:
				rolled = GameEnums.Rarity.RARE
		GameEnums.Difficulty.VETERAN:
			if p < 0.09:
				rolled = GameEnums.Rarity.SOVEREIGN
			elif p < 0.30:
				rolled = GameEnums.Rarity.EPIC
			elif p < 0.70:
				rolled = GameEnums.Rarity.RARE
		GameEnums.Difficulty.NIGHTMARE:
			if p < 0.16:
				rolled = GameEnums.Rarity.SOVEREIGN
			elif p < 0.46:
				rolled = GameEnums.Rarity.EPIC
			elif p < 0.86:
				rolled = GameEnums.Rarity.RARE
	if int(rolled) < int(min_rarity):
		return min_rarity
	return rolled


static func _roll_slot(rng: RandomNumberGenerator) -> GameEnums.Slot:
	var p := rng.randf()
	if p < 0.30:
		return GameEnums.Slot.WEAPON
	if p < 0.54:
		return GameEnums.Slot.HELM
	if p < 0.78:
		return GameEnums.Slot.CUIRASS
	return GameEnums.Slot.LANTERN


static func _pick_weapon_type(rng: RandomNumberGenerator, preferred_weapons: Array) -> GameEnums.WeaponType:
	var valid: Array[GameEnums.WeaponType] = []
	for w in preferred_weapons:
		var idx := int(w)
		if idx >= 0 and idx < GameEnums.WeaponType.size():
			valid.append(idx as GameEnums.WeaponType)
	if not valid.is_empty():
		return valid[rng.randi_range(0, valid.size() - 1)]
	return rng.randi_range(0, GameEnums.WeaponType.size() - 1) as GameEnums.WeaponType


static func _roll_affixes(rng: RandomNumberGenerator, tier: int, count: int) -> Array[AffixRoll]:
	var out: Array[AffixRoll] = []
	if count <= 0:
		return out
	var pool: Array[GameEnums.AffixKind] = [
		GameEnums.AffixKind.CLEAVE_SIZE,
		GameEnums.AffixKind.SPARK_BURN,
		GameEnums.AffixKind.CHAIN_COUNT,
		GameEnums.AffixKind.LIFE_ON_HIT,
		GameEnums.AffixKind.COOLDOWN_HASTE,
		GameEnums.AffixKind.CRIT_SHOCKWAVE,
		GameEnums.AffixKind.MOVE_SPEED,
		GameEnums.AffixKind.WARD_ON_DASH,
	]
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var take := mini(count, pool.size())
	var t := float(clampi(tier, 1, 4))
	for i in range(take):
		var kind := pool[i]
		out.append(AffixRoll.new(kind, _roll_affix_value(rng, kind, t)))
	return out


static func _roll_affix_value(rng: RandomNumberGenerator, kind: GameEnums.AffixKind, tier_f: float) -> float:
	match kind:
		GameEnums.AffixKind.CLEAVE_SIZE:
			return snappedf(rng.randf_range(0.08 + 0.04 * tier_f, 0.14 + 0.06 * tier_f), 0.01)
		GameEnums.AffixKind.SPARK_BURN:
			return float(roundi(rng.randf_range(5.0 + 5.0 * tier_f, 9.0 + 8.0 * tier_f)))
		GameEnums.AffixKind.CHAIN_COUNT:
			var max_chains := 1 if tier_f <= 1.0 else (2 if tier_f <= 3.0 else 3)
			return float(rng.randi_range(1, max_chains))
		GameEnums.AffixKind.LIFE_ON_HIT:
			return float(roundi(rng.randf_range(2.0 + 2.0 * tier_f, 4.0 + 3.5 * tier_f)))
		GameEnums.AffixKind.COOLDOWN_HASTE:
			return snappedf(rng.randf_range(0.06 + 0.03 * tier_f, 0.10 + 0.045 * tier_f), 0.01)
		GameEnums.AffixKind.CRIT_SHOCKWAVE:
			return float(roundi(rng.randf_range(12.0 + 10.0 * tier_f, 20.0 + 18.0 * tier_f)))
		GameEnums.AffixKind.MOVE_SPEED:
			return snappedf(rng.randf_range(0.04 + 0.025 * tier_f, 0.07 + 0.035 * tier_f), 0.01)
		GameEnums.AffixKind.WARD_ON_DASH:
			return float(roundi(rng.randf_range(10.0 + 8.0 * tier_f, 16.0 + 14.0 * tier_f)))
	return 1.0
