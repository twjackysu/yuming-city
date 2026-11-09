extends TestCase
## 第 1 章銜接（D-149）：切片完成 → 第 1 章主線、章節、檢查點與關卡；舊存檔補開第 1 章；
## 章節卡只呼叫一次、被釋放時不呼叫；酒館的說話點跟著任務階段；第 1 章的對話資料與翻譯。

var _dir: String = ""


func before_each() -> void:
	_dir = "user://test_chapter1_%d" % Time.get_ticks_usec()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _play_slice(s: GameSession) -> void:
	s.set_flag("slice.met_pear_seller", true)
	s.set_flag("slice.bell_rings", 9)
	s.set_flag("slice.rescue_done", true)
	s.set_flag("slice.sheila_talked", true)
	s.set_flag("slice.ashwalker_defeated", true)
	s.set_flag("slice.convoy_through", true)


func test_slice_complete_starts_chapter1() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.new_game()
	assert_eq(s.main_quest(), "slice_main", "新遊戲的主線是切片")
	assert_eq(s.state.chapter, "slice_frostbridge")
	_play_slice(s)
	assert_eq(s.quests.stage_of("slice_main"), "aftermath")
	assert_false(s.state.quests.has("ch1_main"), "切片還沒完成：第 1 章沒開始")
	s.set_flag("slice.cellar_entered", true)
	assert_true(s.is_slice_complete(), "切片完成")
	assert_eq(s.main_quest(), "ch1_main", "主線換成第 1 章")
	assert_eq(s.quests.stage_of("ch1_main"), "tavern_noon")
	assert_eq(s.state.chapter, "ch1")
	assert_eq(s.state.checkpoint, "ch1_tavern")
	assert_eq(s.objective_key(), "Q_CH1_OBJ_NOON", "HUD 目標換成第 1 章")
	assert_eq(Game.level_for_checkpoint(s.state.checkpoint), "tavern", "第 1 章的檢查點在酒館")
	assert_eq(Game.level_for_checkpoint("aftermath"), "frostbridge", "切片的檢查點照舊在霜橋鎮")
	# 進第 1 章時自動存檔：重來回到酒館
	var other := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(other.load_slot(GameSession.AUTO_SLOT), SaveCodec.Status.OK)
	assert_eq(other.state.checkpoint, "ch1_tavern", "自動存檔在第 1 章開頭")
	assert_eq(other.quests.stage_of("ch1_main"), "tavern_noon")
	assert_eq(other.state.chapter, "ch1")


func test_old_save_with_finished_slice_opens_chapter1() -> void:
	# D-149 之前的存檔：切片已完成、沒有第 1 章
	var old := GameState.new()
	old.checkpoint = "aftermath"
	old.quests = {"slice_main": StoryLogic.QUEST_DONE}
	old.flags = {"slice.complete": true, "slice.cellar_entered": true}
	DirAccess.make_dir_recursive_absolute(_dir)
	assert_eq(SaveCodec.write_file(_dir.path_join("slot1.json"), old), OK)
	var s := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(s.load_slot("slot1"), SaveCodec.Status.OK)
	assert_eq(s.quests.stage_of("ch1_main"), "tavern_noon", "讀檔補開第 1 章")
	assert_eq(s.state.chapter, "ch1")
	assert_eq(s.state.checkpoint, "ch1_tavern")
	assert_eq(s.upgrade_chapters(), 0, "已經開過的不會再開")
	# 切片還沒完成的舊存檔不動
	var mid := GameState.new()
	mid.checkpoint = "undertaker"
	mid.quests = {"slice_main": "escort_convoy"}
	assert_eq(SaveCodec.write_file(_dir.path_join("slot2.json"), mid), OK)
	assert_eq(s.load_slot("slot2"), SaveCodec.Status.OK)
	assert_false(s.state.quests.has("ch1_main"), "切片沒完成：不補開")
	assert_eq(s.state.checkpoint, "undertaker")
	assert_eq(s.main_quest(), "slice_main")


func test_chapter_effect_validates() -> void:
	assert_eq(StoryLogic.validate_effects({"chapter": "ch1"}), "", "chapter 是合法的效果")
	var st := GameState.new()
	StoryLogic.apply({"chapter": "ch1"}, st)
	assert_eq(st.chapter, "ch1")
	var db: QuestDB = QuestDB.load_default()
	assert_true(db.has_quest("ch1_main"), "有第 1 章主線")
	for qid: String in GameSession.MAIN_QUESTS:
		assert_true(db.has_quest(qid), "主線 %s 存在" % qid)
	for link: Dictionary in GameSession.CHAPTER_CHAIN:
		assert_true(GameSession.MAIN_QUESTS.has(str(link["start"])), "章節銜接的主線在 MAIN_QUESTS")


func test_chapter_card_calls_done_once() -> void:
	var host := Node.new()
	tree.root.add_child(host)
	var calls: Array[int] = [0]
	var card: ChapterCard = ChapterCard.play(host, "CH1_CARD_NUMBER", "CH1_CARD_TITLE", func() -> void: calls[0] += 1, 0.01)
	assert_eq(card.title_text(), tr("CH1_CARD_TITLE"))
	for i: int in 30:
		await tree.process_frame
		if card.finished:
			break
	assert_true(card.finished, "播完")
	assert_eq(calls[0], 1, "播完呼叫一次")
	card.finish()
	assert_eq(calls[0], 1, "再結束一次也不會重複呼叫")
	# 關卡先被釋放：卡片跟著消失，不會換關卡
	var calls2: Array[int] = [0]
	var host2 := Node.new()
	tree.root.add_child(host2)
	ChapterCard.play(host2, "CH1_CARD_NUMBER", "CH1_CARD_TITLE", func() -> void: calls2[0] += 1, 0.2)
	await tree.process_frame
	host2.free()
	for i: int in 20:
		await tree.process_frame
	assert_eq(calls2[0], 0, "被釋放的卡片不呼叫")
	host.queue_free()
	await tree.process_frame


func test_chapter1_dialogues_are_valid_and_translated() -> void:
	var db: DialogueDB = DialogueDB.load_default()
	for id: String in ["ch1_noon", "ch1_dinner", "ch1_map", "ch1_map_end"]:
		assert_true(db.has_dialogue(id), "有對話 %s" % id)
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		for key: String in ["SPK_MISHA", "SPK_KEEPER", "SPK_LEO_LETTER", "CH1_CARD_NUMBER", "CH1_CARD_TITLE",
				"CH1_TO_BE_CONTINUED", "GUIDE_MARK_TITLE", "GUIDE_MARK_HINT", "GUIDE_MARK_DONE", "Q_CH1_MAIN_TITLE", "Q_CH1_OBJ_NOON", "Q_CH1_OBJ_DINNER", "Q_CH1_OBJ_MAP", "Q_CH1_OBJ_CELLAR"]:
			assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
	TranslationServer.set_locale("en")


func test_guide_mark_view_toggles_and_confirms() -> void:
	var notes: GuideNotes = GuideNotes.load_default()
	var st := GameState.new()
	GuideNotes.write(st, PackedStringArray(["stair_arrows", "sealed_door"]))
	GuideNotes.set_unsure(st, "sealed_door", true)
	var host := Node.new()
	tree.root.add_child(host)
	var got: Array[PackedStringArray] = []
	var view: GuideMarkView = GuideMarkView.open_on(host, st, notes)
	view.confirmed.connect(func(ids: PackedStringArray) -> void: got.append(ids))
	await tree.process_frame
	assert_eq(view.entry_ids, PackedStringArray(["stair_arrows", "sealed_door"]), "只列寫下的條目（照資料順序）")
	assert_true(tree.paused, "打開時暫停")
	assert_false(view.is_unsure("stair_arrows"))
	assert_true(view.is_unsure("sealed_door"), "已經標過的照舊")
	(view.rows["stair_arrows"] as Button).pressed.emit()
	(view.rows["sealed_door"] as Button).pressed.emit()
	assert_true(view.is_unsure("stair_arrows"), "點一下 → 我不確定")
	assert_false(view.is_unsure("sealed_door"), "再點 → 確定")
	assert_eq(GuideNotes.status(st, "stair_arrows"), GuideNotes.SURE, "按「就這樣」之前不寫進狀態")
	view.done_button.pressed.emit()
	assert_false(tree.paused, "就這樣 → 解除暫停")
	assert_eq(got.size(), 1, "confirmed 一次")
	assert_eq(got[0], PackedStringArray(["stair_arrows"]))
	assert_eq(GuideNotes.status(st, "stair_arrows"), GuideNotes.UNSURE)
	assert_eq(GuideNotes.status(st, "sealed_door"), GuideNotes.SURE)
	view.confirm()
	assert_eq(got.size(), 1, "再按也不會重複")
	await tree.process_frame
	# 被釋放（回標題）時不會讓遊戲停在暫停
	var view2: GuideMarkView = GuideMarkView.open_on(host, st, notes)
	await tree.process_frame
	assert_true(tree.paused)
	view2.free()
	assert_false(tree.paused, "釋放時解除暫停")
	host.queue_free()
	await tree.process_frame


## 段落 4（D-151）：只有第 1 章的白天階段才是白天的霜橋鎮；開發旗標照正式流程推進；油燈的對話與翻譯。
func test_day_town_stages_and_dialogue() -> void:
	var Frost: GDScript = load("res://scenes/levels/frostbridge.gd") as GDScript
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.new_game()
	assert_false(bool(Frost.call("is_day_chapter", s)), "切片：冬夜")
	_play_slice(s)
	s.set_flag("slice.cellar_entered", true)
	assert_false(bool(Frost.call("is_day_chapter", s)), "酒館的階段：不是白天的霜橋鎮")
	Frost.call("dev_start_day", s, "day_north")
	assert_eq(s.quests.stage_of("ch1_main"), "day_north")
	assert_eq(s.state.checkpoint, "ch1_day_town")
	assert_eq(Game.level_for_checkpoint("ch1_day_town"), "frostbridge", "出門 → 霜橋鎮")
	assert_true(bool(Frost.call("is_day_chapter", s)), "出了酒館：白天")
	assert_eq(s.objective_key(), "Q_CH1_OBJ_DAY_NORTH")
	Frost.call("dev_start_day", s, "stairs")
	assert_eq(s.quests.stage_of("ch1_main"), "stairs")
	assert_eq(s.state.checkpoint, "ch1_lamp")
	assert_true(bool(Frost.call("is_day_chapter", s)), "拿到油燈：還在白天的霜橋鎮（一百七十二階還沒做）")
	# 對話：付了石拱記憶 → 艾妲的第一句換成「你連你爸都忘了」
	for paid: bool in [false, true]:
		var st := GameState.new()
		if paid:
			st.memories_paid.append("arch_father_last_talk")
		var r := DialogueRunner.new(Game.dialogues, st)
		assert_true(r.start("ch1_ada_lamp"))
		assert_eq(r.current_text(), "DLG_CH1_ADA_001_FORGOT" if paid else "DLG_CH1_ADA_001")
	assert_true(Game.dialogues.has_dialogue("ch1_north_day"), "有北街的對話")
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		for key: String in ["DLG_CH1_ADA_001_FORGOT", "DLG_CH1_ADA_004", "DLG_CH1_NORTH_003", "Q_CH1_OBJ_DAY_NORTH",
				"Q_CH1_OBJ_ADA_LAMP", "Q_CH1_OBJ_STAIRS", "CH1_NEXT_MORNING"]:
			assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
	TranslationServer.set_locale("en")
