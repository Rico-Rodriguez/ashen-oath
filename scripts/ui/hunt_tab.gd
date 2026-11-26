class_name HuntTab
extends Control

signal embark_requested(class_id: String, zone_id: String, difficulty: int)

@onready var stage_3d: SanctuaryStage3D = $SanctuaryStage3D
@onready var bottom_scrim: TextureRect = $BottomScrim
@onready var safe_overlay: MarginContainer = $SafeOverlay
@onready var hero_name_lbl: Label = $SafeOverlay/OverlayVBox/HeroPlaqueVBox/HeroNameLbl
@onready var hero_sub_lbl: Label = $SafeOverlay/OverlayVBox/HeroPlaqueVBox/HeroSubLbl
@onready var skill_badges_row: HBoxContainer = $SafeOverlay/OverlayVBox/HeroPlaqueVBox/SkillBadgesCenter/SkillBadgesRow
@onready var skill_tooltip_panel: PanelContainer = $SafeOverlay/OverlayVBox/HeroPlaqueVBox/SkillTooltipPanel
@onready var skill_tooltip_lbl: Label = $SafeOverlay/OverlayVBox/HeroPlaqueVBox/SkillTooltipPanel/SkillTooltipLbl
@onready var lower_dock: PanelContainer = $SafeOverlay/OverlayVBox/LowerDock
@onready var hero_cards_row: HBoxContainer = $SafeOverlay/OverlayVBox/LowerDock/DockVBox/HeroCardsRow
@onready var zones_vbox: VBoxContainer = $SafeOverlay/OverlayVBox/LowerDock/DockVBox/ZonesVBox
@onready var diff_row: HBoxContainer = $SafeOverlay/OverlayVBox/LowerDock/DockVBox/DiffRow
@onready var embark_btn: Button = $SafeOverlay/OverlayVBox/LowerDock/DockVBox/EmbarkBtn

var _hero_card_btns: Dictionary = {}
var _zone_tab_btns: Dictionary = {}
var _featured_zone_widgets: Dictionary = {}
var _diff_btns: Dictionary = {}
var _skill_badge_btns: Dictionary = {}
var _active_tooltip_ab_id: String = ""
var _last_skill_class_id: String = ""


func _ready() -> void:
	stage_3d.set_stage_mode("sanctum")
	bottom_scrim.texture = UiThemeBuilder.make_scrim_texture(false, 0.88, 0.36)
	lower_dock.add_theme_stylebox_override(
		"panel",
		UiThemeBuilder.make_glass_panel(Color(0.044, 0.048, 0.066, 0.80), Color(0.83, 0.66, 0.33, 0.48), 16, 12, 10)
	)
	skill_tooltip_panel.add_theme_stylebox_override(
		"panel",
		UiThemeBuilder.make_pill(Color(0.042, 0.046, 0.064, 0.90), UiThemeBuilder.BORDER_GOLD, 14, 6)
	)

	_build_hero_cards()
	_build_zone_cards()
	_build_difficulty_buttons()

	embark_btn.pressed.connect(_on_embark_pressed)

	var gs := _game_state()
	if gs != null:
		if not gs.profile_changed.is_connected(refresh_ui):
			gs.profile_changed.connect(refresh_ui)

	refresh_ui()


func apply_chrome_insets(insets: Dictionary) -> void:
	var top_px := int(insets.get("top", 88))
	var bot_px := int(insets.get("bottom", 96))
	var left_px := int(insets.get("left", 0))
	var right_px := int(insets.get("right", 0))
	safe_overlay.add_theme_constant_override("margin_top", top_px + 4)
	safe_overlay.add_theme_constant_override("margin_bottom", bot_px + 10)
	safe_overlay.add_theme_constant_override("margin_left", 14 + left_px)
	safe_overlay.add_theme_constant_override("margin_right", 14 + right_px)


func _selected_class_id(gs: Node) -> String:
	var cid := str(gs.get("selected_class_id")) if gs != null else "oathbreaker"
	return cid if GameRegistry.get_class_def(cid) != null else "oathbreaker"


func _build_hero_cards() -> void:
	for ch in hero_cards_row.get_children():
		ch.queue_free()
	_hero_card_btns.clear()

	var short_names := {
		"oathbreaker": "Oathbreaker",
		"battlemage": "Battlemage",
		"revenant": "Revenant",
	}

	for hdef in GameRegistry.get_all_classes():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 78)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_hero_card_pressed.bind(hdef.class_id))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(hbox)

		var pframe := PanelContainer.new()
		pframe.custom_minimum_size = Vector2(58, 58)
		pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(pframe)

		var tex := TextureRect.new()
		tex.texture = UiThemeBuilder.get_portrait(hdef.class_id)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pframe.add_child(tex)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(vbox)

		var nlbl := Label.new()
		nlbl.text = str(short_names.get(hdef.class_id, hdef.display_name))
		nlbl.clip_text = true
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(nlbl)

		var rlbl := Label.new()
		rlbl.text = hdef.subtitle
		rlbl.clip_text = true
		rlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(rlbl)

		hero_cards_row.add_child(btn)
		_hero_card_btns[hdef.class_id] = {
			"btn": btn,
			"name_lbl": nlbl,
			"sub_lbl": rlbl,
			"frame": pframe,
		}


func _build_zone_cards() -> void:
	for ch in zones_vbox.get_children():
		ch.queue_free()
	_zone_tab_btns.clear()
	_featured_zone_widgets.clear()

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	zones_vbox.add_child(tabs_row)

	var roman := ["I", "II", "III", "IV"]
	for zdef in GameRegistry.get_all_zones():
		var tbtn := Button.new()
		tbtn.custom_minimum_size = Vector2(0, 56)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := clampi(zdef.depth_index, 0, roman.size() - 1)
		tbtn.text = "%s · %s" % [roman[idx], _zone_short_name(zdef)]
		tbtn.pressed.connect(_on_zone_pressed.bind(zdef.zone_id))
		tabs_row.add_child(tbtn)
		_zone_tab_btns[zdef.zone_id] = {"btn": tbtn, "zdef": zdef}

	var summary_panel := PanelContainer.new()
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.add_theme_stylebox_override(
		"panel",
		UiThemeBuilder.make_glass_panel(Color(0.042, 0.046, 0.064, 0.78), Color(0.83, 0.66, 0.33, 0.42), 12, 10, 8)
	)
	zones_vbox.add_child(summary_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	summary_panel.add_child(hbox)

	var bframe := PanelContainer.new()
	bframe.custom_minimum_size = Vector2(52, 52)
	bframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bframe.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_GOLD, 1, 8, 2, 2))
	hbox.add_child(bframe)

	var btex := TextureRect.new()
	btex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	btex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bframe.add_child(btex)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 2)
	hbox.add_child(mid)

	var ztitle := Label.new()
	ztitle.clip_text = true
	mid.add_child(ztitle)

	var zsub := Label.new()
	zsub.clip_text = true
	mid.add_child(zsub)

	var pwr_badge := PanelContainer.new()
	pwr_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(pwr_badge)

	var pwr_lbl := Label.new()
	pwr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pwr_badge.add_child(pwr_lbl)

	_featured_zone_widgets = {
		"panel": summary_panel,
		"btex": btex,
		"title": ztitle,
		"sub": zsub,
		"pwr_badge": pwr_badge,
		"pwr": pwr_lbl,
	}


static func _zone_short_name(zdef: ZoneDef) -> String:
	match zdef.zone_id:
		"fringe":
			return "FRINGE"
		"weald":
			return "WEALD"
		"catacombs":
			return "CATACOMBS"
		"rift":
			return "RIFT"
		_:
			return zdef.display_name.get_slice(" ", 0).to_upper()


func _build_difficulty_buttons() -> void:
	for ch in diff_row.get_children():
		ch.queue_free()
	_diff_btns.clear()

	var specs := [
		{"diff": GameEnums.Difficulty.NORMAL, "label": "NORMAL · 1.0x"},
		{"diff": GameEnums.Difficulty.VETERAN, "label": "VETERAN · 1.35x"},
		{"diff": GameEnums.Difficulty.NIGHTMARE, "label": "NIGHTMARE · 1.75x"},
	]
	for sp in specs:
		var d: GameEnums.Difficulty = sp["diff"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(sp["label"])
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.pressed.connect(_on_diff_pressed.bind(d))
		diff_row.add_child(btn)
		_diff_btns[int(d)] = btn


func refresh_ui() -> void:
	var gs := _game_state()
	var cid := _selected_class_id(gs)
	var zid := str(gs.get("selected_zone_id")) if gs != null else "fringe"
	var diff := int(gs.get("selected_difficulty")) if gs != null else int(GameEnums.Difficulty.NORMAL)
	var hero_pwr := int(gs.call("get_class_power_score", cid)) if gs != null and gs.has_method("get_class_power_score") else 140

	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null:
		hdef = GameRegistry.get_class_def("oathbreaker")

	UiThemeBuilder.style_label(hero_name_lbl, UiThemeBuilder.font_title(), 26, UiThemeBuilder.TEXT_GOLD, 3)
	UiThemeBuilder.style_label(hero_sub_lbl, UiThemeBuilder.font_body(), 16, UiThemeBuilder.TEXT_PARCHMENT, 2)
	UiThemeBuilder.style_label(skill_tooltip_lbl, UiThemeBuilder.font_body(), 15, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_cta_button(embark_btn, 22)

	hero_name_lbl.text = hdef.display_name.to_upper()
	hero_sub_lbl.text = "%s  ·  Hero Power %d" % [hdef.subtitle, hero_pwr]

	for k in _hero_card_btns:
		var entry: Dictionary = _hero_card_btns[k]
		var active := (str(k) == cid)
		var btn: Button = entry["btn"]
		var bg := Color(0.16, 0.11, 0.085, 0.90) if active else Color(0.055, 0.060, 0.080, 0.78)
		var bdr := UiThemeBuilder.BORDER_GOLD if active else Color(0.36, 0.34, 0.30, 0.45)
		var sb := UiThemeBuilder.make_box(bg, bdr, 2 if active else 1, 14, 6, 4)
		var sb_h := UiThemeBuilder.make_box(bg.lightened(0.08), UiThemeBuilder.BORDER_GOLD, 2, 14, 6, 4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("focus", sb_h)
		btn.add_theme_stylebox_override("pressed", sb)

		var nlbl: Label = entry["name_lbl"]
		var slbl: Label = entry["sub_lbl"]
		UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD if active else UiThemeBuilder.TEXT_PARCHMENT, 1)
		UiThemeBuilder.style_label(slbl, UiThemeBuilder.font_body(), 12, UiThemeBuilder.TEXT_MUTED, 1)

		var pframe: PanelContainer = entry["frame"]
		pframe.add_theme_stylebox_override(
			"panel",
			UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_GOLD if active else UiThemeBuilder.BORDER_SLATE, 2 if active else 1, 10, 2, 2)
		)

	_rebuild_skill_badges(hdef)

	var cleared_map: Dictionary = gs.get("cleared_zones") if gs != null and gs.get("cleared_zones") is Dictionary else {}
	var roman := ["I", "II", "III", "IV"]
	for zk in _zone_tab_btns:
		var entry: Dictionary = _zone_tab_btns[zk]
		var zdef: ZoneDef = entry["zdef"]
		var btn: Button = entry["btn"]
		var unlocked := bool(gs.call("is_zone_unlocked", zdef.zone_id)) if gs != null and gs.has_method("is_zone_unlocked") else (zdef.depth_index == 0)
		var selected := (zdef.zone_id == zid) and unlocked
		btn.disabled = not unlocked
		var idx := clampi(zdef.depth_index, 0, roman.size() - 1)
		btn.text = "%s · %s" % [roman[idx], _zone_short_name(zdef) if unlocked else "LOCKED"]
		UiThemeBuilder.style_tab_button(btn, selected, 13)

	var sel_zone := GameRegistry.get_zone(zid)
	if sel_zone == null:
		sel_zone = GameRegistry.get_zone("fringe")
	var unlocked_sel := bool(gs.call("is_zone_unlocked", sel_zone.zone_id)) if gs != null and gs.has_method("is_zone_unlocked") else true
	var cleared_arr: Variant = cleared_map.get(sel_zone.zone_id, [])
	var is_cleared := (cleared_arr is Array) and not (cleared_arr as Array).is_empty()

	var btex: TextureRect = _featured_zone_widgets["btex"]
	btex.texture = UiThemeBuilder.get_portrait(sel_zone.boss_id)
	btex.modulate = Color.WHITE if unlocked_sel else Color(0.4, 0.4, 0.45, 0.85)

	var ztitle: Label = _featured_zone_widgets["title"]
	var zsub: Label = _featured_zone_widgets["sub"]
	UiThemeBuilder.style_label(ztitle, UiThemeBuilder.font_title(), 16, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(zsub, UiThemeBuilder.font_body(), 14, UiThemeBuilder.TEXT_PARCHMENT, 1)

	var boss_def := GameRegistry.get_enemy(sel_zone.boss_id)
	var boss_short := boss_def.display_name if boss_def != null else sel_zone.boss_id
	var cleared_tag := "  ·  PURGED" if is_cleared else ""
	ztitle.text = "Depth %d · %s%s" % [sel_zone.depth_index + 1, sel_zone.display_name, cleared_tag]
	zsub.text = "Guardian: %s  ·  Tier %d Relics" % [boss_short, sel_zone.max_drop_tier]

	var pwr_badge: PanelContainer = _featured_zone_widgets["pwr_badge"]
	var pwr_lbl: Label = _featured_zone_widgets["pwr"]
	var pwr_col := UiThemeBuilder.TEXT_READY if hero_pwr >= sel_zone.recommended_power else (UiThemeBuilder.TEXT_GOLD if hero_pwr >= int(float(sel_zone.recommended_power) * 0.75) else UiThemeBuilder.TEXT_CRIMSON)
	pwr_badge.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.04, 0.044, 0.06, 0.86), pwr_col.darkened(0.20), 10, 5))
	UiThemeBuilder.style_label(pwr_lbl, UiThemeBuilder.font_bold(), 14, pwr_col, 1)
	pwr_lbl.text = "REC %d" % sel_zone.recommended_power

	for dk in _diff_btns:
		var dbtn: Button = _diff_btns[dk]
		UiThemeBuilder.style_pill_button(dbtn, int(dk) == diff, 13)

	var z_title := sel_zone.display_name.to_upper() if sel_zone != null else "BARROW FRINGE"
	embark_btn.text = "EMBARK  —  %s" % z_title

	if stage_3d != null:
		stage_3d.refresh_hero()


func _rebuild_skill_badges(hdef: HeroClassDef) -> void:
	if hdef == null:
		return
	if _last_skill_class_id != hdef.class_id:
		_active_tooltip_ab_id = ""
		skill_tooltip_panel.visible = false
		_last_skill_class_id = hdef.class_id

	for ch in skill_badges_row.get_children():
		ch.queue_free()
	_skill_badge_btns.clear()

	var entries: Array[AbilityDef] = [hdef.skill_1, hdef.skill_2]
	if hdef.skill_3 != null:
		entries.append(hdef.skill_3)
	entries.append(hdef.dash_ability)

	for ab in entries:
		if ab == null:
			continue
		var is_sel := (_active_tooltip_ab_id == ab.ability_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(52, 52)
		var sb := UiThemeBuilder.make_box(
			Color(0.14, 0.11, 0.08, 0.90) if is_sel else Color(0.05, 0.055, 0.075, 0.82),
			UiThemeBuilder.BORDER_GOLD if is_sel else Color(0.75, 0.60, 0.30, 0.60),
			2 if is_sel else 1,
			26,
			0,
			0
		)
		var sb_h := UiThemeBuilder.make_box(Color(0.14, 0.12, 0.10, 0.92), UiThemeBuilder.BORDER_GOLD, 2, 26, 0, 0)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("focus", sb_h)
		btn.add_theme_stylebox_override("pressed", sb_h)
		btn.pressed.connect(_on_skill_badge_pressed.bind(ab))

		var icon_tex := TextureRect.new()
		icon_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_tex.offset_left = 6.0
		icon_tex.offset_top = 6.0
		icon_tex.offset_right = -6.0
		icon_tex.offset_bottom = -6.0
		icon_tex.texture = UiThemeBuilder.get_skill_icon(ab.ability_id)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_tex)

		skill_badges_row.add_child(btn)
		_skill_badge_btns[ab.ability_id] = btn


func _on_skill_badge_pressed(ab: AbilityDef) -> void:
	if ab == null:
		return
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	if _active_tooltip_ab_id == ab.ability_id:
		_active_tooltip_ab_id = ""
		skill_tooltip_panel.visible = false
	else:
		_active_tooltip_ab_id = ab.ability_id
		skill_tooltip_lbl.text = "%s (%.1fs) — %s" % [ab.display_name, ab.cooldown_sec, ab.description]
		skill_tooltip_panel.visible = true
	var gs := _game_state()
	var hdef := GameRegistry.get_class_def(_selected_class_id(gs))
	if hdef != null:
		_rebuild_skill_badges(hdef)


func _on_hero_card_pressed(cid: String) -> void:
	if GameRegistry.get_class_def(cid) == null:
		return
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_press")
	var gs := _game_state()
	if gs != null and gs.has_method("select_class"):
		gs.call("select_class", cid)
	refresh_ui()


func _on_zone_pressed(zid: String) -> void:
	var gs := _game_state()
	if gs != null and gs.has_method("select_zone"):
		if bool(gs.call("select_zone", zid)):
			var ad := _audio()
			if ad != null:
				ad.call("sfx", "ui_tap")
		else:
			var ad := _audio()
			if ad != null:
				ad.call("sfx", "ui_error")
	refresh_ui()


func _on_diff_pressed(diff: GameEnums.Difficulty) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_toggle")
	var gs := _game_state()
	if gs != null and gs.has_method("select_difficulty"):
		gs.call("select_difficulty", diff)
	refresh_ui()


func _on_embark_pressed() -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_press")
	var gs := _game_state()
	var cid := _selected_class_id(gs)
	var zid := str(gs.get("selected_zone_id")) if gs != null else "fringe"
	var diff := int(gs.get("selected_difficulty")) if gs != null else 0
	embark_requested.emit(cid, zid, diff)


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
