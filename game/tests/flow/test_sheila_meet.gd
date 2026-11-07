extends TestCase
## 段落 4「席菈」：救出三人 → 席菈在主街北段出現 → 走近開始對話（說實話／說謊）→ 灰巡者協作戰 → 打倒 → 護送車隊。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_sheila_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _session(rescued: int) -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_game()
	s.set_flag("slice.met_pear_seller", true)
	for i: int in 9:
		s.add_flag("slice.bell_rings")
	if rescued > 0:
		s.add_flag("slice.rescued_count", rescued)
	return s


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


## 把對話走完；choice＝遇到選項時按第幾個。
func _run_dialogue(level: Node, choice: int) -> void:
	var game: Node = tree.root.get_node("Game")
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	var choices: Node = box.find_child("Choices", true, false)
	for i: int in 40:
		if not bool(game.call("is_in_dialogue")):
			break
		if choices.get_child_count() > 0:
			(choices.get_child(choice) as Button).pressed.emit()
		else:
			box.press_continue()
		await tree.process_frame


func _meet(choice: int) -> Dictionary:
	var s := _session(3)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "meet_sheila")
	var level: StoryLevel = await _load()
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	assert_not_null(sheila, "席菈在主街北段")
	assert_false(level.has_node("Ashwalker"), "還沒說話：沒有灰巡者")
	sheila.set_physics_process(false)
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.global_position = sheila.global_position + Vector3(1.2, 0.05, 0.8)
	for i: int in 3:
		await tree.physics_frame
	assert_true(tree.root.get_node("Game").call("is_in_dialogue"), "走近席菈 → 對話")
	var puppet: Puppet = player.find_child("Puppet", true, false) as Puppet
	assert_false(puppet.has_splint(), "上夾板之前右手沒有夾板")
	await _run_dialogue(level, choice)
	assert_eq(s.state.get_flag("slice.sheila_talked"), true)
	assert_true(puppet.has_splint(), "說完話：右前臂綁上夾板")
	var walker: Ashwalker = level.get_node_or_null("Ashwalker") as Ashwalker
	assert_not_null(walker, "說完話 → 灰巡者從裂縫爬出來")
	assert_eq(s.state.get_flag("tutorial.insight_shown"), true, "第一次遇到灰巡者：看穿／打弱點教學")
	if walker != null:
		walker.set_physics_process(false)  # 別讓諾恩真的倒下
		assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "meet_sheila", "還沒打倒灰巡者")
		walker.health.apply_damage(walker.health.hp + 1.0, {"stagger": 0.0})
		await tree.physics_frame
	assert_eq(s.state.get_flag("slice.ashwalker_defeated"), true)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "escort_convoy", "打倒灰巡者 → 護送車隊")
	var told: Variant = s.state.get_flag("slice.told_truth_about_bell")
	level.queue_free()
	await tree.process_frame
	await tree.process_frame
	return {"told_truth": told}


func test_meet_sheila_tell_truth() -> void:
	var r: Dictionary = await _meet(0)
	assert_eq(r["told_truth"], true, "說九下")


func test_meet_sheila_lie() -> void:
	var r: Dictionary = await _meet(1)
	assert_eq(r["told_truth"], false, "說八下（她也數了）")


func test_sheila_appears_after_third_rescue_in_level() -> void:
	_session(2)
	var level: StoryLevel = await _load()
	assert_false(level.has_node("Sheila"), "救援中席菈還沒出現")
	var sites: Array[RescueSite] = []
	for c: Node in level.get_children():
		if c is RescueSite:
			(c as RescueSite).set_physics_process(false)
			sites.append(c as RescueSite)
	sites[0].rescue()
	assert_true(level.has_node("Sheila"), "救出第三人 → 席菈出現")
	level.queue_free()
	await tree.process_frame
	await tree.process_frame


## 段落 6「收束」：車隊通過後回到梨販攤 → 艾妲對話 → 走進地窖 → 切片完成。
func test_aftermath_ada_then_cellar_completes_slice() -> void:
	var s := _session(4)
	s.set_flag("slice.sheila_talked", true)
	s.set_flag("slice.ashwalker_defeated", true)
	s.set_flag("slice.convoy_through", true)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "aftermath")
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	var cellar: Vector3 = (level.get_node("CellarTrigger") as Node3D).global_position
	# 還沒跟艾妲說話：地窖不算數
	player.global_position = Vector3(cellar.x, 0.05, cellar.z)
	for i: int in 3:
		await tree.physics_frame
	assert_ne(s.state.get_flag("slice.cellar_entered", false), true, "先跟艾妲說話")
	player.global_position = Vector3(3.2, 0.05, 0.6)
	for i: int in 3:
		await tree.physics_frame
	assert_true(tree.root.get_node("Game").call("is_in_dialogue"), "回到梨販攤 → 艾妲")
	await _run_dialogue(level, 0)
	assert_eq(s.state.get_flag("slice.ada_talked_aftermath"), true)
	player.global_position = Vector3(0.0, 0.05, 2.0)
	for i: int in 2:
		await tree.physics_frame
	player.global_position = Vector3(cellar.x, 0.05, cellar.z)
	for i: int in 3:
		await tree.physics_frame
	assert_eq(s.state.get_flag("slice.cellar_entered"), true, "走進地窖")
	assert_true(s.is_slice_complete(), "切片完成")
	level.queue_free()
	await tree.process_frame
	await tree.process_frame
