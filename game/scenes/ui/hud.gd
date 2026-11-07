class_name Hud
extends CanvasLayer
## 關卡 HUD：左上目前目標，右下存檔提示。只聽 Game.session 的訊號，不輪詢。
## 目標換了會淡入，停留一陣子後淡出（03：探索時幾乎沒有 HUD）；按「日誌」鍵（Tab／Back）再顯示。
## 進入檢查點（自動存檔）時右下閃一下「已存檔」（失敗則顯示「存檔失敗」）。

const OBJECTIVE_FADE_SEC: float = 0.6
const OBJECTIVE_HOLD_SEC: float = 8.0
const OBJECTIVE_PEEK_SEC: float = 4.0
const SAVED_SHOW_SEC: float = 2.2

var _objective: Label
var _objective_box: VBoxContainer
var _saved: Label
var _saved_tween: Tween
var _objective_tween: Tween


func _ready() -> void:
	layer = 10
	_build()
	var s: GameSession = Game.session
	s.stage_changed.connect(_on_stage_changed)
	s.checkpoint_reached.connect(_on_checkpoint)
	_set_objective(s.objective_key(), false)
	_saved.modulate.a = 0.0


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
