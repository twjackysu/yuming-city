class_name PauseMenu
extends CanvasLayer
## 暫停選單：Esc／Start 暫停（get_tree().paused），繼續、設定、回標題。
## 暫停時釋放滑鼠，繼續時恢復原本的滑鼠模式。視窗失去焦點時自動暫停。

signal resumed

const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

var _root: Control
var _menu: VBoxContainer
var _resume: Button
var _settings: SettingsMenu
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


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
	_resume.grab_focus.call_deferred()


func resume() -> void:
	if not is_open():
		return
	_settings.hide()
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = _mouse_before
	resumed.emit()


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

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.position = Vector2(160, 330)
	_menu.add_theme_constant_override("separation", 10)
	_root.add_child(_menu)

	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSE_TITLE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
	var serif: Font = UiFonts.load_font(UiFonts.TITLE_SERIF)
	if serif != null:
		title.add_theme_font_override("font", serif)
	_menu.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	_menu.add_child(gap)

	_resume = _button("Resume", "MENU_RESUME", resume)
	_button("Settings", "MENU_SETTINGS", _open_settings)
	_button("BackToTitle", "MENU_BACK_TO_TITLE", _back_to_title)

	_settings = SETTINGS_SCENE.instantiate() as SettingsMenu
	_root.add_child(_settings)
	_settings.hide()
	_settings.closed.connect(_on_settings_closed)


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
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.back_to_title()
