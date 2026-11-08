class_name UiTheme
extends RefCounted
## 選單的樣子（D-067）：取代 Godot 預設的白色焦點方框。
## - 按鈕（全部是 flat）：焦點＝左側一道暖金色細條＋往右淡出的暖光；文字平常是冷灰白，
##   焦點／滑鼠移上去變暖金色，不能按的變暗
## - 滑桿：細軌道、已填滿的部分暖金色、圓形把手；焦點跟按鈕一樣
## 顏色跟標題字（0.92, 0.86, 0.7）同一個色系。圖都在程式裡畫（不需要素材檔）。

const ACCENT: Color = Color(0.93, 0.76, 0.47)
const TEXT: Color = Color(0.8, 0.82, 0.86)
const TEXT_FOCUS: Color = Color(0.98, 0.9, 0.72)
const TEXT_DISABLED: Color = Color(0.46, 0.48, 0.52, 0.85)
## 焦點左側細條的寬度（px，不隨按鈕寬度拉伸）
const BAR_WIDTH: int = 3
## 按鈕文字離左邊的距離（細條＋一點空隙）
const PAD_LEFT: float = 14.0


static func style(theme: Theme) -> void:
	var focus: StyleBoxTexture = focus_box()
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = PAD_LEFT
	empty.content_margin_right = 10.0
	empty.content_margin_top = 4.0
	empty.content_margin_bottom = 4.0
	for s: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		theme.set_stylebox(s, "Button", empty)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT_FOCUS)
	theme.set_color("font_focus_color", "Button", TEXT_FOCUS)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_hover_pressed_color", "Button", TEXT_FOCUS)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.22, 0.24, 0.28)
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	track.set_corner_radius_all(2)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = ACCENT.darkened(0.15)
	var filled_hi := track.duplicate() as StyleBoxFlat
	filled_hi.bg_color = ACCENT
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled_hi)
	theme.set_stylebox("focus", "HSlider", focus)
	theme.set_icon("grabber", "HSlider", knob(TEXT, 16))
	theme.set_icon("grabber_highlight", "HSlider", knob(TEXT_FOCUS, 18))
	theme.set_icon("grabber_disabled", "HSlider", knob(TEXT_DISABLED, 16))


## 焦點框：左邊 BAR_WIDTH px 實心暖金色（九宮格的左邊界，不拉伸），右邊從 22% 透明度淡出到 0。
static func focus_box() -> StyleBoxTexture:
	var w: int = 128
	var img := Image.create(w, 4, false, Image.FORMAT_RGBA8)
	for x: int in w:
		var c: Color = ACCENT
		if x >= BAR_WIDTH:
			var t: float = float(x - BAR_WIDTH) / float(w - BAR_WIDTH - 1)
			c.a = 0.22 * pow(1.0 - t, 1.6)
		for y: int in 4:
			img.set_pixel(x, y, c)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(img)
	box.texture_margin_left = BAR_WIDTH
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return box


## 圓形把手（柔邊）。
static func knob(color: Color, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r: float = size * 0.5
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var c: Color = color
			c.a *= clampf(r - 1.0 - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
