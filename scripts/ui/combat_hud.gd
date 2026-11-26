class_name CombatHud
extends CanvasLayer

signal return_to_sanctum_requested()
signal hunt_again_requested()

@onready var root_ctrl: Control = $Root
@onready var floaters_layer: Control = $Root/FloatersLayer

@onready var top_margin: MarginContainer = $Root/TopMargin
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
@onready var action_cluster: Control = $Root/ActionDeckMargin/ActionCluster

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
var skill1_btn: Button = null
var skill2_btn: Button = null
var skill3_btn: Button = null
var dash_btn: Button = null
var _action_btns: Dictionary = {}
var _floaters: Array[Dictionary] = []
var _syncing_pause_settings: bool = false
var _tracked_enemy_ids: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.theme = UiThemeBuilder.get_theme()

	_style_static_chrome()
	_build_action_buttons()
	root_ctrl.resized.connect(_apply_safe_margins)
	_apply_safe_margins()

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
	for ch in action_cluster.get_children():
		ch.queue_free()
	_action_btns.clear()
	skill1_btn = null
	skill2_btn = null
	skill3_btn = null
	dash_btn = null

	var hdef := director.class_def if director != null else GameRegistry.get_class_def("oathbreaker")
	var has_s3 := hdef != null and hdef.skill_3 != null
	var is_mobile := OS.get_name() in ["iOS", "Android"]

	var specs: Array[Dictionary] = [
		{
			"id": "skill_1",
			"node_name": "skill1_btn",
			"key": "Q",
			"ab": hdef.skill_1 if hdef != null else null,
			"short": _short_skill_label(hdef.skill_1 if hdef != null else null, "TEMPEST"),
			"size": 78,
			"center": Vector2(86.0, 202.0) if has_s3 else Vector2(96.0, 198.0),
		},
		{
			"id": "skill_2",
			"node_name": "skill2_btn",
			"key": "E",
			"ab": hdef.skill_2 if hdef != null else null,
			"short": _short_skill_label(hdef.skill_2 if hdef != null else null, "PYRE"),
			"size": 78,
			"center": Vector2(128.0, 100.0) if has_s3 else Vector2(180.0, 86.0),
		},
	]
	if has_s3:
		specs.append({
			"id": "skill_3",
			"node_name": "skill3_btn",
			"key": "R",
			"ab": hdef.skill_3,
			"short": _short_skill_label(hdef.skill_3, "STORM"),
			"size": 78,
			"center": Vector2(230.0, 58.0),
		})
	specs.append({
		"id": "dash",
		"node_name": "dash_btn",
		"key": "SPC",
		"ab": hdef.dash_ability if hdef != null else null,
		"short": "DASH",
		"size": 86,
		"center": Vector2(224.0, 196.0),
	})

	for sp in specs:
		var aid := str(sp["id"])
		var btn_sz := int(sp["size"])
		var ab: AbilityDef = sp["ab"]
		var ab_id := ab.ability_id if ab != null else ("iron_roll" if aid == "dash" else "iron_tempest")
		var b_radius := 44

		var slot := Control.new()
		slot.size = Vector2(float(btn_sz) + 20.0, float(btn_sz) + 24.0)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		action_cluster.add_child(slot)

		var btn := Button.new()
		btn.name = str(sp["node_name"])
		btn.custom_minimum_size = Vector2(btn_sz, btn_sz)
		btn.size = Vector2(btn_sz, btn_sz)
		btn.position = Vector2(10.0, 0.0)
		btn.pivot_offset = Vector2(float(btn_sz) * 0.5, float(btn_sz) * 0.5)

		var border_w := 3 if aid == "dash" else 2
		var sb_n := UiThemeBuilder.make_box(Color(0.055, 0.062, 0.082, 0.94), UiThemeBuilder.BORDER_GOLD, border_w, b_radius, 0, 0)
		sb_n.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
		sb_n.shadow_size = 5
		var sb_h := UiThemeBuilder.make_box(Color(0.11, 0.12, 0.16, 0.96), UiThemeBuilder.BORDER_GOLD.lightened(0.22), border_w, b_radius, 0, 0)
		sb_h.shadow_color = Color(0.85, 0.65, 0.25, 0.30)
		sb_h.shadow_size = 6
		var sb_p := UiThemeBuilder.make_box(Color(0.24, 0.09, 0.08, 0.98), UiThemeBuilder.BORDER_GOLD, border_w, b_radius, 0, 0)
		btn.add_theme_stylebox_override("normal", sb_n)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("focus", sb_h)
		btn.add_theme_stylebox_override("pressed", sb_p)
		btn.pressed.connect(_on_action_btn_pressed.bind(aid))
		btn.button_down.connect(_on_action_btn_down.bind(btn))
		btn.button_up.connect(_on_action_btn_up.bind(btn))
		btn.mouse_exited.connect(_on_action_btn_up.bind(btn))
		slot.add_child(btn)

		var icon_tex := TextureRect.new()
		icon_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_tex.offset_left = 3.0
		icon_tex.offset_top = 3.0
		icon_tex.offset_right = -3.0
		icon_tex.offset_bottom = -3.0
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

		var cdlbl := Label.new()
		cdlbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cdlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cdlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiThemeBuilder.style_label(cdlbl, UiThemeBuilder.font_bold(), 20, Color.WHITE, 3)
		cdlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cdlbl.visible = false
		btn.add_child(cdlbl)

		if not is_mobile:
			var kbadge := PanelContainer.new()
			kbadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kbadge.position = Vector2(float(btn_sz) - 20.0, -4.0)
			kbadge.custom_minimum_size = Vector2(22.0, 18.0)
			kbadge.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(Color(0.05, 0.055, 0.075, 0.92), UiThemeBuilder.BORDER_BRONZE, 1, 6, 3, 1))
			var klbl := Label.new()
			klbl.text = str(sp["key"])
			klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UiThemeBuilder.style_label(klbl, UiThemeBuilder.font_title(), 9, UiThemeBuilder.TEXT_GOLD, 1)
			klbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kbadge.add_child(klbl)
			slot.add_child(kbadge)

		var nlbl := Label.new()
		nlbl.text = str(sp["short"])
		nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlbl.position = Vector2(0.0, float(btn_sz) + 2.0)
		nlbl.size = Vector2(float(btn_sz) + 20.0, 20.0)
		UiThemeBuilder.style_label(nlbl, UiThemeBuilder.font_title(), 11, UiThemeBuilder.TEXT_PARCHMENT, 2)
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(nlbl)

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
			"name_lbl": nlbl,
			"cd_lbl": cdlbl,
			"center": sp["center"],
			"btn_size": float(btn_sz),
		}


static func _short_skill_label(ab: AbilityDef, fallback: String) -> String:
	if ab == null:
		return fallback
	match ab.ability_id:
		"iron_tempest":
			return "TEMPEST"
		"blackflame_pyre":
			return "PYRE"
		"stormbrand_arc":
			return "STORM"
		"iron_roll":
			return "DASH"
		_:
			return ab.display_name.get_slice(" ", 0).to_upper()


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
	var segs := 28
	for i in range(segs + 1):
		var a := lerpf(start_a, end_a, float(i) / float(segs))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	dial.draw_colored_polygon(pts, Color(0.015, 0.018, 0.025, 0.35))
	dial.draw_arc(c, r - 1.5, start_a, end_a, 32, Color(0.88, 0.70, 0.34, 0.85), 2.5, true)


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
	var m := UiThemeBuilder.get_safe_margins(root_ctrl)
	var top_pad := int(m["top"])
	top_margin.add_theme_constant_override("margin_top", (6 + top_pad) if top_pad > 0 else 10)
	top_margin.add_theme_constant_override("margin_left", 10 + int(m["left"]))
	top_margin.add_theme_constant_override("margin_right", 10 + int(m["right"]))
	thumbstick.safe_bottom = float(m["bottom"])
	_apply_handedness()


func _apply_handedness() -> void:
	var left_handed := false
	var gs := _game_state()
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		left_handed = bool((gs.settings as Dictionary).get("left_handed", false))

	var m := UiThemeBuilder.get_safe_margins(root_ctrl)
	var raw_bot := int(m["bottom"])
	var bot_pad := (12.0 + float(raw_bot)) if raw_bot > 0 else 18.0
	var side_pad := 14.0 + float(m["left"] if left_handed else m["right"])
	var cluster_w := 292.0
	var cluster_h := 276.0

	if left_handed:
		action_deck_margin.anchor_left = 0.0
		action_deck_margin.anchor_right = 0.0
		action_deck_margin.offset_left = side_pad
		action_deck_margin.offset_right = side_pad + cluster_w
		thumbstick.anchor_left = 0.42
		thumbstick.anchor_right = 1.0
		thumbstick.offset_left = 0.0
		thumbstick.offset_right = -float(m["right"])
		thumbstick.is_right_side = true
	else:
		action_deck_margin.anchor_left = 1.0
		action_deck_margin.anchor_right = 1.0
		action_deck_margin.offset_left = -(side_pad + cluster_w)
		action_deck_margin.offset_right = -side_pad
		thumbstick.anchor_left = 0.0
		thumbstick.anchor_right = 0.58
		thumbstick.offset_left = float(m["left"])
		thumbstick.offset_right = 0.0
		thumbstick.is_right_side = false

	action_deck_margin.anchor_top = 1.0
	action_deck_margin.anchor_bottom = 1.0
	action_deck_margin.offset_top = -(bot_pad + cluster_h)
	action_deck_margin.offset_bottom = -bot_pad

	for aid in _action_btns:
		var d: Dictionary = _action_btns[aid]
		var slot: Control = d["slot"]
		var raw_c: Vector2 = d["center"]
		var bsz: float = float(d["btn_size"])
		var cx := (cluster_w - raw_c.x) if left_handed else raw_c.x
		slot.position = Vector2(cx - (bsz + 20.0) * 0.5, raw_c.y - bsz * 0.5)

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
		if hdef.skill_1 != null and _action_btns.has("skill_1"):
			(_action_btns["skill_1"]["name_lbl"] as Label).text = _short_skill_label(hdef.skill_1, "TEMPEST")
			(_action_btns["skill_1"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.skill_1.ability_id)
		if hdef.skill_2 != null and _action_btns.has("skill_2"):
			(_action_btns["skill_2"]["name_lbl"] as Label).text = _short_skill_label(hdef.skill_2, "PYRE")
			(_action_btns["skill_2"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.skill_2.ability_id)
		if hdef.skill_3 != null and _action_btns.has("skill_3"):
			(_action_btns["skill_3"]["name_lbl"] as Label).text = _short_skill_label(hdef.skill_3, "STORM")
			(_action_btns["skill_3"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.skill_3.ability_id)
		if hdef.dash_ability != null and _action_btns.has("dash"):
			(_action_btns["dash"]["name_lbl"] as Label).text = _short_skill_label(hdef.dash_ability, "DASH")
			(_action_btns["dash"]["icon"] as TextureRect).texture = UiThemeBuilder.get_skill_icon(hdef.dash_ability.ability_id)


func _update_live_cooldowns() -> void:
	if director == null or director.hero == null or not is_instance_valid(director.hero):
		return
	var h := director.hero
	_apply_cd_visual("skill_1", h.skill_1_cooldown_left, h.skill_1_cooldown_max)
	_apply_cd_visual("skill_2", h.skill_2_cooldown_left, h.skill_2_cooldown_max)
	if _action_btns.has("skill_3"):
		_apply_cd_visual("skill_3", h.skill_3_cooldown_left, h.skill_3_cooldown_max)
	_apply_cd_visual("dash", h.dash_cooldown_left, h.dash_cooldown_max)


func _apply_cd_visual(aid: String, cd_left: float, cd_max: float) -> void:
	if not _action_btns.has(aid):
		return
	var d: Dictionary = _action_btns[aid]
	var dial: Control = d["dial"]
	var cdlbl: Label = d["cd_lbl"]
	var icon_tex: TextureRect = d["icon"]
	if cd_left > 0.04:
		var ratio := clampf(cd_left / maxf(0.1, cd_max), 0.0, 1.0)
		dial.set_meta("ratio", ratio)
		dial.visible = true
		dial.queue_redraw()
		cdlbl.visible = true
		cdlbl.text = "%.1f" % cd_left if cd_left < 2.0 else "%d" % ceili(cd_left)
		icon_tex.modulate = Color(0.55, 0.55, 0.62, 1.0)
	else:
		dial.visible = false
		cdlbl.visible = false
		icon_tex.modulate = Color.WHITE


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


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")
