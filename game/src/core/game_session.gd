class_name GameSession
extends RefCounted
## 一局遊戲：GameState＋QuestRunner＋存讀檔與檢查點。純邏輯，autoload「Game」只是它的外殼。
## 規則（docs/design/04-architecture.md）：
## - 場景只透過 set_flag／add_flag 等方法改狀態，不直接改存檔。
## - 進入有 checkpoint 的任務階段時自動存檔到 auto；死亡重試＝重讀 auto。

signal checkpoint_reached(checkpoint_id: String)
signal stage_changed(quest_id: String, from_stage: String, to_stage: String)
signal quest_completed(quest_id: String)
## 要寫存檔之前（新版：玩家把生命、狀態、反轉欄位寫回 state，D-202）
signal saving(state: GameState)

const AUTO_SLOT: String = "auto"
const MANUAL_SLOTS: PackedStringArray = ["slot1", "slot2", "slot3"]
const DEFAULT_SAVE_DIR: String = "user://saves"
## 新版（劇情重寫）的存檔放另一個資料夾：舊版存檔不會被新版寫到（D-202）
const REBOOT_SAVE_DIR: String = "user://saves_reboot"
## 新版的主線（docs/design/09-reboot-first-ten-minutes.md）
const REBOOT_MAIN_QUEST: String = "rb_main"
const REBOOT_CHAPTER: String = "rb_ch1"

var db: QuestDB
## 舊版的存檔資料夾；新版用 reboot_save_dir()（另一個資料夾）
var save_dir: String
## true＝存讀檔走新版的資料夾（new_reboot_game／load_reboot_slot 設定）
var use_reboot_saves: bool = false
var state: GameState
var quests: QuestRunner
## 最近一次自動存檔的錯誤碼（給 UI 顯示「存檔失敗」用）
var last_autosave_error: Error = OK
var _autosave_pending: bool = false


func _init(p_db: QuestDB, p_save_dir: String = DEFAULT_SAVE_DIR) -> void:
	db = p_db
	save_dir = p_save_dir
	_bind(GameState.new())


## 新遊戲：mode="reboot"、主線 rb_main、存檔寫到 reboot_save_dir()（D-202；舊劇情的入口第 77 輪刪了，D-220）。
func new_reboot_game() -> void:
	use_reboot_saves = true
	var s := GameState.new()
	s.mode = "reboot"
	s.chapter = REBOOT_CHAPTER
	s.checkpoint = "rb_start"
	_bind(s)
	quests.start(REBOOT_MAIN_QUEST)
	advance()


func is_reboot() -> bool:
	return state.mode == "reboot"


## 新版的存檔資料夾：正式是 REBOOT_SAVE_DIR；測試自己給了資料夾時放在旁邊（<資料夾>_reboot），不會寫到真的 user://
func reboot_save_dir() -> String:
	return REBOOT_SAVE_DIR if save_dir == DEFAULT_SAVE_DIR else save_dir + "_reboot"


func active_save_dir() -> String:
	return reboot_save_dir() if use_reboot_saves else save_dir


## 新版有沒有存檔（標題畫面的「繼續」；不改變現在讀寫哪個資料夾）
func has_reboot_save(slot: String = AUTO_SLOT) -> bool:
	var path: String = reboot_save_dir().path_join(slot + ".json")
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## 讀新版的存檔（標題畫面的「繼續」用）
func load_reboot_slot(slot: String = AUTO_SLOT) -> SaveCodec.Status:
	var was: bool = use_reboot_saves
	use_reboot_saves = true
	var status: SaveCodec.Status = load_slot(slot)
	if status != SaveCodec.Status.OK:
		use_reboot_saves = was
	return status


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
	return active_save_dir().path_join(slot + ".json")


func has_save(slot: String = AUTO_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


func save(slot: String) -> Error:
	saving.emit(state)
	DirAccess.make_dir_recursive_absolute(active_save_dir())
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


## 目前的主線任務（只有一條；之後有第二章再擴充）
func main_quest() -> String:
	return REBOOT_MAIN_QUEST


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
	if quest_id == REBOOT_MAIN_QUEST:
		_autosave_pending = true
	quest_completed.emit(quest_id)


func _flush_autosave() -> void:
	_autosave_pending = false
	last_autosave_error = save(AUTO_SLOT)
	if last_autosave_error != OK:
		push_warning("自動存檔失敗：%s" % error_string(last_autosave_error))
