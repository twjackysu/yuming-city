class_name GameState
extends RefCounted
## 可存檔的遊戲狀態（純資料，不依賴場景）。
## 只放「故事記得的事」：旗標、任務階段、目前章節與檢查點、身上的狀態與道具。

var chapter: String = "ch1"
var checkpoint: String = "start"
var playtime_sec: float = 0.0
## 任意故事旗標，值限 bool / int / float / String（要能 JSON 化）
var flags: Dictionary = {}
## quest_id -> 階段 id
var quests: Dictionary = {}

## 有開新遊戲（或讀檔）的劇情＝STORY_MODE；""＝沒有開劇情（測試、benchmark 的空關卡）：不恢復生命、不寫存檔。
const STORY_MODE: String = "story"
var mode: String = ""
## 身上還在的狀態（StatusEffects.to_array()），檢查點存的照原樣恢復
var statuses: Array = []
## 道具數量：item_id -> int
var items: Dictionary = {}
## 已經發放過的一次性東西（寶箱、獎勵），讀檔重試不重複領
var grants: PackedStringArray = []
## 諾恩的生命（檢查點存檔記下）；沒有 "hp"＝滿血
var vitals: Dictionary = {}


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


## 一次性發放：第一次回傳 true 並記下，之後一律 false
func grant_once(grant_id: String) -> bool:
	if grants.has(grant_id):
		return false
	grants.append(grant_id)
	return true


func to_dict() -> Dictionary:
	return {
		"chapter": chapter,
		"checkpoint": checkpoint,
		"playtime_sec": playtime_sec,
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true),
		"mode": mode,
		"statuses": statuses.duplicate(true),
		"items": items.duplicate(true),
		"grants": Array(grants),
		"vitals": vitals.duplicate(true),
	}


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.chapter = str(d.get("chapter", s.chapter))
	s.checkpoint = str(d.get("checkpoint", s.checkpoint))
	s.playtime_sec = float(d.get("playtime_sec", 0.0))
	var f: Variant = d.get("flags", {})
	if f is Dictionary:
		s.flags = (f as Dictionary).duplicate(true)
	var q: Variant = d.get("quests", {})
	if q is Dictionary:
		s.quests = (q as Dictionary).duplicate(true)
	s.mode = str(d.get("mode", ""))
	var st: Variant = d.get("statuses", [])
	if st is Array:
		s.statuses = (st as Array).duplicate(true)
	var it: Variant = d.get("items", {})
	if it is Dictionary:
		for k: Variant in (it as Dictionary):
			s.items[str(k)] = int((it as Dictionary)[k])
	var gr: Variant = d.get("grants", [])
	if gr is Array:
		for g_id: Variant in (gr as Array):
			s.grants.append(str(g_id))
	var vt: Variant = d.get("vitals", {})
	if vt is Dictionary:
		s.vitals = (vt as Dictionary).duplicate(true)
	return s
