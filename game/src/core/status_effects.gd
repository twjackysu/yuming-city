class_name StatusEffects
extends RefCounted
## 身上的持續狀態。純邏輯：擁有者每個物理幀呼叫 tick(delta, health)；
## 暫停、對話、過場時不呼叫＝不計時。
## 規則（docs/design/02-gameplay.md「異常狀態與反轉」）：
## - 同一種狀態只有一份：新來源比較強就換強度；時間取剩下的與新的較長者；不超過 max_duration。
## - 會反轉的人（reverses）身上的狀態**全部**反轉，而且發生在扣血之前：每幀直接變成好處（中毒 → 回血），不先扣再補。
## - 反轉後的好處有上限（max_reversed_rate）。直接傷害不歸這裡管（Health.apply_damage）。
## - 每一份狀態記得來源、強度、剩餘時間；存檔照原樣存（讀檔不補滿、不清掉）。

const PARALYSIS: String = "paralysis"

## event："start"（新上身）、"refresh"（同種刷新）、"end"（時間到）、"clear"（被清掉）
signal changed(status_id: String, event: String)

var rules: StatusRules
## 這個人身上的異常狀態會不會反轉成好處。諾恩（【逆理之器】）＝true：落在他身上的每一種都反轉，沒有條件、沒有代價；
## 其他人（敵人、NPC）＝false：照原樣吃。
var reverses: bool = false
## 「養」：已經在身上的持續傷害類狀態（中毒）每再上一次，剩餘時間多加這麼多秒（還是不超過 max_duration）。
## 0＝取剩下的與新的較長者。PlayerController 每幀從 `noen.status_refresh_gain` 寫進來：
## 瘴氣每 0.25 秒上一次，所以站在裡面越久身上的毒越多秒——「釋放」的威力看的就是這個秒數。
var refresh_gain: float = 0.0
## 反轉之後的好處乘幾成（`noen.reversed_heal_scale`）：留著毒只是慢慢補，大的好處要自己按「釋放」去拿。
var reversed_scale: float = 1.0
## status_id -> {"rate": float, "remaining": float, "source": String}
var _active: Dictionary = {}


func _init(p_rules: StatusRules = null, p_reverses: bool = false) -> void:
	rules = p_rules if p_rules != null else StatusRules.load_default()
	reverses = p_reverses


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


## 麻痺沒有反轉的時候：這段時間不能出手（動作被打斷）。
func blocks_attack() -> bool:
	return has(PARALYSIS) and not reverses


## 出手的速度倍率：麻痺被反轉時＝它的強度（不超過 max_reversed_rate；同一種只有一份，所以不會越疊越快）；其他時候 1。
## 只加快自己的出手，不加快別的計時。
func attack_speed() -> float:
	if not has(PARALYSIS) or not reverses:
		return 1.0
	return clampf(rate(PARALYSIS), 1.0, maxf(rules.max_reversed_rate(PARALYSIS), 1.0))


## 上狀態。回傳 "start"／"refresh"／"ignored"（強度或時間不合法）。
func apply(status_id: String, p_rate: float, duration: float, source: String = "") -> String:
	if p_rate <= 0.0 or duration <= 0.0 or not rules.statuses.has(status_id):
		return "ignored"
	var cap: float = rules.max_duration(status_id)
	var event: String = "start"
	if _active.has(status_id):
		event = "refresh"
		var cur: Dictionary = _active[status_id] as Dictionary
		if p_rate > float(cur["rate"]):
			cur["rate"] = p_rate
			cur["source"] = source
		var want: float = maxf(float(cur["remaining"]), duration)
		if refresh_gain > 0.0 and rules.kind(status_id) == "dot":
			want = maxf(float(cur["remaining"]) + refresh_gain, duration)
		cur["remaining"] = minf(want, cap)
	else:
		_active[status_id] = {"rate": p_rate, "remaining": minf(duration, cap), "source": source}
	changed.emit(status_id, event)
	return event


## 用資料表裡的來源（"miasma"、"boss_miasma"）上狀態
func apply_source(source_id: String) -> String:
	var src: Dictionary = rules.source(source_id)
	if src.is_empty():
		return "ignored"
	return apply(str(src["status"]), float(src["rate"]), float(src["duration"]), source_id)


func clear(status_id: String) -> void:
	if _active.erase(status_id):
		changed.emit(status_id, "clear")


## 把一種狀態整個用掉（釋放）：回傳用掉幾秒（身上沒有＝0）。之後身上就沒有這個狀態了。
func consume(status_id: String) -> float:
	if not _active.has(status_id):
		return 0.0
	var left: float = maxf(remaining(status_id), 0.0)
	_active.erase(status_id)
	changed.emit(status_id, "clear")
	return left


## 推進 delta 秒。health 為 null 時只計時（例如測試）。
func tick(delta: float, health: Health) -> void:
	if delta <= 0.0 or _active.is_empty():
		return
	var ended: PackedStringArray = []
	for k: Variant in _active.keys():
		var id: String = str(k)
		var cur: Dictionary = _active[id] as Dictionary
		var dt: float = minf(delta, float(cur["remaining"]))
		# 麻痺這一類（kind=action）不碰生命：只計時，效果由 attack_speed()／blocks_attack() 問
		if health != null and dt > 0.0 and rules.kind(id) == "dot":
			var info: Dictionary = {"status": id, "source": cur["source"]}
			if reverses:
				var capped: float = minf(float(cur["rate"]), rules.max_reversed_rate(id))
				info["reversed"] = true
				health.heal(capped * reversed_scale * dt, info)
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


## 讀檔：照存的恢復（不補滿、不清掉）；不認得的狀態、壞值略過。
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
