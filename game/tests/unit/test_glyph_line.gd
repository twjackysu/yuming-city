extends TestCase
## HUD 操作提示的手把圖示（GlyphLine，D-063）：翻譯字串裡的 {key} 在鍵鼠模式是「[V]」文字、手把模式換成 PadGlyph；
## 戰鬥 HUD 三個指令、掙扎提示、重現提示、對話框與過場的提示列切到手把都有圖示、切回鍵鼠變回文字，plain_text 永遠是文字版。

var _locale: String = ""
var _device: int = 0


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")
	_device = App.last_device


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	App.set_device(_device)
	Input.action_release("nine_breath")


func _line() -> GlyphLine:
	var line: GlyphLine = GlyphLine.new().configure(20, Color.WHITE)
	tree.root.add_child(line)
	return line


func test_kbm_text_and_pad_glyph() -> void:
	var line: GlyphLine = _line()
	line.set_line(tr("NB_HOLD_HINT"), "nine_breath", InputGlyphs.Device.KBM)
	assert_eq(line.plain_text(), "按住 [V]　重現 9 秒")
	assert_false(line.uses_glyph(), "鍵鼠用文字")
	assert_eq(line.visible_glyphs().size(), 0)
	assert_eq(line.parts(), PackedStringArray(["按住 [V]　重現 9 秒"]))
	line.set_line(tr("NB_HOLD_HINT"), "nine_breath", InputGlyphs.Device.PAD)
	assert_eq(line.plain_text(), "按住 [Y]　重現 9 秒", "文字版照樣有鍵名（測試與讀屏）")
	assert_true(line.uses_glyph(), "手把用圖示")
	var glyphs: Array[PadGlyph] = line.visible_glyphs()
	assert_eq(glyphs.size(), 1)
	assert_eq(glyphs[0].spec, Vector2i(2, JOY_BUTTON_Y))
	assert_eq(PadGlyph.shape_of(glyphs[0].spec), PadGlyph.Shape.FACE)
	assert_eq(glyphs[0].letter(), "Y")
	assert_eq(line.parts(), PackedStringArray(["按住", "　重現 9 秒"]), "圖示兩側的字")
	for p: String in line.parts():
		assert_false(p.contains("{key}") or p.contains("["), "字段裡沒有鍵名或佔位符：" + p)
	await tree.process_frame
	assert_true(line.size.x > 100.0 and line.size.y >= glyphs[0].glyph_h, "大小照內容：%s" % line.size)
	assert_true(glyphs[0].position.x > 0.0, "圖示在「按住」後面")
	line.set_line(tr("NB_HOLD_HINT"), "nine_breath", InputGlyphs.Device.KBM)
	assert_false(line.uses_glyph(), "切回鍵鼠")
	assert_eq(line.visible_glyphs().size(), 0)
	assert_eq(line.parts(), PackedStringArray(["按住 [V]　重現 9 秒"]))
	line.free()


func test_two_keys_and_unbound_fallback() -> void:
	var line: GlyphLine = _line()
	line.set_line(tr("HUD_DLG_HINT"), "interact", InputGlyphs.Device.PAD)
	assert_eq(line.visible_glyphs().size(), 2, "「{key} 繼續・按住 {key} 跳過」兩個圖示")
	assert_eq(line.parts(), PackedStringArray(["繼續・按住", "跳過"]))
	assert_eq(line.plain_text(), "[A] 繼續・按住 [A] 跳過")
	# 改了別的字串：圖示減少時多的藏起來
	line.set_line(tr("NB_HOLD_HINT"), "nine_breath", InputGlyphs.Device.PAD)
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


func test_combat_hud_commands_and_struggle() -> void:
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


func test_struggle_line_uses_glyph() -> void:
	var line: GlyphLine = _line()
	var fmt: String = tr("HUD_STRUGGLE").format({"n": 3})
	assert_true(fmt.contains("{key}"), "只代入次數，{key} 留給 GlyphLine")
	line.set_line(fmt, "dodge", InputGlyphs.Device.PAD)
	assert_eq(line.plain_text(), "連按 [B] 掙脫（3）")
	assert_eq(line.parts(), PackedStringArray(["連按", "掙脫（3）"]))
	line.free()


func test_restore_prompt_hint_glyph() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(40, 1, 40)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.position = Vector3(0, 0, 3)
	root.add_child(player)
	var site := NineBreathSite.new()
	site.state = GameState.new()
	root.add_child(site)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var prompt := RestorePrompt.new()
	layer.add_child(prompt)
	await tree.physics_frame
	await tree.physics_frame
	App.set_device(InputGlyphs.Device.PAD)
	prompt.refresh(0.0)
	assert_eq(prompt.mode, "prompt")
	assert_true(prompt.hint_line().uses_glyph(), "手把：按住後面是 Y 圖示")
	assert_eq(prompt.hint_line().parts()[0], "按住")
	assert_true(prompt.text().contains("[Y]"), "text() 是文字版：" + prompt.text())
	assert_eq(prompt.text().split("\n")[2], site.prompt_lines()[2], "跟場景的文字一致")
	await tree.process_frame
	prompt.refresh(0.0)
	var r: Rect2 = prompt.panel_rect()
	assert_true(absf(r.get_center().x - prompt.size.x * 0.5) < 2.0, "面板還是水平置中")
	App.set_device(InputGlyphs.Device.KBM)
	prompt.refresh(0.0)
	assert_false(prompt.hint_line().uses_glyph(), "切回鍵鼠")
	assert_true(prompt.text().contains("[V]"))
	root.free()


func test_dialogue_and_cutscene_hints_follow_device() -> void:
	App.set_device(InputGlyphs.Device.KBM)
	var box := DialogueBox.new()
	tree.root.add_child(box)
	var view := CutsceneView.new()
	tree.root.add_child(view)
	assert_false(box.hint_line().uses_glyph())
	assert_true(box.hint_text().contains("[F]"))
	App.set_device(InputGlyphs.Device.PAD)
	assert_true(box.hint_line().uses_glyph(), "對話框提示切到手把有圖示（聽 device_changed）")
	assert_eq(box.hint_line().visible_glyphs().size(), 2)
	assert_true(box.hint_text().contains("[A]"), box.hint_text())
	assert_true(view.skip_line().uses_glyph(), "過場「按住 A 跳過」有圖示")
	assert_eq(view.skip_line().parts(), PackedStringArray(["按住", "跳過"]))
	App.set_device(InputGlyphs.Device.KBM)
	assert_false(box.hint_line().uses_glyph())
	assert_false(view.skip_line().uses_glyph())
	assert_true(view.skip_text().contains("[F]"), view.skip_text())
	box.free()
	view.free()
