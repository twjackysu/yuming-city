extends TestCase
## 手把按鈕圖示（PadGlyph，D-060）：每種手把綁定對到正確的形狀、ABXY 四色不同、鍵盤滑鼠不畫；
## 按鍵設定頁的手把格顯示圖示（文字透明但還在）、固定格變暗、等新鍵時藏起圖示顯示提示字、改鍵後圖示跟著換。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func test_shapes_and_colors() -> void:
	assert_eq(PadGlyph.shape_of(Vector2i(2, JOY_BUTTON_A)), PadGlyph.Shape.FACE)
	assert_eq(PadGlyph.shape_of(Vector2i(2, JOY_BUTTON_Y)), PadGlyph.Shape.FACE)
	assert_eq(PadGlyph.shape_of(Vector2i(2, JOY_BUTTON_RIGHT_SHOULDER)), PadGlyph.Shape.BUMPER)
	assert_eq(PadGlyph.shape_of(Vector2i(3, JOY_AXIS_TRIGGER_LEFT)), PadGlyph.Shape.TRIGGER)
	assert_eq(PadGlyph.shape_of(Vector2i(3, JOY_AXIS_LEFT_Y)), PadGlyph.Shape.STICK)
	assert_eq(PadGlyph.shape_of(Vector2i(2, JOY_BUTTON_RIGHT_STICK)), PadGlyph.Shape.STICK_PRESS)
	assert_eq(PadGlyph.shape_of(Vector2i(2, JOY_BUTTON_DPAD_UP)), PadGlyph.Shape.DPAD)
	assert_eq(PadGlyph.shape_of(Vector2i(2, JOY_BUTTON_START)), PadGlyph.Shape.SMALL)
	assert_eq(PadGlyph.shape_of(Vector2i(0, KEY_V)), PadGlyph.Shape.NONE, "鍵盤不畫")
	assert_eq(PadGlyph.shape_of(Vector2i(1, MOUSE_BUTTON_LEFT)), PadGlyph.Shape.NONE, "滑鼠不畫")
	assert_eq(PadGlyph.shape_of(InputSetup.NONE), PadGlyph.Shape.NONE)
	var cols: Array[Color] = []
	for b: int in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
		var c: Color = PadGlyph.face_color(b)
		for other: Color in cols:
			assert_true(absf(c.h - other.h) > 0.05, "ABXY 四色色相不同")
		cols.append(c)
	# 每個預設手把綁定都有圖示、寬度合理（格子 250 px 放得下）
	for action: String in InputSetup.BINDINGS:
		var spec: Vector2i = (InputSetup.BINDINGS[action] as Array)[InputSetup.SLOT_PAD]
		var g := PadGlyph.new()
		g.spec = spec
		assert_true(g.has_shape(), "%s 的手把鍵有圖示" % action)
		assert_true(g.glyph_width() > 0.0 and g.glyph_width() < 120.0, "%s 圖示寬度 %.0f" % [action, g.glyph_width()])
		g.free()


func test_controls_menu_pad_cells_show_glyphs() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var real_path: String = str(settings.get("_config_path"))
	settings.call("load_settings", "user://test_pad_glyph_%d.cfg" % Time.get_ticks_usec())
	TranslationServer.set_locale("zh_TW")
	var menu := ControlsMenu.new()
	tree.root.add_child(menu)
	menu.open()
	await tree.process_frame
	var g: PadGlyph = menu.glyph("attack", InputSetup.SLOT_PAD)
	assert_true(g != null and g.visible, "手把格有圖示")
	assert_eq(g.spec, Vector2i(2, JOY_BUTTON_X), "攻擊＝X")
	assert_eq(g.letter(), "X", "圖示上的字")
	var cell: Button = menu.cell("attack", InputSetup.SLOT_PAD)
	assert_eq(cell.text, "X", "文字還在（測試與讀屏用）")
	assert_eq(cell.get_theme_color("font_color").a, 0.0, "有圖示時文字透明")
	assert_true(menu.glyph("attack", InputSetup.SLOT_KBM) == null, "鍵鼠格沒有圖示")
	var fixed: PadGlyph = menu.glyph("move_forward", InputSetup.SLOT_PAD)
	assert_true(fixed.visible and fixed.dim, "固定的移動搖桿：圖示變暗")
	var inside: Rect2 = Rect2(Vector2.ZERO, cell.size)
	assert_true(inside.encloses(Rect2(g.position, g.size)), "圖示在格子裡")
	# 等新鍵：圖示藏起來、提示字看得到
	menu.begin_capture("attack", InputSetup.SLOT_PAD)
	assert_false(g.visible, "等新鍵時藏起圖示")
	assert_true(cell.get_theme_color("font_color").a > 0.5, "等新鍵時提示字看得到")
	await tree.process_frame
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_RIGHT_SHOULDER
	ev.pressed = true
	assert_true(menu.feed_capture(ev), "收到 RB")
	assert_true(g.visible, "改完圖示回來")
	assert_eq(g.spec, Vector2i(2, JOY_BUTTON_RIGHT_SHOULDER), "圖示換成 RB")
	assert_eq(PadGlyph.shape_of(g.spec), PadGlyph.Shape.BUMPER)
	assert_eq(g.letter(), "RB", "圖示上的字跟著換")
	assert_eq(menu.glyph("command_weakpoint", InputSetup.SLOT_PAD).letter(), "", "十字鍵沒有字（亮起的那一臂就是方向）")
	menu.reset_to_defaults()
	assert_eq(g.spec, Vector2i(2, JOY_BUTTON_X), "還原預設：圖示回到 X")
	menu.queue_free()
	await tree.process_frame
	settings.call("load_settings", real_path)
