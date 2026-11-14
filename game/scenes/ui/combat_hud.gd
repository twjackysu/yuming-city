class_name CombatHud
extends Control
## 戰鬥 HUD（左下）：諾恩的生命條，回血／受傷有顏色的變化段。
## 戰鬥中（20 公尺內有活著的敵人）或身上有狀態時淡入，探索時隱藏。數值每幀從場景讀（純顯示，不改狀態）。
## 同伴（席菈）的條與指令之後加在這裡。

const COMBAT_RANGE: float = 20.0
const BAR_W: float = 260.0
const BAR_H: float = 8.0
const COL_BG: Color = Color(0.05, 0.06, 0.08, 0.6)
const COL_HP: Color = Color(0.84, 0.78, 0.66)
## 生命條的變化段：回血＝綠色往上的段（前緣一條更亮的線），剛被扣掉的＝紅色往下的段
const COL_HEAL: Color = Color(0.45, 0.9, 0.5)
const COL_HEAL_TIP: Color = Color(0.82, 1.0, 0.8)
const COL_LOSS: Color = Color(0.86, 0.3, 0.26, 0.9)

var noen_ratio: float = 1.0
## 諾恩生命條的變化段；測試讀 noen_trail.heal_span()／loss_span()
var noen_trail: BarTrail = BarTrail.new()
var in_combat: bool = false
## 生命條看不看得到：戰鬥中，或諾恩身上有狀態（中毒回血時要看得到生命往上爬）
var bars_shown: bool = false
## Hud 設定：不在戰鬥、身上也沒狀態時照樣顯示
var force_bars: bool = false

var _noen_name: Label
var _alpha: float = 0.0


func _ready() -> void:
	name = "CombatHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_noen_name = Label.new()
	_noen_name.text = "SPK_NOEN"
	_noen_name.add_theme_font_size_override("font_size", 16)
	_noen_name.add_theme_color_override("font_color", COL_HP)
	_noen_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_noen_name.add_theme_constant_override("shadow_offset_y", 2)
	_noen_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_noen_name)
	modulate.a = 0.0


func is_shown() -> bool:
	return in_combat


func _process(delta: float) -> void:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	refresh(player)
	if player != null:
		noen_trail.step(noen_ratio, delta)
	_alpha = move_toward(_alpha, 1.0 if bars_shown else 0.0, delta * (3.0 if bars_shown else 1.2))
	modulate.a = _alpha
	_noen_name.position = _origin() + Vector2(0, -24)
	queue_redraw()


## 從場景讀數值（測試直接呼叫）。
func refresh(player: PlayerController) -> void:
	in_combat = player != null and _enemy_near(player.global_position)
	bars_shown = in_combat or force_bars or (player != null and player.status_effects != null and not player.status_effects.ids().is_empty())
	noen_ratio = player.health.ratio() if player != null else 0.0


func _enemy_near(pos: Vector3) -> bool:
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: EnemyActor = n as EnemyActor
		if e != null and e.brain != null and e.brain.state != EnemyBrain.State.DEAD and e.global_position.distance_to(pos) <= COMBAT_RANGE:
			return true
	return false


func _origin() -> Vector2:
	return Vector2(56.0, size.y - 150.0)


func _draw() -> void:
	var o: Vector2 = _origin()
	_bar(o, noen_trail.base_ratio(), COL_HP)
	_bar_span(o, noen_trail.base_ratio(), noen_trail.heal_span(), COL_HEAL)
	_bar_span(o, noen_trail.ratio, noen_trail.loss_span(), COL_LOSS)
	if noen_trail.is_healing() and noen_trail.ratio > 0.0:
		draw_rect(Rect2(o + Vector2(maxf(BAR_W * noen_trail.ratio - 2.0, 0.0), -1.0), Vector2(2.0, BAR_H + 2.0)), COL_HEAL_TIP)


func _bar(pos: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(BAR_W, BAR_H)), COL_BG)
	draw_rect(Rect2(pos, Vector2(BAR_W * clampf(ratio, 0.0, 1.0), BAR_H)), color)


## 條上的一段：從 from（比例）開始、寬 span（比例）
func _bar_span(pos: Vector2, from: float, span: float, color: Color) -> void:
	if span <= 0.0:
		return
	draw_rect(Rect2(pos + Vector2(BAR_W * clampf(from, 0.0, 1.0), 0.0), Vector2(BAR_W * clampf(span, 0.0, 1.0 - from), BAR_H)), color)
