class_name GuideNotes
extends RefCounted
## 攻略筆記（第 1 章起，docs/design/07-chapter1-door.md 系統 1、D-148）：諾恩前世記得的攻略，一條條被現實推翻。
## 資料在 res://data/guide/notes.json：每條 id、哪一章推翻（chapter，只是註記）、推翻條件 wrong_when／證實條件 confirmed_when
## （跟任務 done_when 同一套 StoryLogic 格式）。文字 key：GUIDE_<ID>（攻略寫的）、GUIDE_<ID>_WRONG（現實裡看到的）。
## 狀態存在 GameState.guide：id -> {"unsure": bool, "result": "" | "wrong" | "confirmed"}；還沒寫下的條目不在裡面。
## 玩家看到的可信度（06-terminology）：確定（sure）／我不確定（unsure）／被推翻（wrong）／證實（confirmed）。
## 「我不確定」只影響之後的台詞（標了的被推翻時諾恩說「果然」），不懲罰。

const UNWRITTEN: String = "unwritten"
const SURE: String = "sure"
const UNSURE: String = "unsure"
const WRONG: String = "wrong"
const CONFIRMED: String = "confirmed"
const STATUSES: PackedStringArray = [UNWRITTEN, SURE, UNSURE, WRONG, CONFIRMED]
const DEFAULT_PATH: String = "res://data/guide/notes.json"

static var _default: GuideNotes = null

var entries: Array[Dictionary] = []
var errors: PackedStringArray = []


static func load_default() -> GuideNotes:
	if _default == null:
		_default = load_file(DEFAULT_PATH)
	return _default


static func load_file(path: String) -> GuideNotes:
	var g := GuideNotes.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		g.errors.append("讀不到 %s" % path)
		return g
	for e: Variant in ((json.data as Dictionary).get("entries", []) as Array):
		if e is Dictionary:
			g.entries.append(e as Dictionary)
	g.errors.append_array(g.validate())
	return g


func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	var seen: Dictionary = {}
	for e: Dictionary in entries:
		var id: String = str(e.get("id", ""))
		if id == "" or seen.has(id):
			out.append("攻略條目 id 空白或重複：%s" % id)
		seen[id] = true
		for key: String in ["wrong_when", "confirmed_when"]:
			if e.has(key):
				var err: String = StoryLogic.validate_condition(e[key])
				if err != "":
					out.append("%s.%s：%s" % [id, key, err])
	return out


func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Dictionary in entries:
		out.append(str(e["id"]))
	return out


func ids_for_chapter(chapter: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Dictionary in entries:
		if str(e.get("chapter", "")) == chapter:
			out.append(str(e["id"]))
	return out


static func text_key(entry_id: String) -> String:
	return "GUIDE_" + entry_id.to_upper()


static func wrong_key(entry_id: String) -> String:
	return text_key(entry_id) + "_WRONG"


## 寫下條目（已經寫過的不動）。回傳這次新寫下的 id。
static func write(state: GameState, entry_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in entry_ids:
		if not state.guide.has(id):
			state.guide[id] = {"unsure": false, "result": ""}
			out.append(id)
	return out


static func status(state: GameState, entry_id: String) -> String:
	var e: Variant = state.guide.get(entry_id, null)
	if not e is Dictionary:
		return UNWRITTEN
	var d: Dictionary = e as Dictionary
	var result: String = str(d.get("result", ""))
	if result != "":
		return result
	return UNSURE if bool(d.get("unsure", false)) else SURE


## 寫下時有沒有標「我不確定」（被推翻之後也記得）。
static func was_unsure(state: GameState, entry_id: String) -> bool:
	var e: Variant = state.guide.get(entry_id, null)
	return e is Dictionary and bool((e as Dictionary).get("unsure", false))


## 標／取消「我不確定」：只有還沒被推翻或證實的條目可以改。回傳是否改了。
static func set_unsure(state: GameState, entry_id: String, unsure: bool) -> bool:
	var s: String = status(state, entry_id)
	if s != SURE and s != UNSURE:
		return false
	(state.guide[entry_id] as Dictionary)["unsure"] = unsure
	return true


## 檢查已寫下、還沒有結果的條目；條件成立就推翻或證實。回傳 [{id, result, was_unsure}]。
func evaluate(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		var id: String = str(e["id"])
		var s: String = status(state, id)
		if s != SURE and s != UNSURE:
			continue
		var result: String = ""
		if e.has("wrong_when") and StoryLogic.check(e["wrong_when"] as Dictionary, state):
			result = WRONG
		elif e.has("confirmed_when") and StoryLogic.check(e["confirmed_when"] as Dictionary, state):
			result = CONFIRMED
		if result == "":
			continue
		(state.guide[id] as Dictionary)["result"] = result
		out.append({"id": id, "result": result, "was_unsure": s == UNSURE})
	return out
