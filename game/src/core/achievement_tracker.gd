class_name AchievementTracker
extends RefCounted
## 成就（docs/steam/achievements.md、D-147）：帳號層級，跟存檔槽分開，存在 user://achievements.json。
## 條件跟任務的 done_when 同一套格式（StoryLogic），寫在 res://data/achievements.json，不寫死在程式裡。
##
## 只在「玩家這一局真的讓條件從不成立變成成立」時解鎖：
## - baseline(state)：新遊戲、讀檔、死亡重試時呼叫，記下哪些條件「已經成立」——這些先不算（讀舊存檔不會解鎖）
## - evaluate(state)：每次狀態改變時呼叫；條件不成立的先「上膛」，之後變成立才解鎖
## 已解鎖的永遠不會取消（讀舊存檔、重新開始都不影響）。
## store_path 空字串＝只在記憶體（開發旗標、測試；不會寫到玩家的檔案）。

signal unlocked(achievement_id: String)

const DEFAULT_DATA_PATH: String = "res://data/achievements.json"
const DEFAULT_STORE_PATH: String = "user://achievements.json"
const STORE_VERSION: int = 1

## [{id, hidden, when}]，照資料檔的順序
var defs: Array[Dictionary] = []
var store_path: String = ""
## 資料檔的錯誤（測試會擋）
var errors: PackedStringArray = []
## id -> 解鎖時間（ISO 字串）
var _unlocked: Dictionary = {}
## 這一局條件曾經不成立過的成就 id（之後變成立才解鎖）
var _armed: Dictionary = {}


func _init(p_defs: Array[Dictionary] = [], p_store_path: String = "") -> void:
	defs = p_defs
	store_path = p_store_path
	for d: Dictionary in defs:
		var err: String = StoryLogic.validate_condition(d.get("when", null))
		if str(d.get("id", "")) == "":
			errors.append("成就缺少 id")
		elif err != "":
			errors.append("%s：%s" % [d["id"], err])
	load_store()


static func load_defs(path: String = DEFAULT_DATA_PATH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string(path)
	var root: Variant = JSON.parse_string(text)
	if not root is Dictionary:
		push_error("AchievementTracker: 讀不到 %s" % path)
		return out
	for a: Variant in ((root as Dictionary).get("achievements", []) as Array):
		if a is Dictionary:
			out.append(a as Dictionary)
	return out


static func create(store: String = DEFAULT_STORE_PATH) -> AchievementTracker:
	return AchievementTracker.new(load_defs(), store)


func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for d: Dictionary in defs:
		out.append(str(d["id"]))
	return out


func def_of(achievement_id: String) -> Dictionary:
	for d: Dictionary in defs:
		if str(d["id"]) == achievement_id:
			return d
	return {}


func is_hidden(achievement_id: String) -> bool:
	return bool(def_of(achievement_id).get("hidden", false))


func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.has(achievement_id)


func unlocked_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in ids():
		if _unlocked.has(id):
			out.append(id)
	return out


static func name_key(achievement_id: String) -> String:
	return achievement_id + "_NAME"


static func desc_key(achievement_id: String) -> String:
	return achievement_id + "_DESC"


## 新遊戲／讀檔／重試：現在已經成立的條件不算（不是這一局做到的），不成立的上膛。
func baseline(state: GameState) -> void:
	_armed.clear()
	for d: Dictionary in defs:
		var id: String = str(d["id"])
		if not _unlocked.has(id) and not StoryLogic.check(d["when"] as Dictionary, state):
			_armed[id] = true


## 狀態改變後呼叫。回傳這次新解鎖的 id。
func evaluate(state: GameState) -> PackedStringArray:
	var out: PackedStringArray = []
	for d: Dictionary in defs:
		var id: String = str(d["id"])
		if _unlocked.has(id):
			continue
		if not StoryLogic.check(d["when"] as Dictionary, state):
			_armed[id] = true
		elif _armed.has(id) and unlock(id):
			out.append(id)
	return out


## 直接解鎖（已解鎖或沒有這個成就回傳 false）。
func unlock(achievement_id: String) -> bool:
	if _unlocked.has(achievement_id) or def_of(achievement_id).is_empty():
		return false
	_unlocked[achievement_id] = Time.get_datetime_string_from_system(true)
	_armed.erase(achievement_id)
	save_store()
	unlocked.emit(achievement_id)
	return true


func load_store() -> void:
	_unlocked.clear()
	if store_path == "" or not FileAccess.file_exists(store_path):
		return
	# JSON.new().parse：壞掉的檔案不要印引擎的 ERROR（玩家的檔案可能被別的程式改壞，這不是程式錯誤）
	var json := JSON.new()
	var root: Variant = json.data if json.parse(FileAccess.get_file_as_string(store_path)) == OK else null
	if not root is Dictionary:
		push_warning("AchievementTracker: %s 壞掉了，當作沒有解鎖" % store_path)
		return
	var d: Dictionary = root as Dictionary
	if int(d.get("version", 0)) > STORE_VERSION:
		push_warning("AchievementTracker: %s 是較新版本的遊戲寫的，照樣讀已解鎖清單" % store_path)
	# 不認得的 id（較新版本加的成就）也留著，存回去時不會弄丟；清單只列認得的
	var u: Variant = d.get("unlocked", {})
	if u is Dictionary:
		for k: Variant in (u as Dictionary):
			_unlocked[str(k)] = str((u as Dictionary)[k])


func save_store() -> Error:
	if store_path == "":
		return OK
	DirAccess.make_dir_recursive_absolute(store_path.get_base_dir())
	var tmp: String = store_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": STORE_VERSION, "unlocked": _unlocked}, "  "))
	f.close()
	return DirAccess.rename_absolute(tmp, store_path)
