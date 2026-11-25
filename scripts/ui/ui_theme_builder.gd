class_name UiThemeBuilder
extends RefCounted

const BG_ABYSS := Color("#0b0d11")
const BG_IRON := Color("#111318")
const BG_IRON_RAISED := Color("#181b22")
const BG_IRON_HOVER := Color("#212631")
const BORDER_SLATE := Color("#2a2f3c")
const BORDER_BRONZE := Color("#8c7241")
const BORDER_GOLD := Color("#c69f53")
const CTA_CRIMSON := Color("#6e1916")
const CTA_CRIMSON_HOVER := Color("#8a221e")
const CTA_CRIMSON_PRESS := Color("#4d100e")

const TEXT_PARCHMENT := Color("#ece6d8")
const TEXT_MUTED := Color("#9ea4b3")
const TEXT_DIM := Color("#6d7382")
const TEXT_GOLD := Color("#e2ba68")
const TEXT_CRIMSON := Color("#e45652")
const TEXT_READY := Color("#6ed68a")
const HP_CRIMSON := Color("#9e1f24")
const WARD_CYAN := Color("#2e8bc0")

const BESTIARY_NOTES := {
	"barrow_troll": {
		"lore": "Lord of the Ashen Nave, Vaelor guards the barrow ossuary in blackened Sovereign plate and a smoldering ember-forged greatsword.",
		"tip": "Telegraph: Heavy overhead slam casts a crimson ring. Roll past his flank before the blade lands.",
	},
	"blight_werewolf": {
		"lore": "Once the Houndmaster of the Weald, fused with rot-spores that pulse emerald venom through torn sinew.",
		"tip": "Telegraph: Crouches low before a long predatory pounce. Dash sideways as the lunge line locks.",
	},
	"dread_golem": {
		"lore": "Forged from blackiron sarcophagi in the Sovereign Catacombs, powered by a furnace of trapped oaths.",
		"tip": "Telegraph: Molten core flares before radial fissure eruptions. Step outside the glowing shock rings.",
	},
	"infernal_minotaur": {
		"lore": "Khorvath broke the Rift chains in ages past, his bronze-shod horns wreathed in undying cinder.",
		"tip": "Telegraph: Scrapes hoof for a gore-charge, then cleaves wide. Bait the charge into open stone.",
	},
	"hollow_ghoul": {
		"lore": "Risen oath-sworn footmen in battered iron kettles and grave-cloth, swarming relentlessly from the nave shadows.",
		"tip": "Telegraph: Short cleaver windup in packs. Wide cleave arcs shatter whole clusters at once.",
	},
	"crypt_batlord": {
		"lore": "Crimson-cowled cultists wearing forged iron death-masks, hurling searing blackflame bolts from wrought brazier staves.",
		"tip": "Telegraph: Raises brazier staff while charging cinder bolts. Strafe perpendicular or close distance fast.",
	},
	"ash_scorpion": {
		"lore": "Chitinous cinder-skitterers nesting in hot ash vents, armored against glancing blows.",
		"tip": "Telegraph: Arches stinger tail bright orange before scuttling forward in a rapid strike.",
	},
	"stone_gargoyle": {
		"lore": "Cathedral sentinels clad in horned gunmetal barbutes, anchoring the nave with sweeping poleaxe halberd strikes.",
		"tip": "Telegraph: Slow crushing two-hand halberd sweep. Strike during recovery after the blade slams down.",
	},
}

static var _font_cinzel: FontFile = null
static var _font_body_med: FontFile = null
static var _font_body_bold: FontFile = null
static var _theme_cache: Theme = null
static var _tex_cache: Dictionary = {}


static func clear_cache() -> void:
	_tex_cache.clear()
	_theme_cache = null
	_font_cinzel = null
	_font_body_med = null
	_font_body_bold = null


static func get_theme() -> Theme:
	if _theme_cache == null:
		_theme_cache = load("res://scenes/ui/dark_theme.tres") as Theme
	return _theme_cache


static func font_title() -> FontFile:
	if _font_cinzel == null:
		_font_cinzel = load("res://assets/fonts/Cinzel-Variable.ttf") as FontFile
	return _font_cinzel


static func font_body() -> FontFile:
	if _font_body_med == null:
		_font_body_med = load("res://assets/fonts/AlegreyaSans-Medium.ttf") as FontFile
	return _font_body_med


static func font_bold() -> FontFile:
	if _font_body_bold == null:
		_font_body_bold = load("res://assets/fonts/AlegreyaSans-Bold.ttf") as FontFile
	return _font_body_bold


static func get_portrait(actor_id: String) -> Texture2D:
	return _load_tex("res://assets/sprites/ui/portraits/%s.png" % actor_id)


static func get_item_icon_by_key(key: String) -> Texture2D:
	return _load_tex("res://assets/sprites/ui/items/%s.png" % key)


static func get_item_icon(item: EquipmentItem) -> Texture2D:
	if item == null:
		return get_item_icon_by_key("zweihander")
	var key := "zweihander"
	match item.slot:
		GameEnums.Slot.WEAPON:
			var wdef := GameRegistry.get_weapon(item.base_id)
			if wdef == null:
				wdef = GameRegistry.get_weapon_by_type_and_tier(item.weapon_type, item.tier)
			key = wdef.mesh_key if wdef != null and wdef.mesh_key != "" else "zweihander"
		GameEnums.Slot.HELM:
			key = "helm_plume" if item.has_plume else "helm_iron"
		GameEnums.Slot.CUIRASS:
			key = "cuirass_plate"
		GameEnums.Slot.LANTERN:
			key = "waist_lantern"
	return get_item_icon_by_key(key)


static func get_ui_icon(icon_name: String) -> Texture2D:
	return _load_tex("res://assets/sprites/icons/%s.png" % icon_name)


static func get_skill_icon(ability_id: String) -> Texture2D:
	var mapped := ability_id
	match ability_id:
		"reaping_sweep":
			mapped = "iron_tempest"
		"wraith_lances":
			mapped = "stormbrand_arc"
		"phase_blink", "shadow_step":
			mapped = "iron_roll"
	var tex := _load_tex("res://assets/sprites/ui/skills/%s.png" % mapped)
	if tex != null:
		return tex
	return _load_tex("res://assets/sprites/ui/skills/iron_tempest.png")


static func get_safe_margins(viewport_node: Control) -> Dictionary:
	var top := 0
	var bottom := 0
	var left := 0
	var right := 0
	var win_size := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := Vector2(720.0, 1280.0)
	if viewport_node != null and viewport_node.get_viewport() != null:
		var r := viewport_node.get_viewport().get_visible_rect()
		if r.size.x > 0.0 and r.size.y > 0.0:
			vp_size = r.size
	if win_size.x > 0 and win_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
		var sx := vp_size.x / float(win_size.x)
		var sy := vp_size.y / float(win_size.y)
		left = maxi(0, ceili(float(safe.position.x) * sx))
		top = maxi(0, ceili(float(safe.position.y) * sy))
		right = maxi(0, ceili(float(win_size.x - safe.end.x) * sx))
		bottom = maxi(0, ceili(float(win_size.y - safe.end.y) * sy))
	if OS.get_name() == "iOS":
		top = maxi(top, 46)
		bottom = maxi(bottom, 24)
	return {"top": top, "bottom": bottom, "left": left, "right": right}


static func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			_tex_cache[path] = t
			return t
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			var itex := ImageTexture.create_from_image(img)
			_tex_cache[path] = itex
			return itex
	return null


static func make_box(
	bg: Color,
	border: Color,
	border_w: int = 1,
	corner_r: int = 4,
	pad_h: int = 10,
	pad_v: int = 8
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner_r)
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


static func style_cta_button(btn: Button, font_px: int = 20) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", font_title())
	btn.add_theme_font_size_override("font_size", font_px)
	btn.add_theme_color_override("font_color", TEXT_PARCHMENT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", TEXT_GOLD)
	var normal := make_box(CTA_CRIMSON, BORDER_GOLD, 2, 5, 16, 10)
	normal.shadow_color = Color(0, 0, 0, 0.55)
	normal.shadow_size = 5
	var hover := make_box(CTA_CRIMSON_HOVER, BORDER_GOLD.lightened(0.18), 2, 5, 16, 10)
	hover.shadow_color = Color(0.5, 0.1, 0.08, 0.45)
	hover.shadow_size = 6
	var pressed := make_box(CTA_CRIMSON_PRESS, BORDER_BRONZE, 2, 5, 16, 10)
	var disabled := make_box(Color("#1e1618"), BORDER_SLATE, 1, 5, 16, 10)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)


static func style_tab_button(btn: Button, active: bool, font_px: int = 15) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", font_title())
	btn.add_theme_font_size_override("font_size", font_px)
	var bg := Color("#261b18") if active else BG_IRON
	var bdr := BORDER_GOLD if active else BORDER_SLATE
	var bw := 2 if active else 1
	var sb := make_box(bg, bdr, bw, 4, 10, 6)
	var sb_hover := make_box(bg.lightened(0.08), BORDER_GOLD, bw, 4, 10, 6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", TEXT_GOLD if active else TEXT_MUTED)
	btn.add_theme_color_override("font_hover_color", TEXT_PARCHMENT)


static func style_rarity_tile(btn: Button, rarity: GameEnums.Rarity, selected: bool, pad: int = 6) -> void:
	if btn == null:
		return
	var rcol := GameEnums.rarity_color(rarity)
	var bg := BG_ABYSS.lerp(rcol, 0.14 if selected else 0.07)
	var bdr := BORDER_GOLD.lightened(0.22) if selected else rcol.darkened(0.15)
	var bw := 2 if (selected or int(rarity) >= int(GameEnums.Rarity.RARE)) else 1
	var sb := make_box(bg, bdr, bw, 4, pad, pad)
	var sb_h := make_box(bg.lightened(0.08), rcol.lightened(0.15), 2, 4, pad, pad)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)


static func style_label(lbl: Label, font_res: FontFile, size_px: int, col: Color, outline: int = 2) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", col)
	if outline > 0:
		lbl.add_theme_constant_override("outline_size", outline)
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.92))


static func format_item_primary_line(item: EquipmentItem) -> String:
	if item == null:
		return ""
	var mult := item.temper_multiplier()
	match item.slot:
		GameEnums.Slot.WEAPON:
			var wdef := GameRegistry.get_weapon(item.base_id)
			if wdef == null:
				wdef = GameRegistry.get_weapon_by_type_and_tier(item.weapon_type, item.tier)
			if wdef == null:
				return "PWR %d" % item.power_score()
			var dmg := roundi(wdef.base_damage * mult)
			var extra := "  ·  +%d ARM" % roundi(wdef.bonus_armor * mult) if wdef.bonus_armor > 0.0 else ""
			return "%d ATK  ·  %.2fs Swing%s" % [dmg, wdef.attack_interval, extra]
		GameEnums.Slot.HELM:
			var hs := GameRegistry.helm_stats(item.tier)
			return "+%d ARM  ·  +%d Max HP" % [roundi(float(hs["armor"]) * mult), roundi(float(hs["hp"]) * mult)]
		GameEnums.Slot.CUIRASS:
			var cs := GameRegistry.cuirass_stats(item.tier)
			return "+%d ARM  ·  +%d Max HP" % [roundi(float(cs["armor"]) * mult), roundi(float(cs["hp"]) * mult)]
		GameEnums.Slot.LANTERN:
			var t := float(clampi(item.tier, 1, 4))
			match item.lantern_aspect:
				GameEnums.LanternAspect.EMBER_GOLD:
					return "Ember Aura: %d Burn DPS" % roundi((8.0 + 7.0 * t) * mult)
				GameEnums.LanternAspect.SOUL_BLUE:
					return "Soulfire: +%d%% Cooldown Haste" % roundi((0.06 + 0.04 * t) * mult * 100.0)
				GameEnums.LanternAspect.BLIGHT_GREEN:
					return "Blightglass: +%d Life on Hit" % roundi((2.5 + 3.0 * t) * mult)
				GameEnums.LanternAspect.BLOOD_CRIMSON:
					return "Bloodward: +%d%% Crit & +%.2fx Mult" % [roundi((0.03 + 0.02 * t) * mult * 100.0), (0.12 + 0.08 * t) * mult]
	return "PWR %d" % item.power_score()


static func get_bestiary_kills(gs: Node, enemy_id: String) -> int:
	if gs == null:
		return 0
	var direct: Variant = gs.get("bestiary_kills")
	if direct is Dictionary and (direct as Dictionary).has(enemy_id):
		return maxi(0, int((direct as Dictionary)[enemy_id]))
	var st: Variant = gs.get("settings")
	if st is Dictionary and (st as Dictionary).has("bestiary_kills"):
		var bk: Variant = (st as Dictionary)["bestiary_kills"]
		if bk is Dictionary and (bk as Dictionary).has(enemy_id):
			return maxi(0, int((bk as Dictionary)[enemy_id]))
	var cz: Variant = gs.get("cleared_zones")
	if cz is Dictionary:
		for zid in GameRegistry.ZONE_ORDER:
			var zdef := GameRegistry.get_zone(zid)
			if zdef != null and zdef.boss_id == enemy_id:
				var arr: Variant = (cz as Dictionary).get(zid, [])
				if arr is Array and not (arr as Array).is_empty():
					return (arr as Array).size()
	return 0


static func record_bestiary_kill(gs: Node, enemy_id: String) -> void:
	if gs == null or enemy_id == "":
		return
	var direct: Variant = gs.get("bestiary_kills")
	if direct is Dictionary:
		var d := direct as Dictionary
		d[enemy_id] = int(d.get(enemy_id, 0)) + 1
		return
	var st: Variant = gs.get("settings")
	if st is Dictionary:
		var s := st as Dictionary
		var bk: Dictionary = {}
		if s.has("bestiary_kills") and s["bestiary_kills"] is Dictionary:
			bk = (s["bestiary_kills"] as Dictionary).duplicate()
		bk[enemy_id] = int(bk.get(enemy_id, 0)) + 1
		s["bestiary_kills"] = bk
