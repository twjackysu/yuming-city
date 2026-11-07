extends TestCase
## 鎖定：挑目標（鏡頭前方優先、15 公尺內）、鏡頭轉向目標、遠離或死亡自動解除、席菈跟著打鎖定目標。


func _arena() -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(60, 1, 60)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	return [root, player]


func _walker(root: Node3D, pos: Vector3) -> Ashwalker:
	# 先設位置再進樹：不然牠會先出現在原點、跟諾恩重疊，把諾恩頂到頭上當平台載走
	var w := Ashwalker.new()
	w.position = pos
	w.set_physics_process(false)
	root.add_child(w)
	return w


func test_pick_prefers_camera_front() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var front := _walker(root, Vector3(0, 0, -8))
	var side := _walker(root, Vector3(4, 0, 0))
	var far := _walker(root, Vector3(0, 0, -20))
	await tree.process_frame
	var fwd := Vector3(0, 0, -1)
	assert_eq(PlayerController.pick_lock_target(Vector3.ZERO, fwd, [front, side, far]), front, "前方較遠的優先於側邊較近的")
	assert_eq(PlayerController.pick_lock_target(Vector3.ZERO, fwd, [side, far]), side, "前方沒有就挑最近的")
	assert_eq(PlayerController.pick_lock_target(Vector3.ZERO, fwd, [far]), null, "15 公尺外不能鎖")
	root.queue_free()
	await tree.process_frame


func test_lock_turns_camera_and_releases() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	player.global_position = Vector3.ZERO
	player.yaw = 0.0
	var w := _walker(root, Vector3(6, 0, -6))
	await tree.physics_frame
	assert_eq(player.toggle_lock(), w)
	for i: int in 90:
		await tree.physics_frame
	var want: float = atan2(-6.0, 6.0)
	assert_true(absf(angle_difference(player.yaw, want)) < 0.1, "鏡頭轉向目標（yaw %.2f，目標 %.2f）" % [player.yaw, want])
	w.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(player.lock_target, null, "超過 15 公尺自動解除")
	w.global_position = Vector3(0, 0, -5)
	player.toggle_lock()
	assert_eq(player.lock_target, w)
	w.health.apply_damage(999.0)
	await tree.physics_frame
	assert_eq(player.lock_target, null, "目標倒下自動解除")
	assert_eq(player.toggle_lock(), null, "沒有可鎖的目標")
	root.queue_free()
	await tree.process_frame


func test_sheila_attacks_locked_target() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	player.global_position = Vector3.ZERO
	var near := _walker(root, Vector3(2, 0, 1))
	var locked := _walker(root, Vector3(0, 0, -7))
	var sheila := Sheila.new()
	root.add_child(sheila)
	sheila.global_position = Vector3(1.5, 0, 1.5)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(sheila.target, near, "沒鎖定時打離她最近的")
	player.lock_target = locked
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(sheila.target, locked, "鎖定後打諾恩鎖定的目標")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_switch_target_left_right() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var cur := _walker(root, Vector3(0, 0, -6))
	var right_near := _walker(root, Vector3(3, 0, -6))
	var right_far := _walker(root, Vector3(7, 0, -6))
	var left := _walker(root, Vector3(-3, 0, -6))
	await tree.process_frame
	var all: Array = [cur, right_near, right_far, left]
	assert_eq(PlayerController.pick_switch_target(Vector3.ZERO, cur, 1, all), right_near, "往右：右邊最近的角度")
	assert_eq(PlayerController.pick_switch_target(Vector3.ZERO, cur, -1, all), left, "往左")
	assert_eq(PlayerController.pick_switch_target(Vector3.ZERO, left, -1, all), null, "最左邊再往左：沒有")
	root.queue_free()
	await tree.process_frame


func test_lock_released_when_blocked_by_wall() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	player.global_position = Vector3.ZERO
	var w := _walker(root, Vector3(0, 0, -8))
	await tree.physics_frame
	assert_eq(player.toggle_lock(), w)
	var wall := CSGBox3D.new()
	wall.size = Vector3(6, 4, 0.5)
	wall.position = Vector3(0, 2, -4)
	wall.use_collision = true
	root.add_child(wall)
	for i: int in 60:
		await tree.physics_frame
	assert_eq(player.lock_target, w, "被擋 1 秒：還鎖著")
	assert_true(player.lock_blocked > 0.5, "計時中（%.2f）" % player.lock_blocked)
	for i: int in 40:
		await tree.physics_frame
	assert_eq(player.lock_target, null, "被擋超過 1.5 秒：解除")
	root.queue_free()
	await tree.process_frame


func test_combat_camera_pulls_back() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	player.global_position = Vector3.ZERO
	await tree.physics_frame
	assert_true(absf(player.camera_distance() - 3.2) < 0.01, "探索 3.2 m")
	var _w := _walker(root, Vector3(0, 0, -12))
	for i: int in 45:
		await tree.physics_frame
	assert_true(absf(player.camera_distance() - 4.2) < 0.01, "戰鬥中拉遠到 4.2 m（%.2f）" % player.camera_distance())
	player.toggle_lock()
	for i: int in 45:
		await tree.physics_frame
	assert_true(absf(player.camera_distance() - 3.2) < 0.01, "鎖定時回到 3.2 m（%.2f）" % player.camera_distance())
	root.queue_free()
	await tree.process_frame
