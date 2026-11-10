extends TestCase
## M1.4 主線流程（場景層面）：用 Game.go_to_level 真的換場景進霜橋鎮，從新遊戲走到切片結尾。
## 每進一個檢查點就呼叫 Game.retry()（真的重新載入關卡），確認「任務恢復」：
## 任務階段、HUD 目標、出生位置、場上該有／不該有的東西（席菈、灰巡者、受困者、送葬者）。
## 兩條路線：九息石拱（付出父親的記憶、對艾妲說不出那段話）／薪火劍（記憶還在、收下梨）。

const STALL_NEAR: Vector3 = Vector3(3.2, 0.05, 0.6)

var _dir: String = ""
var _game: Node
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_playthrough_%d" % Time.get_ticks_usec()
	_game = tree.root.get_node("Game")
	_original = _game.get("session") as GameSession


func after_each() -> void:
	_game.set("session", _original)
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _level() -> StoryLevel:
	return tree.current_scene as StoryLevel


## change_scene_to_file：舊場景立刻移出、這一幀結束時新場景才進樹。
func _wait_scene() -> StoryLevel:
	for i: int in 3:
		await tree.process_frame
	await tree.physics_frame
	return _level()


func _retry() -> StoryLevel:
	var s: GameSession = _game.get("session") as GameSession
	var played: float = s.state.playtime_sec
	_game.call("retry")
	assert_true(s.state.playtime_sec >= played, "重來不會把遊戲時間退回檢查點（D-179）")
	return await _wait_scene()


func _player(level: StoryLevel) -> PlayerController:
	return level.get_node("Player") as PlayerController


func _objective(level: StoryLevel) -> String:
	return (level.get_node("Hud") as Hud).objective_text_key()


func _stage(s: GameSession) -> String:
	return s.quests.stage_of(GameSession.MAIN_QUEST)


## 瞬移進觸發區（下一個物理幀才會 body_entered）。
func _step_into(player: PlayerController, pos: Vector3, frames: int = 4) -> void:
	var level: StoryLevel = _level()
	var ground: float = level.ground_y(pos) if level != null else 0.0
	player.global_position = Vector3(pos.x, ground + 0.05, pos.z)
	for i: int in frames:
		await tree.physics_frame


func _run_dialogue(level: StoryLevel, choice: int) -> int:
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	var choices: Node = box.find_child("Choices", true, false)
	var most_choices: int = 0
	for i: int in 40:
		# 對話講完就換關卡（柯德 → 白晝城）：下一個關卡的對話不算這一段
		if not is_instance_valid(box) or not bool(_game.call("is_in_dialogue")):
			break
		if choices.get_child_count() > 0:
			most_choices = maxi(most_choices, choices.get_child_count())
			(choices.get_child(mini(choice, choices.get_child_count() - 1)) as Button).pressed.emit()
		else:
			box.press_continue()
		await tree.process_frame
	return most_choices


func _rescue_sites(level: StoryLevel) -> Array[RescueSite]:
	var out: Array[RescueSite] = []
	for c: Node in level.get_children():
		if c is RescueSite:
			out.append(c as RescueSite)
	return out


func _playthrough(use_nine_breath: bool) -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	# 成就（D-147）：只在記憶體，走完再檢查兩條路線各自解鎖了哪些
	s.attach_achievements(AchievementTracker.new(AchievementTracker.load_defs(), ""))
	_game.set("session", s)
	s.new_game()
	_game.call("go_to_level", "frostbridge")
	var level: StoryLevel = await _wait_scene()
	assert_not_null(level, "換場景進霜橋鎮")
	if level == null:
		return
	await _assert_restore(level, "[slice_start]", ["south_arch"])
	_assert_ambience(level, "[slice_start]", "frost_wind")
	assert_eq(_player(level).footstep_surface(), "snow", "[slice_start] 腳步踩在雪上")
	assert_eq(_stage(s), "explore_town", "新遊戲：找梨販")
	assert_true(_player(level).global_position.distance_to(Vector3(0, 0.05, 7)) < 0.6, "廣場南邊出生")

	# --- 段落 2：梨販
	await _step_into(_player(level), (level.get_node("PearSellerTrigger") as Node3D).global_position)
	assert_true(_game.call("is_in_dialogue"), "走到梨販攤 → 對話")
	await _run_dialogue(level, 99)  # 最後一個選項「我先走了」
	assert_eq(_stage(s), "ring_bell", "說完 → 敲鐘")

	# 檢查點 bell_tower：重來
	level = await _retry()
	assert_eq(_stage(s), "ring_bell", "[bell_tower] 階段恢復")
	assert_eq(_objective(level), "Q_SLICE_OBJ_BELL", "[bell_tower] HUD 目標")
	assert_eq(s.state.get_flag("slice.met_pear_seller"), true, "[bell_tower] 梨販談過")
	assert_false(level.is_north_collapsed(), "[bell_tower] 北街還沒陷落")
	assert_eq(_rescue_sites(level).size(), 0, "[bell_tower] 還沒有受困者")

	# --- 段落 2：親手敲九下
	await _step_into(_player(level), (level.get_node("BellTowerTrigger") as Node3D).global_position)
	assert_true(_game.call("is_in_cutscene"), "走到鐘樓 → 敲鐘演出")
	var cs: CutsceneRunner = _game.get("cutscene") as CutsceneRunner
	if cs == null:
		return
	cs.update(10.0)
	for i: int in 9:
		cs.press(cs.awaited_action())
	for i: int in 3:
		cs.update(10.0)
	assert_false(_game.call("is_in_cutscene"), "演出結束")
	assert_eq(_stage(s), "rescue", "九聲 → 救援")

	# 檢查點 rescue：重來
	level = await _retry()
	assert_eq(_stage(s), "rescue", "[rescue] 階段恢復")
	assert_eq(_objective(level), "Q_SLICE_OBJ_RESCUE", "[rescue] HUD 目標")
	assert_true(_player(level).global_position.distance_to(Vector3(0, 0.05, -24)) < 0.6, "[rescue] 主街北段出生")
	assert_true(level.is_north_collapsed(), "[rescue] 北街已陷落")
	var sites: Array[RescueSite] = _rescue_sites(level)
	assert_eq(sites.size(), 4, "[rescue] 四個受困者")
	assert_false(level.has_node("Sheila"), "[rescue] 席菈還沒出現")

	# --- 段落 3：救三人
	for i: int in 3:
		sites[i].rescue()
	assert_eq(_stage(s), "meet_sheila", "救三人 → 席菈")
	assert_true(level.has_node("Sheila"), "席菈出現")

	# 檢查點 sheila_meet：重來
	level = await _retry()
	assert_eq(_stage(s), "meet_sheila", "[sheila_meet] 階段恢復")
	assert_eq(_objective(level), "Q_SLICE_OBJ_SHEILA", "[sheila_meet] HUD 目標")
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	assert_not_null(sheila, "[sheila_meet] 席菈在主街北段等")
	assert_false(level.has_node("Ashwalker"), "[sheila_meet] 還沒說話：沒有灰巡者")
	sites = _rescue_sites(level)
	var rescued: int = 0
	for site: RescueSite in sites:
		if site.is_rescued():
			rescued += 1
	assert_eq(rescued, 3, "[sheila_meet] 救過的三人不會重來")
	assert_eq(int(s.state.get_flag("slice.rescued_count", 0)), 3, "[sheila_meet] 救援數")
	if sheila == null:
		return

	# --- 段落 4：席菈（九息路線說實話、薪火劍路線說謊）→ 灰巡者
	sheila.set_physics_process(false)
	await _step_into(_player(level), sheila.global_position + Vector3(1.2, 0.0, 0.8), 3)
	assert_true(_game.call("is_in_dialogue"), "走近席菈 → 對話")
	await _run_dialogue(level, 0 if use_nine_breath else 1)
	assert_eq(s.state.get_flag("slice.told_truth_about_bell"), use_nine_breath, "說實話／說謊")
	var walker: Ashwalker = level.get_node_or_null("Ashwalker") as Ashwalker
	assert_not_null(walker, "說完話 → 灰巡者")
	if walker == null:
		return
	walker.set_physics_process(false)
	walker.health.apply_damage(walker.health.hp + 1.0, {"stagger": 0.0})
	await tree.physics_frame
	assert_eq(_stage(s), "escort_convoy", "打倒灰巡者 → 護送車隊")

	# 檢查點 undertaker：重來
	level = await _retry()
	assert_eq(_stage(s), "escort_convoy", "[undertaker] 階段恢復")
	assert_eq(_objective(level), "Q_SLICE_OBJ_CONVOY", "[undertaker] HUD 目標")
	assert_true(_player(level).global_position.distance_to(Vector3(0, 0.05, 6)) < 0.6, "[undertaker] 廣場出生")
	assert_true(level.has_node("Sheila"), "[undertaker] 席菈在身邊")
	assert_false(level.has_node("Ashwalker"), "[undertaker] 灰巡者不會再出現")
	assert_false(level.has_node("Undertaker"), "[undertaker] 還沒走進南街")
	assert_eq(s.state.get_flag("slice.told_truth_about_bell"), use_nine_breath, "[undertaker] 對話選擇保留")

	# --- 段落 5：走進南街 → 送葬者戰
	await _step_into(_player(level), (level.get_node("ConvoyTrigger") as Node3D).global_position, 2)
	var enc: ConvoyEncounter = level.encounter
	assert_not_null(enc, "走進南街 → 送葬者戰")
	if enc == null:
		return
	_player(level).global_position = Vector3(0.0, 0.05, 4.0)
	var boss: Undertaker = level.get_node("Undertaker") as Undertaker
	var caravan: Caravan = level.get_node("Caravan") as Caravan
	boss.health.apply_damage(boss.health.hp - 290.0, {"stagger": 0.0})
	await tree.physics_frame
	await tree.physics_frame
	assert_not_null(enc.frame_throw, "第二階段生命 ≤ 300 → 舉鐵架")
	if enc.frame_throw == null:
		return
	var site_arch: NineBreathSite = level.arch_site
	if use_nine_breath:
		site_arch.update_hold(1.1, true)
		assert_true(site_arch.is_solid(), "保存南街石拱")
		assert_true(Game.restore_mix.sources_active(), "[slice_convoy] 石拱倒數中，其他聲音悶下去（D-183）")
	else:
		assert_false(Game.restore_mix.sources_active(), "[slice_convoy] 沒有重現，混音照常")
	enc.frame_throw.tick(FrameThrowEvent.WINDUP_SEC + 0.1, site_arch.is_solid(), s.state)
	assert_eq(s.state.get_flag("slice.frame_throw_outcome"), "arch" if use_nine_breath else "kindling")
	caravan.runner.traveled = caravan.runner.length() - 0.05
	for i: int in 20:
		await tree.physics_frame
		if enc.done:
			break
	assert_true(enc.done, "車隊通過路口")
	assert_eq(_stage(s), "aftermath", "車隊通過 → 收束")

	# 檢查點 aftermath：重來
	level = await _retry()
	assert_eq(_stage(s), "aftermath", "[aftermath] 階段恢復")
	assert_eq(_objective(level), "Q_SLICE_OBJ_CELLAR", "[aftermath] HUD 目標")
	assert_false(level.has_node("Undertaker"), "[aftermath] 送葬者戰不會重打")
	assert_true(level.encounter == null, "[aftermath] 沒有遭遇戰")
	assert_true(level.has_node("Sheila"), "[aftermath] 席菈還在")
	assert_eq(s.state.has_paid_memory("arch_father_last_talk"), use_nine_breath, "[aftermath] 記憶代價保留")
	assert_false(level.arch_site.is_solid(), "[aftermath] 石拱不會還立著")

	# --- 段落 6：艾妲 → 地窖
	await _step_into(_player(level), STALL_NEAR, 3)
	assert_true(_game.call("is_in_dialogue"), "回梨販攤 → 艾妲")
	var choice_count: int = await _run_dialogue(level, 0)
	assert_eq(choice_count, 1 if use_nine_breath else 2, "付出記憶後說不出父親那段話")
	assert_eq(s.state.get_flag("slice.ada_gave_pear", false), not use_nine_breath, "記得 → 收下梨")
	assert_eq(s.state.get_flag("slice.ada_talked_aftermath"), true)
	_player(level).global_position = Vector3(0.0, 0.05, 2.0)
	await tree.physics_frame
	await _step_into(_player(level), (level.get_node("CellarTrigger") as Node3D).global_position, 3)
	assert_eq(s.state.get_flag("slice.cellar_entered"), true, "走進地窖")
	assert_true(s.is_slice_complete(), "切片完成")

	# 成就：中途重來了六次，該解鎖的照樣解鎖；另一條路線的沒有
	var ach: AchievementTracker = s.achievements
	var expected: Array[String] = ["ACH_NINTH_BELL", "ACH_NO_ONE_LEFT"]
	if use_nine_breath:
		expected.append_array(["ACH_THE_TRUTH", "ACH_NINE_SECONDS"])
	else:
		expected.append("ACH_BURNING_BLADE")
	if int(s.state.get_flag("slice.convoy_injured", 0)) == 0:
		expected.append("ACH_SAFE_PASSAGE")
	expected.append("ACH_CELLAR_DOOR")
	var got: Array[String] = []
	for id: String in ach.unlocked_ids():
		got.append(id)
	var want: Array[String] = []
	for id: String in ach.ids():
		if expected.has(id):
			want.append(id)
	assert_eq(got, want, "成就（%s）" % ("石拱路線" if use_nine_breath else "燃燒劍路線"))
	assert_false(ach.is_unlocked("ACH_SEEN_THROUGH"), "灰巡者是直接打倒的（沒打弱點）")

	# --- 第 1 章（D-149）：章節卡 → 酒館：中午 → 晚餐（灑湯）→ 攻略地圖 → 出門
	await _chapter1(level, use_nine_breath)


## 走到說話點旁邊（TALK_RANGE 以內），等對話開始後走完。
func _talk_at(level: StoryLevel, node_name: String, choice: int) -> void:
	var n: Node3D = level.get_node(node_name) as Node3D
	var p: PlayerController = _player(level)
	p.global_position = Vector3(n.global_position.x + 1.0, 0.05, n.global_position.z + 0.9)
	for i: int in 3:
		await tree.physics_frame
	assert_true(_game.call("is_in_dialogue"), "走到%s旁邊 → 對話" % node_name)
	await _run_dialogue(level, choice)


## 酒館的美術（第 53 輪，D-171）：地板是木板 shader、牆是半木構的室內版（不積雪）、窗有窗框、蠟燭入夜才點。
func _assert_tavern_art(tavern: StoryLevel, night: bool) -> void:
	var tag: String = "[ch1_dinner]" if night else "[ch1_tavern]"
	var floor_mat: ShaderMaterial = (tavern.get_node("Floor") as CSGBox3D).material as ShaderMaterial
	assert_true(floor_mat != null and floor_mat.shader.resource_path == str(tavern.get("PLANK_SHADER")), "%s 地板是木板" % tag)
	var wall_mat: ShaderMaterial = (tavern.get_node("WallN") as CSGBox3D).material as ShaderMaterial
	assert_true(wall_mat != null and wall_mat.shader.resource_path == FrostbridgeLook.HALF_TIMBER_SHADER, "%s 牆是半木構" % tag)
	if wall_mat != null:
		assert_eq(float(wall_mat.get_shader_parameter("exterior")), 0.0, "%s 室內牆不積雪" % tag)
	for n: String in ["WindowFrameTop", "WindowSill", "WindowMullion", "Bowl0", "Candle", "BackShelf0", "DinnerBenchN", "LampGlass"]:
		assert_true(tavern.has_node(n), "%s 有 %s" % [tag, n])
	assert_eq(bool(tavern.call("candle_lit")), night, "%s 蠟燭%s" % [tag, "點著" if night else "沒點"])
	# 聲音（D-180）：牆外悶悶的風＋壁爐的柴火從爐膛發出來；入夜火旺、比中午大聲
	_assert_ambience(tavern, tag, "frost_wind_indoor")
	assert_eq(_player(tavern).footstep_surface(), "wood", "%s 腳步踩在木板上" % tag)
	var crackle: AudioStreamPlayer3D = _assert_ambience(tavern, tag, "hearth_crackle", "HearthCrackle") as AudioStreamPlayer3D
	if crackle != null:
		var hearth: Node3D = tavern.get_node("Hearth") as Node3D
		assert_true(_flat_dist(crackle.global_position, hearth.global_position) < 1.0, "%s 柴火聲從壁爐來" % tag)
		var want: float = float(tavern.get("HEARTH_DB_NIGHT" if night else "HEARTH_DB_NOON"))
		assert_eq(crackle.volume_db, want, "%s 柴火聲的音量（入夜比較大）" % tag)
	# 窗外的光束（D-177）：東牆有真的窗洞、玻璃不擋光、聚光燈投影子；中午亮、入夜只剩淡藍
	assert_false(tavern.has_node("WallE"), "%s 東牆拆成四塊（中間是窗洞）" % tag)
	var glass: CSGBox3D = tavern.get_node("Window") as CSGBox3D
	assert_eq(glass.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s 窗玻璃不擋光" % tag)
	var beam: SpotLight3D = tavern.get_node_or_null("SunBeam") as SpotLight3D
	assert_not_null(beam, "%s 窗外的光束" % tag)
	if beam != null:
		assert_true(beam.shadow_enabled, "%s 光束投影子（窗櫺的十字）" % tag)
		assert_true(beam.global_position.x > float(tavern.get("ROOM_HALF").x), "%s 光從窗外來" % tag)
		if night:
			assert_true(beam.light_energy < 5.0 and beam.light_color.b > beam.light_color.r, "%s 入夜只剩淡藍" % tag)
		else:
			assert_true(beam.light_energy > 10.0, "%s 中午的光束夠亮" % tag)
	if not night:
		# 截圖旗標 --pos（第 53 輪）：格式不對不動，對的話把諾恩移過去
		assert_false(bool(tavern.call("dev_place_player", "1.0")), "%s --pos 格式不對" % tag)
		assert_true(bool(tavern.call("dev_place_player", "2.0,2.0")), "%s --pos=2,2" % tag)
		var at: Vector3 = _player(tavern).global_position
		assert_true(absf(at.x - 2.0) < 0.01 and absf(at.z - 2.0) < 0.01, "%s 諾恩移到 (2, 2)" % tag)


func _chapter1(level: StoryLevel, help_with_soup: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(s.main_quest(), "ch1_main", "切片完成 → 主線換成第 1 章")
	assert_eq(s.state.chapter, "ch1", "章節換成 ch1")
	assert_eq(s.state.checkpoint, "ch1_tavern", "第 1 章的第一個檢查點")
	var card: ChapterCard = level.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "走進地窖 → 章節卡")
	if card == null:
		return
	assert_eq(card.title_text(), tr("CH1_CARD_TITLE"), "章節卡的章名")
	card.finish()
	var tavern: StoryLevel = await _wait_scene()
	assert_eq(str(tavern.name), "Tavern", "章節卡之後換到酒館")
	assert_eq(_objective(tavern), "Q_CH1_OBJ_NOON", "[ch1_tavern] HUD 目標")
	assert_false(bool(tavern.call("is_night")), "中午")
	_assert_tavern_art(tavern, false)
	await _assert_restore(tavern, "[ch1_tavern]", [])
	await _talk_at(tavern, "Sheila", 0)
	assert_eq(s.state.get_flag("ch1.noon_talked"), true, "中午跟席菈、彌夏說完話")
	assert_eq(s.quests.stage_of("ch1_main"), "dinner")
	assert_true(bool(tavern.call("is_night")), "晚餐：入夜")
	# 重來：回到晚餐的檢查點，還在酒館
	tavern = await _retry()
	assert_eq(str(tavern.name), "Tavern", "[ch1_dinner] 重來還在酒館")
	assert_eq(s.quests.stage_of("ch1_main"), "dinner", "[ch1_dinner] 階段恢復")
	_assert_tavern_art(tavern, true)
	assert_eq(_objective(tavern), "Q_CH1_OBJ_DINNER", "[ch1_dinner] HUD 目標")
	await _talk_at(tavern, "DinnerTable", 0 if help_with_soup else 1)
	assert_eq(s.state.get_flag("ch1.sheila_soup_helped"), help_with_soup, "灑湯的選擇記下來")
	assert_eq(s.quests.stage_of("ch1_main"), "draw_map")
	for id: String in s.guide.ids():
		assert_eq(GuideNotes.status(s.state, id), GuideNotes.UNWRITTEN, "畫地圖之前還沒寫下 %s" % id)
	await _talk_at(tavern, "MapTable", 0)
	for id: String in s.guide.remembered_ids():
		assert_eq(GuideNotes.status(s.state, id), GuideNotes.SURE, "攻略筆記寫下 %s（預設確定）" % id)
	assert_ne(s.state.get_flag("ch1.map_drawn", false), true, "還沒標完")
	for i: int in 3:
		await tree.physics_frame
	var view: GuideMarkView = tavern.get_node_or_null("GuideMarkView") as GuideMarkView
	assert_not_null(view, "席菈說完 → 標記畫面")
	if view == null:
		return
	assert_true(tree.paused, "標記畫面打開時暫停")
	assert_eq(view.entry_ids.size(), 6, "列出 6 條")
	# 石拱路線：標射箭陷阱「我不確定」；燃燒劍路線：全部確定
	if help_with_soup:
		(view.rows["stair_arrows"] as Button).pressed.emit()
		assert_true(view.is_unsure("stair_arrows"), "點一下 → 我不確定")
	view.done_button.pressed.emit()
	assert_false(tree.paused, "就這樣 → 解除暫停")
	assert_true(_game.call("is_in_dialogue"), "標完 → 最後一句")
	var box_line: String = (_game.get("dialogue") as DialogueRunner).current_text()
	assert_eq(box_line, "DLG_CH1_MAP_007_SOME" if help_with_soup else "DLG_CH1_MAP_007_NONE", "最後一句跟著標了幾條")
	await _run_dialogue(tavern, 0)
	assert_eq(s.state.get_flag("ch1.map_drawn"), true, "攻略畫成地圖")
	var want_arrows: String = GuideNotes.UNSURE if help_with_soup else GuideNotes.SURE
	assert_eq(GuideNotes.status(s.state, "stair_arrows"), want_arrows, "標記寫進攻略筆記")
	assert_eq(GuideNotes.status(s.state, "usurper"), GuideNotes.SURE, "沒標的照舊確定")
	assert_eq(s.quests.stage_of("ch1_main"), "to_cellar")
	tavern = await _retry()
	assert_eq(s.quests.stage_of("ch1_main"), "to_cellar", "[ch1_map_done] 階段恢復")
	assert_eq(GuideNotes.status(s.state, "stair_arrows"), want_arrows, "[ch1_map_done] 攻略筆記與標記保留")
	assert_false(tavern.has_node("GuideMarkView"), "[ch1_map_done] 不會再開標記畫面")
	assert_eq(s.state.get_flag("ch1.sheila_soup_helped"), help_with_soup, "[ch1_map_done] 灑湯的選擇保留")
	# --- 段落 4（D-151）：出門 → 白天的霜橋鎮 → 北街 → 艾妲的油燈 → 地窖 → 段落 5 一百七十二階（D-152）
	await _chapter1_day(tavern, help_with_soup)


## 段落 4：石拱路線（paid_arch）付了父親那段記憶，艾妲的第一句不同。
func _chapter1_day(tavern: StoryLevel, paid_arch: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	var door: Node3D = tavern.get_node("TavernDoor") as Node3D
	await _step_into(_player(tavern), door.global_position, 2)
	assert_eq(s.state.get_flag("ch1.left_tavern"), true, "走到酒館門口 → 出門")
	assert_eq(s.state.checkpoint, "ch1_day_town", "出門 → 白天的檢查點")
	var town: StoryLevel = await _wait_scene()
	assert_eq(str(town.name), "Frostbridge", "出門 → 霜橋鎮")
	_assert_day_town(town, "[ch1_day_town]")
	await _assert_restore(town, "[ch1_day_town]", [])
	assert_eq(_objective(town), "Q_CH1_OBJ_DAY_NORTH", "[ch1_day_town] HUD 目標")
	town = await _retry()
	assert_eq(s.quests.stage_of("ch1_main"), "day_north", "[ch1_day_town] 重來階段恢復")
	_assert_day_town(town, "[ch1_day_town] 重來")
	await _step_into(_player(town), Vector3(0.0, 0.0, -32.0), 3)
	assert_true(_game.call("is_in_dialogue"), "走上北街 → 白天看昨晚的現場")
	await _run_dialogue(town, 0)
	assert_eq(s.state.get_flag("ch1.saw_north_day"), true, "北街的對話講完")
	assert_eq(s.quests.stage_of("ch1_main"), "ada_lamp")
	# D-170：回廣場的路上看死者名單（可以不看）
	var board: DeadListBoard = town.get_node("DeadList") as DeadListBoard
	await _step_into(_player(town), board.global_position + board.global_basis.z * 1.3, 3)
	assert_true(board.is_near(), "走到名單前 → 提示")
	assert_false(board.interact_hint().is_empty(), "提示「看名單」")
	board.read()
	assert_true(_game.call("is_in_dialogue"), "看名單 → 對話")
	var count: int = DeadListBoard.dead_count(s.state)
	assert_eq((_game.get("dialogue") as DialogueRunner).current_text(), "DLG_CH1_LIST_COUNT_%d" % count, "數到的張數跟切片結果一樣")
	await _run_dialogue(town, 0)
	assert_eq(s.state.get_flag("ch1.read_dead_list"), true, "看完名單")
	assert_eq(s.quests.stage_of("ch1_main"), "ada_lamp", "看名單不影響主線")
	var ada: Node3D = town.get_node("Ada") as Node3D
	await _step_into(_player(town), ada.global_position + Vector3(0.0, 0.0, 1.6), 3)
	assert_true(_game.call("is_in_dialogue"), "走到地窖門口 → 艾妲")
	var first: String = (_game.get("dialogue") as DialogueRunner).current_text()
	assert_eq(first, "DLG_CH1_ADA_001_FORGOT" if paid_arch else "DLG_CH1_ADA_001", "付了石拱記憶 → 「你連你爸都忘了」")
	assert_false(_player(town).has_oil_lamp(), "還拿著提燈")
	await _run_dialogue(town, 0)
	assert_eq(s.state.get_flag("ch1.lamp_received"), true, "拿到油燈")
	assert_true(_player(town).has_oil_lamp(), "油燈取代提燈")
	assert_eq(s.quests.stage_of("ch1_main"), "stairs")
	assert_eq(s.state.checkpoint, "ch1_lamp")
	# --- 段落 5（D-152）：走進地窖 → 一百七十二階
	await _step_into(_player(town), (town.get_node("CellarTrigger") as Node3D).global_position, 3)
	var stairs: StoryLevel = await _wait_scene()
	assert_eq(str(stairs.name), "Stairs", "拿著油燈走進地窖 → 一百七十二階")
	await _chapter1_stairs(stairs, paid_arch)


## 段落 5：石拱路線（標了射箭陷阱我不確定）丟石頭試探；燃燒劍路線（全部確定）直接走上平台被淋濕。
func _chapter1_stairs(stairs: StoryLevel, threw_stone: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(_objective(stairs), "Q_CH1_OBJ_STAIRS", "[ch1_lamp] HUD 目標")
	stairs = await _retry()
	assert_eq(str(stairs.name), "Stairs", "[ch1_lamp] 重來在樓梯頂")
	assert_eq(s.quests.stage_of("ch1_main"), "stairs", "[ch1_lamp] 階段恢復")
	assert_true(_player(stairs).has_oil_lamp(), "[ch1_lamp] 拿著油燈")
	assert_true(stairs.has_node("Sheila") and stairs.has_node("Misha"), "[ch1_lamp] 席菈、彌夏跟著")
	assert_true(float(stairs.call("path_param", _player(stairs).global_position)) < 3.0, "[ch1_lamp] 出生在樓梯頂")
	await _assert_restore(stairs, "[ch1_lamp]", [])
	_assert_ambience(stairs, "[ch1_lamp]", "stair_ambience")
	var entrance: float = float(stairs.call("trap_entrance_s"))
	await _step_into(_player(stairs), stairs.call("path_point", entrance - 2.0) as Vector3, 3)
	assert_true(_game.call("is_in_dialogue"), "走近陷阱 → 諾恩攔住大家")
	var warn: String = ""
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	runner.advance()
	warn = runner.current_text()
	assert_eq(warn, "DLG_CH1_STAIR_002_UNSURE" if threw_stone else "DLG_CH1_STAIR_002", "標了我不確定的那條 → 諾恩自己說")
	await _run_dialogue(stairs, 0)
	assert_eq(s.state.get_flag("ch1.stair_warned"), true)
	assert_true(bool(stairs.call("can_throw")), "攔住之後可以丟石頭")
	assert_false((stairs.call("interact_hint") as Dictionary).is_empty(), "互動提示：往前丟一塊石頭")
	if threw_stone:
		stairs.call("throw_stone")
	else:
		await _step_into(_player(stairs), stairs.call("path_point", entrance + 0.3) as Vector3, 3)
	await tree.create_timer(float(stairs.get("THROW_SEC")) + float(stairs.get("TRAP_TALK_DELAY")) + 0.3).timeout
	assert_eq(s.state.get_flag("ch1.stair_trap_sprung"), true, "機關觸發")
	assert_eq(s.state.get_flag("ch1.stair_trap_soaked"), not threw_stone, "沒丟石頭 → 淋在諾恩身上")
	assert_eq(GuideNotes.status(s.state, "stair_arrows"), GuideNotes.WRONG, "攻略筆記「射箭陷阱」被推翻")
	assert_true(_game.call("is_in_dialogue"), "水落下 → 對話")
	runner = _game.get("dialogue") as DialogueRunner
	var lines: PackedStringArray = []
	for i: int in 12:
		if not runner.is_running():
			break
		lines.append(runner.current_text())
		runner.advance()
	assert_true(("DLG_CH1_TRAP_003_UNSURE" if threw_stone else "DLG_CH1_TRAP_003") in lines, "標了我不確定 →「果然」；沒標 → 席菈看他一眼")
	assert_true(("DLG_CH1_TRAP_002" if threw_stone else "DLG_CH1_TRAP_002_SOAKED") in lines, "水潑在哪裡")
	assert_true("DLG_CH1_TRAP_004" in lines, "樓梯深處的笑聲")
	await _run_dialogue(stairs, 0)
	await _step_into(_player(stairs), stairs.call("path_point", float(stairs.call("bottom_s"))) as Vector3, 3)
	assert_eq(s.quests.stage_of("ch1_main"), "daylight_gate", "走到底 → 樓梯底的門")
	assert_eq(s.state.checkpoint, "ch1_stairs_bottom")
	stairs = await _retry()
	assert_eq(str(stairs.name), "Stairs", "[ch1_stairs_bottom] 重來還在樓梯")
	assert_eq(_objective(stairs), "Q_CH1_OBJ_GATE", "[ch1_stairs_bottom] HUD 目標")
	assert_true(float(stairs.call("path_param", _player(stairs).global_position)) > float(stairs.call("bottom_s")) - 3.0, "[ch1_stairs_bottom] 出生在樓梯底")
	assert_eq(GuideNotes.status(s.state, "stair_arrows"), GuideNotes.WRONG, "[ch1_stairs_bottom] 攻略筆記保留")
	assert_true((stairs.get_node("Puddle") as Node3D).visible, "[ch1_stairs_bottom] 平台上的水灘還在")
	assert_false(_game.call("is_in_dialogue"), "[ch1_stairs_bottom] 出生的地方離門還有一段（不會一進來就開門）")
	# --- 段落 6（D-153）：不可互動的門——柯德舉著叉子出來
	var door: Node3D = stairs.get_node("GateDoor") as Node3D
	_player(stairs).global_position = door.global_position + Vector3(-0.9, -0.95, 0.0)
	for i: int in 3:
		await tree.physics_frame
	assert_eq(s.state.get_flag("ch1.door_opened"), true, "走到門口 → 門開了")
	assert_true(stairs.has_node("Kord"), "柯德走出來")
	assert_eq(GuideNotes.status(s.state, "sealed_door"), GuideNotes.WRONG, "攻略筆記「不可互動的門」被推翻")
	assert_true(_game.call("is_in_dialogue"), "→ 對話")
	var most: int = await _run_dialogue(stairs, 0 if threw_stone else 2)
	assert_eq(most, 3, "諾恩的回答有三個選項")
	assert_eq(s.state.get_flag("ch1.kord_first"), "hands" if threw_stone else "map", "柯德的第一印象記下來")
	assert_eq(s.state.get_flag("ch1.met_kord"), true)
	assert_eq(GuideNotes.status(s.state, "city_of_monsters"), GuideNotes.WRONG, "攻略筆記「全城是怪物」被推翻：門後面是人")
	# --- 段落 7（D-154）：「那先吃點東西」→ 跟著柯德走進白晝城
	assert_eq(s.state.get_flag("ch1.entered_daylight"), true, "柯德說完 → 走進白晝城")
	var city: StoryLevel = await _wait_scene()
	assert_eq(str(city.name), "Daylight", "走進門 → 白晝城")
	await _chapter1_daylight(city)


## 段落 7：沒有影子的城——一進來的第一眼、空的淨化爐、瑪菈用一天換半壺水、石碑上沒有諾恩的名字、柯德家門口（待續）。
func _chapter1_daylight(city: StoryLevel) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(s.quests.stage_of("ch1_main"), "daylight_furnace")
	assert_eq(s.state.checkpoint, "ch1_daylight")
	await _assert_daylight(city, "[ch1_daylight]")
	await _assert_restore(city, "[ch1_daylight]", [])
	city = await _retry()
	assert_eq(str(city.name), "Daylight", "[ch1_daylight] 重來還在白晝城")
	assert_eq(_objective(city), "Q_CH1_OBJ_FURNACE", "[ch1_daylight] HUD 目標")
	await _assert_daylight(city, "[ch1_daylight] 重來")
	assert_true(_game.call("is_in_dialogue"), "一進來：白晝城沒有天空")
	await _run_dialogue(city, 0)
	assert_eq(s.state.get_flag("ch1.daylight_intro"), true)
	var furnace: Vector3 = city.get("FURNACE_POS") as Vector3
	await _step_into(_player(city), furnace + Vector3(-2.4, 0.0, -0.5), 3)
	assert_true(_game.call("is_in_dialogue"), "走到爐子旁邊 → 對話")
	assert_eq(GuideNotes.status(s.state, "purifier"), GuideNotes.WRONG, "攻略筆記「入口的淨化爐」被推翻")
	await _run_dialogue(city, 0)
	assert_eq(s.quests.stage_of("ch1_main"), "daylight_stele", "看完爐子 → 跟著柯德走")
	assert_eq(_objective(city), "Q_CH1_OBJ_FOLLOW_KORD")
	var stele: Vector3 = (city.get("STELES") as Dictionary)["stele_gate"] as Vector3
	var res: Residents = city.get("residents") as Residents
	assert_eq(res.days_left(s.state, "mara"), 19, "換水之前：瑪菈還能活 19 天")
	await _step_into(_player(city), stele + Vector3(-1.6, 0.0, 4.5), 3)
	assert_true(_game.call("is_in_dialogue"), "走近路口的石碑 → 瑪菈把手按在石碑上")
	await _run_dialogue(city, 0)
	assert_eq(res.days_left(s.state, "mara"), 18, "數字 19 → 18")
	assert_true(str(city.call("stele_text", "stele_gate")).contains(res.line(s.state, "mara")), "石碑上的字跟著變")
	assert_true((city.find_child("JugWater", true, false) as Node3D).visible, "壺裡有半壺水")
	assert_eq(s.quests.stage_of("ch1_main"), "kord_home", "→ 到柯德家吃飯")
	var other: Vector3 = (city.get("STELES") as Dictionary)["stele_bakery"] as Vector3
	await _step_into(_player(city), other + Vector3(0.4, 0.0, 1.3), 2)
	assert_eq(str(city.call("nearest_stele")), "stele_bakery", "站在第二塊石碑前")
	assert_false((city.call("interact_hint") as Dictionary).is_empty(), "互動提示：把手按在石碑上")
	city.call("touch_stele")
	assert_eq((city.get_node("Hud") as Hud).banner_text(), "CH1_STELE_NO_NAME", "上面沒有你的名字")
	await _step_into(_player(city), city.get("KORD_HOME") as Vector3 + Vector3(0.6, 0.0, 0.0), 3)
	await _chapter1_dinner(city)


## 段落 8（D-155）：柯德家的晚餐——走到門口進屋、五片麵包、小女兒的問題、席菈放乾糧（兩條路線各選一邊）、
## 吃完回到街上（檢查點 ch1_after_dinner）→ 跟著柯德到鐘院門口（待續）。
func _chapter1_dinner(city: StoryLevel) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_true(bool(city.get("in_house")), "走到柯德家門口 → 進屋")
	assert_true(_game.call("is_in_dialogue"), "→ 晚餐對話")
	var house: Vector3 = city.get("HOUSE_ORIGIN") as Vector3
	assert_true(_flat_dist(_player(city).global_position, house) < 3.0, "諾恩在屋裡的桌邊")
	for n: String in ["KordWife", "KordDaughter", "KordSon", "DinnerTable", "KordWater"]:
		assert_true(city.has_node(n), "屋裡有 " + n)
	# 室內材質（第 53 輪，D-171）：木板地、室內牆（不積雪）
	var house_floor: ShaderMaterial = (city.get_node("HouseFloor") as MeshInstance3D).material_override as ShaderMaterial
	assert_true(house_floor != null and house_floor.shader.resource_path == InteriorLook.PLANK_SHADER, "柯德家是木板地")
	assert_eq(_player(city).footstep_surface(), "wood", "[柯德家] 腳步踩在木板上（D-184）")
	assert_eq(Footsteps.surface_at(city.get_node("Sheila") as Node3D), "wood", "[柯德家] 席菈也是")
	var house_wall: ShaderMaterial = (city.get_node("HouseWallN") as MeshInstance3D).material_override as ShaderMaterial
	assert_true(house_wall != null and float(house_wall.get_shader_parameter("exterior")) == 0.0, "柯德家的牆是室內牆")
	assert_true(_flat_dist((city.get_node("Kord") as Node3D).global_position, house) < 3.0, "柯德也在桌邊")
	assert_true(_flat_dist((city.get_node("Sheila") as Node3D).global_position, house) < 3.0, "席菈也在桌邊")
	assert_false((city.get_node("RationsSheila") as Node3D).visible, "席菈還沒放乾糧")
	await _assert_daylight(city, "[柯德家]")
	# 丟石頭那條路線（柯德的第一印象 hands）：回答＋跟著放乾糧；另一條：不回答＋不放
	var share: bool = s.state.get_flag("ch1.kord_first") == "hands"
	var most: int = await _run_dialogue(city, 0 if share else 1)
	assert_eq(most, 2, "晚餐的選項各兩個")
	assert_eq(s.state.get_flag("ch1.answered_daughter"), share, "回答／不回答小女兒記下來")
	assert_eq(s.state.get_flag("ch1.shared_rations"), share, "放不放乾糧記下來（第 4 章柯德的台詞）")
	assert_eq(s.state.get_flag("ch1.sheila_shared"), true, "席菈一定放")
	assert_false(bool(city.get("in_house")), "吃完 → 回到街上")
	assert_true(_flat_dist(_player(city).global_position, city.get("KORD_HOME") as Vector3) < 3.0, "站在柯德家門口")
	assert_eq(s.quests.stage_of("ch1_main"), "bell_yard", "→ 跟著柯德去鐘院")
	assert_eq(s.state.checkpoint, "ch1_after_dinner")
	for i: int in 2:
		await tree.physics_frame
	assert_true((city.get_node("RationsSheila") as Node3D).visible, "桌上有席菈的乾糧")
	assert_eq((city.get_node("RationsNoen") as Node3D).visible, share, "諾恩的乾糧跟著選項")
	city = await _retry()
	assert_eq(str(city.name), "Daylight", "[ch1_after_dinner] 重來還在白晝城")
	assert_eq(_objective(city), "Q_CH1_OBJ_BELL_YARD", "[ch1_after_dinner] HUD 目標")
	assert_false(bool(city.get("in_house")), "[ch1_after_dinner] 在街上")
	assert_true(_flat_dist(_player(city).global_position, city.get("KORD_HOME") as Vector3) < 3.0, "[ch1_after_dinner] 出生在柯德家門口")
	await _assert_daylight(city, "[ch1_after_dinner]")
	for i: int in 3:
		await tree.physics_frame
	assert_false(_game.call("is_in_dialogue"), "[ch1_after_dinner] 不會又開晚餐")
	assert_eq(s.state.get_flag("ch1.shared_rations"), share, "[ch1_after_dinner] 乾糧的選項保留")
	# --- 段落 9（D-156）：往鐘院的路上——兔子、「看路，攻略先生。」、撞上柱子
	for n: String in ["RabbitGirl", "RabbitMother", "StreetPillar", "StreetPillarBody"]:
		assert_true(city.has_node(n), "街上有 " + n)
	await _step_into(_player(city), (city.get("KORD_HOME") as Vector3) + Vector3(2.0, 0.0, -1.4), 3)
	assert_true(_game.call("is_in_dialogue"), "往鐘院走 → 小女孩摸了席菈背上的斷劍")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	var lines: PackedStringArray = []
	for i: int in 12:
		if not runner.is_running():
			break
		lines.append(runner.current_text())
		runner.advance()
	assert_true("DLG_CH1_RABBIT_002" in lines and "DLG_CH1_RABBIT_006" in lines, "劍柄上的兔子、「很醜。我知道。」")
	assert_true("DLG_CH1_RABBIT_008" in lines, "看路，攻略先生。")
	await _run_dialogue(city, 0)
	assert_eq(s.state.get_flag("ch1.rabbit_seen"), true)
	assert_false(_game.call("is_in_dialogue"), "兔子之後不會一直重開")
	var pillar: Vector3 = city.get("PILLAR_POS") as Vector3
	await _step_into(_player(city), pillar + Vector3(0.0, 0.0, 0.7), 3)
	assert_eq(s.state.get_flag("ch1.bumped_pillar"), true, "走到柱子前 → 撞上去")
	assert_true(_game.call("is_in_dialogue"), "→ 我撞上了柱子；彌夏笑得扶住鐘箱")
	await _run_dialogue(city, 0)
	await _step_into(_player(city), city.get("BELL_YARD_POS") as Vector3, 3)
	assert_false(_game.call("is_in_dialogue"), "撞過一次就不會再開")
	assert_true(s.quests.is_done("ch1_main"), "走到鐘院門口 → 第 1 章完成")
	assert_eq(s.state.get_flag("ch1.complete"), true)
	await _chapter2(city)


## 第 2 章（D-157／D-158）：章節卡 → 鐘院（城主的飯廳）→ 伊薩拉椅子、支架吱一聲 → 飯桌的對話 → 看穿伊薩（或沉默）→
## 他自願的（道歉／不說話）→ 檢查點 ch2_volunteer → 鐘院內室待續。
func _chapter2(city: StoryLevel) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(s.main_quest(), "ch2_main", "第 1 章完成 → 主線換成第 2 章")
	assert_eq(s.state.chapter, "ch2", "章節換成 ch2")
	assert_eq(s.state.checkpoint, "ch2_start", "第 2 章的第一個檢查點")
	var card: ChapterCard = city.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "鐘院門口 → 第 2 章章節卡")
	if card == null:
		return
	assert_eq(card.title_text(), tr("CH2_CARD_TITLE"), "章節卡的章名：城主的飯桌")
	card.finish()
	var hall: StoryLevel = await _wait_scene()
	assert_eq(str(hall.name), "BellHall", "章節卡之後換到鐘院")
	await _assert_bell_hall(hall, "[ch2_start]")
	await _assert_restore(hall, "[ch2_start]", [])
	_assert_ambience(hall, "[ch2_start]", "daylight_ambience")
	hall = await _retry()
	assert_eq(str(hall.name), "BellHall", "[ch2_start] 重來還在鐘院")
	assert_eq(_objective(hall), "Q_CH2_OBJ_TABLE", "[ch2_start] HUD 目標")
	assert_false(bool(hall.call("is_seated")), "[ch2_start] 還沒坐下")
	await _assert_bell_hall(hall, "[ch2_start] 重來")
	assert_eq(float(hall.get("steam_level")), 1.0, "剛端上來的粥冒著熱氣")
	await _step_into(_player(hall), hall.get("CHAIR_POS") as Vector3 + Vector3(0.0, 0.0, 1.2), 3)
	assert_true(bool(hall.call("is_seated")), "走到桌邊 → 伊薩拉椅子")
	assert_true(_game.call("is_in_dialogue"), "→ 飯桌的對話")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	var lines: PackedStringArray = []
	for i: int in 12:
		if not runner.is_running():
			break
		lines.append(runner.current_text())
		runner.advance()
	assert_true("DLG_CH2_TABLE_003" in lines, "伊薩先問席菈的手")
	assert_true("DLG_CH2_TABLE_007" in lines, "他為什麼進了鐘院？")
	await _run_dialogue(hall, 0)
	assert_eq(s.state.get_flag("ch2.table_seated"), true)
	# 兩條路線：丟石頭那條（柯德的第一印象 hands）看穿伊薩＋先開口道歉；另一條不看穿（沉默一段時間伊薩自己開口）＋不說話
	var see_through: bool = s.state.get_flag("ch1.kord_first") == "hands"
	var strike: StrikeCard = hall.call("strike_card") as StrikeCard
	assert_not_null(strike, "看穿伊薩的小卡")
	hall.call("update_isa_insight", 0.1, false)
	assert_false(strike.visible, "沒按看穿：不顯示")
	assert_eq(str((hall.call("interact_hint") as Dictionary).get("action", "")), "insight", "提示：按住看穿伊薩")
	assert_ne(GuideNotes.status(s.state, "usurper"), GuideNotes.WRONG, "還沒看穿：攻略筆記照舊")
	if see_through:
		# 段落 1（D-158）：對伊薩按住看穿 → 攻略的稱號一個字一個字被劃掉 → 攻略筆記「城主＝食歲的僭王」被推翻
		for i: int in 60:
			hall.call("update_isa_insight", 0.1, true)
			if strike.is_done():
				break
		assert_true(strike.is_done(), "按住看穿 → 劃完")
		assert_eq(s.state.get_flag("ch2.usurper_crossed_out"), true)
		assert_eq(GuideNotes.status(s.state, "usurper"), GuideNotes.WRONG, "攻略筆記「城主＝食歲的僭王」被推翻")
		assert_true((hall.call("interact_hint") as Dictionary).is_empty(), "看穿過了：不再提示")
	else:
		hall.set("silence", float(hall.get("SILENCE_SEC")) - 0.05)
	for i: int in 6:
		await tree.physics_frame
		if _game.call("is_in_dialogue"):
			break
	assert_true(_game.call("is_in_dialogue"), "看穿劃完放開／沉默一段時間 → 伊薩開口：他自願的")
	var most: int = await _run_dialogue(hall, 0 if see_through else 1)
	assert_eq(most, 2, "道歉／不說話")
	assert_eq(s.state.get_flag("ch2.noen_apologized"), see_through, "諾恩有沒有先開口道歉記下來（第 5 章伊薩的台詞）")
	assert_eq(s.quests.stage_of("ch2_main"), "inner_room", "→ 跟著伊薩走進鐘院內室")
	await tree.process_frame
	assert_true(absf(float(hall.get("steam_level")) - float(hall.get("STEAM_COLD"))) < 0.001, "桌上的湯涼了（熱氣變淡）")
	assert_eq(ParticleLook.untextured(hall), [] as Array[String], "鐘院的粒子都有圓形貼圖")
	assert_eq(s.state.checkpoint, "ch2_volunteer")
	hall = await _retry()
	assert_eq(str(hall.name), "BellHall", "[ch2_volunteer] 重來還在鐘院")
	assert_eq(_objective(hall), "Q_CH2_OBJ_INNER", "[ch2_volunteer] HUD 目標")
	assert_true(bool(hall.call("is_seated")), "[ch2_volunteer] 在桌邊")
	assert_eq((hall.call("strike_card") as StrikeCard).is_done(), see_through, "[ch2_volunteer] 看穿過的小卡維持劃完的樣子")
	await _assert_bell_hall(hall, "[ch2_volunteer]")
	for i: int in 3:
		await tree.physics_frame
	assert_false(_game.call("is_in_dialogue"), "[ch2_volunteer] 不會又開對話")
	assert_false(bool(hall.call("is_door_open")), "[ch2_volunteer] 內室的門還關著")
	await _chapter2_inner(hall, see_through)


## 第 2 章段落 3（D-159）：走到內室的門前 → 伊薩推開門 → 內室（主椅、鐘盤、細管、暖光）→ 過場「妳剪頭髮了。」→ 彌夏走到黎歐旁邊 →
## 檢查點 ch2_inner → 牆上的紋路待續。兩條路線：看完整段過場／跳過（狀態一樣）。
func _chapter2_inner(hall: StoryLevel, watch: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(float(hall.get("mood")), 0.0, "還在飯廳：白光")
	await _step_into(_player(hall), (hall.get("INNER_DOOR_POS") as Vector3) + Vector3(0.0, 0.0, 1.2), 3)
	assert_eq(s.state.get_flag("ch2.inner_room_entered"), true, "走到內室的門前 → 進內室")
	assert_true(bool(hall.call("is_door_open")), "伊薩推開門")
	assert_true(bool(hall.call("is_in_inner_room")), "諾恩在內室裡")
	assert_eq(s.quests.stage_of("ch2_main"), "meet_leo")
	assert_true(_game.call("is_in_cutscene"), "→ 過場：黎歐")
	var cs: CutsceneRunner = _game.get("cutscene") as CutsceneRunner
	assert_eq(cs.id, "ch2_leo")
	assert_eq(float(hall.get("mood")), 1.0, "內室：暖光")
	await _assert_inner_room(hall, "[內室]")
	var misha: Node3D = hall.get_node("Misha") as Node3D
	var spots: Dictionary = hall.get("INNER_SPOTS") as Dictionary
	assert_true(misha.global_position.distance_to(spots["misha_door"] as Vector3) < 0.1, "彌夏站在門口，一步都沒有走")
	if watch:
		var lines: PackedStringArray = []
		var events: PackedStringArray = []
		cs.event_fired.connect(func(e: String, _shot: Dictionary) -> void: events.append(e))
		for i: int in 12:
			if not cs.is_running():
				break
			lines.append(str(cs.current().get("line", "")))
			cs.update(100.0)
		assert_true("CUT_CH2_LEO_002" in lines, "妳剪頭髮了。")
		assert_true("CUT_CH2_LEO_004" in lines, "魚是不是把那段吃掉了？")
		assert_eq(events, PackedStringArray(["misha_walk", "slap"]), "過場事件：彌夏走過去、一巴掌")
	else:
		cs.skip()
	await tree.process_frame
	assert_false(_game.call("is_in_cutscene"), "過場結束")
	assert_eq(s.state.get_flag("ch2.leo_met"), true)
	assert_true(misha.global_position.distance_to(spots["misha"] as Vector3) < 0.1, "過場之後彌夏在黎歐旁邊（跳過也一樣）")
	assert_eq(s.quests.stage_of("ch2_main"), "wall_carvings", "→ 牆上的紋路")
	assert_eq(s.state.checkpoint, "ch2_inner")
	hall = await _retry()
	assert_eq(str(hall.name), "BellHall", "[ch2_inner] 重來還在鐘院")
	assert_eq(_objective(hall), "Q_CH2_OBJ_CARVINGS", "[ch2_inner] HUD 目標")
	assert_true(bool(hall.call("is_in_inner_room")), "[ch2_inner] 在內室裡")
	assert_true(bool(hall.call("is_door_open")), "[ch2_inner] 門開著")
	assert_false(_game.call("is_in_cutscene"), "[ch2_inner] 不會又播過場")
	await _assert_bell_hall(hall, "[ch2_inner]")
	await _assert_inner_room(hall, "[ch2_inner]")
	assert_eq(int(hall.call("nearest_carving")), -1, "[ch2_inner] 不在浮雕前")
	# 走回飯廳：氣氛換回白光
	await _step_into(_player(hall), Vector3(0.0, 0.0, 1.5), 2)
	for i: int in 400:
		await tree.process_frame
		if float(hall.get("mood")) <= 0.0:
			break
	assert_eq(float(hall.get("mood")), 0.0, "走回飯廳 → 白光")
	await _chapter2_carvings(hall, watch)


## 第 2 章段落 4（D-160）：站在浮雕前按互動 → 伊薩解說那一塊、刻痕亮起來；4 塊都看完 → 諾恩的獨白 →
## 攻略筆記「焚城路線最快」被推翻 → 檢查點 ch2_carvings → 窗簾待續。兩條路線看的順序不一樣（最後一塊才接獨白）。
func _chapter2_carvings(hall: StoryLevel, reverse: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	var zs: Array = hall.get("CARVING_ZS") as Array
	var cx: float = float(hall.get("CARVING_X"))
	var order: Array[int] = [0, 1, 2, 3]
	if reverse:
		order = [3, 0, 2, 1]
	assert_ne(GuideNotes.status(s.state, "burn_route"), GuideNotes.WRONG, "還沒看紋路：攻略筆記照舊")
	for k: int in order.size():
		var i: int = order[k]
		await _step_into(_player(hall), Vector3(cx + 0.9, 0.0, float(zs[i])), 2)
		assert_eq(int(hall.call("nearest_carving")), i, "站在第 %d 塊浮雕前" % i)
		assert_eq(str((hall.call("interact_hint") as Dictionary).get("action", "")), "interact", "提示：按互動看牆上的紋路")
		assert_false(bool(hall.call("carving_lit", i)), "還沒看的刻痕是暗的")
		hall.call("read_carving", i)
		assert_true(_game.call("is_in_dialogue"), "看浮雕 → 伊薩解說（第 %d 塊）" % i)
		assert_true(bool(hall.call("carving_lit", i)), "看過的刻痕亮起來")
		if k < order.size() - 1:
			await _run_dialogue(hall, 0)
			await tree.process_frame
			await tree.process_frame
			assert_false(_game.call("is_in_dialogue"), "還沒看完 4 塊：不接獨白")
			assert_ne(s.state.get_flag("ch2.read_wall_carvings"), true, "還沒看完 4 塊：攻略筆記照舊")
	# 最後一塊的解說講完，下一幀接諾恩的獨白（_run_dialogue 會一路按完）
	var box: DialogueBox = hall.get_node("DialogueBox") as DialogueBox
	box.press_continue()
	await tree.process_frame
	await tree.process_frame
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	for i: int in 6:
		if runner != null and runner.current_text().begins_with("DLG_CH2_CARVE_END"):
			break
		box.press_continue()
		await tree.process_frame
		await tree.process_frame
		runner = _game.get("dialogue") as DialogueRunner
	assert_true(runner != null and runner.current_text() == "DLG_CH2_CARVE_END_1", "4 塊都看完 → 諾恩的獨白：我終於理解，自己的攻略為什麼那麼有效")
	await _run_dialogue(hall, 0)
	assert_eq(s.state.get_flag("ch2.read_wall_carvings"), true)
	assert_eq(GuideNotes.status(s.state, "burn_route"), GuideNotes.WRONG, "攻略筆記「焚城路線最快」被推翻（諾恩自己寫的那條）")
	assert_eq(s.quests.stage_of("ch2_main"), "curtain", "→ 問伊薩還有沒有別的辦法")
	assert_eq(s.state.checkpoint, "ch2_carvings")
	hall = await _retry()
	assert_eq(str(hall.name), "BellHall", "[ch2_carvings] 重來還在鐘院")
	assert_eq(_objective(hall), "Q_CH2_OBJ_CURTAIN", "[ch2_carvings] HUD 目標")
	assert_true(bool(hall.call("is_in_inner_room")), "[ch2_carvings] 在內室裡")
	for i: int in zs.size():
		assert_true(bool(hall.call("carving_lit", i)), "[ch2_carvings] 4 塊的刻痕都亮著")
	await _assert_inner_room(hall, "[ch2_carvings]")
	for i: int in 3:
		await tree.physics_frame
	assert_false(_game.call("is_in_dialogue"), "[ch2_carvings] 不會又開獨白")
	await _chapter2_curtain(hall, reverse)


## 第 2 章段落 5（D-161）：紋路看完伊薩在窗邊等 → 走到他旁邊 → 窗簾的對話（席菈「把人撤走。」；諾恩問毀掉鐘、地上的援軍，
## 兩條都被擋下才有「……」）→ 過場 ch2_eye（拉開窗簾、黑牆動了一下、眼睛睜開、瞳孔收窄）→ 第 2 章完成 → 待續。
## 兩條路線：問的順序不一樣＋看完整段過場／跳過（結果一樣）。
func _chapter2_curtain(hall: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	await _assert_window(hall, "[窗簾]", false)
	var at_window: Vector3 = hall.get("ISA_WINDOW") as Vector3
	var isa: Node3D = hall.get_node("Isa") as Node3D
	assert_true(_flat_dist(isa.global_position, at_window) < 0.1, "紋路看完：伊薩在窗邊等")
	assert_eq(_objective(hall), "Q_CH2_OBJ_CURTAIN")
	await _step_into(_player(hall), at_window + Vector3(-1.5, 0.0, -0.5), 3)
	assert_true(_game.call("is_in_dialogue"), "走到伊薩旁邊 → 窗簾的對話")
	assert_eq((_game.get("dialogue") as DialogueRunner).dialogue_id, "ch2_curtain")
	var most: int = await _run_dialogue(hall, 1 if alt else 0)
	assert_eq(most, 3, "諾恩想得到的辦法：毀掉鐘、地上的援軍，或什麼都不說（問過的就不再出現）")
	assert_eq(s.state.get_flag("ch2.plan_aid"), true, "問過援軍 →「援軍沒有來。」")
	# 另一條路線：問完援軍就沉默（「……」隨時可以選），毀掉鐘沒問
	assert_eq(s.state.get_flag("ch2.plan_break") == true, not alt, "毀掉鐘 →「深層的東西就會上來。」（沉默那條沒問）")
	assert_eq(s.state.get_flag("ch2.curtain_talked"), true)
	await tree.process_frame
	assert_true(_game.call("is_in_cutscene"), "→ 過場：伊薩拉開窗簾")
	var cs: CutsceneRunner = _game.get("cutscene") as CutsceneRunner
	assert_eq(cs.id, "ch2_eye")
	assert_true(bool(hall.call("is_curtain_open")), "第一個鏡頭：伊薩拉開窗簾")
	assert_eq(float(hall.get("eye_open")), 0.0, "剛拉開：只是一堵黑牆")
	if not alt:
		var lines: PackedStringArray = []
		var events: PackedStringArray = []
		cs.event_fired.connect(func(e: String, _shot: Dictionary) -> void: events.append(e))
		for i: int in 12:
			if not cs.is_running():
				break
			lines.append(str(cs.current().get("line", "")))
			cs.update(100.0)
		assert_true("CUT_CH2_EYE_004" in lines, "那是一隻眼睛，正在隔著屏障看我們。")
		assert_true("CUT_CH2_EYE_006" in lines, "最終章的災厄，吞日獸。")
		assert_eq(events, PackedStringArray(["wall_shift", "eye_open", "pupil"]), "過場事件：牆動了一下、眼睛睜開、瞳孔收窄")
	else:
		cs.skip()
	await tree.process_frame
	assert_false(_game.call("is_in_cutscene"), "過場結束")
	assert_eq(s.state.get_flag("ch2.curtain_opened"), true)
	assert_true(s.quests.is_done("ch2_main"), "第 2 章完成")
	assert_eq(s.state.get_flag("ch2.complete"), true)
	await _assert_window(hall, "[看過眼睛]", true)
	await _chapter3(hall, alt)


## 第 3 章（D-163）：章節卡 → 乾運河（斜光切成條、只有這裡有影子、吊樑下掛著胸口有鐘舌的送葬者）→ 走到岸邊 →
## 「我去引開牠。」→「不行。」／沉默 →「那你有什麼方案？」→ 攻略筆記多一條空白 →「牠跟著什麼走？」「心跳。」「多快？」→
## 檢查點 ch3_bank → 段落 2 待續。
func _chapter3(hall: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(s.main_quest(), "ch3_main", "第 2 章完成 → 主線換成第 3 章")
	assert_eq(s.state.chapter, "ch3", "章節換成 ch3")
	assert_eq(s.state.checkpoint, "ch3_start", "第 3 章的第一個檢查點")
	var card: ChapterCard = hall.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "看完眼睛 → 第 3 章章節卡")
	if card == null:
		return
	assert_eq(card.title_text(), tr("CH3_CARD_TITLE"), "章節卡的章名：不准替我答應")
	card.finish()
	var canal: StoryLevel = await _wait_scene()
	assert_eq(str(canal.name), "Canal", "章節卡之後換到乾運河")
	_assert_canal(canal, "[ch3_start]")
	await _assert_restore(canal, "[ch3_start]", [])
	assert_eq(s.state.get_flag("ch3.heard_noen", false), false, "[ch3_start] 送葬者還掛著：按住重現鍵牠也聽不到")
	canal = await _retry()
	assert_eq(str(canal.name), "Canal", "[ch3_start] 重來還在乾運河（第 2 章完成有自動存檔，不會回到窗簾之前）")
	assert_false(_game.call("is_in_cutscene"), "[ch3_start] 不會又播眼睛的過場")
	assert_eq(_objective(canal), "Q_CH3_OBJ_BANK", "[ch3_start] HUD 目標：走到岸邊")
	_assert_canal(canal, "[ch3_start] 重來")
	assert_false(_game.call("is_in_dialogue"), "還沒走到岸邊")
	await _step_into(_player(canal), canal.get("BANK_POS") as Vector3 + Vector3(0.4, 0.0, 0.6), 3)
	assert_true(_game.call("is_in_dialogue"), "走到岸邊 → 對話")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	assert_eq(runner.dialogue_id, "ch3_bank")
	var lines: PackedStringArray = []
	for i: int in 6:
		if not runner.is_running() or runner.visible_choices.size() > 0:
			break
		lines.append(runner.current_text())
		runner.advance()
	assert_true("DLG_CH3_BANK_004" in lines, "鐘舌：鐘裡面那根撞鐘的鐵棒（第一次出現時說明）")
	assert_eq(runner.current_text(), "DLG_CH3_BANK_005", "我去引開牠。")
	assert_eq(runner.visible_choices.size(), 2, "選項只有「不行。」與沉默")
	var most: int = await _run_dialogue(canal, 1 if alt else 0)
	assert_eq(most, 2)
	assert_eq(s.state.get_flag("ch3.refused_lure"), not alt, "「不行。」記 ch3.refused_lure")
	assert_eq(s.state.get_flag("ch3.bank_talked"), true)
	assert_eq(GuideNotes.status(s.state, "clapper_heartbeat"), GuideNotes.BLANK, "攻略筆記：這一條是空白（攻略沒有寫）")
	assert_eq(s.quests.stage_of("ch3_main"), "observe", "→ 段落 2 觀察")
	assert_eq(s.state.checkpoint, "ch3_bank", "檢查點 ch3_bank")
	assert_eq((canal.get_node("Hud") as Hud).banner_text(), "GUIDE_BLANK_NOTE", "提示：攻略筆記這一條是空白")
	canal = await _retry()
	assert_eq(str(canal.name), "Canal", "[ch3_bank] 重來還在乾運河")
	assert_eq(_objective(canal), "Q_CH3_OBJ_OBSERVE", "[ch3_bank] HUD 目標：看清楚牠跟著什麼走")
	assert_eq(GuideNotes.status(s.state, "clapper_heartbeat"), GuideNotes.BLANK, "[ch3_bank] 空白條目有存到")
	await _step_into(_player(canal), canal.get("BANK_POS") as Vector3, 3)
	assert_false(_game.call("is_in_dialogue"), "[ch3_bank] 岸邊的對話不會再開")
	_assert_canal(canal, "[ch3_bank]")
	await _chapter3_observe(canal, alt)


## 第 3 章段落 2（D-164）：走進岸邊的水溝 → 三個人趴下 → 席菈隔著銅片敲，玩家選節奏（試過的消失）→
## 送葬者照 RhythmTrial 反應（不動／偏頭／轉頭）→ 不快不慢（人的心跳）→ 轉頭 →「就是這個速度。」→
## 攻略筆記的空白條目變成證實 → 站起來 → 檢查點 ch3_rhythm → 段落 3 待續。
## 主路線：慢一點（偏頭）→ 不快不慢（轉頭）；另一條：忽快忽慢（不動）→ 很快（不動）→ 快一點（偏頭）→ 不快不慢。
func _chapter3_observe(canal: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(s.quests.stage_of("ch3_main"), "observe")
	assert_true(canal.has_node("Drain") and canal.has_node("Drain/CopperPlate"), "岸邊有一道水溝、前端插著銅片")
	var player: PlayerController = _player(canal)
	await _step_into(player, canal.get("DRAIN_POS") as Vector3, 3)
	assert_true(_game.call("is_in_dialogue"), "走進水溝 → 開始觀察")
	assert_true(canal.call("is_lying", player), "諾恩趴在水溝裡")
	assert_true(canal.call("is_lying", canal.get_node("Sheila")), "席菈也趴著")
	assert_true(canal.call("is_lying", canal.get_node("Misha")), "彌夏也趴著")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	assert_eq(runner.dialogue_id, "ch3_rhythm")
	for i: int in 6:
		if runner.visible_choices.size() > 0:
			break
		runner.advance()
	assert_eq(runner.current_text(), "DLG_CH3_RHY_HUB", "席菈：多快？")
	assert_eq(runner.visible_choices.size(), RhythmTrial.ORDER.size(), "六種節奏可以選")
	var route: PackedStringArray = ["irregular", "very_fast", "fast", "steady"] if alt else ["slow", "steady"]
	var left: int = RhythmTrial.ORDER.size()
	for tempo: String in route:
		var pick: int = -1
		for i: int in runner.visible_choices.size():
			if str(runner.visible_choices[i]["text"]) == "DLG_CH3_RHY_C_" + tempo.to_upper():
				pick = i
		assert_true(pick >= 0, "選項裡有「%s」" % tempo)
		runner.choose(pick)
		assert_eq(runner.current_text(), "DLG_CH3_RHY_KNOCK", "席菈開始敲（%s）" % tempo)
		var want: String = RhythmTrial.reaction(tempo)
		assert_eq(str(canal.get("last_reaction")), want, "送葬者的反應照判定：%s → %s" % [tempo, want])
		assert_eq(s.state.get_flag("ch3.react"), want, "反應寫進 ch3.react")
		await tree.process_frame
		runner.advance()
		var react_key: String = str({"turn": "DLG_CH3_RHY_TURN", "tilt": "DLG_CH3_RHY_TILT"}.get(want, "DLG_CH3_RHY_IRREGULAR" if tempo == "irregular" else "DLG_CH3_RHY_STILL"))
		assert_eq(runner.current_text(), react_key, "旁白照反應換（%s）" % tempo)
		canal.call("skip_reaction")
		if want == RhythmTrial.TURN:
			assert_true(absf(float(canal.call("torso_turn_deg"))) > 30.0, "轉頭：上半身轉向銅片，停在那裡")
			assert_eq(float(canal.get("heart_bpm")), RhythmTrial.TARGET_BPM, "轉頭之後胸口的銅光跟著敲的速度亮")
			assert_eq(runner.visible_choices.size(), 2, "轉頭之後：就是這個速度／再試一次")
			assert_eq(str(runner.visible_choices[0]["text"]), "DLG_CH3_RHY_C_THIS", "就是這個速度。")
			runner.choose(0)
			break
		assert_eq(runner.visible_choices.size(), 1, "沒轉頭：只能再試一次")
		assert_eq(str(runner.visible_choices[0]["text"]), "DLG_CH3_RHY_C_AGAIN")
		assert_true(absf(float(canal.call("torso_turn_deg"))) < 1.0, "沒有轉頭（%s）" % tempo)
		assert_eq(float(canal.get("heart_bpm")), float(canal.get("HEART_BPM")), "沒轉頭：銅光照自己的速度（%s）" % tempo)
		runner.choose(0)
		left -= 1
		assert_eq(runner.visible_choices.size(), left, "試過的節奏從選項消失")
		assert_eq(runner.current_text(), "DLG_CH3_RHY_HUB3" if int(s.state.get_flag("ch3.rhythm_tries", 0)) >= 3 else "DLG_CH3_RHY_HUB2", "席菈：再一次。多快？")
	assert_eq(s.state.get_flag("ch3.rhythm_tries"), route.size(), "試了幾次有記下來")
	for i: int in 8:
		if not runner.is_running():
			break
		runner.advance()
	await tree.process_frame
	assert_false(_game.call("is_in_dialogue"), "觀察結束")
	assert_eq(s.state.get_flag("ch3.rhythm_found"), true, "找到速度")
	assert_eq(GuideNotes.status(s.state, "clapper_heartbeat"), GuideNotes.CONFIRMED, "攻略筆記：空白條目變成證實（自己看到的）")
	assert_false(canal.call("is_lying", player), "看完站起來")
	assert_false(canal.call("is_lying", canal.get_node("Sheila")), "席菈也站起來")
	assert_eq(s.quests.stage_of("ch3_main"), "decoy", "→ 段落 3 假心臟")
	assert_eq(s.state.checkpoint, "ch3_rhythm", "檢查點 ch3_rhythm")
	assert_eq((canal.get_node("Hud") as Hud).banner_text(), "GUIDE_SELF_NOTE", "提示：攻略筆記自己寫下一條")
	canal = await _retry()
	assert_eq(str(canal.name), "Canal", "[ch3_rhythm] 重來還在乾運河")
	assert_eq(_objective(canal), "Q_CH3_OBJ_DECOY", "[ch3_rhythm] HUD 目標：彌夏照那個速度做假心臟")
	assert_eq(GuideNotes.status(s.state, "clapper_heartbeat"), GuideNotes.CONFIRMED, "[ch3_rhythm] 證實有存到")
	await _step_into(_player(canal), canal.get("DRAIN_POS") as Vector3, 3)
	assert_false(_game.call("is_in_dialogue"), "[ch3_rhythm] 水溝的觀察不會再開")
	_assert_canal(canal, "[ch3_rhythm]")
	await _chapter3_decoy(canal, alt)


## 段落 3 假心臟（D-165）：彌夏交出假心臟 → 東岸三個點一段一段垂下去，把送葬者引進閘道 → 檢查點 ch3_lured → 段落 4 待續。
## alt：先垂在第 1 點（太遠，牠聽不到）；牠醒過來之後按住重現鍵 → 牠停下來轉向諾恩。
func _chapter3_decoy(canal: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	assert_eq(s.quests.stage_of("ch3_main"), "decoy")
	canal.set("_decoy_wait", 0.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(_game.call("is_in_dialogue"), "找到速度之後、彌夏在旁邊 → 她交出假心臟")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	assert_eq(runner.dialogue_id, "ch3_decoy_make")
	for i: int in 10:
		if not runner.is_running():
			break
		runner.advance()
	await tree.process_frame
	assert_false(_game.call("is_in_dialogue"), "彌夏說完")
	assert_eq(s.quests.stage_of("ch3_main"), "lure", "→ 把假心臟垂下去，引進閘道")
	assert_eq(s.state.checkpoint, "ch3_decoy", "檢查點 ch3_decoy")
	if not alt:
		canal = await _retry()
		assert_eq(str(canal.name), "Canal", "[ch3_decoy] 重來還在乾運河")
		assert_eq(_objective(canal), "Q_CH3_OBJ_LURE", "[ch3_decoy] HUD 目標：把假心臟垂下去")
		_assert_canal(canal, "[ch3_decoy]")
	assert_true(canal.has_node("DecoySpot0") and canal.has_node("DecoySpot2"), "東岸有三個放假心臟的點")
	assert_false(bool(canal.get("awake")), "還掛在吊樑下")
	var hud: Hud = canal.get_node("Hud") as Hud
	var player: PlayerController = _player(canal)
	if alt:
		await _step_into(player, Vector3(canal.get("DECOY_BANK_X"), 0.0, (canal.get("DECOY_ZS") as PackedFloat32Array)[1]), 2)
		assert_eq(int(canal.call("nearest_spot")), 1, "站在第 1 點旁邊")
		assert_eq(str((canal.call("interact_hint") as Dictionary).get("fmt", "")), str(TranslationServer.translate("CH3_DECOY_LOWER_HINT")), "提示：把假心臟垂下去")
		canal.call("use_spot", 1)
		assert_eq(int(canal.get("heart_spot")), 1, "垂在第 1 點")
		assert_false(bool(canal.get("awake")), "第 1 點太遠：牠聽不到、不會動")
		assert_eq(hud.banner_text(), "CH3_DECOY_TOO_FAR", "提示：太遠了，牠聽不到")
		assert_false(bool(canal.call("spot_actionable", 0)), "假心臟垂著的時候，別的點不能放")
		canal.call("use_spot", 1)
		assert_eq(int(canal.get("heart_spot")), -1, "收上來")
	canal.set("walk_scale", 6.0)
	canal.call("use_spot", 0)
	assert_true(bool(canal.get("awake")), "第 0 點聽得到：鏈子鬆開")
	assert_eq(hud.banner_text(), "CH3_DECOY_WOKE")
	var u: Node3D = canal.call("undertaker") as Node3D
	canal.call("finish_drop")
	assert_true(absf(u.global_position.y - float(canal.get("BED_Y"))) < 0.01, "掉到河床上")
	assert_false(u.is_in_group("enemies"), "牠不是來打的：還是不在敵人名單裡")
	if alt:
		await _step_into(player, Vector3(canal.get("DECOY_BANK_X"), 0.0, (canal.get("DECOY_ZS") as PackedFloat32Array)[0]), 2)
		canal.set("force_restoring", true)
		var before: Vector3 = u.global_position
		for i: int in 6:
			await tree.physics_frame
		assert_eq(str(canal.get("follow_kind")), HeartTargets.NOEN, "按住重現：牠轉向諾恩")
		assert_true(Vector2(u.global_position.x - before.x, u.global_position.z - before.z).length() < 0.01, "轉向諾恩時停下來，不往假心臟走")
		assert_eq(s.state.get_flag("ch3.heard_noen"), true)
		assert_eq(hud.banner_text(), "CH3_HEARS_NOEN", "提示：重現時心跳變快，牠聽得到")
		assert_true(Game.restore_mix.sources_active(), "[ch3_decoy] 按住重現：其他聲音悶下去、只剩心跳（D-183）")
		canal.set("force_restoring", false)
		assert_false(Game.restore_mix.sources_active(), "[ch3_decoy] 放開就恢復")
	for spot: int in 3:
		if spot > 0:
			assert_true(bool(canal.call("spot_actionable", spot)), "第 %d 點可以放" % spot)
			canal.call("use_spot", spot)
		assert_eq(int(canal.get("heart_spot")), spot)
		for i: int in 240:
			if (canal.get("reached") as Array)[spot] or s.quests.stage_of("ch3_main") != "lure":
				break
			await tree.physics_frame
		assert_true(bool((canal.get("reached") as Array)[spot]), "牠走到第 %d 點旁邊、停下來聽" % spot)
		if s.quests.stage_of("ch3_main") != "lure":
			break
		assert_eq(str(canal.get("follow_kind")), HeartTargets.DECOY, "牠跟著假心臟")
		assert_false(bool(canal.call("spot_actionable", spot + 1)), "假心臟還垂在第 %d 點：要先收上來" % spot)
		canal.call("use_spot", spot)
	assert_eq(s.state.get_flag("ch3.decoy_done"), true, "牠進了閘道")
	assert_true(u.global_position.z <= float(canal.get("SLUICE_REACH_Z")), "送葬者走到閘道口")
	assert_eq(s.quests.stage_of("ch3_main"), "coal_cart", "→ 段落 4 煤車")
	assert_eq(s.state.checkpoint, "ch3_lured", "檢查點 ch3_lured")
	assert_eq(hud.banner_text(), "CH3_LURED_NOTE")
	canal = await _retry()
	assert_eq(str(canal.name), "Canal", "[ch3_lured] 重來還在乾運河")
	assert_eq(_objective(canal), "Q_CH3_OBJ_CART", "[ch3_lured] HUD 目標：煤車")
	var u2: Node3D = canal.call("undertaker") as Node3D
	assert_true(bool(canal.get("awake")), "[ch3_lured] 牠已經在河床上")
	assert_true(u2.global_position.z <= float(canal.get("SLUICE_REACH_Z")) and absf(u2.global_position.y - float(canal.get("BED_Y"))) < 0.01, "[ch3_lured] 站在閘道口")
	await _chapter3_cart(canal, alt)


## 段落 4 煤車（D-166）：抬頭看見閘道上面的煤車（對話）→ 把假心臟垂到閘道另一邊 → 牠從煤車底下走過去 → 站在繩子旁割斷 →
## 壓住 → 檢查點 ch3_pinned → 段落 5 倒吊（_chapter3_hang）。alt：先割太早（牠掙脫、爬上岸 → 掙脫戰打到跪下 → 回到 ch3_lured、
## 不再重講對話，D-169），再按住重現讓牠停在正下方割；
## 否則看牠走路的時機割（提早 FALL_SEC 秒的路程）。
func _chapter3_cart(canal: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	canal.set("_cart_talk_wait", 0.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(_game.call("is_in_dialogue"), "[ch3_lured] 抬頭看見閘道上的煤車")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	assert_eq(runner.dialogue_id, "ch3_cart_plan")
	for i: int in 10:
		if not runner.is_running():
			break
		runner.advance()
	await tree.process_frame
	assert_false(_game.call("is_in_dialogue"), "煤車的對話講完")
	assert_eq(s.state.get_flag("ch3.cart_planned"), true)
	assert_true(canal.has_node("CoalCart") and canal.has_node("DecoySpot3") and canal.has_node("CartRopeLine"), "閘道上有煤車和繩子、另一邊有放心臟的點")
	var sluice_lamp: OmniLight3D = canal.call("sluice_lamp") as OmniLight3D
	assert_true(sluice_lamp != null and sluice_lamp.shadow_enabled, "閘道木架下掛著一盞投影子的小油燈")
	var player: PlayerController = _player(canal)
	var spot3: Vector3 = (canal.get_node("DecoySpot3") as Node3D).global_position
	var rope_pos: Vector3 = canal.get("ROPE_POS") as Vector3
	var guide: Vector3 = ObjectiveGuide.resolve_target(canal, s.quests.marker_spec("ch3_main"), player.global_position)
	assert_true(Vector2(guide.x - spot3.x, guide.z - spot3.z).length() < 0.01, "目標指引：假心臟在手上 → 閘道另一邊的點")
	assert_false(bool(canal.call("spot_actionable", 0)), "段落 4 只用閘道兩邊的點")
	if alt:
		canal.call("use_spot", 3)
		await _step_into(player, rope_pos, 2)
		canal.set("fail_retry_sec", 0.05)
		canal.call("cut_rope")
		assert_eq(str(canal.get("cut_result")), CoalDrop.EARLY, "牠還在閘道口就割：太早")
		canal.call("finish_cut")
		assert_eq((canal.get_node("Hud") as Hud).banner_text(), "CH3_CART_EARLY", "提示：太早了，牠掙脫了")
		assert_eq(s.quests.stage_of("ch3_main"), "coal_cart", "沒壓住：還在段落 4")
		# 掙脫戰（D-169）：爬上東岸 → 變回敵人（少一招、不會進第二階段）→ 打到失衡跪下 → 撞回運河 → 回到 ch3_lured
		var freed: Undertaker = canal.call("undertaker") as Undertaker
		canal.call("finish_climb")
		assert_true(bool(canal.get("struggling")), "掙脫戰開始")
		assert_eq((canal.get_node("Hud") as Hud).banner_text(), "CH3_STRUGGLE_START", "提示：牠爬上岸了，打到牠跪下")
		assert_eq((canal.get_node("Hud") as Hud).objective_text_key(), "CH3_STRUGGLE_OBJ", "目標換成：跟席菈一起把牠打到跪下")
		assert_true(absf(freed.global_position.y) < 0.05 and freed.global_position.x > float(canal.get("CANAL_HALF_W")), "站在東岸上")
		assert_true(Vector2(freed.global_position.x - player.global_position.x, freed.global_position.z - player.global_position.z).length() >= float(canal.get("STRUGGLE_MIN_GAP")) - 0.5, "沒有直接落在諾恩臉上")
		assert_true(freed.is_in_group("enemies") and freed.is_in_group("damageable"), "變回敵人：席菈會打、諾恩打得到")
		assert_true(freed.is_physics_processing() and freed.can_process(), "自己的戰鬥邏輯在跑")
		assert_false(freed.brain.pattern.has("charge"), "少一招：沒有衝撞")
		var misha: Node3D = canal.get_node("Misha") as Node3D
		var hide0: Vector3 = canal.call("misha_hide_spot", player.global_position, freed.global_position) as Vector3
		var misha_far: float = Vector2(misha.global_position.x - hide0.x, misha.global_position.z - hide0.z).length()
		for i: int in 20:
			await tree.physics_frame
		assert_true(freed.brain.state != EnemyBrain.State.IDLE, "牠盯上了心跳（%s）" % freed.brain.state_name())
		assert_eq(freed.phase, 1, "還是第一階段")
		var hide: Vector3 = canal.call("misha_hide_spot", player.global_position, freed.global_position) as Vector3
		assert_true(Vector2(misha.global_position.x - hide.x, misha.global_position.z - hide.z).length() < misha_far - 0.3, "彌夏往諾恩背後躲")
		canal.set("kneel_hold_sec", 0.0)
		canal.set("push_sec", 0.05)
		canal.set("fail_retry_sec", 0.05)
		freed.brain.force_kneel(2.0)
		await tree.physics_frame
		await tree.physics_frame
		assert_true(bool(canal.get("struggle_won")) and not bool(canal.get("struggling")), "打到失衡跪下：掙脫戰結束")
		assert_false(freed.is_in_group("enemies"), "跪下之後不再是敵人（席菈停手）")
		assert_eq((canal.get_node("Hud") as Hud).banner_text(), "CH3_STRUGGLE_KNEEL", "提示：席菈把牠撞回運河")
		assert_eq((canal.get_node("Hud") as Hud).objective_text_key(), s.objective_key(), "打贏：目標換回煤車那一句")
		for i: int in 240:
			await tree.process_frame
			if _level() != canal:
				break
		canal = await _wait_scene()
		assert_eq(str(canal.name), "Canal", "[ch3_lured] 掙脫戰打贏 → 重來還在乾運河")
		assert_eq(s.state.checkpoint, "ch3_lured", "[ch3_lured] 回到段落 3 的檢查點")
		assert_false(bool(canal.get("cart_cut")), "[ch3_lured] 煤車回到原位")
		assert_false(bool(canal.get("struggling")) or bool(canal.get("struggle_won")), "[ch3_lured] 重來不在掙脫戰裡")
		assert_false((canal.call("undertaker") as Node).is_in_group("enemies"), "[ch3_lured] 牠又只是跟著心跳走")
		assert_true(float(canal.get("_cart_talk_wait")) < 0.0, "[ch3_lured] 失敗重來不再重講一次")
		assert_eq((canal.get_node("Hud") as Hud).banner_text(), "CH3_STRUGGLE_RESET", "[ch3_lured] 提示：煤車重新裝好了，再來一次")
		player = _player(canal)
	var u: Node3D = canal.call("undertaker") as Node3D
	canal.call("use_spot", 3)
	assert_eq(int(canal.get("heart_spot")), 3, "垂在閘道另一邊")
	await _step_into(player, rope_pos, 2)
	guide = ObjectiveGuide.resolve_target(canal, s.quests.marker_spec("ch3_main"), player.global_position)
	assert_true(Vector2(guide.x - rope_pos.x, guide.z - rope_pos.z).length() < 0.01, "目標指引：心臟垂下去了 → 繩子")
	assert_true(bool(canal.call("near_rope")), "站在繩子旁邊")
	assert_eq(str((canal.call("interact_hint") as Dictionary).get("fmt", "")), str(TranslationServer.translate("CH3_CART_CUT_HINT")), "提示：割斷繩子")
	canal.set("walk_scale", 2.0)
	var cart_z: float = float(canal.get("CART_Z"))
	var ready_to_cut: bool = false
	for i: int in 400:
		await tree.physics_frame
		var vz: float = float(canal.get("walk_vz"))
		if alt:
			if absf(u.global_position.z - cart_z) < 0.3:
				canal.set("force_restoring", true)
				for k: int in 3:
					await tree.physics_frame
				assert_eq(str(canal.get("follow_kind")), HeartTargets.NOEN, "在煤車下面按住重現：牠停下來轉向諾恩")
				assert_eq(float(canal.get("walk_vz")), 0.0, "停著")
				ready_to_cut = true
				break
		elif absf(CoalDrop.landing_z(u.global_position.z, signf(vz), absf(vz)) - cart_z) < 0.3:
			assert_true(vz < 0.0, "牠正往北走進閘道")
			ready_to_cut = true
			break
	assert_true(ready_to_cut, "牠走到煤車底下")
	assert_true(absf(u.global_position.x) <= float(canal.get("SLUICE_HALF")) + 0.01 or absf(u.global_position.z - cart_z) > float(canal.get("SLUICE_PIER_HALF_Z")), "從閘道石牆中間走過去")
	canal.call("cut_rope")
	assert_eq(str(canal.get("cut_result")), CoalDrop.PINNED, "時機對：壓住")
	canal.call("finish_cut")
	canal.set("force_restoring", false)
	assert_true(bool(canal.get("pinned")), "煤壓住了牠")
	assert_true(u.global_position.y < float(canal.get("BED_Y")), "陷進煤堆")
	assert_true((canal.get_node("CoalHeap") as Node3D).visible, "閘道裡一堆煤")
	assert_true(canal.has_node("CoalDust"), "黑色粉塵")
	assert_eq(ParticleLook.untextured(canal), [] as Array[String], "粉塵是柔邊圓點")
	assert_eq(s.state.get_flag("ch3.cart_dropped"), true)
	assert_eq(s.quests.stage_of("ch3_main"), "hang", "→ 段落 5 倒吊")
	assert_eq(s.state.checkpoint, "ch3_pinned", "檢查點 ch3_pinned")
	assert_eq((canal.get_node("Hud") as Hud).banner_text(), "CH3_CART_PINNED")
	canal = await _retry()
	assert_eq(str(canal.name), "Canal", "[ch3_pinned] 重來還在乾運河")
	assert_eq(_objective(canal), "Q_CH3_OBJ_HANG", "[ch3_pinned] HUD 目標：煤壓住了牠")
	assert_true(bool(canal.get("pinned")), "[ch3_pinned] 牠還被壓著")
	assert_true((canal.get_node("CoalHeap") as Node3D).visible and not (canal.get_node("CartRopeLine") as Node3D).visible, "[ch3_pinned] 煤堆還在、繩子斷了")
	await _chapter3_hang(canal, alt)


## 段落 5 倒吊（D-167）：走到東岸抓繩子的地方 → 對話 ch3_hang_plan → 按住拉住＋左右修正 → 抓到鐘舌、煤堆塌了
## → 三個人摔進泥裡（仰躺）→ 對話 ch3_hang_end → 日記「乾運河的泥」→ 檢查點 ch3_clapper → 段落 6 待續。
## alt：先放開（切不到）、再按住但不修正（撞到鐵架），最後才穩住。
func _chapter3_hang(canal: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	var player: PlayerController = _player(canal)
	var hang_spot: Vector3 = canal.get("HANG_SPOT") as Vector3
	var guide: Vector3 = ObjectiveGuide.resolve_target(canal, s.quests.marker_spec("ch3_main"), player.global_position)
	assert_true(Vector2(guide.x - hang_spot.x, guide.z - hang_spot.z).length() < 0.01, "目標指引：東岸抓繩子的地方")
	await _step_into(player, hang_spot, 2)
	assert_true(bool(canal.call("near_hang_spot")), "站在抓繩子的地方")
	assert_eq(str((canal.call("interact_hint") as Dictionary).get("fmt", "")), str(TranslationServer.translate("CH3_HANG_GRAB_HINT")), "提示：抓住席菈的繩子")
	canal.call("grab_hang_rope")
	await tree.process_frame
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	assert_true(_game.call("is_in_dialogue"), "抓繩子之前先講一段")
	assert_eq(runner.dialogue_id, "ch3_hang_plan")
	for i: int in 10:
		if not runner.is_running():
			break
		runner.advance()
	await tree.process_frame
	assert_true(bool(canal.get("hang_active")), "倒吊開始")
	assert_true(player.held_in_place, "諾恩站著抓繩子，不會走掉")
	var ally: Node3D = canal.get_node("Sheila") as Node3D
	assert_true(ally.global_basis.y.y < -0.9, "席菈倒過來、頭朝下")
	var head: Vector3 = ally.global_position + ally.global_basis.y * 1.7
	var clapper: Vector3 = (canal.call("clapper_light") as Node3D).global_position
	assert_true(head.distance_to(clapper) < 1.2, "她的頭在鐘舌附近（差 %.2f m）" % head.distance_to(clapper))
	var hang: HangRope = canal.get("hang") as HangRope
	var dt: float = 1.0 / 60.0
	if alt:
		for i: int in 120:
			canal.call("hang_tick", dt, false, 0.0)
		assert_eq(hang.progress, 0.0, "沒按住：切不到")
		for i: int in 60 * 8:
			canal.call("hang_tick", dt, true, 0.0)
		assert_true(hang.bumps >= 1, "按住但不修正：撞到鐵架")
		assert_false(hang.done, "撞來撞去還沒切完")
		assert_eq(str((canal.call("interact_hint") as Dictionary).get("fmt", "")), str(TranslationServer.translate("CH3_HANG_HOLD_HINT")), "提示：按住拉住、左右修正")
	var sway_seen: float = 0.0
	for i: int in 60 * 20:
		if not bool(canal.get("hang_active")):
			break
		canal.call("hang_tick", dt, true, HangRope.counter_steer(hang))
		sway_seen = maxf(sway_seen, absf((canal.get_node("HangPivot5") as Node3D).rotation.z))
	assert_true(hang.done, "穩住：切開了")
	assert_true(sway_seen > 0.01, "繩子跟著擺")
	assert_true(bool(canal.get("clapper_taken")), "抓到鐘舌")
	assert_false((canal.call("clapper_light") as Node3D).visible, "牠胸口不亮了")
	assert_true(canal.has_node("CoalDust"), "煤堆塌了：粉塵")
	canal.call("finish_collapse")
	await tree.process_frame
	assert_true(_game.call("is_in_dialogue"), "摔進泥裡")
	runner = _game.get("dialogue") as DialogueRunner
	assert_eq(runner.dialogue_id, "ch3_hang_end")
	assert_true(bool(canal.call("is_on_back", player)) and bool(canal.call("is_on_back", ally)) and bool(canal.call("is_on_back", canal.get_node("Misha"))), "三個人一起仰躺在泥裡")
	assert_true(ally.global_basis.y.y > 0.9, "席菈翻回來了")
	assert_false(player.held_in_place, "放開繩子")
	for i: int in 10:
		if not runner.is_running():
			break
		runner.advance()
	await tree.process_frame
	assert_false(_game.call("is_in_dialogue"), "講完")
	assert_false(bool(canal.call("is_on_back", player)), "站起來")
	assert_eq(s.state.get_flag("ch3.clapper_taken"), true)
	var journal: Journal = Journal.load_default()
	assert_true(journal.visible_ids(s.state).has("ch3_first_laugh"), "日記多一條：乾運河的泥")
	assert_eq(s.quests.stage_of("ch3_main"), "misha_map", "→ 段落 6 彌夏的圖")
	assert_eq(s.state.checkpoint, "ch3_clapper", "檢查點 ch3_clapper")
	canal = await _retry()
	assert_eq(str(canal.name), "Canal", "[ch3_clapper] 重來還在乾運河")
	assert_eq(_objective(canal), "Q_CH3_OBJ_MAP", "[ch3_clapper] HUD 目標：彌夏有話要說")
	assert_true(bool(canal.get("clapper_taken")) and bool(canal.get("pinned")), "[ch3_clapper] 鐘舌拿到了、牠還壓在煤下")
	assert_false((canal.call("clapper_light") as Node3D).visible, "[ch3_clapper] 胸口不亮")
	await _chapter3_map(canal, alt)


## 段落 6 彌夏的圖（D-167）：回程往南走 → 彌夏拉住諾恩（對話 ch3_misha_map）→ 收下／不收（都會被塞進手裡，記 ch3.map_accepted）
## → 檢查點 ch3_map → 段落 7 轉角待續。alt：不收。
func _chapter3_map(canal: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	var player: PlayerController = _player(canal)
	var trigger_z: float = float(canal.get("MAP_TRIGGER_Z"))
	assert_true(player.global_position.z < trigger_z, "[ch3_clapper] 站在摔倒的地方（還沒往回走）")
	assert_false(_game.call("is_in_dialogue"), "還沒開始講")
	await _step_into(player, Vector3(player.global_position.x, 0.0, trigger_z + 0.6), 2)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(_game.call("is_in_dialogue"), "往回走：彌夏拉住我")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	assert_eq(runner.dialogue_id, "ch3_misha_map")
	for i: int in 20:
		if not runner.is_running():
			break
		if not runner.visible_choices.is_empty():
			runner.choose(1 if alt else 0)
		else:
			runner.advance()
	await tree.process_frame
	assert_false(_game.call("is_in_dialogue"), "講完")
	assert_eq(s.state.get_flag("ch3.map_accepted"), not alt, "收下／不收記下來")
	assert_eq(s.state.get_flag("ch3.misha_map_given"), true, "圖都會被塞進手裡")
	assert_eq(s.quests.stage_of("ch3_main"), "corner", "→ 段落 7 轉角")
	assert_eq(s.state.checkpoint, "ch3_map", "檢查點 ch3_map")
	assert_true(bool(canal.get("misha_gone")), "彌夏交完圖先走了")
	assert_true(bool(canal.call("is_sheila_waiting")), "席菈先走到轉角等")
	canal = await _retry()
	assert_eq(_objective(canal), "Q_CH3_OBJ_CORNER", "[ch3_map] HUD 目標：席菈在轉角等我")
	await tree.process_frame
	assert_false((canal.get_node("Misha") as Node3D).visible, "[ch3_map] 彌夏已經走了")
	assert_true(bool(canal.call("is_sheila_waiting")), "[ch3_map] 席菈在轉角等")
	await _chapter3_corner(canal, alt)


## 段落 7 轉角（D-168）：往南走，席菈在牆角的另一邊等 → 對話 ch3_corner（是我敲的鐘／不說話；不敢動／我沒有鬆手；
## 第 1 章替她拿過湯匙的話最後一句不同）→ 日記多一條「轉角的衣領」→ ch3.corner_talked → 第 3 章完成（自動存檔）→ 結尾卡。
## alt：兩題都選第二個選項（湯匙、圖的那兩句照前面的旗標檢查）。
func _chapter3_corner(canal: StoryLevel, alt: bool) -> void:
	var s: GameSession = _game.get("session") as GameSession
	var player: PlayerController = _player(canal)
	var wait: Vector3 = canal.get("CORNER_WAIT") as Vector3
	var ally: Node3D = canal.get_node("Sheila") as Node3D
	assert_true(Vector2(ally.global_position.x - wait.x, ally.global_position.z - wait.z).length() < 0.6, "[ch3_map] 席菈站在轉角")
	assert_true(player.global_position.z < float(canal.get("CORNER_WALL_Z")) - 10.0, "[ch3_map] 諾恩還在拿到圖的地方")
	var guide: Vector3 = ObjectiveGuide.resolve_target(canal, s.quests.marker_spec("ch3_main"), player.global_position)
	assert_true(Vector2(guide.x - ally.global_position.x, guide.z - ally.global_position.z).length() < 0.01, "目標指引：席菈")
	assert_true(canal.has_node("CornerWall") and canal.call("corner_lamp") != null, "牆角與小油燈")
	var lamp: OmniLight3D = canal.call("corner_lamp") as OmniLight3D
	assert_true(lamp.light_color.r > lamp.light_color.b, "牆角的燈是暖色")
	await _step_into(player, Vector3(5.4, 0.0, float(canal.get("CORNER_WALL_Z")) - 6.0), 2)
	assert_false(_game.call("is_in_dialogue"), "還沒走到")
	await _step_into(player, Vector3(5.6, 0.0, float(canal.get("CORNER_WALL_Z")) - 0.3), 2)
	await tree.physics_frame
	assert_true(_game.call("is_in_dialogue"), "走到轉角：開始講")
	var runner: DialogueRunner = _game.get("dialogue") as DialogueRunner
	assert_eq(runner.dialogue_id, "ch3_corner")
	assert_true((canal.get_node("CornerCam") as Camera3D).current, "換成對話的固定鏡頭")
	var gap_before: float = float(canal.call("sheila_gap"))
	var saw_refused: bool = false
	var saw_soup: bool = false
	var closest: float = INF
	for i: int in 30:
		if not runner.is_running():
			break
		var key: String = runner.current_text()
		if key == "DLG_CH3_CORNER_003_REFUSED":
			saw_refused = true
		if key == "DLG_CH3_CORNER_013_SOUP":
			saw_soup = true
		if key == "DLG_CH3_CORNER_007":
			for f: int in 30:
				await tree.process_frame
			closest = float(canal.call("sheila_gap"))
		if not runner.visible_choices.is_empty():
			runner.choose(1 if alt else 0)
		else:
			runner.advance()
	assert_eq(saw_refused, s.state.get_flag("ch3.map_accepted") == false, "不收圖的話，「我沒回答」那句不一樣")
	assert_eq(saw_soup, s.state.get_flag("ch1.sheila_soup_helped") == true, "第 1 章替她拿過湯匙：「上次是一支湯匙，這次是主椅。」")
	assert_true(closest < gap_before - 0.3, "抓住領口：她走近一步（%.2f → %.2f m）" % [gap_before, closest])
	await tree.process_frame
	assert_false(_game.call("is_in_dialogue"), "講完")
	assert_false((canal.get_node("CornerCam") as Camera3D).current, "換回玩家的鏡頭")
	assert_eq(s.state.get_flag("ch3.corner_answer"), "silent" if alt else "bell", "是我敲的鐘／不說話")
	assert_eq(s.state.get_flag("ch3.collar_reply"), "held" if alt else "still", "不敢動／我沒有鬆手")
	assert_eq(s.state.get_flag("ch3.collar_fixed"), true, "她把衣領拉出來（第二部用）")
	var journal: Journal = Journal.load_default()
	assert_true(journal.visible_ids(s.state).has("ch3_collar"), "日記多一條：轉角的衣領")
	assert_true(s.quests.is_done("ch3_main"), "第 3 章完成")
	assert_eq(s.state.get_flag("ch3.complete"), true, "ch3.complete")
	assert_eq(_objective(canal), "", "HUD 沒有目標了")
	assert_true(s.has_save(GameSession.AUTO_SLOT), "完成時自動存檔")
	# 結尾卡：不真的回標題
	var ended: Array[bool] = [false]
	canal.set("end_card_done", func() -> void: ended[0] = true)
	canal.set("_end_card_wait", 0.01)
	for i: int in 4:
		await tree.process_frame
	var card: ChapterCard = canal.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "講完幾秒後結尾卡")
	if card != null:
		assert_eq(card.title_text(), str(TranslationServer.translate("PART1_END_TITLE")), "結尾卡：前半　完")
		card.finish()
	# 結尾卡之後：「感謝試玩」一頁（D-176）；按鈕剛出現時不能按，關掉才回標題
	var page: ThanksPage = canal.get_node_or_null("ThanksPage") as ThanksPage
	assert_not_null(page, "結尾卡播完 → 感謝試玩")
	assert_false(ended[0], "感謝試玩還沒關：不會直接回標題")
	if page != null:
		assert_eq(page.layer, ThanksPage.LAYER, "感謝試玩蓋在結尾卡上面")
		assert_true(page.back_button.disabled, "剛出現時按鈕不能按（連按跳過結尾卡不會順手跳掉這頁）")
		assert_eq((canal.get_node("Player") as Node).process_mode, Node.PROCESS_MODE_DISABLED, "黑幕底下諾恩停住")
		var rescued: int = clampi(int(s.state.get_flag("slice.rescued_count", 0)), 0, 4)
		assert_eq(page.value_text("THANKS_RUN_RESCUED"), "%d / 4" % rescued, "你的這一趟：北街救出幾個人")
		assert_eq(page.value_text("THANKS_RUN_DEAD"), str(DeadListBoard.dead_count(s.state)), "你的這一趟：死者跟名單一樣")
		assert_eq(page.value_text("THANKS_RUN_MEMORIES"), str(s.state.memories_paid.size()), "你的這一趟：忘掉幾段記憶")
		assert_true(int(page.value_text("THANKS_RUN_GUIDE")) >= 1, "你的這一趟：至少一條攻略筆記被推翻")
		assert_true(s.state.playtime_sec > 1.0, "在關卡裡的時間有在累計（%.1f 秒）" % s.state.playtime_sec)
		assert_eq(page.value_text("THANKS_RUN_TIME"), ThanksPage.time_text(s.state.playtime_sec), "你的這一趟：遊戲時間")
		page.elapsed = ThanksPage.INPUT_DELAY
		await tree.process_frame
		assert_false(page.back_button.disabled, "過一下子按鈕就能按")
		assert_true(page.back_button.has_focus(), "焦點在「回到標題」（手把直接按 A）")
		page.back_button.pressed.emit()
	assert_true(ended[0], "感謝試玩關掉 → 回標題")
	# 讀檔（＝標題的「繼續」）：站在轉角、「下一章還在製作中」，不會再講一次
	canal = await _retry()
	await tree.process_frame
	assert_eq(str(canal.name), "Canal", "[完成] 讀檔回到乾運河")
	assert_true(s.quests.is_done("ch3_main") or (_game.get("session") as GameSession).quests.is_done("ch3_main"), "[完成] 存檔裡第 3 章做完了")
	player = _player(canal)
	assert_true(_flat_dist(player.global_position, canal.get("CORNER_NOEN") as Vector3) < 0.5, "[完成] 站在轉角")
	assert_eq((canal.get_node("Hud") as Hud).banner_text(), "CH3_END_BANNER", "[完成] 下一章還在製作中")
	for i: int in 4:
		await tree.physics_frame
	assert_false(_game.call("is_in_dialogue"), "[完成] 不會再講一次")


## 乾運河：投影子的斜光（整座地底城只有這裡有）、頭頂一排排石樑、吊樑下掛著的送葬者（不在敵人名單裡、胸口的鐘舌會亮）。
func _assert_canal(canal: StoryLevel, tag: String) -> void:
	var sun: DirectionalLight3D = canal.get_node_or_null("SlitLight") as DirectionalLight3D
	assert_not_null(sun, tag + " 有從縫裡斜照下來的光")
	if sun != null:
		assert_true(sun.shadow_enabled, tag + " 這裡有影子")
		assert_true(sun.rotation_degrees.x < -30.0 and sun.rotation_degrees.x > -80.0, tag + " 光是斜的")
	assert_true((canal.get_node("CeilingSlats") as Node3D).get_child_count() >= 15, tag + " 頭頂一排排石樑")
	var u: Node3D = canal.call("undertaker") as Node3D
	assert_not_null(u, tag + " 吊樑下掛著送葬者")
	assert_false(u.is_in_group("enemies"), tag + " 掛著的送葬者不會被鎖定、不會開打")
	assert_eq(u.process_mode, Node.PROCESS_MODE_DISABLED, tag + " 牠一動也不動")
	assert_true(u.global_position.y < 0.0 and u.global_position.y > float(canal.get("BED_Y")) + 1.0, tag + " 掛在吊樑下、腳懸在河床上方")
	var light: OmniLight3D = canal.call("clapper_light") as OmniLight3D
	assert_false(light.shadow_enabled, tag + " 鐘舌的銅光不投影子")
	assert_true(light.light_color.r > light.light_color.b, tag + " 鐘舌是銅色的光")
	assert_true(canal.has_node("BankEdge") and canal.has_node("Sheila") and canal.has_node("Misha"), tag + " 說話點、席菈、彌夏")
	var amb: AudioStreamPlayer = canal.get_node_or_null("Ambience") as AudioStreamPlayer
	assert_not_null(amb, tag + " 地底的環境音")
	if amb != null:
		assert_eq((amb.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, tag + " 環境音會循環")
	_assert_canal_art(canal, tag)


## 乾運河的美術（第 55 輪，D-173）：河道牆＝方石＋舊水位線、岸頂＝石板（頂面在 y＝0、碰撞一整塊）、河床＝龜裂乾泥、木架＝整根木頭。
func _assert_canal_art(canal: StoryLevel, tag: String) -> void:
	var half_timber: String = FrostbridgeLook.HALF_TIMBER_SHADER
	for side: String in ["E", "W"]:
		var wall: MeshInstance3D = canal.get_node("Bank" + side) as MeshInstance3D
		var wm: ShaderMaterial = wall.material_override as ShaderMaterial
		assert_not_null(wm, tag + " 河道牆 " + side + " 是 shader 材質")
		if wm != null:
			assert_eq(wm.shader.resource_path, half_timber, tag + " 河道牆是方石")
			assert_true(float(wm.get_shader_parameter("tide_amount")) > 0.0, tag + " 河道牆有舊水位線")
			assert_eq(float(wm.get_shader_parameter("exterior")), 0.0, tag + " 河道牆不積雪")
		var top: MeshInstance3D = canal.get_node("BankTop" + side) as MeshInstance3D
		assert_true(absf(top.global_position.y + (top.mesh as BoxMesh).size.y * 0.5) < 0.001, tag + " 岸頂石板的頂面在 y＝0")
		assert_eq(((top.material_override as ShaderMaterial).shader as Shader).resource_path, InteriorLook.PLANK_SHADER, tag + " 岸頂是石板")
		assert_true(canal.has_node("Bank" + side + "Body"), tag + " 岸的碰撞還在")
		assert_false(canal.has_node("Seam%s0" % side), tag + " 接縫改成 shader 畫，不再是一條條方塊")
	var bed: MeshInstance3D = canal.get_node("CanalBed") as MeshInstance3D
	assert_eq(((bed.material_override as ShaderMaterial).shader as Shader).resource_path, "res://src/world/dry_mud.gdshader", tag + " 河床是龜裂的乾泥")
	assert_true(canal.has_node("MudPatch/Main"), tag + " 東岸摔下來的地方有一片泥")
	var drain_mud: MeshInstance3D = canal.get_node("Drain/DrainMud") as MeshInstance3D
	assert_eq(((drain_mud.material_override as ShaderMaterial).shader as Shader).resource_path, "res://src/world/dry_mud.gdshader", tag + " 水溝底的爛泥跟河床同一種")
	for n: String in ["SluiceBeam", "HangBeam", "CoalCart/CartBody", "CartDeck", "SluicePier1"]:
		var mi: MeshInstance3D = canal.get_node(n) as MeshInstance3D
		assert_true(mi.material_override is ShaderMaterial, tag + " " + n + " 換上了美術材質")


## 內室東牆的窗：窗框、窗簾兩半、窗外的屏障與眼睛（程序 shader）、屏障照進來的冷光（不投影子）。open＝看過眼睛之後的樣子。
func _assert_window(hall: StoryLevel, tag: String, open: bool) -> void:
	for n: String in ["WindowFrame", "Curtain/CurtainS", "Curtain/CurtainN", "Curtain/CurtainRod", "EyeWall", "Barrier", "BarrierLight", "EyeCamWindow", "EyeCamClose", "EyeCamGroup"]:
		assert_true(hall.has_node(n), tag + " 有 " + n)
	var eye: MeshInstance3D = hall.get_node("EyeWall") as MeshInstance3D
	assert_eq(((eye.material_override as ShaderMaterial).shader as Shader).resource_path, "res://src/world/deep_eye.gdshader", tag + " 眼睛是程序 shader")
	var barrier: MeshInstance3D = hall.get_node("Barrier") as MeshInstance3D
	assert_eq(((barrier.material_override as ShaderMaterial).shader as Shader).resource_path, "res://src/world/barrier_grid.gdshader", tag + " 屏障的冷光網格")
	var light: OmniLight3D = hall.get_node("BarrierLight") as OmniLight3D
	assert_false(light.shadow_enabled, tag + " 冷光不投影子")
	assert_true(light.light_color.b > light.light_color.r, tag + " 屏障的光是冷的")
	assert_eq(bool(hall.call("is_curtain_open")), open, tag + (" 窗簾開著" if open else " 窗簾拉著"))
	assert_eq(eye.visible, open, tag + (" 看得到窗外的眼睛" if open else " 窗簾拉著：看不到窗外"))
	assert_eq(barrier.visible, open, tag + " 屏障跟著窗簾")
	if open:
		await tree.process_frame
		assert_eq(float(hall.get("eye_open")), 1.0, tag + " 眼睛睜開")
		assert_eq(float(hall.get("pupil")), float(hall.get("PUPIL_NARROW")), tag + " 瞳孔收窄")
		assert_true(light.light_energy > 0.5, tag + " 冷光照進來")
		assert_eq(float((eye.material_override as ShaderMaterial).get_shader_parameter("eye_open")), 1.0, tag + " shader 拿到眼睛的狀態")
		var isa: Node3D = hall.get_node("Isa") as Node3D
		assert_true(_flat_dist(isa.global_position, hall.get("ISA_WINDOW") as Vector3) < 0.1, tag + " 伊薩站在窗邊")
	else:
		assert_eq(light.light_energy, 0.0, tag + " 窗簾拉著：沒有冷光")


## 鐘院內室：主椅上坐著黎歐、牆上的鐘盤（九道刻痕）、十二條細管（光團往鐘盤流的 shader）、西牆 4 塊浮雕；暖光都不投影子。
func _assert_inner_room(hall: StoryLevel, tag: String) -> void:
	for n: String in ["Leo", "MainSeat", "BellDial", "BellDial/Hub", "LifeTubes", "WallCarvings", "InnerCamWide", "InnerCamLeo", "InnerCamMisha", "InnerCamTwo"]:
		assert_true(hall.has_node(n), tag + " 有 " + n)
	for i: int in 9:
		assert_true(hall.has_node("BellDial/Tick%d" % i), tag + " 鐘盤上九道刻痕")
	for i: int in 4:
		assert_true(hall.has_node("WallCarvings/Carving%d" % i), tag + " 牆上 4 塊浮雕")
	var leo: Puppet = hall.get_node("Leo") as Puppet
	assert_true(leo.sitting, tag + " 黎歐坐在主椅上")
	var tubes: MeshInstance3D = hall.get_node("LifeTubes") as MeshInstance3D
	assert_eq(((tubes.material_override as ShaderMaterial).shader as Shader).resource_path, "res://src/world/life_tube.gdshader", tag + " 細管用流動微光的 shader")
	assert_true(tubes.mesh.get_aabb().size.z > 2.5, tag + " 細管從椅背一路接到鐘盤")
	for l: String in ["DialGlow", "SeatGlow", "InnerFill", "EastFill"]:
		var light: OmniLight3D = hall.get_node(l) as OmniLight3D
		assert_true(light.light_color.r > light.light_color.b, tag + " " + l + " 是暖光")


## 鐘院：還在白晝城裡——只有油燈投影子、沒有太陽、接地陰影拿掉；桌上三盤煮豆、一鍋稀粥、四個碗；伊薩右腿有支架。
func _assert_bell_hall(hall: StoryLevel, tag: String) -> void:
	await tree.process_frame
	for n: String in ["Isa", "Sheila", "Misha", "DinnerTable", "IsaChair", "PorridgePot", "PorridgePot/PorridgeSteam", "InnerDoor", "Curtain"]:
		assert_true(hall.has_node(n), tag + " 有 " + n)
	for i: int in 3:
		assert_true(hall.has_node("BeanPlate%d" % i), tag + " 三盤煮豆")
	for i: int in 4:
		assert_true(hall.has_node("Bowl%d/Chip" % i), tag + " 四個缺口不一樣的碗")
	assert_true(bool(hall.call("has_leg_brace")), tag + " 伊薩右腿的金屬支架")
	assert_true(_player(hall).has_oil_lamp(), tag + " 拿著油燈")
	var lamp: OmniLight3D = hall.call("lamp_light") as OmniLight3D
	var shadowed: PackedStringArray = []
	for l: Node in hall.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D or ((l as Light3D).shadow_enabled and l != lamp):
			shadowed.append(str(l.get_path()))
	assert_eq(shadowed.size(), 0, tag + " 除了油燈以外沒有投影子的光：%s" % ", ".join(shadowed))
	assert_true(lamp != null and lamp.shadow_enabled, tag + " 油燈投影子")
	for c: Node in hall.find_children(ContactShadow.NODE_NAME, "", true, false):
		assert_false((c as Node3D).visible, tag + " 接地陰影拿掉：" + str(c.get_parent().name))
	# 飯廳的美術（第 54 輪，D-172）：木板地、石塊牆腳＋灰泥＋壁柱、掛畫留下的白印、白燈
	var floor_mat: ShaderMaterial = (hall.get_node("Floor") as MeshInstance3D).material_override as ShaderMaterial
	assert_true(floor_mat != null and floor_mat.shader.resource_path == InteriorLook.PLANK_SHADER, tag + " 飯廳是木板地")
	var wall_mat: ShaderMaterial = (hall.get_node("WallWest") as MeshInstance3D).material_override as ShaderMaterial
	assert_true(wall_mat != null and wall_mat.shader.resource_path == FrostbridgeLook.HALF_TIMBER_SHADER, tag + " 飯廳的牆是石塊＋灰泥")
	if wall_mat != null:
		assert_eq(float(wall_mat.get_shader_parameter("exterior")), 0.0, tag + " 室內牆不積雪")
	for n: String in ["HallLamp/Bulb", "InnerCasingHead", "HallCasingHead", "CeilingBeam0", "FadedFrame0", "FadedFrameNail0", "TableStretcher", "IsaChair", "IsaOwnChair", "InnerWallSouthW", "InnerWallSouthLintel"]:
		assert_true(hall.has_node(n), tag + " 有 " + n)
	var frames: Array = hall.get("FADED_FRAMES") as Array
	assert_true(hall.has_node("FadedFrame%d" % (frames.size() - 1)), tag + " 每一塊白印都有")
	var inner_floor: ShaderMaterial = (hall.get_node("InnerFloor") as MeshInstance3D).material_override as ShaderMaterial
	assert_true(inner_floor != null and float(inner_floor.get_shader_parameter("grain_amount")) == 0.0, tag + " 內室是石板地")
	var inner_wall: ShaderMaterial = (hall.get_node("InnerWallNorth") as MeshInstance3D).material_override as ShaderMaterial
	assert_true(inner_wall != null and float(inner_wall.get_shader_parameter("stone_height")) > float(hall.get("INNER_H")), tag + " 內室整面方石")


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 白晝城：只有諾恩的油燈投影子（07 的場景斷言）；沒有太陽；接地陰影也拿掉；柯德、席菈、彌夏、瑪菈都在。
func _assert_daylight(city: StoryLevel, tag: String) -> void:
	await tree.process_frame
	for n: String in ["Kord", "Sheila", "Misha", "Mara", "Furnace", "OnionPot", "KordHome", "Ambience"]:
		assert_true(city.has_node(n), tag + " 有 " + n)
	assert_true(_player(city).has_oil_lamp(), tag + " 拿著油燈")
	var lamp: OmniLight3D = city.call("lamp_light") as OmniLight3D
	assert_not_null(lamp, tag + " 油燈的光")
	var shadowed: PackedStringArray = []
	for l: Node in city.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			shadowed.append("太陽 " + str(l.name))
		elif (l as Light3D).shadow_enabled and l != lamp:
			shadowed.append(str(l.get_path()))
	assert_eq(shadowed.size(), 0, tag + " 除了油燈以外沒有投影子的光：%s" % ", ".join(shadowed))
	assert_true(lamp != null and lamp.shadow_enabled, tag + " 油燈投影子")
	for c: Node in city.find_children(ContactShadow.NODE_NAME, "", true, false):
		assert_false((c as Node3D).visible, tag + " 接地陰影拿掉：" + str(c.get_parent().name))
	_assert_daylight_art(city, tag)


## 白晝城街道的美術（第 56 輪，D-174）：房子、廣場與路口的牆不再是素色白盒；地面是石板；窗台、門框、拱肋合併在 StreetTrim。
func _assert_daylight_art(city: StoryLevel, tag: String) -> void:
	var white_box: PackedStringArray = []
	var plaster: Color = (city.get_script() as GDScript).get_script_constant_map()["PLASTER"] as Color
	var shutter: Color = (city.get_script() as GDScript).get_script_constant_map()["SHUTTER"] as Color
	for n: Node in city.get_children():
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or not (mi.material_override is StandardMaterial3D):
			continue
		var c: Color = (mi.material_override as StandardMaterial3D).albedo_color
		if c.is_equal_approx(plaster) or c.is_equal_approx(shutter):
			white_box.append(str(mi.name))
	assert_eq(white_box.size(), 0, tag + " 街上沒有素色的白灰牆或窗板：%s" % ", ".join(white_box.slice(0, 5)))
	var ground: MeshInstance3D = city.get_node("Ground") as MeshInstance3D
	assert_true(ground.material_override is ShaderMaterial, tag + " 地面是石板")
	for n: String in ["EndWall", "StreetPillar", "BellYardGate"]:
		assert_true((city.get_node(n) as MeshInstance3D).material_override is ShaderMaterial, tag + " " + n + " 有材質")
	assert_true(city.has_node("StreetTrim"), tag + " 窗台、門框、拱肋（StreetTrim）")
	assert_true(city.get_node("StreetTrim").get_child_count() >= 3, tag + " StreetTrim 有石、木、拱肋三種材質")
	for n: String in ["FurnaceBand0", "FurnaceBand2", "FurnacePlinth", "FurnaceDoorFrame0", "FurnacePipeJoint0"]:
		assert_true(city.get_node("Furnace").has_node(n), tag + " 淨化爐的 " + n)
	# 第 57 輪（D-175）：後門是門洞＋往上的台階（不是一塊黑板）、門房有屋頂與前面的石柱、晾衣繩的衣服不是方塊
	assert_false(city.has_node("GateDark"), tag + " 後門不是一塊黑板")
	for n: String in ["PassageStep0", "PassageWallW", "BackDoorLeaf", "BackDoorBlock"]:
		assert_true(city.get_node("BackDoor").has_node(n), tag + " 後門的 " + n)
	assert_true((city.get_node("BackDoor/PassageStep0") as MeshInstance3D).material_override is ShaderMaterial, tag + " 通道的台階會變暗")
	assert_true(city.has_node("Gatehouse/GatehouseRoof") and city.has_node("GatehousePost") and city.has_node("GatehouseSill"), tag + " 門房的屋頂、石柱、矮牆")
	for i: int in 4:
		var cloth: MeshInstance3D = city.get_node("Laundry%d" % i) as MeshInstance3D
		assert_false(cloth.mesh is BoxMesh, tag + " 晾的衣服 %d 不是方塊" % i)
	assert_true(city.get_node("Clothesline").get_child_count() >= 4, tag + " 晾衣繩分段往下垂")


## 環境音（D-180）：關卡裡的那個播放器在播那一段、走 SFX 匯流排、會循環。
func _assert_ambience(level: Node, tag: String, sfx_name: String, node_name: String = "Ambience") -> Node:
	var p: Node = level.get_node_or_null(node_name)
	assert_eq(Ambience.sfx_of(p), sfx_name, "%s 環境音 %s" % [tag, sfx_name])
	if p != null:
		assert_eq(StringName(p.get("bus")), &"SFX", "%s %s 走音效匯流排" % [tag, node_name])
		assert_true(bool(p.get("playing")), "%s %s 在播" % [tag, node_name])
		var stream: AudioStreamWAV = p.get("stream") as AudioStreamWAV
		assert_true(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s %s 會循環" % [tag, node_name])
	return p


## 白天的霜橋鎮：陰天的太陽、路燈不點、沒有切片的敵人與車隊、席菈跟著。
func _assert_day_town(town: StoryLevel, tag: String) -> void:
	assert_true(bool(town.get("day")), tag + " 白天版本")
	var wind: AudioStreamPlayer = _assert_ambience(town, tag, "frost_wind") as AudioStreamPlayer
	if wind != null:
		assert_true(wind.volume_db < float(town.get("WIND_DB_NIGHT")), tag + " 白天的風比那一夜小")
	assert_true(town.has_node("Sun") and not town.has_node("Moon"), tag + " 陰天的太陽、沒有月光")
	for n: String in ["Undertaker", "Ashwalker", "Caravan", "ConvoyEncounter"]:
		assert_false(town.has_node(n), tag + " 沒有 " + n)
	assert_true(town.has_node("Sheila"), tag + " 席菈跟著")
	assert_true(town.has_node("Ada"), tag + " 艾妲在地窖門口")
	var player: Node = town.get_node("Player")
	var lit: int = 0
	for l: Node in town.find_children("*", "OmniLight3D", true, false):
		if (l as OmniLight3D).visible and not player.is_ancestor_of(l) and not town.get_node("Sheila").is_ancestor_of(l):
			lit += 1
	assert_eq(lit, 0, tag + " 路燈與攤子的燈不點")
	for site: RescueSite in _rescue_sites(town):
		assert_false(site.is_available(), tag + " 受困者不能再救")
		# D-170：救出來的只剩碎石；沒救出來的蓋著布
		assert_eq(site.is_covered(), not site.is_rescued(), tag + " 沒救出來的 %s 蓋著布" % site.site_id)
	# D-170：梨販攤旁的死者名單，張數＝切片結果的死亡人數
	var s: GameSession = _game.get("session") as GameSession
	assert_true(town.has_node("DeadList"), tag + " 有死者名單")
	var board: DeadListBoard = town.get_node("DeadList") as DeadListBoard
	assert_eq(board.paper_count, DeadListBoard.dead_count(s.state), tag + " 名單的張數")
	# D-178：白天走進南街不會再播切片的「石拱回憶」（就算旗標沒設——那段記憶可能已經為了重現付掉了）
	var saw: Variant = s.state.get_flag("slice.saw_south_arch", false)
	s.state.set_flag("slice.saw_south_arch", false)
	town.call("_on_arch_memory")
	assert_false(_game.call("is_in_dialogue"), tag + " 白天走進南街不會再播石拱回憶")
	s.state.set_flag("slice.saw_south_arch", saw)
	# 白天大部分的窗熄了
	assert_true(int(town.get("day_unlit_windows")) > int(town.get("lit_window_count")), tag + " 白天大部分的窗熄了")
	assert_true(int(town.get("lit_window_count")) > 0, tag + " 還有幾扇窗亮著")


## D-178：「重現」與記憶代價的一致性（每個關卡進場都跑一次）。
## - 現在能重現的地方＝expected（物件 id）；其他的 NineBreathSite 都停用或用過了、地上的圈不亮、不會出提示。
## - 每個地方的記憶都在日記裡、提示的「可以重現」與「代價」有翻譯。
## - 付出過的記憶都在日記裡看得到；感謝試玩的「忘掉幾段記憶」算的就是這些。
## - expected 是空的：按住重現鍵一陣子什麼都不會發生（不付記憶、不改重現狀態、HUD 沒有提示、日記不標亮）。
func _assert_restore(level: StoryLevel, tag: String, expected: Array[String]) -> void:
	var s: GameSession = _game.get("session") as GameSession
	var journal: Journal = _game.get("journal") as Journal
	var usable: Array[String] = []
	for n: Node in tree.get_nodes_in_group("nine_breath_site"):
		var site: NineBreathSite = n as NineBreathSite
		if site == null or not level.is_ancestor_of(site):
			continue
		assert_true(journal.has_entry(site.memory_id), tag + " %s 的代價 %s 在日記裡" % [site.object_id, site.memory_id])
		for key: String in [site.label_key, site.cost_key]:
			assert_ne(tr(key), key, tag + " %s 的提示有翻譯（%s）" % [site.object_id, key])
		if site.is_usable():
			usable.append(site.object_id)
		else:
			assert_false(site.prompt_shown(), tag + " 不能重現的 %s 沒有提示" % site.object_id)
			assert_false(site.ring_visible(), tag + " 不能重現的 %s 地上的圈不亮" % site.object_id)
	usable.sort()
	assert_eq(usable, expected, tag + " 現在能重現的地方")
	var visible: PackedStringArray = journal.visible_ids(s.state)
	for id: String in s.state.memories_paid:
		assert_true(journal.has_entry(id), tag + " 付出的記憶 %s 是日記裡的條目" % id)
		assert_true(visible.has(id), tag + " 付出的記憶 %s 在日記裡看得到" % id)
	if not expected.is_empty():
		return
	var paid: PackedStringArray = s.state.memories_paid.duplicate()
	var restore_flags: Dictionary = {}
	for k: String in s.state.flags:
		if k.begins_with("ninebreath."):
			restore_flags[k] = s.state.flags[k]
	var hud: Hud = level.get_node("Hud") as Hud
	Input.action_press(NineBreathSite.ACTION)
	for i: int in 12:
		await tree.physics_frame
	assert_false(hud.restore.visible, tag + " 按住重現鍵：沒有可以重現的東西，HUD 不出提示")
	assert_eq(journal.highlighted, "", tag + " 按住重現鍵：日記不標亮")
	Input.action_release(NineBreathSite.ACTION)
	await tree.physics_frame
	assert_eq(s.state.memories_paid, paid, tag + " 按住重現鍵：不付記憶")
	var after: Dictionary = {}
	for k: String in s.state.flags:
		if k.begins_with("ninebreath."):
			after[k] = s.state.flags[k]
	assert_eq(after, restore_flags, tag + " 按住重現鍵：重現的狀態不變")


func _cleanup() -> void:
	var scene: Node = tree.current_scene
	if scene != null:
		scene.queue_free()
	for i: int in 3:
		await tree.process_frame


func test_playthrough_nine_breath_route() -> void:
	await _playthrough(true)
	await _cleanup()


func test_playthrough_kindling_route() -> void:
	await _playthrough(false)
	await _cleanup()
