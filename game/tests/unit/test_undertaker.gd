extends TestCase
## 送葬者第一階段：招式輪替與距離、各招前兆長度、橫掃／下砸／衝撞命中、撞牆跪地、
## 第二階段看穿「下砸」變未證實、鐵架關節只在背後露出。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Engine.time_scale = 1.0


func _finish_move(b: EnemyBrain, dist: float) -> void:
	b.tick(b.telegraph_sec + 0.01, dist)
	b.tick(b.strike_sec + 0.01, dist)
	b.tick(b.recover_sec + 0.01, dist)


func test_pattern_and_ranges() -> void:
	var b := EnemyBrain.new().configure("undertaker")
	b.tick(0.1, 10.0)
	assert_eq(b.state_name(), "chase")
	b.tick(0.01, 2.0)
	assert_eq(b.state_name(), "telegraph")
	assert_eq(b.move_id, "sweep", "第一招橫掃")
	assert_true(absf(b.telegraph_sec - 0.9) < 0.001, "橫掃前兆 0.9")
	_finish_move(b, 2.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "slam", "第二招下砸")
	assert_true(absf(b.telegraph_sec - 1.0) < 0.001, "第一階段下砸前兆與攻略一致 1.0")
	assert_true(absf(b.recover_sec - 0.6) < 0.001, "砸地後破綻 0.6")
	_finish_move(b, 2.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "sweep")
	_finish_move(b, 2.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "sweep", "近身時衝撞不合距離，跳過")
	_finish_move(b, 7.0)
	b.tick(0.01, 7.0)
	assert_eq(b.move_id, "charge", "拉開距離就衝撞")
	assert_eq(b.current_move(), "charge")
	var story := EnemyBrain.new().configure("undertaker", "story")
	story.tick(0.1, 10.0)
	story.tick(0.01, 2.0)
	assert_true(absf(story.telegraph_sec - 0.9 * 1.3) < 0.001, "故事難度前兆 ×1.3")


func test_force_kneel() -> void:
	var b := EnemyBrain.new().configure("undertaker")
	b.force_kneel(2.0)
	assert_eq(b.state_name(), "staggered")
	b.tick(1.9, 5.0)
	assert_eq(b.state_name(), "staggered")
	b.tick(0.2, 5.0)
	assert_eq(b.state_name(), "chase", "撞牆跪地 2 秒")


func test_frame_joint_exposed_from_behind() -> void:
	var fwd := Vector3(0, 0, -1)
	var arc: Vector2 = EnemyIntel.arc_of(EnemyIntel.weakpoint("undertaker", "frame_joint"))
	assert_true(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(0, 0, 3), arc), "正後方")
	assert_true(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(-1, 0, 2), arc), "左後方")
	assert_false(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(0, 0, -3), arc), "正面打不到")
	assert_false(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(3, 0, 0), arc), "側面打不到")


func _arena(with_wall: bool = false) -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(40, 1, 40)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	if with_wall:
		var wall := CSGBox3D.new()
		wall.size = Vector3(10, 4, 1)
		wall.position = Vector3(0, 2, -14)
		wall.use_collision = true
		root.add_child(wall)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var boss := Undertaker.new()
	root.add_child(boss)
	return [root, player, boss]


func test_sweep_then_slam_hit_player() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	player.global_position = Vector3(0, 0, 0)
	boss.global_position = Vector3(0, 0, -2.0)
	var hp0: float = player.health.hp
	for i: int in 150:
		await tree.physics_frame
		if player.health.hp < hp0:
			break
	assert_eq(player.health.hp, hp0 - 28.0, "橫掃 28")
	for i: int in 200:
		await tree.physics_frame
		if player.health.hp < hp0 - 28.0:
			break
	assert_eq(boss.brain.move_id, "slam")
	assert_eq(player.health.hp, hp0 - 28.0 - 40.0, "下砸 40")
	assert_true(boss.brain.is_open() or boss.brain.state == EnemyBrain.State.STRIKE, "砸地後是破綻")
	root.queue_free()
	await tree.process_frame


func test_charge_into_wall_kneels() -> void:
	var a: Array = _arena(true)
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	# 諾恩站在牆前，送葬者在遠處；出招瞬間諾恩往旁邊閃開，送葬者直直撞上牆
	player.global_position = Vector3(0, 0, -11.5)
	boss.global_position = Vector3(0, 0, -4.0)
	var knelt: bool = false
	var charged: bool = false
	for i: int in 240:
		await tree.physics_frame
		charged = charged or boss.brain.current_move() == "charge"
		if boss.brain.state == EnemyBrain.State.STRIKE and player.global_position.x < 1.0:
			player.global_position = Vector3(4.0, 0, -11.5)
		if boss.brain.state == EnemyBrain.State.STAGGERED:
			knelt = true
			break
	assert_true(charged, "距離 7.5 公尺：衝撞")
	assert_true(knelt, "撞牆跪地")
	assert_true(boss.global_position.z < -10.0, "衝到牆邊（z=%.2f）" % boss.global_position.z)
	assert_eq(player.health.hp, player.health.max_hp, "閃開了沒被撞到")
	root.queue_free()
	await tree.process_frame


func test_phase_two_makes_slam_unverified() -> void:
	TranslationServer.set_locale("zh_TW")
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	assert_eq(boss.health.hp, 900.0)
	var lines: PackedStringArray = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：鐵架下砸（已證實）"))
	boss.health.apply_damage(460.0, {"stagger": 0.0})
	assert_eq(boss.phase, 2, "生命 450 以下進入第二階段")
	lines = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：鐵架下砸（未證實？）"), "攻略開始失準：" + ", ".join(lines))
	assert_true(absf(boss.brain.move_num("slam", "telegraph") - 0.7) < 0.001, "下砸前兆縮短到 0.7")
	root.queue_free()
	await tree.process_frame
