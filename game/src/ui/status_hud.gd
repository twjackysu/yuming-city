class_name StatusHud
extends Control
## 新版的狀態圖示（D-202，09 第 6 節）：生命條下方一列，每種狀態一格。
## 一格＝原類型的圖示（中毒：瓶子＋骷髏點）＋反轉時右下角一個綠色迴轉箭頭＋剩餘秒數，旁邊一行字
## 「中毒 → 回血」（反轉，綠）／「中毒」（沒反轉，紅）。圖示保留原類型，不讓人以為綠霧對所有人安全。
## 純顯示：refresh(effects) 每幀從玩家的 StatusEffects 讀。

const ICON: float = 26.0
const ROW_H: float = 34.0
const COL_REVERSED: Color = Color(0.55, 0.92, 0.55)
const COL_HARMFUL: Color = Color(0.95, 0.45, 0.4)
const COL_ICON_BG: Color = Color(0.05, 0.06, 0.08, 0.7)
const COL_BOTTLE: Color = Color(0.78, 0.86, 0.62)

## 每格：{"id", "reversed", "remaining", "label"}
var rows: Array[Dictionary] = []
var _labels: Array[Label] = []


func _ready() -> void:
	name = "StatusHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh(effects: StatusEffects) -> void:
	rows.clear()
	if effects != null:
		var ids: PackedStringArray = effects.ids()
		ids.sort()
		for id: String in ids:
			var def: Dictionary = effects.rules.statuses.get(id, {}) as Dictionary
			var reversed: bool = effects.is_reversed(id)
			var key: String = str(def.get("reversed_key" if reversed else "name_key", id))
			rows.append({"id": id, "reversed": reversed, "remaining": effects.remaining(id), "label": key})
	while _labels.size() < rows.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 動態組字（翻譯＋秒數）：UI 測試的「寫死文字」檢查會跳過
		l.set_meta("glyph", true)
		add_child(l)
		_labels.append(l)
	for i: int in _labels.size():
		var l: Label = _labels[i]
		l.visible = i < rows.size()
		if not l.visible:
			continue
		var r: Dictionary = rows[i]
		l.text = "%s  %d" % [tr(str(r["label"])), ceili(float(r["remaining"]))]
		l.add_theme_color_override("font_color", COL_REVERSED if bool(r["reversed"]) else COL_HARMFUL)
		l.position = Vector2(ICON + 10.0, ROW_H * float(i) + (ICON - 24.0) * 0.5)
	custom_minimum_size = Vector2(260.0, ROW_H * float(rows.size()))
	queue_redraw()


func line_text(i: int) -> String:
	return _labels[i].text if i < _labels.size() and _labels[i].visible else ""


func _draw() -> void:
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		var o: Vector2 = Vector2(0.0, ROW_H * float(i))
		var c: Vector2 = o + Vector2(ICON, ICON) * 0.5
		draw_circle(c, ICON * 0.5, COL_ICON_BG)
		draw_arc(c, ICON * 0.5, 0.0, TAU, 24, COL_REVERSED if bool(r["reversed"]) else COL_HARMFUL, 1.5)
		if str(r["id"]) == "poison":
			_draw_bottle(c)
		if bool(r["reversed"]):
			_draw_reverse_mark(c + Vector2(ICON * 0.34, ICON * 0.34))


## 中毒的原圖示：圓肚瓶＋瓶頸＋肚子上兩點一橫（骷髏的簡筆）
func _draw_bottle(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 3), 7.0, COL_BOTTLE)
	draw_rect(Rect2(c + Vector2(-2.5, -9), Vector2(5, 7)), COL_BOTTLE)
	var dark := Color(0.12, 0.14, 0.1)
	draw_circle(c + Vector2(-2.6, 2), 1.5, dark)
	draw_circle(c + Vector2(2.6, 2), 1.5, dark)
	draw_line(c + Vector2(-2.5, 6), c + Vector2(2.5, 6), dark, 1.2)


## 反轉標記：右下角的綠色迴轉箭頭
func _draw_reverse_mark(p: Vector2) -> void:
	draw_circle(p, 7.0, Color(0.05, 0.12, 0.06, 0.9))
	draw_arc(p, 4.5, PI * 0.15, PI * 1.6, 12, COL_REVERSED, 1.8)
	var tip: Vector2 = p + Vector2(cos(PI * 1.6), sin(PI * 1.6)) * 4.5
	draw_line(tip, tip + Vector2(3.0, -0.5), COL_REVERSED, 1.8)
	draw_line(tip, tip + Vector2(0.5, 3.0), COL_REVERSED, 1.8)
