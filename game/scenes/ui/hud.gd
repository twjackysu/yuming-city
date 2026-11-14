class_name Hud
extends CanvasLayer
## 關卡 HUD：左上目前目標，右下存檔提示，目標指引（ObjectiveGuide）。只聽 Game.session 的訊號，不輪詢。
## 目標換了會淡入，停留一陣子後淡出（03：探索時幾乎沒有 HUD）；按「日誌」鍵（Tab／Back）再顯示。
## 進入檢查點（自動存檔）時右下閃一下「已存檔」（失敗則顯示「存檔失敗」）。

const OBJECTIVE_FADE_SEC: float = 0.6
const OBJECTIVE_HOLD_SEC: float = 8.0
const OBJECTIVE_PEEK_SEC: float = 4.0
const SAVED_SHOW_SEC: float = 2.2
## 狀態列後面的「可以釋放」提示
const RELEASE_HINT_KEY: String = "HUD_RELEASE_HINT"

var _objective: Label
var _objective_box: VBoxContainer
var _saved: Label
var _died: Label
var _saved_tween: Tween
var _objective_tween: Tween
var _banner: Label
## 戰鬥 HUD（生命、體力、指令）
var combat: CombatHud
## 目標指引（指向目前目標的小菱形＋距離）
var guide: ObjectiveGuide
## 互動提示（下方中央：拿藥瓶、拉起席菈）
var interact: InteractPrompt
## 新版的狀態圖示（左下、諾恩生命條上方）；舊版沒有狀態，永遠是空的
var status: StatusHud
## 新版：可攜藥劑的數量（生命條右上方）與滿血時的確認框
var potion: PotionHud
var potion_confirm: PotionConfirm
var _potion_player: PlayerController
var _banner_tween: Tween
## 畫面中間的兩行字（新版第一次覺醒：「【中毒】」→「【逆轉體質已啟動】中毒 → 持續回血」）
var _center: VBoxContainer
var _center_tween: Tween
var _center_back: StyleBoxFlat
## 第二行比第一行晚出現幾秒
const CENTER_LINE_GAP: float = 0.9
## 中央兩行字的暗底比字多出多少（左右、上下）
const CENTER_BACK_PAD: Vector2 = Vector2(30.0, 12.0)
const CENTER_LINE2_COLOR: Color = Color(0.55, 0.95, 0.6)
## 角色頭上的一句話（諾恩的碎念、旁人的反應）：跟著角色走、不停住遊戲、不是對話框。同一個角色同時只有一句
const BARK_FADE_IN: float = 0.12
const BARK_FADE_OUT: float = 0.45
const BARK_RISE_PX: float = 16.0
const BARK_MAX: int = 3
const BARK_EDGE: float = 14.0
## 頭頂的那一點超出畫面這麼多（px）以內還算在畫面裡
const BARK_OFFSCREEN: float = 40.0
const BARK_STACK_GAP: float = 4.0
## 講的人的臉被比較靠近鏡頭的另一個角色擋住就不顯示：第 99 輪的過肩連拍上，站在後面 8 m 的人講的話
## 畫在前面那個人的頭上，看起來像前面那個人講的。臉＝腳上面 head × BARK_FACE；擋人的身體＝腳到 BARK_BODY_HEIGHT、左右各 BARK_BODY_HALF 公尺。
const BARK_FACE: float = 0.76
const BARK_BODY_HEIGHT: float = 1.8
const BARK_BODY_HALF: float = 0.3
const BARK_BLOCKER_GROUPS: PackedStringArray = ["player", "heartbeat", "enemies"]
## 第一次連拍 24 px 的字在 1280×720 上只有 16 px 高、看不清楚（第 98 輪）——放大到跟中央提示差不多
const BARK_FONT_SIZE: int = 32
const BARK_COLOR: Color = Color(0.97, 0.94, 0.84)
var _bark_root: Control
var _barks: Array[Dictionary] = []


func _ready() -> void:
	layer = 10
	add_to_group(PauseMenu.HIDE_GROUP)  # 暫停時藏起來
	_build()
	var s: GameSession = Game.session
	s.stage_changed.connect(_on_stage_changed)
	s.checkpoint_reached.connect(_on_checkpoint)
	_set_objective(s.objective_key(), false)
	_saved.modulate.a = 0.0
	Game.player_died.connect(_on_player_died)
	# 截圖用：`--nohud` 整個 HUD 不顯示（Steam 膠囊圖替代版的背景、宣傳截圖）
	if App.parse_user_args(OS.get_cmdline_user_args()).has("nohud"):
		visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and _objective.text != "":
		_show_objective(OBJECTIVE_PEEK_SEC, _objective_box.modulate.a < 0.99)


func is_objective_shown() -> bool:
	return _objective_box.visible and _objective_box.modulate.a > 0.0


func objective_text_key() -> String:
	return _objective.text


func saved_label() -> Label:
	return _saved


func _build() -> void:
	_objective_box = VBoxContainer.new()
	_objective_box.name = "Objective"
	_objective_box.position = Vector2(56, 44)
	_objective_box.add_theme_constant_override("separation", 2)
	add_child(_objective_box)
	var header := Label.new()
	header.name = "Header"
	header.text = "HUD_OBJECTIVE"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.75, 0.66, 0.48, 0.9))
	_objective_box.add_child(header)
	_objective = Label.new()
	_objective.name = "Text"
	_objective.add_theme_font_size_override("font_size", 24)
	_objective.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	_objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_objective.add_theme_constant_override("shadow_offset_y", 2)
	_objective_box.add_child(_objective)

	_died = Label.new()
	_died.name = "Died"
	_died.text = "HUD_DIED"
	_died.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_died.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_died.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_died.add_theme_font_size_override("font_size", 44)
	_died.add_theme_color_override("font_color", Color(0.85, 0.78, 0.66))
	_died.hide()
	add_child(_died)
	_saved = Label.new()
	_saved.name = "Saved"
	_saved.text = "HUD_SAVED"
	_saved.add_theme_font_size_override("font_size", 18)
	_saved.add_theme_color_override("font_color", Color(0.85, 0.8, 0.68))
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	anchor.add_child(_saved)
	_saved.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	# 戰鬥中的劇情提示（鐵架拋擲等）：畫面上方置中，淡入淡出
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98))
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 110)
	_banner.modulate.a = 0.0
	_bark_root = Control.new()
	_bark_root.name = "Barks"
	_bark_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_bark_root)
	_center = VBoxContainer.new()
	_center.name = "CenterLines"
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_center)
	# 兩行字後面一塊邊緣柔和的暗底：背景很亮、很花的時候（藥店那一排發光的瓶子）字才讀得出來
	_center_back = StyleBoxFlat.new()
	_center_back.bg_color = Color(0.02, 0.03, 0.04, 0.5)
	_center_back.set_corner_radius_all(20)
	_center_back.shadow_color = Color(0.02, 0.03, 0.04, 0.26)
	_center_back.shadow_size = 30
	_center.draw.connect(_draw_center_back)
	for i: int in 2:
		var l := Label.new()
		l.name = "Line%d" % (i + 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 34 if i == 0 else 30)
		l.add_theme_color_override("font_color", Color(0.95, 0.42, 0.38) if i == 0 else CENTER_LINE2_COLOR)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_center.add_child(l)
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_center.modulate.a = 0.0
	combat = CombatHud.new()
	add_child(combat)
	guide = ObjectiveGuide.new()
	add_child(guide)
	interact = InteractPrompt.new()
	add_child(interact)
	status = StatusHud.new()
	add_child(status)
	potion = PotionHud.new()
	add_child(potion)
	potion_confirm = PotionConfirm.new()
	add_child(potion_confirm)
	potion_confirm.decided.connect(_on_potion_decided)


func _process(delta: float) -> void:
	# 目標文字亮著時指引也全亮；關卡＝Hud 的父節點
	guide.emphasized = is_objective_shown()
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var pc: PlayerController = player as PlayerController
	# 身上的毒可以放出去的時候（戰鬥場），那一列後面寫按哪個鍵、會扣多少
	var power: float = pc.release_power() if pc != null else 0.0
	var hint: String = ""
	if power > 0.0:
		hint = tr(RELEASE_HINT_KEY).format({"key": InputGlyphs.label_for_action("release", App.last_device), "dmg": int(power)})
	status.refresh(pc.status_effects if pc != null else null, PlayerController.RELEASE_STATUS, hint)
	# 戰鬥 HUD 的諾恩名字在 size.y-174；狀態一列 34，往上長
	var view_h: float = get_viewport().get_visible_rect().size.y
	status.position = Vector2(56.0, view_h - 182.0 - status.custom_minimum_size.y)
	_refresh_potion(pc, view_h, delta)
	guide.refresh(get_parent(), player, get_viewport().get_camera_3d(), combat.in_combat, delta)
	_update_barks(delta)


## 角色頭上跳一句話（翻譯 key 或已經翻好的字），seconds 秒後淡掉。head＝字浮在腳上面幾公尺。
## 同一個角色的上一句直接換掉；同時最多 BARK_MAX 句（最舊的先拿掉）。
func show_bark(speaker: Node3D, key: String, seconds: float = 2.4, color: Color = BARK_COLOR, head: float = 2.1) -> void:
	if speaker == null or key == "":
		return
	var i: int = _barks.size() - 1
	while i >= 0:
		if _barks[i]["speaker"] == speaker:
			(_barks[i]["label"] as Label).queue_free()
			_barks.remove_at(i)
		i -= 1
	while _barks.size() >= BARK_MAX:
		(_barks[0]["label"] as Label).queue_free()
		_barks.remove_at(0)
	var l := Label.new()
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", BARK_FONT_SIZE)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	_bark_root.add_child(l)
	_barks.append({"speaker": speaker, "label": l, "key": key, "age": 0.0, "life": maxf(seconds, 0.2), "head": head})
	_update_barks(0.0)


## 現在畫面上有哪幾句（key；測試用）
func bark_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for b: Dictionary in _barks:
		out.append(str(b["key"]))
	return out


func _update_barks(delta: float) -> void:
	if _barks.is_empty():
		return
	var i: int = _barks.size() - 1
	while i >= 0:
		var old: Dictionary = _barks[i]
		old["age"] = float(old["age"]) + delta
		if float(old["age"]) >= float(old["life"]) or not is_instance_valid(old["speaker"]):
			(old["label"] as Label).queue_free()
			_barks.remove_at(i)
		i -= 1
	var cam: Camera3D = get_viewport().get_camera_3d()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var placed: Array[Rect2] = []
	for b: Dictionary in _barks:
		var l: Label = b["label"] as Label
		var age: float = float(b["age"])
		var life: float = float(b["life"])
		l.modulate.a = clampf(minf(age / BARK_FADE_IN, (life - age) / BARK_FADE_OUT), 0.0, 1.0)
		if cam == null:
			continue
		var at: Vector3 = (b["speaker"] as Node3D).global_position + Vector3.UP * float(b["head"])
		var on: Vector2 = cam.unproject_position(at)
		# 講話的人不在畫面裡（或在鏡頭後面）就不顯示：貼在畫面邊上的一句話看不出是誰講的（第 98 輪的連拍）
		l.visible = not cam.is_position_behind(at) and Rect2(Vector2.ZERO, view).grow(BARK_OFFSCREEN).has_point(on)
		if l.visible and bark_speaker_hidden(cam, b["speaker"] as Node3D, float(b["head"])):
			l.visible = false
		if not l.visible:
			continue
		var size: Vector2 = l.get_minimum_size()
		var p: Vector2 = on - Vector2(size.x * 0.5, size.y + BARK_RISE_PX * age / life)
		var rect := Rect2(Vector2(clampf(p.x, BARK_EDGE, maxf(view.x - size.x - BARK_EDGE, BARK_EDGE)), clampf(p.y, BARK_EDGE, maxf(view.y - size.y - BARK_EDGE, BARK_EDGE))), size)
		# 幾個人站得近（或離鏡頭遠）的時候字會疊在一起看不懂（第 98 輪的連拍）：後講的往上讓，上面沒位置就往下
		var step: float = -(size.y + BARK_STACK_GAP)
		var tries: int = 0
		while tries < BARK_MAX * 2 and _bark_blocked(rect, placed):
			if rect.position.y + step < BARK_EDGE:
				step = size.y + BARK_STACK_GAP
			rect.position.y += step
			tries += 1
		l.position = rect.position
		placed.append(rect)


## 講的人的臉在畫面上是不是被另一個比較靠近鏡頭的角色（諾恩、席菈、還站著的敵人）的身體蓋住。
func bark_speaker_hidden(cam: Camera3D, speaker: Node3D, head: float) -> bool:
	if cam == null or speaker == null or not is_inside_tree():
		return false
	var face: Vector3 = speaker.global_position + Vector3.UP * head * BARK_FACE
	var on: Vector2 = cam.unproject_position(face)
	var far: float = cam.global_position.distance_to(face)
	var seen: Array[Node] = []
	for group: String in BARK_BLOCKER_GROUPS:
		for n: Node in get_tree().get_nodes_in_group(group):
			var other: Node3D = n as Node3D
			if other == null or other == speaker or seen.has(other):
				continue
			seen.append(other)
			var foe: EnemyActor = other as EnemyActor
			if foe != null and (foe.health == null or foe.health.is_dead()):
				continue
			var feet: Vector3 = other.global_position
			var top: Vector3 = feet + Vector3.UP * BARK_BODY_HEIGHT
			if cam.is_position_behind(feet) or cam.is_position_behind(top) or cam.global_position.distance_to(feet) > far - 0.5:
				continue
			var a: Vector2 = cam.unproject_position(top)
			var b: Vector2 = cam.unproject_position(feet)
			var half: float = absf(b.y - a.y) * BARK_BODY_HALF / BARK_BODY_HEIGHT
			if on.y >= minf(a.y, b.y) and on.y <= maxf(a.y, b.y) and absf(on.x - (a.x + b.x) * 0.5) <= half:
				return true
	return false


func _bark_blocked(rect: Rect2, placed: Array[Rect2]) -> bool:
	for r: Rect2 in placed:
		if r.intersects(rect):
			return true
	return false


## 畫面上看得到的那幾句各佔哪一塊（測試用）
func bark_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b: Dictionary in _barks:
		var l: Label = b["label"] as Label
		if l.visible:
			out.append(Rect2(l.position, l.get_minimum_size()))
	return out


## 可攜藥劑（新版）：數量一格在諾恩生命條的右上方；釘住時生命條也跟著亮（看得到現在滿不滿血）。
func _refresh_potion(pc: PlayerController, view_h: float, delta: float) -> void:
	var in_story: bool = Game.session != null and Game.session.in_story()
	var count: int = int(Game.session.state.items.get(PlayerController.PORTABLE_ITEM, 0)) if in_story else 0
	combat.force_bars = potion.pinned and count > 0
	potion.refresh(count, combat.bars_shown, delta)
	potion.position = Vector2(56.0 + CombatHud.BAR_W - PotionHud.WIDTH, view_h - 150.0 - 34.0)
	if pc != _potion_player:
		_potion_player = pc
		if pc != null and not pc.potion_needs_confirm.is_connected(_on_potion_needs_confirm):
			pc.potion_needs_confirm.connect(_on_potion_needs_confirm)


func _on_potion_needs_confirm(_item_id: String) -> void:
	potion_confirm.open()


## 確認框選完：喝＝帶 confirmed 再喝一次；先收著＝什麼都不做
func _on_potion_decided(drink: bool) -> void:
	if drink:
		if _potion_player != null and is_instance_valid(_potion_player):
			_potion_player.use_potion(true)


func _set_objective(key: String, animate: bool) -> void:
	_objective.text = key
	_objective_box.visible = key != ""
	if key != "":
		_show_objective(OBJECTIVE_HOLD_SEC, animate)


## 顯示目標 hold 秒後淡出；fade_in 為 false 時立即出現。
func _show_objective(hold: float, fade_in: bool) -> void:
	if _objective_tween != null:
		_objective_tween.kill()
	_objective_box.modulate.a = 0.0 if fade_in else 1.0
	if not is_inside_tree():
		return
	_objective_tween = create_tween()
	if fade_in:
		_objective_tween.tween_property(_objective_box, "modulate:a", 1.0, OBJECTIVE_FADE_SEC)
	_objective_tween.tween_interval(hold)
	_objective_tween.tween_property(_objective_box, "modulate:a", 0.0, OBJECTIVE_FADE_SEC * 2.0)


func _on_stage_changed(quest_id: String, _from: String, _to: String) -> void:
	if quest_id == Game.session.main_quest():
		_set_objective(Game.session.objective_key(), true)


func _on_checkpoint(_checkpoint_id: String) -> void:
	# 存檔在訊號之後才寫入，下一幀再看結果
	_show_saved.call_deferred()


func _on_player_died() -> void:
	if not is_inside_tree():
		return
	_died.show()
	_died.modulate.a = 0.0
	create_tween().tween_property(_died, "modulate:a", 1.0, 0.8)


func is_death_shown() -> bool:
	return _died.visible


## 「你倒下了」收掉（戰鬥場原地重來）
func hide_death() -> void:
	_died.hide()


## 畫面上方的一行提示（翻譯 key），停留 seconds 秒後淡出。
func show_banner(key: String, seconds: float = 3.0) -> void:
	_banner.text = key
	_banner.reset_size()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 110)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


## 中央兩行字的暗底（畫在字的後面，跟著字一起淡入淡出）
func _draw_center_back() -> void:
	_center.draw_style_box(_center_back, Rect2(-CENTER_BACK_PAD, _center.size + CENTER_BACK_PAD * 2.0))


## 畫面中間的兩行字（不暫停遊戲）：第一行先出現，第二行晚 CENTER_LINE_GAP 秒，一起停留 seconds 秒後淡出。
func show_center_lines(key1: String, key2: String, seconds: float = 4.0) -> void:
	var l1: Label = _center.get_child(0) as Label
	var l2: Label = _center.get_child(1) as Label
	l1.text = key1
	l2.text = key2
	l2.modulate.a = 0.0
	_center.reset_size()
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_center.position.y -= 150.0
	_center.queue_redraw()
	if _center_tween != null:
		_center_tween.kill()
	_center_tween = create_tween()
	_center_tween.tween_property(_center, "modulate:a", 1.0, 0.25)
	_center_tween.tween_property(l2, "modulate:a", 1.0, 0.35).set_delay(CENTER_LINE_GAP)
	_center_tween.tween_interval(seconds)
	_center_tween.tween_property(_center, "modulate:a", 0.0, 0.8)


## 中間兩行字現在的內容（測試用；沒顯示時是空的）
func center_lines() -> PackedStringArray:
	if _center.modulate.a <= 0.0 and (_center_tween == null or not _center_tween.is_running()):
		return PackedStringArray()
	return PackedStringArray([(_center.get_child(0) as Label).text, (_center.get_child(1) as Label).text])


## 立刻收掉上方的提示（截圖旗標直接跳段落時用：前一段的提示不該留到下一段的對話上）
func hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 0.0


func banner_text() -> String:
	return _banner.text if _banner.modulate.a > 0.0 or (_banner_tween != null and _banner_tween.is_running()) else ""


func _show_saved() -> void:
	if not is_inside_tree():
		return
	_saved.text = "HUD_SAVED" if Game.session.last_autosave_error == OK else "HUD_SAVE_FAILED"
	if _saved_tween != null:
		_saved_tween.kill()
	_saved.modulate.a = 0.0
	_saved_tween = create_tween()
	_saved_tween.tween_property(_saved, "modulate:a", 1.0, 0.25)
	_saved_tween.tween_interval(SAVED_SHOW_SEC)
	_saved_tween.tween_property(_saved, "modulate:a", 0.0, 0.6)
