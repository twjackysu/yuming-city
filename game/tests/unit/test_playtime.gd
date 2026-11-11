extends TestCase
## 遊戲時間（D-179）：GameState.playtime_sec 在關卡裡、沒暫停時累計；用真實時間（打擊停頓的慢動作不少算）；
## 換場景卡住的那一幀不算；倒下重來不退回檢查點；存讀檔保留（存檔本來就有這一欄）。

var _game: Node
var _original: GameSession
var _dir: String = ""


func before_each() -> void:
	_game = tree.root.get_node("Game")
	_original = _game.get("session") as GameSession
	_dir = "user://test_playtime_%d" % Time.get_ticks_usec()


func after_each() -> void:
	_game.set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func test_step_uses_real_time_and_caps() -> void:
	var step: float = float(_game.call("playtime_step", 0.016, 1.0))
	assert_true(absf(step - 0.016) < 0.0001, "一般的一幀：照算（%.4f）" % step)
	step = float(_game.call("playtime_step", 0.0008, 0.05))
	assert_true(absf(step - 0.016) < 0.0001, "打擊停頓（時間放慢到 0.05）：換回真實時間（%.4f）" % step)
	step = float(_game.call("playtime_step", 3.0, 1.0))
	assert_eq(step, float(_game.get("PLAYTIME_MAX_STEP")), "換場景卡住 3 秒的那一幀：只算上限")
	assert_eq(float(_game.call("playtime_step", -1.0, 1.0)), 0.0, "不會倒退")


func test_accumulates_only_in_a_level() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.new_game()
	_game.set("session", s)
	# 測試時的 current_scene 是測試執行器（不是關卡）：不算
	assert_false(tree.current_scene is StoryLevel)
	for i: int in 5:
		await tree.process_frame
	assert_eq(s.state.playtime_sec, 0.0, "不在關卡裡（標題畫面）不算")


func test_retry_keeps_playtime() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.new_game()
	_game.set("session", s)
	s.state.playtime_sec = 100.0
	assert_eq(s.save(GameSession.AUTO_SLOT), OK, "自動存檔（檢查點）")
	s.state.playtime_sec = 160.0
	_game.call("retry", false)
	assert_eq(s.state.playtime_sec, 160.0, "倒下重來：遊戲時間不退回檢查點的 100 秒")
	# 讀檔（標題的「繼續」）：存檔裡的時間
	assert_eq(s.load_slot(GameSession.AUTO_SLOT), SaveCodec.Status.OK)
	assert_eq(s.state.playtime_sec, 100.0, "讀檔：存檔當時的時間")
