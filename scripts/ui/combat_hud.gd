class_name CombatHud
extends CanvasLayer

signal return_to_sanctum_requested()
signal hunt_again_requested()

const FLOATER_POOL_SIZE := 24
const ACTION_CLUSTER_W := 296.0
const ACTION_CLUSTER_H := 296.0

@onready var root_ctrl: Control = $Root
@onready var damage_vignette: TextureRect = $Root/DamageVignette
@onready var combat_overlay: Control = $Root/CombatOverlay2D
@onready var floaters_layer: Control = $Root/FloatersLayer
@onready var top_scrim: TextureRect = $Root/TopScrim

@onready var top_margin: MarginContainer = $Root/TopMargin
@onready var portrait_frame: PanelContainer = $Root/TopMargin/TopVBox/TopRow/PortraitFrame
@onready var hero_portrait_tex: TextureRect = $Root/TopMargin/TopVBox/TopRow/PortraitFrame/HeroPortraitTex
@onready var hp_bar: ProgressBar = $Root/TopMargin/TopVBox/TopRow/VitalsVBox/HpBarWrap/HpBar
@onready var hp_lbl: Label = $Root/TopMargin/TopVBox/TopRow/VitalsVBox/HpBarWrap/HpLbl
@onready var ward_bar_wrap: Control = $Root/TopMargin/TopVBox/TopRow/VitalsVBox/WardBarWrap
@onready var ward_bar: ProgressBar = $Root/TopMargin/TopVBox/TopRow/VitalsVBox/WardBarWrap/WardBar
@onready var status_pill: PanelContainer = $Root/TopMargin/TopVBox/TopRow/VitalsVBox/StatusPill
@onready var objective_lbl: Label = $Root/TopMargin/TopVBox/TopRow/VitalsVBox/StatusPill/ObjectiveLbl
@onready var pause_btn: Button = $Root/TopMargin/TopVBox/TopRow/PauseBtn

@onready var boss_center: CenterContainer = $Root/TopMargin/TopVBox/BossCenter
@onready var boss_vbox: VBoxContainer = $Root/TopMargin/TopVBox/BossCenter/BossVBox
@onready var boss_name_lbl: Label = $Root/TopMargin/TopVBox/BossCenter/BossVBox/BossHeaderRow/BossNameLbl
@onready var boss_enraged_badge: PanelContainer = $Root/TopMargin/TopVBox/BossCenter/BossVBox/BossHeaderRow/BossEnragedBadge
@onready var boss_enraged_lbl: Label = $Root/TopMargin/TopVBox/BossCenter/BossVBox/BossHeaderRow/BossEnragedBadge/BossEnragedLbl
@onready var boss_hp_bar: ProgressBar = $Root/TopMargin/TopVBox/BossCenter/BossVBox/BossBarWrap/BossHpBar
@onready var boss_hp_lbl: Label = $Root/TopMargin/TopVBox/BossCenter/BossVBox/BossBarWrap/BossHpLbl

@onready var thumbstick: VirtualThumbstick = $Root/ThumbstickZone
@onready var action_deck_margin: MarginContainer = $Root/ActionDeckMargin
@onready var action_cluster: Control = $Root/ActionDeckMargin/ActionCluster

@onready var shrine_modal: ColorRect = $Root/ShrineModal
@onready var shrine_safe_wrap: MarginContainer = $Root/ShrineModal/SafeWrap
@onready var shrine_card_panel: PanelContainer = $Root/ShrineModal/SafeWrap/Center/ShrinePanel
@onready var shrine_title_lbl: Label = $Root/ShrineModal/SafeWrap/Center/ShrinePanel/VBox/ShrineTitleLbl
@onready var shrine_sub_lbl: Label = $Root/ShrineModal/SafeWrap/Center/ShrinePanel/VBox/ShrineSubLbl
@onready var shrine_choices_box: VBoxContainer = $Root/ShrineModal/SafeWrap/Center/ShrinePanel/VBox/ShrineChoicesBox

@onready var pause_modal: ColorRect = $Root/PauseModal
@onready var pause_safe_wrap: MarginContainer = $Root/PauseModal/SafeWrap
@onready var pause_panel: PanelContainer = $Root/PauseModal/SafeWrap/Center/PausePanel
@onready var pause_title_lbl: Label = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/PauseTitleLbl
@onready var pause_music_lbl: Label = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/MusicRow/MusicLbl
@onready var pause_music_slider: HSlider = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/MusicRow/MusicSlider
@onready var pause_music_val: Label = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/MusicRow/MusicVal
@onready var pause_sfx_lbl: Label = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/SfxRow/SfxLbl
@onready var pause_sfx_slider: HSlider = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/SfxRow/SfxSlider
@onready var pause_sfx_val: Label = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/SfxRow/SfxVal
@onready var pause_shake_toggle: CheckButton = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/ShakeToggle
@onready var pause_lefty_toggle: CheckButton = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/LeftyToggle
@onready var resume_btn: Button = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/ResumeBtn
@onready var retreat_btn: Button = $Root/PauseModal/SafeWrap/Center/PausePanel/VBox/RetreatBtn

@onready var summary_modal: ColorRect = $Root/SummaryModal
@onready var summary_safe_wrap: MarginContainer = $Root/SummaryModal/SafeWrap
@onready var summary_panel: PanelContainer = $Root/SummaryModal/SafeWrap/Center/SummaryPanel
@onready var summary_banner_lbl: Label = $Root/SummaryModal/SafeWrap/Center/SummaryPanel/VBox/SummaryBannerLbl
@onready var summary_stats_lbl: Label = $Root/SummaryModal/SafeWrap/Center/SummaryPanel/VBox/SummaryStatsLbl
@onready var summary_loot_header: Label = $Root/SummaryModal/SafeWrap/Center/SummaryPanel/VBox/SummaryLootHeader
@onready var summary_loot_list: VBoxContainer = $Root/SummaryModal/SafeWrap/Center/SummaryPanel/VBox/SummaryScroll/SummaryLootList
@onready var summary_sanctum_btn: Button = $Root/SummaryModal/SafeWrap/Center/SummaryPanel/VBox/SummaryBtns/SanctumBtn
@onready var summary_again_btn: Button = $Root/SummaryModal/SafeWrap/Center/SummaryPanel/VBox/SummaryBtns/HuntAgainBtn

var director: CombatDirector = null
var skill1_btn: Button = null
var skill2_btn: Button = null
var skill3_btn: Button = null
var dash_btn: Button = null

var _action_btns: Dictionary = {}
var _floater_pool: Array[Dictionary] = []
var _floater_ls_normal: LabelSettings = null
var _floater_ls_crit: LabelSettings = null
var _floater_ls_hurt: LabelSettings = null
var _floater_ls_heal: LabelSettings = null
var _floater_ls_scale: float = -1.0

var _syncing_pause_settings: bool = false
var _tracked_enemy_ids: Dictionary = {}
var _touch_active: bool = false
var _touch_guard_until_usec: Dictionary = {}
var _touch_held_index: Dictionary = {}
var _shrine_input_guard: float = 0.0

var _last_hero_hp: float = -1.0
var _hero_hp_ratio: float = 1.0
var _damage_flash_alpha: float = 0.0
var _low_hp_pulse_t: float = 0.0
var _safe_margins: Dictionary = {"top": 12, "bottom": 12, "left": 0, "right": 0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.theme = UiThemeBuilder.get_theme()

	_init_floater_pool()
	_style_static_chrome()
	_build_action_buttons()
	combat_overlay.draw.connect(_draw_combat_overlay)

	root_ctrl.resized.connect(_apply_safe_margins)
	_apply_safe_margins()

	thumbstick.move_vector_changed.connect(_on_thumbstick_moved)
	pause_btn.pivot_offset = pause_btn.custom_minimum_size * 0.5
	pause_btn.gui_input.connect(_on_hud_btn_gui_input.bind(pause_btn, "pause"))
	pause_btn.pressed.connect(_on_pause_btn_pressed)
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


func _input(event: InputEvent) -> void:
	if _touch_held_index.is_empty():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed or st.canceled:
			var released_aids: Array[String] = []
			for aid in _touch_held_index:
				if int(_touch_held_index[aid]) == st.index:
					released_aids.append(str(aid))
			if not released_aids.is_empty():
				var now := Time.get_ticks_usec()
				for aid in released_aids:
					_touch_held_index.erase(aid)
					_touch_guard_until_usec[aid] = now + 220_000
					var b: Button = pause_btn if aid == "pause" else (_action_btns[aid]["btn"] as Button if _action_btns.has(aid) else null)
					if b != null:
						_on_action_btn_up(b)
				_touch_active = not _touch_held_index.is_empty()


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

	_last_hero_hp = -1.0
	_hero_hp_ratio = 1.0
	_damage_flash_alpha = 0.0
	_reset_floater_pool()
	_build_action_buttons()
	_apply_handedness()

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

	boss_center.visible = false
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
	if _shrine_input_guard > 0.0:
		_shrine_input_guard = maxf(0.0, _shrine_input_guard - delta)
	_update_live_cooldowns(delta)
	_tick_floaters(delta)
	_tick_vignette(delta)
	if director != null and is_instance_valid(director) and director.run_started and not director.run_finished and not pause_modal.visible and not summary_modal.visible:
		combat_overlay.queue_redraw()


func _init_floater_pool() -> void:
	_floater_pool.clear()
	_refresh_floater_label_settings()
	for i in range(FLOATER_POOL_SIZE):
		var lbl := Label.new()
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.label_settings = _floater_ls_normal
		floaters_layer.add_child(lbl)
		_floater_pool.append({
			"lbl": lbl,
			"active": false,
			"vel": Vector2.ZERO,
			"age": 0.0,
			"life": 0.72,
		})


func _reset_floater_pool() -> void:
	for i in range(_floater_pool.size()):
		var slot: Dictionary = _floater_pool[i]
		slot["active"] = false
		var lbl: Label = slot["lbl"]
		if lbl != null and is_instance_valid(lbl):
			lbl.visible = false
		_floater_pool[i] = slot


func _refresh_floater_label_settings() -> void:
	var t_scale := UiThemeBuilder.get_text_scale()
	if is_equal_approx(t_scale, _floater_ls_scale) and _floater_ls_normal != null:
		return
	_floater_ls_scale = t_scale
	_floater_ls_normal = _make_floater_settings(roundi(20.0 * t_scale), Color("#f5efe2"))
	_floater_ls_crit = _make_floater_settings(roundi(28.0 * t_scale), Color("#ffd257"))
	_floater_ls_hurt = _make_floater_settings(roundi(23.0 * t_scale), Color("#ff524f"))
	_floater_ls_heal = _make_floater_settings(roundi(21.0 * t_scale), Color("#62e884"))


static func _make_floater_settings(px: int, col: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = UiThemeBuilder.font_title()
	ls.font_size = maxi(14, px)
	ls.font_color = col
	ls.outline_size = 4
	ls.outline_color = Color(0.02, 0.02, 0.03, 0.94)
	return ls


func _style_static_chrome() -> void:
	top_scrim.texture = UiThemeBuilder.make_scrim_texture(true, 0.72, 0.28)
	damage_vignette.texture = UiThemeBuilder.get_vignette_texture()
	damage_vignette.modulate = Color(0.88, 0.10, 0.10, 0.0)
	damage_vignette.visible = false

	portrait_frame.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(Color(0.04, 0.045, 0.06, 0.88), UiThemeBuilder.BORDER_GOLD, 2, 10, 2, 2))
	status_pill.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.042, 0.046, 0.064, 0.74), Color(0.75, 0.60, 0.30, 0.42), 12, 4))

	hp_bar.add_theme_stylebox_override("background", UiThemeBuilder.make_box(Color(0.04, 0.045, 0.06, 0.86), Color(0.55, 0.44, 0.24, 0.55), 1, 6, 0, 0))
	hp_bar.add_theme_stylebox_override("fill", UiThemeBuilder.make_box(Color("#b62026"), Color("#df3b3e"), 0, 5, 0, 0))

	ward_bar.add_theme_stylebox_override("background", UiThemeBuilder.make_box(Color(0.04, 0.045, 0.06, 0.82), Color(0.24, 0.56, 0.78, 0.45), 1, 4, 0, 0))
	ward_bar.add_theme_stylebox_override("fill", UiThemeBuilder.make_box(UiThemeBuilder.WARD_CYAN, UiThemeBuilder.WARD_CYAN.lightened(0.25), 0, 3, 0, 0))

	boss_hp_bar.add_theme_stylebox_override("background", UiThemeBuilder.make_box(Color(0.04, 0.03, 0.04, 0.88), UiThemeBuilder.BORDER_GOLD, 1, 6, 0, 0))
	boss_hp_bar.add_theme_stylebox_override("fill", UiThemeBuilder.make_box(Color("#b81e24"), UiThemeBuilder.BORDER_GOLD, 0, 5, 0, 0))
	boss_enraged_badge.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.45, 0.07, 0.07, 0.90), Color(1.0, 0.36, 0.30, 0.88), 8, 2))

	UiThemeBuilder.style_label(hp_lbl, UiThemeBuilder.font_bold(), 17, Color.WHITE, 2)
	UiThemeBuilder.style_label(objective_lbl, UiThemeBuilder.font_bold(), 16, UiThemeBuilder.TEXT_PARCHMENT, 2)
	UiThemeBuilder.style_label(boss_name_lbl, UiThemeBuilder.font_title(), 19, UiThemeBuilder.TEXT_GOLD, 3)
	UiThemeBuilder.style_label(boss_enraged_lbl, UiThemeBuilder.font_title(), 13, Color("#ff6b63"), 1)
	UiThemeBuilder.style_label(boss_hp_lbl, UiThemeBuilder.font_bold(), 14, Color.WHITE, 2)

	var p_n := UiThemeBuilder.make_box(Color(0.048, 0.052, 0.072, 0.76), Color(0.83, 0.66, 0.33, 0.62), 2, 42, 0, 0)
	p_n.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	p_n.shadow_size = 6
	var p_h := UiThemeBuilder.make_box(Color(0.11, 0.12, 0.16, 0.88), UiThemeBuilder.BORDER_GOLD, 2, 42, 0, 0)
	var p_p := UiThemeBuilder.make_box(Color(0.22, 0.09, 0.08, 0.94), UiThemeBuilder.BORDER_GOLD, 2, 42, 0, 0)
	pause_btn.add_theme_stylebox_override("normal", p_n)
	pause_btn.add_theme_stylebox_override("hover", p_h)
	pause_btn.add_theme_stylebox_override("focus", p_h)
	pause_btn.add_theme_stylebox_override("pressed", p_p)
	pause_btn.add_theme_font_override("font", UiThemeBuilder.font_title())
	pause_btn.add_theme_font_size_override("font_size", 24)
	pause_btn.add_theme_color_override("font_color", UiThemeBuilder.TEXT_GOLD)

	var modal_sb := UiThemeBuilder.make_glass_panel(Color(0.052, 0.056, 0.076, 0.95), UiThemeBuilder.BORDER_GOLD, 16, 22, 20)
	modal_sb.set_border_width_all(1)
	modal_sb.border_width_top = 2
	shrine_card_panel.add_theme_stylebox_override("panel", modal_sb)
	pause_panel.add_theme_stylebox_override("panel", modal_sb.duplicate())
	summary_panel.add_theme_stylebox_override("panel", modal_sb.duplicate())

	UiThemeBuilder.style_label(shrine_title_lbl, UiThemeBuilder.font_title(), 26, UiThemeBuilder.TEXT_GOLD, 2)
	UiThemeBuilder.style_label(shrine_sub_lbl, UiThemeBuilder.font_body(), 18, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(pause_title_lbl, UiThemeBuilder.font_title(), 26, UiThemeBuilder.TEXT_GOLD, 2)
	UiThemeBuilder.style_label(pause_music_lbl, UiThemeBuilder.font_bold(), 18, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(pause_music_val, UiThemeBuilder.font_bold(), 18, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(pause_sfx_lbl, UiThemeBuilder.font_bold(), 18, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(pause_sfx_val, UiThemeBuilder.font_bold(), 18, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_slider(pause_music_slider)
	UiThemeBuilder.style_slider(pause_sfx_slider)

	UiThemeBuilder.style_label(summary_banner_lbl, UiThemeBuilder.font_title(), 28, UiThemeBuilder.TEXT_GOLD, 2)
	UiThemeBuilder.style_label(summary_stats_lbl, UiThemeBuilder.font_bold(), 19, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(summary_loot_header, UiThemeBuilder.font_title(), 17, UiThemeBuilder.TEXT_GOLD, 1)

	UiThemeBuilder.style_cta_button(resume_btn, 21)
	UiThemeBuilder.style_tab_button(retreat_btn, false, 19)
	UiThemeBuilder.style_tab_button(summary_sanctum_btn, false, 19)
	UiThemeBuilder.style_cta_button(summary_again_btn, 20)


func _build_action_buttons() -> void:
	for ch in action_cluster.get_children():
		ch.queue_free()
	_action_btns.clear()
	_touch_held_index.clear()
	_touch_active = false
	skill1_btn = null
	skill2_btn = null
	skill3_btn = null
	dash_btn = null

	var hdef := director.class_def if director != null else GameRegistry.get_class_def("oathbreaker")
	var has_s3 := hdef != null and hdef.skill_3 != null
	var is_mobile := OS.has_feature("ios") or OS.has_feature("mobile") or (OS.get_name() in ["iOS", "Android"]) or bool(ProjectSettings.get_setting("display/window/simulate_ios_safe_area", false))

	# Dash (116px) at lower-right thumb rest; 98px skills on a 152px radial arc (>= 30px clear edge gap between circles).
	var specs: Array[Dictionary] = [
		{
			"id": "skill_1",
			"node_name": "skill1_btn",
			"key": "Q",
			"ab": hdef.skill_1 if hdef != null else null,
			"size": 98,
			"center": Vector2(69.0, 234.0) if has_s3 else Vector2(69.0, 231.0),
		},
		{
			"id": "skill_2",
			"node_name": "skill2_btn",
			"key": "E",
			"ab": hdef.skill_2 if hdef != null else null,
			"size": 98,
			"center": Vector2(111.0, 112.0) if has_s3 else Vector2(156.0, 80.0),
		},
	]
	if has_s3:
		specs.append({
			"id": "skill_3",
			"node_name": "skill3_btn",
			"key": "R",
			"ab": hdef.skill_3,
			"size": 98,
			"center": Vector2(231.0, 66.0),
		})
	specs.append({
		"id": "dash",
		"node_name": "dash_btn",
		"key": "SPC",
		"ab": hdef.dash_ability if hdef != null else null,
		"size": 116,
		"center": Vector2(220.0, 218.0),
	})

	for sp in specs:
		var aid := str(sp["id"])
		var btn_sz := int(sp["size"])
		var ab: AbilityDef = sp["ab"]
		var ab_id := ab.ability_id if ab != null else ("iron_roll" if aid == "dash" else "iron_tempest")
		var b_radius := btn_sz / 2

		var slot := Control.new()
		slot.size = Vector2(float(btn_sz), float(btn_sz))
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		action_cluster.add_child(slot)

		var btn := Button.new()
		btn.name = str(sp["node_name"])
		btn.custom_minimum_size = Vector2(btn_sz, btn_sz)
		btn.size = Vector2(btn_sz, btn_sz)
		btn.position = Vector2.ZERO
		btn.pivot_offset = Vector2(float(btn_sz) * 0.5, float(btn_sz) * 0.5)

		var border_w := 3 if aid == "dash" else 2
		var sb_n := UiThemeBuilder.make_box(Color(0.052, 0.058, 0.078, 0.88), UiThemeBuilder.BORDER_GOLD, border_w, b_radius, 0, 0)
		sb_n.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
		sb_n.shadow_size = 7
		var sb_h := UiThemeBuilder.make_box(Color(0.11, 0.12, 0.16, 0.94), UiThemeBuilder.BORDER_GOLD.lightened(0.24), border_w, b_radius, 0, 0)
		sb_h.shadow_color = Color(0.88, 0.68, 0.28, 0.34)
		sb_h.shadow_size = 8
		var sb_p := UiThemeBuilder.make_box(Color(0.24, 0.09, 0.08, 0.98), UiThemeBuilder.BORDER_GOLD, border_w, b_radius, 0, 0)
		btn.add_theme_stylebox_override("normal", sb_n)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("focus", sb_h)
		btn.add_theme_stylebox_override("pressed", sb_p)
		btn.gui_input.connect(_on_hud_btn_gui_input.bind(btn, aid))
		btn.pressed.connect(_on_action_btn_pressed.bind(aid))
		btn.button_down.connect(_on_action_btn_down.bind(btn))
		btn.button_up.connect(_on_action_btn_up.bind(btn))
		btn.mouse_exited.connect(_on_action_btn_up.bind(btn))
		slot.add_child(btn)

		var icon_tex := TextureRect.new()
		icon_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_tex.offset_left = 7.0
		icon_tex.offset_top = 7.0
		icon_tex.offset_right = -7.0
		icon_tex.offset_bottom = -7.0
		icon_tex.texture = UiThemeBuilder.get_skill_icon(ab_id)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_tex)

		var dial := Control.new()
		dial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dial.visible = false
		dial.set_meta("ratio", 0.0)
		dial.draw.connect(_draw_cd_dial.bind(dial))
		btn.add_child(dial)

		var flash := Control.new()
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.visible = false
		flash.set_meta("alpha", 0.0)
		flash.draw.connect(_draw_ready_flash.bind(flash))
		btn.add_child(flash)

		var cdlbl := Label.new()
		cdlbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cdlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cdlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiThemeBuilder.style_label(cdlbl, UiThemeBuilder.font_bold(), 26, Color.WHITE, 4)
		cdlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cdlbl.visible = false
		btn.add_child(cdlbl)

		if not is_mobile:
			var kbadge := PanelContainer.new()
			kbadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kbadge.position = Vector2(float(btn_sz) - 24.0, -4.0)
			kbadge.custom_minimum_size = Vector2(24.0, 20.0)
			kbadge.add_theme_stylebox_override("panel", UiThemeBuilder.make_pill(Color(0.05, 0.055, 0.075, 0.90), UiThemeBuilder.BORDER_BRONZE, 5, 1))
			var klbl := Label.new()
			klbl.text = str(sp["key"])
			klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UiThemeBuilder.style_label(klbl, UiThemeBuilder.font_title(), 10, UiThemeBuilder.TEXT_GOLD, 1)
			klbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kbadge.add_child(klbl)
			slot.add_child(kbadge)

		match aid:
			"skill_1":
				skill1_btn = btn
			"skill_2":
				skill2_btn = btn
			"skill_3":
				skill3_btn = btn
			"dash":
				dash_btn = btn

		_action_btns[aid] = {
			"slot": slot,
			"btn": btn,
			"icon": icon_tex,
			"dial": dial,
			"flash": flash,
			"cd_lbl": cdlbl,
			"center": sp["center"],
			"btn_size": float(btn_sz),
			"was_on_cd": false,
			"flash_alpha": 0.0,
		}


func _draw_cd_dial(dial: Control) -> void:
	var ratio := clampf(float(dial.get_meta("ratio", 0.0)), 0.0, 1.0)
	if ratio <= 0.001:
		return
	var r := minf(dial.size.x, dial.size.y) * 0.5 - 2.0
	var c := dial.size * 0.5
	dial.draw_circle(c, r, Color(0.02, 0.022, 0.032, 0.72))
	var start_a := -PI * 0.5
	var end_a := start_a + TAU * ratio
	var pts := PackedVector2Array([c])
	var segs := 32
	for i in range(segs + 1):
		var a := lerpf(start_a, end_a, float(i) / float(segs))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	dial.draw_colored_polygon(pts, Color(0.015, 0.018, 0.025, 0.36))
	dial.draw_arc(c, r - 2.0, start_a, end_a, 36, Color(0.92, 0.74, 0.38, 0.90), 3.0, true)


func _draw_ready_flash(flash: Control) -> void:
	var alpha := clampf(float(flash.get_meta("alpha", 0.0)), 0.0, 1.0)
	if alpha <= 0.01:
		return
	var r := minf(flash.size.x, flash.size.y) * 0.5 - 2.0
	var c := flash.size * 0.5
	flash.draw_circle(c, r, Color(0.98, 0.82, 0.40, alpha * 0.28))
	flash.draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(1.0, 0.88, 0.52, alpha * 0.95), 4.0, true)


func _on_action_btn_down(btn: Button) -> void:
	if btn != null and is_instance_valid(btn):
		btn.scale = Vector2(0.90, 0.90)


func _on_action_btn_up(btn: Button) -> void:
	if btn != null and is_instance_valid(btn):
		if btn.is_inside_tree():
			var tw := btn.create_tween()
			tw.tween_property(btn, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			btn.scale = Vector2.ONE


func _apply_safe_margins() -> void:
	_safe_margins = UiThemeBuilder.get_safe_margins(root_ctrl)
	var top_pad := int(_safe_margins["top"])
	var bot_pad := int(_safe_margins["bottom"])
	var left_pad := int(_safe_margins["left"])
	var right_pad := int(_safe_margins["right"])

	top_margin.add_theme_constant_override("margin_top", top_pad + 6)
	top_margin.add_theme_constant_override("margin_left", 12 + left_pad)
	top_margin.add_theme_constant_override("margin_right", 12 + right_pad)
	top_scrim.offset_bottom = float(top_pad + 140)

	var vp_w := root_ctrl.size.x if root_ctrl.size.x > 0.0 else 720.0
	boss_vbox.custom_minimum_size.x = minf(500.0, maxf(260.0, vp_w - float(left_pad + right_pad) - 48.0))

	var modal_w := minf(660.0, maxf(300.0, vp_w - float(left_pad + right_pad) - 40.0))
	shrine_card_panel.custom_minimum_size.x = modal_w
	pause_panel.custom_minimum_size.x = minf(600.0, modal_w)
	summary_panel.custom_minimum_size.x = modal_w

	for wrap in [shrine_safe_wrap, pause_safe_wrap, summary_safe_wrap]:
		wrap.add_theme_constant_override("margin_top", top_pad + 18)
		wrap.add_theme_constant_override("margin_bottom", bot_pad + 18)
		wrap.add_theme_constant_override("margin_left", left_pad + 20)
		wrap.add_theme_constant_override("margin_right", right_pad + 20)

	thumbstick.safe_bottom = float(bot_pad)
	_apply_handedness()


func _apply_handedness() -> void:
	var left_handed := false
	var gs := _game_state()
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		left_handed = bool((gs.settings as Dictionary).get("left_handed", false))

	var raw_bot := int(_safe_margins["bottom"])
	var bot_pad := float(raw_bot) + 14.0
	var side_pad := 14.0 + float(_safe_margins["left"] if left_handed else _safe_margins["right"])

	if left_handed:
		action_deck_margin.anchor_left = 0.0
		action_deck_margin.anchor_right = 0.0
		action_deck_margin.offset_left = side_pad
		action_deck_margin.offset_right = side_pad + ACTION_CLUSTER_W
		thumbstick.anchor_left = 0.48
		thumbstick.anchor_right = 1.0
		thumbstick.anchor_top = 0.28
		thumbstick.anchor_bottom = 1.0
		thumbstick.offset_left = 0.0
		thumbstick.offset_right = -float(_safe_margins["right"])
		thumbstick.is_right_side = true
	else:
		action_deck_margin.anchor_left = 1.0
		action_deck_margin.anchor_right = 1.0
		action_deck_margin.offset_left = -(side_pad + ACTION_CLUSTER_W)
		action_deck_margin.offset_right = -side_pad
		thumbstick.anchor_left = 0.0
		thumbstick.anchor_right = 0.52
		thumbstick.anchor_top = 0.28
		thumbstick.anchor_bottom = 1.0
		thumbstick.offset_left = float(_safe_margins["left"])
		thumbstick.offset_right = 0.0
		thumbstick.is_right_side = false

	action_deck_margin.anchor_top = 1.0
	action_deck_margin.anchor_bottom = 1.0
	action_deck_margin.offset_top = -(bot_pad + ACTION_CLUSTER_H)
	action_deck_margin.offset_bottom = -bot_pad

	for aid in _action_btns:
		var d: Dictionary = _action_btns[aid]
		var slot: Control = d["slot"]
		var raw_c: Vector2 = d["center"]
		var bsz: float = float(d["btn_size"])
		var cx := (ACTION_CLUSTER_W - raw_c.x) if left_handed else raw_c.x
		slot.position = Vector2(cx - bsz * 0.5, raw_c.y - bsz * 0.5)

	thumbstick.queue_redraw()


func _on_hud_updated(state: Dictionary) -> void:
	if state.is_empty():
		return

	var cid := str(state.get("class_id", "oathbreaker"))
	hero_portrait_tex.texture = UiThemeBuilder.get_portrait(cid)

	var hp := float(state.get("hp", 200.0))
	var mhp := maxf(1.0, float(state.get("max_hp", 200.0)))
	var ward := maxf(0.0, float(state.get("ward_hp", 0.0)))

	if _last_hero_hp >= 0.0 and hp < _last_hero_hp - 0.5:
		_trigger_damage_flash()
	_last_hero_hp = hp
	_hero_hp_ratio = clampf(hp / mhp, 0.0, 1.0)

	hp_bar.max_value = mhp
	hp_bar.value = clampf(hp, 0.0, mhp)
	hp_lbl.text = "%d / %d" % [maxi(0, roundi(hp)), roundi(mhp)]

	var has_ward := ward > 0.5
	ward_bar_wrap.visible = has_ward
	if has_ward:
		ward_bar.max_value = mhp * 0.5
		ward_bar.value = clampf(ward, 0.0, mhp * 0.5)

	var cl_done := int(state.get("clearings_cleared", 0))
	var cl_total := maxi(1, int(state.get("clearings_total", 3)))
	var gate_open := bool(state.get("boss_gate_unlocked", false))
	var boss_active := bool(state.get("boss_active", false))
	var foes_alive := int(state.get("enemies_alive", 0))
	var gold_run := int(state.get("gold", 0))
	var relics_run := int(state.get("items_collected", 0))

	var shrine_unvisited := false
	if director != null and director.dark_shrine != null and is_instance_valid(director.dark_shrine):
		shrine_unvisited = not director.dark_shrine.is_consumed

	var obj_prefix := ""
	if boss_active:
		obj_prefix = "GUARDIAN ENGAGED"
	elif gate_open:
		obj_prefix = "SHRINE & BOSS GATE" if shrine_unvisited else "ENTER BOSS SANCTUM"
	else:
		var cur_cl := mini(cl_done + 1, cl_total)
		if cl_done >= 1 and shrine_unvisited and foes_alive == 0:
			obj_prefix = "DARK SHRINE · %d/%d" % [cur_cl, cl_total]
		else:
			obj_prefix = "CLEARING %d/%d · %d FOES" % [cur_cl, cl_total, foes_alive]

	var loot_suffix := "%dg" % gold_run
	if relics_run > 0:
		loot_suffix += " · %d %s" % [relics_run, "Relic" if relics_run == 1 else "Relics"]
	objective_lbl.text = "%s  ·  %s" % [obj_prefix, loot_suffix]

	if director != null and director.class_def != null:
		var hdef := director.class_def
		if hdef.skill_1 != null and _action_btns.has("skill_1"):
			(_action_btns["skill_1"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.skill_1.ability_id)
		if hdef.skill_2 != null and _action_btns.has("skill_2"):
			(_action_btns["skill_2"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.skill_2.ability_id)
		if hdef.skill_3 != null and _action_btns.has("skill_3"):
			(_action_btns["skill_3"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.skill_3.ability_id)
		if hdef.dash_ability != null and _action_btns.has("dash"):
			(_action_btns["dash"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.dash_ability.ability_id)


func _trigger_damage_flash() -> void:
	var peak := 0.24 if _reduce_flashing() else 0.55
	_damage_flash_alpha = maxf(_damage_flash_alpha, peak)


func _tick_vignette(delta: float) -> void:
	if _damage_flash_alpha > 0.0:
		_damage_flash_alpha = maxf(0.0, _damage_flash_alpha - (0.55 / 0.28) * delta)
	var pulse_alpha := 0.0
	if _hero_hp_ratio > 0.0 and _hero_hp_ratio < 0.30 and director != null and not director.run_finished:
		_low_hp_pulse_t += delta * 3.8
		var hi := 0.24 if _reduce_flashing() else 0.38
		pulse_alpha = lerpf(0.15, hi, 0.5 + 0.5 * sin(_low_hp_pulse_t))
	var final_a := maxf(_damage_flash_alpha, pulse_alpha)
	damage_vignette.visible = final_a > 0.005
	if damage_vignette.visible:
		damage_vignette.modulate = Color(0.88, 0.09, 0.09, final_a)


func _update_live_cooldowns(delta: float) -> void:
	if director == null or director.hero == null or not is_instance_valid(director.hero):
		return
	var h := director.hero
	_apply_cd_visual("skill_1", h.skill_1_cooldown_left, h.skill_1_cooldown_max, delta)
	_apply_cd_visual("skill_2", h.skill_2_cooldown_left, h.skill_2_cooldown_max, delta)
	if _action_btns.has("skill_3"):
		_apply_cd_visual("skill_3", h.skill_3_cooldown_left, h.skill_3_cooldown_max, delta)
	_apply_cd_visual("dash", h.dash_cooldown_left, h.dash_cooldown_max, delta)


func _apply_cd_visual(aid: String, cd_left: float, cd_max: float, delta: float) -> void:
	if not _action_btns.has(aid):
		return
	var d: Dictionary = _action_btns[aid]
	var dial: Control = d["dial"]
	var flash: Control = d["flash"]
	var cdlbl: Label = d["cd_lbl"]
	var icon_tex: TextureRect = d["icon"]
	var btn: Button = d["btn"]
	var was_on_cd := bool(d["was_on_cd"])
	var flash_a := float(d["flash_alpha"])

	if cd_left > 0.04:
		var ratio := clampf(cd_left / maxf(0.1, cd_max), 0.0, 1.0)
		dial.set_meta("ratio", ratio)
		dial.visible = true
		dial.queue_redraw()
		cdlbl.visible = true
		cdlbl.text = "%.1f" % cd_left if cd_left < 2.0 else "%d" % ceili(cd_left)
		icon_tex.modulate = Color(0.52, 0.52, 0.60, 1.0)
		d["was_on_cd"] = true
	else:
		dial.visible = false
		cdlbl.visible = false
		icon_tex.modulate = Color.WHITE
		if was_on_cd:
			d["was_on_cd"] = false
			flash_a = 0.45 if _reduce_flashing() else 0.90
			if btn != null and is_instance_valid(btn) and btn.is_inside_tree():
				btn.scale = Vector2(1.07, 1.07)
				var tw := btn.create_tween()
				tw.tween_property(btn, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if flash_a > 0.005:
		flash_a = maxf(0.0, flash_a - delta * 3.2)
		flash.set_meta("alpha", flash_a)
		flash.visible = flash_a > 0.005
		if flash.visible:
			flash.queue_redraw()
	else:
		flash.visible = false
	d["flash_alpha"] = flash_a
	_action_btns[aid] = d


func _draw_combat_overlay() -> void:
	if director == null or not is_instance_valid(director) or not director.run_started or director.run_finished:
		return
	var cam := director.get_camera()
	if cam == null:
		return
	var vp_size := combat_overlay.size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return

	var tracked := director.get_hud_tracked_enemies()
	var drawn := 0
	for e_v in tracked:
		if drawn >= 16:
			break
		if not (e_v is EnemyController3D):
			continue
		var e := e_v as EnemyController3D
		if not is_instance_valid(e) or e.is_dead():
			continue
		var e_origin := e.get_global_transform_interpolated().origin if e.is_inside_tree() else e.global_position
		var head_h := 2.35 if e.is_elite else 1.92
		if e.visual != null and is_instance_valid(e.visual):
			head_h = maxf(1.55, e.visual.height_meters + 0.34)
		var world_head := e_origin + Vector3(0.0, head_h, 0.0)
		if cam.is_position_behind(world_head):
			continue
		var sp := cam.unproject_position(world_head)
		if sp.x < -40.0 or sp.x > vp_size.x + 40.0 or sp.y < -20.0 or sp.y > vp_size.y + 20.0:
			continue
		var bar_w := 56.0 if e.is_elite else 46.0
		var bar_h := 7.0 if e.is_elite else 6.0
		var ratio := clampf(e.current_hp / maxf(1.0, e.max_hp), 0.0, 1.0)
		var bx := sp.x - bar_w * 0.5
		var by := sp.y - bar_h
		var bg_rect := Rect2(bx - 1.0, by - 1.0, bar_w + 2.0, bar_h + 2.0)
		var border_col := UiThemeBuilder.BORDER_GOLD if e.is_elite else Color(0.02, 0.02, 0.03, 0.94)
		combat_overlay.draw_rect(bg_rect, border_col, true)
		combat_overlay.draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0.05, 0.05, 0.07, 0.88), true)
		var fill_col := Color(0.95, 0.42, 0.16, 0.98) if e.is_elite else Color(0.84, 0.17, 0.18, 0.96)
		combat_overlay.draw_rect(Rect2(bx, by, bar_w * ratio, bar_h), fill_col, true)
		drawn += 1

	_draw_objective_chevron(cam, vp_size)


func _draw_objective_chevron(cam: Camera3D, vp_size: Vector2) -> void:
	var target_world := director.get_objective_target_world_pos()
	if director.hero != null and is_instance_valid(director.hero):
		var d_sq := Vector2(target_world.x - director.hero.global_position.x, target_world.z - director.hero.global_position.z).length_squared()
		if d_sq < 4.5:
			return
	var target_pt := target_world + Vector3(0.0, 1.05, 0.0)
	var behind := cam.is_position_behind(target_pt)
	var proj := cam.unproject_position(target_pt)

	var safe_top := float(_safe_margins["top"]) + 116.0
	var safe_bot := vp_size.y - float(_safe_margins["bottom"]) - 36.0
	var safe_left := float(_safe_margins["left"]) + 32.0
	var safe_right := vp_size.x - float(_safe_margins["right"]) - 32.0

	if not behind and proj.x >= safe_left and proj.x <= safe_right and proj.y >= safe_top and proj.y <= safe_bot:
		return

	var center := vp_size * 0.5
	var dir: Vector2
	if behind:
		var local_p := cam.global_transform.affine_inverse() * target_pt
		dir = Vector2(local_p.x, -local_p.y)
		if dir.length_squared() < 0.0001:
			dir = Vector2(0.0, 1.0)
		else:
			dir = dir.normalized()
	else:
		dir = (proj - center).normalized()

	var t_max := INF
	if absf(dir.x) > 0.0001:
		var tx := ((safe_right - center.x) / dir.x) if dir.x > 0.0 else ((safe_left - center.x) / dir.x)
		if tx > 0.0:
			t_max = minf(t_max, tx)
	if absf(dir.y) > 0.0001:
		var ty := ((safe_bot - center.y) / dir.y) if dir.y > 0.0 else ((safe_top - center.y) / dir.y)
		if ty > 0.0:
			t_max = minf(t_max, ty)
	if not is_finite(t_max):
		return

	var edge_pos := center + dir * t_max
	var perp := Vector2(-dir.y, dir.x)
	var is_hostile := not director.get_alive_enemies().is_empty()
	var accent := Color(0.95, 0.30, 0.24, 0.96) if is_hostile else Color(0.96, 0.78, 0.36, 0.96)

	var tip := edge_pos + dir * 13.0
	var wing_l := edge_pos - dir * 10.0 + perp * 11.0
	var wing_r := edge_pos - dir * 10.0 - perp * 11.0
	var notch := edge_pos - dir * 4.0

	combat_overlay.draw_colored_polygon(
		PackedVector2Array([tip + dir * 2.0, wing_l + perp * 2.5 - dir * 1.5, notch - dir * 2.0, wing_r - perp * 2.5 - dir * 1.5]),
		Color(0.02, 0.02, 0.03, 0.85)
	)
	combat_overlay.draw_colored_polygon(PackedVector2Array([tip, wing_l, notch, wing_r]), accent)
	combat_overlay.draw_circle(edge_pos - dir * 1.0, 3.0, Color(1.0, 0.96, 0.86, 0.92))


func _on_boss_updated(boss_name: String, boss_title: String, current_hp: float, max_hp: float, is_enraged: bool) -> void:
	boss_center.visible = current_hp > 0.0
	if not boss_center.visible:
		return
	boss_name_lbl.text = "%s — %s" % [boss_name.to_upper(), boss_title]
	boss_enraged_badge.visible = is_enraged
	boss_hp_bar.max_value = maxf(1.0, max_hp)
	boss_hp_bar.value = clampf(current_hp, 0.0, max_hp)
	boss_hp_lbl.text = "%d / %d" % [maxi(0, roundi(current_hp)), roundi(max_hp)]


func _on_damage_floated(world_pos: Vector3, amount: int, is_crit: bool, is_hero_hurt: bool, is_heal: bool) -> void:
	if is_hero_hurt and amount > 0:
		_trigger_damage_flash()
	var gs := _game_state()
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		if not bool((gs.settings as Dictionary).get("damage_numbers", true)):
			return
	if director == null or _floater_pool.is_empty():
		return
	var cam := director.get_camera()
	if cam == null or cam.is_position_behind(world_pos):
		return

	_refresh_floater_label_settings()

	var slot_idx := -1
	var oldest_idx := 0
	var oldest_age := -1.0
	for i in range(_floater_pool.size()):
		var f: Dictionary = _floater_pool[i]
		if not bool(f["active"]):
			slot_idx = i
			break
		if float(f["age"]) > oldest_age:
			oldest_age = float(f["age"])
			oldest_idx = i
	if slot_idx < 0:
		slot_idx = oldest_idx

	var entry: Dictionary = _floater_pool[slot_idx]
	var lbl: Label = entry["lbl"]
	if lbl == null or not is_instance_valid(lbl):
		return

	var txt := "%d" % amount
	var ls := _floater_ls_normal
	if is_heal:
		ls = _floater_ls_heal
		txt = "+%d" % amount
	elif is_hero_hurt:
		ls = _floater_ls_hurt
		txt = "-%d" % amount
	elif is_crit:
		ls = _floater_ls_crit
		txt = "%d!" % amount

	var screen_pt := cam.unproject_position(world_pos + Vector3(0.0, 1.25, 0.0))
	var jitter_x := randf_range(-18.0, 18.0)
	lbl.label_settings = ls
	lbl.text = txt
	lbl.position = screen_pt + Vector2(jitter_x - 28.0, -14.0)
	lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
	lbl.visible = true

	entry["active"] = true
	entry["vel"] = Vector2(jitter_x * 0.45, -66.0 if is_crit else -50.0)
	entry["age"] = 0.0
	entry["life"] = 0.72
	_floater_pool[slot_idx] = entry


func _tick_floaters(delta: float) -> void:
	for i in range(_floater_pool.size()):
		var f: Dictionary = _floater_pool[i]
		if not bool(f["active"]):
			continue
		var lbl: Label = f["lbl"]
		if lbl == null or not is_instance_valid(lbl):
			f["active"] = false
			_floater_pool[i] = f
			continue
		var age := float(f["age"]) + delta
		var life := float(f["life"])
		if age >= life:
			lbl.visible = false
			f["active"] = false
			_floater_pool[i] = f
			continue
		f["age"] = age
		var vel: Vector2 = f["vel"]
		lbl.position += vel * delta
		lbl.modulate.a = 1.0 - clampf((age - life * 0.45) / (life * 0.55), 0.0, 1.0)
		_floater_pool[i] = f


func _on_shrine_offered(choices: Array[ShrineBlessingDef]) -> void:
	thumbstick.reset_stick()
	for ch in shrine_choices_box.get_children():
		ch.queue_free()

	for bdef in choices:
		if bdef == null:
			continue
		var rcol := GameEnums.rarity_color(bdef.rarity)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 124)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiThemeBuilder.style_rarity_tile(btn, bdef.rarity, false, 12)
		btn.pressed.connect(_on_shrine_choice_picked.bind(bdef.blessing_id))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 6)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vb)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top)

		var t_lbl := Label.new()
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.text = bdef.display_name.to_upper()
		UiThemeBuilder.style_label(t_lbl, UiThemeBuilder.font_title(), 20, rcol)
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(t_lbl)

		var r_lbl := Label.new()
		r_lbl.text = "[%s]" % GameEnums.rarity_name(bdef.rarity).to_upper()
		UiThemeBuilder.style_label(r_lbl, UiThemeBuilder.font_title(), 14, rcol)
		r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(r_lbl)

		var d_lbl := Label.new()
		d_lbl.text = bdef.description
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiThemeBuilder.style_label(d_lbl, UiThemeBuilder.font_body(), 18, UiThemeBuilder.TEXT_PARCHMENT, 1)
		d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(d_lbl)

		shrine_choices_box.add_child(btn)

	_shrine_input_guard = 0.45
	shrine_modal.visible = true


func _on_shrine_choice_picked(blessing_id: String) -> void:
	if _shrine_input_guard > 0.0:
		return
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
		UiThemeBuilder.style_label(empty_lbl, UiThemeBuilder.font_body(), 17, UiThemeBuilder.TEXT_MUTED, 1)
		summary_loot_list.add_child(empty_lbl)
	else:
		for d_item in drops:
			if not (d_item is EquipmentItem):
				continue
			var item := d_item as EquipmentItem
			var rcol := GameEnums.rarity_color(item.rarity)
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(Color(0.048, 0.052, 0.072, 0.88).lerp(rcol, 0.10), rcol, 2, 10, 10, 8))

			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 12)
			card.add_child(hb)

			var iframe := PanelContainer.new()
			iframe.custom_minimum_size = Vector2(64, 64)
			iframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			iframe.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_ABYSS, rcol, 1, 8, 3, 3))
			hb.add_child(iframe)

			var itex := TextureRect.new()
			itex.texture = UiThemeBuilder.get_item_icon(item)
			itex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			itex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			iframe.add_child(itex)

			var vb := VBoxContainer.new()
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vb.add_theme_constant_override("separation", 3)
			hb.add_child(vb)

			var nlbl := Label.new()
			nlbl.text = "%s  (T%d %s · PWR %d)" % [
				item.display_name(),
				item.tier,
				GameEnums.rarity_name(item.rarity),
				item.power_score(),
			]
			UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_title(), 17, rcol)
			vb.add_child(nlbl)

			var details: Array[String] = [UiThemeBuilder.format_item_primary_line(item)]
			for af in item.affixes:
				if af != null:
					details.append(af.format_line())
			var slbl := Label.new()
			slbl.text = "  ·  ".join(details)
			slbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UiThemeBuilder.style_label(slbl, UiThemeBuilder.font_body(), 15, UiThemeBuilder.TEXT_PARCHMENT, 1)
			vb.add_child(slbl)

			summary_loot_list.add_child(card)

	summary_modal.visible = true


func _on_thumbstick_moved(vec: Vector2) -> void:
	if director != null:
		director.set_virtual_move(vec)


func _on_hud_btn_gui_input(event: InputEvent, btn: Button, aid: String) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var now := Time.get_ticks_usec()
		if st.pressed and not st.canceled:
			_touch_active = true
			_touch_held_index[aid] = st.index
			_touch_guard_until_usec[aid] = now + 350_000
			_on_action_btn_down(btn)
			_dispatch_hud_action(aid)
			btn.accept_event()
		elif (not st.pressed or st.canceled) and int(_touch_held_index.get(aid, -1)) == st.index:
			_touch_held_index.erase(aid)
			_touch_guard_until_usec[aid] = now + 220_000
			_touch_active = not _touch_held_index.is_empty()
			_on_action_btn_up(btn)
			btn.accept_event()
	elif event is InputEventMouseButton:
		if _touch_active or Time.get_ticks_usec() < int(_touch_guard_until_usec.get(aid, 0)):
			btn.accept_event()


func _on_pause_btn_pressed() -> void:
	if Time.get_ticks_usec() < int(_touch_guard_until_usec.get("pause", 0)):
		return
	open_pause_modal()


func _on_action_btn_pressed(aid: String) -> void:
	if Time.get_ticks_usec() < int(_touch_guard_until_usec.get(aid, 0)):
		return
	_dispatch_hud_action(aid)


func _dispatch_hud_action(aid: String) -> void:
	if aid == "pause":
		open_pause_modal()
		return
	if director == null:
		return
	match aid:
		"skill_1":
			director.press_skill_1()
		"skill_2":
			director.press_skill_2()
		"skill_3":
			director.press_skill_3()
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


func _reduce_flashing() -> bool:
	var gs := _game_state()
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		return bool((gs.settings as Dictionary).get("reduce_flashing", false))
	var ad := _audio()
	if ad != null and "settings" in ad and ad.settings is Dictionary:
		return bool((ad.settings as Dictionary).get("reduce_flashing", false))
	return false


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
