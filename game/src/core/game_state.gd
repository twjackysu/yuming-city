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


func to_dict() -> Dictionary:
	return {
		"chapter": chapter,
		"checkpoint": checkpoint,
		"playtime_sec": playtime_sec,
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true),
		"memories_paid": Array(memories_paid),
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
	var m: Variant = d.get("memories_paid", [])
	if m is Array:
		for item: Variant in (m as Array):
			s.memories_paid.append(str(item))
	return s
