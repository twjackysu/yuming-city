class_name GlyphLine
extends HBoxContainer
## 一行含按鍵的提示（D-063）：翻譯字串裡的 {key} 在鍵鼠模式顯示成「[F]」文字，
## 在手把模式換成 PadGlyph 按鈕圖示（圖示之間的字各用一個 Label；{key} 可以出現不只一次）。
## 例：「按住 {key}　重現 9 秒」→ 鍵鼠「按住 [V]　重現 9 秒」；手把「按住 (Y 圖示)　重現 9 秒」。
## 字一律用子節點 Label（D-060：遊戲裡 draw_string 這套子集字型會畫成缺字方塊）。
## Label 印的是組好的字（不是翻譯 key），標 meta "glyph"，UI 測試的「寫死文字」檢查會跳過。
## plain_text() 永遠是文字版（「[Y]」），給測試與讀屏用。

## 圖示高度相對字級
const GLYPH_SCALE: float = 1.3
const KEY: String = "{key}"

var font_size: int = 20
## 內容變了就把自己縮成剛好的大小（放在一般 Control 底下用）；用錨點或放在容器裡時設成 false。
var fit_content: bool = true
var _color: Color = Color(0.9, 0.92, 0.95)
var _font: Font
## 依序排列的子節點：Label 與 PadGlyph 交錯（用不到的隱藏，下次重用）
var _labels: Array[Label] = []
var _glyphs: Array[PadGlyph] = []
var _plain: String = ""
var _sig: String = ""
var _uses_glyph: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)


## 字級、顏色、字型（null＝主題預設）。回傳自己方便串接。
func configure(size: int, color: Color, font: Font = null) -> GlyphLine:
	font_size = size
	_font = font
	_color = color
	for l: Label in _labels:
		_style_label(l)
	for g: PadGlyph in _glyphs:
		g.glyph_h = _glyph_h()
		g.spec = g.spec
	return self


func set_color(c: Color) -> void:
	if c == _color:
		return
	_color = c
	for l: Label in _labels:
		l.add_theme_color_override("font_color", c)


## fmt：已翻譯、其他佔位符已代入的字串，保留 {key}；action：InputMap 動作；device：InputGlyphs.Device。
## 內容沒變就不重排（HUD 每幀呼叫）。
func set_line(fmt: String, action: String, device: int) -> void:
	var spec: Vector2i = InputGlyphs.spec_for_action(action, device)
	var use_glyph: bool = device == InputGlyphs.Device.PAD and fmt.contains(KEY) \
		and PadGlyph.shape_of(spec) != PadGlyph.Shape.NONE
	var key_text: String = InputGlyphs.label_for_action(action, device)
	var sig: String = "%s|%s|%s" % [fmt, key_text, str(spec) if use_glyph else ""]
	if sig == _sig:
		return
	_sig = sig
	_plain = fmt.replace(KEY, key_text)
	_uses_glyph = use_glyph
	var segments: PackedStringArray = fmt.split(KEY) if use_glyph else PackedStringArray([_plain])
	var li: int = 0
	var gi: int = 0
	var child_i: int = 0
	for i: int in segments.size():
		var t: String = segments[i]
		if use_glyph:
			# 圖示兩側的半形空白交給容器間距（全形空白保留，那是中文的停頓）
			t = t.strip_edges(i > 0, i < segments.size() - 1)
		if t != "":
			var l: Label = _label_at(li)
			l.text = t
			l.visible = true
			move_child(l, child_i)
			li += 1
			child_i += 1
		if use_glyph and i < segments.size() - 1:
			var g: PadGlyph = _glyph_at(gi)
			if g.spec != spec:
				g.spec = spec
			g.visible = true
			move_child(g, child_i)
			gi += 1
			child_i += 1
	for j: int in range(li, _labels.size()):
		_labels[j].visible = false
	for j: int in range(gi, _glyphs.size()):
		_glyphs[j].visible = false
	if fit_content:
		reset_size()


## 字的顏色（看第一個字段 Label 實際的主題色；還沒有字段時回傳設定值）。
func text_color() -> Color:
	if not _labels.is_empty():
		return _labels[0].get_theme_color("font_color")
	return _color


func plain_text() -> String:
	return _plain


## 目前是不是用手把圖示顯示按鍵。
func uses_glyph() -> bool:
	return _uses_glyph


## 看得到的圖示（測試用）。
func visible_glyphs() -> Array[PadGlyph]:
	var out: Array[PadGlyph] = []
	for g: PadGlyph in _glyphs:
		if g.visible:
			out.append(g)
	return out


## 看得到的字段（照順序，測試用）。
func parts() -> PackedStringArray:
	var out := PackedStringArray()
	for c: Node in get_children():
		var l: Label = c as Label
		if l != null and l.visible:
			out.append(l.text)
	return out


func _glyph_h() -> float:
	return roundf(float(font_size) * GLYPH_SCALE)


func _label_at(i: int) -> Label:
	while _labels.size() <= i:
		var l := Label.new()
		l.name = "Text%d" % _labels.size()
		l.set_meta("glyph", true)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("shadow_offset_y", 2)
		_style_label(l)
		add_child(l)
		_labels.append(l)
	return _labels[i]


func _glyph_at(i: int) -> PadGlyph:
	while _glyphs.size() <= i:
		var g := PadGlyph.new()
		g.name = "Glyph%d" % _glyphs.size()
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.glyph_h = _glyph_h()
		add_child(g)
		_glyphs.append(g)
	return _glyphs[i]


func _style_label(l: Label) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", _color)
	if _font != null:
		l.add_theme_font_override("font", _font)
