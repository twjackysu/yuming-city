extends Node
## 玩家設定：語言、音量、畫質。存在 user://settings.cfg，與存檔分開。

signal changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "zh_TW"]
const DEFAULT_LOCALE: String = "en"

var locale: String = DEFAULT_LOCALE
var master_volume: float = 1.0
var subtitles_enabled: bool = true

var _config_path: String = SETTINGS_PATH


func _ready() -> void:
	load_settings()
	apply()


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


func set_locale(value: String) -> void:
	locale = normalize_locale(value)
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	TranslationServer.set_locale(locale)
	var bus: int = AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


func load_settings(path: String = _config_path) -> void:
	_config_path = path
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		locale = pick_default_locale(OS.get_locale())
		return
	locale = normalize_locale(str(cfg.get_value("general", "locale", pick_default_locale(OS.get_locale()))))
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	subtitles_enabled = bool(cfg.get_value("general", "subtitles", true))


func save_settings(path: String = _config_path) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", locale)
	cfg.set_value("general", "subtitles", subtitles_enabled)
	cfg.set_value("audio", "master_volume", master_volume)
	return cfg.save(path)
