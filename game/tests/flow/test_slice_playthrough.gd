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
	_game.call("retry")
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
	await _talk_at(tavern, "Sheila", 0)
	assert_eq(s.state.get_flag("ch1.noon_talked"), true, "中午跟席菈、彌夏說完話")
	assert_eq(s.quests.stage_of("ch1_main"), "dinner")
	assert_true(bool(tavern.call("is_night")), "晚餐：入夜")
	# 重來：回到晚餐的檢查點，還在酒館
	tavern = await _retry()
	assert_eq(str(tavern.name), "Tavern", "[ch1_dinner] 重來還在酒館")
	assert_eq(s.quests.stage_of("ch1_main"), "dinner", "[ch1_dinner] 階段恢復")
	assert_eq(_objective(tavern), "Q_CH1_OBJ_DINNER", "[ch1_dinner] HUD 目標")
	await _talk_at(tavern, "DinnerTable", 0 if help_with_soup else 1)
	assert_eq(s.state.get_flag("ch1.sheila_soup_helped"), help_with_soup, "灑湯的選擇記下來")
	assert_eq(s.quests.stage_of("ch1_main"), "draw_map")
	for id: String in s.guide.ids():
		assert_eq(GuideNotes.status(s.state, id), GuideNotes.UNWRITTEN, "畫地圖之前還沒寫下 %s" % id)
	await _talk_at(tavern, "MapTable", 0)
	for id: String in s.guide.ids():
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
	assert_eq(_objective(town), "Q_CH1_OBJ_DAY_NORTH", "[ch1_day_town] HUD 目標")
	town = await _retry()
	assert_eq(s.quests.stage_of("ch1_main"), "day_north", "[ch1_day_town] 重來階段恢復")
	_assert_day_town(town, "[ch1_day_town] 重來")
	await _step_into(_player(town), Vector3(0.0, 0.0, -32.0), 3)
	assert_true(_game.call("is_in_dialogue"), "走上北街 → 白天看昨晚的現場")
	await _run_dialogue(town, 0)
	assert_eq(s.state.get_flag("ch1.saw_north_day"), true, "北街的對話講完")
	assert_eq(s.quests.stage_of("ch1_main"), "ada_lamp")
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


## 第 2 章（D-157）：章節卡 → 鐘院（城主的飯廳）→ 伊薩拉椅子、支架吱一聲 → 飯桌的對話 → 待續（段落 2 下一輪做）。
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
	hall = await _retry()
	assert_eq(str(hall.name), "BellHall", "[ch2_start] 重來還在鐘院")
	assert_eq(_objective(hall), "Q_CH2_OBJ_TABLE", "[ch2_start] HUD 目標")
	assert_false(bool(hall.call("is_seated")), "[ch2_start] 還沒坐下")
	await _assert_bell_hall(hall, "[ch2_start] 重來")
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
	# 段落 1（D-158）：對伊薩按住看穿 → 攻略的稱號一個字一個字被劃掉 → 攻略筆記「城主＝食歲的僭王」被推翻
	var strike: StrikeCard = hall.call("strike_card") as StrikeCard
	assert_not_null(strike, "看穿伊薩的小卡")
	hall.call("update_isa_insight", 0.1, false)
	assert_false(strike.visible, "沒按看穿：不顯示")
	assert_eq(str((hall.call("interact_hint") as Dictionary).get("action", "")), "insight", "提示：按住看穿伊薩")
	assert_ne(GuideNotes.status(s.state, "usurper"), GuideNotes.WRONG, "還沒看穿：攻略筆記照舊")
	for i: int in 60:
		hall.call("update_isa_insight", 0.1, true)
		if strike.is_done():
			break
	assert_true(strike.is_done(), "按住看穿 → 劃完")
	assert_eq(s.state.get_flag("ch2.usurper_crossed_out"), true)
	assert_eq(GuideNotes.status(s.state, "usurper"), GuideNotes.WRONG, "攻略筆記「城主＝食歲的僭王」被推翻")
	assert_true((hall.call("interact_hint") as Dictionary).is_empty(), "看穿過了：不再提示")
	assert_eq(s.quests.stage_of("ch2_main"), "isa_volunteer", "→ 問伊薩彌夏的弟弟在哪裡")
	for i: int in 3:
		await tree.physics_frame
	assert_eq((hall.get_node("Hud") as Hud).banner_text(), "CH1_TO_BE_CONTINUED", "段落 2（他自願的）待續")


## 鐘院：還在白晝城裡——只有油燈投影子、沒有太陽、接地陰影拿掉；桌上三盤煮豆、一鍋稀粥、四個碗；伊薩右腿有支架。
func _assert_bell_hall(hall: StoryLevel, tag: String) -> void:
	await tree.process_frame
	for n: String in ["Isa", "Sheila", "Misha", "DinnerTable", "IsaChair", "PorridgePot", "InnerDoor", "Curtain"]:
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


## 白天的霜橋鎮：陰天的太陽、路燈不點、沒有切片的敵人與車隊、席菈跟著。
func _assert_day_town(town: StoryLevel, tag: String) -> void:
	assert_true(bool(town.get("day")), tag + " 白天版本")
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
