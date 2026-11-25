class_name MainShell
extends Control

enum Tab {
	SANCTUM = 0,
	ARMORY = 1,
	FORGE = 2,
}

const ARENA_SCENE_PATH := "res://scenes/combat/arena_run.tscn"
const COMBAT_HUD_SCENE_PATH := "res://scenes/ui/combat_hud.tscn"

@onready var combat_world_mount: Node = $CombatWorldMount
@onready var hub_layer: Control = $HubLayer
@onready var header_panel: PanelContainer = $HubLayer/HubVBox/HeaderPanel
@onready var brand_lbl: Label = $HubLayer/HubVBox/HeaderPanel/HeaderRow/BrandLbl
@onready var power_pill: PanelContainer = $HubLayer/HubVBox/HeaderPanel/HeaderRow/PowerPill
@onready var power_lbl: Label = $HubLayer/HubVBox/HeaderPanel/HeaderRow/PowerPill/PowerLbl
@onready var gold_pill: PanelContainer = $HubLayer/HubVBox/HeaderPanel/HeaderRow/GoldPill
@onready var gold_lbl: Label = $HubLayer/HubVBox/HeaderPanel/HeaderRow/GoldPill/GoldLbl
@onready var scrap_pill: PanelContainer = $HubLayer/HubVBox/HeaderPanel/HeaderRow/ScrapPill
@onready var scrap_lbl: Label = $HubLayer/HubVBox/HeaderPanel/HeaderRow/ScrapPill/ScrapLbl
@onready var settings_btn: Button = $HubLayer/HubVBox/HeaderPanel/HeaderRow/SettingsBtn

@onready var hunt_tab: HuntTab = $HubLayer/HubVBox/TabStack/HuntTab
@onready var armory_tab: ArmoryTab = $HubLayer/HubVBox/TabStack/ArmoryTab
@onready var forge_tab: ForgeTab = $HubLayer/HubVBox/TabStack/ForgeTab

@onready var nav_panel: PanelContainer = $HubLayer/HubVBox/NavDockPanel
@onready var nav_sanctum_btn: Button = $HubLayer/HubVBox/NavDockPanel/NavRow/NavSanctumBtn
@onready var nav_armory_btn: Button = $HubLayer/HubVBox/NavDockPanel/NavRow/NavArmoryBtn
@onready var nav_forge_btn: Button = $HubLayer/HubVBox/NavDockPanel/NavRow/NavForgeBtn

@onready var settings_modal: SettingsModal = $HubLayer/SettingsModal

var active_tab: Tab = Tab.SANCTUM
var active_arena: CombatDirector = null
var active_hud: CombatHud = null
var _last_run_params: Dictionary = {}


func _ready() -> void:
	theme = UiThemeBuilder.get_theme()
	_style_shell_chrome()

	nav_sanctum_btn.pressed.connect(switch_tab.bind(Tab.SANCTUM))
	nav_armory_btn.pressed.connect(switch_tab.bind(Tab.ARMORY))
	nav_forge_btn.pressed.connect(switch_tab.bind(Tab.FORGE))
	settings_btn.pressed.connect(_on_settings_pressed)
	hunt_tab.embark_requested.connect(start_expedition)

	var gs := _game_state()
	if gs != null:
		if str(gs.get("selected_class_id")) != "oathbreaker":
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


func _style_shell_chrome() -> void:
	_apply_safe_margins()

	power_pill.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_BRONZE, 1, 4, 8, 4))
	gold_pill.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 4, 8, 4))
	scrap_pill.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 4, 8, 4))

	UiThemeBuilder.style_label(brand_lbl, UiThemeBuilder.font_title(), 17, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(power_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(gold_lbl, UiThemeBuilder.font_bold(), 14, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(scrap_lbl, UiThemeBuilder.font_bold(), 14, UiThemeBuilder.TEXT_PARCHMENT, 1)

	var gear_tex := UiThemeBuilder.get_ui_icon("gear")
	if gear_tex != null:
		settings_btn.icon = gear_tex
		settings_btn.text = ""
		settings_btn.expand_icon = true
	else:
		settings_btn.text = "CFG"
	UiThemeBuilder.style_tab_button(settings_btn, false, 12)


func _apply_safe_margins() -> void:
	var m := UiThemeBuilder.get_safe_margins(self)
	var top_pad := int(m["top"])
	var bot_pad := int(m["bottom"])
	var left_pad := int(m["left"])
	var right_pad := int(m["right"])

	var h_box := UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_BRONZE, 1, 0, 12, 8)
	h_box.content_margin_top = 8.0 + float(top_pad)
	h_box.content_margin_left = 12.0 + float(left_pad)
	h_box.content_margin_right = 12.0 + float(right_pad)
	header_panel.add_theme_stylebox_override("panel", h_box)
	header_panel.custom_minimum_size.y = 58.0 + float(top_pad)

	var n_box := UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_BRONZE, 1, 0, 12, 8)
	n_box.content_margin_bottom = 8.0 + float(bot_pad)
	n_box.content_margin_left = 12.0 + float(left_pad)
	n_box.content_margin_right = 12.0 + float(right_pad)
	nav_panel.add_theme_stylebox_override("panel", n_box)
	nav_panel.custom_minimum_size.y = 68.0 + float(bot_pad)


func switch_tab(tab: Tab) -> void:
	if active_tab != tab:
		var ad := _audio()
		if ad != null:
			ad.call("sfx", "ui_tap")
	active_tab = tab
	hunt_tab.visible = (tab == Tab.SANCTUM)
	armory_tab.visible = (tab == Tab.ARMORY)
	forge_tab.visible = (tab == Tab.FORGE)

	UiThemeBuilder.style_tab_button(nav_sanctum_btn, tab == Tab.SANCTUM, 14)
	UiThemeBuilder.style_tab_button(nav_armory_btn, tab == Tab.ARMORY, 14)
	UiThemeBuilder.style_tab_button(nav_forge_btn, tab == Tab.FORGE, 14)

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
	gold_lbl.text = "Gold %d" % int(gs.get("gold"))
	scrap_lbl.text = "Scrap %d" % int(gs.get("scrap"))


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


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
