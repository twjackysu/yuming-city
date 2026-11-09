class_name GuideMarkView
extends CanvasLayer
## 第 1 章段落 3「把攻略畫成地圖」的標記畫面（D-150，07-chapter1-door.md 系統 1）：
## 桌上一張舊紙，列出剛寫下的攻略筆記；玩家逐條決定標不標「我不確定」，按「就這樣」結束。
## - 打開時暫停遊戲（跟日記一樣），本身 PROCESS_MODE_ALWAYS
## - 鍵盤／手把：上下移動焦點、確認鍵切換；滑鼠直接點
## - 每一列是 flat Button（全域 Theme 的暖金色焦點），字一律用子節點 Label（D-060）
## 結果在 confirm() 時才寫進 GameState.guide（GuideNotes.set_unsure），中途關不掉。

signal confirmed(unsure_ids: PackedStringArray)

const PAPER: Color = Color(0.86, 0.8, 0.66)
const INK: Color = Color(0.2, 0.15, 0.1)
const INK_SOFT: Color = Color(0.42, 0.37, 0.31)
const LAYER: int = 25
const ROW_WIDTH: float = 820.0

var entry_ids: PackedStringArray = []
## id -> 那一列的按鈕
var rows: Dictionary = {}
var done_button: Button
var _state: GameState
var _unsure: Dictionary = {}
var _status_labels: Dictionary = {}
var _closed: bool = false


## 開一個標記畫面：列出 state 裡已寫下、還沒有結果的條目（照 notes 的順序）。
static func open_on(parent: Node, state: GameState, notes: GuideNotes) -> GuideMarkView:
	var v := GuideMarkView.new()
	v._state = state
	for id: String in notes.ids():
		var st: String = GuideNotes.status(state, id)
		if st == GuideNotes.SURE or st == GuideNotes.UNSURE:
			v.entry_ids.append(id)
			v._unsure[id] = st == GuideNotes.UNSURE
	parent.add_child(v)
	return v


func _ready() -> void:
	name = "GuideMarkView"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_tree().paused = true
	if not entry_ids.is_empty():
		(rows[entry_ids[0]] as Button).grab_focus.call_deferred()
	else:
		done_button.grab_focus.call_deferred()


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var paper := PanelContainer.new()
	paper.name = "Paper"
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = Color(0.55, 0.45, 0.32)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 44.0
	sb.content_margin_right = 44.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 18
	paper.add_theme_stylebox_override("panel", sb)
	center.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	paper.add_child(col)
	var title := _label("GUIDE_MARK_TITLE", 34, INK)
	title.name = "Title"
	var serif: Font = UiFonts.load_font(UiFonts.TITLE_SERIF)
	if serif != null:
		title.add_theme_font_override("font", serif)
	col.add_child(title)
	var hint := _label("GUIDE_MARK_HINT", 20, INK_SOFT)
	hint.name = "Hint"
	col.add_child(hint)
	col.add_child(_spacer(10.0))
	for id: String in entry_ids:
		col.add_child(_row(id))
	col.add_child(_spacer(14.0))
	done_button = Button.new()
	done_button.name = "Done"
	done_button.flat = true
	done_button.custom_minimum_size = Vector2(220.0, 52.0)
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done_button.focus_mode = Control.FOCUS_ALL
	var done_label := _label("GUIDE_MARK_DONE", 24, INK)
	done_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	done_button.add_child(done_label)
	done_button.pressed.connect(confirm)
	col.add_child(done_button)


func _row(id: String) -> Button:
	var b := Button.new()
	b.name = "Row_" + id
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(ROW_WIDTH, 64.0)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12.0
	h.offset_right = -12.0
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 18)
	b.add_child(h)
	var text := _label(GuideNotes.text_key(id), 20, INK)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(text)
	var status := _label("", 19, INK)
	status.name = "Status"
	status.custom_minimum_size = Vector2(130.0, 0.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(status)
	_status_labels[id] = status
	b.pressed.connect(toggle.bind(id))
	rows[id] = b
	_refresh(id)
	return b


func _label(key: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = key
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _refresh(id: String) -> void:
	var unsure: bool = is_unsure(id)
	var status: Label = _status_labels.get(id) as Label
	if status != null:
		status.text = "GUIDE_STATUS_UNSURE" if unsure else "GUIDE_STATUS_SURE"
		status.add_theme_color_override("font_color", INK_SOFT if unsure else INK)
	var b: Button = rows.get(id) as Button
	if b != null:
		# 標了我不確定的整列淡一點（像用鉛筆圈起來、沒那麼篤定）
		b.modulate = Color(1.0, 1.0, 1.0, 0.62) if unsure else Color.WHITE


func is_unsure(id: String) -> bool:
	return bool(_unsure.get(id, false))


func set_unsure(id: String, unsure: bool) -> void:
	if not _unsure.has(id) or _closed:
		return
	_unsure[id] = unsure
	_refresh(id)
	Sfx.play_flat(self, "ui_tick", -15.0)


func toggle(id: String) -> void:
	set_unsure(id, not is_unsure(id))


func unsure_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in entry_ids:
		if is_unsure(id):
			out.append(id)
	return out


## 寫進 GameState.guide、解除暫停、關閉；只會生效一次。
func confirm() -> void:
	if _closed:
		return
	_closed = true
	for id: String in entry_ids:
		GuideNotes.set_unsure(_state, id, is_unsure(id))
	get_tree().paused = false
	var picked: PackedStringArray = unsure_ids()
	queue_free()
	confirmed.emit(picked)


func _exit_tree() -> void:
	# 關卡被釋放（回標題、測試）時別讓遊戲停在暫停
	if not _closed and get_tree() != null:
		get_tree().paused = false
