class_name SettingsModal
extends ColorRect

signal closed()
signal settings_updated()

@onready var card: PanelContainer = $Center/Card
@onready var title_lbl: Label = $Center/Card/VBox/TitleLbl
@onready var music_toggle: CheckButton = $Center/Card/VBox/MusicRow/MusicToggle
@onready var music_slider: HSlider = $Center/Card/VBox/MusicSliderRow/MusicSlider
@onready var music_val_lbl: Label = $Center/Card/VBox/MusicSliderRow/MusicValLbl
@onready var sfx_toggle: CheckButton = $Center/Card/VBox/SfxRow/SfxToggle
@onready var sfx_slider: HSlider = $Center/Card/VBox/SfxSliderRow/SfxSlider
@onready var sfx_val_lbl: Label = $Center/Card/VBox/SfxSliderRow/SfxValLbl
@onready var shake_toggle: CheckButton = $Center/Card/VBox/ShakeToggle
@onready var numbers_toggle: CheckButton = $Center/Card/VBox/NumbersToggle
@onready var lefty_toggle: CheckButton = $Center/Card/VBox/LeftyToggle
@onready var close_btn: Button = $Center/Card/VBox/CloseBtn

var _syncing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	card.add_theme_stylebox_override("panel", UiThemeBuilder.make_box(UiThemeBuilder.BG_IRON, UiThemeBuilder.BORDER_GOLD, 2, 6, 20, 18))
	UiThemeBuilder.style_label(title_lbl, UiThemeBuilder.font_title(), 22, UiThemeBuilder.TEXT_GOLD)
	UiThemeBuilder.style_cta_button(close_btn, 16)

	music_toggle.toggled.connect(_on_music_toggled)
	music_slider.value_changed.connect(_on_music_vol_changed)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	sfx_slider.value_changed.connect(_on_sfx_vol_changed)
	shake_toggle.toggled.connect(_on_shake_toggled)
	numbers_toggle.toggled.connect(_on_numbers_toggled)
	lefty_toggle.toggled.connect(_on_lefty_toggled)
	close_btn.pressed.connect(_on_close_pressed)
	refresh_from_settings()


func open_modal() -> void:
	refresh_from_settings()
	visible = true


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

	shake_toggle.button_pressed = float(st.get("screen_shake", 1.0)) > 0.05
	numbers_toggle.button_pressed = bool(st.get("damage_numbers", true))
	lefty_toggle.button_pressed = bool(st.get("left_handed", false))
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


func _on_shake_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("screen_shake", 1.0 if on else 0.0)


func _on_numbers_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("damage_numbers", on)


func _on_lefty_toggled(on: bool) -> void:
	if _syncing:
		return
	_write_setting("left_handed", on)


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
