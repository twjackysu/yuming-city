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
