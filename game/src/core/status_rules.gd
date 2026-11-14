class_name StatusRules
extends RefCounted
## 狀態規則的資料：狀態定義、來源（瘴氣、史萊姆、席菈的藥瓶…）、可攜藥劑。
## 資料在 res://data/status/statuses.json；數值說明見 docs/design/13-chapter-1-plan.md。

const DEFAULT_PATH: String = "res://data/status/statuses.json"

static var _default: StatusRules = null

var statuses: Dictionary = {}
var sources: Dictionary = {}
var items: Dictionary = {}
var errors: PackedStringArray = []


static func load_default() -> StatusRules:
	if _default == null:
		_default = load_file(DEFAULT_PATH)
	return _default


static func load_file(path: String) -> StatusRules:
	var r := StatusRules.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		r.errors.append("讀不到 %s" % path)
		return r
	var root: Dictionary = json.data as Dictionary
	r.statuses = (root.get("statuses", {}) as Dictionary).duplicate(true)
	r.sources = (root.get("sources", {}) as Dictionary).duplicate(true)
	r.items = (root.get("items", {}) as Dictionary).duplicate(true)
	for table: Dictionary in [r.sources, r.items]:
		for id: Variant in table:
			var status_id: String = str((table[id] as Dictionary).get("status", ""))
			if not r.statuses.has(status_id):
				r.errors.append("%s 指到不存在的狀態 %s" % [id, status_id])
	# also（同一下再套用另一個來源）：要指到存在的來源，而且不能繞回自己——有問題的拿掉，照樣能跑
	for id: Variant in r.sources:
		var seen: PackedStringArray = [str(id)]
		var cur: Dictionary = r.sources[id] as Dictionary
		while cur.has("also"):
			var next_id: String = str(cur["also"])
			if not r.sources.has(next_id) or seen.has(next_id):
				r.errors.append("%s 的 also 指到不存在或繞回來的來源 %s" % [seen[seen.size() - 1], next_id])
				cur.erase("also")
				break
			seen.append(next_id)
			cur = r.sources[next_id] as Dictionary
	return r


## 狀態的種類："dot"＝每秒扣血／反轉後回血（中毒）；"action"＝不碰生命，影響能不能出手、出手多快（麻痺）；
## "guard"＝不碰生命，影響受到的直接傷害（防禦歸零）；"bleed"＝沒反轉每秒扣血、反轉後出手加速（流血）
func kind(status_id: String) -> String:
	return str((statuses.get(status_id, {}) as Dictionary).get("kind", "dot"))


func max_duration(status_id: String) -> float:
	return float((statuses.get(status_id, {}) as Dictionary).get("max_duration", 30.0))


## 反轉後每秒最多變成多少好處（中毒＝回血上限）
func max_reversed_rate(status_id: String) -> float:
	return float((statuses.get(status_id, {}) as Dictionary).get("max_reversed_rate", 0.0))


## 會疊的狀態（流血）：再上一次是把強度加上去，最多到這個數。0＝不疊（只留比較強的那一份）
func stack_max(status_id: String) -> float:
	return float((statuses.get(status_id, {}) as Dictionary).get("stack_max", 0.0))


## 流血被反轉：每一層出手快多少（0.12＝快 12%）
func haste_per_rate(status_id: String) -> float:
	return float((statuses.get(status_id, {}) as Dictionary).get("haste_per_rate", 0.0))


func source(source_id: String) -> Dictionary:
	return sources.get(source_id, {}) as Dictionary


func item(item_id: String) -> Dictionary:
	return items.get(item_id, {}) as Dictionary
