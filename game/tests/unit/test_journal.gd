extends TestCase
## 日記：記憶條目、付出後被剪掉、存讀檔、九息預覽標亮、日記畫面。

const ARCH: String = "arch_father_last_talk"

var _original: GameSession
var _session: GameSession


func before_each() -> void:
	var game: Node = tree.root.get_node("Game")
	_original = game.get("session") as GameSession
	_session = GameSession.new(QuestDB.load_default(), "user://test_journal_%d" % Time.get_ticks_usec())
	_session.state = GameState.new()
	game.set("session", _session)
	(game.get("journal") as Journal).highlighted = ""


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	tree.paused = false


func test_default_data_is_valid() -> void:
	var j := Journal.load_default()
	assert_eq(j.validate().size(), 0, "資料沒有錯誤：%s" % [j.validate()])
	assert_true(j.has_entry(ARCH), "第一條是石拱下的記憶")
	var e: Dictionary = j.entry(ARCH)
	for k: String in ["title", "context", "body", "residue"]:
		var key: String = str(e.get(k, ""))
		assert_ne(TranslationServer.translate(key), key, "%s 有翻譯（%s）" % [k, key])


func test_cut_after_paying() -> void:
	var j := Journal.load_default()
	var st := GameState.new()
	var before: Dictionary = j.view(ARCH, st)
	assert_false(before["cut"])
	assert_eq(before["body"], "JM_ARCH_FATHER_BODY")
	assert_eq(before["residue"], "", "還沒付出：沒有殘留")
	assert_true(st.pay_memory(ARCH))
	var after: Dictionary = j.view(ARCH, st)
	assert_true(after["cut"], "付出後被剪掉")
	assert_eq(after["body"], "", "內文剪掉")
	assert_eq(after["title"], before["title"], "標題保留")
	assert_eq(after["context"], before["context"], "前後文保留")
	assert_eq(after["residue"], "JM_ARCH_FATHER_RESIDUE", "留下熱薯的味道")
	# 存讀檔：只靠 memories_paid
	var loaded: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_true(j.view(ARCH, loaded)["cut"], "讀檔後還是被剪掉")


func test_unlock_and_validate() -> void:
	var j := Journal.new()
	j.entries.append({"id": "a", "title": "T", "body": "B"})
	j.entries.append({"id": "b", "title": "T", "body": "B", "unlocked_when": {"flag": "seen_b"}})
	var st := GameState.new()
	assert_eq(Array(j.visible_ids(st)), ["a"], "條件不成立時看不到")
	st.set_flag("seen_b", true)
	assert_eq(Array(j.visible_ids(st)), ["a", "b"])
	j.entries.append({"id": "a", "body": "B"})
	var errors: PackedStringArray = j.validate()
	assert_true(errors.size() >= 2, "重複 id 與缺標題都會報：%s" % [errors])


func test_arch_preview_highlights_memory() -> void:
	var journal: Journal = tree.root.get_node("Game").get("journal") as Journal
	var site := NineBreathSite.new()
	tree.root.add_child(site)
	await tree.process_frame
	site.set_physics_process(false)
	site.update_hold(0.3, true)
	assert_eq(journal.highlighted, ARCH, "按住預覽 → 日記標亮那段記憶")
	assert_true(journal.view(ARCH, _session.state)["highlighted"])
	site.update_hold(0.1, false)
	assert_eq(journal.highlighted, "", "放開 → 取消標亮")
	site.update_hold(0.5, true)
	site.update_hold(0.6, true)
	assert_true(site.is_solid(), "按滿發動")
	assert_eq(journal.highlighted, "", "發動後不再標亮")
	assert_true(journal.view(ARCH, _session.state)["cut"], "發動 → 記憶被剪掉")
	site.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_journal_view_open_close_and_cut_gap() -> void:
	var view := JournalView.new()
	tree.root.add_child(view)
	await tree.process_frame
	view.open()
	assert_true(view.is_open())
	assert_true(tree.paused, "打開日記會暫停")
	assert_eq(view.shown_entry_count(), 0, "還沒看過南街石拱：日記是空的")
	assert_true((view.find_child("Empty", true, false) as Label).visible, "空的時候有提示")
	view.close()
	_session.state.set_flag("slice.saw_south_arch", true)
	view.open()
	assert_eq(view.shown_entry_count(), 1, "看過石拱 → 那段記憶")
	assert_false((view.find_child("Empty", true, false) as Label).visible)
	assert_eq((view.find_child("Objective", true, false) as Label).text, _session.objective_key(), "日記最上面是目前目標")
	assert_true(view.find_child("CutGap", true, false) == null, "還沒付出：沒有剪痕")
	view.close()
	assert_false(tree.paused, "闔上恢復")
	_session.state.pay_memory(ARCH)
	view.open()
	await tree.process_frame
	assert_not_null(view.find_child("CutGap", true, false), "付出後：內文變成剪掉的空白")
	view.close()
	# 九息預覽中：不暫停，只在一角顯示那一張卡
	var journal: Journal = tree.root.get_node("Game").get("journal") as Journal
	journal.highlighted = ARCH
	await tree.process_frame
	assert_true(view.is_peeking(), "預覽中顯示代價卡")
	assert_false(tree.paused, "預覽不暫停")
	journal.highlighted = ""
	await tree.process_frame
	assert_false(view.is_peeking())
	view.queue_free()
	await tree.process_frame


## 日記是暖色舊紙（D-073）：紙是程式畫的紋理、卡片在紙上不畫深色底（上方細線）、字是深色墨水；
## 右側的預覽卡維持深色底亮色字（疊在遊戲畫面上要讀得到）。
func test_journal_paper_look() -> void:
	var tex: ImageTexture = JournalView.paper_texture()
	assert_eq(tex.get_width(), 256)
	assert_true(JournalView.paper_texture() == tex, "紙紋理只畫一次")
	var c: Color = tex.get_image().get_pixel(128, 128)
	assert_true(c.r > 0.7 and c.r > c.b + 0.1, "暖色的紙（%s）" % c)
	var view := JournalView.new()
	tree.root.add_child(view)
	await tree.process_frame
	var paper: PanelContainer = view.find_child("Paper", true, false) as PanelContainer
	assert_true(paper.get_theme_stylebox("panel") is StyleBoxTexture, "紙用紋理")
	_session.state.set_flag("slice.saw_south_arch", true)
	view.open()
	var card: PanelContainer = view.find_child("Card_" + ARCH, true, false) as PanelContainer
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(sb.bg_color.a < 0.01, "紙上的卡片沒有深色底")
	assert_eq(sb.border_width_top, 1, "上方一條細線分隔")
	var title: Label = card.get_child(0).get_child(0) as Label
	assert_true(title.get_theme_color("font_color").get_luminance() < 0.4, "紙上的標題是深色墨水")
	view.close()
	var journal: Journal = tree.root.get_node("Game").get("journal") as Journal
	journal.highlighted = ARCH
	await tree.process_frame
	var peek_card: PanelContainer = view.find_child("Peek", true, false).find_child("Card_" + ARCH, true, false) as PanelContainer
	assert_true((peek_card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.9, "預覽卡維持深色底")
	journal.highlighted = ""
	await tree.process_frame
	view.queue_free()
	await tree.process_frame
