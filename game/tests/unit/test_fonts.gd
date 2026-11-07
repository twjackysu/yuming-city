extends TestCase
## 產生的字型子集要涵蓋翻譯檔的每一個字（字型不存在時跳過：例如沒跑 gen-assets 的本機）。


func test_generated_fonts_cover_all_strings() -> void:
	var paths: PackedStringArray = [UiFonts.TITLE_SERIF, UiFonts.UI_SANS, UiFonts.UI_SANS_MEDIUM]
	var text: String = FileAccess.get_file_as_string("res://i18n/strings.csv")
	for path: String in paths:
		var font: Font = UiFonts.load_font(path)
		if font == null:
			print("  （略過：%s 尚未產生）" % path)
			continue
		var missing: String = ""
		for i: int in text.length():
			var c: int = text.unicode_at(i)
			if c < 0x20:
				continue
			if not font.has_char(c) and not missing.contains(char(c)):
				missing += char(c)
		assert_eq(missing, "", "%s 缺字" % path.get_file())


func test_theme_builds_without_fonts() -> void:
	var theme: Theme = UiFonts.build_theme()
	assert_not_null(theme)
	assert_eq(theme.default_font_size, 22)
