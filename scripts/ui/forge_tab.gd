class_name ForgeTab
extends MarginContainer

@onready var forge_toggle_btn: Button = $VBox/ToggleRow/ForgeToggleBtn
@onready var bestiary_toggle_btn: Button = $VBox/ToggleRow/BestiaryToggleBtn

@onready var forge_view: VBoxContainer = $VBox/ForgeView
@onready var anvil_banner: PanelContainer = $VBox/ForgeView/AnvilBanner
@onready var anvil_title_lbl: Label = $VBox/ForgeView/AnvilBanner/BannerVBox/AnvilTitleLbl
@onready var anvil_sub_lbl: Label = $VBox/ForgeView/AnvilBanner/BannerVBox/AnvilSubLbl
@onready var slot_lbl: Label = $VBox/ForgeView/SlotHeaderLbl
@onready var slot_row: HBoxContainer = $VBox/ForgeView/SlotRow
@onready var wtype_box: VBoxContainer = $VBox/ForgeView/WeaponTypeBox
@onready var wtype_lbl: Label = $VBox/ForgeView/WeaponTypeBox/WTypeHeaderLbl
@onready var wtype_row: HBoxContainer = $VBox/ForgeView/WeaponTypeBox/WTypeRow
@onready var tier_lbl: Label = $VBox/ForgeView/TierHeaderLbl
@onready var tier_row: HBoxContainer = $VBox/ForgeView/TierRow
@onready var cost_panel: PanelContainer = $VBox/ForgeView/CostPanel
@onready var cost_lbl: Label = $VBox/ForgeView/CostPanel/CostVBox/CostLbl
@onready var wallet_lbl: Label = $VBox/ForgeView/CostPanel/CostVBox/WalletLbl
@onready var forge_btn: Button = $VBox/ForgeView/CostPanel/CostVBox/ForgeBtn
@onready var result_panel: PanelContainer = $VBox/ForgeView/ResultPanel
@onready var result_header_lbl: Label = $VBox/ForgeView/ResultPanel/ResultVBox/ResultHeaderLbl
@onready var result_card_row: HBoxContainer = $VBox/ForgeView/ResultPanel/ResultVBox/ResultCardRow
@onready var result_icon_frame: PanelContainer = $VBox/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultIconFrame
@onready var result_icon: TextureRect = $VBox/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultIconFrame/ResultIcon
@onready var result_name_lbl: Label = $VBox/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultInfoVBox/ResultNameLbl
@onready var result_meta_lbl: Label = $VBox/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultInfoVBox/ResultMetaLbl
@onready var result_affix_lbl: Label = $VBox/ForgeView/ResultPanel/ResultVBox/ResultCardRow/ResultInfoVBox/ResultAffixLbl
@onready var equip_now_btn: Button = $VBox/ForgeView/ResultPanel/ResultVBox/EquipNowBtn

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
	anvil_banner.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_BRONZE, 1, 5, 12, 8))
	cost_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_BRONZE, 1, 5, 12, 10))
	result_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 5, 14, 12))

	UiThemeBuilder.style_label(anvil_title_lbl, UiThemeBuilder.font_title(), 18, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(anvil_sub_lbl, UiThemeBuilder.font_body(), 14, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(slot_lbl, UiThemeBuilder.font_title(), 12, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(wtype_lbl, UiThemeBuilder.font_title(), 12, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(tier_lbl, UiThemeBuilder.font_title(), 12, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(cost_lbl, UiThemeBuilder.font_title(), 15, UiThemeBuilder.TEXT_PARCHMENT)
	UiThemeBuilder.style_label(wallet_lbl, UiThemeBuilder.font_body(), 14, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(result_header_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(result_name_lbl, UiThemeBuilder.font_title(), 18, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(result_meta_lbl, UiThemeBuilder.font_bold(), 14, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(result_affix_lbl, UiThemeBuilder.font_body(), 14, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(bestiary_header_lbl, UiThemeBuilder.font_title(), 14, UiThemeBuilder.TEXT_GOLD)

	UiThemeBuilder.style_cta_button(forge_btn, 18)
	UiThemeBuilder.style_cta_button(equip_now_btn, 15)

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
		btn.custom_minimum_size = Vector2(0, 82)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_selected.bind(sl))

		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 3)
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
		UiThemeBuilder.style_label(lbl, UiThemeBuilder.font_title(), 11, UiThemeBuilder.TEXT_PARCHMENT, 1)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lbl)

		slot_row.add_child(btn)
		_slot_btns[sl] = btn


func _build_wtype_buttons() -> void:
	for ch in wtype_row.get_children():
		ch.queue_free()
	_wtype_btns.clear()

	var specs := [
		{"wt": GameEnums.WeaponType.GREATSWORD, "name": "Greatsword"},
		{"wt": GameEnums.WeaponType.HALBERD, "name": "Halberd"},
		{"wt": GameEnums.WeaponType.SWORD_SHIELD, "name": "Sword & Shield"},
		{"wt": GameEnums.WeaponType.WAR_STAFF, "name": "War-Staff"},
	]
	for sp in specs:
		var wt: GameEnums.WeaponType = sp["wt"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(sp["name"])
		btn.pressed.connect(_on_wtype_selected.bind(wt))
		wtype_row.add_child(btn)
		_wtype_btns[wt] = btn


func _build_tier_buttons() -> void:
	for ch in tier_row.get_children():
		ch.queue_free()
	_tier_btns.clear()

	for t in range(1, 5):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 62)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tier_selected.bind(t))
		tier_row.add_child(btn)
		_tier_btns[t] = btn


func refresh_ui() -> void:
	UiThemeBuilder.style_tab_button(forge_toggle_btn, not _showing_bestiary, 15)
	UiThemeBuilder.style_tab_button(bestiary_toggle_btn, _showing_bestiary, 15)

	forge_view.visible = not _showing_bestiary
	bestiary_view.visible = _showing_bestiary

	if _showing_bestiary:
		_rebuild_bestiary()
		return

	var gs := _game_state()
	var max_t := _max_unlocked_tier(gs)
	if _selected_tier > max_t:
		_selected_tier = max_t

	for sl in _slot_btns:
		UiThemeBuilder.style_tab_button(_slot_btns[sl] as Button, sl == _selected_slot, 12)

	wtype_box.visible = (_selected_slot == GameEnums.Slot.WEAPON)
	for wt in _wtype_btns:
		UiThemeBuilder.style_tab_button(_wtype_btns[wt] as Button, wt == _selected_wtype, 12)

	var tier_subtitles := {1: "Worn Iron", 2: "Black Steel", 3: "Sovereign", 4: "Ashen"}
	for t in range(1, 5):
		var tbtn := _tier_btns[t] as Button
		var unlocked := (t <= max_t)
		tbtn.disabled = not unlocked
		if unlocked:
			tbtn.text = "TIER %d\n%s" % [t, str(tier_subtitles[t])]
		else:
			tbtn.text = "TIER %d\nLOCKED" % t
		UiThemeBuilder.style_tab_button(tbtn, (t == _selected_tier) and unlocked, 11)

	var cost := LootEngine.forge_cost(_selected_tier)
	var g_cost := int(cost["gold"])
	var s_cost := int(cost["scrap"])
	var cur_gold := int(gs.get("gold")) if gs != null else 0
	var cur_scrap := int(gs.get("scrap")) if gs != null else 0
	var can_afford := (cur_gold >= g_cost and cur_scrap >= s_cost)

	cost_lbl.text = "COST: %d GOLD  ·  %d SCRAP   (Guaranteed RARE+)" % [g_cost, s_cost]
	wallet_lbl.text = "Your Coffers: %d Gold  ·  %d Scrap" % [cur_gold, cur_scrap]
	wallet_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_READY if can_afford else UiThemeBuilder.TEXT_CRIMSON)
	forge_btn.disabled = not can_afford
	forge_btn.text = "FORGE TIER %d %s" % [_selected_tier, GameEnums.slot_name(_selected_slot).to_upper()]

	_refresh_forged_showcase(gs)


func _refresh_forged_showcase(gs: Node) -> void:
	if _last_forged_item != null and gs != null and gs.call("get_item", _last_forged_item.uid) == null:
		_last_forged_item = null

	if _last_forged_item == null:
		result_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 5, 14, 12))
		result_header_lbl.text = "ANVIL CHAMBER READY"
		result_icon_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_BRONZE, 1, 5, 6, 6))
		result_icon.texture = UiThemeBuilder.get_item_icon_by_key("zweihander" if _selected_slot == GameEnums.Slot.WEAPON else ("helm_plume" if _selected_slot == GameEnums.Slot.HELM else ("cuirass_plate" if _selected_slot == GameEnums.Slot.CUIRASS else "waist_lantern")))
		result_icon.modulate = Color(0.55, 0.55, 0.62, 0.75)
		result_name_lbl.text = "Strike the Soul Forge"
		result_name_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_MUTED)
		result_meta_lbl.text = "Choose a Relic Slot and Tier above to bind a guaranteed Rare, Epic, or Sovereign piece."
		result_affix_lbl.text = "• Forged relics roll 1 to 3 Barrow Affixes immediately.\n• Can be equipped or tempered right away."
		equip_now_btn.visible = false
		return

	var item := _last_forged_item
	var rcol := GameEnums.rarity_color(item.rarity)
	result_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS.lerp(rcol, 0.08), rcol, 2, 6, 14, 12))
	result_header_lbl.text = "NEWLY FORGED RELIC"
	result_icon_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, rcol, 2, 5, 6, 6))
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
	var hdef := GameRegistry.get_class_def(cid)
	var already_eq := bool(gs.call("is_item_equipped", item.uid)) if gs != null else false
	var compat := true
	if item.slot == GameEnums.Slot.WEAPON and hdef != null and not hdef.can_equip_weapon_type(item.weapon_type):
		compat = false

	if already_eq:
		equip_now_btn.text = "EQUIPPED ON %s" % (hdef.display_name.to_upper() if hdef != null else "HERO")
		equip_now_btn.disabled = true
	elif not compat:
		equip_now_btn.text = "INCOMPATIBLE WITH %s (SAVED TO SATCHEL)" % (hdef.display_name.to_upper() if hdef != null else "HERO")
		equip_now_btn.disabled = true
	else:
		equip_now_btn.text = "EQUIP NOW ON %s" % (hdef.display_name.to_upper() if hdef != null else "HERO")
		equip_now_btn.disabled = false


func _rebuild_bestiary() -> void:
	for ch in bestiary_list.get_children():
		ch.queue_free()

	var gs := _game_state()
	var ordered: Array[EnemyDef] = []
	for b in GameRegistry.get_boss_enemies():
		ordered.append(b)
	for e in GameRegistry.get_regular_enemies():
		ordered.append(e)

	for edef in ordered:
		var card := PanelContainer.new()
		var bdr := UiThemeBuilder.BORDER_GOLD if edef.is_boss else UiThemeBuilder.BORDER_SLATE
		var bg := UiThemeBuilder.BG_IRON.lerp(Color(0.28, 0.08, 0.08), 0.16) if edef.is_boss else UiThemeBuilder.BG_IRON
		card.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(bg, bdr, 2 if edef.is_boss else 1, 5, 10, 9))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)

		var pframe := PanelContainer.new()
		pframe.custom_minimum_size = Vector2(92, 92)
		pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pframe.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, bdr, 1, 4, 2, 2))
		hb.add_child(pframe)

		var ptex := TextureRect.new()
		ptex.texture = UiThemeBuilder.get_portrait(edef.enemy_id)
		ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pframe.add_child(ptex)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		hb.add_child(vb)

		var top := HBoxContainer.new()
		vb.add_child(top)

		var tag_prefix := "[BOSS] " if edef.is_boss else ""
		var nlbl := Label.new()
		nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nlbl.text = "%s%s" % [tag_prefix, edef.display_name]
		UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_title(), 15, UiThemeBuilder.TEXT_GOLD if edef.is_boss else UiThemeBuilder.TEXT_PARCHMENT)
		top.add_child(nlbl)

		var kills := UiThemeBuilder.get_bestiary_kills(gs, edef.enemy_id)
		var klbl := Label.new()
		klbl.text = "Slain: %d" % kills
		UiThemeBuilder.style_label(klbl, UiThemeBuilder.font_bold(), 13, UiThemeBuilder.TEXT_READY if kills > 0 else UiThemeBuilder.TEXT_MUTED, 1)
		top.add_child(klbl)

		var notes: Dictionary = UiThemeBuilder.BESTIARY_NOTES.get(edef.enemy_id, {})
		var sub_lore := Label.new()
		sub_lore.text = "%s — %s" % [edef.title, str(notes.get("lore", "Denizen of the Barrow Lands.")).strip_edges()]
		sub_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiThemeBuilder.style_label(sub_lore, UiThemeBuilder.font_body(), 13, UiThemeBuilder.TEXT_MUTED, 1)
		vb.add_child(sub_lore)

		var tip_lbl := Label.new()
		tip_lbl.text = str(notes.get("tip", "Watch enemy windups and dodge through strikes."))
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiThemeBuilder.style_label(tip_lbl, UiThemeBuilder.font_bold(), 13, UiThemeBuilder.TEXT_GOLD, 1)
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
