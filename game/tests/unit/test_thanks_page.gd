extends TestCase
## 「感謝試玩」一頁（D-176）：文字都走翻譯 key、中英都有；「你的這一趟」的數字跟遊戲狀態一致；
## 剛出現時不能按、之後確認／取消都會關、只呼叫一次；回饋按鈕在 headless 只記次數。

const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]*$"

var _host: Node


func after_each() -> void:
	if _host != null and is_instance_valid(_host):
		_host.free()
	_host = null
	tree.paused = false
	TranslationServer.set_locale(str(tree.root.get_node("Settings").get("locale")))


func _show(state: GameState, calls: Array[int]) -> ThanksPage:
	_host = Node.new()
	tree.root.add_child(_host)
	return ThanksPage.show_on(_host, state, func() -> void: calls[0] += 1)


func test_texts_are_translated_keys() -> void:
	var calls: Array[int] = [0]
	var page: ThanksPage = _show(GameState.new(), calls)
	await tree.process_frame
	var re := RegEx.create_from_string(KEY_PATTERN)
	var keys: PackedStringArray = []
	for n: Node in page.find_children("*", "", true, false):
		var text: String = ""
		if n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		else:
			continue
		if text == "" or n.has_meta("glyph"):
			continue
		assert_true(re.search(text) != null, "%s 寫死了文字：%s" % [n.name, text])
		keys.append(text)
	assert_true(keys.size() >= 12, "標題、範圍、四列、預告、回饋、兩個按鈕都有字（%d）" % keys.size())
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		for key: String in keys:
			assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
	TranslationServer.set_locale("zh_TW")
	assert_eq(tr("THANKS_TITLE"), "感謝試玩")
	assert_true(tr("THANKS_TEASER").contains("地圖"), "後半預告是原作第七章的第一句")


## D-179：遊戲時間——四捨五入到分鐘，一小時以上換成「小時＋分鐘」；中英文各一套。
func test_time_played_text() -> void:
	TranslationServer.set_locale("zh_TW")
	assert_eq(ThanksPage.time_text(0.0), "0 分鐘")
	assert_eq(ThanksPage.time_text(29.0), "0 分鐘", "不到半分鐘")
	assert_eq(ThanksPage.time_text(31.0), "1 分鐘", "四捨五入")
	assert_eq(ThanksPage.time_text(42.0 * 60.0 + 10.0), "42 分鐘")
	assert_eq(ThanksPage.time_text(59.0 * 60.0 + 40.0), "1 小時 0 分鐘", "59 分 40 秒進位成一小時")
	assert_eq(ThanksPage.time_text(65.0 * 60.0), "1 小時 5 分鐘")
	assert_eq(ThanksPage.time_text(-5.0), "0 分鐘", "負的當 0")
	TranslationServer.set_locale("en")
	assert_eq(ThanksPage.time_text(42.0 * 60.0), "42 min")
	assert_eq(ThanksPage.time_text(125.0 * 60.0), "2 h 5 min")
	TranslationServer.set_locale("zh_TW")
	var st := GameState.new()
	st.playtime_sec = 27.0 * 60.0
	assert_eq(ThanksPage.run_summary(st)["THANKS_RUN_TIME"], "27 分鐘", "你的這一趟：遊戲時間")
	var calls: Array[int] = [0]
	var page: ThanksPage = _show(st, calls)
	assert_eq(page.value_text("THANKS_RUN_TIME"), "27 分鐘", "畫面上的遊戲時間")


func test_run_summary_matches_state() -> void:
	var st := GameState.new()
	assert_eq(ThanksPage.run_summary(st)["THANKS_RUN_RESCUED"], "0 / 4", "什麼都沒做：0／4")
	assert_eq(ThanksPage.run_summary(st)["THANKS_RUN_DEAD"], "31", "原作的死亡人數")
	st.set_flag("slice.rescued_count", 4)
	st.pay_memory("arch_father")
	st.guide["stair_safe"] = {"unsure": false, "result": GuideNotes.WRONG}
	st.guide["kord_hostile"] = {"unsure": true, "result": GuideNotes.WRONG}
	st.guide["isa_tyrant"] = {"unsure": false, "result": GuideNotes.CONFIRMED}
	st.guide["blank_one"] = {"unsure": false, "result": "", "blank": true}
	var d: Dictionary = ThanksPage.run_summary(st)
	assert_eq(d["THANKS_RUN_RESCUED"], "4 / 4", "救滿四個")
	assert_eq(d["THANKS_RUN_DEAD"], str(DeadListBoard.dead_count(st)), "死者跟死者名單同一套條件")
	assert_eq(d["THANKS_RUN_DEAD"], "29", "救滿四個、車隊沒被打：29")
	assert_eq(d["THANKS_RUN_MEMORIES"], "1", "忘掉一段記憶")
	assert_eq(d["THANKS_RUN_GUIDE"], "2", "只算被推翻的（確認過的、空白的不算）")
	st.set_flag("slice.rescued_count", 9)
	assert_eq(ThanksPage.run_summary(st)["THANKS_RUN_RESCUED"], "4 / 4", "不會超過四個")
	var calls: Array[int] = [0]
	var page: ThanksPage = _show(st, calls)
	assert_eq(page.value_text("THANKS_RUN_GUIDE"), "2", "畫面上的數字")
	assert_eq(page.value_text("THANKS_RUN_RESCUED"), "4 / 4")


func test_input_delay_then_close_once() -> void:
	var calls: Array[int] = [0]
	var page: ThanksPage = _show(GameState.new(), calls)
	await tree.process_frame
	assert_true(page.back_button.disabled, "剛出現：按鈕不能按")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	page._unhandled_input(cancel)
	assert_eq(calls[0], 0, "剛出現：取消鍵也不會關")
	page.elapsed = ThanksPage.INPUT_DELAY
	await tree.process_frame
	assert_false(page.back_button.disabled, "過一下子就能按")
	assert_true(page.back_button.has_focus(), "焦點預設在「回到標題」")
	assert_eq(page.feedback_button.get_node(page.feedback_button.focus_neighbor_right), page.back_button, "左右切換兩個按鈕")
	page.feedback_button.pressed.emit()
	assert_eq(page.feedback_opened, 1, "回饋頁面（headless 不開瀏覽器）")
	assert_eq(calls[0], 0, "按回饋不會關掉這頁")
	# 暫停選單開著時（樹暫停）取消鍵是暫停選單的
	tree.paused = true
	page._unhandled_input(cancel)
	assert_eq(calls[0], 0, "暫停時不處理取消鍵")
	tree.paused = false
	page._unhandled_input(cancel)
	assert_eq(calls[0], 1, "取消鍵（Esc／B）回標題")
	page.back_button.pressed.emit()
	page.close()
	assert_eq(calls[0], 1, "只呼叫一次")


func test_hold_still_for_screenshots() -> void:
	var calls: Array[int] = [0]
	var page: ThanksPage = _show(GameState.new(), calls)
	page.hold_still()
	assert_eq((page.get_node("Root") as Control).modulate.a, 1.0, "完全淡入")
	assert_false(page.back_button.disabled, "按鈕可以按")
	assert_eq(calls[0], 0, "不會自己關")
