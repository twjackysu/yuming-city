class_name StrikeCard
extends PanelContainer
## 看穿「看錯」的小卡（第 2 章段落 1，D-158；08-chapter2-3.md）：對伊薩按住看穿時，先跳出攻略裡的樣子
## （「食歲的僭王」「弱點：心臟」），按住一秒後字一個一個被劃掉，劃完換成真的伊薩（「伊薩，城主。右腿金屬支架。問了席菈的手。」）。
## 外觀照看穿小卡（InsightCard）：暗底、左邊一條霜藍細線；被劃掉的字變淡、中間一條暖金色的線（自己畫的 ColorRect）。
## 只有按住的時候會往前走（放開就停在那裡，下次按住接著劃）；劃完之後再按住直接顯示最後的樣子。

signal finished

## 按住多久才開始劃（先讓玩家讀到攻略的字）
const HOLD_BEFORE_SEC: float = 1.0
## 從第一個字劃到最後一個字要幾秒（固定時間：英文的字數是中文的四倍，照字數算英文要多等好幾秒——第 42 輪截圖）
const STRIKE_SEC: float = 1.4

## 攻略裡的那幾行（已翻譯）
var lines: PackedStringArray = []
## 劃完之後的真話（已翻譯）
var truth: String = ""
## 按住累積了幾秒
var held: float = 0.0
var _rows: Array[HBoxContainer] = []
var _truth_label: Label
var _done: bool = false


func _init() -> void:
	name = "StrikeCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.04, 0.065, 0.84)
	sb.border_color = Color(InsightCard.FROST, 0.85)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 9.0
	sb.content_margin_bottom = 11.0
	add_theme_stylebox_override("panel", sb)
	visible = false


## 換內容：攻略的幾行＋真話（都要先翻譯好）。done＝已經劃完過（讀檔、重來）。
func setup(guide_lines: PackedStringArray, truth_text: String, done: bool = false) -> void:
	lines = guide_lines
	truth = truth_text
	_done = done
	held = total_sec() if done else 0.0
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_rows.clear()
	var box := VBoxContainer.new()
	box.name = "Rows"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	for i: int in lines.size():
		var row := HBoxContainer.new()
		row.name = "Guide%d" % i
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 0)
		var size_px: int = 24 if i == 0 else 19
		var struck_l: Label = _label("Struck", size_px, Color(InsightCard.DIM, 0.75))
		# 刪除線自己畫一條（字型子集的刪除線粗細是 0，RichTextLabel 的 [s] 畫不出來——第 42 輪截圖）
		var line := ColorRect.new()
		line.name = "Line"
		line.color = Color(InsightCard.WARM, 0.9)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = 0.55
		line.anchor_bottom = 0.55
		line.offset_top = -1.0
		line.offset_bottom = 1.0
		struck_l.add_child(line)
		row.add_child(struck_l)
		row.add_child(_label("Rest", size_px, InsightCard.NAME_COL if i == 0 else InsightCard.INK))
		box.add_child(row)
		_rows.append(row)
	_truth_label = Label.new()
	_truth_label.name = "Truth"
	_truth_label.text = truth
	_truth_label.add_theme_font_size_override("font_size", 19)
	_truth_label.add_theme_color_override("font_color", InsightCard.WARM)
	_truth_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_truth_label)
	_refresh()


## 全部的字數（劃線要劃幾個字）。
func total_chars() -> int:
	var n: int = 0
	for l: String in lines:
		n += l.length()
	return n


## 從開始按住到劃完要幾秒。
func total_sec() -> float:
	return HOLD_BEFORE_SEC + STRIKE_SEC


## 現在劃掉了幾個字。
func struck_count() -> int:
	return clampi(int(floor((held - HOLD_BEFORE_SEC) / STRIKE_SEC * float(total_chars()))), 0, total_chars())


func is_done() -> bool:
	return _done


## 按住看穿的每一幀呼叫：往前劃；剛好劃完的那一幀回傳 true（並發出 finished）。
func advance(delta: float) -> bool:
	if _done:
		return false
	held += delta
	var just: bool = struck_count() >= total_chars()
	if just:
		_done = true
	_refresh()
	if just:
		finished.emit()
	return just


## 一行字被劃掉的部分與剩下的部分：[前 n 個字, 其餘]。
static func split_struck(text: String, n: int) -> PackedStringArray:
	var k: int = clampi(n, 0, text.length())
	return PackedStringArray([text.left(k), text.substr(k)])


func _label(node_name: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _refresh() -> void:
	var left: int = struck_count()
	for i: int in _rows.size():
		var line: String = lines[i]
		var parts: PackedStringArray = split_struck(line, left)
		var struck_l: Label = _rows[i].get_node("Struck") as Label
		struck_l.text = parts[0]
		struck_l.visible = parts[0] != ""
		(_rows[i].get_node("Rest") as Label).text = parts[1]
		left = maxi(left - line.length(), 0)
	if _truth_label != null:
		_truth_label.visible = _done
	reset_size()


## 每幀：放在 world（頭頂）投影點的右邊；在鏡頭後面就藏起來（同看穿小卡）。
func place(cam: Camera3D, world: Vector3) -> void:
	if cam == null or cam.is_position_behind(world):
		visible = false
		return
	visible = true
	var rect: Rect2 = get_viewport_rect()
	var s: Vector2 = get_combined_minimum_size()
	var p: Vector2 = InsightCard.card_anchor(cam, world, 0.3)
	p.x = clampf(p.x, InsightCard.MARGIN, maxf(InsightCard.MARGIN, rect.size.x - s.x - InsightCard.MARGIN))
	p.y = clampf(p.y, InsightCard.MARGIN, maxf(InsightCard.MARGIN, rect.size.y - s.y - InsightCard.MARGIN))
	position = p
	size = s
