class_name GameState
extends RefCounted
## 可存檔的遊戲狀態（純資料，不依賴場景）。
## 只放「故事記得的事」：旗標、任務階段、已付出的記憶、目前章節與檢查點。

var chapter: String = "slice_frostbridge"
var checkpoint: String = "start"
var playtime_sec: float = 0.0
## 任意故事旗標，值限 bool / int / float / String（要能 JSON 化）
var flags: Dictionary = {}
## quest_id -> 階段 id
var quests: Dictionary = {}
## 已付出的記憶 id（九息代價），依付出順序
var memories_paid: PackedStringArray = []
## 攻略筆記（GuideNotes，存檔 v2 起）：id -> {"unsure": bool, "result": "" | "wrong" | "confirmed"}
var guide: Dictionary = {}

## ── 存檔 v3 起（新版劇情重寫，D-202）。舊版存檔讀進來是 "classic"、下面全空；memories_paid 不映射成任何新資源。
## "classic"＝舊版（切片、第 1～3 章）；"reboot"＝新版前十分鐘（存在另一個資料夾，GameSession.REBOOT_SAVE_DIR）
var mode: String = "classic"
## 身上還在的狀態（StatusEffects.to_array()），檢查點存的照原樣恢復
var statuses: Array = []
## 反轉欄位（ReversalSlots.to_dict()）；空＝還沒覺醒、兩個空格
var reversal: Dictionary = {}
## 道具數量：item_id -> int
var items: Dictionary = {}
## 已經發放過的一次性東西（藥箱、欠薪），讀檔重試不重複領
var grants: PackedStringArray = []
## 諾恩的生命（檢查點存檔記下）；沒有 "hp"＝滿血
var vitals: Dictionary = {}


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func has_paid_memory(memory_id: String) -> bool:
	return memories_paid.has(memory_id)


## 付出記憶。同一段記憶只能付一次；回傳 false 代表已付過（讀檔重來時不會重複扣）。
func pay_memory(memory_id: String) -> bool:
	if memories_paid.has(memory_id):
		return false
	memories_paid.append(memory_id)
	return true


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
		"memories_paid": Array(memories_paid),
		"guide": guide.duplicate(true),
		"mode": mode,
		"statuses": statuses.duplicate(true),
		"reversal": reversal.duplicate(true),
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
	var g: Variant = d.get("guide", {})
	if g is Dictionary:
		s.guide = (g as Dictionary).duplicate(true)
	var m: Variant = d.get("memories_paid", [])
	if m is Array:
		for item: Variant in (m as Array):
			s.memories_paid.append(str(item))
	s.mode = str(d.get("mode", "classic"))
	var st: Variant = d.get("statuses", [])
	if st is Array:
		s.statuses = (st as Array).duplicate(true)
	var rv: Variant = d.get("reversal", {})
	if rv is Dictionary:
		s.reversal = (rv as Dictionary).duplicate(true)
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
