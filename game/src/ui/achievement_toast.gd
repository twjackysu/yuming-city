class_name AchievementToast
extends CanvasLayer
## 成就解鎖小卡（D-147）：畫面右上角一張暗底小卡（跟看穿小卡同一套樣子，左邊暖金色細條），
## 一個小鐘＋「成就解鎖」＋成就名稱；滑進來、停一下、1.5 秒淡出。
## - 對話、過場、暫停中不顯示（排隊，結束後才出來；暫停時正在顯示的先藏起來、計時停住）
## - 有 Steam 時由 Steam 自己的通知取代（Game 不會把 id 送進來）
## 自己畫的圖只有小鐘的形狀；字一律用子節點 Label（D-060）。

const WARM: Color = Color(0.98, 0.8, 0.52)
const INK: Color = Color(0.97, 0.94, 0.88)
const MARGIN: Vector2 = Vector2(36.0, 30.0)
const SLIDE_SEC: float = 0.35
const HOLD_SEC: float = 3.2
const FADE_SEC: float = 1.5
const SLIDE_PX: float = 26.0
const LAYER: int = 30

## 回傳 true＝現在不能顯示（對話或過場中）；Game 設定
var blocked_check: Callable = func() -> bool: return false
## 排隊中的成就 id（還沒顯示）
var queue: PackedStringArray = []
## 正在顯示的成就 id（沒有則為空字串）
var current: String = ""
var _t: float = 0.0
var _panel: PanelContainer
var _title: Label
var _name: Label


func _init() -> void:
	name = "AchievementToast"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.88)
	sb.border_color = Color(WARM, 0.9)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	var icon := BellIcon.new()
	icon.custom_minimum_size = Vector2(34.0, 40.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	_title = _label(15, Color(WARM, 0.85))
	_title.name = "Title"
	col.add_child(_title)
	_name = _label(23, INK)
	_name.name = "AchName"
	col.add_child(_name)
	_panel.visible = false
	add_child(_panel)


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func enqueue(achievement_id: String) -> void:
	if achievement_id == current or queue.has(achievement_id):
		return
	queue.append(achievement_id)


func is_showing() -> bool:
	return current != "" and _panel.visible


## 目前小卡上的字（測試用）：[標題, 名稱]
func shown_text() -> PackedStringArray:
	return PackedStringArray([_title.text, _name.text]) if current != "" else PackedStringArray()


func total_sec() -> float:
	return SLIDE_SEC + HOLD_SEC + FADE_SEC


func _process(delta: float) -> void:
	tick(delta, get_tree().paused or bool(blocked_check.call()))


## 推進 delta 秒；blocked＝現在不能顯示（暫停、對話、過場）。
func tick(delta: float, blocked: bool) -> void:
	if blocked:
		_panel.visible = false
		return
	if current == "":
		if queue.is_empty():
			return
		current = queue[0]
		queue.remove_at(0)
		_t = 0.0
		_title.text = TranslationServer.translate("ACH_UNLOCKED")
		_name.text = TranslationServer.translate(AchievementTracker.name_key(current))
	else:
		_t += delta
	if _t >= total_sec():
		current = ""
		_panel.visible = false
		return
	_panel.visible = true
	_layout()


func _layout() -> void:
	var s: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = s
	var rect: Rect2 = _panel.get_viewport_rect()
	var slide: float = clampf(_t / SLIDE_SEC, 0.0, 1.0)
	var ease_in: float = 1.0 - pow(1.0 - slide, 3.0)
	var fade_start: float = SLIDE_SEC + HOLD_SEC
	var alpha: float = ease_in
	if _t > fade_start:
		alpha = clampf(1.0 - (_t - fade_start) / FADE_SEC, 0.0, 1.0)
	_panel.modulate.a = alpha
	_panel.position = Vector2(rect.size.x - s.x - MARGIN.x + SLIDE_PX * (1.0 - ease_in), MARGIN.y)


## 小鐘：鐘身（往下張開的梯形＋圓頂）、鐘口一條線、鐘舌一顆點，暖金色。
class BellIcon:
	extends Control

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var c := Color(0.98, 0.8, 0.52)
		var pts := PackedVector2Array()
		var top: float = h * 0.16
		var mouth: float = h * 0.74
		# 圓頂（半圓）
		for i: int in 9:
			var a: float = PI + PI * float(i) / 8.0
			pts.append(Vector2(w * 0.5 + cos(a) * w * 0.22, top + h * 0.12 + sin(a) * h * 0.12))
		# 右側往下張開、鐘口外翻
		pts.append(Vector2(w * 0.74, mouth - h * 0.1))
		pts.append(Vector2(w * 0.92, mouth))
		pts.append(Vector2(w * 0.08, mouth))
		pts.append(Vector2(w * 0.26, mouth - h * 0.1))
		draw_colored_polygon(pts, Color(c, 0.92))
		# 鐘鈕
		draw_rect(Rect2(w * 0.44, top - h * 0.08, w * 0.12, h * 0.1), Color(c, 0.92))
		# 鐘口暗線與鐘舌
		draw_line(Vector2(w * 0.1, mouth - h * 0.03), Vector2(w * 0.9, mouth - h * 0.03), Color(0.03, 0.035, 0.05, 0.6), 1.5)
		draw_circle(Vector2(w * 0.5, mouth + h * 0.1), w * 0.08, Color(c, 0.92))
