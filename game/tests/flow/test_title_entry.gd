extends TestCase
## 標題畫面的入口（D-211）：「新遊戲／繼續」＝新版《這些詛咒對我太有用了》；舊版的新遊戲／繼續收在「舊版」選項裡。
## 兩邊的存檔分開：新版的「繼續」只看新版的存檔，舊存檔照舊讀得到、不會被新版寫到。

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
	assert_eq(_button(boot, "Classic").text, "MENU_CLASSIC", "「舊版」選項（翻譯 key）")
	assert_true(_button(boot, "NewGame").has_focus(), "焦點在「新遊戲」")
	assert_true(_button(boot, "Continue").disabled, "還沒玩過：繼續不能按")
	assert_false(bool(boot.call("is_classic_open")), "舊版那一頁先收著")
	_button(boot, "NewGame").pressed.emit()
	assert_true(s.is_reboot(), "新遊戲＝新版")
	assert_eq(s.quests.stage_of(GameSession.REBOOT_MAIN_QUEST), "escape")
	assert_eq(s.state.checkpoint, "rb_start")
	assert_eq(str(_game().call("level_for_checkpoint", s.state.checkpoint)), "frostbridge")
	assert_false(s.state.quests.has(GameSession.MAIN_QUEST), "不會順便開舊版的主線")
	boot.queue_free()
	await tree.process_frame


func test_continue_reads_only_the_new_story_save() -> void:
	var s := _session()
	# 只有舊版的存檔：標題的「繼續」不能按，「舊版」裡的可以
	s.new_game()
	s.set_flag("slice.met_pear_seller", true)
	assert_eq(s.save(GameSession.AUTO_SLOT), OK)
	var boot: Control = await _boot()
	assert_true(_button(boot, "Continue").disabled, "新版沒有存檔")
	assert_false(_button(boot, "ClassicContinue").disabled, "舊存檔還在")
	boot.queue_free()
	await tree.process_frame
	# 新版玩到一半存了檔
	s.new_reboot_game()
	s.set_flag("rb.opening_done", true)
	assert_eq(s.save(GameSession.AUTO_SLOT), OK)
	# 重開遊戲（新的 session、同一個存檔資料夾）
	var s2 := _session()
	var boot2: Control = await _boot()
	assert_false(_button(boot2, "Continue").disabled, "新版有存檔了")
	_button(boot2, "Continue").pressed.emit()
	assert_true(s2.is_reboot(), "繼續＝新版的存檔")
	assert_true(bool(s2.state.get_flag("rb.opening_done", false)))
	assert_false(bool(s2.state.get_flag("slice.met_pear_seller", false)), "不是舊版那一份")
	# 舊存檔沒有被新版寫到：從「舊版」選項照樣讀得回來
	_button(boot2, "Classic").pressed.emit()
	assert_false(_button(boot2, "ClassicContinue").disabled)
	_button(boot2, "ClassicContinue").pressed.emit()
	assert_false(s2.is_reboot(), "舊版的繼續＝舊存檔")
	assert_true(bool(s2.state.get_flag("slice.met_pear_seller", false)), "舊存檔的內容還在")
	assert_true(s2.state.quests.has(GameSession.MAIN_QUEST))
	boot2.queue_free()
	await tree.process_frame


func test_classic_page_opens_starts_old_story_and_goes_back() -> void:
	var s := _session()
	var boot: Control = await _boot()
	var menu: Control = boot.get_node("%Menu") as Control
	var classic_menu: Control = boot.get_node("%ClassicMenu") as Control
	_button(boot, "Classic").pressed.emit()
	await tree.process_frame
	assert_true(bool(boot.call("is_classic_open")))
	assert_true(classic_menu.visible and not menu.visible, "換成舊版那一頁")
	assert_eq((boot.get_node("%Subtitle") as Label).text, "GAME_SUBTITLE", "副標題換回舊劇情的名字")
	assert_eq((boot.get_node("%ClassicNote") as Label).text, "MENU_CLASSIC_NOTE")
	assert_true(_button(boot, "ClassicNew").has_focus(), "焦點在舊版的新遊戲")
	assert_true(_button(boot, "ClassicContinue").disabled, "沒有舊存檔")
	_button(boot, "ClassicNew").pressed.emit()
	assert_false(s.is_reboot(), "舊版的新遊戲")
	assert_true(s.quests.is_active(GameSession.MAIN_QUEST), "舊版的主線照舊開始")
	assert_false(s.use_reboot_saves, "存檔寫回舊版的資料夾")
	_button(boot, "ClassicBack").pressed.emit()
	await tree.process_frame
	assert_true(menu.visible and not classic_menu.visible, "返回")
	assert_eq((boot.get_node("%Subtitle") as Label).text, "RB_GAME_SUBTITLE")
	assert_true(_button(boot, "Classic").has_focus(), "焦點回到「舊版」")
	boot.queue_free()
	await tree.process_frame
