class_name CutsceneView
extends CanvasLayer
## 過場的畫面：上下黑邊、字幕、等待輸入時的提示（[F] 敲鐘 3／9）、右下「按住 [F] 跳過」與進度條。
## 鏡頭：在目前場景找 shot.camera 同名節點（Marker3D），把自己的 Camera3D 移過去；結束時還給原本的鏡頭。
## 只聽 Game.cutscene_started；邏輯都在 CutsceneRunner。等待輸入的鏡頭按一下互動鍵觸發，按住 1 秒跳過整段。

const HOLD_SKIP_SEC: float = 1.0
const BAR_HEIGHT: float = 0.11  # 畫面高度比例
const SHAKE_DECAY: float = 2.5

var runner: CutsceneRunner
var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _speaker: Label
var _line: Label
var _prompt: GlyphLine
var _skip: GlyphLine
var _skip_bar: ProgressBar
var _camera: Camera3D
var _previous_camera: Camera3D
var _hold := HoldToSkip.new(HOLD_SKIP_SEC)
var _shake: float = 0.0
var _base_transform: Transform3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 15
	_build()
	_root.hide()
	Game.cutscene_started.connect(attach)
	Game.cutscene_ended.connect(_on_ended)
	App.device_changed.connect(_on_device_changed)


func attach(r: CutsceneRunner) -> void:
	runner = r
	r.shot_started.connect(_on_shot)
	r.event_fired.connect(_on_event)
	_root.show()
	_hold.reset()
	_refresh_texts()
	_ensure_camera()


func is_open() -> bool:
	return _root.visible


func prompt_text() -> String:
	return _prompt.plain_text() if _prompt.visible else ""


func skip_text() -> String:
	return _skip.plain_text()


func prompt_line() -> GlyphLine:
	return _prompt


func skip_line() -> GlyphLine:
	return _skip


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or runner == null or not runner.is_running():
		return
	if event.is_action_pressed("interact"):
		runner.press("interact")
		get_viewport().set_input_as_handled()
	elif runner.is_waiting() and event.is_action_pressed(runner.awaited_action()):
		runner.press(runner.awaited_action())
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open() or runner == null:
		return
	if _hold.update(Input.is_action_pressed("interact"), delta):
		runner.skip()
		return
	_skip_bar.value = _hold.progress()
	if _camera != null and _shake > 0.0:
		_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
		var amount: float = _shake * _shake * (0.25 if Settings.reduce_camera_shake else 1.0)
		_camera.global_transform = _base_transform.rotated_local(Vector3.FORWARD, _rng.randf_range(-1, 1) * 0.02 * amount)
		_camera.global_position = _base_transform.origin + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * 0.08 * amount


func _on_shot(_index: int, shot: Dictionary) -> void:
	_speaker.text = str(shot.get("speaker", ""))
	_line.text = str(shot.get("line", ""))
	_refresh_texts()
	_move_camera(str(shot.get("camera", "")))
	if not shot.has("await"):
		_shake = maxf(_shake, float(shot.get("shake", 0.0)))


func _on_event(_event: String, shot: Dictionary) -> void:
	_shake = maxf(_shake, float(shot.get("shake", 0.0)))
	_refresh_texts()


func _on_device_changed(_device: int) -> void:
	_refresh_texts()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _skip != null:
		_refresh_texts()


## 提示與跳過文字含目前裝置的鍵名，所以不是翻譯 key（標記 meta "glyph"）。
func _refresh_texts() -> void:
	_skip.set_line(tr("HUD_CUTSCENE_SKIP"), "interact", int(App.last_device))
	_prompt.visible = runner != null and runner.is_waiting()
	if not _prompt.visible:
		return
	var shot: Dictionary = runner.current()
	var text: String = "{key}  %s" % tr(str(shot.get("prompt", "")))
	if shot.has("counter"):
		var n: int = int(Game.session.state.get_flag(str(shot["counter"]), 0))
		text += "　%d／%d" % [n, int(shot.get("counter_max", 0))]
	_prompt.set_line(text, runner.awaited_action(), int(App.last_device))


func _ensure_camera() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not scene is Node3D:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = Camera3D.new()
		_camera.name = "CutsceneCamera"
		_camera.fov = 50.0
		scene.add_child(_camera)
	_previous_camera = get_viewport().get_camera_3d()


func _move_camera(marker_name: String) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var scene: Node = get_tree().current_scene
	var marker: Node3D = scene.find_child(marker_name, true, false) as Node3D if scene != null else null
	if marker == null:
		return
	_base_transform = marker.global_transform
	_camera.global_transform = _base_transform
	_camera.make_current()


func _on_ended(_id: String, _skipped: bool) -> void:
	_root.hide()
	_shake = 0.0
	runner = null
	if _previous_camera != null and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	if _camera != null and is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_top = _bar(0.0, BAR_HEIGHT)
	_bottom = _bar(1.0 - BAR_HEIGHT, 1.0)

	var box := VBoxContainer.new()
	box.anchor_left = 0.2
	box.anchor_right = 0.8
	box.anchor_top = 1.0 - BAR_HEIGHT - 0.16
	box.anchor_bottom = 1.0 - BAR_HEIGHT - 0.02
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_speaker = _label("Speaker", 20, Color(0.85, 0.7, 0.45))
	box.add_child(_speaker)
	_line = _label("Line", 30, Color(0.95, 0.94, 0.9))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_constant_override("outline_size", 6)
	_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	box.add_child(_line)

	# 鍵名用 GlyphLine：手把模式顯示按鈕圖示（D-063）
	_prompt = GlyphLine.new().configure(26, Color(0.95, 0.82, 0.55))
	_prompt.name = "Prompt"
	_prompt.fit_content = false
	_prompt.anchor_left = 0.3
	_prompt.anchor_right = 0.7
	_prompt.anchor_top = 0.66
	_prompt.anchor_bottom = 0.71
	_root.add_child(_prompt)

	_skip = GlyphLine.new().configure(16, Color(0.62, 0.64, 0.68, 0.85))
	_skip.name = "Skip"
	_skip.fit_content = false
	_skip.alignment = BoxContainer.ALIGNMENT_END
	_skip.anchor_left = 0.6
	_skip.anchor_right = 0.97
	_skip.anchor_top = 1.0 - BAR_HEIGHT * 0.7
	_skip.anchor_bottom = 1.0 - BAR_HEIGHT * 0.35
	_root.add_child(_skip)
	_skip_bar = ProgressBar.new()
	_skip_bar.name = "SkipBar"
	_skip_bar.show_percentage = false
	_skip_bar.max_value = 1.0
	_skip_bar.anchor_left = 0.85
	_skip_bar.anchor_right = 0.97
	_skip_bar.anchor_top = 1.0 - BAR_HEIGHT * 0.3
	_skip_bar.anchor_bottom = 1.0 - BAR_HEIGHT * 0.25
	_skip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.7, 0.45, 0.9)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	_skip_bar.add_theme_stylebox_override("fill", fill)
	_skip_bar.add_theme_stylebox_override("background", bg)
	_root.add_child(_skip_bar)


func _bar(top: float, bottom: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = top
	r.anchor_bottom = bottom
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r


func _label(node_name: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
