extends TestCase

const SettingsScript: GDScript = preload("res://autoload/settings.gd")
const AppScript: GDScript = preload("res://autoload/app.gd")


func test_default_locale_from_os() -> void:
	assert_eq(SettingsScript.pick_default_locale("zh_TW"), "zh_TW")
	assert_eq(SettingsScript.pick_default_locale("zh-Hant-TW"), "zh_TW")
	assert_eq(SettingsScript.pick_default_locale("zh_HK"), "zh_TW")
	assert_eq(SettingsScript.pick_default_locale("en_US"), "en")
	assert_eq(SettingsScript.pick_default_locale("ja_JP"), "en", "不支援的語系回到英文")


func test_normalize_locale() -> void:
	assert_eq(SettingsScript.normalize_locale("zh_TW"), "zh_TW")
	assert_eq(SettingsScript.normalize_locale("fr"), "en")


func test_settings_round_trip() -> void:
	var path: String = "user://test_settings_%d.cfg" % Time.get_ticks_usec()
	var a: Node = SettingsScript.new()
	a.set("locale", "zh_TW")
	a.set("master_volume", 0.25)
	a.call("set_volume", "Voice", 0.4)
	a.call("set_quality", QualityPreset.Level.HIGH)
	a.call("set_option", "subtitles", false)
	a.call("set_option", "reduce_camera_shake", true)
	a.call("set_option", "vsync", false)
	a.call("set_difficulty", "hard")
	assert_eq(a.call("save_settings", path), OK, "存設定")
	var b: Node = SettingsScript.new()
	b.call("load_settings", path)
	assert_eq(b.get("locale"), "zh_TW")
	assert_eq(b.get("master_volume"), 0.25)
	assert_eq(float(b.call("volume", "Voice")), 0.4, "語音音量")
	assert_eq(int(b.get("quality")), int(QualityPreset.Level.HIGH), "畫質")
	assert_eq(b.get("subtitles_enabled"), false, "字幕")
	assert_eq(b.get("reduce_camera_shake"), true, "減少鏡頭晃動")
	assert_eq(b.get("vsync"), false, "垂直同步")
	assert_eq(b.get("difficulty"), "hard", "難度")
	a.free()
	b.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_parse_user_args() -> void:
	var args: Dictionary = AppScript.parse_user_args(PackedStringArray(["--screenshot=/tmp/a.png", "--frames=30", "--benchmark", "junk"]))
	assert_eq(args.get("screenshot"), "/tmp/a.png")
	assert_eq(args.get("frames"), "30")
	assert_eq(args.get("benchmark"), true)
	assert_false(args.has("junk"))


func test_audio_buses() -> void:
	SettingsScript.ensure_buses()
	for bus: String in ["Master", "Music", "SFX", "Voice", "UI"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "匯流排 %s" % bus)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("UI")), &"SFX", "UI 音效跟著音效音量")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("Music")), &"Master")


func test_missing_file_uses_defaults() -> void:
	var s: Node = SettingsScript.new()
	s.call("load_settings", "user://does_not_exist_%d.cfg" % Time.get_ticks_usec())
	assert_eq(int(s.get("quality")), int(QualityPreset.DEFAULT_LEVEL), "預設中畫質")
	assert_eq(s.get("subtitles_enabled"), true, "預設開字幕")
	s.free()
