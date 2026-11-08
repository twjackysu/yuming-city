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


func _add_sheila(root: Node3D, pos: Vector3) -> Sheila:
	var ally := Sheila.new()
	ally.difficulty = "standard"
	ally.position = pos
	root.add_child(ally)
	ally.set_physics_process(false)
	return ally


## 鐵架拋物線：起點、終點、中間比兩端高。
func test_thrown_frame_arc() -> void:
	var f := ThrownFrame.create(Vector3(0, 3, 0), Vector3(0, 3, 10), "arch")
	assert_true(f.position_at(0.0).is_equal_approx(Vector3(0, 3, 0)))
	assert_true(f.position_at(1.0).is_equal_approx(Vector3(0, 3, 10)))
	assert_true(is_equal_approx(f.position_at(0.5).y, 3.0 + ThrownFrame.ARC_HEIGHT), "拋物線頂點")
	f.free()


## 石拱擋下：背上的鐵架不見、飛出去的那副撞上石拱碎成十截、碎片落地不穿地、時間到自己消失。
func test_frame_flies_and_shatters_on_arch() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	var boss: Undertaker = w[4]
	var enc: ConvoyEncounter = w[5]
	await tree.physics_frame
	assert_true(boss.has_frame(), "擲之前鐵架在背上")
	boss.trigger_frame_throw()
	site.update_hold(1.1, true)
	enc.frame_throw.tick(5.0, site.is_solid(), st)
	assert_false(boss.has_frame(), "擲出去了：背上沒有鐵架")
	var f: ThrownFrame = enc.thrown_frame
	assert_not_null(f, "鐵架飛出去")
	f.set_physics_process(false)
	assert_eq(f.outcome, "arch")
	assert_true(f.to.distance_to(site.global_position + Vector3.UP * 3.0) < 0.01, "落點是石拱")
	var impacts: Array[String] = []
	f.impacted.connect(func(o: String) -> void: impacts.append(o))
	f.advance(ThrownFrame.FLIGHT_SEC * 0.5)
	assert_false(f.has_impacted, "飛到一半")
	f.advance(ThrownFrame.FLIGHT_SEC * 0.6)
	assert_eq(impacts, ["arch"] as Array[String], "撞上一次")
	assert_eq(f.pieces.size(), 10, "碎成十截")
	for i: int in 60:
		f.advance(1.0 / 30.0)
	for p: Node3D in f.pieces:
		assert_true(p.position.y >= f.ground_y, "碎片不穿地")
	f.advance(ThrownFrame.DEBRIS_LIFE)
	assert_true(f.is_queued_for_deletion(), "碎片時間到消失")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 燃燒劍路線：席菈在身前把鐵架斬成兩截，劍燒起來、過一下熄掉；結尾斬倒送葬者劍又燒一次。
func test_kindling_cuts_frame_in_front_of_sheila() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var boss: Undertaker = w[4]
	var enc: ConvoyEncounter = w[5]
	var ally: Sheila = _add_sheila(root, Vector3(4, 0, -6))
	await tree.physics_frame
	assert_false(ally.is_sword_lit(), "平常劍是熄的")
	boss.trigger_frame_throw()
	enc.frame_throw.tick(5.0, false, st)
	assert_eq(st.get_flag("slice.frame_throw_outcome"), "kindling")
	assert_true(ally.is_sword_lit(), "燃燒劍點起來")
	var f: ThrownFrame = enc.thrown_frame
	assert_not_null(f)
	f.set_physics_process(false)
	var flat := Vector2(f.to.x - ally.global_position.x, f.to.z - ally.global_position.z)
	assert_true(flat.length() < 1.5, "落點在席菈身前（%.2f）" % flat.length())
	f.advance(ThrownFrame.FLIGHT_SEC + 0.01)
	assert_true(f.has_impacted)
	assert_eq(f.pieces.size(), 2, "斬成兩截")
	ally._fire_tick(5.0)
	assert_false(ally.is_sword_lit(), "火熄了")
	enc.finish()
	assert_true(ally.is_sword_lit(), "結尾斬倒送葬者：劍又燒起來")
	assert_true(boss.health.is_dead())
	assert_eq(int(st.get_flag("sheila.hand_injury", 0)), 2, "提前燒一次＋結尾一次")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


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
