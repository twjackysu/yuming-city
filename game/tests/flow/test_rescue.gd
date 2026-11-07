extends TestCase
## 段落 3「救援」：北街陷落後出現受困者，按住互動鍵搬開瓦礫救人；救三人任務推進，之後還能救；讀檔不重複。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_rescue_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _session_after_bell() -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_game()
	s.set_flag("slice.met_pear_seller", true)
	for i: int in 9:
		s.add_flag("slice.bell_rings")
	return s


func _sites(level: Node) -> Array[RescueSite]:
	var out: Array[RescueSite] = []
	for c: Node in level.get_children():
		if c is RescueSite:
			(c as RescueSite).set_physics_process(false)
			out.append(c as RescueSite)
	return out


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func test_no_trapped_before_collapse() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_game()
	var level: StoryLevel = await _load()
	assert_eq(_sites(level).size(), 0, "北街還沒陷落：沒有受困者")
	level.collapse_north_street(false)
	var sites: Array[RescueSite] = _sites(level)
	assert_eq(sites.size(), 4, "陷落後出現四個受困者")
	assert_false(sites[0].is_available(), "還沒到救援階段不能救")
	level.queue_free()
	await tree.process_frame


func test_hold_to_rescue_and_quest_advances() -> void:
	var s := _session_after_bell()
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "rescue")
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_true(player.global_position.distance_to(Vector3(0, 0.05, -24)) < 0.5, "救援檢查點在主街北段出生")
	var sites: Array[RescueSite] = _sites(level)
	assert_eq(sites.size(), 4, "讀檔時已陷落：受困者都在")
	var a: RescueSite = sites[0]
	assert_true(a.is_available())
	assert_false(a.update_hold(0.2, true), "按不夠久")
	assert_eq(a.scrape_count, 1, "一按下就有刮石聲")
	assert_false(a.update_hold(0.2, true))
	assert_eq(a.scrape_count, 2, "按住每 0.35 秒刮一下")
	assert_false(a.update_hold(0.6, true), "按不夠久")
	a.update_hold(0.1, false)
	assert_eq(a.hold, 0.0, "放開歸零")
	assert_true(a.update_hold(1.7, true), "按滿救出")
	assert_true(a.is_rescued())
	assert_false(a.is_available(), "救過不能再救")
	assert_eq(int(s.state.get_flag("slice.rescued_count", 0)), 1)
	assert_eq(s.state.get_flag("slice.rescued.north_a"), true)
	sites[1].rescue()
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "rescue", "救兩人還在救援")
	sites[2].rescue()
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "meet_sheila", "救出三人 → 席菈")
	assert_true(sites[3].is_available(), "送葬者戰之前還能繼續救")
	sites[3].rescue()
	assert_eq(int(s.state.get_flag("slice.rescued_count", 0)), 4)
	assert_eq(s.save("slot1"), OK)
	level.queue_free()
	await tree.process_frame
	await tree.process_frame

	# 讀檔：救過的不會再出現
	var s2 := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s2)
	assert_eq(s2.load_slot("slot1"), SaveCodec.Status.OK)
	var level2: StoryLevel = await _load()
	for site: RescueSite in _sites(level2):
		assert_true(site.is_rescued(), "%s 讀檔後是已救出" % site.site_id)
		assert_false(site.is_available())
	assert_eq(int(s2.state.get_flag("slice.rescued_count", 0)), 4, "數字沒有重複加")
	level2.queue_free()
	await tree.process_frame
	await tree.process_frame
