class_name SettingsMenu
extends Control
## 設定選單（標題畫面與暫停選單共用）。所有文字都是翻譯 key。
## 鍵鼠與手把都能操作：上下移動焦點，左右調滑桿／切換選項，確認鍵切換，取消鍵返回。
## 改值即時生效；關閉時存到 settings.cfg。
## 分成四組（遊戲／聲音／畫面／操作，D-076）；多選一的值顯示成「‹ 值 ›」：兩側箭頭用程式畫
## （不靠字型），滑鼠點箭頭、十字鍵左右都能切，值下面的小圓點標出目前是第幾個；音量旁邊顯示百分比。

signal closed

const ROW_LABEL_WIDTH: float = 400.0
const CONTROL_WIDTH: float = 360.0
const ROW_HEIGHT: float = 38.0
## 音量百分比那一格的寬度（滑桿寬度＝CONTROL_WIDTH 減掉這格）
const PERCENT_WIDTH: float = 62.0
## 箭頭可點的寬度、離按鈕左右邊的距離（左邊讓出焦點細條）
const ARROW_WIDTH: float = 34.0
const ARROW_INSET: float = 8.0
## 有小圓點的按鈕：文字（與箭頭）往上抬幾 px，讓出底下放圓點的空間
const PIPS_LIFT: float = 3.0
const GROUP_COLOR: Color = Color(0.86, 0.72, 0.48)
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
var _controls: ControlsMenu


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
	if is_controls_open():
		_controls.close()
	Settings.save_settings()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_controls_open():
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
	style.content_margin_top = 30.0
	style.content_margin_bottom = 26.0
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
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)

	_add_group("SET_GROUP_GAME", "Game")
	_add_cycler("SET_DIFFICULTY", "Difficulty", Settings.DIFFICULTIES.size(),
		func() -> int: return Settings.DIFFICULTIES.find(Settings.difficulty),
		func(i: int) -> void: Settings.set_difficulty(Settings.DIFFICULTIES[i]),
		func(i: int) -> String: return Settings.DIFFICULTY_KEYS[i])
	_add_cycler("MENU_LANGUAGE", "Language", Settings.SUPPORTED_LOCALES.size(),
		func() -> int: return Settings.SUPPORTED_LOCALES.find(Settings.locale),
		func(i: int) -> void: Settings.set_locale(Settings.SUPPORTED_LOCALES[i]),
		func(i: int) -> String: return str(LOCALE_KEYS[Settings.SUPPORTED_LOCALES[i]]))
	_add_toggle("SET_SUBTITLES", "Subtitles", "subtitles")
	_add_toggle("SET_OBJECTIVE_MARKER", "ObjectiveMarker", "objective_marker")
	_add_toggle("SET_OBSERVE_CUE", "ObserveCue", "observe_cue")

	_add_group("SET_GROUP_AUDIO", "Audio")
	for bus: String in Settings.VOLUME_BUSES:
		_add_slider(str(VOLUME_KEYS[bus]), "Volume" + bus, bus)

	_add_group("SET_GROUP_DISPLAY", "Display")
	_add_cycler("SET_QUALITY", "Quality", QualityPreset.NAME_KEYS.size(),
		func() -> int: return int(Settings.quality),
		func(i: int) -> void: Settings.set_quality(i),
		func(i: int) -> String: return QualityPreset.NAME_KEYS[i])
	_add_toggle("SET_FULLSCREEN", "Fullscreen", "fullscreen")
	_add_toggle("SET_VSYNC", "Vsync", "vsync")
	_add_toggle("SET_REDUCE_SHAKE", "ReduceShake", "reduce_camera_shake")

	_add_group("SET_GROUP_INPUT", "Input")
	_add_controls_row()

	_back = Button.new()
	_back.name = "Back"
	_back.text = "MENU_BACK"
	_back.flat = true
	_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_back.custom_minimum_size = Vector2(200, 44)
	_back.pressed.connect(close)
	box.add_child(_back)

	_controls = ControlsMenu.new()
	_controls.name = "ControlsMenu"
	add_child(_controls)
	_controls.closed.connect(_on_controls_closed)


func is_controls_open() -> bool:
	return _controls != null and _controls.visible


func open_controls() -> void:
	_controls.open()


func _on_controls_closed() -> void:
	_focus_controls_row.call_deferred()


func _focus_controls_row() -> void:
	var b: Control = control_of("Controls")
	if visible and b != null and b.is_inside_tree():
		b.grab_focus()


func _add_controls_row() -> void:
	var row: HBoxContainer = _row("SET_CONTROLS", "Controls")
	var button := Button.new()
	button.name = "Value"
	button.text = "SET_CONTROLS_OPEN"
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(CONTROL_WIDTH, ROW_HEIGHT)
	button.pressed.connect(open_controls)
	row.add_child(button)


## 分組標題：暖金色小字＋往右延伸的一條細線；不是第一組時上面多留一點空。
func _add_group(label_key: String, group_name: String) -> void:
	if _rows.get_child_count() > 0:
		var gap := Control.new()
		gap.name = "Gap" + group_name
		gap.custom_minimum_size = Vector2(0, 10)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(gap)
	var head := HBoxContainer.new()
	head.name = "Group" + group_name
	head.add_theme_constant_override("separation", 16)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = "Heading"
	label.text = label_key
	label.uppercase = true
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", GROUP_COLOR)
	var medium: Font = UiFonts.load_font(UiFonts.UI_SANS_MEDIUM)
	if medium != null:
		label.add_theme_font_override("font", medium)
	head.add_child(label)
	var line := ColorRect.new()
	line.name = "Rule"
	line.color = Color(GROUP_COLOR, 0.28)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(line)
	_rows.add_child(head)


## 測試用：分組標題的翻譯 key（照畫面上由上到下）。
func group_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for c: Node in _rows.get_children():
		if c.name.begins_with("Group"):
			keys.append((c.get_node("Heading") as Label).text)
	return keys


## 測試用：某一列在哪一組底下（回傳組名，例如 "Audio"）。
func group_of(row_name: String) -> String:
	var current: String = ""
	for c: Node in _rows.get_children():
		if c.name.begins_with("Group"):
			current = str(c.name).trim_prefix("Group")
		elif c.name == row_name:
			return current
	return ""


func _row(label_key: String, row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	var label := Label.new()
	label.text = label_key
	label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, ROW_HEIGHT)
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
	slider.custom_minimum_size = Vector2(CONTROL_WIDTH - PERCENT_WIDTH, ROW_HEIGHT)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := Label.new()
	pct.name = "Percent"
	pct.set_meta("glyph", true)  # 數字，不是翻譯 key
	pct.custom_minimum_size = Vector2(PERCENT_WIDTH, ROW_HEIGHT)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.add_theme_font_size_override("font_size", 19)
	pct.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.7))
	var show_pct: Callable = func(v: float) -> void: pct.text = "%d%%" % roundi(v * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_volume(bus, v)
		show_pct.call(v)
		tick())
	slider.set_meta("refresh", func() -> void:
		slider.set_value_no_signal(Settings.volume(bus))
		show_pct.call(Settings.volume(bus)))
	row.add_child(slider)
	row.add_child(pct)
	_remember_first(slider)


## 多選一：「‹ 值 ›」。按確認鍵往下一個，左右鍵／點兩側箭頭前後切換；pips＝值下面標出第幾個的小圓點
## （開／關不畫）。
func _add_cycler(label_key: String, row_name: String, count: int, read_index: Callable, set_index: Callable, key_of: Callable, pips: bool = true) -> void:
	var row: HBoxContainer = _row(label_key, row_name)
	var button := Button.new()
	button.name = "Value"
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(CONTROL_WIDTH, ROW_HEIGHT)
	var lift: float = PIPS_LIFT if pips else 0.0
	var prev := ValueArrow.new(button, -1, lift)
	var next := ValueArrow.new(button, 1, lift)
	var dots: ValuePips = ValuePips.new(button, count) if pips else null
	if pips:
		var raised: StyleBoxEmpty = _raised_box()
		for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			button.add_theme_stylebox_override(state, raised)
	var refresh: Callable = func() -> void:
		var i: int = int(read_index.call())
		button.text = str(key_of.call(i))
		if dots != null:
			dots.index = i
			dots.queue_redraw()
	var step: Callable = func(delta: int) -> void:
		set_index.call(posmod(int(read_index.call()) + delta, count))
		(next if delta > 0 else prev).kick()
		tick()
		_refresh_all()
	prev.stepped.connect(step)
	next.stepped.connect(step)
	button.pressed.connect(func() -> void: step.call(1))
	button.gui_input.connect(func(e: InputEvent) -> void: _cycler_input(button, e, step))
	button.set_meta("refresh", refresh)
	row.add_child(button)
	button.add_child(prev)
	button.add_child(next)
	if dots != null:
		button.add_child(dots)
	_remember_first(button)


var _raised: StyleBoxEmpty
## 上一次「叮」的時間（拖滑桿時每 70 ms 最多一聲）
var _last_tick_ms: int = -1000
## 測試用：響過幾聲
var ticks: int = 0
const TICK_GAP_MS: int = 70
const TICK_DB: float = -15.0


## 換值時一聲很小的「叮」（ui_tick，走 SFX 匯流排，所以調音效音量時馬上聽得到新的大小）。
func tick() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_tick_ms < TICK_GAP_MS:
		return
	_last_tick_ms = now
	ticks += 1
	Sfx.play_flat(self, "ui_tick", TICK_DB)


## 跟 UiTheme 的按鈕框一樣，只是上下邊距不對稱（文字抬高 PIPS_LIFT）。
func _raised_box() -> StyleBoxEmpty:
	if _raised == null:
		_raised = StyleBoxEmpty.new()
		_raised.content_margin_left = UiTheme.PAD_LEFT
		_raised.content_margin_right = 10.0
		_raised.content_margin_top = 4.0 - PIPS_LIFT
		_raised.content_margin_bottom = 4.0 + PIPS_LIFT
	return _raised


func _add_toggle(label_key: String, row_name: String, option: String) -> void:
	_add_cycler(label_key, row_name, 2,
		func() -> int: return 1 if Settings.get_option(option) else 0,
		func(i: int) -> void: Settings.set_option(option, i == 1),
		func(i: int) -> String: return "OPT_ON" if i == 1 else "OPT_OFF", false)


func _cycler_input(button: Button, e: InputEvent, step: Callable) -> void:
	if e.is_action_pressed("ui_left"):
		step.call(-1)
		button.accept_event()
	elif e.is_action_pressed("ui_right"):
		step.call(1)
		button.accept_event()


## 測試用：多選一那一列的左（-1）或右（1）箭頭。
func arrow_of(row_name: String, dir: int) -> ValueArrow:
	var c: Control = control_of(row_name)
	if c == null:
		return null
	return c.get_node_or_null("Next" if dir > 0 else "Prev") as ValueArrow


## 測試用：多選一那一列的小圓點（開／關沒有）。
func pips_of(row_name: String) -> ValuePips:
	var c: Control = control_of(row_name)
	if c == null:
		return null
	return c.get_node_or_null("Pips") as ValuePips


func _refresh_all() -> void:
	if _rows == null:
		return
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
