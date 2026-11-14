class_name GameSession
extends RefCounted
## 一局遊戲：GameState＋QuestRunner＋存讀檔與檢查點。純邏輯，autoload「Game」只是它的外殼。
## 規則（docs/design/04-architecture.md）：
## - 場景只透過 set_flag／add_flag 等方法改狀態，不直接改存檔。
## - 進入有 checkpoint 的任務階段時自動存檔到 auto；死亡重試＝重讀 auto。

signal checkpoint_reached(checkpoint_id: String)
signal stage_changed(quest_id: String, from_stage: String, to_stage: String)
signal quest_completed(quest_id: String)
## 要寫存檔之前（玩家把生命、狀態、反轉欄位寫回 state）
signal saving(state: GameState)

const AUTO_SLOT: String = "auto"
const MANUAL_SLOTS: PackedStringArray = ["slot1", "slot2", "slot3"]
const DEFAULT_SAVE_DIR: String = "user://saves"
## 主線照順序排；HUD 的目標與任務標記指「第一條還沒做完的」。第一章：docs/story/chapter-1.md
const MAIN_QUEST: String = "ch1_main"
const MAIN_QUESTS: PackedStringArray = [MAIN_QUEST]
const FIRST_CHAPTER: String = "ch1"
const FIRST_CHECKPOINT: String = "ch1_forest_gate"

var db: QuestDB
var save_dir: String
var state: GameState
var quests: QuestRunner
## 最近一次自動存檔的錯誤碼（給 UI 顯示「存檔失敗」用）
var last_autosave_error: Error = OK
var _autosave_pending: bool = false


func _init(p_db: QuestDB, p_save_dir: String = DEFAULT_SAVE_DIR) -> void:
	db = p_db
	save_dir = p_save_dir
	_bind(GameState.new())


## 新遊戲：開主線、進第一個檢查點（會自動存檔）。
func new_game() -> void:
	var s := GameState.new()
	s.mode = GameState.STORY_MODE
	s.chapter = FIRST_CHAPTER
	s.checkpoint = FIRST_CHECKPOINT
	_bind(s)
	quests.start(MAIN_QUEST)
	advance()


## 這個 session 有沒有開劇情（新遊戲或讀檔）。沒有＝空關卡（測試、benchmark）：不恢復生命、不寫存檔。
func in_story() -> bool:
	return state.mode == GameState.STORY_MODE


func set_flag(key: String, value: Variant) -> void:
	state.set_flag(key, value)
	advance()


func add_flag(key: String, amount: int = 1) -> void:
	StoryLogic.apply({"add": {key: amount}}, state)
	advance()


## 重新檢查任務條件；有進入新檢查點就自動存檔。
func advance() -> Array[Dictionary]:
	var changes: Array[Dictionary] = quests.evaluate()
	if _autosave_pending:
		_flush_autosave()
	return changes


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func has_save(slot: String = AUTO_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


func save(slot: String) -> Error:
	saving.emit(state)
	DirAccess.make_dir_recursive_absolute(save_dir)
	return SaveCodec.write_file(slot_path(slot), state)


## 讀檔成功回傳 SaveCodec.Status.OK，狀態與任務一併恢復。
func load_slot(slot: String) -> SaveCodec.Status:
	var r: Dictionary = SaveCodec.read_file(slot_path(slot))
	var status: SaveCodec.Status = int(r["status"]) as SaveCodec.Status
	if status != SaveCodec.Status.OK:
		return status
	_bind(r["state"] as GameState)
	# 讀檔不重新觸發自動存檔；若存檔後資料改版、條件已成立，照常推進。
	quests.evaluate()
	_autosave_pending = false
	return status


## 死亡重試：回到最近的自動存檔。
func retry_from_checkpoint() -> SaveCodec.Status:
	return load_slot(AUTO_SLOT)


func objective_key() -> String:
	return quests.objective_key(main_quest())


func hint_key() -> String:
	return quests.hint_key(main_quest())


## 主線全部做完了（目前做好的內容到底了）
func story_finished() -> bool:
	return quests.is_done(MAIN_QUESTS[MAIN_QUESTS.size() - 1])


## 目前的主線任務：MAIN_QUESTS 裡第一條還沒做完的；全部做完就是最後一條（沒有目標文字、沒有標記）。
func main_quest() -> String:
	for q: String in MAIN_QUESTS:
		if not quests.is_done(q):
			return q
	return MAIN_QUESTS[MAIN_QUESTS.size() - 1]


func _bind(new_state: GameState) -> void:
	state = new_state
	quests = QuestRunner.new(db, state)
	# 用方法而不是 lambda：lambda 會強參照 self，形成 GameSession ⇄ QuestRunner 的循環而洩漏。
	quests.checkpoint_reached.connect(_on_checkpoint)
	quests.stage_changed.connect(_on_stage_changed)
	quests.quest_completed.connect(_on_quest_completed)


func _on_checkpoint(checkpoint_id: String) -> void:
	_autosave_pending = true
	checkpoint_reached.emit(checkpoint_id)


func _on_stage_changed(quest_id: String, from_stage: String, to_stage: String) -> void:
	stage_changed.emit(quest_id, from_stage, to_stage)


func _on_quest_completed(quest_id: String) -> void:
	# 主線完成也自動存檔：還沒有下一章的檢查點時，重來、讀檔不會回到結尾之前
	if quest_id in MAIN_QUESTS:
		_autosave_pending = true
	quest_completed.emit(quest_id)


func _flush_autosave() -> void:
	_autosave_pending = false
	last_autosave_error = save(AUTO_SLOT)
	if last_autosave_error != OK:
		push_warning("自動存檔失敗：%s" % error_string(last_autosave_error))
