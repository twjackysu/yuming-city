class_name SettingsMenu
extends Control
## 設定選單（標題畫面與暫停選單共用）。所有文字都是翻譯 key。
## 鍵鼠與手把都能操作：上下移動焦點，左右調滑桿／切換選項，確認鍵切換，取消鍵返回。
## 改值即時生效；關閉時存到 settings.cfg。

signal closed

const ROW_LABEL_WIDTH: float = 420.0
const CONTROL_WIDTH: float = 360.0
const VOLUME_KEYS: Dictionary = {
	"Master": "SET_MASTER_VOLUME",
	"Music": "SET_MUSIC_VOLUME",
	"SFX": "SET_SFX_VOLUME",
	"Voice": "SET_VOICE_VOLUME",
}
const LOCALE_KEYS: Dictionary = {"en": "LANG_EN", "zh_TW": "LANG_ZH_TW"}

var _rows: VBoxContainer
var _first_focus: Control
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visibility_changed.connect(_on_visibility_changed)


func open() -> void:
	show()
	_refresh_all()
	if _first_focus != null:
		_first_focus.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	set_process_unhandled_input(visible)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.03, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	style.border_color = Color(0.55, 0.5, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "MENU_SETTINGS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
	var serif: Font = UiFonts.load_font(UiFonts.TITLE_SERIF)
	if serif != null:
		title.add_theme_font_override("font", serif)
	box.add_child(title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)

	_add_cycler("MENU_LANGUAGE", "Language", Settings.SUPPORTED_LOCALES.size(),
		func() -> int: return Settings.SUPPORTED_LOCALES.find(Settings.locale),
		func(i: int) -> void: Settings.set_locale(Settings.SUPPORTED_LOCALES[i]),
		func(i: int) -> String: return str(LOCALE_KEYS[Settings.SUPPORTED_LOCALES[i]]))
	for bus: String in Settings.VOLUME_BUSES:
		_add_slider(str(VOLUME_KEYS[bus]), "Volume" + bus, bus)
	_add_toggle("SET_SUBTITLES", "Subtitles", "subtitles")
	_add_cycler("SET_QUALITY", "Quality", QualityPreset.NAME_KEYS.size(),
		func() -> int: return int(Settings.quality),
		func(i: int) -> void: Settings.set_quality(i),
		func(i: int) -> String: return QualityPreset.NAME_KEYS[i])
	_add_toggle("SET_FULLSCREEN", "Fullscreen", "fullscreen")
	_add_toggle("SET_VSYNC", "Vsync", "vsync")
	_add_toggle("SET_REDUCE_SHAKE", "ReduceShake", "reduce_camera_shake")

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "MENU_BACK"
	_back.flat = true
	_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_back.custom_minimum_size = Vector2(200, 48)
	_back.pressed.connect(close)
	box.add_child(_back)


func _row(label_key: String, row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	var label := Label.new()
	label.text = label_key
	label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, 44)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84))
	row.add_child(label)
	_rows.add_child(row)
	return row


func _remember_first(c: Control) -> void:
	if _first_focus == null:
		_first_focus = c


func _add_slider(label_key: String, row_name: String, bus: String) -> void:
	var row: HBoxContainer = _row(label_key, row_name)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(CONTROL_WIDTH, 44)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float) -> void: Settings.set_volume(bus, v))
	slider.set_meta("refresh", func() -> void: slider.set_value_no_signal(Settings.volume(bus)))
	row.add_child(slider)
	_remember_first(slider)


## 多選一：按確認鍵往下一個，左右鍵前後切換。
func _add_cycler(label_key: String, row_name: String, count: int, read_index: Callable, set_index: Callable, key_of: Callable) -> void:
	var row: HBoxContainer = _row(label_key, row_name)
	var button := Button.new()
	button.name = "Value"
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(CONTROL_WIDTH, 44)
	var refresh: Callable = func() -> void: button.text = str(key_of.call(int(read_index.call())))
	var step: Callable = func(delta: int) -> void:
		set_index.call(posmod(int(read_index.call()) + delta, count))
		_refresh_all()
	button.pressed.connect(func() -> void: step.call(1))
	button.gui_input.connect(func(e: InputEvent) -> void: _cycler_input(button, e, step))
	button.set_meta("refresh", refresh)
	row.add_child(button)
	_remember_first(button)


func _add_toggle(label_key: String, row_name: String, option: String) -> void:
	_add_cycler(label_key, row_name, 2,
		func() -> int: return 1 if Settings.get_option(option) else 0,
		func(i: int) -> void: Settings.set_option(option, i == 1),
		func(i: int) -> String: return "OPT_ON" if i == 1 else "OPT_OFF")


func _cycler_input(button: Button, e: InputEvent, step: Callable) -> void:
	if e.is_action_pressed("ui_left"):
		step.call(-1)
		button.accept_event()
	elif e.is_action_pressed("ui_right"):
		step.call(1)
		button.accept_event()


func _refresh_all() -> void:
	for row: Node in _rows.get_children():
		for c: Node in row.get_children():
			if c.has_meta("refresh"):
				(c.get_meta("refresh") as Callable).call()


## 測試用：依列名找到控制項（Slider 或 Value 按鈕）。
func control_of(row_name: String) -> Control:
	var row: Node = _rows.get_node_or_null(row_name)
	if row == null:
		return null
	return row.get_child(1) as Control
