class_name RestorePrompt
extends Control
## 重現提示（HUD，D-059）：畫面下方中央，不跟右側「重現的代價」記憶卡、上方劇情提示、左下戰鬥 HUD 重疊。
##
## 走近可重現的東西（NineBreathSite.prompt_shown()）：三行——可以重現什麼（霜藍）、**代價**（暖色、最大）、
## 「按住 V　重現 9 秒」＋按住進度條（按滿 1 秒發動，放開歸零）。
## 重現中（is_counting()）：一行「重現中　還剩 N 秒」＋九顆心跳點，每過一秒熄一顆。
## 之前是石拱上方的 Label3D，會被記憶卡蓋住、代價那一行被切掉（第 14 輪截圖）。
## 純顯示：每幀從 nine_breath_site 群組讀狀態，不改任何東西。

const FADE_SPEED: float = 6.0
const BOTTOM_GAP: float = 150.0
const FROST: Color = Color(0.72, 0.9, 1.0)
const WARM: Color = Color(0.98, 0.82, 0.55)
const INK: Color = Color(0.9, 0.92, 0.95)
const PIP_R: float = 6.0
const PIP_GAP: float = 22.0
const BAR_W: float = 180.0
const BAR_H: float = 4.0

var _panel: PanelContainer
var _title: Label
var _cost: Label
var _hint: Label
var _hint_row: HBoxContainer
var _bar: Control
var _count: Label
var _pips: Control
var _site: NineBreathSite
var _alpha: float = 0.0
## 目前顯示的模式："" 隱藏、"prompt" 走近提示、"count" 重現倒數
var mode: String = ""
var hold_ratio: float = 0.0
var breaths_left: int = 0


func _ready() -> void:
	name = "RestorePrompt"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	modulate.a = 0.0
	visible = false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.62)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_title = _label("Title", 20, FROST)
	col.add_child(_title)
	_cost = _label("Cost", 26, WARM)
	var medium: Font = UiFonts.load_font(UiFonts.UI_SANS_MEDIUM)
	if medium != null:
		_cost.add_theme_font_override("font", medium)
	col.add_child(_cost)
	_hint_row = HBoxContainer.new()
	_hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint_row.add_theme_constant_override("separation", 14)
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint_row)
	_hint = _label("Hint", 20, INK)
	_hint_row.add_child(_hint)
	_bar = Control.new()
	_bar.name = "HoldBar"
	_bar.custom_minimum_size = Vector2(BAR_W, 18)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_hint_row.add_child(_bar)
	_count = _label("Count", 30, FROST)
	col.add_child(_count)
	_pips = Control.new()
	_pips.name = "Pips"
	_pips.custom_minimum_size = Vector2(PIP_GAP * float(NineBreath.BREATHS), PIP_R * 2.0 + 6.0)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	col.add_child(_pips)


func _label(n: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.name = n
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	refresh(delta)


## 讀場景裡的重現點，更新文字與版面。測試可以直接呼叫。
func refresh(delta: float) -> void:
	_site = _active_site()
	var want: String = ""
	if _site != null:
		want = "count" if _site.is_counting() else "prompt"
	if want != "":
		_apply(want)
	var target: float = 1.0 if want != "" else 0.0
	_alpha = move_toward(_alpha, target, delta * FADE_SPEED) if delta > 0.0 else target
	modulate.a = _alpha
	visible = _alpha > 0.001
	if _alpha <= 0.001:
		mode = ""


func _active_site() -> NineBreathSite:
	if not is_inside_tree():
		return null
	for n: Node in get_tree().get_nodes_in_group("nine_breath_site"):
		var s: NineBreathSite = n as NineBreathSite
		if s != null and (s.is_counting() or s.prompt_shown()):
			return s
	return null


func _apply(want: String) -> void:
	mode = want
	var prompt: bool = want == "prompt"
	_title.visible = prompt
	_cost.visible = prompt
	_hint_row.visible = prompt
	_count.visible = not prompt
	_pips.visible = not prompt
	if prompt:
		var lines: PackedStringArray = _site.prompt_lines()
		_set_text(_title, lines[0])
		_set_text(_cost, lines[1])
		_set_text(_hint, lines[2])
		hold_ratio = _site.hold_ratio()
		_bar.queue_redraw()
	else:
		breaths_left = _site.breaths_left()
		_set_text(_count, _site.countdown_text())
		_pips.queue_redraw()
	_place()


func _set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t


## 面板貼著畫面下方置中，寬度照內容。
func _place() -> void:
	var sz: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = sz
	_panel.position = Vector2((size.x - sz.x) * 0.5, size.y - BOTTOM_GAP - sz.y)


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


func text() -> String:
	if mode == "prompt":
		return "%s\n%s\n%s" % [_title.text, _cost.text, _hint.text]
	if mode == "count":
		return _count.text
	return ""


func _draw_bar() -> void:
	var y: float = (_bar.size.y - BAR_H) * 0.5
	_bar.draw_rect(Rect2(0, y, BAR_W, BAR_H), Color(1, 1, 1, 0.16))
	if hold_ratio > 0.0:
		_bar.draw_rect(Rect2(0, y, BAR_W * hold_ratio, BAR_H), FROST)


func _draw_pips() -> void:
	var n: int = NineBreath.BREATHS
	var x0: float = (_pips.size.x - PIP_GAP * float(n - 1)) * 0.5
	var y: float = _pips.size.y * 0.5
	for i: int in n:
		var c := Vector2(x0 + PIP_GAP * float(i), y)
		if i < breaths_left:
			_pips.draw_circle(c, PIP_R, FROST)
		else:
			_pips.draw_circle(c, PIP_R - 1.5, Color(FROST, 0.35), false, 1.5)
