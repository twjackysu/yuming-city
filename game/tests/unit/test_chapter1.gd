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
	assert_eq(Game.level_for_checkpoint("ch1_lamp"), "stairs", "拿到油燈之後的檢查點在一百七十二階（D-152）")
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


## 一百七十二階（D-152）：方形螺旋的路線參數、射箭陷阱推翻攻略筆記、走到底進下一個階段。
func test_stairs_path_trap_and_bottom() -> void:
	var Stairs: GDScript = load("res://scenes/levels/stairs.gd") as GDScript
	var side: float = float(Stairs.get("SIDE"))
	var flights: int = int(Stairs.get("FLIGHTS"))
	# 路線上的點換回 s 要一樣（螺旋疊了好幾圈，靠高度分辨）
	for s_in: float in [0.0, 1.3, side * 1.5, side * 4.0 + 0.4, side * 6.2, side * flights - 0.5]:
		var p: Vector3 = Stairs.call("path_point", s_in) as Vector3
		assert_true(absf(float(Stairs.call("path_param", p)) - s_in) < 0.05, "s=%.2f 換回來" % s_in)
	# 地面一路往下、不會往上跳（沿路線取樣）
	var prev: float = 1.0
	var s_t: float = 0.0
	while s_t <= side * flights:
		var y: float = (Stairs.call("path_point", s_t) as Vector3).y
		assert_true(y <= prev + 0.0001, "s=%.1f 不往上" % s_t)
		prev = y
		s_t += 0.25
	var lap_drop: float = float(Stairs.get("DROP")) * 4.0
	assert_true(lap_drop >= 3.0, "上下兩圈之間留得出頭頂的空間")
	# 陷阱：旗標 → 攻略筆記「射箭陷阱」被推翻；標過我不確定的會記得
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.new_game()
	_play_slice(s)
	s.set_flag("slice.cellar_entered", true)
	load("res://scenes/levels/frostbridge.gd").call("dev_start_day", s, "stairs")
	GuideNotes.set_unsure(s.state, "stair_arrows", true)
	assert_eq(s.quests.stage_of("ch1_main"), "stairs")
	assert_eq(s.objective_key(), "Q_CH1_OBJ_STAIRS")
	s.set_flag("ch1.stair_trap_sprung", true)
	assert_eq(GuideNotes.status(s.state, "stair_arrows"), GuideNotes.WRONG, "射箭陷阱被推翻")
	var r := DialogueRunner.new(Game.dialogues, s.state)
	assert_true(r.start("ch1_stair_trap"))
	var lines: PackedStringArray = []
	for i: int in 10:
		lines.append(r.current_text())
		if not r.advance():
			break
	assert_true("DLG_CH1_TRAP_003_UNSURE" in lines, "標了我不確定 → 「果然」")
	assert_true("DLG_CH1_TRAP_004" in lines, "樓梯深處的笑聲")
	assert_true("DLG_CH1_TRAP_002" in lines, "丟石頭：水潑在剛剛要踩的地方")
	s.set_flag("ch1.stairs_bottom", true)
	assert_eq(s.quests.stage_of("ch1_main"), "daylight_gate", "走到底 → 不可互動的門")
	# 段落 6（D-153）：開門 → 攻略「不可互動的門」推翻；柯德 → 「全城是怪物」推翻；標過不確定的那條台詞不同
	GuideNotes.set_unsure(s.state, "sealed_door", true)
	s.set_flag("ch1.door_opened", true)
	assert_eq(GuideNotes.status(s.state, "sealed_door"), GuideNotes.WRONG)
	var kr := DialogueRunner.new(Game.dialogues, s.state)
	assert_true(kr.start("ch1_kord_door"))
	var klines: PackedStringArray = []
	for i: int in 12:
		klines.append(kr.current_text())
		if not kr.current().has("choices"):
			if not kr.advance():
				break
		else:
			assert_eq((kr.current()["choices"] as Array).size(), 3, "三個回答")
			kr.choose(1)
	assert_true("DLG_CH1_KORD_006_UNSURE" in klines, "標了我不確定 → 地圖上自己畫的問號")
	assert_true("DLG_CH1_KORD_R_HELP" in klines, "回答「來幫忙的」")
	assert_eq(s.state.get_flag("ch1.kord_first"), "help")
	s.set_flag("ch1.met_kord", true)
	assert_eq(GuideNotes.status(s.state, "city_of_monsters"), GuideNotes.WRONG)
	assert_eq(s.quests.stage_of("ch1_main"), "daylight_city", "柯德之後 → 白晝城（待續）")
	assert_eq(s.state.checkpoint, "ch1_stairs_bottom")
	assert_eq(Game.level_for_checkpoint("ch1_stairs_bottom"), "stairs")
	assert_true("water_splash" in Sfx.NAMES and "child_laugh" in Sfx.NAMES, "新音效登記")
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		for key: String in ["SPK_KORD", "Q_CH1_OBJ_DAYLIGHT", "DLG_CH1_KORD_006_UNSURE", "DLG_CH1_KORD_C_MAP", "DLG_CH1_KORD_010",
				"CH1_STAIR_THROW_HINT", "Q_CH1_OBJ_GATE", "DLG_CH1_STAIR_002_UNSURE", "DLG_CH1_TRAP_002_SOAKED",
				"DLG_CH1_TRAP_003", "DLG_CH1_TRAP_006_UNSURE", "DLG_CH1_TRAP_007"]:
			assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
	TranslationServer.set_locale("en")


## 段落 7（D-154）：沒有影子的城——任務階段、淨化爐推翻、壽命石碑的資料與數字變化、翻譯。
func test_daylight_stages_residents_and_furnace() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.new_game()
	_play_slice(s)
	s.set_flag("slice.cellar_entered", true)
	var Daylight: GDScript = load("res://scenes/levels/daylight.gd") as GDScript
	Daylight.call("dev_start_daylight", s)
	GuideNotes.set_unsure(s.state, "purifier", true)
	assert_eq(s.quests.stage_of("ch1_main"), "daylight_furnace", "跟著柯德進門 → 白晝城")
	assert_eq(s.state.checkpoint, "ch1_daylight", "白晝城的檢查點")
	assert_eq(Game.level_for_checkpoint("ch1_daylight"), "daylight")
	assert_eq(s.objective_key(), "Q_CH1_OBJ_FURNACE")
	assert_eq(GuideNotes.status(s.state, "purifier"), GuideNotes.UNSURE, "還沒看到爐子")
	s.set_flag("ch1.saw_empty_furnace", true)
	assert_eq(GuideNotes.status(s.state, "purifier"), GuideNotes.WRONG, "攻略「入口的淨化爐」被推翻")
	assert_eq(s.quests.stage_of("ch1_main"), "daylight_stele")
	var fr := DialogueRunner.new(Game.dialogues, s.state)
	assert_true(fr.start("ch1_daylight_furnace"))
	var flines: PackedStringArray = []
	for i: int in 10:
		flines.append(fr.current_text())
		if not fr.advance():
			break
	assert_true("DLG_CH1_FURNACE_003_UNSURE" in flines, "標了我不確定 → 「果然」")
	assert_true("DLG_CH1_FURNACE_006" in flines, "柯德：拿來晾衣服")
	# 壽命石碑：資料 4～6 個名字、數字是資料、用掉一天會變、諾恩不在上面
	var res: Residents = Residents.load_default()
	assert_eq(res.errors.size(), 0, "石碑資料沒有錯：%s" % ", ".join(res.errors))
	assert_eq(res.stele_ids().size(), 2, "兩塊石碑")
	for id: String in res.stele_ids():
		var n: int = res.residents_on(id).size()
		assert_true(n >= 4 and n <= 6, "%s 列 4～6 個名字" % id)
		assert_false("noen" in res.residents_on(id), "諾恩不在石碑上")
	assert_eq(res.days_left(s.state, "mara"), 19, "瑪菈還能活 19 天")
	assert_eq(res.spend(s, "mara", 1), 18, "用一天換半壺水 → 18")
	assert_eq(res.days_left(s.state, "mara"), 18)
	assert_eq(res.spend(s, "nika", 99), 0, "不會小於 0")
	var bad: Residents = Residents.new()
	bad.steles = {"x": PackedStringArray(["a", "b"])}
	bad.base_days = {"a": 3, "b": 0}
	assert_eq(bad.validate().size(), 2, "名字太少、天數 0 都擋下來")
	var sr := DialogueRunner.new(Game.dialogues, s.state)
	assert_true(sr.start("ch1_daylight_stele"))
	for i: int in 12:
		if not sr.advance():
			break
	assert_eq(s.state.get_flag("ch1.saw_stele_trade"), true)
	s.set_flag("ch1.saw_stele_trade", true)
	assert_eq(s.quests.stage_of("ch1_main"), "kord_home", "看完石碑 → 到柯德家吃飯")
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		for key: String in ["Q_CH1_OBJ_FURNACE", "Q_CH1_OBJ_FOLLOW_KORD", "Q_CH1_OBJ_KORD_HOME", "DLG_CH1_KORD_011",
				"DLG_CH1_DAY_004_UNSURE", "DLG_CH1_STELE_005", "CH1_STELE_TOUCH_HINT", "CH1_STELE_NO_NAME", "STELE_LINE"]:
			assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
		for id: String in res.stele_ids():
			for rid: String in res.residents_on(id):
				assert_ne(tr(Residents.name_key(rid)), Residents.name_key(rid), "%s 居民名字有翻譯：%s" % [loc, rid])
	TranslationServer.set_locale("zh_TW")
	s.state.set_flag("life.mara", 18)
	assert_eq(res.line(s.state, "mara"), "瑪菈　還能活 18 天", "石碑上的一行")
	TranslationServer.set_locale("en")
