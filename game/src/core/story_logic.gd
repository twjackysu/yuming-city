class_name StoryLogic
extends RefCounted
## 任務與對話共用的條件與效果（D-013）。只能讀寫 GameState 的旗標與記憶，不執行任意程式。
##
## 條件：
##   {"flag": "k"}                       旗標為真（存在且不是 false／0／""）
##   {"flag": "k", "eq"|"ne"|"gte"|"lte"|"gt"|"lt": v}
##   {"memory_paid": "id"}
##   {"quest": "id", "stage": "s"} 或 {"quest": "id", "done": true}
##   {"guide": "id", "is": "unwritten|sure|unsure|wrong|confirmed"}（可加 "was_unsure": true/false：寫下時有沒有標我不確定）
##   {"all": [...]}／{"any": [...]}／{"not": {...}}
##   空字典＝永遠成立
## 效果：
##   {"set": {"k": v, ...}, "add": {"k": n, ...}}
##   {"guide_write": ["id", ...]}           寫下攻略筆記條目（已寫過的不動）
##   （"start_quest" 由 QuestRunner 處理）

const QUEST_DONE: String = "_done"
const COMPARE_OPS: PackedStringArray = ["eq", "ne", "gte", "lte", "gt", "lt"]
const EFFECT_KEYS: PackedStringArray = ["set", "add", "start_quest", "guide_write"]


static func check(cond: Dictionary, state: GameState) -> bool:
	if cond.is_empty():
		return true
	if cond.has("all"):
		for sub: Variant in (cond["all"] as Array):
			if not check(sub as Dictionary, state):
				return false
		return true
	if cond.has("any"):
		for sub: Variant in (cond["any"] as Array):
			if check(sub as Dictionary, state):
				return true
		return false
	if cond.has("not"):
		return not check(cond["not"] as Dictionary, state)
	if cond.has("memory_paid"):
		return state.has_paid_memory(str(cond["memory_paid"]))
	if cond.has("guide"):
		var gid: String = str(cond["guide"])
		if cond.has("was_unsure") and GuideNotes.was_unsure(state, gid) != bool(cond["was_unsure"]):
			return false
		return GuideNotes.status(state, gid) == str(cond.get("is", GuideNotes.SURE))
	if cond.has("quest"):
		var stage: String = str(state.quests.get(str(cond["quest"]), ""))
		if cond.has("done"):
			return (stage == QUEST_DONE) == bool(cond["done"])
		return stage == str(cond.get("stage", ""))
	if cond.has("flag"):
		var value: Variant = state.get_flag(str(cond["flag"]))
		for op: String in COMPARE_OPS:
			if cond.has(op):
				return _compare(value, op, cond[op])
		return _truthy(value)
	push_warning("StoryLogic: 無法辨識的條件 %s" % JSON.stringify(cond))
	return false


static func apply(effects: Dictionary, state: GameState) -> void:
	var sets: Dictionary = effects.get("set", {}) as Dictionary
	for key: String in sets:
		state.set_flag(key, sets[key])
	var adds: Dictionary = effects.get("add", {}) as Dictionary
	for key: String in adds:
		var current: float = _to_number(state.get_flag(key, 0))
		var total: float = current + _to_number(adds[key])
		# 整數保持整數，避免存讀檔後顯示成 3.0
		if is_equal_approx(total, roundf(total)):
			state.set_flag(key, int(roundf(total)))
		else:
			state.set_flag(key, total)
	var written: Variant = effects.get("guide_write", [])
	if written is Array:
		GuideNotes.write(state, PackedStringArray(written as Array))


## 回傳錯誤訊息；空字串代表格式正確。
static func validate_condition(cond: Variant) -> String:
	if not cond is Dictionary:
		return "條件必須是物件"
	var d: Dictionary = cond as Dictionary
	if d.is_empty():
		return ""
	for list_key: String in ["all", "any"]:
		if d.has(list_key):
			if not d[list_key] is Array or (d[list_key] as Array).is_empty():
				return "%s 必須是非空陣列" % list_key
			for sub: Variant in (d[list_key] as Array):
				var err: String = validate_condition(sub)
				if err != "":
					return err
			return ""
	if d.has("not"):
		return validate_condition(d["not"])
	if d.has("memory_paid"):
		return "" if str(d["memory_paid"]) != "" else "memory_paid 不可為空"
	if d.has("quest"):
		return "" if d.has("stage") or d.has("done") else "quest 條件需要 stage 或 done"
	if d.has("guide"):
		return "" if GuideNotes.STATUSES.has(str(d.get("is", ""))) else "guide 條件的 is 必須是 %s" % "／".join(GuideNotes.STATUSES)
	if d.has("flag"):
		var ops: int = 0
		for op: String in COMPARE_OPS:
			if d.has(op):
				ops += 1
		return "" if ops <= 1 else "flag 條件只能有一個比較運算"
	return "無法辨識的條件：%s" % JSON.stringify(d)


static func validate_effects(effects: Variant) -> String:
	if not effects is Dictionary:
		return "效果必須是物件"
	for key: String in (effects as Dictionary):
		if not EFFECT_KEYS.has(key):
			return "無法辨識的效果：%s" % key
	return ""


static func _truthy(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value as bool
		TYPE_INT, TYPE_FLOAT:
			return not is_zero_approx(float(value))
		TYPE_STRING:
			return (value as String) != ""
	return true


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _to_number(value: Variant) -> float:
	return float(value) if _is_number(value) else 0.0


## 數字一律用 float 比較（JSON 讀回的整數會變成 float）。
static func _compare(value: Variant, op: String, target: Variant) -> bool:
	if _is_number(target) or _is_number(value):
		if value == null:
			value = 0
		if not (_is_number(value) and _is_number(target)):
			return op == "ne"
		var a: float = float(value)
		var b: float = float(target)
		match op:
			"eq":
				return is_equal_approx(a, b)
			"ne":
				return not is_equal_approx(a, b)
			"gte":
				return a >= b or is_equal_approx(a, b)
			"lte":
				return a <= b or is_equal_approx(a, b)
			"gt":
				return a > b and not is_equal_approx(a, b)
			"lt":
				return a < b and not is_equal_approx(a, b)
	match op:
		"eq":
			return typeof(value) == typeof(target) and value == target
		"ne":
			return not (typeof(value) == typeof(target) and value == target)
	return false
