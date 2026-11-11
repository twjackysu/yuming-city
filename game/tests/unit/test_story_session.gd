extends TestCase
## 新版（劇情重寫）前十分鐘的任務與存檔流程（D-202，docs/design/09-reboot-first-ten-minutes.md）。
## 只到任務／存檔層面；場景接上後主線流程測試另外走一遍。

var _dir: String = ""


func before_each() -> void:
	_dir = "user://test_story_%d" % Time.get_ticks_usec()


func after_each() -> void:
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session() -> GameSession:
	return GameSession.new(QuestDB.load_default(), _dir)


func test_rb_main_loads_with_markers_and_dialogues_exist() -> void:
	var db := QuestDB.load_default()
	assert_true(db.has_quest("rb_main"), "rb_main 載入成功：%s" % ", ".join(db.errors))
	var q: Dictionary = db.quests["rb_main"] as Dictionary
	var ids: Array[String] = []
	for st: Variant in (q["stages"] as Array):
		ids.append(str((st as Dictionary)["id"]))
		assert_true((st as Dictionary).has("marker"), "每個階段都有 marker（D-040）")
		assert_true((st as Dictionary).has("checkpoint"), "每個階段都有檢查點")
	assert_eq(ids, ["escape", "poison_discovery", "meet_sheila", "guardian_fight", "portable_poison", "market_lead"])
	var dlg := DialogueDB.load_default()
	for did: String in ["rb_opening", "rb_mist_test", "rb_mist_confirmed", "rb_sheila_meet", "rb_guardian_down", "rb_potion_found", "rb_potion_tried", "rb_potion_kept", "rb_ada_wages"]:
		assert_true(dlg.has_dialogue(did), "對話 %s" % did)


func test_new_game_uses_its_own_folder() -> void:
	var s := _session()
	s.new_game()
	assert_eq(s.state.mode, "reboot")
	assert_eq(s.main_quest(), "rb_main")
	assert_eq(s.quests.stage_of("rb_main"), "escape")
	assert_eq(s.objective_key(), "Q_RB_OBJ_ESCAPE")
	assert_false(s.quests.is_active("slice_main"), "新版不開舊的切片主線")
	assert_true(s.has_save(), "進第一個檢查點就自動存檔")
	assert_true(FileAccess.file_exists((_dir + "_reboot").path_join("auto.json")), "寫在新版資料夾")
	assert_false(FileAccess.file_exists(_dir.path_join("auto.json")), "舊版資料夾沒被寫到")


func test_new_game_does_not_overwrite_classic_save() -> void:
	var s := _session()
	# 以前舊劇情留在舊資料夾的存檔（遊戲已經不會寫這種檔了，D-220：直接造一份）
	var old_state := GameState.new()
	old_state.set_flag("slice.met_pear_seller", true)
	DirAccess.make_dir_recursive_absolute(_dir)
	assert_eq(SaveCodec.write_file(_dir.path_join("auto.json"), old_state), OK)
	var classic_text: String = FileAccess.get_file_as_string(_dir.path_join("auto.json"))
	s.new_game()
	s.set_flag("rb.barrels_broken", true)
	assert_eq(FileAccess.get_file_as_string(_dir.path_join("auto.json")), classic_text, "舊版存檔一個字都沒變")
	var old := _session()
	assert_eq(old.load_slot(GameSession.AUTO_SLOT), SaveCodec.Status.OK, "舊資料夾那一份還讀得出來（沒被動過）")
	assert_eq(old.state.mode, "classic")
	assert_true(bool(old.state.get_flag("slice.met_pear_seller", false)))
	var again := _session()
	assert_eq(again.load_story_slot(), SaveCodec.Status.OK)
	assert_eq(again.quests.stage_of("rb_main"), "poison_discovery")


func test_first_ten_minutes_stage_order_and_objective_hint() -> void:
	var s := _session()
	s.new_game()
	s.set_flag("rb.barrels_broken", true)
	assert_eq(s.quests.stage_of("rb_main"), "poison_discovery")
	assert_eq(s.state.checkpoint, "rb_before_mist", "第一次進霧前有檢查點")
	s.set_flag("rb.reversal_awakened", true)
	assert_eq(s.objective_key(), "Q_RB_OBJ_MIST_TEST", "覺醒後、還沒再踏回去：目標換成確認")
	assert_eq(s.quests.marker_spec("rb_main"), "node:RbMistEdge")
	s.set_flag("rb.reached_south", true)
	assert_eq(s.quests.stage_of("rb_main"), "poison_discovery", "沒有自己再驗證一次不往下")
	s.set_flag("rb.mist_reentered", true)
	assert_eq(s.quests.stage_of("rb_main"), "meet_sheila")
	s.set_flag("rb.sheila_met", true)
	assert_eq(s.quests.stage_of("rb_main"), "guardian_fight")
	s.set_flag("rb.guardian_down", true)
	assert_eq(s.quests.marker_spec("rb_main"), "node:Sheila", "打倒之後指向席菈（名字那段）")
	s.set_flag("rb.guardian_talked", true)
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison")
	s.set_flag("rb.potion_found", true)
	s.set_flag("rb.potion_kept", true)
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison", "席菈那句說完才往下")
	s.set_flag("rb.potion_talked", true)
	assert_eq(s.quests.stage_of("rb_main"), "market_lead", "滿血選「先收著」也能完成，不強迫自殘")
	s.set_flag("rb.ada_talked", true)
	assert_eq(s.quests.marker_spec("rb_main"), "node:CellarTrigger")
	s.set_flag("rb.market_reached", true)
	assert_true(s.quests.is_done("rb_main"))
	assert_eq(s.state.get_flag("rb.first_ten_done"), true)


func test_retry_does_not_duplicate_potion_or_restore_hp() -> void:
	var s := _session()
	s.new_game()
	# 檢查點存檔前，玩家把生命、狀態、反轉欄位寫回 state
	var hp: Array[float] = [55.0]
	s.saving.connect(func(st: GameState) -> void: st.vitals["hp"] = hp[0])
	for f: String in ["rb.barrels_broken", "rb.reversal_awakened", "rb.mist_reentered", "rb.reached_south", "rb.sheila_met", "rb.guardian_down"]:
		s.set_flag(f, true)
	hp[0] = 40.0
	s.set_flag("rb.guardian_talked", true)
	assert_eq(s.state.checkpoint, "rb_portable")
	var belt := PotionBelt.new(s.state)
	assert_true(belt.grant_once("rb.guardian_crate", "mist_serpent_poison", 2))
	s.state.set_flag("rb.potion_found", true)
	assert_eq(s.retry_from_checkpoint(), SaveCodec.Status.OK, "撿藥之後死掉重來")
	assert_eq(s.state.mode, "reboot")
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison")
	var belt2 := PotionBelt.new(s.state)
	assert_eq(belt2.count("mist_serpent_poison"), 0, "檢查點之後撿的跟著退回")
	assert_true(belt2.grant_once("rb.guardian_crate", "mist_serpent_poison", 2), "再撿一次")
	assert_false(belt2.grant_once("rb.guardian_crate", "mist_serpent_poison", 2), "只會拿到一次")
	assert_eq(belt2.count("mist_serpent_poison"), 2)
	assert_eq(float(s.state.vitals["hp"]), 40.0, "生命照檢查點存的，不偷偷補滿")
