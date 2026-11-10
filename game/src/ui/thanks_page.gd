class_name ThanksPage
extends CanvasLayer
## 「感謝試玩」一頁（D-176）：第一部前半的結尾卡之後、回標題之前。
## 黑底（跟章節卡同一個黑，接在結尾卡後面看不出換頁）上置中一欄：
##   小字「這一版到這裡」→ 明體「感謝試玩」→ 暖金細線 → 這一版的範圍
##   →「你的這一趟」四列（北街救出幾個人、那一夜的死者、為了重現付出幾段記憶、被推翻的攻略筆記）
##   → 後半預告（原作第七章的第一句）→ 怎麼回饋（GitHub Issue）→ 兩個按鈕（回饋頁面／回到標題）。
## 鍵盤、手把、滑鼠都能關：焦點預設在「回到標題」（確認鍵＝A），取消鍵（Esc／B）也回標題。
## 剛出現的 INPUT_DELAY 秒內按鈕不能按（避免連按跳過結尾卡時順手把這頁也跳掉）。
## 字一律用子節點 Label（D-060）；數字是另一個 Label（標 meta "glyph"），文字本身都是翻譯 key。

const INK: Color = Color(0.95, 0.92, 0.86)
const DIM: Color = Color(0.72, 0.74, 0.78)
const WARM: Color = Color(0.98, 0.8, 0.52)
const BLACK: Color = Color(0.015, 0.017, 0.025, 1.0)
## 比結尾卡（40）高一層：結尾卡播完停在全黑，這頁蓋在上面
const LAYER: int = 41
const FADE_SEC: float = 0.8
const INPUT_DELAY: float = 1.0
const COLUMN_W: float = 1040.0
const FEEDBACK_URL: String = "https://github.com/twjackysu/yuming-city/issues"
## 北街原本有幾個受困者（跟 DeadListBoard.NORTH_TRAPPED 一樣）
const NORTH_TRAPPED: int = 4
## 「你的這一趟」的列：翻譯 key（左欄）→ 數字（右欄）
const RUN_ROWS: PackedStringArray = ["THANKS_RUN_RESCUED", "THANKS_RUN_DEAD", "THANKS_RUN_MEMORIES", "THANKS_RUN_GUIDE"]

var on_done: Callable = Callable()
var finished: bool = false
var elapsed: float = 0.0
var back_button: Button
var feedback_button: Button
## 測試用：「回饋頁面」按了幾次（headless 不真的開瀏覽器）
var feedback_opened: int = 0
var _root: Control
var _values: Dictionary = {}
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


## 建立一頁加到 parent 底下。state 用來算「你的這一趟」；done 在關掉時呼叫一次（通常是回標題）。
static func show_on(parent: Node, state: GameState, done: Callable) -> ThanksPage:
	var page := ThanksPage.new()
	page.on_done = done
	page.fill(state)
	parent.add_child(page)
	return page


## 「你的這一趟」的數字（純資料，測試直接驗）。
static func run_summary(state: GameState) -> Dictionary:
	var rescued: int = clampi(int(state.get_flag("slice.rescued_count", 0)), 0, NORTH_TRAPPED)
	var wrong: int = 0
	for id: Variant in state.guide.keys():
		if GuideNotes.status(state, str(id)) == GuideNotes.WRONG:
			wrong += 1
	return {
		"THANKS_RUN_RESCUED": "%d / %d" % [rescued, NORTH_TRAPPED],
		"THANKS_RUN_DEAD": str(DeadListBoard.dead_count(state)),
		"THANKS_RUN_MEMORIES": str(state.memories_paid.size()),
		"THANKS_RUN_GUIDE": str(wrong),
	}


func _init() -> void:
	name = "ThanksPage"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _ready() -> void:
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE_SEC)
	_set_buttons_enabled(false)


func fill(state: GameState) -> void:
	_values = run_summary(state)
	for key: String in RUN_ROWS:
		var v: Label = _root.find_child("Value_" + key, true, false) as Label
		if v != null:
			v.text = str(_values.get(key, ""))


## 某一列右欄顯示的數字（測試用）。
func value_text(key: String) -> String:
	var v: Label = _root.find_child("Value_" + key, true, false) as Label
	return v.text if v != null else ""


## 截圖用：直接停在完全淡入、按鈕可以按。
func hold_still() -> void:
	_root.modulate.a = 1.0
	elapsed = INPUT_DELAY
	_set_buttons_enabled(true)


func _process(delta: float) -> void:
	elapsed += delta
	if finished:
		return
	if elapsed >= INPUT_DELAY and back_button.disabled:
		_set_buttons_enabled(true)
	# 暫停選單關掉後焦點可能不見了：拿回來（手把才按得到）
	if not back_button.disabled and not get_tree().paused and _root.is_visible_in_tree():
		if get_viewport().gui_get_focus_owner() == null:
			back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if finished or elapsed < INPUT_DELAY or get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## 關掉這頁：呼叫 on_done 一次。畫面維持全黑（不淡出，接下來就換場景）。
func close() -> void:
	if finished:
		return
	finished = true
	Input.mouse_mode = _mouse_before
	if on_done.is_valid():
		on_done.call()


func open_feedback() -> void:
	feedback_opened += 1
	if DisplayServer.get_name() != "headless":
		OS.shell_open(FEEDBACK_URL)


func _set_buttons_enabled(on: bool) -> void:
	back_button.disabled = not on
	feedback_button.disabled = not on
	if on and is_inside_tree():
		back_button.grab_focus()


func _build() -> void:
	var black := ColorRect.new()
	black.name = "Black"
	black.color = BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.custom_minimum_size = Vector2(COLUMN_W, 0.0)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	col.add_child(_label("Kicker", "THANKS_KICKER", 22, Color(WARM, 0.9), UiFonts.UI_SANS))
	col.add_child(_label("Title", "THANKS_TITLE", 68, INK, UiFonts.TITLE_SERIF))
	col.add_child(_rule())
	col.add_child(_gap(6.0))
	col.add_child(_label("Scope", "THANKS_SCOPE", 22, DIM, UiFonts.UI_SANS, true))
	col.add_child(_gap(18.0))

	# 你的這一趟：左欄說明、右欄數字（右對齊、暖金色）
	col.add_child(_label("RunHeader", "THANKS_RUN_HEADER", 18, Color(WARM, 0.75), UiFonts.UI_SANS))
	var grid := GridContainer.new()
	grid.name = "Run"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grid)
	for key: String in RUN_ROWS:
		var k: Label = _label("Key_" + key, key, 20, DIM, UiFonts.UI_SANS)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(k)
		var v: Label = _label("Value_" + key, "", 20, INK, UiFonts.UI_SANS_MEDIUM)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size = Vector2(90.0, 0.0)
		v.set_meta("glyph", true)
		grid.add_child(v)
	col.add_child(_gap(22.0))

	# 後半預告：原作第七章的第一句（不劇透後半的結局）
	col.add_child(_label("TeaserHeader", "THANKS_TEASER_HEADER", 18, Color(WARM, 0.75), UiFonts.UI_SANS))
	col.add_child(_label("Teaser", "THANKS_TEASER", 30, INK, UiFonts.TITLE_SERIF, true))
	col.add_child(_gap(22.0))

	col.add_child(_label("Feedback", "THANKS_FEEDBACK", 20, DIM, UiFonts.UI_SANS, true))
	col.add_child(_gap(14.0))
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 36)
	col.add_child(buttons)
	feedback_button = _button("FeedbackButton", "THANKS_OPEN_FEEDBACK", open_feedback)
	buttons.add_child(feedback_button)
	back_button = _button("BackButton", "MENU_BACK_TO_TITLE", close)
	buttons.add_child(back_button)
	# 左右切換焦點（手把十字鍵／方向鍵）
	feedback_button.focus_neighbor_right = feedback_button.get_path_to(back_button)
	back_button.focus_neighbor_left = back_button.get_path_to(feedback_button)


func _label(n: String, key: String, font_size: int, color: Color, font_path: String, wrap: bool = false) -> Label:
	var l := Label.new()
	l.name = n
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(COLUMN_W, 0.0)
	var font: Font = UiFonts.load_font(font_path)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _button(n: String, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = key
	b.flat = true
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(action)
	return b


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color(WARM, 0.55)
	rule.custom_minimum_size = Vector2(160.0, 1.5)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0.0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g
