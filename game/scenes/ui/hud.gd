class_name Hud
extends CanvasLayer
## 關卡 HUD：左上目前目標，右下存檔提示，目標指引（ObjectiveGuide）。只聽 Game.session 的訊號，不輪詢。
## 目標換了會淡入，停留一陣子後淡出（03：探索時幾乎沒有 HUD）；按「日誌」鍵（Tab／Back）再顯示。
## 進入檢查點（自動存檔）時右下閃一下「已存檔」（失敗則顯示「存檔失敗」）。

const OBJECTIVE_FADE_SEC: float = 0.6
const OBJECTIVE_HOLD_SEC: float = 8.0
const OBJECTIVE_PEEK_SEC: float = 4.0
const SAVED_SHOW_SEC: float = 2.2

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
## 重現提示（下方中央，D-059）
var restore: RestorePrompt
## 互動提示（救援、拉起席菈；疊在重現提示上方，D-065）
var interact: InteractPrompt
var _banner_tween: Tween


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
	combat = CombatHud.new()
	add_child(combat)
	guide = ObjectiveGuide.new()
	add_child(guide)
	restore = RestorePrompt.new()
	add_child(restore)
	interact = InteractPrompt.new()
	add_child(interact)
	interact.avoid = restore


func _process(delta: float) -> void:
	# 目標文字亮著時指引也全亮；關卡＝Hud 的父節點
	guide.emphasized = is_objective_shown()
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	guide.refresh(get_parent(), player, get_viewport().get_camera_3d(), combat.in_combat, delta)


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
	if quest_id == GameSession.MAIN_QUEST:
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
