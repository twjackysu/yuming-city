extends TestCase
## StaticBatch：同材質合併成一個 MeshInstance3D、碰撞形狀一個不少。


func test_merges_by_material() -> void:
	var look := FrostbridgeLook.new()
	var a := look.mat(Color(0.2, 0.2, 0.2))
	var b := look.mat(Color(0.5, 0.1, 0.1))
	assert_true(look.mat(Color(0.2, 0.2, 0.2)) == a, "同色共用同一個材質")
	var batch := StaticBatch.new()
	batch.add_box_at(Vector3(1, 1, 1), Vector3(0, 0.5, 0), a)
	batch.add_box_at(Vector3(2, 1, 1), Vector3(10, 0.5, 0), a)
	batch.add_box_at(Vector3(1, 3, 1), Vector3(0, 1.5, 5), b, false)
	batch.add_cylinder(0.5, 0.5, 1.0, Vector3(-4, 0.5, 0), b)
	assert_eq(batch.material_count(), 2)
	assert_eq(batch.shape_count(), 3, "不碰撞的方塊沒有形狀")
	assert_eq(batch.mesh_count, 4)
	var parent := Node3D.new()
	tree.root.add_child(parent)
	var root: Node3D = batch.build(parent, "Town")
	assert_eq(str(root.name), "Town")
	var meshes: int = 0
	var aabb := AABB()
	for c: Node in root.get_children():
		if c is MeshInstance3D:
			meshes += 1
			var mi: MeshInstance3D = c as MeshInstance3D
			aabb = mi.get_aabb() if meshes == 1 else aabb.merge(mi.get_aabb())
	assert_eq(meshes, 2, "兩種材質 → 兩個 MeshInstance3D")
	assert_true(aabb.position.x <= -4.4 and aabb.end.x >= 10.9, "合併後的範圍涵蓋所有方塊：%s" % aabb)
	var body: StaticBody3D = root.get_node("Collision") as StaticBody3D
	assert_eq(body.get_child_count(), 3)
	assert_true((body.get_child(1) as CollisionShape3D).position.is_equal_approx(Vector3(10, 0.5, 0)), "碰撞形狀的位置")
	assert_true((body.get_child(2) as CollisionShape3D).shape is CylinderShape3D)
	parent.queue_free()
	await tree.process_frame
