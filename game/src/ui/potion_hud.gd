class_name PotionHud
extends Control
## 可攜藥劑的數量（D-209，09 第 5 節）：諾恩生命條右上方的一小格——瓶子圖示＋「×2」＋快捷鍵（鍵盤 [1]／手把十字鍵左的圖示）。
## 只在身上有藥時出現：跟著生命條一起顯示（戰鬥中、身上有狀態），或被關卡釘住（pinned：剛撿到、還沒決定喝不喝的那一段）。
## 純顯示：refresh(count, with_bars, delta) 每幀由 Hud 餵。

const ICON: float = 26.0
const WIDTH: float = 118.0
const FADE_SPEED: float = 4.0
const COL_INK: Color = Color(0.92, 0.94, 0.88)
const COL_GLASS: Color = Color(0.7, 0.86, 0.72)
const COL_LIQUID: Color = Color(0.42, 0.95, 0.4)
const COL_SEAL: Color = Color(0.62, 0.16, 0.12)
const COL_BG: Color = Color(0.05, 0.06, 0.08, 0.6)

var count: int = 0
## 關卡釘住：不管生命條有沒有顯示都亮著
var pinned: bool = false
var _count: Label
var _key: GlyphLine
var _alpha: float = 0.0
var _shown: bool = false


func _ready() -> void:
	name = "PotionHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, ICON)
	size = custom_minimum_size
	_count = Label.new()
	_count.name = "Count"
	_count.add_theme_font_size_override("font_size", 19)
	_count.add_theme_color_override("font_color", COL_INK)
	_count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_count.add_theme_constant_override("shadow_offset_y", 2)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 動態組字（×數量）：UI 測試的「寫死文字」檢查會跳過
	_count.set_meta("glyph", true)
	_count.position = Vector2(ICON + 6.0, -1.0)
	add_child(_count)
	_key = GlyphLine.new().configure(17, Color(0.78, 0.8, 0.76))
	_key.name = "Key"
	_key.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_key)
	modulate.a = 0.0
	visible = false


## count＝身上幾瓶；with_bars＝生命條現在有沒有顯示。delta = 0 時直接到位（測試用）。
func refresh(p_count: int, with_bars: bool, delta: float) -> void:
	count = p_count
	_shown = count > 0 and (with_bars or pinned)
	if count > 0:
		_count.text = "×%d" % count
	_key.set_line("{key}", "use_item", App.last_device)
	_key.position = Vector2(ICON + 44.0, (ICON - _key.size.y) * 0.5)
	var target: float = 1.0 if _shown else 0.0
	_alpha = move_toward(_alpha, target, delta * FADE_SPEED) if delta > 0.0 else target
	modulate.a = _alpha
	visible = _alpha > 0.001
	queue_redraw()


func is_shown() -> bool:
	return _shown


func count_text() -> String:
	return _count.text if _shown else ""


func key_line() -> GlyphLine:
	return _key


func _draw() -> void:
	var c := Vector2(ICON * 0.5, ICON * 0.5)
	draw_circle(c, ICON * 0.5, COL_BG)
	# 圓肚瓶：瓶肚（裡面半滿的綠色藥）、瓶頸、封蠟
	var belly: Vector2 = c + Vector2(0.0, 3.5)
	draw_circle(belly, 7.5, COL_GLASS)
	draw_circle(belly + Vector2(0.0, 0.8), 5.8, COL_LIQUID)
	draw_rect(Rect2(c + Vector2(-2.6, -9.0), Vector2(5.2, 7.0)), COL_GLASS)
	draw_rect(Rect2(c + Vector2(-3.4, -11.0), Vector2(6.8, 3.2)), COL_SEAL)
	draw_arc(c, ICON * 0.5, 0.0, TAU, 24, Color(COL_LIQUID.r, COL_LIQUID.g, COL_LIQUID.b, 0.55), 1.5)
