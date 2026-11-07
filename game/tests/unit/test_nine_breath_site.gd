extends TestCase
## 九息石拱（場景物件）：靠近提示與代價、按住預覽不付代價、放開取消、按滿發動、九息期間有碰撞與去飽和、
## 站在裡面被推出、化灰後記憶已付、讀檔後狀態正確；鐵架拋擲的兩種結局。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Input.action_release("nine_breath")


func _world(st: GameState) -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var env := Environment.new()
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(40, 1, 40)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.position = Vector3(0, 0, 3)
	root.add_child(player)
	var site := NineBreathSite.new()
	site.state = st
	root.add_child(site)
	return [root, player, site, env]


func test_prompt_preview_and_cancel() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var site: NineBreathSite = w[2]
	player.global_position = Vector3(0, 0, 12)
	await tree.physics_frame
	await tree.physics_frame
	assert_false(site.prompt_shown(), "離太遠不顯示")
	player.global_position = Vector3(0, 0, 3)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(site.prompt_shown(), "走近顯示可保存")
	assert_true(site.prompt_text().contains("可保存：南街石拱"), site.prompt_text())
	assert_true(site.prompt_text().contains("代價：與父親最後一次在石拱下交談的記憶"), site.prompt_text())
	Input.action_press("nine_breath")
	for i: int in 20:
		await tree.physics_frame
	assert_true(site.is_previewing(), "按住中：預覽輪廓")
	assert_false(st.has_paid_memory("arch_father_last_talk"), "預覽不付代價")
	Input.action_release("nine_breath")
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(site.hold, 0.0, "放開就取消")
	assert_false(site.is_previewing())
	assert_eq(site.nb.phase, NineBreath.Phase.BROKEN)
	assert_false(st.has_paid_memory("arch_father_last_talk"), "取消不付代價")
	root.queue_free()
	await tree.process_frame


func test_activate_breaths_and_spend() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	var env: Environment = w[3]
	await tree.physics_frame
	assert_false(site.update_hold(0.5, true), "按住 0.5 秒還沒發動")
	assert_true(site.update_hold(0.55, true), "按滿 1 秒發動")
	assert_true(st.has_paid_memory("arch_father_last_talk"), "付出記憶")
	assert_true(site.is_solid(), "石拱是實體")
	await tree.create_timer(0.7).timeout
	assert_true(env.adjustment_saturation < 0.3, "畫面去飽和（%.2f）" % env.adjustment_saturation)
	# 石拱的柱子擋得住（射線打中）
	await tree.physics_frame
	await tree.physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(-2.2, 1.0, 3.0), Vector3(-2.2, 1.0, -3.0))
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
	assert_false(hit.is_empty(), "九息期間有完整碰撞")
	var n: Array[int] = [0]
	site.breath.connect(func(_i: int) -> void: n[0] += 1)
	for i: int in 10:
		site.nb.tick(1.0, st)
	assert_eq(n[0], 9, "九聲心跳")
	assert_eq(site.nb.phase, NineBreath.Phase.SPENT, "化灰")
	assert_false(site.is_solid())
	assert_eq(st.get_flag("ninebreath.south_arch"), "spent")
	await tree.create_timer(1.4).timeout
	assert_true(absf(env.adjustment_saturation - 0.85) < 0.01, "飽和度恢復（%.2f）" % env.adjustment_saturation)
	assert_false(site.update_hold(2.0, true), "化灰後不能再發動")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_push_out_and_reload() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	player.global_position = Vector3(-2.0, 0.0, 0.2)
	site.activate()
	assert_true(player.global_position.z >= 1.3, "站在柱子裡被推出去（z=%.2f）" % player.global_position.z)
	# 九息中間存的檔：讀回來視為已化灰（代價已付、不能再發動）
	var loaded := GameState.from_dict(st.to_dict())
	root.queue_free()
	await tree.process_frame
	var w2: Array = _world(loaded)
	var root2: Node3D = w2[0]
	var site2: NineBreathSite = w2[2]
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(site2.nb.phase, NineBreath.Phase.SPENT, "讀檔後是化灰")
	assert_false(site2.is_solid())
	assert_false(site2.prompt_shown(), "化灰後沒有提示")
	assert_true(loaded.has_paid_memory("arch_father_last_talk"))
	root2.queue_free()
	await tree.process_frame


func test_frame_throw_outcomes() -> void:
	var st := GameState.new()
	var e := FrameThrowEvent.new()
	var got: Array[String] = []
	e.resolved.connect(func(o: String) -> void: got.append(o))
	e.tick(3.0, false, st)
	assert_false(e.is_resolved(), "舉起鐵架中")
	e.tick(1.1, true, st)
	assert_eq(e.outcome, "arch", "落下時石拱是實體：擋下")
	assert_eq(st.get_flag("slice.frame_throw_outcome"), "arch")
	assert_eq(st.get_flag("sheila.kindling_used_early", false), false, "席菈不用燒劍")
	e.tick(5.0, false, st)
	assert_eq(got, ["arch"] as Array[String], "只結算一次")
	var st2 := GameState.new()
	var e2 := FrameThrowEvent.new()
	e2.tick(4.5, false, st2)
	assert_eq(e2.outcome, "kindling", "拒絕九息：薪火劍")
	assert_eq(st2.get_flag("sheila.kindling_used_early"), true)
