extends Node
## 玩家設定：難度、語言、音量、字幕、畫質、顯示、鏡頭晃動、按鍵。存在 user://settings.cfg，與存檔分開。
## UI 改值後呼叫 apply()（即時生效），關閉選單時 save_settings()。

signal changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "zh_TW"]
const DEFAULT_LOCALE: String = "en"
## 音訊匯流排：Music／SFX／Voice 接 Master；UI 接 SFX（跟著音效音量）。
const BUSES: PackedStringArray = ["Music", "SFX", "Voice", "UI"]
const BUS_SEND: Dictionary = {"Music": "Master", "SFX": "Master", "Voice": "Master", "UI": "SFX"}
## 有音量滑桿的匯流排（設定檔的 key 為 <bus 小寫>_volume）
const VOLUME_BUSES: PackedStringArray = ["Master", "Music", "SFX", "Voice"]
## 難度（02-gameplay：只調敵人傷害、前兆長度、指令時機窗，不改代價與流程）；數值在 tuning.json 的 difficulty.*
const DIFFICULTIES: PackedStringArray = ["story", "standard", "hard"]
const DIFFICULTY_KEYS: PackedStringArray = ["DIFF_STORY", "DIFF_STANDARD", "DIFF_HARD"]
const DEFAULT_DIFFICULTY: String = "standard"

var locale: String = DEFAULT_LOCALE
var difficulty: String = DEFAULT_DIFFICULTY
## 匯流排名 -> 線性音量 0..1
var volumes: Dictionary = {"Master": 1.0, "Music": 0.8, "SFX": 1.0, "Voice": 1.0}
var subtitles_enabled: bool = true
var quality: QualityPreset.Level = QualityPreset.DEFAULT_LEVEL
var fullscreen: bool = false
var vsync: bool = true
var reduce_camera_shake: bool = false
## 目標指引（HUD 上指向目前目標的小菱形＋距離；02-gameplay「目標指引」）
var objective_marker: bool = true
## 目前的按鍵綁定（格式見 InputSetup）；存檔時只寫跟預設不同的動作到 [input]
var input_bindings: Dictionary = InputSetup.defaults()

## 舊欄位相容（第 1 輪的測試與程式用 master_volume）
var master_volume: float:
	get:
		return float(volumes.get("Master", 1.0))
	set(value):
		volumes["Master"] = clampf(value, 0.0, 1.0)

var _config_path: String = SETTINGS_PATH


func _ready() -> void:
	ensure_buses()
	load_settings()
	# 開發／截圖用：`-- --locale=zh_TW`、`-- --quality=0..2` 暫時覆寫（不寫入設定檔）
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="):
			locale = normalize_locale(arg.substr("--locale=".length()))
		elif arg.begins_with("--difficulty="):
			difficulty = normalize_difficulty(arg.substr("--difficulty=".length()))
		elif arg.begins_with("--quality="):
			quality = QualityPreset.clamp_level(int(arg.substr("--quality=".length())))
	apply()
	# 之後載入的場景（WorldEnvironment 進樹時）自動套用目前畫質
	get_tree().node_added.connect(_on_node_added)


## 建立音訊匯流排（已存在就跳過）。
static func ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	for bus_name: String in BUSES:
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name), StringName(str(BUS_SEND[bus_name])))


## 依 OS 語系選預設語言：繁中（台灣／香港／Hant）用 zh_TW，其餘一律英文（Steam 預設英文）。
static func pick_default_locale(os_locale: String) -> String:
	var l: String = os_locale.replace("-", "_")
	if l.begins_with("zh_TW") or l.begins_with("zh_HK") or l.begins_with("zh_MO") or l.contains("Hant"):
		return "zh_TW"
	return DEFAULT_LOCALE


static func normalize_locale(value: String) -> String:
	if SUPPORTED_LOCALES.has(value):
		return value
	return DEFAULT_LOCALE


static func normalize_difficulty(value: String) -> String:
	return value if DIFFICULTIES.has(value) else DEFAULT_DIFFICULTY


func set_difficulty(value: String) -> void:
	difficulty = normalize_difficulty(value)
	changed.emit()


func set_locale(value: String) -> void:
	locale = normalize_locale(value)
	apply()
	save_settings()
	changed.emit()


func volume(bus_name: String) -> float:
	return float(volumes.get(bus_name, 1.0))


func set_volume(bus_name: String, value: float) -> void:
	volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_audio()
	changed.emit()


func set_quality(value: int) -> void:
	quality = QualityPreset.clamp_level(value)
	_apply_video()
	changed.emit()


func set_option(option: String, value: bool) -> void:
	match option:
		"subtitles":
			subtitles_enabled = value
		"fullscreen":
			fullscreen = value
		"vsync":
			vsync = value
		"reduce_camera_shake":
			reduce_camera_shake = value
		"objective_marker":
			objective_marker = value
		_:
			push_error("Settings: 沒有選項 %s" % option)
			return
	_apply_video()
	changed.emit()


func get_option(option: String) -> bool:
	match option:
		"subtitles":
			return subtitles_enabled
		"fullscreen":
			return fullscreen
		"vsync":
			return vsync
		"reduce_camera_shake":
			return reduce_camera_shake
		"objective_marker":
			return objective_marker
	return false


func apply() -> void:
	TranslationServer.set_locale(locale)
	_apply_audio()
	_apply_video()
	InputSetup.apply_bindings(input_bindings)


## 重新綁定一個動作的一個欄位（衝突時交換）。綁不了回傳 false。
func set_binding(action: String, slot: int, spec: Vector2i) -> bool:
	var next: Dictionary = InputSetup.rebind(input_bindings, action, slot, spec)
	if next == input_bindings:
		return false
	input_bindings = next
	InputSetup.apply_bindings(input_bindings)
	changed.emit()
	return true


func binding(action: String, slot: int) -> Vector2i:
	return InputSetup.slot_of(input_bindings, action, slot)


func reset_bindings() -> void:
	input_bindings = InputSetup.defaults()
	InputSetup.apply_bindings(input_bindings)
	changed.emit()


func _apply_audio() -> void:
	for bus_name: String in VOLUME_BUSES:
		var bus: int = AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			var v: float = volume(bus_name)
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(bus, v <= 0.001)


func _apply_video() -> void:
	if not is_inside_tree():
		return
	QualityPreset.apply_tree(get_tree().root, quality)
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var current: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_full: bool = current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != fullscreen:
		DisplayServer.window_set_mode(want)


func _on_node_added(node: Node) -> void:
	var we: WorldEnvironment = node as WorldEnvironment
	if we != null:
		QualityPreset.apply_environment(we.environment, quality)


func load_settings(path: String = _config_path) -> void:
	_config_path = path
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		locale = pick_default_locale(OS.get_locale())
		input_bindings = InputSetup.defaults()
		return
	locale = normalize_locale(str(cfg.get_value("general", "locale", pick_default_locale(OS.get_locale()))))
	subtitles_enabled = bool(cfg.get_value("general", "subtitles", true))
	difficulty = normalize_difficulty(str(cfg.get_value("gameplay", "difficulty", DEFAULT_DIFFICULTY)))
	reduce_camera_shake = bool(cfg.get_value("general", "reduce_camera_shake", false))
	objective_marker = bool(cfg.get_value("general", "objective_marker", true))
	for bus_name: String in VOLUME_BUSES:
		var key: String = bus_name.to_lower() + "_volume"
		volumes[bus_name] = clampf(float(cfg.get_value("audio", key, volumes.get(bus_name, 1.0))), 0.0, 1.0)
	quality = QualityPreset.clamp_level(int(cfg.get_value("video", "quality", QualityPreset.DEFAULT_LEVEL)))
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	vsync = bool(cfg.get_value("video", "vsync", true))
	var saved: Dictionary = {}
	if cfg.has_section("input"):
		for action: String in cfg.get_section_keys("input"):
			saved[action] = cfg.get_value("input", action, [])
	input_bindings = InputSetup.from_saved(saved)


func save_settings(path: String = _config_path) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", locale)
	cfg.set_value("general", "subtitles", subtitles_enabled)
	cfg.set_value("gameplay", "difficulty", difficulty)
	cfg.set_value("general", "reduce_camera_shake", reduce_camera_shake)
	cfg.set_value("general", "objective_marker", objective_marker)
	for bus_name: String in VOLUME_BUSES:
		cfg.set_value("audio", bus_name.to_lower() + "_volume", volume(bus_name))
	cfg.set_value("video", "quality", int(quality))
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	var diff: Dictionary = InputSetup.diff_from_defaults(input_bindings)
	for action: String in diff:
		cfg.set_value("input", action, diff[action])
	return cfg.save(path)
