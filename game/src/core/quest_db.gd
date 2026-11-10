class_name QuestDB
extends RefCounted
## 任務資料（res://data/quests/*.json）。只放結構與翻譯 key（D-013）。
##
## {
##   "id": "slice_main", "title": "Q_SLICE_MAIN_TITLE",
##   "stages": [
##     {"id": "explore_town", "objective": "Q_...", "checkpoint": "start",
##      "done_when": {...條件}, "on_done": {...效果}, "next": "選填：預設為下一個階段",
##      "marker": "選填：目標指引指向哪裡（見 validate_marker）",
##      "marker_if": [{"when": {...條件}, "marker": ...}]  選填：第一個成立的取代 marker,
##      "objective_if": [{"when": {...條件}, "objective": "Q_..."}]  選填：第一個成立的取代 objective（D-202）}
##   ],
##   "on_complete": {...效果}
## }

const DEFAULT_DIR: String = "res://data/quests"

## quest_id -> 任務資料
var quests: Dictionary = {}
var errors: PackedStringArray = []


static func load_default() -> QuestDB:
	var db := QuestDB.new()
	db.load_dir(DEFAULT_DIR)
	return db


func load_dir(dir_path: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file: String in files:
		if file.ends_with(".json"):
			load_file(dir_path.path_join(file))


func load_file(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		errors.append("%s：不是有效的 JSON 物件" % path)
		return
	add_quest(parsed as Dictionary, path)


func add_quest(q: Dictionary, source: String = "<memory>") -> void:
	var problems: PackedStringArray = validate_quest(q)
	if not problems.is_empty():
		for p: String in problems:
			errors.append("%s：%s" % [source, p])
		return
	var id: String = str(q["id"])
	if quests.has(id):
		errors.append("%s：任務 id 重複 %s" % [source, id])
		return
	quests[id] = q


func has_quest(quest_id: String) -> bool:
	return quests.has(quest_id)


func stages(quest_id: String) -> Array:
	return (quests[quest_id] as Dictionary)["stages"] as Array


func stage(quest_id: String, stage_id: String) -> Dictionary:
	for s: Variant in stages(quest_id):
		if str((s as Dictionary)["id"]) == stage_id:
			return s as Dictionary
	return {}


func first_stage_id(quest_id: String) -> String:
	return str((stages(quest_id)[0] as Dictionary)["id"])


## 階段完成後的下一個階段 id；最後一個階段回傳 StoryLogic.QUEST_DONE。
func next_stage_id(quest_id: String, stage_id: String) -> String:
	var list: Array = stages(quest_id)
	for i: int in list.size():
		var s: Dictionary = list[i] as Dictionary
		if str(s["id"]) != stage_id:
			continue
		if s.has("next"):
			return str(s["next"])
		if i + 1 < list.size():
			return str((list[i + 1] as Dictionary)["id"])
		return StoryLogic.QUEST_DONE
	return StoryLogic.QUEST_DONE


## 所有用到的翻譯 key（給測試檢查 CSV）。
func translation_keys() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in quests:
		var q: Dictionary = quests[id]
		out.append(str(q["title"]))
		for s: Variant in (q["stages"] as Array):
			out.append(str((s as Dictionary)["objective"]))
			for alt: Variant in ((s as Dictionary).get("objective_if", []) as Array):
				out.append(str((alt as Dictionary)["objective"]))
	return out


static func validate_quest(q: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in ["id", "title", "stages"]:
		if not q.has(key):
			out.append("缺少欄位 %s" % key)
	if not out.is_empty():
		return out
	if not q["stages"] is Array or (q["stages"] as Array).is_empty():
		out.append("stages 必須是非空陣列")
		return out
	var ids: Dictionary = {}
	for s: Variant in (q["stages"] as Array):
		if not s is Dictionary:
			out.append("階段必須是物件")
			continue
		var st: Dictionary = s as Dictionary
		var sid: String = str(st.get("id", ""))
		if sid == "" or sid == StoryLogic.QUEST_DONE:
			out.append("階段 id 不合法：%s" % sid)
		elif ids.has(sid):
			out.append("階段 id 重複：%s" % sid)
		ids[sid] = true
		if not st.has("objective"):
			out.append("階段 %s 缺少 objective" % sid)
		if not st.has("done_when"):
			out.append("階段 %s 缺少 done_when" % sid)
		else:
			var err: String = StoryLogic.validate_condition(st["done_when"])
			if err != "":
				out.append("階段 %s 的 done_when：%s" % [sid, err])
		if st.has("marker"):
			var me: String = validate_marker(st["marker"])
			if me != "":
				out.append("階段 %s 的 marker：%s" % [sid, me])
		if st.has("marker_if"):
			if not st["marker_if"] is Array:
				out.append("階段 %s 的 marker_if 必須是陣列" % sid)
			else:
				for alt: Variant in (st["marker_if"] as Array):
					if not alt is Dictionary or not (alt as Dictionary).has("when") or not (alt as Dictionary).has("marker"):
						out.append("階段 %s 的 marker_if 每一項都要有 when 與 marker" % sid)
						continue
					var ce: String = StoryLogic.validate_condition((alt as Dictionary)["when"])
					var me2: String = validate_marker((alt as Dictionary)["marker"])
					if ce != "" or me2 != "":
						out.append("階段 %s 的 marker_if：%s%s" % [sid, ce, me2])
		if st.has("objective_if"):
			if not st["objective_if"] is Array:
				out.append("階段 %s 的 objective_if 必須是陣列" % sid)
			else:
				for alt: Variant in (st["objective_if"] as Array):
					if not alt is Dictionary or not (alt as Dictionary).has("when") or not (alt as Dictionary).has("objective"):
						out.append("階段 %s 的 objective_if 每一項都要有 when 與 objective" % sid)
						continue
					var oe: String = StoryLogic.validate_condition((alt as Dictionary)["when"])
					if oe != "":
						out.append("階段 %s 的 objective_if：%s" % [sid, oe])
		if st.has("on_done"):
			var e: String = StoryLogic.validate_effects(st["on_done"])
			if e != "":
				out.append("階段 %s 的 on_done：%s" % [sid, e])
	for s: Variant in (q["stages"] as Array):
		if s is Dictionary and (s as Dictionary).has("next"):
			var nxt: String = str((s as Dictionary)["next"])
			if nxt != StoryLogic.QUEST_DONE and not ids.has(nxt):
				out.append("next 指向不存在的階段：%s" % nxt)
	if q.has("on_complete"):
		var e2: String = StoryLogic.validate_effects(q["on_complete"])
		if e2 != "":
			out.append("on_complete：%s" % e2)
	return out


## 目標指引的目標（02-gameplay「目標指引」）：
##   "node:<名稱>"     關卡底下的節點（Node3D）
##   "nearest:<前綴>"  名稱以前綴開頭、還沒完成的節點中最近的一個（有 is_available() 就要回傳 true）
##   [x, y, z]         固定位置
static func validate_marker(m: Variant) -> String:
	if m is String:
		var t: String = m as String
		for prefix: String in ["node:", "nearest:"]:
			if t.begins_with(prefix) and t.length() > prefix.length():
				return ""
		return "不認得的目標 %s（node:／nearest:）" % t
	if m is Array and (m as Array).size() == 3:
		for v: Variant in (m as Array):
			if not (v is float or v is int):
				return "座標必須是數字"
		return ""
	return "必須是字串或 [x, y, z]"
