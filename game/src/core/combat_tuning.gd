class_name CombatTuning
extends RefCounted
## 戰鬥數值（D-014）：預設在 res://data/combat/tuning.json，開發時可用 user://tuning.json 覆寫同名 key（深層合併）。
## 遊戲中按 F5（App）重新載入，不用重新匯出。讀值用路徑：CombatTuning.num("noen.blunt_damage")。

const DEFAULT_PATH: String = "res://data/combat/tuning.json"
const OVERRIDE_PATH: String = "user://tuning.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func load_tuning(default_path: String = DEFAULT_PATH, override_path: String = OVERRIDE_PATH) -> void:
	_data = _read(default_path)
	var over: Dictionary = _read(override_path)
	if not over.is_empty():
		_data = merge(_data, over)
		print("[CombatTuning] 套用覆寫 %s" % override_path)
	_loaded = true


## 深層合併：b 的值蓋過 a；兩邊都是字典時往下合併。
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate(true)
	for k: Variant in b:
		if out.get(k) is Dictionary and b[k] is Dictionary:
			out[k] = merge(out[k] as Dictionary, b[k] as Dictionary)
		else:
			out[k] = b[k]
	return out


static func value(path: String, fallback: Variant = null) -> Variant:
	if not _loaded:
		load_tuning()
	var node: Variant = _data
	for part: String in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(part):
			push_warning("CombatTuning: 沒有 %s，用預設 %s" % [path, fallback])
			return fallback
		node = (node as Dictionary)[part]
	return node


static func num(path: String, fallback: float = 0.0) -> float:
	var v: Variant = value(path, fallback)
	return float(v) if (v is float or v is int) else fallback


static func pair(path: String, fallback: Vector2) -> Vector2:
	var v: Variant = value(path, null)
	if v is Array and (v as Array).size() == 2:
		return Vector2(float((v as Array)[0]), float((v as Array)[1]))
	return fallback


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("CombatTuning: %s 不是 JSON 物件" % path)
		return {}
	return parsed as Dictionary
