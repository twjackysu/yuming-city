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
