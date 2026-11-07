extends TestCase
## 過場：資料驗證、時間推進、等待輸入、跳過時效果一次到位且不重複。


func _data() -> Dictionary:
	return {
		"id": "t",
		"shots": [
			{"camera": "A", "duration": 1.0, "line": "CUT_BELL_001", "effects": {"add": {"n": 1}}},
			{"camera": "B", "await": "interact", "prompt": "CUT_PROMPT_RING", "event": "ring", "effects": {"add": {"n": 10}}},
			{"camera": "C", "duration": 2.0, "event": "boom", "effects": {"set": {"boom": true}}},
		],
		"on_end": {"set": {"done": true}},
	}


func test_all_cutscene_files_valid_and_translated() -> void:
	var count: int = 0
	for f: String in DirAccess.get_files_at(CutsceneRunner.DIR):
		if not f.ends_with(".json"):
			continue
		count += 1
		var d: Dictionary = CutsceneRunner.load_cutscene(f.get_basename())
		assert_eq(CutsceneRunner.validate(d), PackedStringArray(), f + " 格式")
		assert_eq(str(d.get("id", "")), f.get_basename(), f + " 的 id 要跟檔名一樣")
		for key: String in CutsceneRunner.text_keys(d):
			for loc: String in ["en", "zh_TW"]:
				TranslationServer.set_locale(loc)
				assert_ne(TranslationServer.translate(key), StringName(key), "%s 缺翻譯 %s（%s）" % [f, key, loc])
	TranslationServer.set_locale(str(tree.root.get_node("Settings").get("locale")))
	assert_true(count >= 1, "至少有敲鐘演出")


func test_validation_catches_mistakes() -> void:
	var bad: Dictionary = {"id": "x", "shots": [
		{"duration": 1.0},
		{"camera": "A", "duration": 1.0, "await": "interact", "prompt": "P"},
		{"camera": "A", "await": "fly"},
		{"camera": "A", "duration": 1.0, "effects": {"explode": 1}},
	]}
	var errors: PackedStringArray = CutsceneRunner.validate(bad)
	assert_eq(errors.size(), 5, "缺 camera、二選一、await 不是動作、缺 prompt、效果錯：%s" % [errors])


func test_play_through_in_order() -> void:
	var state := GameState.new()
	var r := CutsceneRunner.new(state)
	var events: Array[String] = []
	r.event_fired.connect(func(e: String, _s: Dictionary) -> void: events.append(e))
	var ended: Array[bool] = []
	r.finished.connect(func(_id: String, skipped: bool) -> void: ended.append(skipped))
	assert_true(r.start("t", _data()))
	assert_eq(state.get_flag("n"), 1, "第一個鏡頭開始就套用效果")
	assert_false(r.press("interact"), "時長鏡頭不收輸入")
	r.update(0.5)
	assert_eq(r.index, 0)
	r.update(0.6)
	assert_eq(r.index, 1, "時間到換鏡頭")
	assert_true(r.is_waiting())
	r.update(100.0)
	assert_eq(r.index, 1, "等待輸入的鏡頭不會自己結束")
	assert_false(r.press("dodge"), "別的鍵沒用")
	assert_true(r.press("interact"))
	assert_eq(state.get_flag("n"), 11, "按下才套用")
	assert_eq(events, ["ring", "boom"] as Array[String], "事件依序")
	r.update(2.0)
	assert_false(r.is_running())
	assert_eq(ended, [false] as Array[bool], "正常結束")
	assert_eq(state.get_flag("done"), true, "on_end")


func test_skip_applies_remaining_effects_once() -> void:
	var state := GameState.new()
	var r := CutsceneRunner.new(state)
	var events: Array[String] = []
	r.event_fired.connect(func(e: String, _s: Dictionary) -> void: events.append(e))
	var changes: Array[int] = [0]
	r.state_changed.connect(func() -> void: changes[0] += 1)
	assert_true(r.start("t", _data()))
	r.update(1.5)
	r.skip()
	assert_false(r.is_running(), "跳過＝結束")
	assert_eq(state.get_flag("n"), 11, "第一個鏡頭的效果不重複，等待鏡頭的效果補上")
	assert_eq(state.get_flag("boom"), true, "之後鏡頭的效果補上")
	assert_eq(state.get_flag("done"), true, "on_end")
	assert_eq(events.size(), 0, "被跳過的事件不發")
	assert_true(changes[0] >= 1, "通知任務推進")
	r.skip()
	assert_eq(state.get_flag("n"), 11, "重複跳過沒有效果")


func test_hold_to_skip_timer() -> void:
	var h := HoldToSkip.new(1.0)
	assert_false(h.update(true, 0.6))
	assert_true(absf(h.progress() - 0.6) < 0.001)
	assert_false(h.update(false, 0.1), "放開歸零")
	assert_eq(h.progress(), 0.0)
	assert_false(h.update(true, 0.5))
	assert_true(h.update(true, 0.6), "按滿一秒")


func test_game_skip_from_view_input() -> void:
	var game: Node = tree.root.get_node("Game")
	var original: GameSession = game.get("session") as GameSession
	var dir: String = "user://test_cutscene_%d" % Time.get_ticks_usec()
	var s := GameSession.new(QuestDB.load_default(), dir)
	game.set("session", s)
	s.new_game()
	s.set_flag("slice.met_pear_seller", true)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "ring_bell")
	assert_true(game.call("play_cutscene", "slice_bell_nine"))
	assert_false(game.call("play_cutscene", "slice_bell_nine"), "不能同時兩段")
	(game.get("cutscene") as CutsceneRunner).skip()
	assert_false(game.call("is_in_cutscene"))
	assert_eq(int(s.state.get_flag("slice.bell_rings", 0)), 9, "跳過也算敲滿九下")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "rescue", "跳過後任務照樣推進")
	assert_false(game.call("play_cutscene", "no_such_cutscene"), "不存在的過場")
	game.set("session", original)
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)
