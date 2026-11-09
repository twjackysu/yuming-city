extends TestCase
## 第 3 章段落 2「趴在水溝裡（觀察）」的判定（D-164）：節奏 → 反應（不動／偏頭／轉頭）、敲的時間、
## 對話選了之後的判定（ch3.last_tempo → ch3.react）、觀察提示音的設定。


func test_only_a_heartbeat_turns_its_head() -> void:
	assert_eq(RhythmTrial.reaction("steady"), RhythmTrial.TURN, "不快不慢（跟人的心跳一樣）→ 轉頭")
	assert_eq(RhythmTrial.reaction("slow"), RhythmTrial.TILT, "慢一點 → 偏頭")
	assert_eq(RhythmTrial.reaction("fast"), RhythmTrial.TILT, "快一點 → 偏頭")
	assert_eq(RhythmTrial.reaction("very_slow"), RhythmTrial.STILL, "很慢 → 不動")
	assert_eq(RhythmTrial.reaction("very_fast"), RhythmTrial.STILL, "很快 → 不動")
	assert_eq(RhythmTrial.reaction("irregular"), RhythmTrial.STILL, "忽快忽慢 → 不動（牠跟的是心跳，不是聲音）")
	assert_eq(RhythmTrial.reaction("no_such"), RhythmTrial.STILL, "不認得的節奏 → 不動")
	var turns: int = 0
	for id: String in RhythmTrial.ORDER:
		assert_true(RhythmTrial.is_tempo(id), "%s 是一種節奏" % id)
		if RhythmTrial.reaction(id) == RhythmTrial.TURN:
			turns += 1
	assert_eq(turns, 1, "只有一種節奏會讓牠轉頭")
	assert_eq(RhythmTrial.ORDER.size(), RhythmTrial.TEMPOS.size(), "選項順序涵蓋所有節奏")


func test_reaction_for_bpm_brackets_the_target() -> void:
	assert_eq(RhythmTrial.reaction_for_bpm(RhythmTrial.TARGET_BPM), RhythmTrial.TURN)
	assert_eq(RhythmTrial.reaction_for_bpm(RhythmTrial.TARGET_BPM + RhythmTrial.TURN_WITHIN), RhythmTrial.TURN, "邊界算轉頭")
	assert_eq(RhythmTrial.reaction_for_bpm(RhythmTrial.TARGET_BPM - RhythmTrial.TURN_WITHIN - 1.0), RhythmTrial.TILT)
	assert_eq(RhythmTrial.reaction_for_bpm(RhythmTrial.TARGET_BPM + RhythmTrial.TILT_WITHIN + 1.0), RhythmTrial.STILL)
	assert_eq(RhythmTrial.reaction_for_bpm(0.0), RhythmTrial.STILL, "沒有節奏 → 不動")


func test_knock_times() -> void:
	var t: PackedFloat32Array = RhythmTrial.knock_times("steady", 4)
	assert_eq(t.size(), 4)
	assert_eq(t[0], 0.0, "第一下在 0")
	assert_true(absf(t[3] - 3.0 * 60.0 / 72.0) < 0.001, "每分鐘 72 下：第 4 下在 2.5 秒")
	var irr: PackedFloat32Array = RhythmTrial.knock_times("irregular", 5)
	var gaps: Array[float] = []
	for i: int in 4:
		gaps.append(irr[i + 1] - irr[i])
	assert_true(gaps.max() - gaps.min() > 0.5, "忽快忽慢：間隔差很多")
	assert_eq(RhythmTrial.knock_times("irregular", 5), irr, "不規則的序列每次一樣")


func test_try_last_writes_reaction_flag() -> void:
	var s := GameState.new()
	assert_eq(RhythmTrial.try_last(s), "", "還沒選過節奏")
	StoryLogic.apply({"set": {"ch3.tempo_fast": true, "ch3.last_tempo": "fast", "ch3.react": ""}, "add": {"ch3.rhythm_tries": 1}}, s)
	assert_eq(RhythmTrial.try_last(s), RhythmTrial.TILT)
	assert_eq(s.get_flag("ch3.react"), RhythmTrial.TILT, "結果寫進 ch3.react（對話的下一句讀它）")
	assert_true(StoryLogic.check({"flag": "ch3.react", "eq": "tilt"}, s), "對話條件讀得到")
	assert_eq(RhythmTrial.tried(s), PackedStringArray(["fast"]), "試過的節奏")


func test_dialogue_offers_every_tempo_and_confirms_the_note() -> void:
	var db := DialogueDB.load_default()
	assert_true(db.has_dialogue("ch3_rhythm"), "對話 ch3_rhythm 存在")
	var hub: Dictionary = db.node("ch3_rhythm", "hub")
	var texts: PackedStringArray = []
	for c: Variant in (hub.get("choices", []) as Array):
		texts.append(str((c as Dictionary)["text"]))
	for id: String in RhythmTrial.ORDER:
		assert_true(("DLG_CH3_RHY_C_" + id.to_upper()) in texts, "選項有 %s" % id)
	assert_eq(str(db.node("ch3_rhythm", "knock").get("text", "")), "DLG_CH3_RHY_KNOCK", "「敲」那一句（關卡在這句判定）")
	var g: GuideNotes = GuideNotes.load_default()
	var s := GameState.new()
	GuideNotes.write_blank(s, ["clapper_heartbeat"])
	assert_eq(GuideNotes.status(s, "clapper_heartbeat"), GuideNotes.BLANK)
	s.set_flag(RhythmTrial.FLAG_FOUND, true)
	g.evaluate(s)
	assert_eq(GuideNotes.status(s, "clapper_heartbeat"), GuideNotes.CONFIRMED, "找到速度 → 空白條目變成證實")


func test_observe_cue_setting_defaults_on_and_persists() -> void:
	var settings: Node = Engine.get_main_loop().root.get_node("Settings")
	assert_eq(settings.call("get_option", "observe_cue"), true, "觀察提示音預設開")
	var path: String = "user://test_observe_cue.cfg"
	settings.call("set_option", "observe_cue", false)
	settings.call("save_settings", path)
	settings.call("set_option", "observe_cue", true)
	settings.call("load_settings", path)
	assert_eq(settings.call("get_option", "observe_cue"), false, "關掉之後存檔讀檔還是關")
	settings.call("set_option", "observe_cue", true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
