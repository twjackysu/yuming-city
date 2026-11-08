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


## D-066：帶頂點色的方塊（窗）——頂點色原樣保留、面內 UV 是 BoxMesh 的 3×2 格、不加碰撞。
func test_tinted_boxes_keep_vertex_color_and_uv() -> void:
	var look := FrostbridgeLook.new()
	var win: ShaderMaterial = look.window()
	assert_true(look.window() == win, "全部的窗共用一個材質")
	var batch := StaticBatch.new()
	var lit: Color = FrostbridgeLook.window_tint(true, Vector3(1, 1.6, 5), 1.5)
	var dark: Color = FrostbridgeLook.window_tint(false, Vector3(-3, 1.6, 5), 1.5)
	batch.add_box_tinted(Vector3(0.7, 0.9, 0.08), Vector3(1, 1.6, 5), win, lit)
	batch.add_box_tinted(Vector3(0.7, 0.9, 0.08), Vector3(-3, 1.6, 5), win, dark)
	assert_eq(batch.material_count(), 1)
	assert_eq(batch.shape_count(), 0, "窗不加碰撞")
	var parent := Node3D.new()
	tree.root.add_child(parent)
	var root: Node3D = batch.build(parent, "Windows")
	var mi: MeshInstance3D = root.get_child(0) as MeshInstance3D
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(colors.size(), 48, "兩個方塊 × 24 個頂點都有頂點色")
	assert_true(colors[0].is_equal_approx(lit) or colors[0].r > 0.5, "第一扇是亮窗")
	assert_true(colors[47].r < 0.5, "第二扇是暗窗")
	var uv_ok: bool = true
	for uv: Vector2 in uvs:
		if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
			uv_ok = false
	assert_true(uv_ok, "UV 在 0..1（shader 用 fract(UV × (3, 2)) 取面內座標）")
	parent.queue_free()
	await tree.process_frame


## D-077：木箱要能擋人——帶頂點色的方塊可以選擇加碰撞盒；木箱的頂點色 r＝0（door.gdshader 的木箱模式）。
func test_tinted_box_optional_collision_and_crate_tint() -> void:
	var batch := StaticBatch.new()
	var crate := ShaderMaterial.new()
	batch.add_box_tinted(Vector3(0.6, 0.6, 0.6), Vector3(1, 0.3, 2), crate, FrostbridgeLook.crate_tint(Vector3(1, 0.3, 2)))
	assert_eq(batch.shape_count(), 0, "預設不加碰撞（窗、門）")
	batch.add_box_tinted(Vector3(0.6, 0.6, 0.6), Vector3(3, 0.3, 2), crate, FrostbridgeLook.crate_tint(Vector3(3, 0.3, 2)), true)
	assert_eq(batch.shape_count(), 1, "collide=true 加一個碰撞盒")
	var t: Color = FrostbridgeLook.crate_tint(Vector3(4.5, 0.45, -1.0))
	assert_eq(t.r, 0.0, "木箱模式 r＝0")
	assert_eq(t, FrostbridgeLook.crate_tint(Vector3(4.5, 0.45, -1.0)), "同一個位置顏色固定")
	var d: Color = FrostbridgeLook.door_tint(Vector3(4.5, 0.45, -1.0))
	assert_true(is_equal_approx(t.g, d.g) and is_equal_approx(t.b, d.b), "木色深淺與舊不舊跟門用同一套雜湊")
	assert_eq(d.r, 1.0, "門 r＝1")


func test_window_tint_is_deterministic_and_in_range() -> void:
	var a: Color = FrostbridgeLook.window_tint(true, Vector3(4.2, 1.6, -12.0), 1.5)
	assert_true(a.is_equal_approx(FrostbridgeLook.window_tint(true, Vector3(4.2, 1.6, -12.0), 1.5)), "同位置同結果")
	assert_eq(FrostbridgeLook.window_tint(false, Vector3(4.2, 1.6, -12.0), 1.5).r, 0.0, "暗窗 r=0")
	var curtains: int = 0
	var energies: Array[float] = []
	for i: int in 60:
		var c: Color = FrostbridgeLook.window_tint(true, Vector3(i * 2.3 - 40.0, 1.6 + (i % 2) * 2.4, i * 1.7 - 30.0), 1.5)
		assert_true(c.g >= 0.0 and c.g <= 1.0 and c.b >= 0.0 and c.b < 0.8, "色溫與窗簾在範圍內：%s" % c)
		if c.b > 0.0:
			curtains += 1
		energies.append(c.a * 4.0)
	assert_true(curtains > 10 and curtains < 40, "約四成拉了窗簾（%d／60）" % curtains)
	assert_true(energies.min() >= 1.5 * 0.74 and energies.max() <= 1.5 * 1.21, "亮度在 0.75～1.2 倍之間")
	assert_true(energies.max() - energies.min() > 0.3, "每扇窗亮度不一樣")
