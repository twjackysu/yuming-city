extends TestCase
## 劇情關卡（不是戰鬥場）裡走路：臉朝著走的方向（Jacky 2026-11-14：「主劇情向前會面向後面，向後會面向前面」）。
## 直接量骨架：上（骨盆→頭）×右（左肩→右肩）＝臉朝的方向（世界座標），跟速度的方向比。


func _face_world(player: PlayerController) -> Vector3:
	var sk: Skeleton3D = player.puppet().find_child("*", true, false) as Skeleton3D
	for n: Node in player.puppet().find_children("*", "Skeleton3D", true, false):
		sk = n as Skeleton3D
	if sk == null:
		return Vector3.ZERO
	var at: Array[Vector3] = []
	for j: String in ["hips", "head", "shoulder_L", "shoulder_R"]:
		var b: int = CharacterModels.find_joint_bone(sk, j)
		if b < 0:
			return Vector3.ZERO
		at.append(sk.global_transform * sk.get_bone_global_pose(b).origin)
	var f: Vector3 = (at[1] - at[0]).cross(at[3] - at[2])
	f.y = 0.0
	return f.normalized()


func test_story_noen_faces_the_way_he_walks() -> void:
	var was: bool = Game.arena_mode
	Game.arena_mode = false
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	for i: int in 10:
		await tree.physics_frame
	if _face_world(player) == Vector3.ZERO:
		print("FACING story: 沒有模型（素材沒產生），略過")
	else:
		for action: String in ["move_forward", "move_back", "move_left", "move_right"]:
			Input.action_press(action)
			for i: int in 50:
				await tree.physics_frame
			var v := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
			var f: Vector3 = _face_world(player)
			Input.action_release(action)
			print("FACING story %s: face·velocity = %.2f（1＝臉朝著走的方向）" % [action, f.dot(v)])
			assert_true(f.dot(v) > 0.7, "%s：臉朝著走的方向（%.2f）" % [action, f.dot(v)])
			for i: int in 20:
				await tree.physics_frame
	Game.arena_mode = was
	root.queue_free()
	await tree.process_frame
