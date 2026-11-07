class_name CutsceneRunner
extends RefCounted
## 過場（可互動演出）的純邏輯：一串鏡頭，每個鏡頭有時長或等待玩家輸入。
## 資料放 game/data/cutscenes/*.json（格式見 CutsceneRunner.validate）：
##   {"id": "...", "shots": [
##      {"camera": "Marker 名", "duration": 秒, "speaker": "SPK_*", "line": "CUT_*", "event": "名稱", "shake": 0..1,
##       "effects": {...StoryLogic 效果}},
##      {"camera": "...", "await": "interact", "prompt": "CUT_PROMPT_*", "event": "ring", "effects": {...}}],
##    "on_end": {...StoryLogic 效果}}
## 規則（讓跳過永遠安全）：狀態只由 effects／on_end 改變；event 只給畫面與聲音用。
## 時長鏡頭在開始時觸發 event 與 effects；等待鏡頭在玩家按下時觸發。
## 跳過＝把目前與之後所有鏡頭還沒套用的 effects 依序套用，再套 on_end；被跳過的 event 不會發出。

signal shot_started(index: int, shot: Dictionary)
signal event_fired(event: String, shot: Dictionary)
signal state_changed
signal finished(cutscene_id: String, skipped: bool)

const DIR: String = "res://data/cutscenes"

var id: String = ""
var data: Dictionary = {}
var index: int = -1
var time_in_shot: float = 0.0
var _state: GameState
var _applied: bool = false
var _running: bool = false


static func load_cutscene(cutscene_id: String) -> Dictionary:
	var path: String = DIR.path_join(cutscene_id + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## 回傳錯誤清單（空＝正確）。
static func validate(d: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var cid: String = str(d.get("id", ""))
	if cid == "":
		errors.append("缺 id")
	var shots: Variant = d.get("shots", null)
	if not shots is Array or (shots as Array).is_empty():
		errors.append("%s：shots 要是非空陣列" % cid)
		return errors
	var i: int = 0
	for raw: Variant in (shots as Array):
		var where: String = "%s.shots[%d]" % [cid, i]
		i += 1
		if not raw is Dictionary:
			errors.append(where + " 不是物件")
			continue
		var shot: Dictionary = raw as Dictionary
		if str(shot.get("camera", "")) == "":
			errors.append(where + " 缺 camera")
		var has_await: bool = shot.has("await")
		var dur: float = float(shot.get("duration", 0.0))
		if has_await == (dur > 0.0):
			errors.append(where + " 要有 duration（>0）或 await，二選一")
		if has_await and not InputSetup.BINDINGS.has(str(shot["await"])):
			errors.append(where + " await 不是遊戲動作：" + str(shot["await"]))
		if has_await and str(shot.get("prompt", "")) == "":
			errors.append(where + " 等待輸入的鏡頭要有 prompt")
		if shot.has("effects"):
			var e: String = StoryLogic.validate_effects(shot["effects"])
			if e != "":
				errors.append(where + " effects：" + e)
	if d.has("on_end"):
		var e2: String = StoryLogic.validate_effects(d["on_end"])
		if e2 != "":
			errors.append(cid + ".on_end：" + e2)
	return errors


## 過場用到的所有翻譯 key（測試檢查用）。
static func text_keys(d: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = []
	for shot: Variant in (d.get("shots", []) as Array):
		for field: String in ["speaker", "line", "prompt"]:
			var k: String = str((shot as Dictionary).get(field, ""))
			if k != "" and not keys.has(k):
				keys.append(k)
	return keys


func _init(state: GameState) -> void:
	_state = state


func start(cutscene_id: String, override_data: Dictionary = {}) -> bool:
	data = override_data if not override_data.is_empty() else load_cutscene(cutscene_id)
	if data.is_empty() or not validate(data).is_empty():
		push_error("CutsceneRunner: 過場 %s 不存在或格式錯誤 %s" % [cutscene_id, validate(data)])
		return false
	id = cutscene_id
	_running = true
	index = -1
	_next()
	return true


func is_running() -> bool:
	return _running


func current() -> Dictionary:
	var shots: Array = data.get("shots", []) as Array
	if index < 0 or index >= shots.size():
		return {}
	return shots[index] as Dictionary


func is_waiting() -> bool:
	return _running and current().has("await")


func awaited_action() -> String:
	return str(current().get("await", "")) if is_waiting() else ""


## 每幀呼叫（Game._process）。等待輸入的鏡頭不會因時間結束。
func update(delta: float) -> void:
	if not _running or is_waiting():
		return
	time_in_shot += delta
	if time_in_shot >= float(current().get("duration", 0.0)):
		_next()


## 玩家按下某個動作；是目前鏡頭等待的動作就觸發並往下。回傳是否有用掉。
func press(action: String) -> bool:
	if not is_waiting() or awaited_action() != action:
		return false
	_trigger_current(true)
	_next()
	return true


func skip() -> void:
	if not _running:
		return
	var shots: Array = data.get("shots", []) as Array
	var changed: bool = false
	if not _applied and index >= 0:
		changed = _apply(current().get("effects", {}) as Dictionary) or changed
	for i: int in range(index + 1, shots.size()):
		changed = _apply((shots[i] as Dictionary).get("effects", {}) as Dictionary) or changed
	index = shots.size()
	_finish(true, changed)


func _next() -> void:
	var shots: Array = data.get("shots", []) as Array
	index += 1
	time_in_shot = 0.0
	_applied = false
	if index >= shots.size():
		_finish(false, false)
		return
	shot_started.emit(index, current())
	if not current().has("await"):
		_trigger_current(true)


func _trigger_current(emit_event: bool) -> void:
	if _applied:
		return
	var shot: Dictionary = current()
	if emit_event and str(shot.get("event", "")) != "":
		event_fired.emit(str(shot["event"]), shot)
	if _apply(shot.get("effects", {}) as Dictionary):
		state_changed.emit()
	_applied = true


func _apply(effects: Dictionary) -> bool:
	if effects.is_empty():
		return false
	StoryLogic.apply(effects, _state)
	return true


func _finish(skipped: bool, changed: bool) -> void:
	_running = false
	var end_changed: bool = _apply(data.get("on_end", {}) as Dictionary)
	if changed or end_changed:
		state_changed.emit()
	finished.emit(id, skipped)
