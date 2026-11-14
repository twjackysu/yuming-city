extends TestCase
## HUD 操作提示的手把圖示（GlyphLine）：翻譯字串裡的 {key} 在鍵鼠模式是「[F]」文字、手把模式換成 PadGlyph；
## 戰鬥 HUD 三個指令、掙扎提示、互動提示、對話框的提示列切到手把都有圖示、切回鍵鼠變回文字，plain_text 永遠是文字版。

var _locale: String = ""
var _device: int = 0


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")
	_device = App.last_device


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	App.set_device(_device)


func _line() -> GlyphLine:
	var line: GlyphLine = GlyphLine.new().configure(20, Color.WHITE)
	tree.root.add_child(line)
	return line


func test_dialogue_hint_follows_device() -> void:
	App.set_device(InputGlyphs.Device.KBM)
	var box := DialogueBox.new()
	tree.root.add_child(box)
	assert_false(box.hint_line().uses_glyph())
	assert_true(box.hint_text().contains("[F]"))
	App.set_device(InputGlyphs.Device.PAD)
	assert_true(box.hint_line().uses_glyph(), "對話框提示切到手把有圖示（聽 device_changed）")
	assert_eq(box.hint_line().visible_glyphs().size(), 2)
	assert_true(box.hint_text().contains("[A]"), box.hint_text())
	App.set_device(InputGlyphs.Device.KBM)
	assert_false(box.hint_line().uses_glyph())
	box.free()


## 互動提示（InteractPrompt）：讀 interact_prompts 群組的 interact_hint()，下方中央、按住進度條、手把圖示。
