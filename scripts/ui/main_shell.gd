class_name MainShell
extends Control

enum Tab {
	SANCTUM = 0,
	ARMORY = 1,
	FORGE = 2,
}

const ARENA_SCENE_PATH := "res://scenes/combat/arena_run.tscn"
const COMBAT_HUD_SCENE_PATH := "res://scenes/ui/combat_hud.tscn"
const HEADER_CONTENT_H := 72
const NAV_CONTENT_H := 82

@onready var combat_world_mount: Node = $CombatWorldMount
@onready var hub_layer: Control = $HubLayer
@onready var top_scrim: TextureRect = $HubLayer/TopScrim
@onready var header_overlay: MarginContainer = $HubLayer/HeaderOverlay
@onready var brand_lbl: Label = $HubLayer/HeaderOverlay/HeaderRow/BrandLbl
@onready var power_pill: PanelContainer = $HubLayer/HeaderOverlay/HeaderRow/PowerPill
@onready var power_lbl: Label = $HubLayer/HeaderOverlay/HeaderRow/PowerPill/PowerLbl
@onready var gold_pill: PanelContainer = $HubLayer/HeaderOverlay/HeaderRow/GoldPill
@onready var gold_icon: TextureRect = $HubLayer/HeaderOverlay/HeaderRow/GoldPill/GoldRow/GoldIcon
@onready var gold_lbl: Label = $HubLayer/HeaderOverlay/HeaderRow/GoldPill/GoldRow/GoldLbl
@onready var scrap_pill: PanelContainer = $HubLayer/HeaderOverlay/HeaderRow/ScrapPill
@onready var scrap_icon: TextureRect = $HubLayer/HeaderOverlay/HeaderRow/ScrapPill/ScrapRow/ScrapIcon
@onready var scrap_lbl: Label = $HubLayer/HeaderOverlay/HeaderRow/ScrapPill/ScrapRow/ScrapLbl
@onready var settings_btn: Button = $HubLayer/HeaderOverlay/HeaderRow/SettingsBtn

@onready var hunt_tab: HuntTab = $HubLayer/TabStack/HuntTab
@onready var armory_tab: ArmoryTab = $HubLayer/TabStack/ArmoryTab
@onready var forge_tab: ForgeTab = $HubLayer/TabStack/ForgeTab

@onready var nav_panel: PanelContainer = $HubLayer/NavDockPanel
@onready var nav_sanctum_btn: Button = $HubLayer/NavDockPanel/NavRow/NavSanctumBtn
@onready var nav_armory_btn: Button = $HubLayer/NavDockPanel/NavRow/NavArmoryBtn
@onready var nav_forge_btn: Button = $HubLayer/NavDockPanel/NavRow/NavForgeBtn

@onready var settings_modal: SettingsModal = $HubLayer/SettingsModal

var active_tab: Tab = Tab.SANCTUM
var active_arena: CombatDirector = null
var active_hud: CombatHud = null
var _last_run_params: Dictionary = {}
var _nav_widgets: Dictionary = {}
var _chrome_insets: Dictionary = {"top": 94, "bottom": 96, "left": 0, "right": 0}


func _ready() -> void:
	theme = UiThemeBuilder.get_theme()
	_build_nav_button_contents()
	_build_settings_button_content()
	_style_shell_chrome()

	nav_sanctum_btn.pressed.connect(switch_tab.bind(Tab.SANCTUM))
	nav_armory_btn.pressed.connect(switch_tab.bind(Tab.ARMORY))
	nav_forge_btn.pressed.connect(switch_tab.bind(Tab.FORGE))
	settings_btn.pressed.connect(_on_settings_pressed)
	settings_modal.visibility_changed.connect(_sync_sanctuary_stages_for_modal)
	settings_modal.closed.connect(_sync_sanctuary_stages_for_modal)
	settings_modal.settings_updated.connect(_on_settings_updated)
	hunt_tab.embark_requested.connect(start_expedition)

	var gs := _game_state()
	if gs != null:
		var saved_cid := str(gs.get("selected_class_id"))
		if GameRegistry.get_class_def(saved_cid) == null and gs.has_method("select_class"):
			gs.call("select_class", "oathbreaker")
		if not gs.profile_changed.is_connected(refresh_header):
			gs.profile_changed.connect(refresh_header)

	var ad := _audio()
	if ad != null:
		ad.call("music", "home")

	resized.connect(_apply_safe_margins)
	_apply_safe_margins()

	switch_tab(Tab.SANCTUM)
	refresh_header()


func _exit_tree() -> void:
	_teardown_combat_immediately()


func get_hub_chrome_insets() -> Dictionary:
	return _chrome_insets.duplicate()


func _build_settings_button_content() -> void:
	for ch in settings_btn.get_children():
		ch.queue_free()
	settings_btn.text = ""
	var gear_tex := UiThemeBuilder.get_ui_icon("gear")
	if gear_tex != null:
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		settings_btn.add_child(cc)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.texture = gear_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = UiThemeBuilder.TEXT_GOLD
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(icon)
	else:
		settings_btn.text = "CFG"


func _build_nav_button_contents() -> void:
	_nav_widgets.clear()
	var specs := [
		{"tab": Tab.SANCTUM, "btn": nav_sanctum_btn, "title": "SANCTUM", "icon": "home"},
		{"tab": Tab.ARMORY, "btn": nav_armory_btn, "title": "ARMORY", "icon": "sword"},
		{"tab": Tab.FORGE, "btn": nav_forge_btn, "title": "FORGE", "icon": "book_open"},
	]
	for sp in specs:
		var btn: Button = sp["btn"]
		for ch in btn.get_children():
			ch.queue_free()
		btn.text = ""
		btn.custom_minimum_size = Vector2(0, 78)

		var accent := ColorRect.new()
		accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		accent.offset_left = 18.0
		accent.offset_right = -18.0
		accent.offset_top = 0.0
		accent.offset_bottom = 3.0
		accent.color = UiThemeBuilder.BORDER_GOLD
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(accent)

		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 5)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		var icon_tex := TextureRect.new()
		icon_tex.custom_minimum_size = Vector2(28, 28)
		icon_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_tex.texture = UiThemeBuilder.get_ui_icon(str(sp["icon"]))
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon_tex)

		var lbl := Label.new()
		lbl.text = str(sp["title"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lbl)

		_nav_widgets[sp["tab"]] = {
			"btn": btn,
			"accent": accent,
			"icon": icon_tex,
			"lbl": lbl,
		}


func _style_shell_chrome() -> void:
	top_scrim.texture = UiThemeBuilder.make_scrim_texture(true, 0.84, 0.36)

	power_pill.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.055, 0.052, 0.072, 0.84), Color(0.83, 0.66, 0.33, 0.58), 11, 6))
	gold_pill.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.055, 0.058, 0.078, 0.82), Color(0.68, 0.54, 0.26, 0.48), 11, 6))
	scrap_pill.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.055, 0.058, 0.078, 0.82), Color(0.42, 0.44, 0.52, 0.45), 11, 6))

	var gem_tex := UiThemeBuilder.get_fx_icon("gem")
	if gem_tex != null:
		gold_icon.texture = gem_tex
		gold_icon.modulate = Color(1.0, 0.84, 0.34, 1.0)
		gold_icon.visible = true
	else:
		gold_icon.visible = false

	var pouch_tex := UiThemeBuilder.get_ui_icon("pouch")
	if pouch_tex != null:
		scrap_icon.texture = pouch_tex
		scrap_icon.modulate = UiThemeBuilder.TEXT_PARCHMENT
		scrap_icon.visible = true
	else:
		scrap_icon.visible = false

	UiThemeBuilder.style_label(brand_lbl, UiThemeBuilder.font_title(), 21, UiThemeBuilder.TEXT_GOLD, 3)
	UiThemeBuilder.style_label(power_lbl, UiThemeBuilder.font_title(), 14, UiThemeBuilder.TEXT_GOLD, 2)
	UiThemeBuilder.style_label(gold_lbl, UiThemeBuilder.font_bold(), 16, UiThemeBuilder.TEXT_GOLD, 2)
	UiThemeBuilder.style_label(scrap_lbl, UiThemeBuilder.font_bold(), 16, UiThemeBuilder.TEXT_PARCHMENT, 2)

	var s_n := UiThemeBuilder.make_box(Color(0.055, 0.060, 0.082, 0.80), Color(0.83, 0.66, 0.33, 0.55), 1, 36, 0, 0)
	s_n.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	s_n.shadow_size = 6
	var s_h := UiThemeBuilder.make_box(Color(0.11, 0.115, 0.15, 0.90), UiThemeBuilder.BORDER_GOLD, 2, 36, 0, 0)
	var s_p := UiThemeBuilder.make_box(Color(0.18, 0.10, 0.08, 0.94), UiThemeBuilder.BORDER_GOLD, 2, 36, 0, 0)
	settings_btn.add_theme_stylebox_override("normal", s_n)
	settings_btn.add_theme_stylebox_override("hover", s_h)
	settings_btn.add_theme_stylebox_override("focus", s_h)
	settings_btn.add_theme_stylebox_override("pressed", s_p)

	_apply_safe_margins()
	_refresh_nav_styles()


func _refresh_nav_styles() -> void:
	for t in _nav_widgets:
		var w: Dictionary = _nav_widgets[t]
		var is_active := (int(t) == int(active_tab))
		var btn: Button = w["btn"]
		var accent: ColorRect = w["accent"]
		var icon: TextureRect = w["icon"]
		var lbl: Label = w["lbl"]

		var bg := Color(0.14, 0.105, 0.082, 0.82) if is_active else Color(0.05, 0.055, 0.072, 0.0)
		var bdr := Color(0.83, 0.66, 0.33, 0.45) if is_active else Color(0.0, 0.0, 0.0, 0.0)
		var sb := UiThemeBuilder.make_box(bg, bdr, 1 if is_active else 0, 12, 8, 6)
		var sb_h := UiThemeBuilder.make_box(Color(0.12, 0.11, 0.13, 0.72), Color(0.83, 0.66, 0.33, 0.42), 1, 12, 8, 6)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("focus", sb_h)
		btn.add_theme_stylebox_override("pressed", sb)

		accent.visible = is_active
		icon.modulate = UiThemeBuilder.TEXT_GOLD if is_active else UiThemeBuilder.TEXT_MUTED
		UiThemeBuilder.style_label(lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD if is_active else UiThemeBuilder.TEXT_MUTED, 1)


func _apply_safe_margins() -> void:
	var m := UiThemeBuilder.get_safe_margins(self)
	var top_pad := int(m["top"])
	var bot_pad := int(m["bottom"])
	var left_pad := int(m["left"])
	var right_pad := int(m["right"])

	header_overlay.add_theme_constant_override("margin_top", top_pad + 4)
	header_overlay.add_theme_constant_override("margin_bottom", 4)
	header_overlay.add_theme_constant_override("margin_left", 14 + left_pad)
	header_overlay.add_theme_constant_override("margin_right", 14 + right_pad)
	var header_total_h := top_pad + 4 + HEADER_CONTENT_H + 4
	header_overlay.offset_bottom = float(header_total_h)
	top_scrim.offset_bottom = float(header_total_h + 76)

	var n_box := UiThemeBuilder.make_sheet_panel(12 + left_pad, 6)
	n_box.content_margin_right = float(12 + right_pad)
	n_box.content_margin_bottom = float(6 + bot_pad)
	n_box.content_margin_top = 6.0
	nav_panel.add_theme_stylebox_override("panel", n_box)
	var nav_total_h := NAV_CONTENT_H + bot_pad + 12
	nav_panel.custom_minimum_size.y = float(nav_total_h)
	nav_panel.offset_top = -float(nav_total_h)
	nav_panel.offset_bottom = 0.0

	_chrome_insets = {
		"top": header_total_h,
		"bottom": nav_total_h,
		"left": left_pad,
		"right": right_pad,
	}
	_notify_tabs_insets()


func _notify_tabs_insets() -> void:
	for tab_node in [hunt_tab, armory_tab, forge_tab]:
		if tab_node != null and tab_node.has_method("apply_chrome_insets"):
			tab_node.call("apply_chrome_insets", _chrome_insets)


func switch_tab(tab: Tab) -> void:
	if active_tab != tab:
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "ui_tap")
	active_tab = tab
	hunt_tab.visible = (tab == Tab.SANCTUM)
	armory_tab.visible = (tab == Tab.ARMORY)
	forge_tab.visible = (tab == Tab.FORGE)

	_refresh_nav_styles()
	_notify_tabs_insets()

	match tab:
		Tab.SANCTUM:
			hunt_tab.refresh_ui()
		Tab.ARMORY:
			armory_tab.refresh_ui()
		Tab.FORGE:
			forge_tab.refresh_ui()
	refresh_header()


func refresh_header() -> void:
	var gs := _game_state()
	if gs == null:
		return
	var cid := str(gs.get("selected_class_id"))
	var pwr := int(gs.call("get_class_power_score", cid)) if gs.has_method("get_class_power_score") else 140
	power_lbl.text = "PWR %d" % pwr
	gold_lbl.text = "%d" % int(gs.get("gold"))
	scrap_lbl.text = "%d" % int(gs.get("scrap"))


func start_expedition(class_id: String = "", zone_id: String = "", difficulty: int = -1, seed_val: int = 0) -> CombatDirector:
	_teardown_combat_immediately()

	var gs := _game_state()
	var cid := class_id if class_id != "" else (str(gs.get("selected_class_id")) if gs != null else "oathbreaker")
	var zid := zone_id if zone_id != "" else (str(gs.get("selected_zone_id")) if gs != null else "fringe")
	var diff := difficulty if difficulty >= 0 else (int(gs.get("selected_difficulty")) if gs != null else 0)

	_last_run_params = {"class_id": cid, "zone_id": zid, "difficulty": diff}

	hub_layer.visible = false
	settings_modal.visible = false

	var arena_ps := load(ARENA_SCENE_PATH) as PackedScene
	var hud_ps := load(COMBAT_HUD_SCENE_PATH) as PackedScene
	if arena_ps == null or hud_ps == null:
		hub_layer.visible = true
		return null

	active_arena = arena_ps.instantiate() as CombatDirector
	active_arena.auto_start_from_game_state = false
	combat_world_mount.add_child(active_arena)

	active_hud = hud_ps.instantiate() as CombatHud
	combat_world_mount.add_child(active_hud)
	active_hud.return_to_sanctum_requested.connect(return_to_sanctum)
	active_hud.hunt_again_requested.connect(_on_hunt_again)

	active_arena.start_run(cid, zid, diff, seed_val)
	active_hud.bind_director(active_arena)

	var ad := _audio()
	if ad != null:
		ad.call("music", "hunt")

	return active_arena


func return_to_sanctum() -> void:
	_teardown_combat_immediately()
	hub_layer.visible = true
	switch_tab(active_tab)
	refresh_header()
	var ad := _audio()
	if ad != null:
		ad.call("music", "home")


func _on_hunt_again() -> void:
	var cid := str(_last_run_params.get("class_id", ""))
	var zid := str(_last_run_params.get("zone_id", ""))
	var diff := int(_last_run_params.get("difficulty", -1))
	start_expedition(cid, zid, diff, 0)


func _teardown_combat_immediately() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
	if active_hud != null and is_instance_valid(active_hud):
		if active_hud.get_parent() != null:
			active_hud.get_parent().remove_child(active_hud)
		active_hud.queue_free()
	active_hud = null

	if active_arena != null and is_instance_valid(active_arena):
		if active_arena.get_parent() != null:
			active_arena.get_parent().remove_child(active_arena)
		active_arena.queue_free()
	active_arena = null


func _on_settings_pressed() -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_tap")
	settings_modal.open_modal()
	_sync_sanctuary_stages_for_modal()


func _on_settings_updated() -> void:
	_style_shell_chrome()
	if hunt_tab != null:
		hunt_tab.refresh_ui()
	if armory_tab != null:
		armory_tab.refresh_ui()
	if forge_tab != null:
		forge_tab.refresh_ui()


func _sync_sanctuary_stages_for_modal() -> void:
	var modal_open := settings_modal != null and settings_modal.visible
	if hunt_tab != null and hunt_tab.stage_3d != null:
		hunt_tab.stage_3d.set_external_paused(modal_open)
	if armory_tab != null and armory_tab.stage_3d != null:
		armory_tab.stage_3d.set_external_paused(modal_open)


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
