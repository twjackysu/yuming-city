class_name ChapterCard
extends CanvasLayer
## 章節卡（D-149）：畫面淡成黑 → 置中出現「第一章」小字＋章名（明體）→ 停一下 → 呼叫 on_done（通常是換關卡）。
## 掛在關卡底下：關卡被釋放（測試、回標題）時卡片跟著消失，on_done 不會被呼叫。
## 按確認鍵（ui_accept）可以提早結束；字一律用子節點 Label（D-060）。

const INK: Color = Color(0.95, 0.92, 0.86)
const WARM: Color = Color(0.98, 0.8, 0.52)
const LAYER: int = 40
const FADE_SEC: float = 0.9
const TEXT_IN_SEC: float = 0.8
const HOLD_SEC: float = 2.6
## 開始後多久才接受跳過（避免走進地窖時剛好按著確認鍵）
const SKIP_AFTER_SEC: float = 0.6

var on_done: Callable = Callable()
var finished: bool = false
var elapsed: float = 0.0
var _black: ColorRect
var _box: VBoxContainer
var _number: Label
var _title: Label
var _tween: Tween


## 建立一張章節卡加到 parent 底下並開始播放。number_key 例如 CH1_CARD_NUMBER（「第一章」）。
static func play(parent: Node, number_key: String, title_key: String, done: Callable, time_scale: float = 1.0) -> ChapterCard:
	var card := ChapterCard.new()
	card.on_done = done
	parent.add_child(card)
	card.start(number_key, title_key, time_scale)
	return card


func _init() -> void:
	name = "ChapterCard"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0.015, 0.017, 0.025, 1.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	add_child(_black)
	_box = VBoxContainer.new()
	_box.name = "Text"
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 14)
	_box.modulate.a = 0.0
	add_child(_box)
	_number = _label(26, Color(WARM, 0.9), UiFonts.UI_SANS)
	_number.name = "Number"
	_box.add_child(_number)
	_title = _label(64, INK, UiFonts.TITLE_SERIF)
	_title.name = "Title"
	_box.add_child(_title)
	# 章名下一道細細的暖金色線
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color(WARM, 0.55)
	rule.custom_minimum_size = Vector2(140.0, 1.5)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(rule)


func _label(font_size: int, color: Color, font_path: String) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	var font: Font = UiFonts.load_font(font_path)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## time_scale：測試用（< 1 讓整段變短）。
func start(number_key: String, title_key: String, time_scale: float = 1.0) -> void:
	_number.text = number_key
	_title.text = title_key
	var k: float = maxf(time_scale, 0.01)
	_tween = create_tween()
	_tween.tween_property(_black, "modulate:a", 1.0, FADE_SEC * k)
	_tween.tween_property(_box, "modulate:a", 1.0, TEXT_IN_SEC * k)
	_tween.tween_interval(HOLD_SEC * k)
	_tween.tween_property(_box, "modulate:a", 0.0, TEXT_IN_SEC * 0.6 * k)
	_tween.tween_callback(finish)


## 截圖用：停在章名完整出現的那一刻（不會結束、不呼叫 on_done）。
func hold_still() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_black.modulate.a = 1.0
	_box.modulate.a = 1.0
	finished = true


func _process(delta: float) -> void:
	elapsed += delta


func _unhandled_input(event: InputEvent) -> void:
	if finished or elapsed < SKIP_AFTER_SEC:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		finish()


## 結束（播完或跳過）：畫面維持全黑，呼叫 on_done 一次。
func finish() -> void:
	if finished:
		return
	finished = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_black.modulate.a = 1.0
	_box.modulate.a = 0.0
	if on_done.is_valid():
		on_done.call()


func title_text() -> String:
	return tr(_title.text)
