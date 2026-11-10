extends TestCase
## ChainMesh（D-199）：乾運河吊住牠的鐵鏈、閘道小油燈的細鏈——一節節鏈環、從掛鉤往下垂、長度對、正面朝外。


func test_link_count_covers_length() -> void:
	assert_eq(ChainMesh.link_count(0.1, 0.16, 0.018), 1, "比一節短：一節")
	for length_m: float in [0.5, 1.15, 1.4, 3.0]:
		var n: int = ChainMesh.link_count(length_m, 0.16, 0.018)
		var reach: float = float(n - 1) * ChainMesh.pitch(0.16, 0.018) + 0.16
		assert_true(reach >= length_m - 0.001, "%.2f m：%d 節垂得到底" % [length_m, n])
		assert_true(reach - ChainMesh.pitch(0.16, 0.018) < length_m, "%.2f m：沒有多一節" % length_m)


func test_hangs_from_hook_down() -> void:
	var mesh: ArrayMesh = ChainMesh.build(1.15, 0.16, 0.1, 0.018)
	var aabb: AABB = mesh.get_aabb()
	assert_true(absf(aabb.end.y) < 0.002, "最上面一節的上緣在掛鉤（y＝0）")
	assert_true(aabb.position.y <= -1.15 + 0.002 and aabb.position.y > -1.15 - 0.16, "下緣垂到 1.15 m 附近")
	assert_true(aabb.size.x <= 0.1 + 0.002 and aabb.size.z <= 0.1 + 0.002, "寬度不超過一節的外寬")
	assert_true(aabb.size.x > 0.09 and aabb.size.z > 0.09, "相鄰兩節轉 90°：X、Z 兩個方向都有一節攤開的寬度")


func test_triangles_face_outward() -> void:
	var mesh: ArrayMesh = ChainMesh.build(0.4, 0.16, 0.1, 0.018)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_eq(verts.size() % 3, 0, "三角形")
	assert_eq(verts.size(), ChainMesh.link_count(0.4, 0.16, 0.018) * ChainMesh.RING_SEGMENTS * ChainMesh.TUBE_SEGMENTS * 6, "每節 RING×TUBE 個四邊形")
	var bad: int = 0
	for i: int in range(0, verts.size(), 3):
		var face: Vector3 = (verts[i + 2] - verts[i]).cross(verts[i + 1] - verts[i])
		if face.dot(norms[i] + norms[i + 1] + norms[i + 2]) <= 0.0:
			bad += 1
	assert_eq(bad, 0, "每個三角形正面朝外（Godot 順時針是正面）")
	for n: Vector3 in norms:
		if absf(n.length() - 1.0) > 0.01:
			assert_true(false, "法線是單位向量")
			break
