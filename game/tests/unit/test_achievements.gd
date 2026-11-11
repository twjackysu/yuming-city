extends TestCase
## 成就（D-147，docs/steam/achievements.md）：資料、只在「這一局做到」時解鎖、讀舊存檔不解鎖也不取消、
## 存在帳號層級的檔案（有版本號）、解鎖小卡在對話與暫停時排隊、灰巡者弱點跪地的計數。

const HIDDEN: PackedStringArray = ["ACH_THE_TRUTH", "ACH_NINE_SECONDS", "ACH_BURNING_BLADE"]

var _dir: String = ""


func before_each() -> void:
	_dir = "user://test_achievements_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _mem() -> AchievementTracker:
	return AchievementTracker.new(AchievementTracker.load_defs(), "")


func test_data_is_valid_and_translated() -> void:
	var t: AchievementTracker = _mem()
	assert_eq(t.errors.size(), 0, "資料沒有錯：%s" % ", ".join(t.errors))
	assert_eq(t.ids().size(), 8, "切片 8 個成就")
	var seen: Dictionary = {}
	for id: String in t.ids():
		assert_false(seen.has(id), "id 不重複：%s" % id)
		seen[id] = true
		assert_true(id.begins_with("ACH_"), "id 以 ACH_ 開頭（Steamworks 的 API 名稱）：%s" % id)
		assert_eq(t.is_hidden(id), HIDDEN.has(id), "%s 隱藏與否照設計" % id)
	for loc: String in ["en", "zh_TW"]:
		TranslationServer.set_locale(loc)
		assert_ne(tr("ACH_UNLOCKED"), "ACH_UNLOCKED", "%s 有「成就解鎖」" % loc)
		for id: String in t.ids():
			for key: String in [AchievementTracker.name_key(id), AchievementTracker.desc_key(id)]:
				assert_ne(tr(key), key, "%s 有翻譯：%s" % [loc, key])
	TranslationServer.set_locale("en")


func test_unlocks_when_condition_becomes_true() -> void:
	var t: AchievementTracker = _mem()
	var got: Array[String] = []
	t.unlocked.connect(func(id: String) -> void: got.append(id))
	var s := GameState.new()
	t.baseline(s)
	assert_eq(t.evaluate(s).size(), 0, "新遊戲什麼都沒解鎖")
	s.set_flag("slice.bell_rings", 8)
	assert_eq(t.evaluate(s).size(), 0, "八下還不算")
	s.set_flag("slice.bell_rings", 9)
	assert_eq(Array(t.evaluate(s)), ["ACH_NINTH_BELL"], "第九下解鎖")
	assert_eq(t.evaluate(s).size(), 0, "不會重複解鎖")
	assert_eq(got, ["ACH_NINTH_BELL"], "訊號只發一次")
	s.set_flag("slice.told_truth_about_bell", false)
	assert_eq(t.evaluate(s).size(), 0, "說謊不算「實話」")
	s.set_flag("slice.frame_throw_outcome", "kindling")
	assert_eq(Array(t.evaluate(s)), ["ACH_BURNING_BLADE"], "燃燒劍路線")
	assert_false(t.is_unlocked("ACH_NINE_SECONDS"), "另一條路線的沒有")
	s.set_flag("slice.convoy_through", true)
	s.set_flag("slice.convoy_injured", 1)
	assert_eq(t.evaluate(s).size(), 0, "有傷者再受傷：不算「一個都沒少」")


func test_state_already_true_on_load_does_not_unlock() -> void:
	var t: AchievementTracker = _mem()
	var s := GameState.new()
	s.set_flag("slice.bell_rings", 9)
	s.set_flag("slice.complete", true)
	t.baseline(s)
	assert_eq(t.evaluate(s).size(), 0, "讀進來時已經成立的不算")
	# 這一局真的再做一次（例如從鐘樓檢查點重來、從第一下重新數）
	s.set_flag("slice.bell_rings", 0)
	t.evaluate(s)
	s.set_flag("slice.bell_rings", 9)
	assert_eq(Array(t.evaluate(s)), ["ACH_NINTH_BELL"], "這一局做到就解鎖")
	assert_false(t.is_unlocked("ACH_CELLAR_DOOR"), "走完那一夜還是不算（讀檔帶來的）")


func test_store_persists_versioned_and_never_revoked() -> void:
	var path: String = _dir.path_join("achievements.json")
	var t := AchievementTracker.new(AchievementTracker.load_defs(), path)
	assert_true(t.unlock("ACH_NO_ONE_LEFT"), "解鎖")
	assert_false(t.unlock("ACH_NO_ONE_LEFT"), "已解鎖的不會再解鎖")
	assert_false(t.unlock("ACH_NO_SUCH"), "沒有的成就不能解鎖")
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	assert_eq(int(root.get("version", 0)), AchievementTracker.STORE_VERSION, "檔案有版本號")
	var t2 := AchievementTracker.new(AchievementTracker.load_defs(), path)
	assert_true(t2.is_unlocked("ACH_NO_ONE_LEFT"), "重開遊戲還在")
	t2.baseline(GameState.new())
	t2.evaluate(GameState.new())
	assert_true(t2.is_unlocked("ACH_NO_ONE_LEFT"), "新遊戲／讀別的存檔不會取消")
	assert_eq(Array(t2.unlocked_ids()), ["ACH_NO_ONE_LEFT"])
	# 較新版本的遊戲加的成就：認不得也不能弄丟
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 9, "unlocked": {"ACH_NO_ONE_LEFT": "x", "ACH_FUTURE": "y"}}))
	f.close()
	var t3 := AchievementTracker.new(AchievementTracker.load_defs(), path)
	assert_eq(Array(t3.unlocked_ids()), ["ACH_NO_ONE_LEFT"], "清單只列認得的")
	t3.unlock("ACH_THE_TRUTH")
	var saved: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary)["unlocked"] as Dictionary
	assert_true(saved.has("ACH_FUTURE"), "存回去時保留不認得的")
	assert_true(saved.has("ACH_THE_TRUTH"))


func test_corrupt_store_is_treated_as_empty() -> void:
	var path: String = _dir.path_join("achievements.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var t := AchievementTracker.new(AchievementTracker.load_defs(), path)
	assert_eq(t.unlocked_ids().size(), 0, "壞掉的檔案當作沒有解鎖")
	assert_true(t.unlock("ACH_THE_TRUTH"), "照樣可以解鎖並覆寫")
	assert_true(AchievementTracker.new(AchievementTracker.load_defs(), path).is_unlocked("ACH_THE_TRUTH"))


func test_memory_tracker_writes_nothing() -> void:
	var t: AchievementTracker = _mem()
	assert_true(t.unlock("ACH_THE_TRUTH"))
	assert_eq(t.save_store(), OK)
	assert_eq(DirAccess.get_files_at(_dir).size(), 0, "store_path 空字串不寫檔")


## 成就的條件還是舊劇情的旗標；舊劇情已經沒有入口（D-220），這裡直接開那條任務。
## （成就系統跟舊任務資料下一步一起刪，NEXT「000」第 2 步剩下的。）
func _start_old_quest(s: GameSession) -> void:
	s.quests.start("slice_main")
	s.advance()


func test_session_unlocks_and_old_save_does_not() -> void:
	var path: String = _dir.path_join("achievements.json")
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.attach_achievements(AchievementTracker.new(AchievementTracker.load_defs(), path))
	_start_old_quest(s)
	s.set_flag("slice.met_pear_seller", true)
	s.set_flag("slice.bell_rings", 9)
	assert_true(s.achievements.is_unlocked("ACH_NINTH_BELL"), "set_flag 推進時就解鎖")
	assert_eq(s.save("slot1"), OK)
	# 別台電腦（沒有任何成就）讀這個存檔：存檔裡已經敲完九下，不會因此解鎖
	var other := GameSession.new(QuestDB.load_default(), _dir)
	other.attach_achievements(AchievementTracker.new(AchievementTracker.load_defs(), ""))
	assert_eq(other.load_slot("slot1"), SaveCodec.Status.OK)
	other.advance()
	assert_false(other.achievements.is_unlocked("ACH_NINTH_BELL"), "讀舊存檔不解鎖")
	# 接著真的救出三個人：照常解鎖
	other.add_flag("slice.rescued_count", 3)
	assert_true(other.achievements.is_unlocked("ACH_NO_ONE_LEFT"), "讀檔之後做到的照常解鎖")
	# 原本這台：讀回更早的狀態也不會取消
	s.new_reboot_game()
	assert_true(s.achievements.is_unlocked("ACH_NINTH_BELL"), "新遊戲不取消")
	var no_tracker := GameSession.new(QuestDB.load_default(), _dir)
	no_tracker.set_flag("slice.bell_rings", 9)
	assert_eq(no_tracker.check_achievements().size(), 0, "沒接成就的 session 什麼都不做")


func test_ashwalker_weak_kneel_counts() -> void:
	var game: Node = tree.root.get_node("Game")
	var original: GameSession = game.get("session") as GameSession
	var s := GameSession.new(QuestDB.load_default(), _dir)
	s.attach_achievements(_mem())
	_start_old_quest(s)
	game.set("session", s)
	var walker := Ashwalker.new()
	walker.position = Vector3(0.0, 0.0, -40.0)
	tree.root.add_child(walker)
	walker.set_physics_process(false)
	walker.health.apply_damage(1.0, {"stagger": 1.0})
	walker.health.apply_damage(1.0, {"stagger": 999.0})
	assert_eq(int(s.state.get_flag("stats.ashwalker_weak_kneels", 0)), 0, "不是打弱點跪下的不算")
	assert_false(s.achievements.is_unlocked("ACH_SEEN_THROUGH"))
	walker.brain.tick(walker.brain.stagger_kneel_sec + 0.1, 99.0)
	walker.health.apply_damage(1.0, {"stagger": 999.0, "weak": "left_knee"})
	assert_eq(int(s.state.get_flag("stats.ashwalker_weak_kneels", 0)), 1, "打中弱點而跪下 +1")
	assert_true(s.achievements.is_unlocked("ACH_SEEN_THROUGH"), "解鎖「看穿」")
	assert_eq(s.quests.stage_of("slice_main"), "explore_town", "統計不推進任務")
	game.set("session", original)
	walker.queue_free()
	await tree.process_frame


func test_toast_queues_while_blocked_and_fades() -> void:
	TranslationServer.set_locale("zh_TW")
	var toast := AchievementToast.new()
	tree.root.add_child(toast)
	toast.set_process(false)
	toast.enqueue("ACH_NINTH_BELL")
	toast.enqueue("ACH_NINTH_BELL")
	toast.enqueue("ACH_THE_TRUTH")
	assert_eq(toast.queue.size(), 2, "同一個不重複排隊")
	toast.tick(0.1, true)
	assert_false(toast.is_showing(), "對話／過場／暫停中不顯示")
	assert_eq(toast.current, "", "還沒開始")
	toast.tick(0.016, false)
	assert_true(toast.is_showing(), "結束後才出來")
	assert_eq(Array(toast.shown_text()), ["成就解鎖", "第九聲鐘"], "標題＋名稱")
	var panel: Control = toast.get_node("Panel") as Control
	var vp: Rect2 = panel.get_viewport_rect()
	toast.tick(AchievementToast.SLIDE_SEC + 0.5, false)
	assert_true(panel.position.x + panel.size.x <= vp.size.x - AchievementToast.MARGIN.x + 0.5, "在右上角、不超出畫面")
	assert_true(panel.position.y < vp.size.y * 0.2, "在上方")
	assert_true(panel.modulate.a > 0.99, "停著的時候不透明")
	toast.tick(0.1, true)
	assert_false(toast.is_showing(), "暫停時藏起來")
	toast.tick(0.0, false)
	assert_true(toast.is_showing(), "恢復後繼續")
	toast.tick(AchievementToast.HOLD_SEC - 0.4 + AchievementToast.FADE_SEC * 0.5, false)
	assert_true(panel.modulate.a < 0.6 and panel.modulate.a > 0.4, "淡出中")
	toast.tick(AchievementToast.FADE_SEC, false)
	assert_eq(toast.current, "", "第一張結束")
	toast.tick(0.016, false)
	assert_eq(Array(toast.shown_text()), ["成就解鎖", "實話"], "下一張")
	TranslationServer.set_locale("en")
	toast.queue_free()
	await tree.process_frame


func test_steam_bridge_is_noop_without_steam() -> void:
	assert_false(SteamBridge.available(), "雲端與 CI 沒有 GodotSteam")
	assert_false(SteamBridge.set_achievement("ACH_NINTH_BELL"))
	assert_eq(SteamBridge.sync(PackedStringArray(["ACH_NINTH_BELL"])), 0)
	assert_false(SteamBridge.shows_own_toast(), "沒有 Steam 時用遊戲內的小卡")
