extends Node

signal update_ready(build: int)

const BOOT_VERSION := 2
# CI stamps NATIVE_VERSION into version.json as min_engine.
const NATIVE_VERSION := 1
const DEFAULT_URL := "https://github.com/Rico-Rodriguez/ashen-oath/releases/download/ota/version.json"
const DIR := "user://ota"
const MANIFEST := "user://ota/manifest.json"
const FLAG := "user://ota/booting.flag"
const CHECK_TIMEOUT := 3.0
const DOWNLOAD_TIMEOUT := 1800.0
const SETTLE := 4.0

var enabled := false
var baked_build := 0
var baked_sha := ""
var ota_build := 0
var build := 0
var just_updated := false
var rolled_back := 0
var pending_build := 0
var blocking := false
var status := "off"

var _m: Dictionary = {}
var _url := DEFAULT_URL
var _remote: Dictionary = {}
var _http: HTTPRequest
var _hasher: Thread
var _ui: CanvasLayer
var _bar: ProgressBar
var _step: Label
var _downloading := false


func _init() -> void:
	baked_build = int(ProjectSettings.get_setting("ota/build", 0))
	baked_sha = str(ProjectSettings.get_setting("ota/sha", ""))
	build = baked_build
	var test := OS.get_environment("AO_OTA_TEST") == "1"
	enabled = (OS.has_feature("template") and OS.get_name() == "iOS") or test
	if OS.get_cmdline_user_args().has("--no-ota"):
		enabled = false
	if OS.get_environment("AO_OTA_URL") != "":
		_url = OS.get_environment("AO_OTA_URL")
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	_m = _read_json(MANIFEST)
	for key in ["current", "previous"]:
		if not (_m.get(key) is Dictionary):
			_m[key] = {}
	if not (_m.get("bad") is Array):
		_m["bad"] = []
	# JSON numbers parse as floats; coerce to int so `in` matches build ids.
	_m["bad"] = _m["bad"].map(func(x: Variant) -> int: return int(x))
	if FileAccess.file_exists(FLAG):
		var crashed := int(_read_text(FLAG).strip_edges())
		DirAccess.remove_absolute(FLAG)
		if crashed > 0 and int(_m["current"].get("build", 0)) == crashed:
			rolled_back = crashed
			_discard("current")
			_m["current"] = _m["previous"]
			_m["previous"] = {}
	for key in ["previous", "current"]:
		if not _usable(_m[key]):
			_discard(key)
	if _m["current"].is_empty() and not _m["previous"].is_empty():
		_m["current"] = _m["previous"]
		_m["previous"] = {}
	_mount()
	_save_manifest()


func _mount() -> void:
	for _attempt in 2:
		var entry: Dictionary = _m["current"]
		if entry.is_empty():
			return
		var path := DIR + "/" + str(entry.get("file", ""))
		var ok := FileAccess.file_exists(path) and _file_size(path) == int(entry.get("size", -1))
		if ok:
			_write_text(FLAG, str(entry["build"]))
			ok = ProjectSettings.load_resource_pack(path, true)
		if ok:
			ota_build = int(entry["build"])
			build = ota_build
			if int(_m.get("last_shown", 0)) != ota_build:
				just_updated = true
				_m["last_shown"] = ota_build
			status = "mounted"
			return
		DirAccess.remove_absolute(FLAG)
		_discard("current")
		_m["current"] = _m["previous"]
		_m["previous"] = {}


func _ready() -> void:
	if not enabled:
		return
	# Keep download and overlay responsive while SceneTree is paused during boot update.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	await _boot_update()
	if ota_build > 0:
		get_tree().create_timer(SETTLE).timeout.connect(_settled)


func _exit_tree() -> void:
	if _hasher != null and _hasher.is_started():
		_hasher.wait_to_finish()
		_hasher = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if ota_build > 0:
			_settled()


func _settled() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(FLAG)


func _process(_delta: float) -> void:
	if _step != null:
		_step.text = status
	if _downloading and _bar != null and _http != null:
		_bar.value = minf(float(_http.get_downloaded_bytes()), _bar.max_value)


func _boot_update() -> void:
	if not enabled or _http == null:
		return
	if not await _check():
		return
	var target := int(_remote["build"])
	_open_ui(target)
	get_tree().paused = true
	status = "applying %d" % target
	var failure: String = await _fetch_pack()
	get_tree().paused = false
	_close_ui()
	if failure != "":
		status = failure
		_restage()
		return
	_mount()
	_save_manifest()


func _check() -> bool:
	_http.timeout = CHECK_TIMEOUT
	_http.download_file = ""
	status = "checking"
	if _http.request(_url) != OK:
		status = "offline"
		return false
	var res: Array = await _http.request_completed
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		status = "offline"
		return false
	var v: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (v is Dictionary):
		status = "bad version.json"
		return false
	_remote = v
	var why := accepts(_remote)
	if why != "":
		status = why
		return false
	return true


func accepts(r: Dictionary) -> String:
	for key in ["build", "pck_url", "sha256", "size", "min_engine"]:
		if not r.has(key):
			return "missing " + key
	var b := int(r["build"])
	if b <= baked_build or b <= ota_build or b <= int(_m["current"].get("build", 0)):
		return "up to date"
	if b in _m["bad"]:
		return "build %d was rolled back" % b
	if int(r["min_engine"]) > NATIVE_VERSION:
		return "needs a newer app (shell %d)" % int(r["min_engine"])
	if r.has("godot") and str(r["godot"]) != _engine():
		return "built for Godot " + str(r["godot"])
	if r.has("platform") and str(r["platform"]) != OS.get_name().to_lower() and OS.get_environment("AO_OTA_TEST") != "1":
		return "built for " + str(r["platform"])
	return ""


func _fetch_pack() -> String:
	var tmp := DIR + "/download.tmp"
	_http.timeout = DOWNLOAD_TIMEOUT
	_http.download_file = tmp
	_downloading = true
	if _http.request(str(_remote["pck_url"])) != OK:
		_downloading = false
		_http.download_file = ""
		status = "download failed"
		return status
	var res: Array = await _http.request_completed
	_downloading = false
	_http.download_file = ""
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200 or _file_size(tmp) != int(_remote["size"]):
		DirAccess.remove_absolute(tmp)
		status = "download failed"
		return status
	status = "verifying"
	# Hash off the main thread so large packs do not stall UI rendering.
	_hasher = Thread.new()
	_hasher.start(_sha256.bind(tmp))
	while _hasher.is_alive():
		await get_tree().process_frame
	var digest: String = _hasher.wait_to_finish()
	_hasher = null
	if digest == "" or digest != str(_remote["sha256"]).to_lower():
		DirAccess.remove_absolute(tmp)
		status = "sha256 mismatch"
		return status
	var b := int(_remote["build"])
	var file := "content_%d.pck" % b
	if DirAccess.rename_absolute(tmp, DIR + "/" + file) != OK:
		DirAccess.remove_absolute(tmp)
		status = "rename failed"
		return status
	var running: Dictionary = _m["current"]
	if not _m["previous"].is_empty() and str(_m["previous"].get("file")) != str(running.get("file")):
		_discard("previous")
	_m["previous"] = running
	_m["current"] = {
		"build": b,
		"file": file,
		"size": int(_remote["size"]),
		"sha256": digest,
		"min_engine": int(_remote["min_engine"]),
		"godot": str(_remote.get("godot", _engine())),
		"sha": str(_remote.get("sha", "")),
	}
	_save_manifest()
	return ""


func _restage() -> void:
	if not await _check():
		return
	if await _fetch_pack() != "":
		return
	pending_build = int(_remote["build"])
	status = "ready %d" % pending_build
	update_ready.emit(pending_build)


func _open_ui(target: int) -> void:
	blocking = true
	_ui = CanvasLayer.new()
	_ui.layer = 100
	add_child(_ui)

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.05, 0.07, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460.0, 0.0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.08, 0.11, 0.98)
	card_sb.border_color = Color(0.83, 0.66, 0.33, 0.85)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(8)
	card_sb.set_content_margin_all(24.0)
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)

	var head := Label.new()
	head.text = "ASHEN OATH — UPDATING"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color(0.92, 0.78, 0.44))
	box.add_child(head)

	var info := Label.new()
	info.text = "Build %d -> %d" % [build, target]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.84, 0.82, 0.78))
	box.add_child(info)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 22.0)
	_bar.max_value = maxf(float(int(_remote.get("size", 1))), 1.0)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.04, 0.04, 0.06, 1.0)
	bg_sb.border_color = Color(0.32, 0.27, 0.18, 0.9)
	bg_sb.set_border_width_all(1)
	bg_sb.set_corner_radius_all(4)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.83, 0.66, 0.33, 1.0)
	fill_sb.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg_sb)
	_bar.add_theme_stylebox_override("fill", fill_sb)
	box.add_child(_bar)

	_step = Label.new()
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step.add_theme_font_size_override("font_size", 14)
	_step.add_theme_color_override("font_color", Color(0.72, 0.70, 0.68))
	box.add_child(_step)


func _close_ui() -> void:
	_downloading = false
	if _ui != null:
		_ui.queue_free()
		_ui = null
	_bar = null
	_step = null
	blocking = false


static func _sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


func _usable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return true
	return int(entry.get("build", 0)) > baked_build \
		and int(entry.get("min_engine", 1 << 30)) <= NATIVE_VERSION \
		and str(entry.get("godot", _engine())) == _engine() \
		and not (int(entry.get("build", 0)) in _m["bad"])


func _discard(key: String) -> void:
	var entry: Dictionary = _m[key]
	if entry.is_empty():
		return
	if rolled_back == int(entry.get("build", 0)) and not (rolled_back in _m["bad"]):
		_m["bad"].append(rolled_back)
	var file := str(entry.get("file", ""))
	if file != "" and file.get_file() == file:
		DirAccess.remove_absolute(DIR + "/" + file)
	_m[key] = {}


func _save_manifest() -> void:
	var tmp := MANIFEST + ".tmp"
	_write_text(tmp, JSON.stringify(_m, "\t"))
	DirAccess.rename_absolute(tmp, MANIFEST)


static func _engine() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return -1 if f == null else int(f.get_length())


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(_read_text(path))
	return v if v is Dictionary else {}


static func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.flush()
