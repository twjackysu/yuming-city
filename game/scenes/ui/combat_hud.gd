class_name CombatHud
extends Control
## 戰鬥 HUD（左下）：諾恩生命、席菈生命＋體力、三個指令的鍵名與冷卻。
## 鍵名用 GlyphLine：鍵鼠顯示「[Q] 打弱點」，手把顯示按鈕圖示＋「打弱點」（D-063）；掙扎提示同。
## 只在戰鬥中（20 公尺內有活著的敵人）淡入，探索時隱藏（03：探索時幾乎沒有 HUD）。
## 席菈倒下時她的條顯示「倒下」與可拉起的剩餘秒數。數值每幀從場景讀（純顯示，不改狀態）。

const COMBAT_RANGE: float = 20.0
const BAR_W: float = 260.0
const BAR_H: float = 8.0
const COMMANDS: Array[Array] = [
	["command_weakpoint", "weakpoint", "HUD_CMD_WEAKPOINT"],
	["command_evade", "evade", "HUD_CMD_EVADE"],
	["command_guard", "guard", "HUD_CMD_GUARD"],
]
const COL_BG: Color = Color(0.05, 0.06, 0.08, 0.6)
const COL_HP: Color = Color(0.84, 0.78, 0.66)
const COL_HP_SHEILA: Color = Color(0.82, 0.88, 0.95)
const COL_STAMINA: Color = Color(0.5, 0.72, 0.9)
const COL_DOWN: Color = Color(0.85, 0.45, 0.4)
## 生命條的變化段（D-213）：回血＝綠色往上的段（前緣一條更亮的線），剛被扣掉的＝紅色往下的段
const COL_HEAL: Color = Color(0.45, 0.9, 0.5)
const COL_HEAL_TIP: Color = Color(0.82, 1.0, 0.8)
const COL_LOSS: Color = Color(0.86, 0.3, 0.26, 0.9)
const COL_CMD: Color = Color(0.9, 0.92, 0.95)
## 席菈正在守（玩家下的「守住」或劇情暫時守住）：「守住」那一格染成霜藍，玩家才知道再按一次是解除
const COL_GUARD_ON: Color = Color(0.55, 0.85, 1.0)

var noen_ratio: float = 1.0
## 諾恩生命條的變化段（回血的綠、受傷的紅）；測試讀 noen_trail.heal_span()／loss_span()
var noen_trail: BarTrail = BarTrail.new()
var sheila_ratio: float = 1.0
var stamina_ratio: float = 1.0
var sheila_present: bool = false
var sheila_down: bool = false
var in_combat: bool = false
## 這一塊（生命條）看不看得到：戰鬥中，或諾恩身上有狀態（新版：中毒回血時要看得到生命往上爬，D-205）
var bars_shown: bool = false
## Hud 設定：不在戰鬥、身上也沒狀態時照樣顯示生命條（新版剛撿到藥、還沒決定喝不喝的那一段，D-209）
var force_bars: bool = false
## cmd → 冷卻比例 0..1（0＝可用）
var cooldowns: Dictionary = {}

var _sheila_name: Label
var _noen_name: Label
var _cmd_lines: Array[GlyphLine] = []
var _struggle: GlyphLine
## 被抓時的掙扎提示
var struggle_shown: bool = false
var guard_on: bool = false
var _alpha: float = 0.0


func _ready() -> void:
	name = "CombatHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_noen_name = _label("SPK_NOEN", 16, COL_HP)
	_sheila_name = _label("SPK_SHEILA", 16, COL_HP_SHEILA)
	# 動態組字（鍵名＋翻譯）的標籤標上 glyph，UI 測試的「寫死文字」檢查會跳過
	_sheila_name.set_meta("glyph", true)
	for c: Array in COMMANDS:
		var line: GlyphLine = GlyphLine.new().configure(18, COL_CMD)
		line.name = "Cmd_%s" % str(c[1])
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
		add_child(line)
		_cmd_lines.append(line)
	_struggle = GlyphLine.new().configure(30, Color(1.0, 0.92, 0.85))
	_struggle.name = "Struggle"
	add_child(_struggle)
	_struggle.visible = false
	modulate.a = 0.0


func _label(key: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = key
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func is_shown() -> bool:
	return in_combat


## 指令那一格的文字版（「[Q] 打弱點」／手把「[X] 打弱點」）。
func command_label(i: int) -> String:
	return _cmd_lines[i].plain_text()


func command_line(i: int) -> GlyphLine:
	return _cmd_lines[i]


func struggle_line() -> GlyphLine:
	return _struggle


func _process(delta: float) -> void:
	var player: PlayerController = _first("player") as PlayerController
	var sheila: Sheila = _first("companion") as Sheila
	refresh(player, sheila)
	if player != null:
		noen_trail.step(noen_ratio, delta)
	_alpha = move_toward(_alpha, 1.0 if bars_shown else 0.0, delta * (3.0 if bars_shown else 1.2))
	modulate.a = _alpha
	_layout()
	queue_redraw()


## 從場景讀數值（測試直接呼叫）。
func refresh(player: PlayerController, sheila: Sheila) -> void:
	in_combat = player != null and _enemy_near(player.global_position)
	bars_shown = in_combat or force_bars or (player != null and player.status_effects != null and not player.status_effects.ids().is_empty())
	noen_ratio = player.health.ratio() if player != null else 0.0
	sheila_present = sheila != null
	if sheila != null:
		sheila_ratio = sheila.health.ratio()
		stamina_ratio = clampf(sheila.brain.stamina / sheila.brain.max_stamina, 0.0, 1.0)
		sheila_down = sheila.brain.mode == CompanionBrain.Mode.DOWN
		var cd: float = maxf(sheila.brain.command_cooldown, 0.01)
		for c: Array in COMMANDS:
			cooldowns[str(c[1])] = clampf(sheila.brain.cooldown_left(str(c[1])) / cd, 0.0, 1.0)
		if sheila_down:
			var left: float = sheila.brain.revive_time_left()
			_sheila_name.text = tr("HUD_SHEILA_DOWN").format([ceili(left)]) if left > 0.0 else tr("HUD_SHEILA_DOWN_WAIT")
		else:
			_sheila_name.text = "SPK_SHEILA"
	_sheila_name.visible = sheila_present
	guard_on = sheila_present and not sheila_down and sheila.brain.guard_active
	struggle_shown = player != null and player.grabbed_by != null
	_struggle.visible = struggle_shown
	if struggle_shown:
		_struggle.set_line(tr("HUD_STRUGGLE").format({"n": player.struggle_need - player.struggle}), "dodge", App.last_device)
	for i: int in COMMANDS.size():
		var c: Array = COMMANDS[i]
		_cmd_lines[i].set_line("{key} %s" % tr(str(c[2])), str(c[0]), App.last_device)
		var usable: bool = sheila_present and not sheila_down and float(cooldowns.get(str(c[1]), 0.0)) <= 0.0
		_cmd_lines[i].modulate.a = 1.0 if usable else 0.35
		if str(c[1]) == "guard":
			_cmd_lines[i].set_color(COL_GUARD_ON if guard_on else COL_CMD)
		_cmd_lines[i].visible = sheila_present


func _enemy_near(pos: Vector3) -> bool:
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: EnemyActor = n as EnemyActor
		if e != null and e.brain != null and e.brain.state != EnemyBrain.State.DEAD and e.global_position.distance_to(pos) <= COMBAT_RANGE:
			return true
	return false


func _first(group: String) -> Node:
	for n: Node in get_tree().get_nodes_in_group(group):
		return n
	return null


func _origin() -> Vector2:
	return Vector2(56.0, size.y - 150.0)


func _layout() -> void:
	var o: Vector2 = _origin()
	_noen_name.position = o + Vector2(0, -24)
	_sheila_name.position = o + Vector2(0, 22)
	for i: int in _cmd_lines.size():
		var line: GlyphLine = _cmd_lines[i]
		# 每格以第 i 列的中線對齊（圖示比字高，不能用左上角對齊）
		line.position = o + Vector2(BAR_W + 40.0, -12.0 + 28.0 * float(i) - line.size.y * 0.5)
	_struggle.position = Vector2((size.x - _struggle.size.x) * 0.5, size.y * 0.62)


func _draw() -> void:
	var o: Vector2 = _origin()
	_bar(o, noen_trail.base_ratio(), COL_HP)
	_bar_span(o, noen_trail.base_ratio(), noen_trail.heal_span(), COL_HEAL)
	_bar_span(o, noen_trail.ratio, noen_trail.loss_span(), COL_LOSS)
	if noen_trail.is_healing() and noen_trail.ratio > 0.0:
		draw_rect(Rect2(o + Vector2(maxf(BAR_W * noen_trail.ratio - 2.0, 0.0), -1.0), Vector2(2.0, BAR_H + 2.0)), COL_HEAL_TIP)
	if sheila_present:
		_bar(o + Vector2(0, 46), sheila_ratio, COL_DOWN if sheila_down else COL_HP_SHEILA)
		_bar(o + Vector2(0, 58), stamina_ratio, COL_STAMINA, 4.0)
		for i: int in COMMANDS.size():
			var f: float = float(cooldowns.get(str(COMMANDS[i][1]), 0.0))
			if f > 0.0:
				var p: Vector2 = o + Vector2(BAR_W + 22.0, -14.0 + 28.0 * float(i))
				draw_arc(p, 7.0, -PI * 0.5, -PI * 0.5 + TAU * f, 20, Color(0.8, 0.85, 0.95, 0.8), 2.0)


func _bar(pos: Vector2, ratio: float, color: Color, h: float = BAR_H) -> void:
	draw_rect(Rect2(pos, Vector2(BAR_W, h)), COL_BG)
	draw_rect(Rect2(pos, Vector2(BAR_W * clampf(ratio, 0.0, 1.0), h)), color)


## 條上的一段：從 from（比例）開始、寬 span（比例）
func _bar_span(pos: Vector2, from: float, span: float, color: Color, h: float = BAR_H) -> void:
	if span <= 0.0:
		return
	draw_rect(Rect2(pos + Vector2(BAR_W * clampf(from, 0.0, 1.0), 0.0), Vector2(BAR_W * clampf(span, 0.0, 1.0 - from), h)), color)
