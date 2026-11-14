class_name PadGlyph
extends Control
## 手把按鈕圖示（程序畫）：按鍵設定頁的手把格用它取代純文字 A／B／LB。
## - A／B／X／Y：實心圓＋字母，四色（柔和的綠、紅、藍、黃，配合冬夜色調，不是刺眼的原色）
## - LB／RB：圓角長條；LT／RT：上圓下方的扳機形
## - 搖桿：外圈＋L／R；按下搖桿（L3／R3）多一個實心內圈
## - 十字鍵：十字形，該方向那一臂亮起
## - View／Menu：小圓角矩形＋字
## 不是手把的綁定（鍵盤、滑鼠）不畫（shape_of 回傳 NONE），格子照常顯示文字。
## 字從 InputGlyphs.label_for_spec 來（同一套翻譯 key），所以換語言、改鍵都跟著變。
## 字用子節點 Label 顯示（在遊戲裡直接 draw_string 這套子集字型會畫成缺字方塊，Label 正常）。

enum Shape { NONE, FACE, BUMPER, TRIGGER, STICK, STICK_PRESS, DPAD, SMALL }

const FACE_COLORS: Dictionary = {
	JOY_BUTTON_A: Color(0.36, 0.62, 0.36),
	JOY_BUTTON_B: Color(0.74, 0.32, 0.3),
	JOY_BUTTON_X: Color(0.3, 0.48, 0.78),
	JOY_BUTTON_Y: Color(0.82, 0.66, 0.26),
}
const BODY: Color = Color(0.2, 0.22, 0.26)
## 十字鍵本體比一般按鈕亮一點（深底上才看得出十字形）
const DPAD_BODY: Color = Color(0.4, 0.43, 0.48)
const RIM: Color = Color(0.62, 0.66, 0.72)
const INK: Color = Color(0.96, 0.96, 0.95)
const LIT: Color = Color(0.98, 0.86, 0.6)
const DIRS: Dictionary = {
	JOY_BUTTON_DPAD_UP: Vector2(0, -1),
	JOY_BUTTON_DPAD_DOWN: Vector2(0, 1),
	JOY_BUTTON_DPAD_LEFT: Vector2(-1, 0),
	JOY_BUTTON_DPAD_RIGHT: Vector2(1, 0),
}

var spec: Vector2i = InputSetup.NONE:
	set(v):
		spec = v
		_update_size()
		_update_label()
		queue_redraw()
## 固定（不能改）的格子：整個圖示變暗
var dim: bool = false:
	set(v):
		dim = v
		_update_label()
		queue_redraw()
## 圖示高度（px）
var glyph_h: float = 32.0


var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_size()
	_update_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_label()


## 圖示上的字（測試用）；十字鍵沒有字。
func letter() -> String:
	return _label.text if _label != null and _label.visible else ""


func _update_label() -> void:
	if _label == null:
		_label = Label.new()
		_label.name = "Letter"
		# 印在按鈕上的字（不是翻譯 key），跟按鍵設定頁的鍵名格一樣標記
		_label.set_meta("glyph", true)
		_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var f: Font = UiFonts.load_font(UiFonts.UI_SANS_MEDIUM)
		if f != null:
			_label.add_theme_font_override("font", f)
		add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	var shape: int = shape_of(spec)
	var t: String = ""
	var fs: int = _font_size()
	var dy: float = 0.0
	match shape:
		Shape.FACE:
			t = _text()
			fs += 1
		Shape.BUMPER:
			t = _text()
			fs = int(fs * 0.9)
		Shape.TRIGGER:
			t = _text()
			fs = int(fs * 0.9)
			dy = glyph_h * 0.06
		Shape.STICK, Shape.STICK_PRESS:
			var left: bool = spec.y in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] if spec.x == 3 else spec.y == JOY_BUTTON_LEFT_STICK
			t = "L" if left else "R"
		Shape.SMALL:
			t = _text()
			fs = int(fs * 0.8)
	_label.visible = t != ""
	_label.text = t
	_label.add_theme_font_size_override("font_size", maxi(fs, 8))
	_label.add_theme_color_override("font_color", _shade(INK))
	_label.position = Vector2(0, dy)
	_label.size = Vector2(glyph_width(), glyph_h)


static func shape_of(s: Vector2i) -> int:
	if s.x == 2:
		if FACE_COLORS.has(s.y):
			return Shape.FACE
		if s.y == JOY_BUTTON_LEFT_SHOULDER or s.y == JOY_BUTTON_RIGHT_SHOULDER:
			return Shape.BUMPER
		if s.y == JOY_BUTTON_LEFT_STICK or s.y == JOY_BUTTON_RIGHT_STICK:
			return Shape.STICK_PRESS
		if DIRS.has(s.y):
			return Shape.DPAD
		if s.y == JOY_BUTTON_BACK or s.y == JOY_BUTTON_START:
			return Shape.SMALL
	elif s.x == 3:
		if s.y == JOY_AXIS_TRIGGER_LEFT or s.y == JOY_AXIS_TRIGGER_RIGHT:
			return Shape.TRIGGER
		return Shape.STICK
	return Shape.NONE


static func face_color(button: int) -> Color:
	return FACE_COLORS.get(button, BODY) as Color


func has_shape() -> bool:
	return shape_of(spec) != Shape.NONE


## 圖示寬度（依形狀與字）
func glyph_width() -> float:
	var h: float = glyph_h
	match shape_of(spec):
		Shape.FACE, Shape.STICK, Shape.STICK_PRESS, Shape.DPAD:
			return h
		Shape.BUMPER, Shape.TRIGGER:
			return h * 1.6
		Shape.SMALL:
			return maxf(h * 1.4, _text_w(_text(), _font_size()) + h * 0.6)
	return 0.0


func _update_size() -> void:
	custom_minimum_size = Vector2(glyph_width(), glyph_h)
	size = custom_minimum_size


func _font() -> Font:
	var f: Font = UiFonts.load_font(UiFonts.UI_SANS_MEDIUM)
	return f if f != null else get_theme_default_font()


func _font_size() -> int:
	return int(glyph_h * 0.56)


func _text() -> String:
	return InputGlyphs.label_for_spec(spec)


func _text_w(t: String, fs: int) -> float:
	return _font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _shade(c: Color) -> Color:
	return c.darkened(0.45) if dim else c


func _draw_round_rect(r: Rect2, radius: float, c: Color, filled: bool = true, width: float = 1.5) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if filled:
		sb.bg_color = _shade(c)
	else:
		sb.draw_center = false
		sb.set_border_width_all(int(width))
		sb.border_color = _shade(c)
	draw_style_box(sb, r)


func _draw() -> void:
	var h: float = glyph_h
	var w: float = glyph_width()
	var mid := Vector2(w * 0.5, h * 0.5)
	match shape_of(spec):
		Shape.FACE:
			draw_circle(mid, h * 0.5, _shade(face_color(spec.y)), true, -1.0, true)
			draw_circle(mid, h * 0.5 - 1.0, _shade(Color(1, 1, 1, 0.25)), false, 1.5, true)
		Shape.BUMPER:
			_draw_round_rect(Rect2(0, h * 0.2, w, h * 0.62), h * 0.3, BODY)
			_draw_round_rect(Rect2(0, h * 0.2, w, h * 0.62), h * 0.3, RIM, false)
		Shape.TRIGGER:
			var sb := StyleBoxFlat.new()
			sb.bg_color = _shade(BODY)
			sb.border_color = _shade(RIM)
			sb.set_border_width_all(2)
			sb.corner_radius_top_left = int(h * 0.45)
			sb.corner_radius_top_right = int(h * 0.45)
			sb.corner_radius_bottom_left = 3
			sb.corner_radius_bottom_right = 3
			sb.corner_detail = 6
			sb.anti_aliasing = true
			draw_style_box(sb, Rect2(w * 0.1, 0, w * 0.8, h))
		Shape.STICK, Shape.STICK_PRESS:
			draw_circle(mid, h * 0.5, _shade(BODY), true, -1.0, true)
			draw_circle(mid, h * 0.5 - 1.0, _shade(RIM), false, 2.0, true)
			if shape_of(spec) == Shape.STICK_PRESS:
				draw_circle(mid, h * 0.3, _shade(RIM.darkened(0.35)), true, -1.0, true)
		Shape.DPAD:
			var arm: float = h * 0.34
			var t: float = h * 0.32
			var lit_dir: Vector2 = DIRS.get(spec.y, Vector2.ZERO) as Vector2
			draw_rect(Rect2(mid.x - t * 0.5, 0, t, h), _shade(DPAD_BODY))
			draw_rect(Rect2(0, mid.y - t * 0.5, w, t), _shade(DPAD_BODY))
			var lc: Vector2 = mid + lit_dir * (arm + t * 0.5) * 0.62
			var lit_size := Vector2(t, arm) if lit_dir.x == 0.0 else Vector2(arm, t)
			draw_rect(Rect2(lc - lit_size * 0.5, lit_size), _shade(LIT))
		Shape.SMALL:
			_draw_round_rect(Rect2(0, h * 0.18, w, h * 0.64), 5.0, BODY)
			_draw_round_rect(Rect2(0, h * 0.18, w, h * 0.64), 5.0, RIM, false)
