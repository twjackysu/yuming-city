class_name DialogueBox
extends CanvasLayer
## 對話框（字幕）：畫面下方顯示說話者與台詞，逐字浮現；有選項時列出按鈕。
## 互動鍵（F／A）或確認鍵：字還在浮現時先顯示完整，否則下一句；按住互動鍵 0.6 秒：跳到下一個選項。
## 只聽 Game.dialogue_started；邏輯都在 DialogueRunner。

const CHARS_PER_SEC: float = 38.0
const HOLD_SKIP_SEC: float = 0.6

var runner: DialogueRunner
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _hint: Label
var _choices: VBoxContainer
var _reveal: Tween
var _hold: float = 0.0
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 20
	_build()
	_panel.hide()
	Game.dialogue_started.connect(attach)


func attach(r: DialogueRunner) -> void:
	runner = r
	r.line_shown.connect(_on_line)
	r.choices_shown.connect(_on_choices)
	r.finished.connect(_on_finished)
	_panel.show()
	var n: Dictionary = r.current()
	_on_line(str(n.get("speaker", "")), str(n.get("text", "")))
	if not r.visible_choices.is_empty():
		_on_choices(r.visible_choices)


func is_open() -> bool:
	return _panel.visible


func is_revealing() -> bool:
	return _text.visible_ratio < 1.0


## 互動鍵：先把字顯示完，再往下一句。
func press_continue() -> void:
	if runner == null or not runner.is_running():
		return
	if is_revealing():
		_finish_reveal()
		return
	if runner.visible_choices.is_empty():
		runner.advance()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		press_continue()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open() or runner == null:
		_hold = 0.0
		return
	if Input.is_action_pressed("interact") and runner.visible_choices.is_empty():
		_hold += delta
		if _hold >= HOLD_SKIP_SEC:
			_hold = 0.0
			runner.skip_to_choice()
			_finish_reveal()
	else:
		_hold = 0.0


func _on_line(speaker_key: String, text_key: String) -> void:
	_clear_choices()
	_speaker.text = speaker_key
	_text.text = text_key
	_hint.visible = true
	if _reveal != null:
		_reveal.kill()
	_text.visible_ratio = 0.0
	var length: int = tr(text_key).length()
	_reveal = create_tween()
	_reveal.tween_property(_text, "visible_ratio", 1.0, maxf(length / CHARS_PER_SEC, 0.15))


func _finish_reveal() -> void:
	if _reveal != null:
		_reveal.kill()
	_text.visible_ratio = 1.0


func _on_choices(choices: Array[Dictionary]) -> void:
	_clear_choices()
	_hint.visible = false
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var i: int = 0
	for c: Dictionary in choices:
		var b := Button.new()
		b.text = str(c["text"])
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_color_override("font_color", Color(0.86, 0.8, 0.66))
		b.add_theme_font_size_override("font_size", 24)
		var index: int = i
		b.pressed.connect(func() -> void: _choose(index))
		_choices.add_child(b)
		i += 1
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus.call_deferred()


func _choose(index: int) -> void:
	Input.mouse_mode = _mouse_before
	_clear_choices()
	runner.choose(index)


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _on_finished(_id: String) -> void:
	_panel.hide()
	_clear_choices()
	runner = null


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.035, 0.82)
	style.border_color = Color(0.55, 0.5, 0.4, 0.35)
	style.border_width_top = 1
	style.set_content_margin_all(24)
	style.content_margin_left = 40
	style.content_margin_right = 40
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	_panel.anchor_left = 0.18
	_panel.anchor_right = 0.82
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -250
	_panel.offset_bottom = -48
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.add_theme_font_size_override("font_size", 20)
	_speaker.add_theme_color_override("font_color", Color(0.85, 0.7, 0.45))
	box.add_child(_speaker)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 28)
	_text.add_theme_color_override("font_color", Color(0.94, 0.93, 0.9))
	box.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	box.add_child(_choices)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = "HUD_DLG_HINT"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66, 0.8))
	box.add_child(_hint)
