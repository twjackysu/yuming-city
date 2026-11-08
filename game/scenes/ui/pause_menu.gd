class_name PauseMenu
extends CanvasLayer
## 暫停選單：Esc／Start 暫停（get_tree().paused），繼續、設定、回標題。
## 暫停時釋放滑鼠，繼續時恢復原本的滑鼠模式。視窗失去焦點時自動暫停。

signal resumed

const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")
## 暫停時藏起來的 CanvasLayer（HUD：目標已經寫在暫停選單左下角，隔著暗幕再看到一次是重複的）
const HIDE_GROUP: StringName = &"hide_when_paused"

var _root: Control
var _menu: VBoxContainer
var _resume: Button
var _settings: SettingsMenu
## 左下：目前目標（暫停時 HUD 被暗幕蓋住，這裡再寫一次）＋按鍵提示（D-093）
var _objective_box: VBoxContainer
var _objective: Label
var _hint: GlyphLine
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
## 這次暫停藏起來的圖層（繼續時只恢復這些；本來就藏著的維持原狀）
var _hidden: Array[CanvasLayer] = []


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	# 截圖用：`-- --open=pause`／`--open=settings`
	var open_arg: String = str(App.parse_user_args(OS.get_cmdline_user_args()).get("open", ""))
	if open_arg == "pause" or open_arg == "settings":
		_open_for_screenshot.call_deferred(open_arg)


func _open_for_screenshot(what: String) -> void:
	open()
	if what == "settings":
		_open_settings()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.show()
	_menu.show()
	_settings.hide()
	_hide_layers()
	_refresh_info()
	_resume.grab_focus.call_deferred()


## 目前目標與按鍵提示（每次打開時更新；裝置換了也更新提示）。
func _refresh_info() -> void:
	var key: String = Game.session.objective_key() if Game.session != null else ""
	_objective.text = key
	_objective_box.visible = key != ""
	_hint.set_line(tr("PAUSE_HINT_RESUME"), "pause", int(App.last_device))


func objective_text() -> String:
	return _objective.text if _objective_box.visible else ""


func hint_text() -> String:
	return _hint.plain_text()


func _on_device_changed(_device: int) -> void:
	if is_open():
		_refresh_info()


func resume() -> void:
	if not is_open():
		return
	_settings.hide()
	_root.hide()
	_restore_layers()
	get_tree().paused = false
	Input.mouse_mode = _mouse_before
	resumed.emit()


func _hide_layers() -> void:
	_hidden.clear()
	for n: Node in get_tree().get_nodes_in_group(HIDE_GROUP):
		var cl: CanvasLayer = n as CanvasLayer
		if cl != null and cl.visible:
			cl.visible = false
			_hidden.append(cl)


func _restore_layers() -> void:
	for cl: CanvasLayer in _hidden:
		if is_instance_valid(cl):
			cl.visible = true
	_hidden.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") and not (is_open() and event.is_action_pressed("ui_cancel")):
		return
	if _settings.visible:
		return  # 設定選單自己處理返回
	if is_open():
		resume()
	else:
		open()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and not is_open():
		if DisplayServer.get_name() != "headless":
			open()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.025, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	# 左側一條由深到透明的直向暗帶（第二輪盤點第 5 項，D-090）：選單有個「底」，右邊的場景照舊看得到
	var band := TextureRect.new()
	band.name = "Band"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.015, 0.03, 0.82))
	grad.set_color(1, Color(0.01, 0.015, 0.03, 0.0))
	grad.add_point(0.55, Color(0.01, 0.015, 0.03, 0.6))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 4
	band.texture = tex
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.anchor_bottom = 1.0
	band.offset_right = 760.0
	_root.add_child(band)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.position = Vector2(160, 330)
	_menu.add_theme_constant_override("separation", 10)
	_root.add_child(_menu)

	# 標題上方一行小字：章節名（霜橋鎮的第九聲鐘），淡藍灰、字距拉開
	var chapter := Label.new()
	chapter.name = "Chapter"
	chapter.text = "GAME_SUBTITLE"
	chapter.add_theme_font_size_override("font_size", 18)
	chapter.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78, 0.85))
	_menu.add_child(chapter)
	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSE_TITLE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
	var serif: Font = UiFonts.load_font(UiFonts.TITLE_SERIF)
	if serif != null:
		title.add_theme_font_override("font", serif)
	_menu.add_child(title)
	# 標題下一條暖金細線（跟設定頁的分組線同一個語彙，D-076），左邊實、往右淡出
	var rule := TextureRect.new()
	rule.name = "Rule"
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rg := Gradient.new()
	rg.set_color(0, Color(0.95, 0.78, 0.5, 0.85))
	rg.set_color(1, Color(0.95, 0.78, 0.5, 0.0))
	var rt := GradientTexture2D.new()
	rt.gradient = rg
	rt.width = 128
	rt.height = 2
	rule.texture = rt
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.custom_minimum_size = Vector2(320, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_menu.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	_menu.add_child(gap)

	_resume = _button("Resume", "MENU_RESUME", resume)
	_button("Settings", "MENU_SETTINGS", _open_settings)
	_button("BackToTitle", "MENU_BACK_TO_TITLE", _back_to_title)

	_build_info()

	_settings = SETTINGS_SCENE.instantiate() as SettingsMenu
	_root.add_child(_settings)
	_settings.hide()
	_settings.closed.connect(_on_settings_closed)


## 左下角：「目標」小標題（暖金色）＋目前目標一行，最底下一行「[Esc] 繼續遊戲」。
func _build_info() -> void:
	_objective_box = VBoxContainer.new()
	_objective_box.name = "Objective"
	_objective_box.add_theme_constant_override("separation", 6)
	_objective_box.anchor_top = 1.0
	_objective_box.anchor_bottom = 1.0
	_objective_box.offset_left = 164.0
	_objective_box.offset_top = -230.0
	_objective_box.offset_right = 164.0 + 520.0
	_objective_box.offset_bottom = -110.0
	_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_objective_box)
	var head := Label.new()
	head.name = "Head"
	head.text = "HUD_OBJECTIVE"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.95, 0.78, 0.5, 0.9))
	_objective_box.add_child(head)
	_objective = Label.new()
	_objective.name = "Text"
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(520, 0)
	_objective.add_theme_font_size_override("font_size", 24)
	_objective.add_theme_color_override("font_color", Color(0.9, 0.89, 0.86))
	_objective_box.add_child(_objective)

	_hint = GlyphLine.new().configure(18, Color(0.62, 0.64, 0.68, 0.85))
	_hint.name = "Hint"
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 164.0
	_hint.offset_top = -78.0
	_hint.offset_bottom = -46.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)
	App.device_changed.connect(_on_device_changed)


func _button(node_name: String, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = key
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(360, 52)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(action)
	_menu.add_child(b)
	return b


func _open_settings() -> void:
	_menu.hide()
	_settings.open()


func _on_settings_closed() -> void:
	_menu.show()
	(_menu.get_node("Settings") as Button).grab_focus.call_deferred()


func _back_to_title() -> void:
	_root.hide()
	_hidden.clear()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.back_to_title()
