extends Node

const DEFAULTS := {"music_on": true, "sfx_on": true, "haptics_on": true, "music_vol": 0.8, "sfx_vol": 0.9, "screen_shake": 1.0, "reduce_flashing": false, "damage_numbers": true, "text_size": 100, "left_handed": false}

const EVENTS := {
	"ui_tap": [-8.0, 2, 0.03, 0.04, "UI"],
	"ui_press": [-5.0, 2, 0.04, 0.03, "UI"],
	"ui_back": [-6.0, 1, 0.05, 0.03, "UI"],
	"ui_error": [-6.0, 1, 0.2, 0.0, "UI"],
	"ui_toggle": [-6.0, 1, 0.04, 0.02, "UI"],
	"atk_mage": [-9.0, 3, 0.08, 0.07, "SFX"],
	"atk_archer": [-9.0, 3, 0.06, 0.08, "SFX"],
	"atk_tank": [-7.0, 3, 0.08, 0.06, "SFX"],
	"atk_enemy": [-12.0, 3, 0.07, 0.1, "SFX"],
	"cast": [-13.0, 3, 0.08, 0.06, "SFX"],
	"swing": [-7.0, 3, 0.06, 0.08, "SFX"],
	"blade_scrape": [-10.0, 2, 0.09, 0.08, "SFX"],
	"hit": [-10.0, 4, 0.035, 0.09, "SFX"],
	"impact": [-11.0, 4, 0.04, 0.09, "SFX"],
	"block": [-8.0, 2, 0.06, 0.08, "SFX"],
	"crit": [-6.0, 2, 0.06, 0.05, "SFX"],
	"hero_hurt": [-5.0, 1, 0.25, 0.05, "SFX"],
	"enemy_die": [-8.0, 3, 0.05, 0.1, "SFX"],
	"dodge": [-6.0, 2, 0.08, 0.1, "SFX"],
	"charge": [-13.0, 2, 0.12, 0.08, "SFX"],
	"charge_land": [-8.0, 2, 0.12, 0.05, "SFX"],
	"cleave": [-6.0, 2, 0.1, 0.06, "SFX"],
	"lifesteal": [-12.0, 2, 0.12, 0.08, "SFX"],
	"boom": [-9.0, 3, 0.1, 0.06, "SFX"],
	"enemy_windup": [-12.0, 2, 0.25, 0.12, "SFX"],
	"aggro": [-14.0, 2, 0.25, 0.1, "SFX"],
	"shield_break": [-7.0, 2, 0.12, 0.07, "SFX"],
	"skill_fx": [-11.0, 4, 0.12, 0.1, "SFX"],
	"chain": [-9.0, 2, 0.1, 0.07, "SFX"],
	"frost": [-9.0, 2, 0.12, 0.07, "SFX"],
	"quake": [-8.0, 2, 0.15, 0.06, "SFX"],
	"volley": [-9.0, 2, 0.08, 0.08, "SFX"],
	"blink": [-10.0, 2, 0.08, 0.08, "SFX"],
	"roar": [-9.0, 2, 0.25, 0.08, "SFX"],
	"thunder": [-6.0, 1, 0.4, 0.05, "SFX"],
	"phoenix": [-6.0, 1, 0.5, 0.05, "SFX"],
	"howl": [-8.0, 1, 0.6, 0.05, "SFX"],
	"meteor": [-8.0, 2, 0.2, 0.07, "SFX"],
	"fire_trail": [-18.0, 1, 0.28, 0.12, "SFX"],
	"wolf_bite": [-8.0, 3, 0.06, 0.09, "SFX"],
	"blades": [-8.0, 2, 0.25, 0.07, "SFX"],
	"thorns": [-5.0, 2, 0.2, 0.08, "SFX"],
	"static": [-5.0, 2, 0.2, 0.08, "SFX"],
	"siphon": [-10.0, 2, 0.12, 0.08, "SFX"],
	"mark": [-7.0, 3, 0.08, 0.09, "SFX"],
	"split": [-7.0, 2, 0.08, 0.08, "SFX"],
	"ricochet": [-8.0, 3, 0.06, 0.09, "SFX"],
	"xp_gain": [-14.0, 2, 0.25, 0.02, "SFX"],
	"skill_level": [-9.0, 2, 0.2, 0.04, "SFX"],
	"banner": [-8.0, 1, 0.4, 0.02, "SFX"],
	"buff_end": [-15.0, 1, 0.3, 0.03, "SFX"],
	"boss_roar": [-2.0, 1, 1.0, 0.0, "SFX"],
	"boss_windup": [-5.0, 1, 0.5, 0.03, "SFX"],
	"boss_slam": [-3.0, 2, 0.15, 0.04, "SFX"],
	"boss_hit": [-7.0, 2, 0.06, 0.06, "SFX"],
	"boss_die": [-2.0, 1, 1.0, 0.0, "SFX"],
	"gem": [-11.0, 3, 0.03, 0.0, "SFX"],
	"coin": [-8.0, 2, 0.06, 0.05, "SFX"],
	"gear_drop": [-8.0, 2, 0.1, 0.08, "SFX"],
	"gear_pickup": [-9.0, 2, 0.06, 0.08, "SFX"],
	"goblin_escape": [-11.0, 1, 0.3, 0.06, "SFX"],
	"hunt_start": [-6.0, 1, 0.5, 0.02, "SFX"],
	"levelup": [-3.0, 1, 0.5, 0.0, "SFX"],
	"card_pick": [-4.0, 1, 0.1, 0.03, "UI"],
	"card_flip": [-9.0, 3, 0.04, 0.06, "UI"],
	"gear_equip": [-3.0, 2, 0.05, 0.05, "UI"],
	"gear_unequip": [-10.0, 1, 0.05, 0.05, "UI"],
	"chest_land": [-5.0, 2, 0.1, 0.05, "SFX"],
	"chest_rattle": [-9.0, 2, 0.08, 0.08, "SFX"],
	"chest_open": [-3.0, 1, 0.3, 0.0, "SFX"],
	"chest_ready": [-7.0, 1, 0.5, 0.02, "UI"],
	"sparkle": [-6.0, 1, 0.3, 0.02, "SFX"],
	"rare_chime": [-3.0, 1, 0.5, 0.0, "SFX"],
	"unlock_start": [-5.0, 1, 0.2, 0.02, "UI"],
	"sting_victory": [-4.0, 1, 1.0, 0.0, "Music"],
	"sting_defeat": [-3.0, 1, 1.0, 0.0, "Music"],
	"duel_win": [-4.0, 1, 1.0, 0.0, "Music"],
	"music_stab": [0.0, 1, 0.5, 0.0, "Music"],
}

const MUSIC_DB := -6.0

var settings: Dictionary = DEFAULTS.duplicate()
var _pool: Array[AudioStreamPlayer] = []
var _variants: Dictionary = {}
var _streams: Dictionary = {}
var _last: Dictionary = {}
var _warned: Dictionary = {}
var _decks: Array[AudioStreamPlayer] = []
var _deck := 0
var _track := ""
var _duck := 0.0
var _duck_tw: Tween
var _haptic_t := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buses()
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var d := AudioStreamPlayer.new()
		d.bus = "Music"
		d.volume_db = -80.0
		add_child(d)
		_decks.append(d)
	refresh_variants()
	call_deferred("_load_settings")


func refresh_variants() -> void:
	_variants.clear()
	var dir := DirAccess.open("res://assets/audio/sfx")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var stem := ""
			if fname.ends_with(".ogg.import"):
				stem = fname.trim_suffix(".ogg.import")
			elif fname.ends_with(".ogg"):
				stem = fname.trim_suffix(".ogg")
			if stem != "":
				var sep := stem.rfind("_")
				if sep > 0:
					var ev := stem.substr(0, sep)
					var idx_str := stem.substr(sep + 1)
					if idx_str.is_valid_int():
						var idx := idx_str.to_int()
						if idx > int(_variants.get(ev, 0)):
							_variants[ev] = idx
		fname = dir.get_next()
	dir.list_dir_end()


# Godot 4 leaks OggPacketSequencePlayback at exit unless active streams are cleared.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_clear_active_streams()


func _exit_tree() -> void:
	_clear_active_streams()


func _clear_active_streams() -> void:
	for p in _pool:
		p.stop()
		p.stream = null
	for d in _decks:
		d.stop()
		d.stream = null
	_streams.clear()


func _buses() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 4.0
		comp.attack_us = 3000.0
		comp.release_ms = 140.0
		comp.gain = 2.0
		AudioServer.add_bus_effect(sfx_idx, comp)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.8
		lim.pre_gain_db = 4.0
		AudioServer.add_bus_effect(master, lim)


func _load_settings() -> void:
	settings = DEFAULTS.duplicate()
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and "settings" in gs and gs.settings is Dictionary:
		var saved: Dictionary = gs.settings
		for k in saved:
			settings[k] = saved[k]
	_normalize()
	if gs != null and "settings" in gs:
		gs.settings = settings.duplicate()
	_apply()


func _normalize() -> void:
	for k in DEFAULTS:
		var v: Variant = settings.get(k, DEFAULTS[k])
		match k:
			"music_vol", "sfx_vol", "screen_shake":
				v = clampf(float(v), 0.0, 1.0)
			"text_size":
				var px := float(v)
				v = 100 if px < 107.5 else (115 if px < 122.5 else 130)
			"music_on", "sfx_on", "haptics_on", "reduce_flashing", "damage_numbers", "left_handed":
				match typeof(v):
					TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
						v = bool(v)
					_:
						v = DEFAULTS[k]
		settings[k] = v


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_normalize()
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		if "settings" in gs:
			gs.settings = settings.duplicate()
		if gs.has_method("save_profile"):
			gs.save_profile()
	_apply()


func _apply() -> void:
	var music_idx := AudioServer.get_bus_index("Music")
	var music_on := bool(settings["music_on"])
	AudioServer.set_bus_mute(music_idx, not music_on)
	AudioServer.set_bus_volume_db(music_idx, MUSIC_DB + _lin_db(float(settings["music_vol"])) + _duck)
	if music_on and _track != "" and not _decks[_deck].playing and AudioServer.get_driver_name() != "Dummy":
		_decks[_deck].play()
	for bus_name in ["SFX", "UI"]:
		var i := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_mute(i, not bool(settings["sfx_on"]))
		AudioServer.set_bus_volume_db(i, _lin_db(float(settings["sfx_vol"])))


static func _lin_db(v: float) -> float:
	return linear_to_db(maxf(v, 0.001))


func shake_scale() -> float:
	return clampf(float(settings.get("screen_shake", 1.0)), 0.0, 1.0)


func text_scale() -> float:
	return float(settings.get("text_size", 100)) / 100.0


func sfx(event_name: String, db_offset := 0.0, pitch_scale := 1.0) -> void:
	var spec: Array = EVENTS.get(event_name, [-8.0, 2, 0.05, 0.05, "SFX"])
	var now := Time.get_ticks_msec() / 1000.0
	if _last.has(event_name) and now - float(_last[event_name]) < float(spec[2]):
		return
	var count := int(_variants.get(event_name, 0))
	if count <= 0:
		if not EVENTS.has(event_name) and not _warned.has(event_name):
			_warned[event_name] = true
			push_warning("AudioDirector: no sfx clip for event '%s'" % event_name)
		return
	var mine: Array[AudioStreamPlayer] = []
	for p in _pool:
		if p.playing and p.get_meta("event", "") == event_name:
			mine.append(p)
	var player: AudioStreamPlayer = null
	if mine.size() >= int(spec[1]):
		mine.sort_custom(func(a: AudioStreamPlayer, b: AudioStreamPlayer) -> bool: return a.get_playback_position() > b.get_playback_position())
		player = mine[0]
	else:
		for p in _pool:
			if not p.playing:
				player = p
				break
		if player == null:
			var best := 0.0
			for p in _pool:
				if p.get_playback_position() >= best:
					best = p.get_playback_position()
					player = p
	_last[event_name] = now
	var k := randi() % count + 1
	var path := "res://assets/audio/sfx/%s_%d.ogg" % [event_name, k]
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		stream = load(path)
		_streams[path] = stream
	player.stop()
	player.stream = stream
	player.bus = str(spec[4])
	player.set_meta("event", event_name)
	var jitter := float(spec[3])
	player.pitch_scale = pitch_scale * (1.0 + randf_range(-jitter, jitter))
	player.volume_db = float(spec[0]) + db_offset + randf_range(-1.2, 1.2)
	if AudioServer.get_driver_name() != "Dummy" and bool(settings.get("sfx_on", true)):
		player.play()


func music(track: String, fade := 1.4) -> void:
	if track == _track and _decks[_deck].playing:
		return
	_track = track
	var stream: AudioStream = load("res://assets/audio/music/%s.ogg" % track)
	if stream == null:
		return
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var old := _decks[_deck]
	_deck = 1 - _deck
	var nxt := _decks[_deck]
	nxt.stream = stream
	nxt.volume_db = -40.0
	if AudioServer.get_driver_name() != "Dummy" and bool(settings.get("music_on", true)):
		nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(old.stop)


func sting(win: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_decks[_deck], "volume_db", -60.0, 0.35)
	tw.tween_callback(_decks[_deck].stop)
	_track = ""
	sfx("sting_victory" if win else "sting_defeat")
	get_tree().create_timer(7.5 if win else 3.0).timeout.connect(func() -> void:
		if _track == "":
			music("home", 3.0)
	)


func duck(db := -7.0, hold := 0.6, release := 0.9) -> void:
	if _duck_tw:
		_duck_tw.kill()
	_duck_tw = create_tween()
	_duck_tw.tween_method(_set_duck, _duck, db, 0.08)
	_duck_tw.tween_interval(hold)
	_duck_tw.tween_method(_set_duck, db, 0.0, release)


func _set_duck(v: float) -> void:
	_duck = v
	var music_idx := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_idx, MUSIC_DB + _lin_db(float(settings["music_vol"])) + _duck)


func haptic(kind: Variant) -> void:
	if not bool(settings.get("haptics_on", true)):
		return
	match str(kind):
		"light":
			_buzz(12, 0.35, 45)
		"medium":
			_buzz(20, 0.6, 60)
		"heavy":
			_buzz(34, 1.0, 70)
		"rare":
			_pattern([[30, 1.0], [90, 0], [22, 0.7], [80, 0], [16, 0.45], [70, 0], [40, 1.0]])
		"levelup":
			_pattern([[14, 0.4], [60, 0], [18, 0.65], [60, 0], [30, 1.0]])


func _buzz(ms: int, amp: float, gap_ms: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _haptic_t < gap_ms:
		return
	_haptic_t = now
	Input.vibrate_handheld(ms, amp)


func _pattern(steps: Array) -> void:
	_haptic_t = Time.get_ticks_msec()
	for s in steps:
		if float(s[1]) > 0.0:
			Input.vibrate_handheld(int(s[0]), float(s[1]))
		await get_tree().create_timer(float(s[0]) / 1000.0, true, false, true).timeout
