class_name Hud
extends CanvasLayer
## 關卡 HUD：左上目前目標，右下存檔提示，目標指引（ObjectiveGuide）。只聽 Game.session 的訊號，不輪詢。
## 目標換了會淡入，停留一陣子後淡出（03：探索時幾乎沒有 HUD）；按「日誌」鍵（Tab／Back）再顯示。
## 進入檢查點（自動存檔）時右下閃一下「已存檔」（失敗則顯示「存檔失敗」）。

const OBJECTIVE_FADE_SEC: float = 0.6
const OBJECTIVE_HOLD_SEC: float = 8.0
const OBJECTIVE_PEEK_SEC: float = 4.0
const SAVED_SHOW_SEC: float = 2.2
## 狀態列後面的「可以釋放」提示（D-245）
const RELEASE_HINT_KEY: String = "ARENA_RELEASE_HINT"

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
## 互動提示（下方中央：拿藥瓶、拉起席菈，D-065）
var interact: InteractPrompt
## 新版的狀態圖示（左下、諾恩生命條上方，D-202）；舊版沒有狀態，永遠是空的
var status: StatusHud
## 新版：可攜藥劑的數量（生命條右上方）與滿血時的確認框（D-209）
var potion: PotionHud
var potion_confirm: PotionConfirm
var _potion_player: PlayerController
var _banner_tween: Tween
## 畫面中間的兩行字（新版第一次覺醒：「【中毒】」→「【逆轉體質已啟動】中毒 → 持續回血」，D-204）
var _center: VBoxContainer
var _center_tween: Tween
var _center_back: StyleBoxFlat
## 第二行比第一行晚出現幾秒
const CENTER_LINE_GAP: float = 0.9
## 中央兩行字的暗底比字多出多少（左右、上下）
const CENTER_BACK_PAD: Vector2 = Vector2(30.0, 12.0)
const CENTER_LINE2_COLOR: Color = Color(0.55, 0.95, 0.6)


func _ready() -> void:
	layer = 10
	add_to_group(PauseMenu.HIDE_GROUP)  # 暫停時藏起來（D-093）
	_build()
	var s: GameSession = Game.session
	s.stage_changed.connect(_on_stage_changed)
	s.checkpoint_reached.connect(_on_checkpoint)
	_set_objective(s.objective_key(), false)
	_saved.modulate.a = 0.0
	Game.player_died.connect(_on_player_died)
	# 截圖用：`--nohud` 整個 HUD 不顯示（Steam 膠囊圖替代版的背景、宣傳截圖，D-064）
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
	_center = VBoxContainer.new()
	_center.name = "CenterLines"
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_center)
	# 兩行字後面一塊邊緣柔和的暗底：背景很亮、很花的時候（藥店那一排發光的瓶子）字才讀得出來（D-234）
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
	# 身上的毒可以放出去的時候（戰鬥場，D-245），那一列後面寫按哪個鍵、會扣多少
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


## 確認框選完：喝＝帶 confirmed 再喝一次；先收著＝記下來（試用毒劑那一段可以這樣完成，09 第 5 節）
func _on_potion_decided(drink: bool) -> void:
	if drink:
		if _potion_player != null and is_instance_valid(_potion_player):
			_potion_player.use_potion(true)
	elif Game.session != null and Game.session.in_story():
		Game.session.set_flag("rb.potion_kept", true)


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


## 「你倒下了」收掉（戰鬥場原地重來，D-238）
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
