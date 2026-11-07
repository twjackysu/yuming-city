extends TestCase
## 送葬者戰串接：鐵架拋擲時送葬者站定舉起鐵架 → 石拱擋下或薪火劍 → 車隊抵達＝結束（旗標、送葬者被斬倒）。


func _world(st: GameState) -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(60, 1, 60)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.position = Vector3(-8, 0, 8)
	root.add_child(player)
	var site := NineBreathSite.new()
	site.state = st
	site.position = Vector3(0, 0, -9)
	root.add_child(site)
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(6, 0, 0), Vector3(6, 0, -20)])
	root.add_child(caravan)
	caravan.runner.speed = 0.0
	var boss := Undertaker.new()
	boss.state = st
	boss.position = Vector3(-6, 0, -20)
	root.add_child(boss)
	var enc := ConvoyEncounter.new().setup(boss, caravan, site)
	enc.state = st
	root.add_child(enc)
	return [root, player, site, caravan, boss, enc]


func test_throw_windup_then_arch_blocks() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	var boss: Undertaker = w[4]
	var enc: ConvoyEncounter = w[5]
	var banners: Array[String] = []
	enc.banner.connect(func(k: String, _s: float) -> void: banners.append(k))
	await tree.physics_frame
	boss.enter_phase_two()
	boss.health.apply_damage(boss.health.hp - 280.0, {"stagger": 0.0})
	await tree.physics_frame
	await tree.physics_frame
	assert_true(boss.frame_thrown, "生命 ≤ 300：拋擲")
	assert_not_null(enc.frame_throw, "遭遇戰接到拋擲")
	assert_true(boss.throw_windup > 0.0, "送葬者站定舉起鐵架")
	assert_eq(banners, ["FRAME_THROW_WARN"] as Array[String])
	var pos0: Vector3 = boss.global_position
	var state0: int = boss.brain.state
	for i: int in 10:
		await tree.physics_frame
	assert_true(boss.global_position.distance_to(pos0) < 0.05, "舉鐵架時不移動")
	assert_eq(boss.brain.state, state0, "舉鐵架時不出招")
	site.update_hold(1.1, true)
	assert_true(site.is_solid())
	enc.frame_throw.tick(5.0, site.is_solid(), st)
	assert_eq(st.get_flag("slice.frame_throw_outcome"), "arch", "石拱擋下")
	assert_eq(boss.throw_windup, 0.0)
	assert_eq(boss.brain.state, EnemyBrain.State.STAGGERED, "擲完失去平衡")
	assert_true(banners.has("FRAME_THROW_ARCH"))
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_convoy_arrival_ends_fight() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var caravan: Caravan = w[3]
	var boss: Undertaker = w[4]
	var enc: ConvoyEncounter = w[5]
	var ended: Array[int] = [-1]
	enc.finished.connect(func(n: int) -> void: ended[0] = n)
	await tree.physics_frame
	caravan.runner.hit()
	caravan.runner.stop_left = 0.0
	caravan.runner.traveled = 19.5
	caravan.runner.speed = 5.0
	for i: int in 30:
		await tree.physics_frame
		if enc.done:
			break
	assert_true(enc.done, "車隊抵達：戰鬥結束")
	assert_eq(ended[0], 1, "傷者 1 人")
	assert_eq(st.get_flag("slice.convoy_done"), true)
	assert_eq(st.get_flag("slice.convoy_injured"), 1)
	assert_true(int(st.get_flag("sheila.hand_injury", 0)) >= 1, "結尾燒劍斬倒送葬者：手傷 +1")
	assert_true(boss.health.is_dead(), "送葬者被薪火劍斬倒")
	var injury: int = int(st.get_flag("sheila.hand_injury", 0))
	enc.finish()
	assert_eq(ended[0], 1, "只結束一次")
	assert_eq(int(st.get_flag("sheila.hand_injury", 0)), injury, "手傷不重複加")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame
