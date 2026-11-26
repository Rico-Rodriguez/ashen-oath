class_name SettingsModal
extends ColorRect

signal closed()
signal settings_updated()

@onready var safe_wrap: MarginContainer = $SafeWrap
@onready var card: PanelContainer = $SafeWrap/Center/Card
@onready var body_scroll: ScrollContainer = $SafeWrap/Center/Card/CardVBox/BodyScroll
@onready var title_lbl: Label = $SafeWrap/Center/Card/CardVBox/TitleLbl
@onready var music_toggle: CheckButton = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/MusicToggle
@onready var music_lbl: Label = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/MusicSliderRow/MusicLbl
@onready var music_slider: HSlider = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/MusicSliderRow/MusicSlider
@onready var music_val_lbl: Label = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/MusicSliderRow/MusicValLbl
@onready var sfx_toggle: CheckButton = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/SfxToggle
@onready var sfx_lbl: Label = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/SfxSliderRow/SfxLbl
@onready var sfx_slider: HSlider = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/SfxSliderRow/SfxSlider
@onready var sfx_val_lbl: Label = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/SfxSliderRow/SfxValLbl
@onready var haptics_toggle: CheckButton = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/HapticsToggle
@onready var shake_toggle: CheckButton = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/ShakeToggle
@onready var reduce_flash_toggle: CheckButton = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/ReduceFlashToggle
@onready var numbers_toggle: CheckButton = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/NumbersToggle
@onready var lefty_toggle: CheckButton = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/LeftyToggle
@onready var text_size_lbl: Label = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/TextSizeLbl
@onready var text_size_100_btn: Button = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/TextSizeRow/TextSize100Btn
@onready var text_size_115_btn: Button = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/TextSizeRow/TextSize115Btn
@onready var text_size_130_btn: Button = $SafeWrap/Center/Card/CardVBox/BodyScroll/VBox/TextSizeRow/TextSize130Btn
@onready var close_btn: Button = $SafeWrap/Center/Card/CardVBox/CloseBtn

var _syncing: bool = false
var _text_size_btns: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_text_size_btns = {
		100: text_size_100_btn,
		115: text_size_115_btn,
		130: text_size_130_btn,
	}

	var modal_sb := UiThemeBuilder.make_glass_panel(Color(0.052, 0.056, 0.076, 0.96), UiThemeBuilder.BORDER_GOLD, 16, 22, 20)
	modal_sb.set_border_width_all(1)
	modal_sb.border_width_top = 2
	card.add_theme_stylebox_override("panel", modal_sb)

	_style_controls()
	resized.connect(_apply_safe_layout)
	_apply_safe_layout()

	music_toggle.toggled.connect(_on_music_toggled)
	music_slider.value_changed.connect(_on_music_vol_changed)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	sfx_slider.value_changed.connect(_on_sfx_vol_changed)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	shake_toggle.toggled.connect(_on_shake_toggled)
	reduce_flash_toggle.toggled.connect(_on_reduce_flash_toggled)
	numbers_toggle.toggled.connect(_on_numbers_toggled)
	lefty_toggle.toggled.connect(_on_lefty_toggled)
	text_size_100_btn.pressed.connect(_on_text_size_pressed.bind(100))
	text_size_115_btn.pressed.connect(_on_text_size_pressed.bind(115))
	text_size_130_btn.pressed.connect(_on_text_size_pressed.bind(130))
	close_btn.pressed.connect(_on_close_pressed)
	refresh_from_settings()


func open_modal() -> void:
	_apply_safe_layout()
	refresh_from_settings()
	visible = true


func _apply_safe_layout() -> void:
	var m := UiThemeBuilder.get_safe_margins(self)
	var top_pad := int(m["top"])
	var bot_pad := int(m["bottom"])
	var left_pad := int(m["left"])
	var right_pad := int(m["right"])
	safe_wrap.add_theme_constant_override("margin_top", top_pad + 18)
	safe_wrap.add_theme_constant_override("margin_bottom", bot_pad + 18)
	safe_wrap.add_theme_constant_override("margin_left", left_pad + 18)
	safe_wrap.add_theme_constant_override("margin_right", right_pad + 18)

	var vp_w := size.x if size.x > 0.0 else 720.0
	var vp_h := size.y if size.y > 0.0 else 1280.0
	card.custom_minimum_size.x = minf(620.0, maxf(300.0, vp_w - float(left_pad + right_pad) - 36.0))
	var max_scroll_h := maxf(280.0, vp_h - float(top_pad + bot_pad) - 260.0)
	body_scroll.custom_minimum_size.y = minf(660.0, max_scroll_h)


func _style_controls() -> void:
	UiThemeBuilder.style_label(title_lbl, UiThemeBuilder.font_title(), 25, UiThemeBuilder.TEXT_GOLD, 2)
	UiThemeBuilder.style_label(music_lbl, UiThemeBuilder.font_bold(), 17, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(music_val_lbl, UiThemeBuilder.font_bold(), 17, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(sfx_lbl, UiThemeBuilder.font_bold(), 17, UiThemeBuilder.TEXT_PARCHMENT, 1)
	UiThemeBuilder.style_label(sfx_val_lbl, UiThemeBuilder.font_bold(), 17, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_label(text_size_lbl, UiThemeBuilder.font_title(), 15, UiThemeBuilder.TEXT_GOLD, 1)
	UiThemeBuilder.style_slider(music_slider)
	UiThemeBuilder.style_slider(sfx_slider)

	var toggle_px := UiThemeBuilder.scaled_font_px(18, 1.20)
	for cb in [music_toggle, sfx_toggle, haptics_toggle, shake_toggle, reduce_flash_toggle, numbers_toggle, lefty_toggle]:
		cb.add_theme_font_override("font", UiThemeBuilder.font_bold())
		cb.add_theme_font_size_override("font_size", toggle_px)

	UiThemeBuilder.style_cta_button(close_btn, 20)


func refresh_from_settings() -> void:
	_syncing = true
	var st := _read_settings()
	music_toggle.button_pressed = bool(st.get("music_on", true))
	var mvol := clampf(float(st.get("music_vol", 0.8)), 0.0, 1.0)
	music_slider.value = mvol
	music_val_lbl.text = "%d%%" % roundi(mvol * 100.0)

	sfx_toggle.button_pressed = bool(st.get("sfx_on", true))
	var svol := clampf(float(st.get("sfx_vol", 0.9)), 0.0, 1.0)
	sfx_slider.value = svol
	sfx_val_lbl.text = "%d%%" % roundi(svol * 100.0)

	haptics_toggle.button_pressed = bool(st.get("haptics_on", true))
	shake_toggle.button_pressed = float(st.get("screen_shake", 1.0)) > 0.05
	reduce_flash_toggle.button_pressed = bool(st.get("reduce_flashing", false))
	numbers_toggle.button_pressed = bool(st.get("damage_numbers", true))
	lefty_toggle.button_pressed = bool(st.get("left_handed", false))

	var tsize := int(st.get("text_size", 100))
	tsize = 100 if tsize < 108 else (115 if tsize < 123 else 130)
	_style_controls()
	for sz in _text_size_btns:
		UiThemeBuilder.style_pill_button(_text_size_btns[sz] as Button, int(sz) == tsize, 16)
	_syncing = false


func _on_music_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("music_on", on)


func _on_music_vol_changed(val: float) -> void:
	music_val_lbl.text = "%d%%" % roundi(val * 100.0)
	if _syncing:
		return
	_write_setting("music_vol", val)


func _on_sfx_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("sfx_on", on)


func _on_sfx_vol_changed(val: float) -> void:
	sfx_val_lbl.text = "%d%%" % roundi(val * 100.0)
	if _syncing:
		return
	_write_setting("sfx_vol", val)


func _on_haptics_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("haptics_on", on)
	if on:
		var ad := _audio()
		if ad != null and ad.has_method("haptic"):
			ad.call("haptic", "light")


func _on_shake_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("screen_shake", 1.0 if on else 0.0)


func _on_reduce_flash_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("reduce_flashing", on)


func _on_numbers_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("damage_numbers", on)


func _on_lefty_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("left_handed", on)


func _on_text_size_pressed(px_pct: int) -> void:
	if _syncing:
		return
	_write_setting("text_size", px_pct)
	refresh_from_settings()


func _on_close_pressed() -> void:
	var ad := _audio()
	if ad != null:
		ad.call("sfx", "ui_back")
	visible = false
	closed.emit()


func _read_settings() -> Dictionary:
	var gs := _game_state()
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		return gs.settings as Dictionary
	var ad := _audio()
	if ad != null and "settings" in ad and ad.settings is Dictionary:
		return ad.settings as Dictionary
	return {}


func _write_setting(key: String, val: Variant) -> void:
	var ad := _audio()
	if ad != null and ad.has_method("set_setting"):
		ad.call("set_setting", key, val)
		ad.call("sfx", "ui_toggle")
	else:
		var gs := _game_state()
		if gs != null and "settings" in gs and gs.settings is Dictionary:
			gs.settings[key] = val
			if gs.has_method("save_profile"):
				gs.call("save_profile")
	settings_updated.emit()


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")
