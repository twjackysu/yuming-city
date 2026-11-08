extends TestCase
## 過肩鏡頭（D-072）：探索時鏡頭在諾恩右後方、戰鬥／鎖定時收小、貼牆時收回不穿牆、角色擋到不算。


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
	player.global_position = Vector3.ZERO
	player.snap_camera()
	return [root, player]


func _camera(player: PlayerController) -> Camera3D:
	return player.get_node("CameraRig/Pitch/SpringArm3D/Camera3D") as Camera3D


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


## 諾恩胸口在鏡頭座標裡的位置（x < 0＝畫面左邊）
func _player_in_camera(player: PlayerController) -> Vector3:
	return _camera(player).global_transform.affine_inverse() * (player.global_position + Vector3.UP * 1.2)


func test_explore_puts_noen_left_of_center() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	await _frames(5)
	assert_true(absf(player.shoulder_offset() - PlayerController.SHOULDER_OFFSET) < 0.01, "探索時過肩 %.2f m（%.2f）" % [PlayerController.SHOULDER_OFFSET, player.shoulder_offset()])
	var p: Vector3 = _player_in_camera(player)
	assert_true(p.x < -0.7, "諾恩在鏡頭左邊（鏡頭座標 x=%.2f）" % p.x)
	assert_true(p.z < 0.0, "諾恩在鏡頭前面")
	root.queue_free()
	await tree.process_frame


func test_combat_and_lock_shrink_offset() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var w := Ashwalker.new()
	w.position = Vector3(0, 0, -12)
	w.set_physics_process(false)
	root.add_child(w)
	await _frames(45)
	assert_true(absf(player.shoulder_offset() - PlayerController.SHOULDER_OFFSET_COMBAT) < 0.01, "戰鬥中收小（%.2f）" % player.shoulder_offset())
	assert_eq(player.toggle_lock(), w)
	await _frames(10)
	assert_true(absf(player.shoulder_offset() - PlayerController.SHOULDER_OFFSET_COMBAT) < 0.01, "鎖定時也是收小的（%.2f）" % player.shoulder_offset())
	root.queue_free()
	await tree.process_frame


func test_wall_on_right_pulls_camera_in() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	await _frames(3)
	# yaw 0：鏡頭的右邊是 +X。牆的左面在 x=0.9
	var wall := CSGBox3D.new()
	wall.size = Vector3(0.2, 4, 8)
	wall.position = Vector3(1.0, 2, 0)
	wall.use_collision = true
	root.add_child(wall)
	await _frames(2)
	var room: float = 0.9 - PlayerController.SHOULDER_MARGIN
	assert_true(player.shoulder_offset() <= room + 0.02, "貼牆立刻收回（%.2f ≤ %.2f）" % [player.shoulder_offset(), room])
	assert_true(player.shoulder_offset() >= 0.0, "不會變成往左偏")
	assert_true(_camera(player).global_position.x < 0.9 - 0.1, "鏡頭沒有穿進牆（x=%.2f）" % _camera(player).global_position.x)
	# 牆拿掉：慢慢放回去，不是一幀跳回
	wall.queue_free()
	await _frames(2)
	assert_true(player.shoulder_offset() < PlayerController.SHOULDER_OFFSET - 0.1, "離開牆邊不是瞬間跳回（%.2f）" % player.shoulder_offset())
	await _frames(40)
	assert_true(absf(player.shoulder_offset() - PlayerController.SHOULDER_OFFSET) < 0.01, "一下子就回到 %.2f（%.2f）" % [PlayerController.SHOULDER_OFFSET, player.shoulder_offset()])
	root.queue_free()
	await tree.process_frame


func test_characters_do_not_push_camera() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	# 一個站在諾恩右手邊的人（不是敵人，不會觸發戰鬥距離）
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	body.add_child(shape)
	body.position = Vector3(0.8, 0, 0)
	root.add_child(body)
	await _frames(10)
	assert_true(absf(player.shoulder_offset() - PlayerController.SHOULDER_OFFSET) < 0.01, "席菈或路人站在右邊不會把鏡頭推進來（%.2f）" % player.shoulder_offset())
	root.queue_free()
	await tree.process_frame


## D-085：角色站在諾恩正後方（鏡頭那一側）時，SpringArm 不被拉近；牆照樣會把鏡頭拉近。
func test_body_behind_does_not_pull_camera_but_wall_does() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var arm: SpringArm3D = player.get_node("CameraRig/Pitch/SpringArm3D") as SpringArm3D
	# 後來才生成的角色（像送葬者、席菈）：一面寬 3.5 m、高 3 m 的身體擋在鏡頭與諾恩之間
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.5, 3.0, 0.4)
	shape.shape = box
	shape.position = Vector3(0.75, 1.5, 0)
	body.add_child(shape)
	body.position = Vector3(0, 0, 1.8)
	root.add_child(body)
	await _frames(10)
	assert_true(arm.get_hit_length() > arm.spring_length - 0.05, "角色擋在身後不拉近鏡頭（%.2f / %.2f）" % [arm.get_hit_length(), arm.spring_length])
	body.queue_free()
	# 同樣位置換成牆：鏡頭照樣收回，不穿牆
	var wall := StaticBody3D.new()
	var wshape := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(3.5, 3.0, 0.4)
	wshape.shape = wbox
	wshape.position = Vector3(0.75, 1.5, 0)
	wall.add_child(wshape)
	wall.position = Vector3(0, 0, 1.8)
	root.add_child(wall)
	await _frames(10)
	assert_true(arm.get_hit_length() < arm.spring_length - 0.5, "牆在身後會把鏡頭拉近（%.2f / %.2f）" % [arm.get_hit_length(), arm.spring_length])
	root.queue_free()
	await tree.process_frame
