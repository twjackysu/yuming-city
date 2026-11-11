class_name InteractPrompt
extends Control
## 互動提示（HUD，D-065）：救援「按住 A　搬開瓦礫」、倒下的席菈「A 拉起席菈」這類「走近就能做」的提示，
## 從場景裡的 Label3D 搬到畫面下方中央，鍵名用 GlyphLine（手把模式是按鈕圖示，D-063）。
## 來源：`interact_prompts` 群組裡的節點，實作 `interact_hint() -> Dictionary`：
##   {} ＝不顯示；{"fmt": 已翻譯、保留 {key} 的字串, "action": InputMap 動作, "progress": 0..1 按住進度（-1＝沒有進度條）}
## 純顯示：每幀讀，不改任何東西。

const FADE_SPEED: float = 8.0
const BOTTOM_GAP: float = 150.0
const INK: Color = Color(0.95, 0.92, 0.86)
const FILL: Color = Color(0.98, 0.82, 0.55)
const BAR_W: float = 140.0
const BAR_H: float = 4.0

var progress: float = -1.0

var _panel: PanelContainer
var _line: GlyphLine
var _bar: Control
var _alpha: float = 0.0
var _shown: bool = false


func _ready() -> void:
	name = "InteractPrompt"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.62)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_line = GlyphLine.new().configure(22, INK)
	_line.name = "Hint"
	row.add_child(_line)
	_bar = Control.new()
	_bar.name = "HoldBar"
	_bar.custom_minimum_size = Vector2(BAR_W, 18)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	row.add_child(_bar)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	refresh(delta)


## 讀場景裡的提示來源，更新文字與版面。delta = 0 時直接到位（測試用）。
func refresh(delta: float) -> void:
	var hint: Dictionary = _active_hint()
	_shown = not hint.is_empty()
	if _shown:
		_line.set_line(str(hint.get("fmt", "")), str(hint.get("action", "interact")), App.last_device)
		progress = float(hint.get("progress", -1.0))
		_bar.visible = progress >= 0.0
		_bar.queue_redraw()
		_place()
	var target: float = 1.0 if _shown else 0.0
	_alpha = move_toward(_alpha, target, delta * FADE_SPEED) if delta > 0.0 else target
	modulate.a = _alpha
	visible = _alpha > 0.001


func _active_hint() -> Dictionary:
	if not is_inside_tree() or Game.is_player_locked():
		return {}
	for n: Node in get_tree().get_nodes_in_group("interact_prompts"):
		if n.has_method("interact_hint"):
			var h: Variant = n.call("interact_hint")
			if h is Dictionary and not (h as Dictionary).is_empty():
				return h as Dictionary
	return {}


func is_shown() -> bool:
	return _shown


func line() -> GlyphLine:
	return _line


## 文字版（測試、讀屏）。
func text() -> String:
	return _line.plain_text() if _shown else ""


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


func _place() -> void:
	var sz: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = sz
	var bottom: float = size.y - BOTTOM_GAP
	_panel.position = Vector2((size.x - sz.x) * 0.5, bottom - sz.y)


func _draw_bar() -> void:
	var y: float = (_bar.size.y - BAR_H) * 0.5
	_bar.draw_rect(Rect2(0, y, BAR_W, BAR_H), Color(1, 1, 1, 0.16))
	if progress > 0.0:
		_bar.draw_rect(Rect2(0, y, BAR_W * clampf(progress, 0.0, 1.0), BAR_H), FILL)
