extends TestCase
## M1.2 驗收（場景＋狀態層面）：沙盒裡的送葬者戰可以打完，兩條路線都走得通。
##   九息路線：第二階段生命 ≤ 300 → 舉鐵架 → 保存南街石拱擋下 → 車隊通過 → 結束（付出父親的記憶）。
##   薪火劍路線：不用九息 → 席菈燒薪火劍 → 車隊通過 → 結束（sheila.kindling_used_early）。

var _dir: String = ""


func before_each() -> void:
	_dir = "user://test_convoy_%d" % Time.get_ticks_usec()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _fight(use_nine_breath: bool) -> GameState:
	var game: Node = tree.root.get_node("Game")
	var original: GameSession = game.get("session") as GameSession
	var s := GameSession.new(QuestDB.load_default(), _dir)
	game.set("session", s)
	s.new_game()
	var level: Node3D = (load("res://scenes/dev/sandbox.tscn") as PackedScene).instantiate() as Node3D
	tree.root.add_child(level)
	await tree.physics_frame
	var enc: ConvoyEncounter = level.call("spawn_convoy_fight", true) as ConvoyEncounter
	var boss: Undertaker = level.get_node("Undertaker") as Undertaker
	var caravan: Caravan = level.get_node("Caravan") as Caravan
	var site: NineBreathSite = level.get("arch_site") as NineBreathSite
	await tree.physics_frame
	assert_true(boss.target != null, "送葬者有目標")
	# 打到第二階段、生命 ≤ 300
	boss.health.apply_damage(boss.health.hp - 290.0, {"stagger": 0.0})
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(boss.phase, 2, "進第二階段")
	assert_not_null(enc.frame_throw, "鐵架拋擲開始")
	if use_nine_breath:
		site.update_hold(1.1, true)
		assert_true(site.is_solid(), "保存南街石拱")
	enc.frame_throw.tick(FrameThrowEvent.WINDUP_SEC + 0.1, site.is_solid(), s.state)
	assert_eq(s.state.get_flag("slice.frame_throw_outcome"), "arch" if use_nine_breath else "kindling")
	# 車隊推到路口
	caravan.runner.traveled = caravan.runner.length() - 0.05
	for i: int in 20:
		await tree.physics_frame
		if enc.done:
			break
	assert_true(enc.done, "車隊通過路口：戰鬥結束")
	assert_true(boss.health.is_dead(), "送葬者被斬倒")
	assert_eq(s.state.get_flag("slice.convoy_done"), true)
	var st: GameState = s.state
	level.queue_free()
	await tree.process_frame
	await tree.process_frame
	game.set("session", original)
	return st


func test_convoy_fight_nine_breath_route() -> void:
	var st: GameState = await _fight(true)
	assert_true(st.has_paid_memory("arch_father_last_talk"), "九息路線：付出父親的記憶")
	assert_eq(st.get_flag("sheila.kindling_used_early", false), false, "席菈沒有提前燒劍")


func test_convoy_fight_kindling_route() -> void:
	var st: GameState = await _fight(false)
	assert_false(st.has_paid_memory("arch_father_last_talk"), "薪火劍路線：記憶還在")
	assert_eq(st.get_flag("sheila.kindling_used_early"), true, "席菈提前燒了薪火劍")
