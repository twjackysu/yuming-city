class_name QuestRunner
extends RefCounted
## 依旗標推進任務階段。所有狀態都在 GameState.quests（quest_id -> 階段 id），
## 所以讀檔後重建 QuestRunner 就能恢復到同一階段，不需要另外存。

signal stage_changed(quest_id: String, from_stage: String, to_stage: String)
signal quest_completed(quest_id: String)
signal checkpoint_reached(checkpoint_id: String)

## 一次 evaluate 最多推進的步數（防止資料寫錯造成無窮迴圈）
const MAX_STEPS: int = 256

var db: QuestDB
var state: GameState


func _init(p_db: QuestDB, p_state: GameState) -> void:
	db = p_db
	state = p_state


## 開始任務（已開始或已完成就不動）。回傳是否真的開始。
func start(quest_id: String) -> bool:
	if not db.has_quest(quest_id):
		push_error("QuestRunner: 沒有任務 %s" % quest_id)
		return false
	if state.quests.has(quest_id):
		return false
	_enter(quest_id, "", db.first_stage_id(quest_id))
	return true


func stage_of(quest_id: String) -> String:
	return str(state.quests.get(quest_id, ""))


func is_active(quest_id: String) -> bool:
	var s: String = stage_of(quest_id)
	return s != "" and s != StoryLogic.QUEST_DONE


func is_done(quest_id: String) -> bool:
	return stage_of(quest_id) == StoryLogic.QUEST_DONE


## 目前階段的目標文字 key；沒有進行中的階段回傳空字串。
func objective_key(quest_id: String) -> String:
	if not is_active(quest_id):
		return ""
	var st: Dictionary = db.stage(quest_id, stage_of(quest_id))
	for alt: Variant in (st.get("objective_if", []) as Array):
		var a: Dictionary = alt as Dictionary
		if StoryLogic.check(a["when"] as Dictionary, state):
			return str(a["objective"])
	return str(st.get("objective", ""))


## 目前階段的操作提示（翻譯 key）；沒有就回傳空字串。
func hint_key(quest_id: String) -> String:
	if not is_active(quest_id):
		return ""
	return str(db.stage(quest_id, stage_of(quest_id)).get("hint", ""))


## 目前階段的目標指引（QuestDB.validate_marker 的格式）；marker_if 第一個成立的優先。沒有就回傳 null。
func marker_spec(quest_id: String) -> Variant:
	if not is_active(quest_id):
		return null
	var st: Dictionary = db.stage(quest_id, stage_of(quest_id))
	for alt: Variant in (st.get("marker_if", []) as Array):
		var a: Dictionary = alt as Dictionary
		if StoryLogic.check(a["when"] as Dictionary, state):
			return a["marker"]
	return st.get("marker", null)


## 檢查所有進行中的任務，條件成立就推進（可以一次推進多個階段）。
## 回傳本次推進的紀錄：[{quest, from, to}]
func evaluate() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	var steps: int = 0
	var progressed: bool = true
	while progressed and steps < MAX_STEPS:
		progressed = false
		var ids: Array = state.quests.keys()
		ids.sort()
		for qid: Variant in ids:
			var quest_id: String = str(qid)
			if not is_active(quest_id) or not db.has_quest(quest_id):
				continue
			var current: String = stage_of(quest_id)
			var st: Dictionary = db.stage(quest_id, current)
			if st.is_empty():
				push_error("QuestRunner: %s 的階段 %s 不存在（存檔資料過舊？）" % [quest_id, current])
				continue
			if not StoryLogic.check(st["done_when"] as Dictionary, state):
				continue
			_apply(st.get("on_done", {}) as Dictionary)
			var nxt: String = db.next_stage_id(quest_id, current)
			_enter(quest_id, current, nxt)
			changes.append({"quest": quest_id, "from": current, "to": nxt})
			progressed = true
			steps += 1
	if steps >= MAX_STEPS:
		push_error("QuestRunner: 推進超過 %d 步，任務資料可能有循環" % MAX_STEPS)
	return changes


func _enter(quest_id: String, from_stage: String, to_stage: String) -> void:
	state.quests[quest_id] = to_stage
	stage_changed.emit(quest_id, from_stage, to_stage)
	if to_stage == StoryLogic.QUEST_DONE:
		var q: Dictionary = db.quests[quest_id] as Dictionary
		_apply(q.get("on_complete", {}) as Dictionary)
		quest_completed.emit(quest_id)
		return
	var st: Dictionary = db.stage(quest_id, to_stage)
	if st.has("checkpoint"):
		state.checkpoint = str(st["checkpoint"])
		checkpoint_reached.emit(state.checkpoint)


func _apply(effects: Dictionary) -> void:
	StoryLogic.apply(effects, state)
	for qid: Variant in (effects.get("start_quest", []) as Array):
		start(str(qid))
