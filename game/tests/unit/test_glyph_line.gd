extends TestCase
## HUD 操作提示的手把圖示（GlyphLine，D-063）：翻譯字串裡的 {key} 在鍵鼠模式是「[F]」文字、手把模式換成 PadGlyph；
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


func test_kbm_text_and_pad_glyph() -> void:
	var line: GlyphLine = _line()
	line.set_line(tr("RB_CRATE_HINT"), "interact", InputGlyphs.Device.KBM)
	assert_eq(line.plain_text(), "按 [F]　拿走藥瓶")
	assert_false(line.uses_glyph(), "鍵鼠用文字")
	assert_eq(line.visible_glyphs().size(), 0)
	assert_eq(line.parts(), PackedStringArray(["按 [F]　拿走藥瓶"]))
	line.set_line(tr("RB_CRATE_HINT"), "interact", InputGlyphs.Device.PAD)
	assert_eq(line.plain_text(), "按 [A]　拿走藥瓶", "文字版照樣有鍵名（測試與讀屏）")
	assert_true(line.uses_glyph(), "手把用圖示")
	var glyphs: Array[PadGlyph] = line.visible_glyphs()
	assert_eq(glyphs.size(), 1)
	assert_eq(glyphs[0].spec, Vector2i(2, JOY_BUTTON_A))
	assert_eq(PadGlyph.shape_of(glyphs[0].spec), PadGlyph.Shape.FACE)
	assert_eq(glyphs[0].letter(), "A")
	assert_eq(line.parts(), PackedStringArray(["按", "　拿走藥瓶"]), "圖示兩側的字")
	for p: String in line.parts():
		assert_false(p.contains("{key}") or p.contains("["), "字段裡沒有鍵名或佔位符：" + p)
	await tree.process_frame
	assert_true(line.size.x > 100.0 and line.size.y >= glyphs[0].glyph_h, "大小照內容：%s" % line.size)
	assert_true(glyphs[0].position.x > 0.0, "圖示在「按」後面")
	line.set_line(tr("RB_CRATE_HINT"), "interact", InputGlyphs.Device.KBM)
	assert_false(line.uses_glyph(), "切回鍵鼠")
	assert_eq(line.visible_glyphs().size(), 0)
	assert_eq(line.parts(), PackedStringArray(["按 [F]　拿走藥瓶"]))
	line.free()


func test_two_keys_and_unbound_fallback() -> void:
	var line: GlyphLine = _line()
	line.set_line(tr("HUD_DLG_HINT"), "interact", InputGlyphs.Device.PAD)
	assert_eq(line.visible_glyphs().size(), 2, "「{key} 繼續・按住 {key} 跳過」兩個圖示")
	assert_eq(line.parts(), PackedStringArray(["繼續・按住", "跳過"]))
	assert_eq(line.plain_text(), "[A] 繼續・按住 [A] 跳過")
	# 改了別的字串：圖示減少時多的藏起來
	line.set_line(tr("RB_CRATE_HINT"), "interact", InputGlyphs.Device.PAD)
	assert_eq(line.visible_glyphs().size(), 1)
	# 沒有手把綁定的動作：退回文字
	line.set_line("{key} ?", "no_such_action", InputGlyphs.Device.PAD)
	assert_false(line.uses_glyph(), "沒有綁定就用文字")
	assert_eq(line.visible_glyphs().size(), 0)
	# 沒有 {key} 的字串：整句一段
	line.set_line("只有字", "interact", InputGlyphs.Device.PAD)
	assert_false(line.uses_glyph())
	assert_eq(line.parts(), PackedStringArray(["只有字"]))
	line.free()


func test_combat_hud_commands() -> void:
	var hud := CombatHud.new()
	tree.root.add_child(hud)
	App.set_device(InputGlyphs.Device.KBM)
	hud.refresh(null, null)
	assert_true(hud.command_label(0).begins_with("[Q]"), hud.command_label(0))
	assert_false(hud.command_line(0).uses_glyph())
	App.set_device(InputGlyphs.Device.PAD)
	hud.refresh(null, null)
	for i: int in CombatHud.COMMANDS.size():
		var line: GlyphLine = hud.command_line(i)
		assert_true(line.uses_glyph(), "手把：第 %d 個指令有圖示" % i)
		assert_eq(line.parts(), PackedStringArray([tr(str(CombatHud.COMMANDS[i][2]))]), "圖示後面只有指令名")
	assert_eq(PadGlyph.shape_of(hud.command_line(0).visible_glyphs()[0].spec), PadGlyph.Shape.DPAD, "打弱點＝十字鍵上")
	assert_true(hud.command_label(0).contains("打弱點"), "文字版還在：" + hud.command_label(0))
	App.set_device(InputGlyphs.Device.KBM)
	hud.refresh(null, null)
	assert_false(hud.command_line(0).uses_glyph(), "切回鍵鼠變回文字")
	assert_true(hud.command_label(0).begins_with("[Q]"))
	hud.free()


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


## 互動提示（InteractPrompt，D-065）：讀 interact_prompts 群組的 interact_hint()，下方中央、按住進度條、手把圖示。
func test_interact_prompt_reads_sources() -> void:
	var src_script := GDScript.new()
	src_script.source_code = "extends Node\nvar hint: Dictionary = {}\nfunc interact_hint() -> Dictionary:\n\treturn hint\n"
	src_script.reload()
	var src := Node.new()
	src.set_script(src_script)
	src.add_to_group("interact_prompts")
	tree.root.add_child(src)
	var layer := CanvasLayer.new()
	tree.root.add_child(layer)
	var prompt := InteractPrompt.new()
	layer.add_child(prompt)
	App.set_device(InputGlyphs.Device.KBM)
	prompt.refresh(0.0)
	assert_false(prompt.is_shown(), "沒有來源要顯示")
	assert_false(prompt.visible)
	src.set("hint", {"fmt": tr("RB_CRATE_HINT"), "action": "interact", "progress": 0.5})
	prompt.refresh(0.0)
	assert_true(prompt.is_shown())
	assert_eq(prompt.text(), "按 [F]　拿走藥瓶")
	assert_true(absf(prompt.progress - 0.5) < 0.001, "按住進度")
	var r: Rect2 = prompt.panel_rect()
	assert_true(r.position.y > prompt.size.y * 0.6, "在畫面下方：%s／%s" % [r, prompt.size])
	assert_true(absf(r.get_center().x - prompt.size.x * 0.5) < 2.0, "水平置中")
	App.set_device(InputGlyphs.Device.PAD)
	prompt.refresh(0.0)
	assert_true(prompt.line().uses_glyph(), "手把：A 圖示")
	assert_eq(prompt.line().parts(), PackedStringArray(["按", "　拿走藥瓶"]))
	src.set("hint", {})
	prompt.refresh(0.0)
	assert_false(prompt.is_shown(), "來源收起來就消失")
	assert_eq(prompt.text(), "")
	src.free()
	layer.free()
