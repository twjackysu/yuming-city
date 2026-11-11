extends TestCase
## 任務資料與推進（QuestDB、QuestRunner）。


func _tiny_db() -> QuestDB:
	var db := QuestDB.new()
	db.add_quest({
		"id": "main", "title": "T",
		"stages": [
			{"id": "one", "objective": "O1", "checkpoint": "cp1", "done_when": {"flag": "f1"}},
			{"id": "two", "objective": "O2", "done_when": {"flag": "f2"}, "on_done": {"start_quest": ["side"]}},
			{"id": "three", "objective": "O3", "checkpoint": "cp3", "done_when": {"flag": "f3", "gte": 2}},
		],
		"on_complete": {"set": {"main.complete": true}},
	})
	db.add_quest({
		"id": "side", "title": "S",
		"stages": [{"id": "only", "objective": "OS", "done_when": {"flag": "s1"}}],
	})
	return db


func test_default_data_is_valid() -> void:
	var db := QuestDB.load_default()
	assert_eq(db.errors, PackedStringArray(), "res://data/quests 全部通過驗證")
	assert_true(db.has_quest(GameSession.REBOOT_MAIN_QUEST), "有主線")


func test_validation_catches_mistakes() -> void:
	var db := QuestDB.new()
	db.add_quest({"id": "bad", "title": "T", "stages": [
		{"id": "a", "objective": "O", "done_when": {"flag": "x"}},
		{"id": "a", "objective": "O", "done_when": {"flag": "x"}},
	]})
	db.add_quest({"id": "bad2", "title": "T", "stages": [
		{"id": "a", "objective": "O", "done_when": {"weird": 1}, "next": "nowhere"},
	]})
	db.add_quest({"id": "bad3", "stages": []})
	assert_eq(db.quests.size(), 0, "錯誤的任務不載入")
	assert_true(db.errors.size() >= 4, "重複 id、未知條件、錯誤 next、缺欄位都要報錯（實際 %d）" % db.errors.size())


func test_runner_advances_in_order() -> void:
	var db: QuestDB = _tiny_db()
	var s := GameState.new()
	var r := QuestRunner.new(db, s)
	var checkpoints: PackedStringArray = []
	r.checkpoint_reached.connect(func(cp: String) -> void: checkpoints.append(cp))
	assert_true(r.start("main"))
	assert_false(r.start("main"), "不重複開始")
	assert_eq(r.stage_of("main"), "one")
	assert_eq(s.checkpoint, "cp1", "進入階段時設定檢查點")
	assert_eq(r.objective_key("main"), "O1")
	assert_eq(r.evaluate().size(), 0, "條件未成立不推進")
	s.set_flag("f2", true)  # 先成立的後段條件不能跳過前段
	assert_eq(r.evaluate().size(), 0)
	s.set_flag("f1", true)
	var changes: Array[Dictionary] = r.evaluate()
	assert_eq(changes.size(), 2, "f1、f2 都成立 → 一次推進兩步")
	assert_eq(r.stage_of("main"), "three")
	assert_true(r.is_active("side"), "on_done 開始支線")
	assert_eq(checkpoints, PackedStringArray(["cp1", "cp3"]))
	s.set_flag("f3", 2.0)
	r.evaluate()
	assert_true(r.is_done("main"))
	assert_eq(s.get_flag("main.complete"), true, "on_complete 生效")
	assert_eq(r.objective_key("main"), "", "完成後沒有目標")


func test_runner_resumes_from_saved_state() -> void:
	var db: QuestDB = _tiny_db()
	var s := GameState.new()
	var r := QuestRunner.new(db, s)
	r.start("main")
	s.set_flag("f1", true)
	r.evaluate()
	var text: String = SaveCodec.encode(s)
	var loaded: GameState = SaveCodec.decode(text)["state"]
	var r2 := QuestRunner.new(db, loaded)
	assert_eq(r2.stage_of("main"), "two", "讀檔後在同一階段")
	assert_eq(r2.evaluate().size(), 0, "讀檔後不會自己亂跑")
	loaded.set_flag("f2", true)
	r2.evaluate()
	assert_eq(r2.stage_of("main"), "three")


func test_cycle_guard() -> void:
	var db := QuestDB.new()
	db.add_quest({"id": "loop", "title": "T", "stages": [
		{"id": "a", "objective": "O", "done_when": {}, "next": "b"},
		{"id": "b", "objective": "O", "done_when": {}, "next": "a"},
	]})
	var s := GameState.new()
	var r := QuestRunner.new(db, s)
	r.start("loop")
	var changes: Array[Dictionary] = r.evaluate()
	assert_eq(changes.size(), QuestRunner.MAX_STEPS, "循環資料不會卡死")
