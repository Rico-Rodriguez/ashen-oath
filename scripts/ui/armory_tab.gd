class_name ArmoryTab
extends Control

enum BagFilter {
	ALL = 0,
	WEP = 1,
	ARM = 2,
	LNT = 3,
}

@onready var stage_3d: SanctuaryStage3D = $RootVBox/UpperStage/SanctuaryStage3D
@onready var upper_overlay: MarginContainer = $RootVBox/UpperStage/UpperOverlay
@onready var class_row: HBoxContainer = $RootVBox/UpperStage/UpperOverlay/UpperVBox/ClassRow
@onready var left_sockets_box: VBoxContainer = $RootVBox/UpperStage/UpperOverlay/UpperVBox/SocketsArea/LeftSockets
@onready var right_sockets_box: VBoxContainer = $RootVBox/UpperStage/UpperOverlay/UpperVBox/SocketsArea/RightSockets
@onready var stat_panel: PanelContainer = $RootVBox/UpperStage/UpperOverlay/UpperVBox/StatPanel
@onready var stat_row: HBoxContainer = $RootVBox/UpperStage/UpperOverlay/UpperVBox/StatPanel/StatRow

@onready var satchel_sheet: PanelContainer = $RootVBox/SatchelSheet
@onready var filter_pills_row: HBoxContainer = $RootVBox/SatchelSheet/SheetVBox/FilterRow/FilterPillsRow
@onready var salvage_commons_btn: Button = $RootVBox/SatchelSheet/SheetVBox/FilterRow/SalvageCommonsBtn
@onready var bag_grid: GridContainer = $RootVBox/SatchelSheet/SheetVBox/BagScroll/BagGrid

@onready var inspector_panel: PanelContainer = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel
@onready var insp_icon_frame: PanelContainer = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/HeaderRow/IconFrame
@onready var insp_icon: TextureRect = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/HeaderRow/IconFrame/IconTex
@onready var insp_name_lbl: Label = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/HeaderRow/TitleVBox/InspNameLbl
@onready var insp_meta_lbl: Label = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/HeaderRow/TitleVBox/InspMetaLbl
@onready var insp_badge_lbl: Label = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/HeaderRow/InspBadgeLbl
@onready var insp_stats_lbl: Label = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/DetailsRow/InspStatsLbl
@onready var delta_badges_box: VBoxContainer = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/DetailsRow/DeltaBadgesBox
@onready var equip_btn: Button = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/ActionsRow/EquipBtn
@onready var temper_btn: Button = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/ActionsRow/TemperBtn
@onready var salvage_btn: Button = $RootVBox/SatchelSheet/SheetVBox/InspectorPanel/InspVBox/ActionsRow/SalvageBtn

var _class_btns: Dictionary = {}
var _filter_btns: Dictionary = {}
var _socket_widgets: Dictionary = {}
var _stat_val_labels: Dictionary = {}
var _active_filter: BagFilter = BagFilter.ALL
var _selected_uid: String = ""
var _last_stage_signature: String = ""
var _chrome_insets: Dictionary = {"top": 92, "bottom": 100, "left": 0, "right": 0}


func _ready() -> void:
	stage_3d.set_stage_mode("armory")
	stat_panel.add_theme_stylebox_override(
		"panel",
		UiThemeBuilder.make_pill(Color(0.044, 0.048, 0.066, 0.80), Color(0.83, 0.66, 0.33, 0.45), 12, 6)
	)
	inspector_panel.add_theme_stylebox_override(
		"panel",
		UiThemeBuilder.make_glass_panel(Color(0.044, 0.048, 0.064, 0.86), Color(0.83, 0.66, 0.33, 0.48), 14, 12, 10)
	)
	_apply_sheet_margins()

	_build_class_pills()
	_build_filter_pills()
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


func apply_chrome_insets(insets: Dictionary) -> void:
	_chrome_insets = insets.duplicate()
	var top_px := int(insets.get("top", 92))
	var left_px := int(insets.get("left", 0))
	var right_px := int(insets.get("right", 0))
	upper_overlay.add_theme_constant_override("margin_top", top_px + 4)
	upper_overlay.add_theme_constant_override("margin_left", 12 + left_px)
	upper_overlay.add_theme_constant_override("margin_right", 12 + right_px)
	_apply_sheet_margins()


func _apply_sheet_margins() -> void:
	var bot_px := int(_chrome_insets.get("bottom", 100))
	var left_px := int(_chrome_insets.get("left", 0))
	var right_px := int(_chrome_insets.get("right", 0))
	var sheet_sb := UiThemeBuilder.make_sheet_panel(14 + left_px, 10)
	sheet_sb.content_margin_right = float(14 + right_px)
	sheet_sb.content_margin_bottom = float(bot_px + 8)
	satchel_sheet.add_theme_stylebox_override("panel", sheet_sb)


func select_item_uid(uid: String) -> void:
	_selected_uid = uid
	refresh_ui()


func _build_class_pills() -> void:
	for ch in class_row.get_children():
		ch.queue_free()
	_class_btns.clear()

	var short_titles := {
		"oathbreaker": "OATHBREAKER",
		"battlemage": "BATTLEMAGE",
		"revenant": "REVENANT",
	}
	for hdef in GameRegistry.get_all_classes():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 54)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(short_titles.get(hdef.class_id, hdef.display_name.to_upper()))
		btn.pressed.connect(_on_class_pill_pressed.bind(hdef.class_id))
		class_row.add_child(btn)
		_class_btns[hdef.class_id] = btn


func _build_filter_pills() -> void:
	for ch in filter_pills_row.get_children():
		ch.queue_free()
	_filter_btns.clear()

	var specs := [
		{"f": BagFilter.ALL, "txt": "ALL"},
		{"f": BagFilter.WEP, "txt": "WEP"},
		{"f": BagFilter.ARM, "txt": "ARM"},
		{"f": BagFilter.LNT, "txt": "LNT"},
	]
	for sp in specs:
		var f: BagFilter = sp["f"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(sp["txt"])
		btn.pressed.connect(_on_filter_pressed.bind(f))
		filter_pills_row.add_child(btn)
		_filter_btns[f] = btn


func _active_class_id(gs: Node) -> String:
	var cid := str(gs.get("selected_class_id")) if gs != null else "oathbreaker"
	return cid if GameRegistry.get_class_def(cid) != null else "oathbreaker"


func _build_stat_cells() -> void:
	for ch in stat_row.get_children():
		ch.queue_free()
	_stat_val_labels.clear()

	var keys := [
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
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var klbl := Label.new()
		klbl.text = str(pair[1])
		klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		klbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(klbl)

		var vlbl := Label.new()
		vlbl.text = "0"
		vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(vlbl)

		stat_row.add_child(vb)
		_stat_val_labels[str(pair[0])] = {"key": klbl, "val": vlbl}


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
	btn.custom_minimum_size = Vector2(112, 112)
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
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)

	var slbl := Label.new()
	slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slbl.text = slot_title
	slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(slbl)

	var tlbl := Label.new()
	tlbl.text = "T1"
	tlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tlbl)

	var icon_tex := TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(62, 62)
	icon_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_tex)

	var nlbl := Label.new()
	nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nlbl.clip_text = true
	nlbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nlbl)

	parent_box.add_child(btn)
	_socket_widgets[slot] = {
		"btn": btn,
		"slot_lbl": slbl,
		"tier_lbl": tlbl,
		"icon": icon_tex,
		"name_lbl": nlbl,
	}


func refresh_ui() -> void:
	var gs := _game_state()
	if gs == null:
		return

	var cid := _active_class_id(gs)
	var hdef := GameRegistry.get_class_def(cid)
	if hdef == null:
		return

	for k in _class_btns:
		UiThemeBuilder.style_pill_button(_class_btns[k] as Button, str(k) == cid, 14)

	for fk in _filter_btns:
		UiThemeBuilder.style_pill_button(_filter_btns[fk] as Button, int(fk) == int(_active_filter), 13)

	UiThemeBuilder.style_tab_button(salvage_commons_btn, false, 12)
	UiThemeBuilder.style_cta_button(equip_btn, 16)
	UiThemeBuilder.style_tab_button(temper_btn, false, 15)
	UiThemeBuilder.style_tab_button(salvage_btn, false, 15)

	var cstats: CombatStats = gs.call("get_combat_stats", cid)
	var stat_vals := {
		"hp": "%d" % roundi(cstats.max_hp),
		"atk": "%d" % roundi(cstats.attack_damage),
		"arm": "%d" % roundi(cstats.armor),
		"crit": "%d%%" % roundi(cstats.crit_chance * 100.0),
		"spd": "%.1f" % cstats.move_speed,
	}
	for sk in _stat_val_labels:
		var cell: Dictionary = _stat_val_labels[sk]
		UiThemeBuilder.style_label(cell["key"] as Label, UiThemeBuilder.font_title(), 11, UiThemeBuilder.TEXT_MUTED, 1)
		UiThemeBuilder.style_label(cell["val"] as Label, UiThemeBuilder.font_bold(), 17, UiThemeBuilder.TEXT_GOLD if sk == "atk" else UiThemeBuilder.TEXT_PARCHMENT, 1)
		(cell["val"] as Label).text = str(stat_vals.get(sk, "0"))

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
		var slbl: Label = sw["slot_lbl"]
		var tlbl: Label = sw["tier_lbl"]
		var itex: TextureRect = sw["icon"]
		var nlbl: Label = sw["name_lbl"]
		UiThemeBuilder.style_label(slbl, UiThemeBuilder.font_title(), 10, UiThemeBuilder.TEXT_MUTED, 1)
		if eq_item != null:
			var is_sel := (eq_item.uid == _selected_uid)
			UiThemeBuilder.style_rarity_tile(sbtn, eq_item.rarity, is_sel, 4)
			var temp_tag := "+%d" % eq_item.temper_level if eq_item.temper_level > 0 else ""
			tlbl.text = "T%d%s" % [eq_item.tier, temp_tag]
			UiThemeBuilder.style_label(tlbl, UiThemeBuilder.font_bold(), 11, GameEnums.rarity_color(eq_item.rarity), 1)
			itex.texture = UiThemeBuilder.get_item_icon(eq_item)
			nlbl.text = eq_item.display_name()
			UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_bold(), 11, GameEnums.rarity_color(eq_item.rarity).lightened(0.16), 1)

	_refresh_inspector(gs, hdef, cstats, equipped_dict, bag_items)
	_rebuild_bag_grid(hdef, equipped_dict, bag_items)

	var stage_sig := _equipped_visual_signature(cid, equipped_dict)
	if stage_3d != null and stage_sig != _last_stage_signature:
		_last_stage_signature = stage_sig
		stage_3d.refresh_hero()


static func _equipped_visual_signature(cid: String, equipped_dict: Dictionary) -> String:
	var parts := PackedStringArray([cid])
	for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
		var eq_item: EquipmentItem = equipped_dict.get(slot)
		parts.append(eq_item.uid if eq_item != null else "")
	return "|".join(parts)


func _matches_filter(item: EquipmentItem) -> bool:
	match _active_filter:
		BagFilter.WEP:
			return item.slot == GameEnums.Slot.WEAPON
		BagFilter.ARM:
			return item.slot == GameEnums.Slot.HELM or item.slot == GameEnums.Slot.CUIRASS
		BagFilter.LNT:
			return item.slot == GameEnums.Slot.LANTERN
		_:
			return true


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
	salvage_commons_btn.text = "SALVAGE COMMONS (%d)" % common_count
	salvage_commons_btn.disabled = (common_count == 0)

	for ch in delta_badges_box.get_children():
		ch.queue_free()

	UiThemeBuilder.style_label(insp_name_lbl, UiThemeBuilder.font_title(), 19, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(insp_meta_lbl, UiThemeBuilder.font_body(), 14, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(insp_badge_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(insp_stats_lbl, UiThemeBuilder.font_body(), 15, UiThemeBuilder.TEXT_PARCHMENT, 1)

	if item == null:
		insp_name_lbl.text = "Select a Relic"
		insp_meta_lbl.text = "Tap any socket or satchel tile"
		insp_badge_lbl.text = ""
		insp_stats_lbl.text = ""
		equip_btn.disabled = true
		temper_btn.disabled = true
		salvage_btn.disabled = true
		return

	var rcol := GameEnums.rarity_color(item.rarity)
	insp_icon_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, rcol, 2, 8, 3, 3))
	insp_icon.texture = UiThemeBuilder.get_item_icon(item)
	insp_name_lbl.text = item.display_name()
	insp_name_lbl.add_theme_color_override("font_color", rcol)

	var slot_txt := GameEnums.weapon_type_name(item.weapon_type) if item.slot == GameEnums.Slot.WEAPON else GameEnums.slot_name(item.slot)
	insp_meta_lbl.text = "%s · T%d %s · PWR %d" % [
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
		insp_badge_lbl.text = "EQUIPPED"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD)
	elif equipped_anywhere:
		insp_badge_lbl.text = "OTHER HERO"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_MUTED)
	elif not can_wield:
		insp_badge_lbl.text = "CLASS LOCKED"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_CRIMSON)
	else:
		insp_badge_lbl.text = "SATCHEL"
		insp_badge_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_READY)

	var lines: Array[String] = [UiThemeBuilder.format_item_primary_line(item)]
	for af in item.affixes:
		if af != null:
			lines.append("• " + af.format_line())
	insp_stats_lbl.text = "\n".join(lines)

	if equipped_on_active:
		_add_delta_badge("Temper %d / %d" % [item.temper_level, EquipmentItem.MAX_TEMPER_LEVEL], UiThemeBuilder.TEXT_GOLD, 19)
	elif not can_wield:
		_add_delta_badge("Wrong Class", UiThemeBuilder.TEXT_CRIMSON, 19)
	else:
		var sim_kit := equipped_dict.duplicate()
		sim_kit[item.slot] = item
		var sim_stats := LootEngine.compute_combat_stats(hdef, sim_kit)
		var d_pwr := item.power_score() - (eq_in_slot.power_score() if eq_in_slot != null else 0)
		var d_atk := roundi(sim_stats.attack_damage - cur_stats.attack_damage)
		var d_arm := roundi(sim_stats.armor - cur_stats.armor)
		var d_hp := roundi(sim_stats.max_hp - cur_stats.max_hp)

		if d_atk != 0:
			_add_delta_badge("%s %+d ATK" % ["▲" if d_atk > 0 else "▼", d_atk], UiThemeBuilder.TEXT_READY if d_atk > 0 else UiThemeBuilder.TEXT_CRIMSON, 21)
		if d_arm != 0:
			_add_delta_badge("%s %+d ARM" % ["▲" if d_arm > 0 else "▼", d_arm], UiThemeBuilder.TEXT_READY if d_arm > 0 else UiThemeBuilder.TEXT_CRIMSON, 20)
		if d_hp != 0:
			_add_delta_badge("%s %+d HP" % ["▲" if d_hp > 0 else "▼", d_hp], UiThemeBuilder.TEXT_READY if d_hp > 0 else UiThemeBuilder.TEXT_CRIMSON, 20)
		if d_atk == 0 and d_arm == 0 and d_hp == 0:
			_add_delta_badge("%s %+d PWR" % ["▲" if d_pwr >= 0 else "▼", d_pwr], UiThemeBuilder.TEXT_READY if d_pwr >= 0 else UiThemeBuilder.TEXT_CRIMSON, 20)

	equip_btn.disabled = equipped_anywhere or (not can_wield)
	equip_btn.text = "EQUIPPED" if equipped_on_active else "EQUIP"

	if item.temper_level >= EquipmentItem.MAX_TEMPER_LEVEL:
		temper_btn.text = "MAX +5"
		temper_btn.disabled = true
	else:
		var tcost := item.temper_gold_cost()
		temper_btn.text = "TEMPER %dg" % tcost
		temper_btn.disabled = int(gs.get("gold")) < tcost

	var scrap_val := item.salvage_scrap_value()
	salvage_btn.text = "SALVAGE +%d" % scrap_val
	salvage_btn.disabled = equipped_anywhere


func _add_delta_badge(text: String, col: Color, font_px: int = 20) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiThemeBuilder.style_label(lbl, UiThemeBuilder.font_bold(), font_px, col, 2)
	delta_badges_box.add_child(lbl)


func _rebuild_bag_grid(hdef: HeroClassDef, equipped_dict: Dictionary, bag_items: Array) -> void:
	for ch in bag_grid.get_children():
		ch.queue_free()

	var all_entries: Array[Dictionary] = []
	for slot in [GameEnums.Slot.WEAPON, GameEnums.Slot.HELM, GameEnums.Slot.CUIRASS, GameEnums.Slot.LANTERN]:
		var eq_it: Variant = equipped_dict.get(slot)
		if eq_it is EquipmentItem and _matches_filter(eq_it as EquipmentItem):
			all_entries.append({"item": eq_it, "equipped": true})
	for bi in bag_items:
		if bi is EquipmentItem and _matches_filter(bi as EquipmentItem):
			all_entries.append({"item": bi, "equipped": false})

	for entry in all_entries:
		var item: EquipmentItem = entry["item"]
		var is_eq: bool = bool(entry["equipped"])
		var is_sel := (item.uid == _selected_uid)

		var tile := Button.new()
		tile.custom_minimum_size = Vector2(148, 136)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiThemeBuilder.style_rarity_tile(tile, item.rarity, is_sel, 6)
		tile.pressed.connect(select_item_uid.bind(item.uid))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 7)
		margin.add_theme_constant_override("margin_right", 7)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(margin)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vb)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top)

		var t_lbl := Label.new()
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.text = "T%d%s" % [item.tier, ("+%d" % item.temper_level) if item.temper_level > 0 else ""]
		UiThemeBuilder.style_label(t_lbl, UiThemeBuilder.font_bold(), 13, GameEnums.rarity_color(item.rarity), 1)
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(t_lbl)

		var pip_lbl := Label.new()
		pip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_eq:
			pip_lbl.text = "EQ"
			UiThemeBuilder.style_label(pip_lbl, UiThemeBuilder.font_title(), 12, UiThemeBuilder.TEXT_GOLD, 1)
		else:
			var can_wield := true
			if item.slot == GameEnums.Slot.WEAPON and hdef != null and not hdef.can_equip_weapon_type(item.weapon_type):
				can_wield = false
			if not can_wield:
				pip_lbl.text = "LOCK"
				UiThemeBuilder.style_label(pip_lbl, UiThemeBuilder.font_bold(), 11, UiThemeBuilder.TEXT_MUTED, 1)
			else:
				var eq_slot: EquipmentItem = equipped_dict.get(item.slot)
				var delta_pwr := item.power_score() - (eq_slot.power_score() if eq_slot != null else 0)
				if delta_pwr > 0:
					pip_lbl.text = "▲"
					UiThemeBuilder.style_label(pip_lbl, UiThemeBuilder.font_bold(), 16, UiThemeBuilder.TEXT_READY, 2)
				elif delta_pwr < 0:
					pip_lbl.text = "▼"
					UiThemeBuilder.style_label(pip_lbl, UiThemeBuilder.font_bold(), 16, UiThemeBuilder.TEXT_CRIMSON, 2)
				else:
					pip_lbl.text = "•"
					UiThemeBuilder.style_label(pip_lbl, UiThemeBuilder.font_bold(), 14, UiThemeBuilder.TEXT_MUTED, 1)
		top.add_child(pip_lbl)

		var itex := TextureRect.new()
		itex.custom_minimum_size = Vector2(68, 68)
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
		UiThemeBuilder.style_label(p_lbl, UiThemeBuilder.font_bold(), 13, UiThemeBuilder.TEXT_PARCHMENT, 1)
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


func _on_filter_pressed(f: BagFilter) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	_active_filter = f
	refresh_ui()


func _on_socket_pressed(slot: GameEnums.Slot) -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	var gs := _game_state()
	if gs != null and gs.has_method("get_equipped_item"):
		var eq_it: EquipmentItem = gs.call("get_equipped_item", _active_class_id(gs), slot)
		if eq_it != null:
			_selected_uid = eq_it.uid
	refresh_ui()


func _on_equip_pressed() -> void:
	var gs := _game_state()
	if gs == null or _selected_uid == "":
		return
	var cid := _active_class_id(gs)
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
