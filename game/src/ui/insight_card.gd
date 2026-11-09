class_name InsightCard
extends PanelContainer
## 看穿小卡（第二輪盤點第 3 項，D-087）：按住看穿時，敵人頭旁邊一張暗底小卡，取代原本浮在頭上的一串白字。
## - 名字一行（大一點、暖白），下面一條細線
## - 「弱點」「招式」兩段小標題；已證實的畫一個小勾，未證實的是空心圈＋淡色「（未證實？）」
## - 正在出的招整列變暖金色、前面一個小三角（原本的「▶」）
## 位置每幀由 EnemyActor 呼叫 place()：頭頂的世界座標投影到畫面，卡片放在敵人右邊、夾在畫面內；在鏡頭後面就藏起來。
## 字都已經翻譯好（EnemyIntel.rows），自己不再自動翻譯。

const FROST: Color = Color(0.55, 0.82, 1.0)
const INK: Color = Color(0.92, 0.94, 0.97)
const DIM: Color = Color(0.6, 0.66, 0.74)
const WARM: Color = Color(0.98, 0.8, 0.52)
const NAME_COL: Color = Color(0.97, 0.94, 0.88)
const MARGIN: float = 16.0
## 卡片左上角相對於頭頂投影點的位移：在敵人右邊、從頭的高度往下長（頭頂上方常是過場字幕與目標橫幅）
const OFFSET: Vector2 = Vector2(44.0, -14.0)
## 卡片左緣至少離敵人身體右緣（side_m 公尺，沿鏡頭右方投影）這麼多像素：送葬者背上的鐵架很寬，
## 只用固定位移會蓋到鐵架（第八輪盤點第 8 項，D-146）
const EDGE_GAP: float = 14.0

## 目前顯示的列（測試用）
var rows_shown: Array[Dictionary] = []
var _sig: String = ""
var _box: VBoxContainer


func _init() -> void:
	name = "InsightCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.04, 0.065, 0.84)
	sb.border_color = Color(FROST, 0.85)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 9.0
	sb.content_margin_bottom = 11.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 10
	add_theme_stylebox_override("panel", sb)
	_box = VBoxContainer.new()
	_box.name = "Rows"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 3)
	add_child(_box)
	visible = false


## 換內容（跟上次一樣就不重建）。rows 的格式見 EnemyIntel.rows()。
func set_rows(rows: Array[Dictionary]) -> void:
	var sig: String = var_to_str(rows)
	if sig == _sig:
		return
	_sig = sig
	rows_shown = rows.duplicate(true)
	for c: Node in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var section: String = ""
	for r: Dictionary in rows:
		var kind: String = str(r.get("kind", ""))
		if kind == "name":
			_box.add_child(_label(str(r.get("text", "")), 24, NAME_COL))
			_box.add_child(_rule())
			continue
		if kind == "unknown":
			_box.add_child(_label(str(r.get("text", "")), 18, DIM))
			continue
		if kind != section:
			section = kind
			var key: String = "INSIGHT_SEC_WEAK" if kind == "weak" else "INSIGHT_SEC_MOVES"
			var head: Label = _label(TranslationServer.translate(key), 15, Color(FROST, 0.8))
			head.name = "Section_" + kind
			_box.add_child(head)
		_box.add_child(_row(r))
	reset_size()


## 每幀：把卡片放到 world（敵人頭頂）投影點的右邊、從頭的高度往下，夾在畫面內；在鏡頭後面就藏起來。
## side_m：敵人身體（含背上的東西）往右多寬，卡片左緣不會蓋進這個範圍。
func place(cam: Camera3D, world: Vector3, side_m: float = 0.0) -> void:
	if cam == null or cam.is_position_behind(world):
		visible = false
		return
	visible = true
	var rect: Rect2 = get_viewport_rect()
	var s: Vector2 = get_combined_minimum_size()
	var p: Vector2 = card_anchor(cam, world, side_m)
	var pos := p
	pos.x = clampf(pos.x, MARGIN, maxf(MARGIN, rect.size.x - s.x - MARGIN))
	pos.y = clampf(pos.y, MARGIN, maxf(MARGIN, rect.size.y - s.y - MARGIN))
	position = pos
	size = s


## 卡片左上角（夾進畫面之前）：頭頂投影點＋OFFSET，但不蓋進身體右緣 side_m 公尺的投影。
static func card_anchor(cam: Camera3D, world: Vector3, side_m: float) -> Vector2:
	var p: Vector2 = cam.unproject_position(world) + OFFSET
	if side_m > 0.0:
		var edge: Vector2 = cam.unproject_position(world + cam.global_transform.basis.x * side_m)
		p.x = maxf(p.x, edge.x + EDGE_GAP)
	return p


## 已證實的小勾有幾個（測試用）。
func check_count() -> int:
	var n: int = 0
	for m: Node in find_children("*", "Control", true, false):
		if m is Mark and (m as Mark).mode == Mark.CHECK:
			n += 1
	return n


func _row(r: Dictionary) -> HBoxContainer:
	var verified: bool = bool(r.get("verified", false))
	var current: bool = bool(r.get("current", false))
	var h := HBoxContainer.new()
	h.name = "Row"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 7)
	var mark := Mark.new()
	mark.mode = Mark.CURRENT if current else (Mark.CHECK if verified else Mark.OPEN)
	h.add_child(mark)
	var col: Color = WARM if current else (INK if verified else DIM)
	var text: Label = _label(str(r.get("text", "")), 19, col)
	text.name = "Text"
	h.add_child(text)
	if not verified:
		var tag: Label = _label(TranslationServer.translate("INSIGHT_UNVERIFIED"), 15, Color(DIM, 0.85))
		tag.name = "Unverified"
		h.add_child(tag)
	return h


func _label(t: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.name = "Rule"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(0.0, 1.0)
	r.color = Color(FROST, 0.3)
	return r


## 列前面的小記號：只畫線與多邊形，不畫字（D-060）。
class Mark:
	extends Control
	const CHECK: int = 0
	const OPEN: int = 1
	const CURRENT: int = 2
	var mode: int = OPEN

	func _init() -> void:
		custom_minimum_size = Vector2(16.0, 16.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		match mode:
			CHECK:
				var pts := PackedVector2Array([c + Vector2(-4.5, 0.5), c + Vector2(-1.2, 3.8), c + Vector2(5.0, -3.8)])
				draw_polyline(pts, Color(0.01, 0.02, 0.04, 0.8), 4.0, true)
				draw_polyline(pts, InsightCard.FROST, 2.0, true)
			OPEN:
				draw_arc(c, 4.0, 0.0, TAU, 20, Color(InsightCard.DIM, 0.9), 1.5, true)
			CURRENT:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, -5.0), c + Vector2(5.0, 0.0), c + Vector2(-3.5, 5.0)]), InsightCard.WARM)
