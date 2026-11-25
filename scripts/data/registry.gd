class_name GameRegistry
extends RefCounted

const CLASS_ORDER: Array[String] = ["oathbreaker", "battlemage", "revenant"]
const ZONE_ORDER: Array[String] = ["fringe", "weald", "catacombs", "rift"]

static var _initialized: bool = false
static var _classes: Dictionary = {}
static var _weapons: Dictionary = {}
static var _weapon_order: Array[String] = []
static var _enemies: Dictionary = {}
static var _enemy_order: Array[String] = []
static var _zones: Dictionary = {}
static var _blessings: Dictionary = {}
static var _blessing_order: Array[String] = []


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_build_weapons()
	_build_classes()
	_build_enemies()
	_build_zones()
	_build_blessings()


static func _make_ability(
	id: String,
	title: String,
	desc: String,
	cd: float,
	dmg_mult: float,
	radius: float,
	rng_m: float,
	dur: float,
	vfx: String,
	sfx: String,
	anim: String,
	projectiles: int = 1
) -> AbilityDef:
	var a := AbilityDef.new()
	a.ability_id = id
	a.display_name = title
	a.description = desc
	a.cooldown_sec = cd
	a.damage_mult = dmg_mult
	a.radius_m = radius
	a.range_m = rng_m
	a.duration_sec = dur
	a.vfx_id = vfx
	a.sfx_event = sfx
	a.anim_clip = anim
	a.projectile_count = projectiles
	return a


static func _register_weapon(
	id: String,
	title: String,
	wtype: GameEnums.WeaponType,
	tier: int,
	mesh: String,
	offhand: String,
	drags: bool,
	dmg: float,
	interval: float,
	rng_m: float,
	arc_deg: float,
	ranged: bool,
	proj_spd: float,
	vfx: String,
	sfx: String,
	armor_bonus: float = 0.0
) -> void:
	var w := WeaponDef.new()
	w.weapon_id = id
	w.display_name = title
	w.weapon_type = wtype
	w.tier = tier
	w.mesh_key = mesh
	w.offhand_key = offhand
	w.drags_on_ground = drags
	w.base_damage = dmg
	w.attack_interval = interval
	w.range_m = rng_m
	w.cleave_arc_deg = arc_deg
	w.is_ranged = ranged
	w.projectile_speed = proj_spd
	w.vfx_profile = vfx
	w.sfx_event = sfx
	w.bonus_armor = armor_bonus
	_weapons[id] = w
	_weapon_order.append(id)


static func _build_weapons() -> void:
	_register_weapon("zweihander_t1", "Iron Zweihander", GameEnums.WeaponType.GREATSWORD, 1, "zweihander", "", true, 34.0, 0.86, 2.9, 150.0, false, 0.0, "heavy_sparks", "atk_tank")
	_register_weapon("zweihander_t2", "Blackened Claymore", GameEnums.WeaponType.GREATSWORD, 2, "zweihander", "", true, 49.0, 0.84, 3.0, 150.0, false, 0.0, "heavy_sparks", "atk_tank")
	_register_weapon("zweihander_t3", "Sovereign Greatsword", GameEnums.WeaponType.GREATSWORD, 3, "zweihander", "", true, 68.0, 0.82, 3.1, 150.0, false, 0.0, "heavy_sparks", "atk_tank")
	_register_weapon("zweihander_t4", "Oarimaar Cursed Greatsword", GameEnums.WeaponType.GREATSWORD, 4, "blade_oarimaar", "", true, 92.0, 0.80, 3.2, 150.0, false, 0.0, "cursed_ember_arc", "atk_tank")

	_register_weapon("halberd_t1", "Watchman Poleaxe", GameEnums.WeaponType.HALBERD, 1, "halberd", "", true, 29.0, 0.76, 3.4, 125.0, false, 0.0, "crescent_sparks", "cleave")
	_register_weapon("halberd_t2", "Ravensbeak Halberd", GameEnums.WeaponType.HALBERD, 2, "halberd", "", true, 42.0, 0.74, 3.4, 125.0, false, 0.0, "crescent_sparks", "cleave")
	_register_weapon("halberd_t3", "Gilded Glaive", GameEnums.WeaponType.HALBERD, 3, "halberd", "", true, 58.0, 0.72, 3.4, 125.0, false, 0.0, "crescent_sparks", "cleave")
	_register_weapon("halberd_t4", "Barrows Dread-Halberd", GameEnums.WeaponType.HALBERD, 4, "halberd", "", true, 79.0, 0.70, 3.4, 125.0, false, 0.0, "wraith_crescent", "cleave")

	_register_weapon("sword_shield_t1", "Squire Arming Sword", GameEnums.WeaponType.SWORD_SHIELD, 1, "bastardsword", "shield_round", false, 19.0, 0.48, 2.25, 105.0, false, 0.0, "steel_slash", "swing", 14.0)
	_register_weapon("sword_shield_t2", "Knightly Bastard Sword", GameEnums.WeaponType.SWORD_SHIELD, 2, "bastardsword", "shield_heater", false, 27.0, 0.48, 2.30, 105.0, false, 0.0, "steel_slash", "swing", 24.0)
	_register_weapon("sword_shield_t3", "Sovereign Broadsword", GameEnums.WeaponType.SWORD_SHIELD, 3, "bastardsword", "shield_tower", false, 38.0, 0.48, 2.35, 105.0, false, 0.0, "steel_slash", "swing", 36.0)
	_register_weapon("sword_shield_t4", "Ashen Oathblade", GameEnums.WeaponType.SWORD_SHIELD, 4, "bastardsword", "shield_tower", false, 52.0, 0.48, 2.40, 105.0, false, 0.0, "oath_slash", "swing", 50.0)

	_register_weapon("staff_t1", "Ashwood Censer Staff", GameEnums.WeaponType.WAR_STAFF, 1, "runed_staff", "", false, 23.0, 0.62, 8.8, 45.0, true, 16.5, "blackflame_bolt", "atk_mage")
	_register_weapon("staff_t2", "Blackiron Spire Staff", GameEnums.WeaponType.WAR_STAFF, 2, "runed_staff", "", false, 33.0, 0.60, 9.0, 45.0, true, 17.5, "blackflame_bolt", "atk_mage")
	_register_weapon("staff_t3", "Sovereign Storm Staff", GameEnums.WeaponType.WAR_STAFF, 3, "runed_staff", "", false, 46.0, 0.58, 9.2, 45.0, true, 18.5, "blackflame_bolt", "atk_mage")
	_register_weapon("staff_t4", "Voidpyre Staff", GameEnums.WeaponType.WAR_STAFF, 4, "runed_staff", "", false, 64.0, 0.55, 9.5, 45.0, true, 19.5, "voidpyre_bolt", "atk_mage")


static func _build_classes() -> void:
	var oath := HeroClassDef.new()
	oath.class_id = "oathbreaker"
	oath.display_name = "Oathbreaker Knight"
	oath.subtitle = "Greatsword & Bulwark"
	oath.lore = "Sworn once to the Sovereign throne, now dragging notched barrows-iron through the ash to sever the Undying Pact."
	oath.actor_scene_path = "res://scenes/actors/heroes/oathbreaker.tscn"
	oath.portrait_path = "res://assets/sprites/ui/portraits/oathbreaker.png"
	oath.base_hp = 260.0
	oath.base_armor = 28.0
	oath.base_move_speed = 5.4
	oath.base_crit = 0.08
	oath.allowed_weapons = [
		GameEnums.WeaponType.GREATSWORD,
		GameEnums.WeaponType.HALBERD,
		GameEnums.WeaponType.SWORD_SHIELD,
	]
	oath.starter_weapon_id = "zweihander_t1"
	oath.starter_lantern = GameEnums.LanternAspect.EMBER_GOLD
	oath.skill_1 = _make_ability(
		"iron_tempest",
		"Iron Tempest",
		"Whirling dragging blade storm throwing sparks across nearby foes.",
		7.0, 2.1, 3.6, 3.6, 1.6,
		"iron_tempest", "blades", "skill_whirl"
	)
	oath.skill_2 = _make_ability(
		"bulwark_charge",
		"Bulwark Charge",
		"Armored dash-slam that shatters enemy ranks with a shockwave.",
		9.0, 2.6, 3.2, 6.5, 0.45,
		"bulwark_charge", "charge_land", "skill_slam"
	)
	oath.dash_ability = _make_ability(
		"iron_roll",
		"Iron Roll",
		"Heavy shoulder-roll through enemy strikes.",
		3.2, 0.0, 1.5, 4.6, 0.32,
		"dash_dust", "dodge", "dash"
	)
	_classes[oath.class_id] = oath

	var mage := HeroClassDef.new()
	mage.class_id = "battlemage"
	mage.display_name = "Ashen Battlemage"
	mage.subtitle = "Blackflame & Storm"
	mage.lore = "Censer-bearer of the Obsidian Conclave who channels smokey blackflame and jagged stormbrands through runed iron staves."
	mage.actor_scene_path = "res://scenes/actors/heroes/battlemage.tscn"
	mage.portrait_path = "res://assets/sprites/ui/portraits/battlemage.png"
	mage.base_hp = 195.0
	mage.base_armor = 14.0
	mage.base_move_speed = 5.7
	mage.base_crit = 0.11
	mage.allowed_weapons = [
		GameEnums.WeaponType.WAR_STAFF,
		GameEnums.WeaponType.SWORD_SHIELD,
	]
	mage.starter_weapon_id = "staff_t1"
	mage.starter_lantern = GameEnums.LanternAspect.SOUL_BLUE
	mage.skill_1 = _make_ability(
		"blackflame_pyre",
		"Blackflame Pyre",
		"Erupting smokey black-flame pillar that scorches everything inside the ring.",
		6.5, 2.5, 3.5, 8.0, 1.8,
		"blackflame_pyre", "meteor", "skill_cast"
	)
	mage.skill_2 = _make_ability(
		"stormbrand_arc",
		"Stormbrand Arc",
		"Jagged chain lightning arcing across clustered foes.",
		8.0, 2.2, 5.0, 9.0, 0.35,
		"stormbrand_arc", "thunder", "skill_arc", 4
	)
	mage.dash_ability = _make_ability(
		"phase_blink",
		"Phase Blink",
		"Dissolve in cinders and reappear yards away.",
		3.0, 0.0, 1.8, 5.4, 0.22,
		"blink_cinder", "blink", "dash"
	)
	_classes[mage.class_id] = mage

	var rev := HeroClassDef.new()
	rev.class_id = "revenant"
	rev.display_name = "Dread Revenant"
	rev.subtitle = "Poleaxe & Wraithblade"
	rev.lore = "Risen warden of the Weald watches, reaping ranks with long-reach halberds and spectral barrow lances."
	rev.actor_scene_path = "res://scenes/actors/heroes/revenant.tscn"
	rev.portrait_path = "res://assets/sprites/ui/portraits/revenant.png"
	rev.base_hp = 225.0
	rev.base_armor = 20.0
	rev.base_move_speed = 5.85
	rev.base_crit = 0.13
	rev.allowed_weapons = [
		GameEnums.WeaponType.HALBERD,
		GameEnums.WeaponType.GREATSWORD,
		GameEnums.WeaponType.SWORD_SHIELD,
	]
	rev.starter_weapon_id = "halberd_t1"
	rev.starter_lantern = GameEnums.LanternAspect.BLOOD_CRIMSON
	rev.skill_1 = _make_ability(
		"reaping_sweep",
		"Reaping Sweep",
		"Wide crescent polearm cleave that carves the front arc.",
		5.8, 2.35, 4.0, 4.0, 0.5,
		"reaping_sweep", "cleave", "skill_cleave"
	)
	rev.skill_2 = _make_ability(
		"wraith_lances",
		"Wraith Lances",
		"Unleash a fan of 5 piercing spectral lances.",
		7.5, 1.95, 2.4, 9.5, 0.4,
		"wraith_lances", "volley", "skill_thrust", 5
	)
	rev.dash_ability = _make_ability(
		"shadow_step",
		"Shadow Step",
		"Phantom lunge that slips cleanly past enemy bodies.",
		2.8, 0.0, 1.6, 5.2, 0.25,
		"shadow_step", "dodge", "dash"
	)
	_classes[rev.class_id] = rev


static func _register_enemy(
	id: String,
	title_name: String,
	sub: String,
	boss: bool,
	arch: GameEnums.EnemyArchetype,
	hp: float,
	spd: float,
	dmg: float,
	rng_m: float,
	windup: float,
	recovery: float,
	scale_val: float,
	xp: int,
	gold: int
) -> void:
	var e := EnemyDef.new()
	e.enemy_id = id
	e.display_name = title_name
	e.title = sub
	e.is_boss = boss
	e.archetype = arch
	e.actor_scene_path = "res://scenes/actors/enemies/%s.tscn" % id
	e.portrait_path = "res://assets/sprites/ui/portraits/%s.png" % id
	e.max_hp = hp
	e.move_speed = spd
	e.damage = dmg
	e.attack_range = rng_m
	e.windup_sec = windup
	e.recovery_sec = recovery
	e.scale_m = scale_val
	e.xp_value = xp
	e.gold_drop = gold
	_enemies[id] = e
	_enemy_order.append(id)


static func _build_enemies() -> void:
	_register_enemy("hollow_ghoul", "Hollow Ghoul", "Risen Grave-Feeder", false, GameEnums.EnemyArchetype.SWARMER, 58.0, 4.4, 12.0, 1.65, 0.35, 0.45, 1.0, 10, 4)
	_register_enemy("crypt_batlord", "Crypt Batlord", "Bloodwing Screecher", false, GameEnums.EnemyArchetype.RANGED, 48.0, 4.1, 14.0, 7.2, 0.45, 0.65, 1.05, 13, 6)
	_register_enemy("ash_scorpion", "Ash Scorpion", "Cinderback Skitterer", false, GameEnums.EnemyArchetype.CHARGER, 82.0, 5.2, 18.0, 2.2, 0.42, 0.55, 1.15, 16, 8)
	_register_enemy("stone_gargoyle", "Stone Gargoyle", "Carved Bastion Sentinel", false, GameEnums.EnemyArchetype.BRUISER, 145.0, 3.2, 24.0, 2.4, 0.58, 0.72, 1.35, 24, 12)

	_register_enemy("barrow_troll", "Gravemaw, Barrow Troll", "Warden of the Fringe", true, GameEnums.EnemyArchetype.BOSS, 920.0, 3.4, 34.0, 3.2, 0.72, 0.85, 2.1, 140, 65)
	_register_enemy("blight_werewolf", "Nightmaw, Blight Stalker", "Terror of the Weald", true, GameEnums.EnemyArchetype.BOSS, 1480.0, 4.8, 44.0, 2.9, 0.52, 0.68, 1.95, 210, 105)
	_register_enemy("dread_golem", "Obsidian Warden", "Sentinel of the Catacombs", true, GameEnums.EnemyArchetype.BOSS, 2350.0, 3.1, 58.0, 3.5, 0.80, 0.90, 2.35, 310, 160)
	_register_enemy("infernal_minotaur", "Khorvath, Ashen Bull", "Sovereign of the Rift", true, GameEnums.EnemyArchetype.BOSS, 3400.0, 4.3, 74.0, 3.6, 0.64, 0.76, 2.5, 450, 240)


static func _build_zones() -> void:
	var z0 := ZoneDef.new()
	z0.zone_id = "fringe"
	z0.depth_index = 0
	z0.display_name = "Barrow Fringe"
	z0.subtitle = "Fog-bound cairns & shattered watchstones"
	z0.recommended_power = 120
	z0.enemy_pool = ["hollow_ghoul", "crypt_batlord"]
	z0.elite_id = "stone_gargoyle"
	z0.boss_id = "barrow_troll"
	z0.fog_color = Color(0.09, 0.11, 0.14, 1.0)
	z0.ambient_color = Color(0.26, 0.30, 0.36, 1.0)
	z0.ground_tint = Color(0.28, 0.27, 0.25, 1.0)
	z0.max_drop_tier = 1
	_zones[z0.zone_id] = z0

	var z1 := ZoneDef.new()
	z1.zone_id = "weald"
	z1.depth_index = 1
	z1.display_name = "Blighted Weald"
	z1.subtitle = "Rot-choked roots & gallows mire"
	z1.recommended_power = 280
	z1.enemy_pool = ["hollow_ghoul", "crypt_batlord", "ash_scorpion"]
	z1.elite_id = "ash_scorpion"
	z1.boss_id = "blight_werewolf"
	z1.fog_color = Color(0.07, 0.12, 0.09, 1.0)
	z1.ambient_color = Color(0.22, 0.32, 0.25, 1.0)
	z1.ground_tint = Color(0.21, 0.25, 0.19, 1.0)
	z1.max_drop_tier = 2
	_zones[z1.zone_id] = z1

	var z2 := ZoneDef.new()
	z2.zone_id = "catacombs"
	z2.depth_index = 2
	z2.display_name = "Sovereign Catacombs"
	z2.subtitle = "Gilded ossuaries & blackiron vaults"
	z2.recommended_power = 480
	z2.enemy_pool = ["crypt_batlord", "ash_scorpion", "stone_gargoyle"]
	z2.elite_id = "stone_gargoyle"
	z2.boss_id = "dread_golem"
	z2.fog_color = Color(0.08, 0.08, 0.13, 1.0)
	z2.ambient_color = Color(0.25, 0.24, 0.35, 1.0)
	z2.ground_tint = Color(0.23, 0.22, 0.26, 1.0)
	z2.max_drop_tier = 3
	_zones[z2.zone_id] = z2

	var z3 := ZoneDef.new()
	z3.zone_id = "rift"
	z3.depth_index = 3
	z3.display_name = "Ashen Rift"
	z3.subtitle = "Cinder chasm of the Broken Oath"
	z3.recommended_power = 720
	z3.enemy_pool = ["hollow_ghoul", "crypt_batlord", "ash_scorpion", "stone_gargoyle"]
	z3.elite_id = "stone_gargoyle"
	z3.boss_id = "infernal_minotaur"
	z3.fog_color = Color(0.14, 0.06, 0.05, 1.0)
	z3.ambient_color = Color(0.38, 0.20, 0.16, 1.0)
	z3.ground_tint = Color(0.26, 0.17, 0.15, 1.0)
	z3.max_drop_tier = 4
	_zones[z3.zone_id] = z3


static func _build_blessings() -> void:
	var b1 := ShrineBlessingDef.new()
	b1.blessing_id = "cinder_covenant"
	b1.display_name = "Cinder Covenant"
	b1.description = "+22% Attack Damage and +18 Spark Burn DPS."
	b1.rarity = GameEnums.Rarity.RARE
	b1.damage_mult_bonus = 0.22
	b1.spark_burn_dps_bonus = 18.0
	_blessings[b1.blessing_id] = b1
	_blessing_order.append(b1.blessing_id)

	var b2 := ShrineBlessingDef.new()
	b2.blessing_id = "blood_tithe"
	b2.display_name = "Blood Tithe"
	b2.description = "+12 Life on Hit and +15% Attack Speed."
	b2.rarity = GameEnums.Rarity.RARE
	b2.life_on_hit_bonus = 12.0
	b2.attack_speed_bonus = 0.15
	_blessings[b2.blessing_id] = b2
	_blessing_order.append(b2.blessing_id)

	var b3 := ShrineBlessingDef.new()
	b3.blessing_id = "storm_conduit"
	b3.display_name = "Storm Conduit"
	b3.description = "+2 Chain Targets and +20% Cooldown Haste."
	b3.rarity = GameEnums.Rarity.EPIC
	b3.chain_targets_bonus = 2
	b3.cooldown_haste_bonus = 0.20
	_blessings[b3.blessing_id] = b3
	_blessing_order.append(b3.blessing_id)

	var b4 := ShrineBlessingDef.new()
	b4.blessing_id = "iron_vow"
	b4.display_name = "Iron Vow"
	b4.description = "+35 Armor, +20% Max HP, and +35 Ward on Dash."
	b4.rarity = GameEnums.Rarity.RARE
	b4.armor_bonus = 35.0
	b4.max_hp_mult_bonus = 0.20
	b4.ward_on_dash_bonus = 35.0
	_blessings[b4.blessing_id] = b4
	_blessing_order.append(b4.blessing_id)

	var b5 := ShrineBlessingDef.new()
	b5.blessing_id = "reapers_reach"
	b5.display_name = "Reaper's Reach"
	b5.description = "+30% Cleave Area and +16% Move Speed."
	b5.rarity = GameEnums.Rarity.EPIC
	b5.cleave_size_bonus = 0.30
	b5.move_speed_bonus = 0.16
	_blessings[b5.blessing_id] = b5
	_blessing_order.append(b5.blessing_id)

	var b6 := ShrineBlessingDef.new()
	b6.blessing_id = "sovereign_wrath"
	b6.display_name = "Sovereign Wrath"
	b6.description = "+12% Crit Chance, +0.45x Crit Multiplier, and +55 Crit Shockwave Damage."
	b6.rarity = GameEnums.Rarity.SOVEREIGN
	b6.crit_chance_bonus = 0.12
	b6.crit_mult_bonus = 0.45
	b6.crit_shockwave_bonus = 55.0
	_blessings[b6.blessing_id] = b6
	_blessing_order.append(b6.blessing_id)


static func get_all_classes() -> Array[HeroClassDef]:
	_ensure_init()
	var out: Array[HeroClassDef] = []
	for cid in CLASS_ORDER:
		out.append(_classes[cid])
	return out


static func get_class_def(class_id: String) -> HeroClassDef:
	_ensure_init()
	return _classes.get(class_id)


static func get_all_weapons() -> Array[WeaponDef]:
	_ensure_init()
	var out: Array[WeaponDef] = []
	for wid in _weapon_order:
		out.append(_weapons[wid])
	return out


static func get_weapon(weapon_id: String) -> WeaponDef:
	_ensure_init()
	return _weapons.get(weapon_id)


static func get_weapon_by_type_and_tier(weapon_type: GameEnums.WeaponType, tier: int) -> WeaponDef:
	_ensure_init()
	var clamped_tier := clampi(tier, 1, 4)
	for wid in _weapon_order:
		var w: WeaponDef = _weapons[wid]
		if w.weapon_type == weapon_type and w.tier == clamped_tier:
			return w
	return _weapons["zweihander_t1"]


static func get_all_enemies() -> Array[EnemyDef]:
	_ensure_init()
	var out: Array[EnemyDef] = []
	for eid in _enemy_order:
		out.append(_enemies[eid])
	return out


static func get_regular_enemies() -> Array[EnemyDef]:
	_ensure_init()
	var out: Array[EnemyDef] = []
	for eid in _enemy_order:
		var e: EnemyDef = _enemies[eid]
		if not e.is_boss:
			out.append(e)
	return out


static func get_boss_enemies() -> Array[EnemyDef]:
	_ensure_init()
	var out: Array[EnemyDef] = []
	for eid in _enemy_order:
		var e: EnemyDef = _enemies[eid]
		if e.is_boss:
			out.append(e)
	return out


static func get_enemy(enemy_id: String) -> EnemyDef:
	_ensure_init()
	return _enemies.get(enemy_id)


static func get_all_zones() -> Array[ZoneDef]:
	_ensure_init()
	var out: Array[ZoneDef] = []
	for zid in ZONE_ORDER:
		out.append(_zones[zid])
	return out


static func get_zone(zone_id: String) -> ZoneDef:
	_ensure_init()
	return _zones.get(zone_id)


static func get_zone_by_depth(depth_index: int) -> ZoneDef:
	_ensure_init()
	var idx := clampi(depth_index, 0, ZONE_ORDER.size() - 1)
	return _zones[ZONE_ORDER[idx]]


static func get_all_blessings() -> Array[ShrineBlessingDef]:
	_ensure_init()
	var out: Array[ShrineBlessingDef] = []
	for bid in _blessing_order:
		out.append(_blessings[bid])
	return out


static func get_blessing(blessing_id: String) -> ShrineBlessingDef:
	_ensure_init()
	return _blessings.get(blessing_id)


static func roll_shrine_choices(rng: RandomNumberGenerator, count: int = 3, exclude_ids: Array = []) -> Array[ShrineBlessingDef]:
	_ensure_init()
	var gen := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		gen.randomize()
	var pool: Array[ShrineBlessingDef] = []
	for bid in _blessing_order:
		if not exclude_ids.has(bid):
			pool.append(_blessings[bid])
	if pool.is_empty():
		pool = get_all_blessings()
	for i in range(pool.size() - 1, 0, -1):
		var j := gen.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var take := mini(maxi(1, count), pool.size())
	var choices: Array[ShrineBlessingDef] = []
	for i in range(take):
		choices.append(pool[i])
	return choices


static func helm_stats(tier: int) -> Dictionary:
	var t := clampi(tier, 1, 4)
	var prefix := GameEnums.tier_prefix(t)
	match t:
		1:
			return {"name": "%s Helm" % prefix, "armor": 10.0, "hp": 25.0}
		2:
			return {"name": "%s Helm" % prefix, "armor": 18.0, "hp": 50.0}
		3:
			return {"name": "%s Greathelm" % prefix, "armor": 28.0, "hp": 80.0}
		4:
			return {"name": "%s Greathelm" % prefix, "armor": 40.0, "hp": 115.0}
	return {"name": "%s Helm" % prefix, "armor": 10.0, "hp": 25.0}


static func cuirass_stats(tier: int) -> Dictionary:
	var t := clampi(tier, 1, 4)
	var prefix := GameEnums.tier_prefix(t)
	match t:
		1:
			return {"name": "%s Cuirass" % prefix, "armor": 18.0, "hp": 45.0}
		2:
			return {"name": "%s Cuirass" % prefix, "armor": 32.0, "hp": 85.0}
		3:
			return {"name": "%s Cuirass" % prefix, "armor": 48.0, "hp": 135.0}
		4:
			return {"name": "%s Cuirass" % prefix, "armor": 68.0, "hp": 195.0}
	return {"name": "%s Cuirass" % prefix, "armor": 18.0, "hp": 45.0}


static func lantern_display_name(tier: int, aspect: GameEnums.LanternAspect) -> String:
	return "%s %s" % [GameEnums.tier_prefix(tier), GameEnums.lantern_name(aspect)]
