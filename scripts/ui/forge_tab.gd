class_name ForgeTab
extends MarginContainer

@onready var forge_toggle_btn: Button = $VBox/ToggleRow/ForgeToggleBtn
@onready var bestiary_toggle_btn: Button = $VBox/ToggleRow/BestiaryToggleBtn

@onready var forge_scroll: ScrollContainer = $VBox/ForgeScroll
@onready var forge_view: VBoxContainer = $VBox/ForgeScroll/ForgeView
@onready var anvil_banner: PanelContainer = $VBox/ForgeScroll/ForgeView/AnvilBanner
@onready var anvil_title_lbl: Label = $VBox/ForgeScroll/ForgeView/AnvilBanner/BannerVBox/AnvilTitleLbl
@onready var anvil_sub_lbl: Label = $VBox/ForgeScroll/ForgeView/AnvilBanner/BannerVBox/AnvilSubLbl
@onready var slot_lbl: Label = $VBox/ForgeScroll/ForgeView/SlotHeaderLbl
@onready var slot_row: HBoxContainer = $VBox/ForgeScroll/ForgeView/SlotRow
@onready var wtype_box: VBoxContainer = $VBox/ForgeScroll/ForgeView/WeaponTypeBox
@onready var wtype_lbl: Label = $VBox/ForgeScroll/ForgeView/WeaponTypeBox/WTypeHeaderLbl
@onready var wtype_grid: GridContainer = $VBox/ForgeScroll/ForgeView/WeaponTypeBox/WTypeGrid
@onready var tier_lbl: Label = $VBox/ForgeScroll/ForgeView/TierHeaderLbl
@onready var tier_row: HBoxContainer = $VBox/ForgeScroll/ForgeView/TierRow
@onready var odds_rare_panel: PanelContainer = $VBox/ForgeScroll/ForgeView/OddsRow/OddsRare
@onready var odds_rare_lbl: Label = $VBox/ForgeScroll/ForgeView/OddsRow/OddsRare/RareLbl
@onready var odds_epic_panel: PanelContainer = $VBox/ForgeScroll/ForgeView/OddsRow/OddsEpic
@onready var odds_epic_lbl: Label = $VBox/ForgeScroll/ForgeView/OddsRow/OddsEpic/EpicLbl
@onready var odds_sov_panel: PanelContainer = $VBox/ForgeScroll/ForgeView/OddsRow/OddsSov
@onready var odds_sov_lbl: Label = $VBox/ForgeScroll/ForgeView/OddsRow/OddsSov/SovLbl
@onready var cost_panel: PanelContainer = $VBox/ForgeScroll/ForgeView/CostPanel
@onready var cost_lbl: Label = $VBox/ForgeScroll/ForgeView/CostPanel/CostVBox/CostLbl
@onready var wallet_lbl: Label = $VBox/ForgeScroll/ForgeView/CostPanel/CostVBox/WalletLbl
@onready var forge_btn: Button = $VBox/ForgeScroll/ForgeView/CostPanel/CostVBox/ForgeBtn
@onready var result_panel: PanelContainer = $VBox/ForgeScroll/ForgeView/ResultPanel
@onready var result_header_lbl: Label = $VBox/ForgeScroll/ForgeView/ResultPanel/ResultVBox/ResultHeaderLbl
@onready var result_icon_frame: PanelContainer = $VBox/ForgeScroll/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultIconFrame
@onready var result_icon: TextureRect = $VBox/ForgeScroll/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultIconFrame/ResultIcon
@onready var result_name_lbl: Label = $VBox/ForgeScroll/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultInfoVBox/ResultNameLbl
@onready var result_meta_lbl: Label = $VBox/ForgeScroll/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultInfoVBox/ResultMetaLbl
@onready var result_affix_lbl: Label = $VBox/ForgeScroll/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultInfoVBox/ResultAffixLbl
@onready var equip_now_btn: Button = $VBox/ForgeScroll/ForgeView/ResultPanel/ResultVBox/EquipNowBtn

@onready var bestiary_view: VBoxContainer = $VBox/BestiaryView
@onready var bestiary_header_lbl: Label = $VBox/BestiaryView/BestiaryHeaderLbl
@onready var bestiary_list: VBoxContainer = $VBox/BestiaryView/BestiaryScroll/BestiaryList

var _showing_bestiary: bool = false
var _selected_slot: GameEnums.Slot = GameEnums.Slot.WEAPON
var _selected_wtype: GameEnums.WeaponType = GameEnums.WeaponType.GREATSWORD
var _selected_tier: int = 1
var _last_forged_item: EquipmentItem = null

var _slot_btns: Dictionary = {}
var _wtype_btns: Dictionary = {}
var _tier_btns: Dictionary = {}


func _ready() -> void:
	anvil_banner.add_theme_stylebox_override("panel", UiThemeBuilder.make_glass_panel(Color(0.048, 0.052, 0.068, 0.86), UiThemeBuilder.BORDER_GOLD, 14, 14, 10))
	cost_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_glass_panel(Color(0.052, 0.056, 0.074, 0.90), UiThemeBuilder.BORDER_GOLD, 14, 14, 12))
	result_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_glass_panel(Color(0.048, 0.052, 0.068, 0.86), UiThemeBuilder.BORDER_BRONZE, 14, 14, 12))

	var r_rare := GameEnums.rarity_color(GameEnums.Rarity.RARE)
	var r_epic := GameEnums.rarity_color(GameEnums.Rarity.EPIC)
	var r_sov := GameEnums.rarity_color(GameEnums.Rarity.SOVEREIGN)
	odds_rare_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.048, 0.052, 0.070, 0.86).lerp(r_rare, 0.10), r_rare.darkened(0.15), 10, 7))
	odds_epic_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.048, 0.052, 0.070, 0.86).lerp(r_epic, 0.10), r_epic.darkened(0.15), 10, 7))
	odds_sov_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.048, 0.052, 0.070, 0.86).lerp(r_sov, 0.10), r_sov.darkened(0.15), 10, 7))

	forge_toggle_btn.pressed.connect(set_subview.bind(false))
	bestiary_toggle_btn.pressed.connect(set_subview.bind(true))
	forge_btn.pressed.connect(trigger_forge)
	equip_now_btn.pressed.connect(_on_equip_now_pressed)

	_build_slot_buttons()
	_build_wtype_buttons()
	_build_tier_buttons()

	var gs := _game_state()
	if gs != null and not gs.profile_changed.is_connected(refresh_ui):
		gs.profile_changed.connect(refresh_ui)

	refresh_ui()


func apply_chrome_insets(insets: Dictionary) -> void:
	var top_px := int(insets.get("top", 92))
	var bot_px := int(insets.get("bottom", 100))
	var left_px := int(insets.get("left", 0))
	var right_px := int(insets.get("right", 0))
	add_theme_constant_override("margin_top", top_px + 8)
	add_theme_constant_override("margin_bottom", bot_px + 8)
	add_theme_constant_override("margin_left", 14 + left_px)
	add_theme_constant_override("margin_right", 14 + right_px)


func set_subview(show_bestiary: bool) -> void:
	if _showing_bestiary != show_bestiary:
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "ui_tap")
	_showing_bestiary = show_bestiary
	refresh_ui()


func set_forge_selection(slot: GameEnums.Slot, tier: int, wtype: GameEnums.WeaponType = GameEnums.WeaponType.GREATSWORD) -> void:
	_selected_slot = slot
	_selected_tier = clampi(tier, 1, 4)
	_selected_wtype = wtype
	refresh_ui()


func trigger_forge() -> EquipmentItem:
	var gs := _game_state()
	if gs == null:
		return null
	var max_t := _max_unlocked_tier(gs)
	var use_tier := mini(_selected_tier, max_t)
	var forged: EquipmentItem = gs.call("forge_targeted", _selected_slot, use_tier, _selected_wtype)
	var ad := _audio()
	if forged != null:
		_last_forged_item = forged
		if ad != null:
			ad.call("sfx", "gear_equip")
			ad.call("sfx", "rare_chime")
	else:
		if ad != null:
			ad.call("sfx", "ui_error")
	refresh_ui()
	return forged


func _build_slot_buttons() -> void:
	for ch in slot_row.get_children():
		ch.queue_free()
	_slot_btns.clear()

	var specs := [
		{"slot": GameEnums.Slot.WEAPON, "title": "Weapon", "icon": "zweihander"},
		{"slot": GameEnums.Slot.HELM, "title": "Helm", "icon": "helm_plume"},
		{"slot": GameEnums.Slot.CUIRASS, "title": "Cuirass", "icon": "cuirass_plate"},
		{"slot": GameEnums.Slot.LANTERN, "title": "Lantern", "icon": "waist_lantern"},
	]
	for sp in specs:
		var sl: GameEnums.Slot = sp["slot"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 84)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_selected.bind(sl))

		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 4)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(44, 44)
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex.texture = UiThemeBuilder.get_item_icon_by_key(str(sp["icon"]))
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tex)

		var lbl := Label.new()
		lbl.text = str(sp["title"]).to_upper()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lbl)

		slot_row.add_child(btn)
		_slot_btns[sl] = {"btn": btn, "lbl": lbl}


func _build_wtype_buttons() -> void:
	for ch in wtype_grid.get_children():
		ch.queue_free()
	_wtype_btns.clear()

	var specs := [
		{"wt": GameEnums.WeaponType.GREATSWORD, "name": "GREATSWORD"},
		{"wt": GameEnums.WeaponType.HALBERD, "name": "HALBERD"},
		{"wt": GameEnums.WeaponType.SWORD_SHIELD, "name": "SWORD & SHIELD"},
		{"wt": GameEnums.WeaponType.WAR_STAFF, "name": "WAR-STAFF"},
	]
	for sp in specs:
		var wt: GameEnums.WeaponType = sp["wt"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 68)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_wtype_selected.bind(wt))

		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		var title_lbl := Label.new()
		title_lbl.text = str(sp["name"])
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(title_lbl)

		var badge_lbl := Label.new()
		badge_lbl.text = "OTHER HERO"
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_lbl.visible = false
		vb.add_child(badge_lbl)

		wtype_grid.add_child(btn)
		_wtype_btns[wt] = {"btn": btn, "title": title_lbl, "badge": badge_lbl}


func _build_tier_buttons() -> void:
	for ch in tier_row.get_children():
		ch.queue_free()
	_tier_btns.clear()

	for t in range(1, 5):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 68)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tier_selected.bind(t))
		tier_row.add_child(btn)
		_tier_btns[t] = btn


func _style_labels() -> void:
	var r_rare := GameEnums.rarity_color(GameEnums.Rarity.RARE)
	var r_epic := GameEnums.rarity_color(GameEnums.Rarity.EPIC)
	var r_sov := GameEnums.rarity_color(GameEnums.Rarity.SOVEREIGN)
	UiThemeBuilder.style_label(odds_rare_lbl, UiThemeBuilder.font_bold(), 14, r_rare, 1)
	UiThemeBuilder.style_label(odds_epic_lbl, UiThemeBuilder.font_bold(), 14, r_epic, 1)
	UiThemeBuilder.style_label(odds_sov_lbl, UiThemeBuilder.font_bold(), 14, r_sov, 1)

	UiThemeBuilder.style_label(anvil_title_lbl, UiThemeBuilder.font_title(), 20, UiThemeBuilder.TEXT_GOLD, 2)
	UiThemeBuilder.style_label(anvil_sub_lbl, UiThemeBuilder.font_body(), 15, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(slot_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(wtype_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(tier_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(cost_lbl, UiThemeBuilder.font_title(), 16, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(wallet_lbl, UiThemeBuilder.font_bold(), 15, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(result_header_lbl, UiThemeBuilder.font_title(), 14, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(result_name_lbl, UiThemeBuilder.font_title(), 20, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(result_meta_lbl, UiThemeBuilder.font_bold(), 15, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(result_affix_lbl, UiThemeBuilder.font_body(), 15, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(bestiary_header_lbl, UiThemeBuilder.font_title(), 16, UiThemeBuilder.TEXT_GOLD, 1)

	UiThemeBuilder.style_cta_button(forge_btn, 21)
	UiThemeBuilder.style_cta_button(equip_now_btn, 17)


func refresh_ui() -> void:
	_style_labels()
	UiThemeBuilder.style_pill_button(forge_toggle_btn, not _showing_bestiary, 17)
	UiThemeBuilder.style_pill_button(bestiary_toggle_btn, _showing_bestiary, 17)

	forge_scroll.visible = not _showing_bestiary
	bestiary_view.visible = _showing_bestiary

	if _showing_bestiary:
		_rebuild_bestiary()
		return

	var gs := _game_state()
	var cid := str(gs.get("selected_class_id")) if gs != null else "oathbreaker"
	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null:
		hdef = GameRegistry.get_class_def("oathbreaker")

	var max_t := _max_unlocked_tier(gs)
	if _selected_tier > max_t:
		_selected_tier = max_t

	for sl in _slot_btns:
		var entry: Dictionary = _slot_btns[sl]
		var is_sel := (int(sl) == int(_selected_slot))
		UiThemeBuilder.style_tab_button(entry["btn"] as Button, is_sel, 13)
		UiThemeBuilder.style_label(entry["lbl"] as Label, UiThemeBuilder.font_title(), 12, UiThemeBuilder.TEXT_GOLD if is_sel else UiThemeBuilder.TEXT_PARCHMENT, 1)

	wtype_box.visible = (_selected_slot == GameEnums.Slot.WEAPON)
	for wt in _wtype_btns:
		var entry: Dictionary = _wtype_btns[wt]
		var btn: Button = entry["btn"]
		var tlbl: Label = entry["title"]
		var blbl: Label = entry["badge"]
		var is_sel := (int(wt) == int(_selected_wtype))
		var compat := hdef == null or hdef.can_equip_weapon_type(wt as GameEnums.WeaponType)
		if compat:
			UiThemeBuilder.style_tab_button(btn, is_sel, 14)
			UiThemeBuilder.style_label(tlbl, UiThemeBuilder.font_title(), 14, UiThemeBuilder.TEXT_GOLD if is_sel else UiThemeBuilder.TEXT_PARCHMENT, 1)
			blbl.visible = false
		else:
			var bg := Color(0.10, 0.085, 0.085, 0.80) if is_sel else Color(0.044, 0.046, 0.058, 0.68)
			var bdr := Color(0.68, 0.48, 0.26, 0.72) if is_sel else Color(0.30, 0.30, 0.36, 0.48)
			var sb := UiThemeBuilder.make_box(bg, bdr, 2 if is_sel else 1, 10, 8, 6)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_stylebox_override("focus", sb)
			btn.add_theme_stylebox_override("pressed", sb)
			UiThemeBuilder.style_label(tlbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_MUTED, 1)
			blbl.visible = true
			blbl.text = "OTHER HERO"
			UiThemeBuilder.style_label(blbl, UiThemeBuilder.font_bold(), 12, Color(0.92, 0.62, 0.32), 1)

	var tier_subtitles := {1: "Worn Iron", 2: "Black Steel", 3: "Sovereign", 4: "Ashen"}
	for t in range(1, 5):
		var tbtn := _tier_btns[t] as Button
		var unlocked := (t <= max_t)
		tbtn.disabled = not unlocked
		if unlocked:
			tbtn.text = "TIER %d\n%s" % [t, str(tier_subtitles[t])]
		else:
			tbtn.text = "TIER %d\nLOCKED" % t
		UiThemeBuilder.style_tab_button(tbtn, (t == _selected_tier) and unlocked, 13)

	var cost := LootEngine.forge_cost(_selected_tier)
	var g_cost := int(cost["gold"])
	var s_cost := int(cost["scrap"])
	var cur_gold := int(gs.get("gold")) if gs != null else 0
	var cur_scrap := int(gs.get("scrap")) if gs != null else 0
	var can_afford := (cur_gold >= g_cost and cur_scrap >= s_cost)

	cost_lbl.text = "COST: %d GOLD  ·  %d SCRAP  (Guaranteed RARE+)" % [g_cost, s_cost]
	wallet_lbl.text = "Your Coffers: %d Gold  ·  %d Scrap" % [cur_gold, cur_scrap]
	wallet_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_READY if can_afford else UiThemeBuilder.TEXT_CRIMSON)
	forge_btn.disabled = not can_afford
	forge_btn.text = "FORGE TIER %d %s" % [_selected_tier, GameEnums.slot_name(_selected_slot).to_upper()]

	_refresh_forged_showcase(gs)


func _refresh_forged_showcase(gs: Node) -> void:
	if _last_forged_item != null and gs != null and gs.call("get_item", _last_forged_item.uid) == null:
		_last_forged_item = null

	if _last_forged_item == null:
		result_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_glass_panel(Color(0.048, 0.052, 0.068, 0.84), UiThemeBuilder.BORDER_BRONZE, 14, 14, 12))
		result_header_lbl.text = "ANVIL CHAMBER READY"
		result_icon_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_BRONZE, 1, 10, 6, 6))
		result_icon.texture = UiThemeBuilder.get_item_icon_by_key("zweihander" if _selected_slot == GameEnums.Slot.WEAPON else ("helm_plume" if _selected_slot == GameEnums.Slot.HELM else ("cuirass_plate" if _selected_slot == GameEnums.Slot.CUIRASS else "waist_lantern")))
		result_icon.modulate = Color(0.55, 0.55, 0.62, 0.75)
		result_name_lbl.text = "Strike the Soul Forge"
		result_name_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_MUTED)
		result_meta_lbl.text = "Select a Relic Slot and Tier above to bind a Rare, Epic, or Sovereign piece."
		result_affix_lbl.text = "• Forged relics roll 1 to 3 Barrow Affixes immediately.\n• Equip or temper up to +5 at the Armory."
		equip_now_btn.visible = false
		return

	var item := _last_forged_item
	var rcol := GameEnums.rarity_color(item.rarity)
	result_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(Color(0.048, 0.052, 0.070, 0.90).lerp(rcol, 0.10), rcol, 2, 14, 14, 12))
	result_header_lbl.text = "NEWLY FORGED RELIC"
	result_icon_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, rcol, 2, 10, 6, 6))
	result_icon.texture = UiThemeBuilder.get_item_icon(item)
	result_icon.modulate = Color.WHITE
	result_name_lbl.text = item.display_name()
	result_name_lbl.add_theme_color_override("font_color", rcol)

	var stype := GameEnums.weapon_type_name(item.weapon_type) if item.slot == GameEnums.Slot.WEAPON else GameEnums.slot_name(item.slot)
	result_meta_lbl.text = "%s  ·  Tier %d %s  ·  PWR %d" % [
		GameEnums.rarity_name(item.rarity).to_upper(),
		item.tier,
		stype,
		item.power_score(),
	]

	var lines: Array[String] = [UiThemeBuilder.format_item_primary_line(item)]
	for af in item.affixes:
		if af != null:
			lines.append("• " + af.format_line())
	result_affix_lbl.text = "\n".join(lines)

	equip_now_btn.visible = true
	var cid := str(gs.get("selected_class_id")) if gs != null else "oathbreaker"
	if GameRegistry.get_class_def(cid) == null:
		cid = "oathbreaker"
	var hdef := GameRegistry.get_class_def(cid)
	var already_eq := bool(gs.call("is_item_equipped", item.uid)) if gs != null else false
	var compat := true
	if item.slot == GameEnums.Slot.WEAPON and hdef != null and not hdef.can_equip_weapon_type(item.weapon_type):
		compat = false

	if already_eq:
		equip_now_btn.text = "EQUIPPED ON %s" % (hdef.display_name.to_upper() if hdef != null else "HERO")
		equip_now_btn.disabled = true
	elif not compat:
		equip_now_btn.text = "OTHER HERO RELIC (SAVED TO SATCHEL)"
		equip_now_btn.disabled = true
	else:
		equip_now_btn.text = "EQUIP NOW ON %s" % (hdef.display_name.to_upper() if hdef != null else "HERO")
		equip_now_btn.disabled = false


func _rebuild_bestiary() -> void:
	for ch in bestiary_list.get_children():
		ch.queue_free()

	var gs := _game_state()
	var ordered: Array[EnemyDef] = []
	var added: Dictionary = {}
	for zid in ["hollow_ghoul", "crypt_batlord", "stone_gargoyle", "barrow_troll"]:
		var ed := GameRegistry.get_enemy(zid)
		if ed != null:
			ordered.append(ed)
			added[zid] = true
	for b in GameRegistry.get_boss_enemies():
		if not added.has(b.enemy_id):
			ordered.append(b)
			added[b.enemy_id] = true
	for e in GameRegistry.get_regular_enemies():
		if not added.has(e.enemy_id):
			ordered.append(e)
			added[e.enemy_id] = true

	for edef in ordered:
		var card := PanelContainer.new()
		var bdr := UiThemeBuilder.BORDER_GOLD if edef.is_boss else Color(0.55, 0.44, 0.24, 0.42)
		var bg := Color(0.064, 0.044, 0.052, 0.88) if edef.is_boss else Color(0.048, 0.052, 0.068, 0.84)
		card.add_theme_stylebox_override("panel", UiThemeBuilder.make_glass_panel(bg, bdr, 14, 12, 12))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		card.add_child(hb)

		var pframe := PanelContainer.new()
		pframe.custom_minimum_size = Vector2(96, 96)
		pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pframe.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, bdr, 2 if edef.is_boss else 1, 10, 2, 2))
		hb.add_child(pframe)

		var ptex := TextureRect.new()
		ptex.texture = UiThemeBuilder.get_portrait(edef.enemy_id)
		ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pframe.add_child(ptex)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 4)
		hb.add_child(vb)

		var top := HBoxContainer.new()
		vb.add_child(top)

		var tag_prefix := "[BOSS] " if edef.is_boss else ""
		var nlbl := Label.new()
		nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nlbl.text = "%s%s" % [tag_prefix, edef.display_name]
		UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_title(), 21, UiThemeBuilder.TEXT_GOLD if edef.is_boss else UiThemeBuilder.TEXT_PARCHMENT, 2)
		top.add_child(nlbl)

		var kills := UiThemeBuilder.get_bestiary_kills(gs, edef.enemy_id)
		var klbl := Label.new()
		klbl.text = "Slain: %d" % kills
		UiThemeBuilder.style_label(klbl, UiThemeBuilder.font_bold(), 15, UiThemeBuilder.TEXT_READY if kills > 0 else UiThemeBuilder.TEXT_MUTED, 1)
		top.add_child(klbl)

		var notes: Dictionary = UiThemeBuilder.BESTIARY_NOTES.get(edef.enemy_id, {})
		var sub_lore := Label.new()
		sub_lore.text = "%s — %s" % [edef.title, str(notes.get("lore", "Denizen of the Barrow Lands.")).strip_edges()]
		sub_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiThemeBuilder.style_label(sub_lore, UiThemeBuilder.font_body(), 16, UiThemeBuilder.TEXT_PARCHMENT, 1)
		vb.add_child(sub_lore)

		var tip_lbl := Label.new()
		tip_lbl.text = str(notes.get("tip", "Watch enemy windups and dodge through strikes."))
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiThemeBuilder.style_label(tip_lbl, UiThemeBuilder.font_bold(), 16, UiThemeBuilder.TEXT_GOLD, 1)
		vb.add_child(tip_lbl)

		bestiary_list.add_child(card)


func _max_unlocked_tier(gs: Node) -> int:
	if gs == null:
		return 1
	var max_t := 1
	var uz: Variant = gs.get("unlocked_zones")
	if uz is Array:
		for zid in uz:
			var zdef := GameRegistry.get_zone(str(zid))
			if zdef != null:
				max_t = maxi(max_t, zdef.max_drop_tier)
	return clampi(max_t, 1, 4)


func _on_slot_selected(sl: GameEnums.Slot) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	_selected_slot = sl
	refresh_ui()


func _on_wtype_selected(wt: GameEnums.WeaponType) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	_selected_wtype = wt
	refresh_ui()


func _on_tier_selected(t: int) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	_selected_tier = t
	refresh_ui()


func _on_equip_now_pressed() -> void:
	var gs := _game_state()
	if gs == null or _last_forged_item == null:
		return
	var cid := str(gs.get("selected_class_id"))
	if GameRegistry.get_class_def(cid) == null:
		cid = "oathbreaker"
	if bool(gs.call("equip_item", cid, _last_forged_item.uid)):
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "gear_equip")
	refresh_ui()


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
