class_name ValueArrow
extends Control
## 設定頁多選一兩側的箭頭（D-076）。用線畫的「‹」「›」，不靠字型（子集字型不一定有這兩個字）。
## 平常是淡淡的冷灰白，按鈕有焦點或滑鼠移上去時變暖金色；點一下發出 stepped(dir)，
## 切換時往那個方向輕輕彈一下（kick）。放在按鈕裡面（左右兩側），按鈕本身照常拿焦點。

signal stepped(dir: int)

const HALF_HEIGHT: float = 6.5
const DEPTH: float = 5.0
const KICK_DISTANCE: float = 4.0

var dir: int = 1
## 往上抬幾 px（有小圓點的按鈕文字抬高了，箭頭跟著抬，中心對齊文字）
var lift: float = 0.0
var _button: Button
var _hover: bool = false
var _kick: float = 0.0
var _tween: Tween


func _init(button: Button, direction: int, lift_px: float = 0.0) -> void:
	_button = button
	dir = 1 if direction > 0 else -1
	lift = lift_px
	name = "Next" if dir > 0 else "Prev"
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	if dir < 0:
		set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		offset_left = SettingsMenu.ARROW_INSET
		offset_right = SettingsMenu.ARROW_INSET + SettingsMenu.ARROW_WIDTH
	else:
		set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		offset_left = -SettingsMenu.ARROW_INSET - SettingsMenu.ARROW_WIDTH
		offset_right = -SettingsMenu.ARROW_INSET
	offset_top = -lift
	offset_bottom = -lift
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	for sig: Signal in [_button.focus_entered, _button.focus_exited, _button.mouse_entered, _button.mouse_exited]:
		sig.connect(queue_redraw)


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


## 按鈕有焦點、滑鼠在按鈕或箭頭上：亮起來。
func is_lit() -> bool:
	return _hover or _button.has_focus() or _button.is_hovered()


func color() -> Color:
	return UiTheme.ACCENT if is_lit() else Color(UiTheme.TEXT, 0.4)


func kick() -> void:
	if not is_inside_tree():
		return
	if _tween != null:
		_tween.kill()
	_kick = 1.0
	_tween = create_tween()
	_tween.tween_method(_set_kick, 1.0, 0.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_kick(v: float) -> void:
	_kick = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_button.grab_focus()
		stepped.emit(dir)
		accept_event()


## 箭頭三個點（尖端朝 dir 方向），測試也用來確認方向。
func points() -> PackedVector2Array:
	var c: Vector2 = size * 0.5 + Vector2(dir * _kick * KICK_DISTANCE, 0.0)
	var back: float = -dir * DEPTH * 0.5
	var tip: float = dir * DEPTH * 0.5
	return PackedVector2Array([
		c + Vector2(back, -HALF_HEIGHT),
		c + Vector2(tip, 0.0),
		c + Vector2(back, HALF_HEIGHT),
	])


func _draw() -> void:
	draw_polyline(points(), color(), 2.0, true)
