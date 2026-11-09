class_name Residents
extends RefCounted
## 白晝城路口的壽命石碑（07-chapter1-door.md 系統 2、D-154）：附近居民的名字與「還能活幾天」。
## 資料在 res://data/daylight/residents.json：每塊石碑（id）列 4～6 個居民 {id, days}；名字的翻譯 key 是 RES_<ID>。
## 數字是真的資料：用掉的天數存在 GameState 的旗標 `life.<id>`（現在還剩幾天，沒有旗標就是資料裡的天數），
## 之後章節的抉擇（第 4 章盤點）照同一個旗標改。諾恩不在任何石碑上，也不能用壽命換東西（這一章只讓玩家看見別人在付）。

const DEFAULT_PATH: String = "res://data/daylight/residents.json"
const FLAG_PREFIX: String = "life."
const MIN_PER_STELE: int = 4
const MAX_PER_STELE: int = 6

static var _default: Residents = null

## 石碑 id -> 居民（照資料順序）
var steles: Dictionary = {}
## 居民 id -> 資料裡的天數
var base_days: Dictionary = {}
var errors: PackedStringArray = []


static func load_default() -> Residents:
	if _default == null:
		_default = load_file(DEFAULT_PATH)
	return _default


static func load_file(path: String) -> Residents:
	var r := Residents.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		r.errors.append("讀不到 %s" % path)
		return r
	var raw: Variant = (json.data as Dictionary).get("steles", {})
	if not raw is Dictionary:
		r.errors.append("steles 不是物件")
		return r
	for stele_id: Variant in (raw as Dictionary).keys():
		var ids: PackedStringArray = []
		for e: Variant in ((raw as Dictionary)[stele_id] as Array):
			if not e is Dictionary:
				continue
			var d: Dictionary = e as Dictionary
			var rid: String = str(d.get("id", ""))
			ids.append(rid)
			r.base_days[rid] = int(d.get("days", 0))
		r.steles[str(stele_id)] = ids
	r.errors.append_array(r.validate())
	return r


func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	var seen: Dictionary = {}
	for stele_id: String in steles.keys():
		var ids: PackedStringArray = steles[stele_id]
		if ids.size() < MIN_PER_STELE or ids.size() > MAX_PER_STELE:
			out.append("石碑 %s 有 %d 個名字（要 %d～%d）" % [stele_id, ids.size(), MIN_PER_STELE, MAX_PER_STELE])
		for rid: String in ids:
			if rid == "" or seen.has(rid):
				out.append("居民 id 空白或重複：%s" % rid)
			seen[rid] = true
			if int(base_days.get(rid, 0)) <= 0:
				out.append("居民 %s 的天數要大於 0" % rid)
	return out


func stele_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: String in steles.keys():
		out.append(k)
	return out


func residents_on(stele_id: String) -> PackedStringArray:
	return steles.get(stele_id, PackedStringArray()) as PackedStringArray


static func name_key(resident_id: String) -> String:
	return "RES_" + resident_id.to_upper()


func days_left(state: GameState, resident_id: String) -> int:
	return int(state.get_flag(FLAG_PREFIX + resident_id, int(base_days.get(resident_id, 0))))


## 用掉 n 天（石碑換東西）：回傳剩下的天數。不會小於 0。
func spend(session: GameSession, resident_id: String, n: int) -> int:
	var left: int = maxi(days_left(session.state, resident_id) - n, 0)
	session.set_flag(FLAG_PREFIX + resident_id, left)
	return left


## 石碑上的一行：「瑪菈　還能活 19 天」（名字與格式都走翻譯）。
func line(state: GameState, resident_id: String) -> String:
	return TranslationServer.translate("STELE_LINE").format({
		"name": TranslationServer.translate(name_key(resident_id)),
		"n": days_left(state, resident_id)})
