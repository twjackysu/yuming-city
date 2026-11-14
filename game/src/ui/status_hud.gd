class_name StatusHud
extends Control
## 狀態圖示：生命條上方一列，每種狀態一格。
## 一格＝原類型的圖示（中毒：瓶子＋骷髏點；麻痺：閃電；防禦歸零：裂開的盾；流血：一滴血）＋反轉時右下角一個金色迴轉箭頭＋剩餘秒數，旁邊一行字
## 「中毒 → 回血」（反轉，金）／「中毒」（沒反轉，紅）。圖示保留原類型，看得出原本是什麼壞東西。會疊的狀態（流血）字後面寫「×層數」。
## **翻面**：狀態剛上身時先是紅的；會反轉的人（StatusEffects.reverses）ReversalCue.CURSE_SEC 秒後翻成金的（跟畫面碎裂同一刻），旁邊彈一圈金光。
## 純顯示：refresh(effects) 每幀從玩家的 StatusEffects 讀。

const ICON: float = 26.0
const ROW_H: float = 34.0
const COL_REVERSED: Color = Color(1.0, 0.82, 0.36)
const COL_HARMFUL: Color = Color(0.95, 0.45, 0.4)
const COL_ICON_BG: Color = Color(0.05, 0.06, 0.08, 0.7)
const COL_BOTTLE: Color = Color(0.78, 0.86, 0.62)
const COL_BOLT: Color = Color(1.0, 0.86, 0.35)
const COL_SHIELD: Color = Color(0.72, 0.78, 0.88)
const COL_BLOOD: Color = Color(0.86, 0.2, 0.22)

## 翻面那一刻彈出去的金圈多久散掉、散到多大（px）
const PULSE_SEC: float = 0.45
const PULSE_GROW: float = 16.0
## 已經在身上很久的（讀檔、換關卡接上的）：直接是翻好的那一面
const SETTLED: float = 99.0

## 每格：{"id", "reversed"（規則上有沒有反轉）, "stacks"（會疊的狀態現在幾層，不會疊的＝0）, "face"（ReversalCue.icon_face：正＝紅的那一面，負＝金的）, "age", "remaining", "label", "hint"}
var rows: Array[Dictionary] = []
var _labels: Array[Label] = []
## status_id -> 上身之後幾秒（只算這個 HUD 看著它的時間）
var _age: Dictionary = {}
var _source: StatusEffects


func _ready() -> void:
	name = "StatusHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## hint_id／hint：這一種狀態現在可以「釋放」——那一列後面多一段組好的字（「滑鼠右鍵：炸出去 56」）。空的＝不顯示。
func refresh(effects: StatusEffects, hint_id: String = "", hint: String = "") -> void:
	rows.clear()
	# 同一個人身上新冒出來的狀態才從紅的那一面開始；剛接上這個人（讀檔、換關卡）時身上已經有的直接是翻好的
	var watching: bool = effects != null and effects == _source
	_source = effects
	var ids: PackedStringArray = effects.ids() if effects != null else PackedStringArray()
	ids.sort()
	for k: Variant in _age.keys():
		if not ids.has(str(k)):
			_age.erase(k)
	for id: String in ids:
		if not _age.has(id):
			_age[id] = 0.0 if watching else SETTLED
		var def: Dictionary = effects.rules.statuses.get(id, {}) as Dictionary
		var reversed: bool = effects.reverses
		var age: float = float(_age[id])
		var face: float = ReversalCue.icon_face(age) if reversed else 1.0
		var key: String = str(def.get("reversed_key" if face < 0.0 else "name_key", id))
		var stacks: int = roundi(effects.rate(id)) if effects.rules.stack_max(id) > 0.0 else 0
		rows.append({"id": id, "reversed": reversed, "stacks": stacks, "face": face, "age": age, "remaining": effects.remaining(id), "label": key, "hint": hint if id == hint_id else ""})
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
		l.text = tr(str(r["label"]))
		if int(r["stacks"]) > 0:
			l.text += " ×%d" % int(r["stacks"])
		l.text += "  %d" % ceili(float(r["remaining"]))
		if str(r.get("hint", "")) != "":
			l.text += "　" + str(r["hint"])
		l.add_theme_color_override("font_color", COL_REVERSED if float(r["face"]) < 0.0 else COL_HARMFUL)
		l.position = Vector2(ICON + 10.0, ROW_H * float(i) + (ICON - 24.0) * 0.5)
	custom_minimum_size = Vector2(260.0, ROW_H * float(rows.size()))
	queue_redraw()


func line_text(i: int) -> String:
	return _labels[i].text if i < _labels.size() and _labels[i].visible else ""


func _process(delta: float) -> void:
	advance(delta)


## 圖示的時間往前走（測試直接呼叫）
func advance(delta: float) -> void:
	for k: Variant in _age.keys():
		_age[k] = minf(float(_age[k]) + delta, SETTLED)


func _draw() -> void:
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		var c: Vector2 = Vector2(0.0, ROW_H * float(i)) + Vector2(ICON, ICON) * 0.5
		var face: float = float(r["face"])
		var gold: bool = face < 0.0
		# 翻面：整個圖示橫向壓扁到 0 再打開（另一面）
		draw_set_transform(c, 0.0, Vector2(maxf(absf(face), 0.04), 1.0))
		draw_circle(Vector2.ZERO, ICON * 0.5, COL_ICON_BG)
		draw_arc(Vector2.ZERO, ICON * 0.5, 0.0, TAU, 24, COL_REVERSED if gold else COL_HARMFUL, 2.0 if gold else 1.5)
		if str(r["id"]) == "poison":
			_draw_bottle(Vector2.ZERO)
		elif str(r["id"]) == "paralysis":
			_draw_bolt(Vector2.ZERO)
		elif str(r["id"]) == "defense_zero":
			_draw_shield(Vector2.ZERO)
		elif str(r["id"]) == "bleed":
			_draw_drop(Vector2.ZERO)
		if gold:
			_draw_reverse_mark(Vector2(ICON * 0.34, ICON * 0.34))
		draw_set_transform(Vector2.ZERO)
		# 翻過去的那一刻：一圈金光往外散
		var since_flip: float = float(r["age"]) - ReversalCue.CURSE_SEC
		if bool(r["reversed"]) and since_flip >= 0.0 and since_flip < PULSE_SEC:
			var k: float = since_flip / PULSE_SEC
			draw_arc(c, ICON * 0.5 + PULSE_GROW * k, 0.0, TAU, 32, Color(COL_REVERSED, (1.0 - k) * 0.9), 3.0 * (1.0 - k) + 1.0)


## 中毒的原圖示：圓肚瓶＋瓶頸＋肚子上兩點一橫（骷髏的簡筆）
func _draw_bottle(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 3), 7.0, COL_BOTTLE)
	draw_rect(Rect2(c + Vector2(-2.5, -9), Vector2(5, 7)), COL_BOTTLE)
	var dark := Color(0.12, 0.14, 0.1)
	draw_circle(c + Vector2(-2.6, 2), 1.5, dark)
	draw_circle(c + Vector2(2.6, 2), 1.5, dark)
	draw_line(c + Vector2(-2.5, 6), c + Vector2(2.5, 6), dark, 1.2)


## 麻痺的原圖示：一道閃電（黃）
func _draw_bolt(c: Vector2) -> void:
	var pts := PackedVector2Array([
		c + Vector2(2.5, -10.0), c + Vector2(-6.0, 1.5), c + Vector2(-0.5, 1.5),
		c + Vector2(-3.0, 10.0), c + Vector2(6.0, -2.5), c + Vector2(0.5, -2.5),
	])
	draw_colored_polygon(pts, COL_BOLT)


## 防禦歸零的原圖示：一面盾，中間一道裂痕
func _draw_shield(c: Vector2) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-7.0, -8.0), c + Vector2(7.0, -8.0), c + Vector2(7.0, 1.0),
		c + Vector2(0.0, 9.5), c + Vector2(-7.0, 1.0),
	])
	draw_colored_polygon(pts, COL_SHIELD)
	var crack := PackedVector2Array([c + Vector2(1.5, -8.0), c + Vector2(-2.0, -2.0), c + Vector2(2.0, 1.0), c + Vector2(-0.5, 8.0)])
	draw_polyline(crack, Color(0.1, 0.11, 0.14), 1.6)


## 流血的原圖示：一滴血（上尖下圓）
func _draw_drop(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 3.5), 6.0, COL_BLOOD)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10.0), c + Vector2(5.4, 1.0), c + Vector2(-5.4, 1.0)]), COL_BLOOD)
	draw_circle(c + Vector2(-2.2, 4.0), 1.6, Color(1.0, 0.75, 0.72, 0.85))


## 反轉標記：右下角的金色迴轉箭頭
func _draw_reverse_mark(p: Vector2) -> void:
	draw_circle(p, 7.0, Color(0.14, 0.1, 0.03, 0.9))
	draw_arc(p, 4.5, PI * 0.15, PI * 1.6, 12, COL_REVERSED, 1.8)
	var tip: Vector2 = p + Vector2(cos(PI * 1.6), sin(PI * 1.6)) * 4.5
	draw_line(tip, tip + Vector2(3.0, -0.5), COL_REVERSED, 1.8)
	draw_line(tip, tip + Vector2(0.5, 3.0), COL_REVERSED, 1.8)
