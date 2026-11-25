class_name CombatHud
extends CanvasLayer

signal return_to_sanctum_requested()
signal hunt_again_requested()

@onready var root_ctrl: Control = $Root
@onready var floaters_layer: Control = $Root/FloatersLayer

@onready var top_bar_panel: PanelContainer = $Root/TopMargin/TopVBox/TopBarPanel
@onready var portrait_frame: PanelContainer = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/PortraitFrame
@onready var hero_portrait_tex: TextureRect = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/PortraitFrame/HeroPortraitTex
@onready var hero_title_lbl: Label = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/VitalsVBox/HeroTitleRow/HeroTitleLbl
@onready var blessing_lbl: Label = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/VitalsVBox/HeroTitleRow/BlessingLbl
@onready var hp_bar: ProgressBar = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/VitalsVBox/HpBarWrap/HpBar
@onready var hp_lbl: Label = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/VitalsVBox/HpBarWrap/HpLbl
@onready var ward_bar: ProgressBar = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/VitalsVBox/WardBarWrap/WardBar
@onready var ward_lbl: Label = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/VitalsVBox/WardBarWrap/WardLbl
@onready var loot_panel: PanelContainer = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/LootPanel
@onready var gold_lbl: Label = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/LootPanel/LootVBox/GoldLbl
@onready var relics_lbl: Label = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/LootPanel/LootVBox/RelicsLbl
@onready var pause_btn: Button = $Root/TopMargin/TopVBox/TopBarPanel/TopRow/PauseBtn

@onready var objective_panel: PanelContainer = $Root/TopMargin/TopVBox/ObjectiveCenter/ObjectivePanel
@onready var objective_lbl: Label = $Root/TopMargin/TopVBox/ObjectiveCenter/ObjectivePanel/ObjectiveLbl

@onready var boss_panel: PanelContainer = $Root/TopMargin/TopVBox/BossPanel
@onready var boss_portrait_frame: PanelContainer = $Root/TopMargin/TopVBox/BossPanel/BossRow/BossPortraitFrame
@onready var boss_portrait_tex: TextureRect = $Root/TopMargin/TopVBox/BossPanel/BossRow/BossPortraitFrame/BossPortraitTex
@onready var boss_name_lbl: Label = $Root/TopMargin/TopVBox/BossPanel/BossRow/BossVBox/BossHeaderRow/BossNameLbl
@onready var boss_enraged_lbl: Label = $Root/TopMargin/TopVBox/BossPanel/BossRow/BossVBox/BossHeaderRow/BossEnragedLbl
@onready var boss_hp_bar: ProgressBar = $Root/TopMargin/TopVBox/BossPanel/BossRow/BossVBox/BossBarWrap/BossHpBar
@onready var boss_hp_lbl: Label = $Root/TopMargin/TopVBox/BossPanel/BossRow/BossVBox/BossBarWrap/BossHpLbl

@onready var thumbstick: VirtualThumbstick = $Root/ThumbstickZone
@onready var action_deck_margin: MarginContainer = $Root/ActionDeckMargin
@onready var action_row: HBoxContainer = $Root/ActionDeckMargin/ActionRow

@onready var shrine_modal: ColorRect = $Root/ShrineModal
@onready var shrine_card_panel: PanelContainer = $Root/ShrineModal/Center/ShrinePanel
@onready var shrine_title_lbl: Label = $Root/ShrineModal/Center/ShrinePanel/VBox/ShrineTitleLbl
@onready var shrine_sub_lbl: Label = $Root/ShrineModal/Center/ShrinePanel/VBox/ShrineSubLbl
@onready var shrine_choices_box: VBoxContainer = $Root/ShrineModal/Center/ShrinePanel/VBox/ShrineChoicesBox

@onready var pause_modal: ColorRect = $Root/PauseModal
@onready var pause_panel: PanelContainer = $Root/PauseModal/Center/PausePanel
@onready var pause_title_lbl: Label = $Root/PauseModal/Center/PausePanel/VBox/PauseTitleLbl
@onready var pause_music_slider: HSlider = $Root/PauseModal/Center/PausePanel/VBox/MusicRow/MusicSlider
@onready var pause_music_val: Label = $Root/PauseModal/Center/PausePanel/VBox/MusicRow/MusicVal
@onready var pause_sfx_slider: HSlider = $Root/PauseModal/Center/PausePanel/VBox/SfxRow/SfxSlider
@onready var pause_sfx_val: Label = $Root/PauseModal/Center/PausePanel/VBox/SfxRow/SfxVal
@onready var pause_shake_toggle: CheckButton = $Root/PauseModal/Center/PausePanel/VBox/ShakeToggle
@onready var pause_lefty_toggle: CheckButton = $Root/PauseModal/Center/PausePanel/VBox/LeftyToggle
@onready var resume_btn: Button = $Root/PauseModal/Center/PausePanel/VBox/ResumeBtn
@onready var retreat_btn: Button = $Root/PauseModal/Center/PausePanel/VBox/RetreatBtn

@onready var summary_modal: ColorRect = $Root/SummaryModal
@onready var summary_panel: PanelContainer = $Root/SummaryModal/Center/SummaryPanel
@onready var summary_banner_lbl: Label = $Root/SummaryModal/Center/SummaryPanel/VBox/SummaryBannerLbl
@onready var summary_stats_lbl: Label = $Root/SummaryModal/Center/SummaryPanel/VBox/SummaryStatsLbl
@onready var summary_loot_header: Label = $Root/SummaryModal/Center/SummaryPanel/VBox/SummaryLootHeader
@onready var summary_loot_list: VBoxContainer = $Root/SummaryModal/Center/SummaryPanel/VBox/SummaryScroll/SummaryLootList
@onready var summary_sanctum_btn: Button = $Root/SummaryModal/Center/SummaryPanel/VBox/SummaryBtns/SanctumBtn
@onready var summary_again_btn: Button = $Root/SummaryModal/Center/SummaryPanel/VBox/SummaryBtns/HuntAgainBtn

var director: CombatDirector = null
var _action_btns: Dictionary = {}
var _floaters: Array[Dictionary] = []
var _syncing_pause_settings: bool = false
var _tracked_enemy_ids: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.theme = UiThemeBuilder.get_theme()

	_style_static_chrome()
	_build_action_buttons()
	_apply_handedness()

	thumbstick.move_vector_changed.connect(_on_thumbstick_moved)
	pause_btn.pressed.connect(open_pause_modal)
	resume_btn.pressed.connect(close_pause_modal)
	retreat_btn.pressed.connect(_on_retreat_pressed)
	summary_sanctum_btn.pressed.connect(_on_return_sanctum_pressed)
	summary_again_btn.pressed.connect(_on_hunt_again_pressed)

	pause_music_slider.value_changed.connect(_on_pause_music_changed)
	pause_sfx_slider.value_changed.connect(_on_pause_sfx_changed)
	pause_shake_toggle.toggled.connect(_on_pause_shake_toggled)
	pause_lefty_toggle.toggled.connect(_on_pause_lefty_toggled)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if summary_modal.visible or shrine_modal.visible:
			return
		if pause_modal.visible:
			close_pause_modal()
		else:
			open_pause_modal()
		get_viewport().set_input_as_handled()


func bind_director(p_director: CombatDirector) -> void:
	director = p_director
	if director == null:
		return

	if not director.hud_updated.is_connected(_on_hud_updated):
		director.hud_updated.connect(_on_hud_updated)
	if not director.boss_updated.is_connected(_on_boss_updated):
		director.boss_updated.connect(_on_boss_updated)
	if not director.damage_floated.is_connected(_on_damage_floated):
		director.damage_floated.connect(_on_damage_floated)
	if not director.shrine_offered.is_connected(_on_shrine_offered):
		director.shrine_offered.connect(_on_shrine_offered)
	if not director.run_completed.is_connected(_on_run_completed):
		director.run_completed.connect(_on_run_completed)

	if director.actors_root != null:
		if not director.actors_root.child_entered_tree.is_connected(_on_actor_spawned):
			director.actors_root.child_entered_tree.connect(_on_actor_spawned)
		for ch in director.actors_root.get_children():
			_on_actor_spawned(ch)

	boss_panel.visible = false
	shrine_modal.visible = false
	pause_modal.visible = false
	summary_modal.visible = false
	_on_hud_updated(director.get_hud_state())


func _on_actor_spawned(node: Node) -> void:
	if node is EnemyController3D:
		var ec := node as EnemyController3D
		var iid := ec.get_instance_id()
		if not _tracked_enemy_ids.has(iid):
			_tracked_enemy_ids[iid] = true
			ec.died.connect(_on_enemy_slain_for_bestiary)


func _on_enemy_slain_for_bestiary(enemy: EnemyController3D) -> void:
	if enemy == null or enemy.enemy_def == null or enemy.is_boss_summon:
		return
	var gs := _game_state()
	if gs != null:
		UiThemeBuilder.record_bestiary_kill(gs, enemy.enemy_def.enemy_id)


func _process(delta: float) -> void:
	_update_live_cooldowns()
	_tick_floaters(delta)


func _style_static_chrome() -> void:
	top_bar_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(Color(0.055, 0.062, 0.08, 0.92), UiThemeBuilder.BORDER_BRONZE, 1, 5, 8, 6))
	portrait_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_GOLD, 2, 4, 2, 2))
	loot_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 4, 8, 4))
	objective_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(Color(0.06, 0.065, 0.085, 0.88), UiThemeBuilder.BORDER_BRONZE, 1, 4, 14, 5))
	boss_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(Color(0.08, 0.05, 0.055, 0.94), UiThemeBuilder.BORDER_GOLD, 2, 5, 10, 7))
	boss_portrait_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_GOLD, 1, 4, 2, 2))

	hp_bar.add_theme_stylebox_override("background", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 3, 0, 0))
	hp_bar.add_theme_stylebox_override("fill", UiThemeBuilder.make_box(UiThemeBuilder.HP_CRIMSON, UiThemeBuilder.HP_CRIMSON.lightened(0.15), 0, 2, 0, 0))

	ward_bar.add_theme_stylebox_override("background", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_SLATE, 1, 3, 0, 0))
	ward_bar.add_theme_stylebox_override("fill", UiThemeBuilder.make_box(UiThemeBuilder.WARD_CYAN, UiThemeBuilder.WARD_CYAN.lightened(0.2), 0, 2, 0, 0))

	boss_hp_bar.add_theme_stylebox_override("background", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, UiThemeBuilder.BORDER_BRONZE, 1, 3, 0, 0))
	boss_hp_bar.add_theme_stylebox_override("fill", UiThemeBuilder.make_box(Color("#b51d24"), UiThemeBuilder.BORDER_GOLD, 0, 2, 0, 0))

	UiThemeBuilder.style_label(hero_title_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(blessing_lbl, UiThemeBuilder.font_bold(), 12, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(hp_lbl, UiThemeBuilder.font_bold(), 13, Color.WHITE)
	UiThemeBuilder.style_label(ward_lbl, UiThemeBuilder.font_bold(), 11, Color(0.82, 0.94, 1.0))
	UiThemeBuilder.style_label(gold_lbl, UiThemeBuilder.font_bold(), 14, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(relics_lbl, UiThemeBuilder.font_bold(), 13, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(objective_lbl, UiThemeBuilder.font_title(), 13, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(boss_name_lbl, UiThemeBuilder.font_title(), 15, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(boss_enraged_lbl, UiThemeBuilder.font_title(), 13, Color("#ff4c46"))
	UiThemeBuilder.style_label(boss_hp_lbl, UiThemeBuilder.font_bold(), 13, Color.WHITE)

	shrine_card_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_GOLD, 2, 6, 18, 16))
	pause_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_GOLD, 2, 6, 20, 18))
	summary_panel.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_GOLD, 2, 6, 18, 16))

	UiThemeBuilder.style_label(shrine_title_lbl, UiThemeBuilder.font_title(), 22, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(shrine_sub_lbl, UiThemeBuilder.font_body(), 15, UiThemeBuilder.TEXT_MUTED, 1)
	UiThemeBuilder.style_label(pause_title_lbl, UiThemeBuilder.font_title(), 22, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(summary_banner_lbl, UiThemeBuilder.font_title(), 24, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_label(summary_stats_lbl, UiThemeBuilder.font_bold(), 15, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(summary_loot_header, UiThemeBuilder.font_title(), 14, UiThemeBuilder.TEXT_GOLD)

	UiThemeBuilder.style_cta_button(resume_btn, 16)
	UiThemeBuilder.style_cta_button(summary_again_btn, 16)
	UiThemeBuilder.style_tab_button(pause_btn, false, 16)


func _build_action_buttons() -> void:
	for ch in action_row.get_children():
		ch.queue_free()
	_action_btns.clear()

	var specs := [
		{"id": "skill_1", "key": "[Q]", "default_name": "Skill 1"},
		{"id": "skill_2", "key": "[E]", "default_name": "Skill 2"},
		{"id": "dash", "key": "[SPACE]", "default_name": "Dash"},
	]
	for sp in specs:
		var aid := str(sp["id"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(98, 104)
		btn.clip_contents = true
		var sb_n := UiThemeBuilder.make_box(Color(0.08, 0.09, 0.12, 0.94), UiThemeBuilder.BORDER_GOLD, 2, 6, 4, 4)
		var sb_h := UiThemeBuilder.make_box(Color(0.14, 0.15, 0.20, 0.96), UiThemeBuilder.BORDER_GOLD.lightened(0.2), 2, 6, 4, 4)
		var sb_p := UiThemeBuilder.make_box(UiThemeBuilder.CTA_CRIMSON, UiThemeBuilder.BORDER_GOLD, 2, 6, 4, 4)
		btn.add_theme_stylebox_override("normal", sb_n)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("focus", sb_h)
		btn.add_theme_stylebox_override("pressed", sb_p)
		btn.pressed.connect(_on_action_btn_pressed.bind(aid))

		var sweep := ColorRect.new()
		sweep.color = Color(0.02, 0.02, 0.03, 0.76)
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sweep.anchor_left = 0.0
		sweep.anchor_right = 1.0
		sweep.anchor_bottom = 1.0
		sweep.anchor_top = 1.0
		btn.add_child(sweep)

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 5)
		margin.add_theme_constant_override("margin_right", 5)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 4)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vb)

		var klbl := Label.new()
		klbl.text = str(sp["key"])
		klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiThemeBuilder.style_label(klbl, UiThemeBuilder.font_title(), 11, UiThemeBuilder.TEXT_GOLD, 1)
		klbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(klbl)

		var nlbl := Label.new()
		nlbl.text = str(sp["default_name"])
		nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nlbl.max_lines_visible = 2
		UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_bold(), 13, UiThemeBuilder.TEXT_PARCHMENT, 2)
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(nlbl)

		var cdlbl := Label.new()
		cdlbl.text = "READY"
		cdlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiThemeBuilder.style_label(cdlbl, UiThemeBuilder.font_title(), 11, UiThemeBuilder.TEXT_READY, 2)
		cdlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(cdlbl)

		action_row.add_child(btn)
		_action_btns[aid] = {
			"btn": btn,
			"sweep": sweep,
			"name_lbl": nlbl,
			"cd_lbl": cdlbl,
		}


func _apply_handedness() -> void:
	var left_handed := false
	var gs := _game_state()
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		left_handed = bool((gs.settings as Dictionary).get("left_handed", false))

	if left_handed:
		action_deck_margin.anchor_left = 0.0
		action_deck_margin.anchor_right = 0.0
		action_deck_margin.offset_left = 14.0
		action_deck_margin.offset_right = 338.0
		thumbstick.anchor_left = 1.0
		thumbstick.anchor_right = 1.0
		thumbstick.offset_left = -370.0
		thumbstick.offset_right = 0.0
	else:
		action_deck_margin.anchor_left = 1.0
		action_deck_margin.anchor_right = 1.0
		action_deck_margin.offset_left = -338.0
		action_deck_margin.offset_right = -14.0
		thumbstick.anchor_left = 0.0
		thumbstick.anchor_right = 0.0
		thumbstick.offset_left = 0.0
		thumbstick.offset_right = 370.0
	thumbstick.queue_redraw()


func _on_hud_updated(state: Dictionary) -> void:
	if state.is_empty():
		return

	var cid := str(state.get("class_id", "oathbreaker"))
	hero_portrait_tex.texture = UiThemeBuilder.get_portrait(cid)
	hero_title_lbl.text = str(state.get("class_name", "Oathbreaker")).to_upper()

	var blessings: Array = state.get("blessings", []) if state.get("blessings") is Array else []
	blessing_lbl.text = "Shrines: %d" % blessings.size()

	var hp := float(state.get("hp", 200.0))
	var mhp := maxf(1.0, float(state.get("max_hp", 200.0)))
	var ward := maxf(0.0, float(state.get("ward_hp", 0.0)))

	hp_bar.max_value = mhp
	hp_bar.value = clampf(hp, 0.0, mhp)
	hp_lbl.text = "%d / %d HP" % [maxi(0, roundi(hp)), roundi(mhp)]

	ward_bar.max_value = mhp * 0.5
	ward_bar.value = clampf(ward, 0.0, mhp * 0.5)
	ward_lbl.text = "WARD %d" % roundi(ward)

	gold_lbl.text = "Gold: %d" % int(state.get("gold", 0))
	relics_lbl.text = "Relics: %d" % int(state.get("items_collected", 0))

	var cl_done := int(state.get("clearings_cleared", 0))
	var cl_total := maxi(1, int(state.get("clearings_total", 3)))
	var gate_open := bool(state.get("boss_gate_unlocked", false))
	var boss_active := bool(state.get("boss_active", false))
	var foes_alive := int(state.get("enemies_alive", 0))

	var shrine_unvisited := false
	if director != null and director.dark_shrine != null and is_instance_valid(director.dark_shrine):
		shrine_unvisited = not director.dark_shrine.is_consumed

	if boss_active:
		objective_lbl.text = "GUARDIAN OF %s ENGAGED" % str(state.get("zone_name", "THE BARROW")).to_upper()
	elif gate_open:
		if shrine_unvisited:
			objective_lbl.text = "BOSS GATE UNSEALED  ·  DARK SHRINE AHEAD"
		else:
			objective_lbl.text = "BOSS GATE UNSEALED  —  CONFRONT THE GUARDIAN"
	else:
		var cur_cl := mini(cl_done + 1, cl_total)
		if cl_done >= 1 and shrine_unvisited and foes_alive == 0:
			objective_lbl.text = "DARK SHRINE AHEAD  ·  CLEARING %d/%d" % [cur_cl, cl_total]
		else:
			objective_lbl.text = "CLEARING %d / %d  ·  FOES: %d" % [cur_cl, cl_total, foes_alive]

	if director != null and director.class_def != null:
		var hdef := director.class_def
		if hdef.skill_1 != null:
			(_action_btns["skill_1"]["name_lbl"] as Label).text = hdef.skill_1.display_name
		if hdef.skill_2 != null:
			(_action_btns["skill_2"]["name_lbl"] as Label).text = hdef.skill_2.display_name
		if hdef.dash_ability != null:
			(_action_btns["dash"]["name_lbl"] as Label).text = hdef.dash_ability.display_name


func _update_live_cooldowns() -> void:
	if director == null or director.hero == null or not is_instance_valid(director.hero):
		return
	var h := director.hero
	_apply_cd_visual("skill_1", h.skill_1_cooldown_left, h.skill_1_cooldown_max)
	_apply_cd_visual("skill_2", h.skill_2_cooldown_left, h.skill_2_cooldown_max)
	_apply_cd_visual("dash", h.dash_cooldown_left, h.dash_cooldown_max)


func _apply_cd_visual(aid: String, cd_left: float, cd_max: float) -> void:
	if not _action_btns.has(aid):
		return
	var d: Dictionary = _action_btns[aid]
	var sweep: ColorRect = d["sweep"]
	var cdlbl: Label = d["cd_lbl"]
	if cd_left > 0.04:
		var ratio := clampf(cd_left / maxf(0.1, cd_max), 0.0, 1.0)
		sweep.anchor_top = 1.0 - ratio
		sweep.visible = true
		cdlbl.text = "%.1fs" % cd_left
		cdlbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD)
	else:
		sweep.visible = false
		cdlbl.text = "READY"
		cdlbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_READY)


func _on_boss_updated(boss_name: String, boss_title: String, current_hp: float, max_hp: float, is_enraged: bool) -> void:
	boss_panel.visible = current_hp > 0.0
	if not boss_panel.visible:
		return
	if director != null and director.zone_def != null:
		boss_portrait_tex.texture = UiThemeBuilder.get_portrait(director.zone_def.boss_id)
	boss_name_lbl.text = "%s — %s" % [boss_name, boss_title]
	boss_enraged_lbl.visible = is_enraged
	boss_enraged_lbl.text = "[ENRAGED]"
	boss_hp_bar.max_value = maxf(1.0, max_hp)
	boss_hp_bar.value = clampf(current_hp, 0.0, max_hp)
	boss_hp_lbl.text = "%d / %d" % [maxi(0, roundi(current_hp)), roundi(max_hp)]


func _on_damage_floated(world_pos: Vector3, amount: int, is_crit: bool, is_hero_hurt: bool, is_heal: bool) -> void:
	var gs := _game_state()
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		if not bool((gs.settings as Dictionary).get("damage_numbers", true)):
			return
	if director == null:
		return
	var cam := director.get_camera()
	if cam == null or cam.is_position_behind(world_pos):
		return

	var screen_pt := cam.unproject_position(world_pos + Vector3(0.0, 1.25, 0.0))
	var lbl := Label.new()
	var t_scale := 1.0
	var ad := _audio()
	if ad != null and ad.has_method("text_scale"):
		t_scale = float(ad.call("text_scale"))

	var fsize := roundi(20.0 * t_scale)
	var col := Color("#f5efe2")
	var txt := "%d" % amount
	if is_heal:
		col = Color("#62e884")
		txt = "+%d" % amount
	elif is_hero_hurt:
		col = Color("#ff524f")
		txt = "-%d" % amount
		fsize = roundi(22.0 * t_scale)
	elif is_crit:
		col = Color("#ffd257")
		txt = "%d!" % amount
		fsize = roundi(27.0 * t_scale)

	lbl.text = txt
	UiThemeBuilder.style_label(lbl, UiThemeBuilder.font_title(), fsize, col, 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jitter_x := randf_range(-18.0, 18.0)
	lbl.position = screen_pt + Vector2(jitter_x - 28.0, -14.0)
	floaters_layer.add_child(lbl)
	_floaters.append({
		"lbl": lbl,
		"vel": Vector2(jitter_x * 0.45, -62.0 if is_crit else -48.0),
		"age": 0.0,
		"life": 0.72,
	})


func _tick_floaters(delta: float) -> void:
	var i := _floaters.size() - 1
	while i >= 0:
		var f: Dictionary = _floaters[i]
		var lbl: Label = f["lbl"]
		if lbl == null or not is_instance_valid(lbl):
			_floaters.remove_at(i)
			i -= 1
			continue
		var age := float(f["age"]) + delta
		var life := float(f["life"])
		if age >= life:
			lbl.queue_free()
			_floaters.remove_at(i)
			i -= 1
			continue
		f["age"] = age
		var vel: Vector2 = f["vel"]
		lbl.position += vel * delta
		var alpha := 1.0 - clampf((age - life * 0.45) / (life * 0.55), 0.0, 1.0)
		lbl.modulate.a = alpha
		_floaters[i] = f
		i -= 1


func _on_shrine_offered(choices: Array[ShrineBlessingDef]) -> void:
	thumbstick.reset_stick()
	for ch in shrine_choices_box.get_children():
		ch.queue_free()

	for bdef in choices:
		if bdef == null:
			continue
		var rcol := GameEnums.rarity_color(bdef.rarity)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 112)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiThemeBuilder.style_rarity_tile(btn, bdef.rarity, false, 10)
		btn.pressed.connect(_on_shrine_choice_picked.bind(bdef.blessing_id))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 5)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vb)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top)

		var t_lbl := Label.new()
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.text = bdef.display_name.to_upper()
		UiThemeBuilder.style_label(t_lbl, UiThemeBuilder.font_title(), 17, rcol)
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(t_lbl)

		var r_lbl := Label.new()
		r_lbl.text = "[%s OATH]" % GameEnums.rarity_name(bdef.rarity).to_upper()
		UiThemeBuilder.style_label(r_lbl, UiThemeBuilder.font_title(), 12, rcol)
		r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(r_lbl)

		var d_lbl := Label.new()
		d_lbl.text = bdef.description
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiThemeBuilder.style_label(d_lbl, UiThemeBuilder.font_body(), 15, UiThemeBuilder.TEXT_PARCHMENT, 1)
		d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(d_lbl)

		shrine_choices_box.add_child(btn)

	shrine_modal.visible = true


func _on_shrine_choice_picked(blessing_id: String) -> void:
	shrine_modal.visible = false
	if director != null:
		director.apply_shrine_choice(blessing_id)


func open_pause_modal() -> void:
	if summary_modal.visible or shrine_modal.visible:
		return
	thumbstick.reset_stick()
	_syncing_pause_settings = true
	var gs := _game_state()
	var st: Dictionary = gs.settings if (gs != null and "settings" in gs and gs.settings is Dictionary) else {}
	var mvol := clampf(float(st.get("music_vol", 0.8)), 0.0, 1.0)
	var svol := clampf(float(st.get("sfx_vol", 0.9)), 0.0, 1.0)
	pause_music_slider.value = mvol
	pause_music_val.text = "%d%%" % roundi(mvol * 100.0)
	pause_sfx_slider.value = svol
	pause_sfx_val.text = "%d%%" % roundi(svol * 100.0)
	pause_shake_toggle.button_pressed = float(st.get("screen_shake", 1.0)) > 0.05
	pause_lefty_toggle.button_pressed = bool(st.get("left_handed", false))
	_syncing_pause_settings = false

	pause_modal.visible = true
	if get_tree() != null:
		get_tree().paused = true


func close_pause_modal() -> void:
	pause_modal.visible = false
	if get_tree() != null:
		get_tree().paused = false


func _on_pause_music_changed(val: float) -> void:
	pause_music_val.text = "%d%%" % roundi(val * 100.0)
	if _syncing_pause_settings:
		return
	var ad := _audio()
	if ad != null and ad.has_method("set_setting"):
		ad.call("set_setting", "music_vol", val)


func _on_pause_sfx_changed(val: float) -> void:
	pause_sfx_val.text = "%d%%" % roundi(val * 100.0)
	if _syncing_pause_settings:
		return
	var ad := _audio()
	if ad != null and ad.has_method("set_setting"):
		ad.call("set_setting", "sfx_vol", val)


func _on_pause_shake_toggled(on: bool) -> void:
	if _syncing_pause_settings:
		return
	var ad := _audio()
	if ad != null and ad.has_method("set_setting"):
		ad.call("set_setting", "screen_shake", 1.0 if on else 0.0)


func _on_pause_lefty_toggled(on: bool) -> void:
	if _syncing_pause_settings:
		return
	var ad := _audio()
	if ad != null and ad.has_method("set_setting"):
		ad.call("set_setting", "left_handed", on)
	_apply_handedness()


func _on_run_completed(victory: bool, summary: Dictionary) -> void:
	thumbstick.reset_stick()
	shrine_modal.visible = false
	pause_modal.visible = false
	if get_tree() != null:
		get_tree().paused = false

	if victory:
		summary_banner_lbl.text = "GUARDIAN SLAIN — BARROW PURGED"
		summary_banner_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD)
	else:
		summary_banner_lbl.text = "FALLEN IN THE ASH"
		summary_banner_lbl.add_theme_color_override("font_color", UiThemeBuilder.TEXT_CRIMSON)

	var dur := float(summary.get("duration_sec", 0.0))
	var mins := int(dur) / 60
	var secs := int(dur) % 60
	summary_stats_lbl.text = "%s (%s)  ·  Time %02d:%02d\nGold Looted: +%d  ·  Foes Slain: %d" % [
		str(summary.get("zone_name", "Barrow Fringe")),
		str(summary.get("difficulty_name", "Normal")),
		mins,
		secs,
		int(summary.get("gold_earned", 0)),
		int(summary.get("enemies_slain", 0)),
	]

	for ch in summary_loot_list.get_children():
		ch.queue_free()

	var drops: Array = summary.get("items_dropped", []) if summary.get("items_dropped") is Array else []
	summary_loot_header.text = "RECOVERED RELICS (%d)" % drops.size()

	if drops.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No relics recovered on this expedition."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiThemeBuilder.style_label(empty_lbl, UiThemeBuilder.font_body(), 14, UiThemeBuilder.TEXT_MUTED, 1)
		summary_loot_list.add_child(empty_lbl)
	else:
		for d_item in drops:
			if not (d_item is EquipmentItem):
				continue
			var item := d_item as EquipmentItem
			var rcol := GameEnums.rarity_color(item.rarity)
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS.lerp(rcol, 0.08), rcol, 2, 4, 8, 6))

			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			card.add_child(hb)

			var iframe := PanelContainer.new()
			iframe.custom_minimum_size = Vector2(56, 56)
			iframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			iframe.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, rcol, 1, 3, 2, 2))
			hb.add_child(iframe)

			var itex := TextureRect.new()
			itex.texture = UiThemeBuilder.get_item_icon(item)
			itex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			itex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			iframe.add_child(itex)

			var vb := VBoxContainer.new()
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vb.add_theme_constant_override("separation", 2)
			hb.add_child(vb)

			var nlbl := Label.new()
			nlbl.text = "%s  (T%d %s · PWR %d)" % [
				item.display_name(),
				item.tier,
				GameEnums.rarity_name(item.rarity),
				item.power_score(),
			]
			UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_title(), 14, rcol)
			vb.add_child(nlbl)

			var details: Array[String] = [UiThemeBuilder.format_item_primary_line(item)]
			for af in item.affixes:
				if af != null:
					details.append(af.format_line())
			var slbl := Label.new()
			slbl.text = "  ·  ".join(details)
			slbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UiThemeBuilder.style_label(slbl, UiThemeBuilder.font_body(), 13, UiThemeBuilder.TEXT_PARCHMENT, 1)
			vb.add_child(slbl)

			summary_loot_list.add_child(card)

	summary_modal.visible = true


func _on_thumbstick_moved(vec: Vector2) -> void:
	if director != null:
		director.set_virtual_move(vec)


func _on_action_btn_pressed(aid: String) -> void:
	if director == null:
		return
	match aid:
		"skill_1":
			director.press_skill_1()
		"skill_2":
			director.press_skill_2()
		"dash":
			director.press_dash()


func _on_retreat_pressed() -> void:
	close_pause_modal()
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_back")
	return_to_sanctum_requested.emit()


func _on_return_sanctum_pressed() -> void:
	summary_modal.visible = false
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_press")
	return_to_sanctum_requested.emit()


func _on_hunt_again_pressed() -> void:
	summary_modal.visible = false
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_press")
	hunt_again_requested.emit()


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
