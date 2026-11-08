class_name ValuePips
extends Control
## 設定頁多選一的值下面一排小圓點（D-076）：一共幾個選項就幾顆，目前那顆是實心暖金色，
## 其他是空心淡灰。讓玩家一眼看出「畫質：中」是三級裡的第二級。開／關不畫。

const SPACING: float = 11.0
const RADIUS: float = 2.2
## 圓點所在的那一條（按鈕最底下幾 px）；按鈕文字抬高 SettingsMenu.PIPS_LIFT 讓出空間
const STRIP: float = 8.0

var count: int = 1
var index: int = 0
var _button: Button


func _init(button: Button, option_count: int) -> void:
	_button = button
	count = maxi(option_count, 1)
	name = "Pips"
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -STRIP
	offset_bottom = 0.0
	for sig: Signal in [_button.focus_entered, _button.focus_exited, _button.mouse_entered, _button.mouse_exited]:
		sig.connect(queue_redraw)


## 第 i 顆的中心（以這個 Control 為座標）。
func center_of(i: int) -> Vector2:
	return Vector2(size.x * 0.5 + (float(i) - float(count - 1) * 0.5) * SPACING, size.y * 0.5)


func _draw() -> void:
	var lit: bool = _button.has_focus() or _button.is_hovered()
	for i: int in count:
		var c: Vector2 = center_of(i)
		if i == index:
			draw_circle(c, RADIUS, UiTheme.ACCENT if lit else Color(UiTheme.ACCENT, 0.75), true, -1.0, true)
		else:
			draw_circle(c, RADIUS - 0.4, Color(UiTheme.TEXT, 0.32), false, 1.0, true)
