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
		var base := load("res://scenes/ui/dark_theme.tres") as Theme
		if base != null:
			_theme_cache = base.duplicate() as Theme
			_theme_cache.set_icon("grabber", "HSlider", get_slider_grabber_texture(false))
			_theme_cache.set_icon("grabber_highlight", "HSlider", get_slider_grabber_texture(true))
			_theme_cache.set_icon("grabber_disabled", "HSlider", get_slider_grabber_texture(false))
	return _theme_cache


static func get_text_scale() -> float:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var st := ml as SceneTree
		if st.root != null:
			var ad := st.root.get_node_or_null("AudioDirector")
			if ad != null and ad.has_method("text_scale"):
				return clampf(float(ad.call("text_scale")), 0.85, 1.40)
	return 1.0


static func scaled_font_px(base_px: int, max_scale: float = 1.30) -> int:
	var sc := minf(get_text_scale(), max_scale)
	return maxi(10, roundi(float(base_px) * sc))


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
			if item.base_id == "helm_t4" or item.tier >= 4:
				key = "helm_t4"
			elif item.base_id == "helm_t3" or item.tier == 3:
				key = "helm_t3"
			elif item.base_id == "helm_t2" or item.tier == 2:
				key = "helm_t2"
			else:
				key = "helm_plume" if item.has_plume else "helm_iron"
		GameEnums.Slot.CUIRASS:
			key = "cuirass_plate"
		GameEnums.Slot.LANTERN:
			match item.lantern_aspect:
				GameEnums.LanternAspect.SOUL_BLUE:
					key = "waist_lantern_soul"
				GameEnums.LanternAspect.BLIGHT_GREEN:
					key = "waist_lantern_blight"
				GameEnums.LanternAspect.BLOOD_CRIMSON:
					key = "waist_lantern_blood"
				_:
					key = "waist_lantern"
	return get_item_icon_by_key(key)


static func get_ui_icon(icon_name: String) -> Texture2D:
	return _load_tex("res://assets/sprites/icons/%s.png" % icon_name)


static func get_fx_icon(icon_name: String) -> Texture2D:
	return _load_tex("res://assets/sprites/fx/%s.png" % icon_name)


static func get_vignette_texture() -> Texture2D:
	return _load_tex("res://assets/sprites/ui/vignette.png")


static func get_skill_icon(ability_id: String) -> Texture2D:
	var tex := _load_tex("res://assets/sprites/ui/skills/%s.png" % ability_id)
	if tex != null:
		return tex
	var fallback := "iron_tempest"
	match ability_id:
		"reaping_sweep":
			fallback = "iron_tempest"
		"wraith_lances":
			fallback = "stormbrand_arc"
		"phase_blink", "shadow_step":
			fallback = "iron_roll"
	tex = _load_tex("res://assets/sprites/ui/skills/%s.png" % fallback)
	if tex != null:
		return tex
	return _load_tex("res://assets/sprites/ui/skills/iron_tempest.png")


static func get_slider_grabber_texture(highlighted: bool = false) -> ImageTexture:
	var key := "__slider_grabber_hl" if highlighted else "__slider_grabber"
	if _tex_cache.has(key):
		return _tex_cache[key] as ImageTexture
	const SZ := 30
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(SZ - 1) * 0.5, float(SZ - 1) * 0.5)
	var outer_r := float(SZ) * 0.5 - 1.0
	var ring_inner := outer_r - 3.2
	var core_r := ring_inner - 1.2
	var rim_col := Color(0.98, 0.84, 0.48, 1.0) if highlighted else Color(0.84, 0.67, 0.34, 1.0)
	var fill_col := Color(0.18, 0.20, 0.27, 1.0) if highlighted else Color(0.10, 0.11, 0.15, 1.0)
	var core_col := Color(0.98, 0.86, 0.54, 1.0) if highlighted else Color(0.76, 0.60, 0.30, 0.85)
	for y in range(SZ):
		for x in range(SZ):
			var d := Vector2(float(x), float(y)).distance_to(center)
			if d > outer_r + 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var alpha := clampf(outer_r + 0.6 - d, 0.0, 1.0)
			var col := fill_col
			if d >= ring_inner:
				col = rim_col
			elif d <= 4.2:
				var ct := clampf((4.2 - d) / 1.4, 0.0, 1.0)
				col = fill_col.lerp(core_col, ct)
			elif d > core_r:
				var rt := clampf((d - core_r) / maxf(0.1, ring_inner - core_r), 0.0, 1.0)
				col = fill_col.lerp(rim_col, rt)
			col.a *= alpha
			img.set_pixel(x, y, col)
	var itex := ImageTexture.create_from_image(img)
	_tex_cache[key] = itex
	return itex


static func make_scrim_texture(top_to_bottom: bool = true, edge_alpha: float = 0.82, mid_alpha: float = 0.34) -> GradientTexture2D:
	var key := "__scrim_%s_%.2f_%.2f" % ["tb" if top_to_bottom else "bt", edge_alpha, mid_alpha]
	if _tex_cache.has(key):
		return _tex_cache[key] as GradientTexture2D
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	if top_to_bottom:
		grad.colors = PackedColorArray([
			Color(0.03, 0.035, 0.05, edge_alpha),
			Color(0.03, 0.035, 0.05, mid_alpha),
			Color(0.03, 0.035, 0.05, 0.0),
		])
	else:
		grad.colors = PackedColorArray([
			Color(0.03, 0.035, 0.05, 0.0),
			Color(0.03, 0.035, 0.05, mid_alpha),
			Color(0.03, 0.035, 0.05, edge_alpha),
		])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 4
	gtex.height = 64
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.0, 0.0)
	gtex.fill_to = Vector2(0.0, 1.0)
	_tex_cache[key] = gtex
	return gtex


static func get_safe_margins(viewport_node: Control) -> Dictionary:
	var top := 0
	var bottom := 0
	var left := 0
	var right := 0
	var win_size := DisplayServer.window_get_size()
	var screen_size := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := Vector2(720.0, 1280.0)
	if viewport_node != null and viewport_node.get_viewport() != null:
		var r := viewport_node.get_viewport().get_visible_rect()
		if r.size.x > 0.0 and r.size.y > 0.0:
			vp_size = r.size

	var is_mobile := OS.has_feature("ios") or OS.has_feature("mobile") or (OS.get_name() in ["iOS", "Android"])
	var aspect := vp_size.x / maxf(1.0, vp_size.y)
	var sim_mobile := false
	if not is_mobile and aspect < 0.50:
		if bool(ProjectSettings.get_setting("display/window/simulate_ios_safe_area", false)):
			sim_mobile = true
		else:
			for arg in OS.get_cmdline_user_args():
				var a := str(arg).strip_edges()
				if a == "--sim-ios-safe-area" or a == "--ios-safe-area":
					sim_mobile = true
					break

	var space_w := float(win_size.x)
	var space_h := float(win_size.y)
	if is_mobile and screen_size.x > 0 and screen_size.y > 0:
		if (vp_size.y >= vp_size.x) == (screen_size.y >= screen_size.x):
			space_w = float(screen_size.x)
			space_h = float(screen_size.y)
		else:
			space_w = float(screen_size.y)
			space_h = float(screen_size.x)
	if safe.size.x > 0 and safe.size.y > 0:
		space_w = maxf(space_w, float(safe.end.x))
		space_h = maxf(space_h, float(safe.end.y))
		if space_w > 0.0 and space_h > 0.0:
			var sx := vp_size.x / space_w
			var sy := vp_size.y / space_h
			left = maxi(0, ceili(float(safe.position.x) * sx))
			top = maxi(0, ceili(float(safe.position.y) * sy))
			right = maxi(0, ceili((space_w - float(safe.end.x)) * sx))
			bottom = maxi(0, ceili((space_h - float(safe.end.y)) * sy))

	if is_mobile or sim_mobile:
		if vp_size.y >= vp_size.x:
			top = 96 if top == 0 else clampi(top, 88, 136)
			bottom = 62 if bottom == 0 else clampi(bottom, 48, 84)
			left = clampi(left, 0, 32)
			right = clampi(right, 0, 32)
		else:
			top = clampi(top, 0, 36)
			bottom = clampi(bottom, 24, 44)
			left = clampi(left, 0, 96)
			right = clampi(right, 0, 96)
	else:
		top = maxi(top, 12)
		bottom = maxi(bottom, 12)
		left = clampi(left, 0, 32)
		right = clampi(right, 0, 32)

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


static func make_glass_panel(
	bg: Color = Color(0.048, 0.052, 0.068, 0.76),
	top_accent: Color = Color(0.83, 0.66, 0.33, 0.42),
	radius: int = 12,
	pad_h: int = 12,
	pad_v: int = 8
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = top_accent
	sb.border_width_top = 1
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	sb.shadow_size = 8
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


static func make_sheet_panel(pad_h: int = 14, pad_v: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.052, 0.056, 0.074, 0.92)
	sb.border_color = Color(0.83, 0.66, 0.33, 0.62)
	sb.border_width_top = 2
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	sb.shadow_size = 10
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


static func make_pill(
	bg: Color = Color(0.06, 0.066, 0.088, 0.82),
	border: Color = Color(0.55, 0.44, 0.24, 0.55),
	pad_h: int = 12,
	pad_v: int = 6
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


static func style_slider(slider: HSlider) -> void:
	if slider == null:
		return
	slider.custom_minimum_size.y = maxf(slider.custom_minimum_size.y, 38.0)
	slider.add_theme_icon_override("grabber", get_slider_grabber_texture(false))
	slider.add_theme_icon_override("grabber_highlight", get_slider_grabber_texture(true))
	slider.add_theme_icon_override("grabber_disabled", get_slider_grabber_texture(false))
	var track := make_box(Color(0.04, 0.046, 0.064, 0.94), Color(0.38, 0.33, 0.24, 0.65), 1, 5, 0, 5)
	var fill := make_box(Color(0.78, 0.58, 0.25, 0.94), Color(0.92, 0.74, 0.38, 0.6), 0, 5, 0, 5)
	var fill_hl := make_box(Color(0.92, 0.74, 0.38, 1.0), Color(1.0, 0.86, 0.54, 0.8), 0, 5, 0, 5)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hl)


static func style_cta_button(btn: Button, font_px: int = 20) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", font_title())
	btn.add_theme_font_size_override("font_size", scaled_font_px(font_px, 1.20))
	btn.add_theme_color_override("font_color", TEXT_PARCHMENT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", TEXT_GOLD)
	var normal := make_box(CTA_CRIMSON, BORDER_GOLD, 2, 12, 18, 12)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	normal.shadow_size = 8
	var hover := make_box(CTA_CRIMSON_HOVER, BORDER_GOLD.lightened(0.18), 2, 12, 18, 12)
	hover.shadow_color = Color(0.55, 0.14, 0.09, 0.45)
	hover.shadow_size = 9
	var pressed := make_box(CTA_CRIMSON_PRESS, BORDER_BRONZE, 2, 12, 18, 12)
	var disabled := make_box(Color("#1e1618"), BORDER_SLATE, 1, 12, 18, 12)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)


static func style_tab_button(btn: Button, active: bool, font_px: int = 15) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", font_title())
	btn.add_theme_font_size_override("font_size", scaled_font_px(font_px, 1.20))
	var bg := Color(0.16, 0.11, 0.095, 0.92) if active else Color(0.058, 0.064, 0.084, 0.80)
	var bdr := BORDER_GOLD if active else Color(0.32, 0.34, 0.42, 0.55)
	var bw := 2 if active else 1
	var sb := make_box(bg, bdr, bw, 10, 10, 6)
	var sb_hover := make_box(bg.lightened(0.08), BORDER_GOLD, bw, 10, 10, 6)
	var sb_disabled := make_box(Color(0.042, 0.046, 0.058, 0.55), Color(0.20, 0.22, 0.28, 0.40), 1, 10, 10, 6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_color_override("font_color", TEXT_GOLD if active else TEXT_MUTED)
	btn.add_theme_color_override("font_hover_color", TEXT_PARCHMENT)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.52, 0.65))


static func style_pill_button(btn: Button, active: bool, font_px: int = 14) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", font_title())
	btn.add_theme_font_size_override("font_size", scaled_font_px(font_px, 1.20))
	var bg := Color(0.18, 0.13, 0.09, 0.92) if active else Color(0.056, 0.062, 0.084, 0.78)
	var bdr := BORDER_GOLD if active else Color(0.42, 0.36, 0.24, 0.48)
	var sb := make_pill(bg, bdr, 12, 6)
	sb.set_border_width_all(2 if active else 1)
	var sb_h := make_pill(bg.lightened(0.08), BORDER_GOLD, 12, 6)
	sb_h.set_border_width_all(2 if active else 1)
	var sb_d := make_pill(Color(0.04, 0.044, 0.058, 0.50), Color(0.22, 0.24, 0.28, 0.38), 12, 6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_stylebox_override("disabled", sb_d)
	btn.add_theme_color_override("font_color", TEXT_GOLD if active else TEXT_PARCHMENT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


static func style_rarity_tile(btn: Button, rarity: GameEnums.Rarity, selected: bool, pad: int = 6) -> void:
	if btn == null:
		return
	var rcol := GameEnums.rarity_color(rarity)
	var bg := Color(0.048, 0.052, 0.070, 0.86).lerp(rcol, 0.16 if selected else 0.08)
	var bdr := BORDER_GOLD.lightened(0.22) if selected else rcol.darkened(0.10)
	var bw := 2 if (selected or int(rarity) >= int(GameEnums.Rarity.RARE)) else 1
	var sb := make_box(bg, bdr, bw, 10, pad, pad)
	var sb_h := make_box(bg.lightened(0.08), rcol.lightened(0.18), 2, 10, pad, pad)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)


static func style_label(lbl: Label, font_res: FontFile, size_px: int, col: Color, outline: int = 2) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", scaled_font_px(size_px))
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
