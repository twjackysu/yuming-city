class_name PotionConfirm
extends Control
## 滿血時按「使用道具」的小確認框（D-209，09 第 5 節）：「現在滿血，看不出效果。還是要喝嗎？」＋「喝」／「先收著」。
## 不強迫自殘、也不浪費：預設停在「先收著」，Esc／B／暫停鍵＝先收著。
## 開著的時候遊戲暫停（get_tree().paused）：敵人不會趁機打人、身上狀態的秒數也不走。選完發 decided(drink)。

signal decided(drink: bool)

var _panel: PanelContainer
var _drink: Button
var _keep: Button
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _paused_before: bool = false
var _open: bool = false


func _ready() -> void:
	name = "PotionConfirm"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.38)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	sb.border_color = Color(0.42, 0.75, 0.42, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 24
	sb.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_panel.add_child(col)
	var ask := Label.new()
	ask.name = "Ask"
	ask.text = "RB_POTION_FULL_ASK"
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.custom_minimum_size = Vector2(520, 0)
	ask.add_theme_font_size_override("font_size", 24)
	ask.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	col.add_child(ask)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	col.add_child(row)
	_drink = _button("Drink", "RB_POTION_DRINK", true)
	row.add_child(_drink)
	_keep = _button("Keep", "RB_POTION_KEEP", false)
	row.add_child(_keep)
	visible = false


func _button(node_name: String, key: String, drink: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = key
	b.flat = true
	b.custom_minimum_size = Vector2(170, 44)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.86, 0.8, 0.66))
	b.pressed.connect(func() -> void: choose(drink))
	return b


func is_open() -> bool:
	return _open


func open() -> void:
	if _open or not is_inside_tree():
		return
	_open = true
	visible = true
	_paused_before = get_tree().paused
	get_tree().paused = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_keep.grab_focus.call_deferred()


## drink＝喝；false＝先收著。（測試也用）
func choose(drink: bool) -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = _paused_before
	Input.mouse_mode = _mouse_before
	decided.emit(drink)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		choose(false)


func _exit_tree() -> void:
	# 關卡在確認框開著時被換掉（回標題、重來）：不要把遊戲留在暫停
	if _open:
		_open = false
		get_tree().paused = _paused_before
