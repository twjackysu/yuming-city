class_name Journal
extends RefCounted
## 日記：記憶條目（docs/design/02-gameplay.md「記憶與日記」）。
## 條目是靜態資料（data/journal/*.json）；「付出了沒」只看 GameState.memories_paid，所以存讀檔不用另外存。
## 付出後：標題與前後文保留，內文變成被整齊剪掉的空白，另外顯示殘留（residue）。
##
## 條目欄位：id（＝記憶 id，九息的代價）、title／context／body／residue（翻譯 key；context、residue 可省略）、
## people／places（相關人物與地點）、unlocked_when（StoryLogic 條件，省略＝一開始就有）。

const DEFAULT_PATH: String = "res://data/journal/slice.json"

var entries: Array[Dictionary] = []
## 九息預覽中被標亮的記憶 id（暫時狀態，不存檔）
var highlighted: String = ""


static func load_default() -> Journal:
	return load_file(DEFAULT_PATH)


static func load_file(path: String) -> Journal:
	var j := Journal.new()
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Journal: 讀不到 %s" % path)
		return j
	var list: Variant = (data as Dictionary).get("entries", [])
	if list is Array:
		for e: Variant in (list as Array):
			if e is Dictionary:
				j.entries.append(e as Dictionary)
	return j


## 資料檢查：回傳錯誤訊息（空陣列＝沒問題）。
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary = {}
	for e: Dictionary in entries:
		var id: String = str(e.get("id", ""))
		if id == "":
			errors.append("條目缺 id")
			continue
		if seen.has(id):
			errors.append("%s 重複" % id)
		seen[id] = true
		for k: String in ["title", "body"]:
			if str(e.get(k, "")) == "":
				errors.append("%s 缺 %s" % [id, k])
		if e.has("unlocked_when"):
			var err: String = StoryLogic.validate_condition(e["unlocked_when"])
			if err != "":
				errors.append("%s unlocked_when：%s" % [id, err])
	return errors


func has_entry(id: String) -> bool:
	return not entry(id).is_empty()


func entry(id: String) -> Dictionary:
	for e: Dictionary in entries:
		if str(e.get("id", "")) == id:
			return e
	return {}


func is_unlocked(e: Dictionary, state: GameState) -> bool:
	# 付出過的記憶一律看得到（D-178）：不會付了一段日記裡找不到的記憶（例如跳過了解鎖它的那段對話）
	if state.has_paid_memory(str(e.get("id", ""))):
		return true
	if not e.has("unlocked_when"):
		return true
	var cond: Variant = e["unlocked_when"]
	return cond is Dictionary and StoryLogic.check(cond as Dictionary, state)


## 目前日記裡看得到的條目 id（資料順序）。
func visible_ids(state: GameState) -> PackedStringArray:
	var ids: PackedStringArray = []
	for e: Dictionary in entries:
		if is_unlocked(e, state):
			ids.append(str(e["id"]))
	return ids


func is_cut(id: String, state: GameState) -> bool:
	return state.has_paid_memory(id)


## 顯示用的資料：title／context／body／residue（翻譯 key，沒有的是 ""）、cut、highlighted。
## 被剪掉時 body 是 ""、residue 才出現。
func view(id: String, state: GameState) -> Dictionary:
	var e: Dictionary = entry(id)
	if e.is_empty():
		return {}
	var cut: bool = is_cut(id, state)
	return {
		"id": id,
		"title": str(e.get("title", "")),
		"context": str(e.get("context", "")),
		"body": "" if cut else str(e.get("body", "")),
		"residue": str(e.get("residue", "")) if cut else "",
		"cut": cut,
		"highlighted": highlighted == id,
	}
