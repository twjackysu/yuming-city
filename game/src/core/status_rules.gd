class_name StatusRules
extends RefCounted
## 新版（劇情重寫）狀態規則的資料：狀態定義、來源（毒霧、守衛噴毒）、可攜藥劑（D-202）。
## 資料在 res://data/reboot/statuses.json；數值說明見 docs/design/09-reboot-first-ten-minutes.md。

const DEFAULT_PATH: String = "res://data/reboot/statuses.json"

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
	return r


## 狀態的種類："dot"＝每秒扣血／反轉後回血（中毒）；"action"＝不碰生命，影響能不能出手、出手多快（麻痺，D-234）
func kind(status_id: String) -> String:
	return str((statuses.get(status_id, {}) as Dictionary).get("kind", "dot"))


func max_duration(status_id: String) -> float:
	return float((statuses.get(status_id, {}) as Dictionary).get("max_duration", 30.0))


## 反轉後每秒最多變成多少好處（中毒＝回血上限）
func max_reversed_rate(status_id: String) -> float:
	return float((statuses.get(status_id, {}) as Dictionary).get("max_reversed_rate", 0.0))


func source(source_id: String) -> Dictionary:
	return sources.get(source_id, {}) as Dictionary


func item(item_id: String) -> Dictionary:
	return items.get(item_id, {}) as Dictionary
