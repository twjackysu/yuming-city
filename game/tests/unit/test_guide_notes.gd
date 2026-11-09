extends TestCase
## 攻略筆記（D-148，07-chapter1-door.md 系統 1）：資料、可信度狀態、標「我不確定」、旗標推翻、
## 任務／對話用的條件、存檔 v1 → v2 遷移。


func test_data_is_valid_and_translated() -> void:
	var g: GuideNotes = GuideNotes.load_default()
	assert_eq(g.errors.size(), 0, "資料沒有錯：%s" % ", ".join(g.errors))
	assert_eq(g.ids().size(), 6, "第 3 段寫下 6 條")
	assert_eq(g.ids_for_chapter("ch1").size(), 4, "第 1 章推翻 4 條")
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		for id: String in g.ids():
			for key: String in [GuideNotes.text_key(id), GuideNotes.wrong_key(id)]:
				assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
		for s: String in ["SURE", "UNSURE", "WRONG", "CONFIRMED"]:
			assert_ne(tr("GUIDE_STATUS_" + s), "GUIDE_STATUS_" + s, "%s 可信度文字 %s" % [loc, s])
	TranslationServer.set_locale("en")


func test_write_mark_and_refute() -> void:
	var g: GuideNotes = GuideNotes.load_default()
	var s := GameState.new()
	assert_eq(GuideNotes.status(s, "stair_arrows"), GuideNotes.UNWRITTEN, "還沒寫下")
	assert_false(GuideNotes.set_unsure(s, "stair_arrows", true), "沒寫下的不能標")
	assert_eq(GuideNotes.write(s, g.ids()).size(), 6, "寫下 6 條")
	assert_eq(GuideNotes.write(s, g.ids()).size(), 0, "寫過的不會重寫")
	assert_eq(GuideNotes.status(s, "stair_arrows"), GuideNotes.SURE, "預設確定")
	assert_true(GuideNotes.set_unsure(s, "stair_arrows", true))
	assert_eq(GuideNotes.status(s, "stair_arrows"), GuideNotes.UNSURE, "標了我不確定")
	assert_eq(g.evaluate(s).size(), 0, "條件還沒成立")
	s.set_flag("ch1.stair_trap_sprung", true)
	s.set_flag("ch1.met_kord", true)
	var changes: Array[Dictionary] = g.evaluate(s)
	assert_eq(changes.size(), 2, "兩條被推翻")
	assert_eq(changes[0], {"id": "stair_arrows", "result": "wrong", "was_unsure": true}, "標了不確定的 → 「果然」")
	assert_eq(changes[1], {"id": "city_of_monsters", "result": "wrong", "was_unsure": false}, "沒標的 → 席菈看他一眼")
	assert_eq(GuideNotes.status(s, "stair_arrows"), GuideNotes.WRONG)
	assert_true(GuideNotes.was_unsure(s, "stair_arrows"), "被推翻之後還記得當初標了")
	assert_false(GuideNotes.set_unsure(s, "stair_arrows", false), "被推翻的不能再改")
	assert_eq(g.evaluate(s).size(), 0, "不會重複推翻")


func test_confirmed_when() -> void:
	var g := GuideNotes.new()
	g.entries = [{"id": "x", "confirmed_when": {"flag": "seen"}, "wrong_when": {"flag": "nope"}}]
	assert_eq(g.validate().size(), 0)
	var s := GameState.new()
	GuideNotes.write(s, PackedStringArray(["x"]))
	s.set_flag("seen", true)
	assert_eq(g.evaluate(s)[0]["result"], "confirmed", "證實")
	assert_eq(GuideNotes.status(s, "x"), GuideNotes.CONFIRMED)
	var bad := GuideNotes.new()
	bad.entries = [{"id": "a", "wrong_when": {"bogus": 1}}, {"id": "a"}]
	assert_eq(bad.validate().size(), 2, "壞條件、重複 id 都被擋")


func test_story_logic_condition_and_effect() -> void:
	var s := GameState.new()
	StoryLogic.apply({"guide_write": ["sealed_door", "purifier"]}, s)
	assert_true(StoryLogic.check({"guide": "sealed_door", "is": "sure"}, s), "效果寫下條目")
	assert_true(StoryLogic.check({"guide": "usurper", "is": "unwritten"}, s))
	GuideNotes.set_unsure(s, "purifier", true)
	assert_true(StoryLogic.check({"guide": "purifier", "is": "unsure"}, s))
	assert_eq(StoryLogic.validate_condition({"guide": "purifier", "is": "unsure", "was_unsure": true}), "")
	assert_ne(StoryLogic.validate_condition({"guide": "purifier", "is": "maybe"}), "", "is 只能是那五種")
	assert_eq(StoryLogic.validate_effects({"guide_write": ["purifier"]}), "")
	s.set_flag("ch1.saw_empty_furnace", true)
	GuideNotes.load_default().evaluate(s)
	assert_true(StoryLogic.check({"guide": "purifier", "is": "wrong", "was_unsure": true}, s), "「果然」的條件")
	assert_false(StoryLogic.check({"guide": "purifier", "is": "wrong", "was_unsure": false}, s))


func test_session_refutes_on_advance_and_saves() -> void:
	var dir: String = "user://test_guide_%d" % Time.get_ticks_usec()
	var session := GameSession.new(QuestDB.load_default(), dir)
	session.new_game()
	var got: Array[Dictionary] = []
	session.guide_changed.connect(func(c: Array[Dictionary]) -> void: got.append_array(c))
	GuideNotes.write(session.state, session.guide.ids())
	GuideNotes.set_unsure(session.state, "sealed_door", true)
	session.set_flag("ch1.door_opened", true)
	assert_eq(got.size(), 1, "set_flag 推進時推翻並發訊號")
	assert_eq(str(got[0]["id"]), "sealed_door")
	assert_eq(session.save("slot1"), OK)
	var other := GameSession.new(QuestDB.load_default(), dir)
	assert_eq(other.load_slot("slot1"), SaveCodec.Status.OK)
	assert_eq(GuideNotes.status(other.state, "sealed_door"), GuideNotes.WRONG, "讀檔後還是被推翻")
	assert_true(GuideNotes.was_unsure(other.state, "sealed_door"), "標記也存了")
	assert_eq(GuideNotes.status(other.state, "purifier"), GuideNotes.SURE)
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func test_migrate_v1_save_gets_empty_guide() -> void:
	var v1: Dictionary = {"version": 1, "saved_at": "2026-11-08T00:00:00", "state": {
		"chapter": "slice_frostbridge", "checkpoint": "aftermath",
		"flags": {"slice.bell_rings": 9}, "quests": {"slice_main": "aftermath"}, "memories_paid": ["arch_father_last_talk"]}}
	var migrated: Dictionary = SaveCodec.migrate(v1)
	assert_eq(int(migrated["version"]), SaveCodec.CURRENT_VERSION)
	assert_eq((migrated["state"] as Dictionary)["guide"], {}, "v1 → v2 補上空的攻略筆記")
	assert_false((v1["state"] as Dictionary).has("guide"), "輸入不會被修改")
	var r: Dictionary = SaveCodec.decode(JSON.stringify(v1))
	assert_eq(int(r["status"]), SaveCodec.Status.OK)
	assert_eq(int(r["from_version"]), 1)
	var st: GameState = r["state"] as GameState
	assert_eq(st.checkpoint, "aftermath", "切片的存檔照樣停在原本的檢查點")
	assert_true(st.has_paid_memory("arch_father_last_talk"))
	assert_eq(GuideNotes.status(st, "stair_arrows"), GuideNotes.UNWRITTEN, "切片還沒寫下攻略")
