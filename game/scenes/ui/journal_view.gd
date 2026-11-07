class_name JournalView
extends CanvasLayer
## 日記畫面（docs/design/02-gameplay.md「記憶與日記」）：
## - Tab／View 打開（暫停遊戲），再按一次或 Esc／B 闔上。最上面是目前目標（Tab 原本的「再看一次目標」）。
## - 被付出的記憶：標題與前後文保留，內文變成一塊被整齊剪掉的空白，下面是殘留的一句。
## - 九息預覽中（Game.journal.highlighted）：不暫停，在畫面右側只顯示那一張卡（「九息的代價」）。

const PAPER: Color = Color(0.075, 0.08, 0.095, 0.96)
const INK: Color = Color(0.86, 0.84, 0.8)
const INK_DIM: Color = Color(0.62, 0.62, 0.64)
const WARM: Color = Color(0.95, 0.72, 0.42)
const CUT: Color = Color(0.13, 0.135, 0.15)

var _root: Control
var _list: VBoxContainer
var _hint: Label
var _objective: Label
var _peek: PanelContainer
var _peek_id: String = ""
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	_peek.hide()
	# 截圖用：`--open=journal`（可配 `--arch=spent` 看被剪掉的樣子）
	if str(App.parse_user_args(OS.get_cmdline_user_args()).get("open", "")) == "journal":
		open.call_deferred()


func is_open() -> bool:
	return _root.visible


func is_peeking() -> bool:
	return _peek.visible


## 目前日記裡顯示的條目數（測試用）。
func shown_entry_count() -> int:
	return _list.get_child_count()


func open() -> void:
	if is_open() or Game.is_player_locked():
		return
	_refresh()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.show()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = _mouse_before


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if is_open():
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var j: Journal = Game.journal
	var want: String = j.highlighted if j != null and not is_open() else ""
	if want == _peek_id:
		return
	_peek_id = want
	for c: Node in _peek.get_children():
		c.queue_free()
	if want == "" or not j.has_entry(want):
		_peek.hide()
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := Label.new()
	head.text = "JOURNAL_PEEK"
	head.add_theme_color_override("font_color", WARM)
	head.add_theme_font_size_override("font_size", 18)
	box.add_child(head)
	box.add_child(_card(j.view(want, Game.session.state)))
	_peek.add_child(box)
	_peek.show()


func _refresh() -> void:
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	# Tab 原本是「再看一次目前目標」：日記最上面也放目前目標
	_objective.text = Game.session.objective_key()
	var j: Journal = Game.journal
	if j == null:
		return
	for id: String in j.visible_ids(Game.session.state):
		_list.add_child(_card(j.view(id, Game.session.state)))
	_hint.text = TranslationServer.translate("JOURNAL_HINT_CLOSE").format({"key": InputGlyphs.label_for_action("journal", App.last_device)})


## 一張記憶卡：標題、前後文、內文（或被剪掉的空白＋殘留）。
func _card(v: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_" + str(v.get("id", ""))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.105, 0.12, 0.98)
	sb.set_content_margin_all(18)
	sb.set_border_width_all(2 if bool(v.get("highlighted", false)) else 0)
	sb.border_color = WARM
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := Label.new()
	title.text = str(v.get("title", ""))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", WARM if bool(v.get("highlighted", false)) else INK)
	box.add_child(title)
	if str(v.get("context", "")) != "":
		box.add_child(_para(str(v["context"]), INK_DIM))
	if bool(v.get("cut", false)):
		# 被整齊剪掉的空白：一塊比紙稍亮的空格，上下各一條細線
		var gap := Panel.new()
		gap.name = "CutGap"
		gap.custom_minimum_size = Vector2(0, 76)
		var gs := StyleBoxFlat.new()
		gs.bg_color = CUT
		gs.border_width_top = 1
		gs.border_width_bottom = 1
		gs.border_color = Color(0.3, 0.31, 0.34)
		gap.add_theme_stylebox_override("panel", gs)
		gap.tooltip_text = "JOURNAL_CUT"
		box.add_child(gap)
		if str(v.get("residue", "")) != "":
			box.add_child(_para(str(v["residue"]), INK))
	else:
		box.add_child(_para(str(v.get("body", "")), INK))
	return card


func _para(key: String, color: Color) -> Label:
	var l := Label.new()
	l.text = key
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(560, 0)
	return l


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var paper := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = PAPER
	ps.set_content_margin_all(36)
	paper.add_theme_stylebox_override("panel", ps)
	paper.custom_minimum_size = Vector2(720, 520)
	center.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	paper.add_child(col)
	var title := Label.new()
	title.text = "JOURNAL_TITLE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK)
	col.add_child(title)
	var obj_head := Label.new()
	obj_head.text = "HUD_OBJECTIVE"
	obj_head.add_theme_font_size_override("font_size", 14)
	obj_head.add_theme_color_override("font_color", WARM)
	col.add_child(obj_head)
	_objective = Label.new()
	_objective.name = "Objective"
	_objective.add_theme_font_size_override("font_size", 20)
	_objective.add_theme_color_override("font_color", INK)
	col.add_child(_objective)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", INK_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)

	_peek = PanelContainer.new()
	_peek.name = "Peek"
	var pk := StyleBoxFlat.new()
	pk.bg_color = Color(0.05, 0.055, 0.07, 0.82)
	pk.set_content_margin_all(16)
	_peek.add_theme_stylebox_override("panel", pk)
	_peek.anchor_left = 1.0
	_peek.anchor_right = 1.0
	_peek.anchor_top = 0.18
	_peek.anchor_bottom = 0.18
	_peek.offset_left = -660.0
	_peek.offset_right = -40.0
	_peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_peek)
