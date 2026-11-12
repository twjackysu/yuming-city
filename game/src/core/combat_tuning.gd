class_name CombatTuning
extends RefCounted
## 戰鬥數值（D-014）：預設在 res://data/combat/tuning.json，開發時可用 user://tuning.json 覆寫同名 key（深層合併）。
## 遊戲中按 F5（App）重新載入，不用重新匯出。讀值用路徑：CombatTuning.num("noen.blunt_damage")。
##
## 另一套數值（D-239）：tuning.json 最上層的 "profiles" 底下，每個名字是一份「只寫要改的 key」的覆寫，
## `set_profile("arena")` 之後深層合併進來、`set_profile("")` 還原。戰鬥場用這個試新的數值，劇情流程的數字不動。

const DEFAULT_PATH: String = "res://data/combat/tuning.json"
const OVERRIDE_PATH: String = "user://tuning.json"

const PROFILES_KEY: String = "profiles"
const PROFILE_ARENA: String = "arena"

static var _data: Dictionary = {}
## 沒有套 profile 的那一份（檔案＋user:// 覆寫）
static var _base: Dictionary = {}
static var _profile: String = ""
static var _loaded: bool = false


static func load_tuning(default_path: String = DEFAULT_PATH, override_path: String = OVERRIDE_PATH) -> void:
	_base = _read(default_path)
	var over: Dictionary = _read(override_path)
	if not over.is_empty():
		_base = merge(_base, over)
		print("[CombatTuning] 套用覆寫 %s" % override_path)
	_loaded = true
	_apply_profile()


## 換一套數值（""＝原本的）。已經生出來的角色不會跟著變：他們的數值是生出來的時候讀的。
static func set_profile(which: String) -> void:
	if not _loaded:
		load_tuning()
	if which == _profile:
		return
	_profile = which
	_apply_profile()


static func profile() -> String:
	return _profile


static func _apply_profile() -> void:
	_data = _base
	if _profile == "":
		return
	var all: Variant = _base.get(PROFILES_KEY, {})
	var over: Variant = (all as Dictionary).get(_profile, {}) if all is Dictionary else {}
	if over is Dictionary and not (over as Dictionary).is_empty():
		_data = merge(_base, over as Dictionary)


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
