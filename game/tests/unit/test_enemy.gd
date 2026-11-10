extends TestCase
## 灰巡者：狀態機（追 → 前兆 → 出招 → 破綻）、失衡跪地、爪擊命中與閃避無敵。


func test_brain_cycle() -> void:
	var b := EnemyBrain.new().configure("ashwalker")
	assert_eq(b.state_name(), "idle")
	assert_false(b.tick(0.1, 30.0), "太遠不追")
	b.tick(0.1, 10.0)
	assert_eq(b.state_name(), "chase", "進入範圍開始追")
	b.tick(0.1, 1.0)
	assert_eq(b.state_name(), "telegraph", "近身開始前兆")
	assert_eq(b.telegraph_sec, 0.8, "前兆長度照數值表（標準）")
	assert_false(b.tick(0.5, 1.0), "前兆中不出招")
	assert_true(b.telegraph_progress() > 0.5)
	assert_true(b.tick(0.31, 1.0), "前兆結束出招")
	assert_eq(b.state_name(), "strike")
	b.tick(0.2, 1.0)
	assert_eq(b.state_name(), "recover", "出招後破綻")
	b.tick(0.61, 1.0)
	assert_eq(b.state_name(), "chase", "破綻結束繼續追")


func test_story_difficulty_longer_telegraph() -> void:
	var b := EnemyBrain.new().configure("ashwalker", "story")
	assert_true(absf(b.telegraph_sec - 0.8 * 1.3) < 0.001, "故事難度前兆 ×1.3")


func test_stagger_interrupts_telegraph() -> void:
	var b := EnemyBrain.new().configure("ashwalker")
	b.tick(0.1, 10.0)
	b.tick(0.1, 1.0)
	assert_eq(b.state_name(), "telegraph")
	# 前兆中硬撐（失衡 ×0.5）：要六下 20 才滿 60
	for i: int in 5:
		assert_false(b.add_stagger(20.0))
	assert_true(b.add_stagger(20.0), "失衡 60 滿了打斷前兆、跪地")
	assert_eq(b.state_name(), "staggered")
	assert_false(b.tick(1.0, 1.0), "跪地中不出招")
	b.tick(1.1, 1.0)
	assert_eq(b.state_name(), "chase", "2 秒後起身")
	assert_eq(b.stagger, 0.0, "失衡歸零")


## 跪下的那一刻發 knelt（D-191）：跪著再被逼跪（撞牆）不再發；起身後再跪才又發。
func test_knelt_signal_once_per_kneel() -> void:
	var b := EnemyBrain.new().configure("ashwalker")
	var count: Array[int] = [0]
	b.knelt.connect(func() -> void: count[0] += 1)
	b.tick(0.1, 10.0)
	assert_true(b.add_stagger(999.0))
	assert_eq(count[0], 1, "失衡滿了跪下 → 發一次")
	b.force_kneel(1.5)
	assert_false(b.add_stagger(999.0), "跪著不再累積")
	assert_eq(count[0], 1, "已經跪著：不再發")
	b.tick(3.0, 1.0)
	assert_eq(b.state_name(), "chase")
	b.force_kneel(1.0)
	assert_eq(count[0], 2, "起身後撞牆跪下 → 再發一次")
	b.kill()
	assert_eq(count[0], 2, "死掉不算跪")


func test_ashwalker_claws_player_and_dodge_avoids() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(20, 1, 20)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var walker := Ashwalker.new()
	root.add_child(walker)
	walker.global_position = player.global_position + Vector3(0, 0, -1.4)
	var hp0: float = player.health.hp
	for i: int in 120:
		await tree.physics_frame
		if player.health.hp < hp0:
			break
	assert_eq(player.health.hp, hp0 - 14.0, "爪擊 14")
	# 下一輪前兆時閃避無敵
	for i: int in 120:
		await tree.physics_frame
		if walker.brain.state == EnemyBrain.State.TELEGRAPH and walker.brain.telegraph_progress() > 0.8:
			break
	player.invulnerable = true
	for i: int in 30:
		await tree.physics_frame
	assert_eq(player.health.hp, hp0 - 14.0, "閃避無敵時不扣血")
	player.invulnerable = false
	# 諾恩打三下：失衡跪地
	for i: int in 3:
		walker.health.apply_damage(6.0, {"source": player, "stagger": 20.0})
	assert_eq(walker.brain.state_name(), "staggered", "三次鈍擊讓灰巡者跪地")
	assert_eq(walker.health.hp, 60.0 - 18.0)
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 一團粉要噴在指定的地方（D-208）：CPUParticles3D 一進場景樹就會在當下的位置噴出第一批（一次性的就是全部），
## 所以要先擺好位置才能開始——原本先 add_child 再擺位置，粉其實噴在敵人腳下的原點（燈柱砸藥桶那次偏了 8 m，在鏡頭外）。
func test_ground_puff_starts_emitting_only_after_it_is_placed() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var walker := Ashwalker.new()
	walker.position = Vector3(0, 0, -3)
	root.add_child(walker)
	walker.set_physics_process(false)
	await tree.process_frame
	var built: CPUParticles3D = walker.puff_build(Vector3(0.3, 0.05, 0.3), 12, Color(0.7, 0.7, 0.7, 0.5))
	assert_false(built.emitting, "建好的時候還沒開始噴（不然一進場景樹就噴在原點）")
	assert_false(built.is_inside_tree(), "也還沒進場景樹：要調速度、大小的先調")
	assert_true(built.one_shot, "一次性")
	var far := Vector3(6.0, 0.4, 5.0)
	walker.puff_start(built, far)
	assert_true(built.emitting, "擺好位置才開始噴")
	assert_true(built.global_position.distance_to(far) < 0.001, "在指定的地方，不是敵人腳下")
	var puff: CPUParticles3D = walker._ground_puff(far + Vector3.RIGHT, Vector3(0.3, 0.05, 0.3), 8, Color(0.7, 0.7, 0.7, 0.5))
	assert_true(puff.emitting and puff.global_position.distance_to(far + Vector3.RIGHT) < 0.001, "_ground_puff 走同一條路")
	assert_eq(ParticleLook.untextured(walker).size(), 0, "都是柔邊圓點")
	root.queue_free()
	await tree.process_frame


## 灰巡者倒下（D-054）：跪下 → 向前撲倒（頭在原本面向的前方、貼地）→ 灰粉、胸口的光熄掉 → 沉進雪裡移除；不再壓扁。
func test_ashwalker_dies_falling_forward_not_squashed() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var walker := Ashwalker.new()
	walker.position = Vector3(0, 0, -3)
	root.add_child(walker)
	walker.set_physics_process(false)
	walker._body.rotation.y = deg_to_rad(-40.0)
	await tree.process_frame
	var fwd: Vector3 = walker.forward()
	var origin: Vector3 = walker.global_position
	var prev: float = Engine.time_scale
	Engine.time_scale = 4.0
	walker.health.apply_damage(walker.health.hp, {"stagger": 0.0})
	assert_false(walker.is_in_group("damageable"), "倒下後不再吃傷害")
	assert_eq(walker.collision_layer, 0, "倒下後不再擋路")
	for i: int in 300:
		if walker.has_fallen:
			break
		await tree.process_frame
	assert_true(walker.has_fallen, "撲倒在地")
	var head: Node3D = null
	for c: Node in walker._body.get_children():
		if c is CSGSphere3D:
			head = c as Node3D
	assert_not_null(head, "找得到頭")
	if head != null:
		var rel: Vector3 = head.global_position - origin
		assert_true(rel.dot(fwd) > 0.9, "向前倒：頭在原本面向的前方（%.2f m）" % rel.dot(fwd))
		assert_true(head.global_position.y < 0.6, "貼地（頭離地 %.2f m）" % head.global_position.y)
	assert_true(absf(walker._body.scale.y - 1.0) < 0.001, "不再壓扁")
	assert_true(walker.has_node("FallPuff"), "落地揚起灰粉")
	var puff: CPUParticles3D = walker.get_node("FallPuff") as CPUParticles3D
	var puff_mat: StandardMaterial3D = (puff.mesh as QuadMesh).material as StandardMaterial3D
	assert_true(puff_mat.albedo_texture is GradientTexture2D, "灰粉是柔邊圓點，不是硬邊方塊")
	var glow: StandardMaterial3D = walker._claw_mat
	for i: int in 600:
		if glow.emission_energy_multiplier < 0.05 or not is_instance_valid(walker):
			break
		await tree.process_frame
	assert_true(glow.emission_energy_multiplier < 0.05, "胸口與爪上的光熄掉（%.2f）" % glow.emission_energy_multiplier)
	assert_true(is_instance_valid(walker), "光熄掉時還躺在地上")
	for i: int in 600:
		if not is_instance_valid(walker):
			break
		await tree.process_frame
	Engine.time_scale = prev
	assert_false(is_instance_valid(walker), "躺一會兒後沉進雪裡、移除")
	root.queue_free()
	await tree.process_frame
