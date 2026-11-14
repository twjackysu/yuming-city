class_name DialogueDB
extends RefCounted
## 對話資料（res://data/dialogue/*.json）。只放結構與翻譯 key。
##
## {
##   "id": "rb_sheila_meet", "start": "greet",
##   "nodes": {
##     "greet": {"speaker": "SPK_...", "text": "DLG_...", "next": "ada", "do": {...效果，進入節點時套用}},
##     "ask":   {"speaker": "SPK_...", "text": "DLG_...", "choices": [
##                {"text": "DLG_...", "next": "buy", "if": {...條件}, "do": {...效果}}]},
##     "bye":   {"speaker": "SPK_...", "text": "DLG_..."}          ← 沒有 next／choices＝結束
##     "dead":  {"speaker": "SPK_...", "text": "DLG_預設", "text_if": [{"if": {...條件}, "text": "DLG_..."}]}
##              ← 依狀態換台詞（第一個成立的），流程不變
##   }
## }
## next 與 choices 不能同時存在；所有 next 都要指向存在的節點；每個節點都要能從 start 走到。

const DEFAULT_DIR: String = "res://data/dialogue"

## dialogue_id -> 對話資料
var dialogues: Dictionary = {}
var errors: PackedStringArray = []


static func load_default() -> DialogueDB:
	var db := DialogueDB.new()
	db.load_dir(DEFAULT_DIR)
	return db


func load_dir(dir_path: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file: String in files:
		if file.ends_with(".json"):
			load_file(dir_path.path_join(file))


func load_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s：不是有效的 JSON 物件" % path)
		return
	add_dialogue(parsed as Dictionary, path)


func add_dialogue(d: Dictionary, source: String = "<memory>") -> void:
	var problems: PackedStringArray = validate_dialogue(d)
	if not problems.is_empty():
		for p: String in problems:
			errors.append("%s：%s" % [source, p])
		return
	var id: String = str(d["id"])
	if dialogues.has(id):
		errors.append("%s：對話 id 重複 %s" % [source, id])
		return
	dialogues[id] = d


func has_dialogue(dialogue_id: String) -> bool:
	return dialogues.has(dialogue_id)


func node(dialogue_id: String, node_id: String) -> Dictionary:
	var d: Dictionary = dialogues.get(dialogue_id, {}) as Dictionary
	return (d.get("nodes", {}) as Dictionary).get(node_id, {}) as Dictionary


func start_node(dialogue_id: String) -> String:
	return str((dialogues.get(dialogue_id, {}) as Dictionary).get("start", ""))


## 所有用到的翻譯 key（給測試檢查 CSV）。
func translation_keys() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in dialogues:
		var nodes: Dictionary = (dialogues[id] as Dictionary)["nodes"] as Dictionary
		for nid: String in nodes:
			var n: Dictionary = nodes[nid] as Dictionary
			out.append(str(n["speaker"]))
			out.append(str(n["text"]))
			for v: Variant in (n.get("text_if", []) as Array):
				out.append(str((v as Dictionary)["text"]))
			for c: Variant in (n.get("choices", []) as Array):
				out.append(str((c as Dictionary)["text"]))
	return out


static func validate_dialogue(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in ["id", "start", "nodes"]:
		if not d.has(key):
			out.append("缺少欄位 %s" % key)
	if not out.is_empty():
		return out
	if not d["nodes"] is Dictionary or (d["nodes"] as Dictionary).is_empty():
		return PackedStringArray(["nodes 必須是非空物件"])
	var nodes: Dictionary = d["nodes"] as Dictionary
	var start: String = str(d["start"])
	if not nodes.has(start):
		out.append("start 節點不存在：%s" % start)
	for nid: String in nodes:
		if not nodes[nid] is Dictionary:
			out.append("節點 %s 必須是物件" % nid)
			continue
		var n: Dictionary = nodes[nid] as Dictionary
		for key: String in ["speaker", "text"]:
			if str(n.get(key, "")) == "":
				out.append("節點 %s 缺少 %s" % [nid, key])
		if n.has("text_if"):
			if not n["text_if"] is Array:
				out.append("節點 %s 的 text_if 必須是陣列" % nid)
			else:
				for v: Variant in (n["text_if"] as Array):
					if not v is Dictionary or str((v as Dictionary).get("text", "")) == "" or not (v as Dictionary).has("if"):
						out.append("節點 %s 的 text_if 每項都要有 if 與 text" % nid)
						continue
					var te: String = StoryLogic.validate_condition((v as Dictionary)["if"])
					if te != "":
						out.append("節點 %s 的 text_if：%s" % [nid, te])
		if n.has("next") and n.has("choices"):
			out.append("節點 %s 不能同時有 next 與 choices" % nid)
		if n.has("next") and not nodes.has(str(n["next"])):
			out.append("節點 %s 的 next 不存在：%s" % [nid, str(n["next"])])
		if n.has("do"):
			var e: String = StoryLogic.validate_effects(n["do"])
			if e != "":
				out.append("節點 %s 的 do：%s" % [nid, e])
		if n.has("choices"):
			if not n["choices"] is Array or (n["choices"] as Array).is_empty():
				out.append("節點 %s 的 choices 必須是非空陣列" % nid)
				continue
			var has_unconditional: bool = false
			for c: Variant in (n["choices"] as Array):
				if not c is Dictionary:
					out.append("節點 %s 的選項必須是物件" % nid)
					continue
				var ch: Dictionary = c as Dictionary
				if str(ch.get("text", "")) == "":
					out.append("節點 %s 的選項缺少 text" % nid)
				if not nodes.has(str(ch.get("next", ""))):
					out.append("節點 %s 的選項 next 不存在：%s" % [nid, str(ch.get("next", ""))])
				if ch.has("if"):
					var ce: String = StoryLogic.validate_condition(ch["if"])
					if ce != "":
						out.append("節點 %s 的選項 if：%s" % [nid, ce])
				else:
					has_unconditional = true
				if ch.has("do"):
					var de: String = StoryLogic.validate_effects(ch["do"])
					if de != "":
						out.append("節點 %s 的選項 do：%s" % [nid, de])
			if not has_unconditional:
				out.append("節點 %s 至少要有一個沒有條件的選項（避免卡住）" % nid)
	if out.is_empty():
		for nid: String in _unreachable(nodes, start):
			out.append("節點 %s 從 start 走不到" % nid)
	return out


static func _unreachable(nodes: Dictionary, start: String) -> PackedStringArray:
	var seen: Dictionary = {start: true}
	var stack: Array[String] = [start]
	while not stack.is_empty():
		var n: Dictionary = nodes[stack.pop_back()] as Dictionary
		var targets: Array[String] = []
		if n.has("next"):
			targets.append(str(n["next"]))
		for c: Variant in (n.get("choices", []) as Array):
			targets.append(str((c as Dictionary)["next"]))
		for t: String in targets:
			if not seen.has(t):
				seen[t] = true
				stack.append(t)
	var out: PackedStringArray = []
	for nid: String in nodes:
		if not seen.has(nid):
			out.append(nid)
	return out
