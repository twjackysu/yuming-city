extends TestCase
## 存檔：版本、太舊／太新的存檔、壞檔回復、狀態與道具照原樣存。

var _dir: String = ""


func before_each() -> void:
	_dir = "user://test_save_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)


func after_each() -> void:
	for f: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	DirAccess.remove_absolute(_dir)


func _sample() -> GameState:
	var s := GameState.new()
	s.mode = "story"
	s.checkpoint = "ch1_guardian"
	s.playtime_sec = 321.5
	s.set_flag("ch1.barrels_hit", 4)
	s.set_flag("ch1.sheila_met", true)
	s.quests["ch1_main"] = "guardian"
	return s


func test_round_trip() -> void:
	var text: String = SaveCodec.encode(_sample(), "2026-11-07T00:00:00")
	var r: Dictionary = SaveCodec.decode(text)
	assert_eq(r["status"], SaveCodec.Status.OK)
	var s: GameState = r["state"]
	assert_eq(r["from_version"], SaveCodec.CURRENT_VERSION)
	assert_eq(s.mode, "story")
	assert_eq(s.checkpoint, "ch1_guardian")
	assert_eq(s.playtime_sec, 321.5)
	assert_eq(int(s.get_flag("ch1.barrels_hit")), 4, "JSON 數字讀回後要能轉 int")
	assert_eq(s.get_flag("ch1.sheila_met"), true)
	assert_eq(s.quests.get("ch1_main"), "guardian")


## v3 的存檔裡還有舊欄位（memories_paid、guide；值一定是空的）：讀得進來、欄位丟掉，再存就沒有了。
func test_v3_save_with_removed_fields_still_loads() -> void:
	var v3: Dictionary = {"version": 3, "saved_at": "2026-11-11T00:00:00", "state": {
		"chapter": "ch1", "checkpoint": "ch1_mist", "mode": "story", "flags": {"ch1.sheila_met": true},
		"quests": {"ch1_main": "mist"}, "memories_paid": [], "guide": {}, "items": {"sera_poison_vial": 1},
		"statuses": [], "reversal": {}, "grants": ["ch1.guardian_crate"], "vitals": {"hp": 40.0}}}
	var r: Dictionary = SaveCodec.decode(JSON.stringify(v3))
	assert_eq(r["status"], SaveCodec.Status.OK)
	var s: GameState = r["state"]
	assert_eq(s.checkpoint, "ch1_mist")
	assert_eq(s.quests.get("ch1_main"), "mist")
	assert_eq(int(s.items["sera_poison_vial"]), 1)
	assert_false(s.grant_once("ch1.guardian_crate"), "領過的還是領過")
	assert_eq(float(s.vitals["hp"]), 40.0)
	var again: Dictionary = s.to_dict()
	assert_false(again.has("memories_paid") or again.has("guide"), "再存一次就沒有舊欄位了")


## v0～v2 是已經刪掉的舊劇情的存檔：不遷移，回 TOO_OLD（呼叫端當成沒有存檔），也不會當成壞檔去翻備份。
func test_saves_older_than_v3_are_too_old() -> void:
	var v0: Dictionary = {"chapter": "slice_frostbridge", "checkpoint": "bell", "flags": {"a": 1}}
	var v2: Dictionary = {"version": 2, "saved_at": "2026-11-09T00:00:00", "state": {
		"chapter": "ch3", "checkpoint": "ch3_corner", "flags": {"ch3.done": true}, "quests": {"ch3_main": "corner"}}}
	for old: Dictionary in [v0, {"version": 1, "state": {}}, v2]:
		var r: Dictionary = SaveCodec.decode(JSON.stringify(old))
		assert_eq(r["status"], SaveCodec.Status.TOO_OLD, "v%d" % int(old.get("version", 0)))
		assert_eq(r["state"], null)
		assert_eq(r["from_version"], int(old.get("version", 0)))
	assert_eq(SaveCodec.MIN_VERSION, 3, "v3 起才是現在的劇情")
	var migrated: Dictionary = SaveCodec.migrate({"version": 3, "state": {"checkpoint": "x"}})
	assert_eq(migrated["version"], SaveCodec.CURRENT_VERSION, "v3 不用轉")


## 太舊的存檔留在原地：讀不到、不刪檔、不覆寫；GameSession 當成沒有存檔可以讀。
func test_too_old_file_is_left_untouched() -> void:
	var path: String = _dir.path_join("auto.json")
	var text: String = JSON.stringify({"version": 2, "state": {"checkpoint": "ch3_corner"}})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	assert_eq(SaveCodec.read_file(path)["status"], SaveCodec.Status.TOO_OLD)
	var s := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(s.load_slot(GameSession.AUTO_SLOT), SaveCodec.Status.TOO_OLD)
	assert_eq(s.state.checkpoint, GameState.new().checkpoint, "狀態沒被換掉")
	assert_eq(FileAccess.get_file_as_string(path), text, "舊檔一個字都沒變")


func test_reject_newer_version() -> void:
	var r: Dictionary = SaveCodec.decode(JSON.stringify({"version": SaveCodec.CURRENT_VERSION + 1, "state": {}}))
	assert_eq(r["status"], SaveCodec.Status.TOO_NEW)


func test_corrupt_text() -> void:
	assert_eq(SaveCodec.decode("{not json")["status"], SaveCodec.Status.CORRUPT)
	assert_eq(SaveCodec.decode("[1,2]")["status"], SaveCodec.Status.CORRUPT)


func test_file_write_and_backup_recovery() -> void:
	var path: String = _dir.path_join("slot1.json")
	assert_eq(SaveCodec.read_file(path)["status"], SaveCodec.Status.NOT_FOUND)
	assert_eq(SaveCodec.write_file(path, _sample()), OK, "第一次寫入")
	var second: GameState = _sample()
	second.checkpoint = "ch1_market"
	assert_eq(SaveCodec.write_file(path, second), OK, "第二次寫入")
	assert_false(FileAccess.file_exists(path + ".tmp"), "暫存檔要被改名掉")
	# 主檔損毀 → 讀 .bak（上一份）
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	var r: Dictionary = SaveCodec.read_file(path)
	assert_eq(r["status"], SaveCodec.Status.OK)
	assert_eq(r.get("recovered_from_backup", false), true)
	assert_eq((r["state"] as GameState).checkpoint, "ch1_guardian")


func test_v3_story_fields_round_trip() -> void:
	var s := GameState.new()
	s.mode = "story"
	s.statuses = [{"id": "poison", "rate": 3.0, "remaining": 12.5, "source": "sera_poison_vial"}]
	s.reversal = {"slots": 2, "unlocked": ["poison"], "equipped": ["poison", ""], "awakened_once": true}
	s.items["sera_poison_vial"] = 1
	assert_true(s.grant_once("ch1.guardian_crate"))
	s.vitals["hp"] = 55.0
	var back: GameState = SaveCodec.decode(SaveCodec.encode(s))["state"]
	assert_eq(back.mode, "story")
	assert_eq(float((back.statuses[0] as Dictionary)["remaining"]), 12.5, "負面狀態照原樣存，不清掉")
	assert_eq(int(back.items["sera_poison_vial"]), 1)
	assert_false(back.grant_once("ch1.guardian_crate"))
	assert_eq(float(back.vitals["hp"]), 55.0, "生命照原樣，不補滿")
	assert_true(ReversalSlots.from_dict(back.reversal).is_reversed("poison"))
