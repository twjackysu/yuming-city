extends TestCase
## 標題畫面的入口（D-211、D-220）：「新遊戲／繼續」＝《這些詛咒對我太有用了》，沒有別的劇情入口
## （「舊版」選項第 76 輪照 Jacky 11/11 的指示拿掉了）。「繼續」只看這個劇情自己的存檔。

const BOOT: String = "res://scenes/boot/boot.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_title_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session() -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	return s


func _game() -> Node:
	return tree.root.get_node("Game")


## 開標題畫面；按鈕按下去只改狀態、不換場景
func _boot() -> Control:
	var boot: Control = (load(BOOT) as PackedScene).instantiate() as Control
	boot.set("load_levels", false)
	tree.root.add_child(boot)
	await tree.process_frame
	await tree.process_frame
	return boot


func _button(boot: Control, node_name: String) -> Button:
	return boot.get_node("%" + node_name) as Button


func test_new_game_starts_the_new_story() -> void:
	var s := _session()
	var boot: Control = await _boot()
	assert_eq((boot.get_node("%Subtitle") as Label).text, "RB_GAME_SUBTITLE", "副標題是新版的名字")
	assert_true(boot.get_node_or_null("%Classic") == null, "沒有「舊版」選項（D-220）")
	assert_true(boot.get_node_or_null("%ClassicMenu") == null, "也沒有舊版那一頁")
	assert_true(_button(boot, "NewGame").has_focus(), "焦點在「新遊戲」")
	assert_true(_button(boot, "Continue").disabled, "還沒玩過：繼續不能按")
	_button(boot, "NewGame").pressed.emit()
	assert_true(s.in_story(), "新遊戲＝新版")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "escape")
	assert_eq(s.state.checkpoint, "rb_start")
	assert_eq(str(_game().call("level_for_checkpoint", s.state.checkpoint)), "frostbridge")
	assert_false(s.state.quests.has("slice_main"), "不會開舊劇情的主線")
	boot.queue_free()
	await tree.process_frame


func test_continue_reads_only_the_new_story_save() -> void:
	var s := _session()
	# 資料夾裡只有以前舊劇情留下的存檔：標題的「繼續」不能按（不會把舊存檔當成這個劇情的進度）
	# （遊戲已經不會寫這種檔了，D-220：直接在舊資料夾造一份）
	var old_state := GameState.new()
	old_state.set_flag("slice.met_pear_seller", true)
	DirAccess.make_dir_recursive_absolute(_dir)
	assert_eq(SaveCodec.write_file(_dir.path_join("auto.json"), old_state), OK)
	var boot: Control = await _boot()
	assert_true(_button(boot, "Continue").disabled, "新版沒有存檔")
	boot.queue_free()
	await tree.process_frame
	# 新版玩到一半存了檔
	s.new_game()
	s.set_flag("rb.opening_done", true)
	assert_eq(s.save(GameSession.AUTO_SLOT), OK)
	# 重開遊戲（新的 session、同一個存檔資料夾）
	var s2 := _session()
	var boot2: Control = await _boot()
	assert_false(_button(boot2, "Continue").disabled, "新版有存檔了")
	_button(boot2, "Continue").pressed.emit()
	assert_true(s2.in_story(), "繼續＝新版的存檔")
	assert_true(bool(s2.state.get_flag("rb.opening_done", false)))
	assert_false(bool(s2.state.get_flag("slice.met_pear_seller", false)), "不是舊版那一份")
	boot2.queue_free()
	await tree.process_frame


## 標題的選單只有四個：新遊戲、繼續、設定、離開（D-220）
## 第 90 輪（D-238）多了「戰鬥場」：四個變五個，還是只有這幾個（沒有舊版、沒有別的劇情入口）
func test_title_menu_has_only_the_five_entries() -> void:
	_session()
	var boot: Control = await _boot()
	var names: Array[String] = []
	for c: Node in (boot.get_node("%Menu") as Control).get_children():
		if c is Button:
			names.append(str(c.name))
	assert_eq(names, ["NewGame", "Continue", "Arena", "Settings", "Quit"] as Array[String])
	boot.queue_free()
	await tree.process_frame


## 開發旗標（`--level=frostbridge [--rb-at=…]`）開的遊戲存在另一個資料夾：不會蓋掉玩家真正的進度（D-221）
func test_dev_flags_never_write_the_players_save() -> void:
	var s := _session()
	# 玩家真正的進度（測試裡是 _dir + "_reboot"）：玩到毒霧前
	s.new_game()
	s.set_flag("rb.opening_done", true)
	s.set_flag("rb.barrels_broken", true)
	assert_eq(s.state.checkpoint, "rb_before_mist")
	var real_path: String = s.story_save_dir().path_join("auto.json")
	var real_text: String = FileAccess.get_file_as_string(real_path)
	assert_true(real_text != "", "前提：玩家有一份自動存檔")
	# 用開發旗標跳到梨攤那一段
	var dev_dir: String = str(_game().get("DEV_SAVE_DIR")) + "_reboot"
	_game().call("_dev_story_start", "market")
	assert_true(s.in_story(), "開的是同一個劇情")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "market_lead", "推到梨攤那一段")
	assert_eq(s.story_save_dir(), dev_dir, "存檔改寫到開發用的資料夾")
	assert_true(FileAccess.file_exists(dev_dir.path_join("auto.json")), "開發用的資料夾有存檔")
	assert_eq(FileAccess.get_file_as_string(real_path), real_text, "玩家那一份一個字都沒變")
	assert_true(dev_dir != GameSession.STORY_SAVE_DIR, "不是正式的存檔資料夾")
	for f: String in DirAccess.get_files_at(dev_dir):
		DirAccess.remove_absolute(dev_dir.path_join(f))
	DirAccess.remove_absolute(dev_dir)
