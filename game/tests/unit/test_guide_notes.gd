extends TestCase
## 攻略筆記（D-148，07-chapter1-door.md 系統 1）：資料、可信度狀態、標「我不確定」、旗標推翻、
## 任務／對話用的條件、存檔 v1 → v2 遷移。


func test_data_is_valid_and_translated() -> void:
	var g: GuideNotes = GuideNotes.load_default()
	assert_eq(g.errors.size(), 0, "資料沒有錯：%s" % ", ".join(g.errors))
	assert_eq(g.remembered_ids().size(), 6, "第 3 段寫下 6 條（諾恩記得的攻略）")
	assert_eq(g.ids().size(), 7, "再加第 3 章的空白條目")
	assert_eq(g.ids_for_chapter("ch1").size(), 4, "第 1 章推翻 4 條")
	assert_true(g.is_blank_entry("clapper_heartbeat"), "攻略沒有寫：送葬者跟著什麼走")
	assert_false("clapper_heartbeat" in g.remembered_ids(), "空白條目不在畫地圖時寫下的那些裡")
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		for id: String in g.ids():
			var second: String = GuideNotes.confirmed_key(id) if g.is_blank_entry(id) else GuideNotes.wrong_key(id)
			for key: String in [GuideNotes.text_key(id), second]:
				assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
		for s: String in ["SURE", "UNSURE", "WRONG", "CONFIRMED", "BLANK"]:
			assert_ne(tr("GUIDE_STATUS_" + s), "GUIDE_STATUS_" + s, "%s 可信度文字 %s" % [loc, s])
	TranslationServer.set_locale("en")


func test_write_mark_and_refute() -> void:
	var g: GuideNotes = GuideNotes.load_default()
	var s := GameState.new()
	assert_eq(GuideNotes.status(s, "stair_arrows"), GuideNotes.UNWRITTEN, "還沒寫下")
	assert_false(GuideNotes.set_unsure(s, "stair_arrows", true), "沒寫下的不能標")
	assert_eq(GuideNotes.write(s, g.remembered_ids()).size(), 6, "寫下 6 條")
	assert_eq(GuideNotes.write(s, g.remembered_ids()).size(), 0, "寫過的不會重寫")
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


## 空白條目（D-163）：guide_blank 寫下 → 狀態 blank、不能標我不確定、不會被推翻；自己觀察到之後照 confirmed_when 證實。
func test_blank_entry_written_then_confirmed() -> void:
	var g: GuideNotes = GuideNotes.load_default()
	var s := GameState.new()
	assert_eq(GuideNotes.status(s, "clapper_heartbeat"), GuideNotes.UNWRITTEN)
	StoryLogic.apply({"guide_blank": ["clapper_heartbeat"]}, s)
	assert_eq(GuideNotes.status(s, "clapper_heartbeat"), GuideNotes.BLANK, "攻略沒有寫")
	assert_false(GuideNotes.set_unsure(s, "clapper_heartbeat", true), "空白的不能標我不確定")
	StoryLogic.apply({"guide_write": ["clapper_heartbeat"]}, s)
	assert_eq(GuideNotes.status(s, "clapper_heartbeat"), GuideNotes.BLANK, "寫過的不會被改成攻略寫的")
	assert_true(StoryLogic.check({"guide": "clapper_heartbeat", "is": "blank"}, s), "條件可以判斷空白")
	assert_eq(g.evaluate(s).size(), 0, "還沒觀察到")
	s.set_flag("ch3.rhythm_found", true)
	var changes: Array[Dictionary] = g.evaluate(s)
	assert_eq(changes.size(), 1)
	assert_eq(changes[0]["result"], "confirmed", "自己觀察到 → 證實")
	assert_eq(GuideNotes.status(s, "clapper_heartbeat"), GuideNotes.CONFIRMED)
	var back := GameState.from_dict(s.to_dict())
	assert_eq(GuideNotes.status(back, "clapper_heartbeat"), GuideNotes.CONFIRMED, "存讀檔之後一樣")
	var fresh := GameState.new()
	StoryLogic.apply({"guide_blank": ["clapper_heartbeat"]}, fresh)
	assert_eq(GuideNotes.status(GameState.from_dict(fresh.to_dict()), "clapper_heartbeat"), GuideNotes.BLANK, "空白也存得住")


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


func test_journal_shows_guide_section() -> void:
	var game: Node = tree.root.get_node("Game")
	var original: GameSession = game.get("session") as GameSession
	var s := GameSession.new(QuestDB.load_default(), "user://test_guide_view_%d" % Time.get_ticks_usec())
	s.state = GameState.new()
	game.set("session", s)
	var view := JournalView.new()
	tree.root.add_child(view)
	await tree.process_frame
	view.open()
	assert_eq(view.guide_rows_shown.size(), 0, "切片：還沒寫下攻略，整段不出現")
	assert_true(view.find_child("GuideHead", true, false) == null)
	view.close()
	JournalView.guide_demo(s)
	view.open()
	await tree.process_frame
	assert_eq(view.guide_rows_shown.size(), 6, "寫下 6 條")
	assert_not_null(view.find_child("GuideHead", true, false), "有「攻略筆記」小標")
	assert_eq(view.shown_entry_count(), 0, "記憶條目數不含攻略筆記")
	var stair: Node = view.find_child("Guide_stair_arrows", true, false)
	assert_not_null(stair)
	assert_not_null(stair.find_child("Strike", true, false), "被推翻的整句劃掉")
	assert_eq((stair.find_child("Real", true, false) as Label).text, "GUIDE_STAIR_ARROWS_WRONG", "下面是現實裡看到的事")
	var door: Node = view.find_child("Guide_sealed_door", true, false)
	assert_true(door.find_child("Strike", true, false) == null, "還沒推翻的不劃")
	assert_eq((door.find_child("Status", true, false) as Label).text, "GUIDE_STATUS_SURE")
	assert_eq((view.find_child("Guide_purifier", true, false).find_child("Status", true, false) as Label).text, "GUIDE_STATUS_UNSURE")
	var strike: ColorRect = stair.find_child("Strike", true, false) as ColorRect
	assert_true(strike.size.x > 40.0, "墨線跟著字的寬度")
	view.close()
	# 第 3 章：空白條目（D-163）——小標「攻略沒有寫」，沒有墨線；證實之後下面多一行自己看到的事
	StoryLogic.apply({"guide_blank": ["clapper_heartbeat"]}, s.state)
	view.open()
	await tree.process_frame
	assert_eq(view.guide_rows_shown.size(), 7, "多一條空白")
	var blank: Node = view.find_child("Guide_clapper_heartbeat", true, false)
	assert_not_null(blank)
	assert_eq((blank.find_child("Status", true, false) as Label).text, "GUIDE_STATUS_BLANK")
	assert_true(blank.find_child("Strike", true, false) == null, "空白的不劃")
	assert_true(blank.find_child("Real", true, false) == null, "還沒觀察到：沒有下一行")
	view.close()
	s.set_flag("ch3.rhythm_found", true)
	view.open()
	await tree.process_frame
	blank = view.find_child("Guide_clapper_heartbeat", true, false)
	assert_eq((blank.find_child("Status", true, false) as Label).text, "GUIDE_STATUS_CONFIRMED")
	assert_eq((blank.find_child("Real", true, false) as Label).text, "GUIDE_CLAPPER_HEARTBEAT_CONFIRMED", "自己觀察到的那一行")
	view.close()
	view.queue_free()
	game.set("session", original)
	tree.paused = false
	await tree.process_frame
