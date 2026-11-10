class_name StatusEffects
extends RefCounted
## 身上的持續狀態（新版，D-202）。純邏輯：擁有者每個物理幀呼叫 tick(delta, health)；
## 暫停、對話、過場時不呼叫＝不計時。
## 規則（docs/design/09-reboot-first-ten-minutes.md 第 3 節、docs/story-reboot/status-reversal.md）：
## - 同一種狀態只有一份：新來源比較強就換強度；時間取剩下的與新的較長者；不超過 max_duration。
## - 反轉發生在扣血之前：裝進反轉欄位的狀態每幀直接變成好處（中毒 → 回血），不先扣再補。
## - 反轉後的好處有上限（max_reversed_rate）。直接傷害不歸這裡管（Health.apply_damage）。
## - 每一份狀態記得來源、強度、剩餘時間；存檔照原樣存（讀檔不補滿、不清掉）。

## event："start"（新上身）、"refresh"（同種刷新）、"end"（時間到）、"clear"（被清掉）
signal changed(status_id: String, event: String)

var rules: StatusRules
## 擁有者的反轉欄位；null＝這個角色沒有反轉（NPC、敵人）
var reversal: ReversalSlots = null
## status_id -> {"rate": float, "remaining": float, "source": String}
var _active: Dictionary = {}


func _init(p_rules: StatusRules = null, p_reversal: ReversalSlots = null) -> void:
	rules = p_rules if p_rules != null else StatusRules.load_default()
	reversal = p_reversal


func has(status_id: String) -> bool:
	return _active.has(status_id)


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in _active:
		out.append(str(k))
	return out


func remaining(status_id: String) -> float:
	return float((_active.get(status_id, {}) as Dictionary).get("remaining", 0.0))


func rate(status_id: String) -> float:
	return float((_active.get(status_id, {}) as Dictionary).get("rate", 0.0))


func source_of(status_id: String) -> String:
	return str((_active.get(status_id, {}) as Dictionary).get("source", ""))


func is_reversed(status_id: String) -> bool:
	return reversal != null and reversal.is_reversed(status_id)


## 上狀態。回傳 "start"／"refresh"／"ignored"（強度或時間不合法）。
## 第一次中毒會先讓反轉欄位覺醒（D-202），所以第一幀起就是回血。
func apply(status_id: String, p_rate: float, duration: float, source: String = "") -> String:
	if p_rate <= 0.0 or duration <= 0.0 or not rules.statuses.has(status_id):
		return "ignored"
	if reversal != null:
		reversal.on_status_applied(status_id)
	var cap: float = rules.max_duration(status_id)
	var event: String = "start"
	if _active.has(status_id):
		event = "refresh"
		var cur: Dictionary = _active[status_id] as Dictionary
		if p_rate > float(cur["rate"]):
			cur["rate"] = p_rate
			cur["source"] = source
		cur["remaining"] = minf(maxf(float(cur["remaining"]), duration), cap)
	else:
		_active[status_id] = {"rate": p_rate, "remaining": minf(duration, cap), "source": source}
	changed.emit(status_id, event)
	return event


## 用資料表裡的來源（"barrel_mist"、"guardian_spray"）上狀態
func apply_source(source_id: String) -> String:
	var src: Dictionary = rules.source(source_id)
	if src.is_empty():
		return "ignored"
	return apply(str(src["status"]), float(src["rate"]), float(src["duration"]), source_id)


func clear(status_id: String) -> void:
	if _active.erase(status_id):
		changed.emit(status_id, "clear")


## 推進 delta 秒。health 為 null 時只計時（例如測試）。
func tick(delta: float, health: Health) -> void:
	if delta <= 0.0 or _active.is_empty():
		return
	var ended: PackedStringArray = []
	for k: Variant in _active.keys():
		var id: String = str(k)
		var cur: Dictionary = _active[id] as Dictionary
		var dt: float = minf(delta, float(cur["remaining"]))
		if health != null and dt > 0.0:
			var info: Dictionary = {"status": id, "source": cur["source"]}
			if is_reversed(id):
				var capped: float = minf(float(cur["rate"]), rules.max_reversed_rate(id))
				info["reversed"] = true
				health.heal(capped * dt, info)
			else:
				health.apply_status_damage(float(cur["rate"]) * dt, info)
		cur["remaining"] = float(cur["remaining"]) - delta
		if float(cur["remaining"]) <= 0.0:
			ended.append(id)
	for id: String in ended:
		_active.erase(id)
		changed.emit(id, "end")


func to_array() -> Array:
	var out: Array = []
	for k: Variant in _active:
		var cur: Dictionary = _active[k] as Dictionary
		out.append({"id": str(k), "rate": cur["rate"], "remaining": cur["remaining"], "source": cur["source"]})
	return out


## 讀檔：照存的恢復（不補滿、不清掉）；不認得的狀態、壞值略過，也不會觸發覺醒。
func load_array(arr: Array) -> void:
	_active.clear()
	for v: Variant in arr:
		if not v is Dictionary:
			continue
		var d: Dictionary = v as Dictionary
		var id: String = str(d.get("id", ""))
		var r: float = float(d.get("rate", 0.0))
		var rem: float = minf(float(d.get("remaining", 0.0)), rules.max_duration(id))
		if rules.statuses.has(id) and r > 0.0 and rem > 0.0:
			_active[id] = {"rate": r, "remaining": rem, "source": str(d.get("source", ""))}
