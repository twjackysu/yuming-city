extends TestCase
## 第一章的起點（腐敗之森入口）：新遊戲 → 任務與檢查點 → 走進瘴氣反轉 → 打倒三隻史萊姆。
## 劇本 docs/story/chapter-1.md，計畫 docs/design/13-chapter-1-plan.md。

const LEVEL: String = "res://scenes/levels/corrupt_forest.tscn"

var _dir: String = ""
var _old_session: GameSession
var _level: CorruptForest


func _game() -> Node:
	return tree.root.get_node("Game")


func before_each() -> void:
	_dir = "user://test_ch1_%d" % Time.get_ticks_usec()
	_old_session = _game().get("session") as GameSession
	_game().set("session", GameSession.new(QuestDB.load_default(), _dir))


func after_each() -> void:
	if _level != null and is_instance_valid(_level):
		_level.free()
	_game().set("session", _old_session)
	Engine.time_scale = 1.0
	CombatTuning.load_tuning()
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _session() -> GameSession:
	return _game().get("session") as GameSession


func _load_level() -> CorruptForest:
	_level = (load(LEVEL) as PackedScene).instantiate() as CorruptForest
	tree.root.add_child(_level)
	return _level


func test_new_game_starts_chapter_one_and_autosaves() -> void:
	var s: GameSession = _session()
	assert_false(s.in_story(), "還沒開新遊戲")
	_game().call("new_game", false)
	s = _session()
	assert_true(s.in_story())
	assert_eq(s.state.chapter, "ch1")
	assert_eq(s.main_quest(), "ch1_main")
	assert_eq(s.quests.stage_of("ch1_main"), "enter_miasma")
	assert_eq(s.objective_key(), "Q_CH1_OBJ_MIASMA")
	assert_eq(s.state.checkpoint, "ch1_forest_gate")
	assert_true(s.has_save(), "進第一個檢查點就自動存檔")
	assert_true(bool(_game().call("has_continue")), "標題的「繼續」找得到")
	assert_eq(str(_game().call("level_for_checkpoint", s.state.checkpoint)), "corrupt_forest")


func test_quest_follows_the_two_flags_and_continue_restores_it() -> void:
	_game().call("new_game", false)
	var s: GameSession = _session()
	s.set_flag(CorruptForest.FLAG_REVERSAL, true)
	assert_eq(s.quests.stage_of("ch1_main"), "slimes")
	assert_eq(s.state.checkpoint, "ch1_slimes")
	assert_eq(s.quests.marker_spec("ch1_main"), "node:SlimeGlade")
	var again := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(again.load_slot(GameSession.AUTO_SLOT), SaveCodec.Status.OK)
	assert_eq(again.quests.stage_of("ch1_main"), "slimes", "讀檔回到第二段")
	s.set_flag(CorruptForest.FLAG_SLIMES, true)
	assert_true(s.quests.is_done("ch1_main"))
	assert_eq(s.state.get_flag("ch1.forest_gate_done"), true)


func test_quest_and_dialogue_data_are_valid() -> void:
	var db := QuestDB.load_default()
	assert_true(db.errors.is_empty(), "任務資料：%s" % ", ".join(db.errors))
	var dlg := DialogueDB.load_default()
	assert_true(dlg.errors.is_empty(), "對話資料：%s" % ", ".join(dlg.errors))
	assert_true(dlg.has_dialogue("ch1_forest_gate"))
	assert_true(StatusRules.load_default().errors.is_empty(), "狀態資料")


func test_level_builds_with_markers_miasma_slimes_and_a_clear_path() -> void:
	_game().call("new_game", false)
	var level: CorruptForest = _load_level()
	await tree.physics_frame
	for marker: String in ["MiasmaEdge", "SlimeGlade", "Spawn", "Player", "Hud", "Miasma", "Forest"]:
		assert_not_null(level.get_node_or_null(marker), "有節點 %s" % marker)
	assert_eq(level.slimes.size(), 3, "三隻史萊姆")
	assert_eq(level.slimes_alive(), 3)
	assert_true(level.get_node("Forest").get_child_count() >= CorruptForest.TREE_COUNT, "樹與路邊的小東西都種了")
	assert_false(CorruptForest.tree_spot_ok(Vector3(0, 0, 8)), "路上不種樹")
	assert_false(CorruptForest.tree_spot_ok(CorruptForest.GLADE_POS), "空地不種樹")
	assert_false(CorruptForest.tree_spot_ok(CorruptForest.MIASMA_POS), "瘴氣裡不種樹")
	assert_true(CorruptForest.tree_spot_ok(Vector3(12, 0, 8)))
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_true(player.global_position.distance_to((level.get_node("Spawn") as Node3D).global_position) < 0.5, "諾恩在出生點")
	assert_not_null(player.weapon(), "手上有劍")
	assert_true(player.puppet().hand("R").has_node("Weapon"), "劍在右手")


func test_walking_into_the_miasma_reverses_poison_into_healing() -> void:
	_game().call("new_game", false)
	var level: CorruptForest = _load_level()
	await tree.physics_frame
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.health.hp = 40.0
	assert_false(player.reversal.awakened_once)
	player.global_position = CorruptForest.MIASMA_POS + Vector3(0, 0.05, 0)
	for i: int in 30:
		await tree.physics_frame
	assert_true(player.status_effects.has("poison"), "站在瘴氣裡中毒了")
	assert_true(player.reversal.awakened_once, "第一次中毒就覺醒")
	assert_true(player.status_effects.is_reversed("poison"))
	assert_true(player.health.hp > 40.0, "中毒變成回血（%.1f）" % player.health.hp)
	var s: GameSession = _session()
	assert_eq(s.state.get_flag(CorruptForest.FLAG_REVERSAL), true)
	assert_eq(s.quests.stage_of("ch1_main"), "slimes", "任務往下一段")


func test_slime_chases_bumps_and_its_poison_heals_noen() -> void:
	_game().call("new_game", false)
	var level: CorruptForest = _load_level()
	await tree.physics_frame
	var player: PlayerController = level.get_node("Player") as PlayerController
	var slime: Slime = level.slimes[0]
	assert_eq(slime.tuning_id(), "poison_slime")
	assert_eq(slime.health.max_hp, CombatTuning.num("poison_slime.max_hp"))
	assert_true(slime.is_in_group("enemies") and slime.is_in_group("damageable"))
	for other: Slime in [level.slimes[1], level.slimes[2]]:
		other.set_physics_process(false)
	player.global_position = slime.global_position + Vector3(0, 0.05, 1.2)
	var hp0: float = player.health.hp
	var struck: bool = false
	for i: int in 240:
		await tree.physics_frame
		if player.health.hp < hp0 or player.status_effects.has("poison"):
			struck = true
			break
	assert_true(struck, "史萊姆撞到諾恩")
	assert_true(player.status_effects.has("poison"), "撞到會中毒")
	assert_true(player.status_effects.is_reversed("poison"), "而且是反轉的（回血）")


func test_clearing_the_slimes_finishes_the_slice() -> void:
	_game().call("new_game", false)
	var s: GameSession = _session()
	s.set_flag(CorruptForest.FLAG_REVERSAL, true)
	var level: CorruptForest = _load_level()
	await tree.physics_frame
	for slime: Slime in level.slimes:
		slime.health.apply_damage(9999.0, {"source": level.get_node("Player")})
	assert_eq(level.slimes_alive(), 0)
	for i: int in 3:
		await tree.physics_frame
	assert_eq(s.state.get_flag(CorruptForest.FLAG_SLIMES), true)
	assert_true(s.quests.is_done("ch1_main"))
	assert_eq((level.get_node("Hud") as Hud).banner_text(), "CH1_SLIMES_CLEARED")


func test_cleared_glade_stays_cleared_after_reload() -> void:
	_game().call("new_game", false)
	_session().set_flag(CorruptForest.FLAG_REVERSAL, true)
	_session().set_flag(CorruptForest.FLAG_SLIMES, true)
	var level: CorruptForest = _load_level()
	await tree.physics_frame
	assert_eq(level.slimes.size(), 0, "打完之後重進關卡不會再生")


func test_title_menu_has_four_entries_and_new_game_works() -> void:
	var boot: Control = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate() as Control
	boot.set("load_levels", false)
	tree.root.add_child(boot)
	await tree.process_frame
	var names: Array[String] = []
	for c: Node in boot.get_node("%Menu").get_children():
		names.append(str(c.name))
	assert_eq(names, ["NewGame", "Continue", "Settings", "Quit"] as Array[String])
	assert_true((boot.get_node("%Continue") as Button).disabled, "沒有存檔：繼續是灰的")
	assert_eq((boot.get_node("%Title") as Label).text, "GAME_TITLE")
	(boot.get_node("%NewGame") as Button).pressed.emit()
	assert_true(_session().in_story(), "按新遊戲開了第一章")
	boot.free()


func test_enemy_brain_cycle_with_slime_numbers() -> void:
	var b: EnemyBrain = EnemyBrain.new().configure("poison_slime", "standard")
	var struck: bool = false
	var seen: Dictionary = {}
	for i: int in 400:
		if b.tick(1.0 / 60.0, 1.0):
			struck = true
		seen[b.state] = true
	assert_true(struck, "在出手距離內會出招")
	for st: EnemyBrain.State in [EnemyBrain.State.TELEGRAPH, EnemyBrain.State.STRIKE, EnemyBrain.State.RECOVER]:
		assert_true(seen.has(st), "經過 %s" % EnemyBrain.State.keys()[st])
	var far: EnemyBrain = EnemyBrain.new().configure("poison_slime", "standard")
	for i: int in 120:
		assert_false(far.tick(1.0 / 60.0, 20.0), "太遠不出招")
	assert_true(far.add_stagger(CombatTuning.num("poison_slime.stagger_max")), "失衡滿了會跪")
	assert_eq(far.state, EnemyBrain.State.STAGGERED)
	far.kill()
	assert_eq(far.state, EnemyBrain.State.DEAD)
