class_name ObjectiveGuide
extends Control
## 目標指引（02-gameplay「目標指引」）：指向目前任務目標的小菱形＋距離。
## - 目標在畫面內：菱形畫在目標上方（約頭頂高度），下面寫距離
## - 目標在畫面外／身後：菱形貼在畫面邊緣，旁邊一個小三角指向目標方向
## - 隱藏：設定關掉、對話／過場／倒下、戰鬥中、離目標 4 公尺內、沒有目標
## 目標從任務資料的 marker／marker_if 來（QuestRunner.marker_spec），位置每幀從關卡讀（純顯示）。

const HIDE_NEAR: float = 4.0
const HEAD_HEIGHT: float = 1.8
const EDGE_MARGIN: float = 56.0
const SIZE: float = 11.0
const COL: Color = Color(0.98, 0.8, 0.52)
const COL_OUTLINE: Color = Color(0.04, 0.04, 0.06, 0.85)
## 平常淡一點（03：探索時幾乎沒有 HUD），目標剛換或按 Tab 時跟著目標文字亮起
const IDLE_ALPHA: float = 0.55

## 外部（Hud）設定：目標文字顯示中 → 指引全亮
var emphasized: bool = false
## 目前畫面上的狀態（測試用）
var shown: bool = false
var screen_pos: Vector2 = Vector2.ZERO
var on_screen: bool = false
var distance: float = 0.0
var _alpha: float = 0.0
var _edge_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	name = "ObjectiveGuide"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 把 marker 轉成世界座標；找不到回傳 Vector3.INF。
static func resolve_target(level: Node, spec: Variant, from: Vector3) -> Vector3:
	if level == null or spec == null:
		return Vector3.INF
	if spec is Array:
		var a: Array = spec as Array
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	var t: String = str(spec)
	if t.begins_with("node:"):
		var n: Node3D = level.get_node_or_null(NodePath(t.substr(5))) as Node3D
		if n == null or not n.is_inside_tree():
			return Vector3.INF
		return n.global_position
	if t.begins_with("nearest:"):
		var prefix: String = t.substr(8)
		var best: Vector3 = Vector3.INF
		var best_d: float = INF
		for c: Node in level.get_children():
			var n3: Node3D = c as Node3D
			if n3 == null or not str(n3.name).begins_with(prefix):
				continue
			if n3.has_method("is_available") and not bool(n3.call("is_available")):
				continue
			var d: float = n3.global_position.distance_to(from)
			if d < best_d:
				best_d = d
				best = n3.global_position
		return best
	return Vector3.INF


## 每幀更新（Hud 呼叫）。level＝關卡根節點，player＝諾恩，cam＝目前鏡頭。
func refresh(level: Node, player: Node3D, cam: Camera3D, in_combat: bool, delta: float) -> void:
	var want: bool = false
	if Settings.objective_marker and player != null and cam != null and not Game.is_player_locked() and not in_combat:
		var target: Vector3 = resolve_target(level, Game.session.quests.marker_spec(GameSession.MAIN_QUEST), player.global_position)
		if target.is_finite():
			var flat: Vector3 = target - player.global_position
			flat.y = 0.0
			distance = flat.length()
			if distance > HIDE_NEAR:
				want = true
				_place(cam, target + Vector3(0, HEAD_HEIGHT, 0))
	shown = want
	var goal: float = (1.0 if emphasized else IDLE_ALPHA) if want else 0.0
	_alpha = move_toward(_alpha, goal, delta * 3.0)
	queue_redraw()


func _place(cam: Camera3D, world: Vector3) -> void:
	var rect: Rect2 = get_viewport_rect()
	var inner: Rect2 = rect.grow(-EDGE_MARGIN)
	var behind: bool = cam.is_position_behind(world)
	var p: Vector2 = cam.unproject_position(world)
	if behind:
		# 身後：投影會左右顛倒，翻回來並推到畫面下緣
		p = rect.size - p
		p.y = rect.size.y * 2.0
	on_screen = not behind and inner.has_point(p)
	if on_screen:
		screen_pos = p
		_edge_dir = Vector2.ZERO
		return
	var center: Vector2 = rect.size * 0.5
	var dir: Vector2 = (p - center)
	if dir.length() < 0.001:
		dir = Vector2.DOWN
	dir = dir.normalized()
	# 從中心沿 dir 延伸到內框邊緣
	var half: Vector2 = inner.size * 0.5
	var sx: float = half.x / maxf(absf(dir.x), 0.0001)
	var sy: float = half.y / maxf(absf(dir.y), 0.0001)
	screen_pos = center + dir * minf(sx, sy)
	_edge_dir = dir


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var a: float = _alpha
	var c: Vector2 = screen_pos
	var pts := PackedVector2Array([c + Vector2(0, -SIZE * 1.35), c + Vector2(SIZE, 0), c + Vector2(0, SIZE * 1.35), c + Vector2(-SIZE, 0)])
	var outline := PackedVector2Array([c + Vector2(0, -SIZE * 1.35 - 3), c + Vector2(SIZE + 3, 0), c + Vector2(0, SIZE * 1.35 + 3), c + Vector2(-SIZE - 3, 0)])
	draw_colored_polygon(outline, Color(COL_OUTLINE, COL_OUTLINE.a * a))
	draw_colored_polygon(pts, Color(COL, a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -SIZE * 0.55), c + Vector2(SIZE * 0.4, 0), c + Vector2(0, SIZE * 0.55), c + Vector2(-SIZE * 0.4, 0)]), Color(1.0, 0.97, 0.9, a))
	if _edge_dir != Vector2.ZERO:
		var tip: Vector2 = c + _edge_dir * (SIZE * 2.6)
		var side: Vector2 = _edge_dir.orthogonal() * SIZE * 0.7
		var base: Vector2 = c + _edge_dir * (SIZE * 1.6)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(COL, a))
	var font: Font = get_theme_default_font()
	var text: String = TranslationServer.translate("GUIDE_DISTANCE").format({"m": int(round(distance))})
	var fs: int = 18
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var tp: Vector2 = c + Vector2(-size.x * 0.5, SIZE * 1.35 + 8 + font.get_ascent(fs))
	if _edge_dir.y > 0.3:
		# 箭頭朝下（目標在身後）：距離寫在菱形上方，避開箭頭
		tp.y = c.y - SIZE * 1.35 - 8 - font.get_descent(fs)
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(COL_OUTLINE, COL_OUTLINE.a * a))
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.92, 0.86, a))
