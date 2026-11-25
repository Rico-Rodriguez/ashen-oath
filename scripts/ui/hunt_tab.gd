class_name HuntTab
extends MarginContainer

signal embark_requested(class_id: String, zone_id: String, difficulty: int)

const ACTIVE_SLICE_CLASS := "oathbreaker"

@onready var stage_3d: SanctuaryStage3D = $VBox/StageFrame/SanctuaryStage3D
@onready var hero_plaque: PanelContainer = $VBox/StageFrame/HeroPlaque
@onready var hero_name_lbl: Label = $VBox/StageFrame/HeroPlaque/PlaqueVBox/HeroNameLbl
@onready var hero_sub_lbl: Label = $VBox/StageFrame/HeroPlaque/PlaqueVBox/HeroSubLbl
@onready var hero_Cards_row: HBoxContainer = $VBox/HeroCardsRow
@onready var skill_row: GridContainer = $VBox/SkillRow
@onready var zones_vbox: VBoxContainer = $VBox/ZonesVBox
@onready var diff_row: HBoxContainer = $VBox/DiffRow
@onready var embark_btn: Button = $VBox/EmbarkBtn

var _hero_card_btns: Dictionary = {}
var _zone_tab_btns: Dictionary = {}
var _featured_zone_widgets: Dictionary = {}
var _diff_btns: Dictionary = {}


func _ready() -> void:
	hero_plaque.add_theme_stylebox_override(
		"panel",
		UiThemeBuilder.make_box(Color(0.05, 0.055, 0.075, 0.86), UiThemeBuilder.BORDER_BRONZE, 1, 4, 12, 6)
	)
	UiThemeBuilder.style_label(hero_name_lbl, UiThemeBuilder.font_title(), 16, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(hero_sub_lbl, UiThemeBuilder.font_body(), 12, UiThemeBuilder.TEXT_PARCHMENT)
	UiThemeBuilder.style_cta_button(embark_btn, 21)

	_build_hero_cards()
	_build_zone_cards()
	_build_difficulty_buttons()

	embark_btn.pressed.connect(_on_embark_pressed)

	var gs := _game_state()
	if gs != null:
		if str(gs.get("selected_class_id")) != ACTIVE_SLICE_CLASS and gs.has_method("select_class"):
			gs.call("select_class", ACTIVE_SLICE_CLASS)
		if not gs.profile_changed.is_connected(refresh_ui):
			gs.profile_changed.connect(refresh_ui)

	refresh_ui()


func _build_hero_cards() -> void:
	for ch in hero_Cards_row.get_children():
		ch.queue_free()
	_hero_card_btns.clear()

	var short_names := {
		"oathbreaker": "Oathbreaker",
		"battlemage": "Ashen Battlemage",
		"revenant": "Dread Revenant",
	}
	var forge_icons := {
		"battlemage": "runed_staff",
		"revenant": "halberd",
	}

	for hdef in GameRegistry.get_all_classes():
		var is_playable := (hdef.class_id == ACTIVE_SLICE_CLASS)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 68)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_stretch_ratio = 1.55 if is_playable else 1.0
		btn.pressed.connect(_on_hero_card_pressed.bind(hdef.class_id))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 7)
		margin.add_theme_constant_override("margin_right", 7)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(hbox)

		var pframe := PanelContainer.new()
		pframe.custom_minimum_size = Vector2(54, 54)
		pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pframe.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_BRONZE, 1, 4, 2, 2))
		pframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(pframe)

		var tex := TextureRect.new()
		if is_playable:
			tex.texture = UiThemeBuilder.get_portrait(hdef.class_id)
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		else:
			tex.texture = UiThemeBuilder.get_item_icon_by_key(str(forge_icons.get(hdef.class_id, "halberd")))
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.modulate = Color(0.55, 0.56, 0.64, 0.78)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pframe.add_child(tex)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(vbox)

		var nlbl := Label.new()
		nlbl.name = "NameLbl"
		nlbl.text = str(short_names.get(hdef.class_id, hdef.display_name))
		nlbl.clip_text = true
		UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_title(), 13 if is_playable else 11, UiThemeBuilder.TEXT_GOLD if is_playable else UiThemeBuilder.TEXT_MUTED)
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(nlbl)

		var rlbl := Label.new()
		rlbl.text = hdef.subtitle if is_playable else "IN THE FORGE"
		rlbl.clip_text = true
		UiThemeBuilder.style_label(
			rlbl,
			UiThemeBuilder.font_title() if not is_playable else UiThemeBuilder.font_body(),
			10 if not is_playable else 12,
			UiThemeBuilder.BORDER_GOLD if not is_playable else UiThemeBuilder.TEXT_PARCHMENT,
			1
		)
		rlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(rlbl)

		hero_Cards_row.add_child(btn)
		_hero_card_btns[hdef.class_id] = {"btn": btn, "name_lbl": nlbl, "frame": pframe, "playable": is_playable}


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
		tbtn.custom_minimum_size = Vector2(0, 38)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := clampi(zdef.depth_index, 0, roman.size() - 1)
		tbtn.text = "%s · %s" % [roman[idx], zdef.display_name.get_slice(" ", 0).to_upper()]
		if zdef.zone_id == "fringe":
			tbtn.text = "I · FRINGE"
		tbtn.pressed.connect(_on_zone_pressed.bind(zdef.zone_id))
		tabs_row.add_child(tbtn)
		_zone_tab_btns[zdef.zone_id] = {"btn": tbtn, "zdef": zdef}

	var feat_btn := Button.new()
	feat_btn.custom_minimum_size = Vector2(0, 72)
	feat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feat_btn.disabled = false
	feat_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feat_btn.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var bframe := PanelContainer.new()
	bframe.custom_minimum_size = Vector2(56, 56)
	bframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bframe.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_GOLD, 1, 4, 2, 2))
	bframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(bframe)

	var btex := TextureRect.new()
	btex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	btex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	btex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bframe.add_child(btex)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(mid)

	var ztitle := Label.new()
	UiThemeBuilder.style_label(ztitle, UiThemeBuilder.font_title(), 15, UiThemeBuilder.TEXT_GOLD)
	ztitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(ztitle)

	var zsub := Label.new()
	zsub.clip_text = true
	UiThemeBuilder.style_label(zsub, UiThemeBuilder.font_body(), 13, UiThemeBuilder.TEXT_PARCHMENT, 1)
	zsub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(zsub)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 2)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right)

	var status_lbl := Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiThemeBuilder.style_label(status_lbl, UiThemeBuilder.font_title(), 11, UiThemeBuilder.TEXT_GOLD)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(status_lbl)

	var pwr_lbl := Label.new()
	pwr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiThemeBuilder.style_label(pwr_lbl, UiThemeBuilder.font_bold(), 13, UiThemeBuilder.TEXT_PARCHMENT, 1)
	pwr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(pwr_lbl)

	zones_vbox.add_child(feat_btn)
	_featured_zone_widgets = {
		"btn": feat_btn,
		"btex": btex,
		"title": ztitle,
		"sub": zsub,
		"status": status_lbl,
		"pwr": pwr_lbl,
	}


func _build_difficulty_buttons() -> void:
	for ch in diff_row.get_children():
		ch.queue_free()
	_diff_btns.clear()

	var specs := [
		{"diff": GameEnums.Difficulty.NORMAL, "label": "NORMAL\n1.0x Gold"},
		{"diff": GameEnums.Difficulty.VETERAN, "label": "VETERAN\n1.35x Gold · +1 Roll"},
		{"diff": GameEnums.Difficulty.NIGHTMARE, "label": "NIGHTMARE\n1.75x Gold · +2 Rolls"},
	]
	for sp in specs:
		var d: GameEnums.Difficulty = sp["diff"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(sp["label"])
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.pressed.connect(_on_diff_pressed.bind(d))
		diff_row.add_child(btn)
		_diff_btns[int(d)] = btn


func refresh_ui() -> void:
	var gs := _game_state()
	var cid := ACTIVE_SLICE_CLASS
	var zid := str(gs.get("selected_zone_id")) if gs != null else "fringe"
	var diff := int(gs.get("selected_difficulty")) if gs != null else int(GameEnums.Difficulty.NORMAL)
	var hero_pwr := int(gs.call("get_class_power_score", cid)) if gs != null and gs.has_method("get_class_power_score") else 140

	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null:
		hdef = GameRegistry.get_class_def(ACTIVE_SLICE_CLASS)

	hero_name_lbl.text = hdef.display_name.to_upper()
	hero_sub_lbl.text = "%s  ·  Hero Power %d" % [hdef.subtitle, hero_pwr]

	for k in _hero_card_btns:
		var entry: Dictionary = _hero_card_btns[k]
		var active := (str(k) == cid)
		var playable := bool(entry["playable"])
		var btn: Button = entry["btn"]
		UiThemeBuilder.style_tab_button(btn, active, 12)
		if not playable:
			var lock_bg := UiThemeBuilder.make_box(Color(0.055, 0.060, 0.075, 0.72), UiThemeBuilder.BORDER_SLATE, 1, 4, 8, 5)
			btn.add_theme_stylebox_override("normal", lock_bg)
			btn.add_theme_stylebox_override("hover", lock_bg)
			btn.add_theme_stylebox_override("pressed", lock_bg)
		var nlbl: Label = entry["name_lbl"]
		nlbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD if active else UiThemeBuilder.TEXT_MUTED)
		var pframe: PanelContainer = entry["frame"]
		pframe.add_theme_stylebox_override(
			"panel",
			UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_GOLD if active else UiThemeBuilder.BORDER_SLATE, 2 if active else 1, 4, 2, 2)
		)

	_rebuild_skill_strip(hdef)

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
		var short_z := "FRINGE" if zdef.zone_id == "fringe" else zdef.display_name.get_slice(" ", 1).to_upper()
		if short_z == "":
			short_z = zdef.display_name.to_upper()
		btn.text = "%s · %s" % [roman[idx], short_z if unlocked else "LOCKED"]
		UiThemeBuilder.style_tab_button(btn, selected, 12)

	var sel_zone := GameRegistry.get_zone(zid)
	if sel_zone == null:
		sel_zone = GameRegistry.get_zone("fringe")
	var unlocked_sel := bool(gs.call("is_zone_unlocked", sel_zone.zone_id)) if gs != null and gs.has_method("is_zone_unlocked") else true
	var cleared_arr: Variant = cleared_map.get(sel_zone.zone_id, [])
	var is_cleared := (cleared_arr is Array) and not (cleared_arr as Array).is_empty()

	var fbtn: Button = _featured_zone_widgets["btn"]
	UiThemeBuilder.style_tab_button(fbtn, true, 13)
	var btex: TextureRect = _featured_zone_widgets["btex"]
	btex.texture = UiThemeBuilder.get_portrait(sel_zone.boss_id)
	btex.modulate = Color.WHITE if unlocked_sel else Color(0.4, 0.4, 0.45, 0.85)
	var ztitle: Label = _featured_zone_widgets["title"]
	var zsub: Label = _featured_zone_widgets["sub"]
	var boss_def := GameRegistry.get_enemy(sel_zone.boss_id)
	var boss_short := boss_def.display_name if boss_def != null else sel_zone.boss_id
	if sel_zone.zone_id == "fringe":
		ztitle.text = "Depth 1 · Barrow Fringe (The Ashen Nave)"
	else:
		ztitle.text = "Depth %d · %s" % [sel_zone.depth_index + 1, sel_zone.display_name]
	zsub.text = "Guardian: %s  ·  Tier %d Relics" % [boss_short, sel_zone.max_drop_tier]

	var status_lbl: Label = _featured_zone_widgets["status"]
	if is_cleared:
		status_lbl.text = "ACTIVE · CLEARED"
		status_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_READY)
	else:
		status_lbl.text = "SELECTED"
		status_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD)

	var pwr_lbl: Label = _featured_zone_widgets["pwr"]
	pwr_lbl.text = "Rec %d / You %d" % [sel_zone.recommended_power, hero_pwr]
	var pwr_col := UiThemeBuilder.TEXT_READY if hero_pwr >= sel_zone.recommended_power else (UiThemeBuilder.TEXT_GOLD if hero_pwr >= int(float(sel_zone.recommended_power) * 0.75) else UiThemeBuilder.TEXT_CRIMSON)
	pwr_lbl.add_theme_color_override("font_color", pwr_col)

	for dk in _diff_btns:
		var dbtn: Button = _diff_btns[dk]
		var is_act := (int(dk) == diff)
		UiThemeBuilder.style_tab_button(dbtn, is_act, 12)

	var z_title := sel_zone.display_name.to_upper() if sel_zone != null else "BARROW FRINGE"
	embark_btn.text = "EMBARK ON HUNT  —  %s" % z_title

	if stage_3d != null:
		stage_3d.refresh_hero()


func _rebuild_skill_strip(hdef: HeroClassDef) -> void:
	for ch in skill_row.get_children():
		ch.queue_free()
	if hdef == null:
		return

	var entries: Array[AbilityDef] = [hdef.skill_1, hdef.skill_2]
	if hdef.skill_3 != null:
		entries.append(hdef.skill_3)
	entries.append(hdef.dash_ability)

	for ab in entries:
		if ab == null:
			continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 56)
		card.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 5, 7, 5))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		card.add_child(hb)

		var icon_tex := TextureRect.new()
		icon_tex.custom_minimum_size = Vector2(40, 40)
		icon_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_tex.texture = UiThemeBuilder.get_skill_icon(ab.ability_id)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(icon_tex)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 1)
		hb.add_child(vb)

		var top := HBoxContainer.new()
		vb.add_child(top)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = ab.display_name
		name_lbl.clip_text = true
		UiThemeBuilder.style_label(name_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD)
		top.add_child(name_lbl)

		var cd_lbl := Label.new()
		cd_lbl.text = "%.1fs" % ab.cooldown_sec
		UiThemeBuilder.style_label(cd_lbl, UiThemeBuilder.font_bold(), 11, UiThemeBuilder.TEXT_MUTED, 1)
		top.add_child(cd_lbl)

		var desc := Label.new()
		desc.text = ab.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.max_lines_visible = 2
		UiThemeBuilder.style_label(desc, UiThemeBuilder.font_body(), 11, UiThemeBuilder.TEXT_PARCHMENT, 1)
		vb.add_child(desc)

		skill_row.add_child(card)


func _on_hero_card_pressed(cid: String) -> void:
	if cid != ACTIVE_SLICE_CLASS:
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "ui_error")
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
	var cid := ACTIVE_SLICE_CLASS
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
