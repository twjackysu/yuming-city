class_name ControlsMenu
extends Control
## 按鍵設定（從設定選單開啟）：每個動作一列，鍵鼠與手把各一格。
## 按下格子後等待下一個鍵（鍵鼠格只收鍵盤／滑鼠，手把格只收手把）；Esc／Start 取消，6 秒沒按也取消。
## 新鍵已被別的動作用掉時兩者交換（InputSetup.rebind）。暫停鍵與移動搖桿固定。關閉時存到 settings.cfg。
## 鍵名格子不是翻譯 key（印在鍵帽上的字），標記 meta "glyph"，由 InputGlyphs 產生。
## 十字鍵焦點（D-057）：固定的格子不能聚焦（直接跳過）；最後一列往下是「還原預設／返回」；
## 焦點不會跑到後面的設定選單（Godot 走到邊緣時會往整個畫面找最近的按鈕，跑出去就拉回來）。

signal closed

const WAIT_TIMEOUT_SEC: float = 6.0
const LABEL_WIDTH: float = 360.0
const CELL_WIDTH: float = 250.0

var _list: VBoxContainer
var _reset: Button
var _back: Button
var _waiting_action: String = ""
var _waiting_slot: int = -1
var _armed: bool = false
var _wait_left: float = 0.0
var _last_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	set_process(false)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## 開著的時候焦點只能在這頁裡；跑到後面的選單就拉回上一個格子。
func _on_focus_changed(c: Control) -> void:
	if not visible:
		return
	if is_ancestor_of(c):
		_last_focus = c
		return
	if _last_focus != null and is_instance_valid(_last_focus) and _last_focus.is_inside_tree():
		_last_focus.grab_focus()


func open() -> void:
	show()
	_refresh()
	var first: Button = cell("move_forward", InputSetup.SLOT_KBM)
	if first != null:
		first.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	cancel_capture()
	Settings.save_settings()
	hide()
	closed.emit()


func is_waiting() -> bool:
	return _waiting_action != ""


## 開始等待新鍵。下一幀才開始收（避免把「按下這格」的那一下當成新鍵）。
func begin_capture(action: String, slot: int) -> void:
	if not InputSetup.is_rebindable(action, slot):
		return
	cancel_capture()
	_waiting_action = action
	_waiting_slot = slot
	_armed = false
	_wait_left = WAIT_TIMEOUT_SEC
	var b: Button = cell(action, slot)
	if b != null:
		b.text = tr("SET_CONTROLS_WAIT")
	set_process(true)
	get_tree().process_frame.connect(func() -> void: _armed = true, CONNECT_ONE_SHOT)


func cancel_capture() -> void:
	if not is_waiting():
		return
	_waiting_action = ""
	_waiting_slot = -1
	set_process(false)
	_refresh()


## 收到一個輸入事件（_input 與測試共用）。回傳是否吃掉這個事件。
func feed_capture(event: InputEvent) -> bool:
	if not is_waiting():
		return false
	if not _armed:
		return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if event.is_action_pressed("pause"):
		var b: Button = cell(_waiting_action, _waiting_slot)
		cancel_capture()
		if b != null:
			b.grab_focus()
		return true
	var spec: Vector2i = InputSetup.spec_from_event(event, _waiting_slot)
	if spec == InputSetup.NONE:
		# 別的裝置或放開：吃掉按鍵類事件，讓它不要觸發選單
		return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	var action: String = _waiting_action
	var slot: int = _waiting_slot
	_waiting_action = ""
	_waiting_slot = -1
	set_process(false)
	Settings.set_binding(action, slot, spec)
	_refresh()
	var target: Button = cell(action, slot)
	if target != null:
		target.grab_focus()
	return true


func _input(event: InputEvent) -> void:
	if visible and is_waiting() and feed_capture(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_waiting():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_wait_left -= delta
	if _wait_left <= 0.0:
		cancel_capture()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func reset_to_defaults() -> void:
	cancel_capture()
	Settings.reset_bindings()
	_refresh()


## 測試用：某動作某欄位的格子。
func cell(action: String, slot: int) -> Button:
	var row: Node = _list.get_node_or_null(action)
	if row == null:
		return null
	return row.get_child(1 + slot) as Button


func _refresh() -> void:
	for action: String in InputSetup.ACTION_KEYS:
		for slot: int in [InputSetup.SLOT_KBM, InputSetup.SLOT_PAD]:
			var b: Button = cell(action, slot)
			if b == null:
				continue
			b.text = InputGlyphs.label_for_spec(Settings.binding(action, slot))
			b.disabled = not InputSetup.is_rebindable(action, slot)
			b.tooltip_text = tr("SET_CONTROLS_FIXED") if b.disabled else ""
			# 固定的格子十字鍵直接跳過（滑鼠移上去仍看得到「固定」提示）
			b.focus_mode = Control.FOCUS_NONE if b.disabled else Control.FOCUS_ALL
	_link_edges()


## 邊緣的焦點鄰居：第一列往上不動、最後一列往下到底下的按鈕、按鈕往上回最後一列。
func _link_edges() -> void:
	var rows: Array[String] = []
	for action: String in InputSetup.ACTION_KEYS:
		var k: Button = cell(action, InputSetup.SLOT_KBM)
		var p: Button = cell(action, InputSetup.SLOT_PAD)
		if (k != null and not k.disabled) or (p != null and not p.disabled):
			rows.append(action)
	if rows.is_empty() or _reset == null or _back == null:
		return
	var first: String = rows[0]
	var last: String = rows[rows.size() - 1]
	var last_kbm: Button = cell(last, InputSetup.SLOT_KBM)
	var last_pad: Button = cell(last, InputSetup.SLOT_PAD)
	for slot: int in [InputSetup.SLOT_KBM, InputSetup.SLOT_PAD]:
		var top: Button = cell(first, slot)
		top.focus_neighbor_top = top.get_path_to(top)
		var bottom: Button = cell(last, slot)
		var below: Button = _reset if slot == InputSetup.SLOT_KBM else _back
		bottom.focus_neighbor_bottom = bottom.get_path_to(below)
	_reset.focus_neighbor_top = _reset.get_path_to(last_kbm if not last_kbm.disabled else last_pad)
	_back.focus_neighbor_top = _back.get_path_to(last_pad if not last_pad.disabled else last_kbm)
	for b: Button in [_reset, _back]:
		b.focus_neighbor_bottom = b.get_path_to(b)
	_reset.focus_neighbor_left = _reset.get_path_to(_reset)
	_reset.focus_neighbor_right = _reset.get_path_to(_back)
	_back.focus_neighbor_left = _back.get_path_to(_reset)
	_back.focus_neighbor_right = _back.get_path_to(_back)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.03, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.95)
	style.border_color = Color(0.55, 0.5, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "SET_CONTROLS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
	var serif: Font = UiFonts.load_font(UiFonts.TITLE_SERIF)
	if serif != null:
		title.add_theme_font_override("font", serif)
	box.add_child(title)

	var header := HBoxContainer.new()
	header.add_child(_label("", LABEL_WIDTH))
	header.add_child(_label("SET_CONTROLS_KBM", CELL_WIDTH))
	header.add_child(_label("SET_CONTROLS_PAD", CELL_WIDTH))
	box.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LABEL_WIDTH + CELL_WIDTH * 2 + 24, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	for action: String in InputSetup.ACTION_KEYS:
		var row := HBoxContainer.new()
		row.name = action
		var name_label: Label = _label(str(InputSetup.ACTION_KEYS[action]), LABEL_WIDTH)
		name_label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84))
		row.add_child(name_label)
		for slot: int in [InputSetup.SLOT_KBM, InputSetup.SLOT_PAD]:
			var b := Button.new()
			b.name = "Pad" if slot == InputSetup.SLOT_PAD else "Kbm"
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(CELL_WIDTH, 40)
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.set_meta("glyph", true)
			b.add_theme_color_override("font_color", Color(0.9, 0.84, 0.68))
			b.add_theme_color_override("font_disabled_color", Color(0.5, 0.52, 0.55))
			var a: String = action
			var s: int = slot
			b.pressed.connect(func() -> void: begin_capture(a, s))
			row.add_child(b)
		_list.add_child(row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	_reset = Button.new()
	_reset.name = "Reset"
	_reset.text = "SET_CONTROLS_RESET"
	_reset.flat = true
	_reset.custom_minimum_size = Vector2(220, 46)
	_reset.pressed.connect(reset_to_defaults)
	buttons.add_child(_reset)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "MENU_BACK"
	_back.flat = true
	_back.custom_minimum_size = Vector2(160, 46)
	_back.pressed.connect(close)
	buttons.add_child(_back)


func _label(key: String, width: float) -> Label:
	var l := Label.new()
	l.text = key
	l.custom_minimum_size = Vector2(width, 40)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
