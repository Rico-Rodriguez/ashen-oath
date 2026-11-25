class_name ArmoryTab
extends MarginContainer

@onready var class_row: HBoxContainer = $VBox/ClassRow
@onready var stat_panel: PanelContainer = $VBox/StatPanel
@onready var stat_row: HBoxContainer = $VBox/StatPanel/StatRow
@onready var left_sockets_box: VBoxContainer = $VBox/PaperDollRow/LeftSockets
@onready var stage_3d: SanctuaryStage3D = $VBox/PaperDollRow/SanctuaryStage3D
@onready var right_sockets_box: VBoxContainer = $VBox/PaperDollRow/RightSockets
@onready var inspector_panel: PanelContainer = $VBox/InspectorPanel
@onready var insp_icon_frame: PanelContainer = $VBox/InspectorPanel/InspVBox/HeaderRow/IconFrame
@onready var insp_icon: TextureRect = $VBox/InspectorPanel/InspVBox/HeaderRow/IconFrame/IconTex
@onready var insp_name_lbl: Label = $VBox/InspectorPanel/InspVBox/HeaderRow/TitleVBox/InspNameLbl
@onready var insp_meta_lbl: Label = $VBox/InspectorPanel/InspVBox/HeaderRow/TitleVBox/InspMetaLbl
@onready var insp_badge_lbl: Label = $VBox/InspectorPanel/InspVBox/HeaderRow/InspBadgeLbl
@onready var insp_stats_lbl: Label = $VBox/InspectorPanel/InspVBox/DetailsRow/InspStatsLbl
@onready var insp_delta_lbl: Label = $VBox/InspectorPanel/InspVBox/DetailsRow/InspDeltaLbl
@onready var equip_btn: Button = $VBox/InspectorPanel/InspVBox/ActionsRow/EquipBtn
@onready var temper_btn: Button = $VBox/InspectorPanel/InspVBox/ActionsRow/TemperBtn
@onready var salvage_btn: Button = $VBox/InspectorPanel/InspVBox/ActionsRow/SalvageBtn
@onready var salvage_commons_btn: Button = $VBox/InspectorPanel/InspVBox/ActionsRow/SalvageCommonsBtn
@onready var bag_panel: PanelContainer = $VBox/BagPanel
@onready var bag_header_lbl: Label = $VBox/BagPanel/BagVBox/BagHeaderRow/BagHeaderLbl
@onready var bag_hint_lbl: Label = $VBox/BagPanel/BagVBox/BagHeaderRow/BagHintLbl
@onready var bag_grid: GridContainer = $VBox/BagPanel/BagVBox/BagScroll/BagGrid

var _class_btns: Dictionary = {}
var _socket_widgets: Dictionary = {}
var _stat_val_labels: Dictionary = {}
var _selected_uid: String = ""


func _ready() -> void:
	stat_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_BRONZE, 1, 4, 8, 6))
	inspector_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_BRONZE, 1, 5, 10, 8))
	bag_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 5, 8, 8))

	UiThemeBuilder.style_label(insp_name_lbl, UiThemeBuilder.font_title(), 16, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(insp_meta_lbl, UiThemeBuilder.font_body(), 13, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(insp_badge_lbl, UiThemeBuilder.font_title(), 12, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(insp_stats_lbl, UiThemeBuilder.font_body(), 14, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(insp_delta_lbl, UiThemeBuilder.font_bold(), 14, UiThemeBuilder.TEXT_READY, 1)
	UiThemeBuilder.style_label(bag_header_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(bag_hint_lbl, UiThemeBuilder.font_body(), 12, UiThemeBuilder.TEXT_MUTED, 1)

	UiThemeBuilder.style_cta_button(equip_btn, 13)

	_build_class_pills()
	_build_stat_cells()
	_build_paper_doll_sockets()

	equip_btn.pressed.connect(_on_equip_pressed)
	temper_btn.pressed.connect(_on_temper_pressed)
	salvage_btn.pressed.connect(_on_salvage_pressed)
	salvage_commons_btn.pressed.connect(_on_salvage_commons_pressed)

	var gs := _game_state()
	if gs != null and not gs.profile_changed.is_connected(refresh_ui):
		gs.profile_changed.connect(refresh_ui)

	refresh_ui()


func select_item_uid(uid: String) -> void:
	_selected_uid = uid
	refresh_ui()


func _build_class_pills() -> void:
	for ch in class_row.get_children():
		ch.queue_free()
	_class_btns.clear()
	class_row.visible = false


func _build_stat_cells() -> void:
	for ch in stat_row.get_children():
		ch.queue_free()
	_stat_val_labels.clear()

	var keys := [
		["pwr", "PWR"],
		["hp", "HP"],
		["atk", "ATK"],
		["arm", "ARM"],
		["crit", "CRIT"],
		["spd", "SPD"],
	]
	for pair in keys:
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 0)
		var klbl := Label.new()
		klbl.text = str(pair[1])
		klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiThemeBuilder.style_label(klbl, UiThemeBuilder.font_title(), 10, UiThemeBuilder.TEXT_MUTED, 1)
		vb.add_child(klbl)

		var vlbl := Label.new()
		vlbl.text = "0"
		vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var col := UiThemeBuilder.TEXT_GOLD if str(pair[0]) == "pwr" else UiThemeBuilder.TEXT_PARCHMENT
		UiThemeBuilder.style_label(vlbl, UiThemeBuilder.font_bold(), 15, col, 1)
		vb.add_child(vlbl)

		stat_row.add_child(vb)
		_stat_val_labels[str(pair[0])] = vlbl


func _build_paper_doll_sockets() -> void:
	for ch in left_sockets_box.get_children():
		ch.queue_free()
	for ch in right_sockets_box.get_children():
		ch.queue_free()
	_socket_widgets.clear()

	_create_socket(left_sockets_box, GameEnums.Slot.WEAPON, "WEAPON")
	_create_socket(left_sockets_box, GameEnums.Slot.HELM, "HELM")
	_create_socket(right_sockets_box, GameEnums.Slot.CUIRASS, "CUIRASS")
	_create_socket(right_sockets_box, GameEnums.Slot.LANTERN, "LANTERN")


func _create_socket(parent_box: VBoxContainer, slot: GameEnums.Slot, slot_title: String) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(126, 148)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_socket_pressed.bind(slot))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)

	var slbl := Label.new()
	slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slbl.text = slot_title
	UiThemeBuilder.style_label(slbl, UiThemeBuilder.font_title(), 10, UiThemeBuilder.TEXT_MUTED, 1)
	slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(slbl)

	var tlbl := Label.new()
	tlbl.text = "T1"
	UiThemeBuilder.style_label(tlbl, UiThemeBuilder.font_bold(), 11, UiThemeBuilder.TEXT_GOLD, 1)
	tlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tlbl)

	var icon_tex := TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(70, 70)
	icon_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_tex)

	var nlbl := Label.new()
	nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nlbl.max_lines_visible = 2
	UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_bold(), 12, UiThemeBuilder.TEXT_PARCHMENT, 1)
	nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nlbl)

	parent_box.add_child(btn)
	_socket_widgets[slot] = {
		"btn": btn,
		"tier_lbl": tlbl,
		"icon": icon_tex,
		"name_lbl": nlbl,
	}


func refresh_ui() -> void:
	var gs := _game_state()
	if gs == null:
		return

	var cid := "oathbreaker"
	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null:
		return

	for k in _class_btns:
		UiThemeBuilder.style_tab_button(_class_btns[k] as Button, str(k) == cid, 12)

	var cstats: CombatStats = gs.call("get_combat_stats", cid)
	var pwr: int = int(gs.call("get_class_power_score", cid))
	(_stat_val_labels["pwr"] as Label).text = "%d" % pwr
	(_stat_val_labels["hp"] as Label).text = "%d" % roundi(cstats.max_hp)
	(_stat_val_labels["atk"] as Label).text = "%d" % roundi(cstats.attack_damage)
	(_stat_val_labels["arm"] as Label).text = "%d" % roundi(cstats.armor)
	(_stat_val_labels["crit"] as Label).text = "%d%%" % roundi(cstats.crit_chance * 100.0)
	(_stat_val_labels["spd"] as Label).text = "%.1f" % cstats.move_speed

	var equipped_dict: Dictionary = gs.call("get_equipped", cid)
	var bag_items: Array = gs.get("inventory") if gs.get("inventory") is Array else []

	if _selected_uid == "" or gs.call("get_item", _selected_uid) == null:
		if not bag_items.is_empty() and bag_items[0] is EquipmentItem:
			_selected_uid = (bag_items[0] as EquipmentItem).uid
		else:
			var w_eq: EquipmentItem = equipped_dict.get(GameEnums.Slot.WEAPON)
			_selected_uid = w_eq.uid if w_eq != null else ""

	for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
		var sw: Dictionary = _socket_widgets[slot]
		var eq_item: EquipmentItem = equipped_dict.get(slot)
		var sbtn: Button = sw["btn"]
		var tlbl: Label = sw["tier_lbl"]
		var itex: TextureRect = sw["icon"]
		var nlbl: Label = sw["name_lbl"]
		if eq_item != null:
			var is_sel := (eq_item.uid == _selected_uid)
			UiThemeBuilder.style_rarity_tile(sbtn, eq_item.rarity, is_sel, 5)
			var temp_tag := " +%d" % eq_item.temper_level if eq_item.temper_level > 0 else ""
			tlbl.text = "T%d%s" % [eq_item.tier, temp_tag]
			tlbl.add_theme_color_override("font_color", GameEnums.rarity_color(eq_item.rarity))
			itex.texture = UiThemeBuilder.get_item_icon(eq_item)
			nlbl.text = eq_item.display_name()
			nlbl.add_theme_color_override("font_color", GameEnums.rarity_color(eq_item.rarity).lightened(0.18))

	_refresh_inspector(gs, hdef, cstats, equipped_dict, bag_items)
	_rebuild_bag_grid(equipped_dict, bag_items)
	if stage_3d != null:
		stage_3d.refresh_hero()


func _refresh_inspector(
	gs: Node,
	hdef: HeroClassDef,
	cur_stats: CombatStats,
	equipped_dict: Dictionary,
	bag_items: Array
) -> void:
	var item: EquipmentItem = gs.call("get_item", _selected_uid)
	var common_count := 0
	for bi in bag_items:
		if bi is EquipmentItem and (bi as EquipmentItem).rarity == GameEnums.Rarity.COMMON:
			common_count += 1
	salvage_commons_btn.text = "SALVAGE COMMON (%d)" % common_count
	salvage_commons_btn.disabled = (common_count == 0)

	if item == null:
		insp_name_lbl.text = "Select a Relic"
		insp_meta_lbl.text = "Tap any socket or satchel tile"
		insp_badge_lbl.text = ""
		insp_stats_lbl.text = ""
		insp_delta_lbl.text = ""
		equip_btn.disabled = true
		temper_btn.disabled = true
		salvage_btn.disabled = true
		return

	var rcol := GameEnums.rarity_color(item.rarity)
	insp_icon_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, rcol, 2, 4, 3, 3))
	insp_icon.texture = UiThemeBuilder.get_item_icon(item)
	insp_name_lbl.text = item.display_name()
	insp_name_lbl.add_theme_color_override("font_color", rcol)

	var slot_txt := GameEnums.weapon_type_name(item.weapon_type) if item.slot == GameEnums.Slot.WEAPON else GameEnums.slot_name(item.slot)
	insp_meta_lbl.text = "%s  ·  Tier %d %s  ·  PWR %d" % [
		GameEnums.rarity_name(item.rarity),
		item.tier,
		slot_txt,
		item.power_score(),
	]

	var eq_in_slot: EquipmentItem = equipped_dict.get(item.slot)
	var equipped_on_active := (eq_in_slot != null and eq_in_slot.uid == item.uid)
	var equipped_anywhere := bool(gs.call("is_item_equipped", item.uid))
	var can_wield := true
	if item.slot == GameEnums.Slot.WEAPON and not hdef.can_equip_weapon_type(item.weapon_type):
		can_wield = false

	if equipped_on_active:
		insp_badge_lbl.text = "[EQUIPPED]"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD)
	elif equipped_anywhere:
		insp_badge_lbl.text = "[WORN BY OTHER]"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_MUTED)
	elif not can_wield:
		insp_badge_lbl.text = "[CLASS LOCKED]"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_CRIMSON)
	else:
		insp_badge_lbl.text = "[IN SATCHEL]"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_READY)

	var lines: Array[String] = [UiThemeBuilder.format_item_primary_line(item)]
	for af in item.affixes:
		if af != null:
			lines.append("• " + af.format_line())
	insp_stats_lbl.text = "\n".join(lines)

	if equipped_on_active:
		insp_delta_lbl.text = "Active Relic\nTemper %d / %d" % [item.temper_level, EquipmentItem.MAX_TEMPER_LEVEL]
		insp_delta_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD)
	elif not can_wield:
		insp_delta_lbl.text = "%s cannot\nwield %s" % [hdef.display_name, GameEnums.weapon_type_name(item.weapon_type)]
		insp_delta_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_CRIMSON)
	else:
		var sim_kit := equipped_dict.duplicate()
		sim_kit[item.slot] = item
		var sim_stats := LootEngine.compute_combat_stats(hdef, sim_kit)
		var d_pwr := item.power_score() - (eq_in_slot.power_score() if eq_in_slot != null else 0)
		var d_atk := roundi(sim_stats.attack_damage - cur_stats.attack_damage)
		var d_arm := roundi(sim_stats.armor - cur_stats.armor)
		var d_hp := roundi(sim_stats.max_hp - cur_stats.max_hp)

		var d_parts: Array[String] = []
		d_parts.append("vs Equipped: %+d PWR" % d_pwr)
		if d_atk != 0:
			d_parts.append("%+d ATK" % d_atk)
		if d_arm != 0:
			d_parts.append("%+d ARM" % d_arm)
		if d_hp != 0:
			d_parts.append("%+d HP" % d_hp)
		insp_delta_lbl.text = "\n".join(d_parts)
		insp_delta_lbl.add_theme_color_override(
			"font_color",
			UiThemeBuilder.TEXT_READY if d_pwr >= 0 else UiThemeBuilder.TEXT_CRIMSON
		)

	equip_btn.disabled = equipped_anywhere or (not can_wield)
	equip_btn.text = "EQUIPPED" if equipped_on_active else "EQUIP"

	if item.temper_level >= EquipmentItem.MAX_TEMPER_LEVEL:
		temper_btn.text = "MAX +5"
		temper_btn.disabled = true
	else:
		var tcost := item.temper_gold_cost()
		temper_btn.text = "TEMPER (%dg)" % tcost
		temper_btn.disabled = int(gs.get("gold")) < tcost

	var scrap_val := item.salvage_scrap_value()
	salvage_btn.text = "SALVAGE (+%d)" % scrap_val
	salvage_btn.disabled = equipped_anywhere


func _rebuild_bag_grid(equipped_dict: Dictionary, bag_items: Array) -> void:
	for ch in bag_grid.get_children():
		ch.queue_free()

	var all_entries: Array[Dictionary] = []
	for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
		var eq_it: Variant = equipped_dict.get(slot)
		if eq_it is EquipmentItem:
			all_entries.append({"item": eq_it, "equipped": true})
	for bi in bag_items:
		if bi is EquipmentItem:
			all_entries.append({"item": bi, "equipped": false})

	bag_header_lbl.text = "OWNED RELICS (%d)  ·  %d IN SATCHEL" % [all_entries.size(), bag_items.size()]

	for entry in all_entries:
		var item: EquipmentItem = entry["item"]
		var is_eq: bool = bool(entry["equipped"])
		var is_sel := (item.uid == _selected_uid)

		var tile := Button.new()
		tile.custom_minimum_size = Vector2(118, 108)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiThemeBuilder.style_rarity_tile(tile, item.rarity, is_sel, 5)
		tile.pressed.connect(select_item_uid.bind(item.uid))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 5)
		margin.add_theme_constant_override("margin_right", 5)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(margin)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vb)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top)

		var t_lbl := Label.new()
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.text = "T%d%s" % [item.tier, (" +%d" % item.temper_level) if item.temper_level > 0 else ""]
		UiThemeBuilder.style_label(t_lbl, UiThemeBuilder.font_bold(), 11, GameEnums.rarity_color(item.rarity), 1)
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(t_lbl)

		if is_eq:
			var eq_lbl := Label.new()
			eq_lbl.text = "✓ EQ"
			UiThemeBuilder.style_label(eq_lbl, UiThemeBuilder.font_bold(), 11, UiThemeBuilder.TEXT_GOLD, 1)
			eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.add_child(eq_lbl)

		var itex := TextureRect.new()
		itex.custom_minimum_size = Vector2(56, 56)
		itex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		itex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		itex.texture = UiThemeBuilder.get_item_icon(item)
		itex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		itex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		itex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(itex)

		var p_lbl := Label.new()
		p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_lbl.text = "PWR %d" % item.power_score()
		UiThemeBuilder.style_label(p_lbl, UiThemeBuilder.font_bold(), 11, UiThemeBuilder.TEXT_PARCHMENT, 1)
		p_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(p_lbl)

		bag_grid.add_child(tile)


func _on_class_pill_pressed(cid: String) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_press")
	var gs := _game_state()
	if gs != null and gs.has_method("select_class"):
		gs.call("select_class", cid)
	refresh_ui()


func _on_socket_pressed(slot: GameEnums.Slot) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	var gs := _game_state()
	if gs != null and gs.has_method("get_equipped_item"):
		var eq_it: EquipmentItem = gs.call("get_equipped_item", "oathbreaker", slot)
		if eq_it != null:
			_selected_uid = eq_it.uid
	refresh_ui()


func _on_equip_pressed() -> void:
	var gs := _game_state()
	if gs == null or _selected_uid == "":
		return
	var cid := "oathbreaker"
	if bool(gs.call("equip_item", cid, _selected_uid)):
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "gear_equip")
	else:
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "ui_error")
	refresh_ui()


func _on_temper_pressed() -> void:
	var gs := _game_state()
	if gs == null or _selected_uid == "":
		return
	if bool(gs.call("temper_item", _selected_uid)):
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "sparkle")
			ad.call("sfx", "gear_equip")
	else:
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "ui_error")
	refresh_ui()


func _on_salvage_pressed() -> void:
	var gs := _game_state()
	if gs == null or _selected_uid == "":
		return
	var gained := int(gs.call("salvage_item", _selected_uid))
	if gained > 0:
		_selected_uid = ""
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "coin")
	refresh_ui()


func _on_salvage_commons_pressed() -> void:
	var gs := _game_state()
	if gs == null:
		return
	var bag_items: Array = gs.get("inventory") if gs.get("inventory") is Array else []
	var uids: Array[String] = []
	for bi in bag_items:
		if bi is EquipmentItem and (bi as EquipmentItem).rarity == GameEnums.Rarity.COMMON:
			uids.append((bi as EquipmentItem).uid)
	var total := 0
	for u in uids:
		total += int(gs.call("salvage_item", u))
	if total > 0:
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "coin")
	refresh_ui()


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
