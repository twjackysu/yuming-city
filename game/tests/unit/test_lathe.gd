extends TestCase
## Lathe（D-081）：剖面線繞 Y 軸轉成 ArrayMesh；鐘的外側法線朝外、鐘口朝下、內側中空。


func test_bell_mesh_shape_and_bounds() -> void:
	var mesh: ArrayMesh = Lathe.bell_mesh(1.5, 0.95, 24)
	assert_eq(mesh.get_surface_count(), 1, "一個 surface")
	var aabb: AABB = mesh.get_aabb()
	assert_true(absf(aabb.position.y + 1.5) < 0.01 and absf(aabb.end.y) < 0.01, "鐘頂 y=0、鐘口 y=-1.5：%s" % aabb)
	assert_true(absf(aabb.end.x - 0.95) < 0.02 and absf(aabb.position.x + 0.95) < 0.02, "鐘口半徑 0.95：%s" % aabb)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# 每條剖面線 (點數-1) 段 × 24 等分 × 2 個三角形 × 3 個頂點（外側 11 點、唇 2 點、內側 7 點）
	assert_eq(verts.size(), (10 + 1 + 6) * 24 * 6, "頂點數")
	assert_eq(normals.size(), verts.size(), "每個頂點都有法線")


func test_outer_normals_face_out_and_lip_faces_down() -> void:
	var lathe := Lathe.new(16)
	var profiles: Array[PackedVector2Array] = Lathe.bell_profiles(1.5, 0.95)
	assert_eq(profiles.size(), 3, "外側、唇底、內側三條剖面線")
	lathe.add_profile(profiles[0])
	var outer: Array = lathe.commit().surface_get_arrays(0)
	var verts: PackedVector3Array = outer[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = outer[Mesh.ARRAY_NORMAL]
	var outward: int = 0
	var checked: int = 0
	for i: int in verts.size():
		var radial := Vector3(verts[i].x, 0.0, verts[i].z)
		if radial.length() < 0.2:
			continue
		checked += 1
		if normals[i].dot(radial.normalized()) > 0.0:
			outward += 1
	assert_true(checked > 0 and outward == checked, "外側法線都朝外（%d/%d）" % [outward, checked])
	var lip := Lathe.new(16)
	lip.add_profile(profiles[1])
	var lip_n: PackedVector3Array = lip.commit().surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for n: Vector3 in lip_n:
		assert_true(n.y < -0.99, "鐘唇底面朝下（%s）" % n)
		break


## Godot 的正面是順時針：三角形 (v0, v1, v2) 的 (v2-v0)×(v1-v0) 跟頂點法線同一邊，才不會被背面剔除。
func test_triangles_wind_clockwise_toward_normals() -> void:
	var mesh: ArrayMesh = Lathe.bell_mesh(1.5, 0.95, 12)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bad: int = 0
	var tris: int = 0
	var t: int = 0
	while t + 2 < verts.size():
		var face: Vector3 = (verts[t + 2] - verts[t]).cross(verts[t + 1] - verts[t])
		if face.length() > 0.000001:
			tris += 1
			var avg: Vector3 = normals[t] + normals[t + 1] + normals[t + 2]
			if face.dot(avg) <= 0.0:
				bad += 1
		t += 3
	assert_true(tris > 100, "有三角形（%d）" % tris)
	assert_eq(bad, 0, "所有三角形都朝法線那一側")
