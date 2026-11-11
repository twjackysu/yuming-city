extends TestCase
## 對話：資料驗證、選項條件（條件不成立的選項消失）、效果推進任務、跳過不跳選項、依狀態換台詞。
## 遊戲裡的資料用 rb_sheila_meet（有選項）驗；目前劇情還沒用到的功能（選項的 if、text_if）用測試內的小對話驗。


func _db() -> DialogueDB:
	var db := DialogueDB.load_default()
	assert_eq(db.errors, PackedStringArray(), "對話資料沒有錯誤")
	return db


## 測試用的小對話：一句開場 → 三個選項（一個有條件）→ 道別（依旗標換台詞、設旗標）
func _memory_db() -> DialogueDB:
	var db := DialogueDB.new()
	db.add_dialogue({"id": "t_stall", "start": "hello", "nodes": {
		"hello": {"speaker": "S", "text": "T_HELLO", "next": "ask"},
		"ask": {"speaker": "S", "text": "T_ASK", "choices": [
			{"text": "T_C_BUY", "next": "bye", "do": {"set": {"t.bought": true}}},
			{"text": "T_C_LEAVE", "next": "bye"},
			{"text": "T_C_SECRET", "next": "bye", "if": {"not": {"flag": "t.secret_spent"}}},
		]},
		"bye": {"speaker": "S", "text": "T_BYE", "do": {"set": {"t.talked": true}}, "text_if": [
			{"if": {"flag": "t.count", "gte": 4}, "text": "T_BYE_MANY"},
			{"if": {"flag": "t.count", "gte": 2}, "text": "T_BYE_SOME"},
		]},
	}})
	assert_eq(db.errors, PackedStringArray(), "測試對話本身沒有錯")
	return db


func test_default_data_is_valid_and_keys_exist() -> void:
	var db: DialogueDB = _db()
	assert_true(db.has_dialogue("rb_sheila_meet"), "席菈的對話")
	assert_true(db.has_dialogue("rb_ada_wages"), "艾妲的對話")
	TranslationServer.set_locale("en")
	for key: String in db.translation_keys():
		assert_ne(TranslationServer.translate(key), StringName(key), "對話用到不存在的翻譯 key：" + key)
	TranslationServer.set_locale(str(tree.root.get_node("Settings").get("locale")))


func test_validation_catches_mistakes() -> void:
	var bad_next: PackedStringArray = DialogueDB.validate_dialogue({"id": "a", "start": "x", "nodes": {"x": {"speaker": "S", "text": "T", "next": "nope"}}})
	assert_true(bad_next.size() > 0 and bad_next[0].contains("nope"), "next 指向不存在的節點")
	var both: PackedStringArray = DialogueDB.validate_dialogue({"id": "a", "start": "x", "nodes": {
		"x": {"speaker": "S", "text": "T", "next": "y", "choices": [{"text": "C", "next": "y"}]},
		"y": {"speaker": "S", "text": "T"}}})
	assert_true(both.size() > 0, "next 與 choices 不能並存")
	var all_conditional: PackedStringArray = DialogueDB.validate_dialogue({"id": "a", "start": "x", "nodes": {
		"x": {"speaker": "S", "text": "T", "choices": [{"text": "C", "next": "y", "if": {"flag": "k"}}]},
		"y": {"speaker": "S", "text": "T"}}})
	assert_true(all_conditional.size() > 0, "所有選項都有條件會卡住")
	var orphan: PackedStringArray = DialogueDB.validate_dialogue({"id": "a", "start": "x", "nodes": {
		"x": {"speaker": "S", "text": "T"}, "lost": {"speaker": "S", "text": "T"}}})
	assert_true(orphan.size() == 1 and orphan[0].contains("lost"), "走不到的節點")
	var bad_effect: PackedStringArray = DialogueDB.validate_dialogue({"id": "a", "start": "x", "nodes": {
		"x": {"speaker": "S", "text": "T", "do": {"run": "os.exit"}}}})
	assert_true(bad_effect.size() > 0, "效果只能用 set／add")
	var old_condition: PackedStringArray = DialogueDB.validate_dialogue({"id": "a", "start": "x", "nodes": {
		"x": {"speaker": "S", "text": "T", "choices": [{"text": "C", "next": "y"}, {"text": "D", "next": "y", "if": {"memory_paid": "m"}}]},
		"y": {"speaker": "S", "text": "T"}}})
	assert_true(old_condition.size() > 0, "已經拿掉的條件（memory_paid）會被擋下來，不會默默當成不成立")


## 遊戲裡的資料：席菈的對話跳過只跳到選項為止，選項的效果寫進旗標，最後一句設 rb.sheila_met。
func test_sheila_meet_choice_sets_flags() -> void:
	var state := GameState.new()
	var r := DialogueRunner.new(_db(), state)
	var lines: Array[String] = []
	r.line_shown.connect(func(_speaker: String, text: String) -> void: lines.append(text))
	assert_true(r.start("rb_sheila_meet"))
	r.skip_to_choice()
	assert_eq(",".join(PackedStringArray(lines)),
		"DLG_RB_SHEILA_001,DLG_RB_SHEILA_002,DLG_RB_SHEILA_003,DLG_RB_SHEILA_004,DLG_RB_SHEILA_005", "跳過只跳到選項為止")
	assert_eq(r.visible_choices.size(), 2, "兩個選項")
	assert_false(r.choose(5), "超出範圍的選項無效")
	assert_true(r.choose(0), "把傷口給她看")
	assert_eq(state.get_flag("rb.showed_sheila_wound"), true, "選項效果")
	assert_eq(r.current_text(), "DLG_RB_SHEILA_L_SHOW")
	assert_false(bool(state.get_flag("rb.sheila_met", false)), "還沒說完不設旗標")
	r.advance()
	assert_eq(r.current_text(), "DLG_RB_SHEILA_006")
	assert_eq(state.get_flag("rb.sheila_met"), true, "最後一句設旗標")
	var done: Array[bool] = [false]
	r.finished.connect(func(_id: String) -> void: done[0] = true)
	assert_false(r.advance(), "最後一句之後結束")
	assert_true(done[0] and not r.is_running())


## 對話的效果發出 state_changed → 任務重新檢查條件 → 推進（外殼就是這樣接 GameSession.advance()）。
func test_choice_effect_advances_quest() -> void:
	var state := GameState.new()
	var qdb := QuestDB.new()
	qdb.add_quest({"id": "t_quest", "title": "T_Q", "stages": [
		{"id": "talk", "objective": "T_OBJ_TALK", "done_when": {"flag": "t.talked"}},
		{"id": "after", "objective": "T_OBJ_AFTER", "done_when": {"flag": "t.never"}},
	]})
	assert_eq(qdb.errors, PackedStringArray(), "測試任務本身沒有錯")
	var quests := QuestRunner.new(qdb, state)
	quests.start("t_quest")
	var r := DialogueRunner.new(_memory_db(), state)
	r.state_changed.connect(quests.evaluate)
	var lines: Array[String] = []
	r.line_shown.connect(func(_speaker: String, text: String) -> void: lines.append(text))
	assert_true(r.start("t_stall"))
	r.skip_to_choice()
	assert_eq(",".join(PackedStringArray(lines)), "T_HELLO,T_ASK", "跳過只跳到選項為止")
	assert_eq(r.visible_choices.size(), 3, "三個選項")
	assert_eq(quests.stage_of("t_quest"), "talk", "還沒說完不推進")
	assert_true(r.choose(0), "買")
	assert_eq(state.get_flag("t.bought"), true, "選項效果")
	assert_eq(r.current().get("text"), "T_BYE")
	assert_eq(quests.stage_of("t_quest"), "after", "道別節點設旗標 → 任務推進")
	assert_false(r.advance(), "最後一句之後結束")


func test_condition_hides_choice() -> void:
	var db: DialogueDB = _memory_db()
	var state := GameState.new()
	var r := DialogueRunner.new(db, state)
	r.start("t_stall")
	r.skip_to_choice()
	var texts: Array[String] = []
	for c: Dictionary in r.visible_choices:
		texts.append(str(c["text"]))
	assert_true(texts.has("T_C_SECRET"), "條件成立時選項在")
	var state2 := GameState.new()
	state2.set_flag("t.secret_spent", true)
	var r2 := DialogueRunner.new(db, state2)
	r2.start("t_stall")
	r2.skip_to_choice()
	assert_eq(r2.visible_choices.size(), 2, "條件不成立，那個選項消失")
	for c: Dictionary in r2.visible_choices:
		assert_ne(str(c["text"]), "T_C_SECRET")
	assert_false(r2.choose(2), "消失的選項選不到（索引照看得見的算）")
	assert_true(r2.choose(1), "看得見的最後一個選得到")


## 依狀態換台詞（text_if，第一個成立的）；流程不變，line_shown 也是換過的台詞。
func test_text_if_picks_first_match() -> void:
	var db: DialogueDB = _memory_db()
	var cases: Array = [
		[0, "T_BYE"],
		[1, "T_BYE"],
		[2, "T_BYE_SOME"],
		[3, "T_BYE_SOME"],
		[4, "T_BYE_MANY"],
		[9, "T_BYE_MANY"],
	]
	for c: Array in cases:
		var st := GameState.new()
		st.set_flag("t.count", c[0])
		var r := DialogueRunner.new(db, st)
		var seen: Array[String] = []
		r.line_shown.connect(func(_sp: String, text: String) -> void: seen.append(text))
		assert_true(r.start("t_stall"))
		r.skip_to_choice()
		assert_true(r.choose(1))
		assert_eq(r.current_text(), str(c[1]), "t.count＝%d" % c[0])
		assert_eq(seen[seen.size() - 1], str(c[1]), "line_shown 也是換過的台詞")


func test_text_if_validation() -> void:
	var bad: PackedStringArray = DialogueDB.validate_dialogue({"id": "x", "start": "a", "nodes": {
		"a": {"speaker": "S", "text": "T", "text_if": [{"text": "U"}]}}})
	assert_false(bad.is_empty(), "text_if 缺 if 要報錯")
	var ok: PackedStringArray = DialogueDB.validate_dialogue({"id": "x", "start": "a", "nodes": {
		"a": {"speaker": "S", "text": "T", "text_if": [{"if": {"flag": "f"}, "text": "U"}]}}})
	assert_eq(ok, PackedStringArray())
