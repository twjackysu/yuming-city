class_name DialogueRunner
extends RefCounted
## 跑一段對話：顯示台詞、依條件過濾選項、套用效果。純邏輯，UI（字幕、選項）只聽訊號。
## 效果只透過 StoryLogic 改 GameState；效果套用後發出 state_changed，由外殼呼叫 GameSession.advance()
## 讓任務推進（例如對話結束時設 slice.met_pear_seller）。

signal line_shown(speaker_key: String, text_key: String)
signal choices_shown(choices: Array[Dictionary])
signal state_changed
signal finished(dialogue_id: String)

var db: DialogueDB
var state: GameState
var dialogue_id: String = ""
var node_id: String = ""
## 目前可選的選項（已依 if 過濾）：[{text, next, do?, index}]
var visible_choices: Array[Dictionary] = []


func _init(p_db: DialogueDB, p_state: GameState) -> void:
	db = p_db
	state = p_state


func is_running() -> bool:
	return node_id != ""


func start(p_dialogue_id: String) -> bool:
	if not db.has_dialogue(p_dialogue_id):
		push_error("DialogueRunner: 沒有對話 %s" % p_dialogue_id)
		return false
	dialogue_id = p_dialogue_id
	_enter(db.start_node(dialogue_id))
	return true


func current() -> Dictionary:
	return db.node(dialogue_id, node_id) if is_running() else {}


## 目前這句的翻譯 key：text_if 裡第一個條件成立的，否則 text。
func current_text() -> String:
	return text_for(current(), state)


static func text_for(n: Dictionary, st: GameState) -> String:
	for v: Variant in (n.get("text_if", []) as Array):
		var d: Dictionary = v as Dictionary
		if StoryLogic.check(d["if"] as Dictionary, st):
			return str(d["text"])
	return str(n.get("text", ""))


## 台詞看完（沒有選項時）往下走；有選項時要用 choose()。回傳是否還在對話中。
func advance() -> bool:
	if not is_running():
		return false
	if not visible_choices.is_empty():
		return true
	var n: Dictionary = current()
	if n.has("next"):
		_enter(str(n["next"]))
	else:
		_finish()
	return is_running()


## 選第 i 個「可見」選項。回傳是否成功。
func choose(i: int) -> bool:
	if i < 0 or i >= visible_choices.size():
		return false
	var c: Dictionary = visible_choices[i]
	if c.has("do"):
		StoryLogic.apply(c["do"] as Dictionary, state)
		state_changed.emit()
	_enter(str(c["next"]))
	return true


## 跳過：一路往下走到下一個選項或結束（不跳過選項，效果照樣套用）。
func skip_to_choice() -> void:
	var guard: int = 0
	while is_running() and visible_choices.is_empty() and guard < 256:
		advance()
		guard += 1


func _enter(p_node_id: String) -> void:
	node_id = p_node_id
	var n: Dictionary = current()
	if n.has("do"):
		StoryLogic.apply(n["do"] as Dictionary, state)
		state_changed.emit()
	visible_choices = []
	var index: int = 0
	for c: Variant in (n.get("choices", []) as Array):
		var ch: Dictionary = (c as Dictionary).duplicate()
		ch["index"] = index
		index += 1
		if not ch.has("if") or StoryLogic.check(ch["if"] as Dictionary, state):
			visible_choices.append(ch)
	line_shown.emit(str(n["speaker"]), text_for(n, state))
	if not visible_choices.is_empty():
		choices_shown.emit(visible_choices)


func _finish() -> void:
	var id: String = dialogue_id
	node_id = ""
	visible_choices = []
	finished.emit(id)
