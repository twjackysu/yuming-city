extends TestCase
## 存檔：版本、遷移、壞檔回復、記憶代價不重複扣。

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
	s.checkpoint = "after_bell"
	s.playtime_sec = 321.5
	s.set_flag("slice.rescued_count", 4)
	s.set_flag("slice.told_truth_about_bell", true)
	s.quests["frostbridge_main"] = "evacuate"
	s.pay_memory("arch_father_last_talk")
	return s


func test_round_trip() -> void:
	var text: String = SaveCodec.encode(_sample(), "2026-11-07T00:00:00")
	var r: Dictionary = SaveCodec.decode(text)
	assert_eq(r["status"], SaveCodec.Status.OK)
	var s: GameState = r["state"]
	assert_eq(s.checkpoint, "after_bell")
	assert_eq(s.playtime_sec, 321.5)
	assert_eq(int(s.get_flag("slice.rescued_count")), 4, "JSON 數字讀回後要能轉 int")
	assert_eq(s.get_flag("slice.told_truth_about_bell"), true)
	assert_eq(s.quests.get("frostbridge_main"), "evacuate")
	assert_true(s.has_paid_memory("arch_father_last_talk"))


func test_memory_cost_is_paid_once() -> void:
	var s := GameState.new()
	assert_true(s.pay_memory("arch_father_last_talk"), "第一次付出")
	assert_false(s.pay_memory("arch_father_last_talk"), "同一段記憶不能付第二次")
	var reloaded: GameState = SaveCodec.decode(SaveCodec.encode(s))["state"]
	assert_false(reloaded.pay_memory("arch_father_last_talk"), "讀檔後也不會重複扣")
	assert_eq(reloaded.memories_paid.size(), 1)


func test_migrate_v0_flat_format() -> void:
	var v0: Dictionary = {"chapter": "slice_frostbridge", "checkpoint": "bell", "flags": {"a": 1}}
	var r: Dictionary = SaveCodec.decode(JSON.stringify(v0))
	assert_eq(r["status"], SaveCodec.Status.OK)
	assert_eq(r["from_version"], 0)
	var s: GameState = r["state"]
	assert_eq(s.checkpoint, "bell")
	assert_eq(int(s.get_flag("a")), 1)
	var migrated: Dictionary = SaveCodec.migrate(v0)
	assert_eq(migrated["version"], SaveCodec.CURRENT_VERSION)
	assert_false(v0.has("state"), "遷移不能修改輸入")


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
	second.checkpoint = "arch"
	assert_eq(SaveCodec.write_file(path, second), OK, "第二次寫入")
	assert_false(FileAccess.file_exists(path + ".tmp"), "暫存檔要被改名掉")
	# 主檔損毀 → 讀 .bak（上一份）
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	var r: Dictionary = SaveCodec.read_file(path)
	assert_eq(r["status"], SaveCodec.Status.OK)
	assert_eq(r.get("recovered_from_backup", false), true)
	assert_eq((r["state"] as GameState).checkpoint, "after_bell")


func test_migrate_v2_to_v3_is_classic_and_does_not_map_memories() -> void:
	var v2: Dictionary = {"version": 2, "saved_at": "2026-11-09T00:00:00", "state": {
		"chapter": "ch3", "checkpoint": "ch3_corner", "flags": {"ch3.done": true},
		"quests": {"ch3_main": "corner"}, "memories_paid": ["arch_father_last_talk"], "guide": {}}}
	var r: Dictionary = SaveCodec.decode(JSON.stringify(v2))
	assert_eq(r["status"], SaveCodec.Status.OK)
	assert_eq(r["from_version"], 2)
	var s: GameState = r["state"]
	assert_eq(s.mode, "classic", "v2 以前一定是舊版")
	assert_true(s.has_paid_memory("arch_father_last_talk"), "舊版的記憶代價照舊留著")
	assert_true(s.items.is_empty() and s.statuses.is_empty() and s.grants.is_empty(), "記憶不映射成新版任何資源")
	assert_true(s.reversal.is_empty() and s.vitals.is_empty())
	assert_eq(s.quests.get("ch3_main"), "corner", "舊進度不動")


func test_v3_reboot_fields_round_trip() -> void:
	var s := GameState.new()
	s.mode = "reboot"
	s.statuses = [{"id": "poison", "rate": 3.0, "remaining": 12.5, "source": "mist_serpent_poison"}]
	s.reversal = {"slots": 2, "unlocked": ["poison"], "equipped": ["poison", ""], "awakened_once": true}
	s.items["mist_serpent_poison"] = 1
	assert_true(s.grant_once("rb.guardian_crate"))
	s.vitals["hp"] = 55.0
	var back: GameState = SaveCodec.decode(SaveCodec.encode(s))["state"]
	assert_eq(back.mode, "reboot")
	assert_eq(float((back.statuses[0] as Dictionary)["remaining"]), 12.5, "負面狀態照原樣存，不清掉")
	assert_eq(int(back.items["mist_serpent_poison"]), 1)
	assert_false(back.grant_once("rb.guardian_crate"))
	assert_eq(float(back.vitals["hp"]), 55.0, "生命照原樣，不補滿")
	assert_true(ReversalSlots.from_dict(back.reversal).is_reversed("poison"))


func test_reboot_saves_live_in_their_own_folder() -> void:
	assert_ne(GameSession.REBOOT_SAVE_DIR, GameSession.DEFAULT_SAVE_DIR, "新版存檔不會寫到舊版的資料夾")
	assert_false(GameSession.REBOOT_SAVE_DIR.begins_with(GameSession.DEFAULT_SAVE_DIR + "/"), "也不在舊版資料夾裡面")
