extends TestCase
## 手把按鈕圖示（PadGlyph）：每種手把綁定對到正確的形狀、ABXY 四色不同、鍵盤滑鼠不畫；
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
