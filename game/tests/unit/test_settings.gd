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
	assert_eq(a.call("save_settings", path), OK, "存設定")
	var b: Node = SettingsScript.new()
	b.call("load_settings", path)
	assert_eq(b.get("locale"), "zh_TW")
	assert_eq(b.get("master_volume"), 0.25)
	a.free()
	b.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_parse_user_args() -> void:
	var args: Dictionary = AppScript.parse_user_args(PackedStringArray(["--screenshot=/tmp/a.png", "--frames=30", "--benchmark", "junk"]))
	assert_eq(args.get("screenshot"), "/tmp/a.png")
	assert_eq(args.get("frames"), "30")
	assert_eq(args.get("benchmark"), true)
	assert_false(args.has("junk"))
