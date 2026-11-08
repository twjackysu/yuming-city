extends TestCase
## 對話：資料驗證、選項條件（付過的記憶讓選項消失）、效果推進任務、跳過不跳選項。


func _db() -> DialogueDB:
	var db := DialogueDB.load_default()
	assert_eq(db.errors, PackedStringArray(), "對話資料沒有錯誤")
	return db


func test_default_data_is_valid_and_keys_exist() -> void:
	var db: DialogueDB = _db()
	assert_true(db.has_dialogue("slice_pear_seller"), "梨販對話")
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


func test_pear_seller_buy_route_advances_quest() -> void:
	var state := GameState.new()
	var quests := QuestRunner.new(QuestDB.load_default(), state)
	quests.start(GameSession.MAIN_QUEST)
	var r := DialogueRunner.new(_db(), state)
	r.state_changed.connect(quests.evaluate)
	var lines: Array[String] = []
	r.line_shown.connect(func(_speaker: String, text: String) -> void: lines.append(text))
	assert_true(r.start("slice_pear_seller"))
	r.skip_to_choice()
	assert_eq(",".join(PackedStringArray(lines)), "DLG_PEAR_001,DLG_PEAR_002,DLG_PEAR_003", "跳過只跳到選項為止")
	assert_eq(r.visible_choices.size(), 3, "三個選項")
	assert_true(r.choose(0), "買梨")
	assert_eq(state.get_flag("slice.bought_pears"), true, "選項效果")
	assert_eq(quests.stage_of(GameSession.MAIN_QUEST), "explore_town", "還沒說完不推進")
	r.advance()
	assert_eq(r.current().get("text"), "DLG_PEAR_007")
	assert_eq(quests.stage_of(GameSession.MAIN_QUEST), "ring_bell", "道別節點設旗標 → 任務推進")
	var done: Array[bool] = [false]
	r.finished.connect(func(_id: String) -> void: done[0] = true)
	assert_false(r.advance(), "最後一句之後結束")
	assert_true(done[0] and not r.is_running())


func test_paid_memory_hides_choice() -> void:
	var state := GameState.new()
	var r := DialogueRunner.new(_db(), state)
	r.start("slice_pear_seller")
	r.skip_to_choice()
	var texts: Array[String] = []
	for c: Dictionary in r.visible_choices:
		texts.append(str(c["text"]))
	assert_true(texts.has("DLG_PEAR_C_FATHER"), "還記得父親時可以提他")
	var state2 := GameState.new()
	state2.pay_memory("arch_father_last_talk")
	var r2 := DialogueRunner.new(_db(), state2)
	r2.start("slice_pear_seller")
	r2.skip_to_choice()
	assert_eq(r2.visible_choices.size(), 2, "付出記憶後，那個選項消失")
	for c: Dictionary in r2.visible_choices:
		assert_ne(str(c["text"]), "DLG_PEAR_C_FATHER")
	assert_false(r2.choose(5), "超出範圍的選項無效")


func test_ada_aftermath_reflects_paid_memory() -> void:
	var db: DialogueDB = DialogueDB.load_default()
	assert_eq(db.errors, PackedStringArray(), "對話資料沒有錯")
	var keep := GameState.new()
	var r := DialogueRunner.new(db, keep)
	assert_true(r.start("slice_ada_aftermath"))
	r.advance()  # 死者名單那句
	assert_eq(r.visible_choices.size(), 2, "記得父親：可以答，也可以反問")
	var paid := GameState.new()
	paid.pay_memory("arch_father_last_talk")
	var r2 := DialogueRunner.new(db, paid)
	assert_true(r2.start("slice_ada_aftermath"))
	r2.advance()
	assert_eq(r2.visible_choices.size(), 1, "付了石拱的記憶：只剩「……真的不準？」")
	assert_eq(str(r2.visible_choices[0]["text"]), "DLG_AFTER_C_ASK")


## 收束的死者名單：依救出人數與車隊傷者換台詞（text_if，第一個成立的）。
func test_ada_death_toll_reflects_rescue_and_convoy() -> void:
	var db: DialogueDB = DialogueDB.load_default()
	var cases: Array = [
		[3, 1, "DLG_AFTER_DEAD_31"],
		[4, 0, "DLG_AFTER_DEAD_29"],
		[4, 1, "DLG_AFTER_DEAD_30"],
		[3, 3, "DLG_AFTER_DEAD_33"],
		[4, 4, "DLG_AFTER_DEAD_33"],
	]
	for c: Array in cases:
		var st := GameState.new()
		st.set_flag("slice.rescued_count", c[0])
		st.set_flag("slice.convoy_injured", c[1])
		var r := DialogueRunner.new(db, st)
		var seen: Array[String] = []
		r.line_shown.connect(func(_sp: String, text: String) -> void: seen.append(text))
		assert_true(r.start("slice_ada_aftermath"))
		assert_eq(r.current_text(), str(c[2]), "救出 %d、傷者 %d" % [c[0], c[1]])
		assert_eq(seen, [str(c[2])] as Array[String], "line_shown 也是換過的台詞")


func test_text_if_validation() -> void:
	var bad: PackedStringArray = DialogueDB.validate_dialogue({"id": "x", "start": "a", "nodes": {
		"a": {"speaker": "S", "text": "T", "text_if": [{"text": "U"}]}}})
	assert_false(bad.is_empty(), "text_if 缺 if 要報錯")
	var ok: PackedStringArray = DialogueDB.validate_dialogue({"id": "x", "start": "a", "nodes": {
		"a": {"speaker": "S", "text": "T", "text_if": [{"if": {"flag": "f"}, "text": "U"}]}}})
	assert_eq(ok, PackedStringArray())



## 收束：席菈提前燒過燃燒劍（手傷 2）→ 艾妲最後一句多叮嚀包手；只燒一次（石拱路線）就是原句。
func test_ada_notices_sheila_hand_after_two_burns() -> void:
	var db: DialogueDB = DialogueDB.load_default()
	for c: Array in [[1, "DLG_AFTER_005"], [2, "DLG_AFTER_005_HAND"]]:
		var st := GameState.new()
		st.set_flag("sheila.hand_injury", c[0])
		var r := DialogueRunner.new(db, st)
		assert_true(r.start("slice_ada_aftermath"))
		r.advance()
		assert_true(r.choose(r.visible_choices.size() - 1), "選「……真的不準？」")
		assert_eq(r.current_text(), "DLG_AFTER_004")
		r.advance()
		assert_eq(r.current_text(), str(c[1]), "手傷 %d" % c[0])
