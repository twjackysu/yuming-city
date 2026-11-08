extends TestCase
## RoofMesh（D-107）：跟 PrismMesh 一樣的外形；斜面 UV 是公尺（u 沿屋簷、v 從屋簷沿斜面往上），山牆 UV 是 (-1, -1)；
## 每個三角形正面朝外、法線朝外。


func test_shape_and_uv_in_meters() -> void:
	var mesh: ArrayMesh = RoofMesh.build(6.0, 2.0, 5.0)
	var aabb: AABB = mesh.get_aabb()
	assert_true(aabb.position.is_equal_approx(Vector3(-3.0, -1.0, -2.5)) and aabb.size.is_equal_approx(Vector3(6.0, 2.0, 5.0)), "外形跟 PrismMesh 一樣：%s" % aabb)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var slope: float = Vector2(3.0, 2.0).length()
	var max_v: float = 0.0
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		var uv: Vector2 = uvs[i]
		if uv.y < 0.0:
			assert_true(absf(absf(v.z) - 2.5) < 0.001, "UV 是 (-1,-1) 的只有山牆")
			continue
		assert_true(absf(uv.x - (v.z + 2.5)) < 0.001, "u＝沿屋簷的公尺數")
		assert_true(absf(uv.y - (v.y + 1.0) / 2.0 * slope) < 0.001, "v＝從屋簷沿斜面的公尺數")
		max_v = maxf(max_v, uv.y)
	assert_true(absf(max_v - slope) < 0.001, "屋脊的 v 是斜面長度")


func test_faces_point_outward() -> void:
	var mesh: ArrayMesh = RoofMesh.build(4.0, 1.5, 3.0)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_eq(verts.size(), 18, "兩片斜面各兩個三角形＋兩個山牆三角形")
	var good_face: int = 0
	var good_normal: int = 0
	for t: int in range(0, verts.size(), 3):
		var center: Vector3 = (verts[t] + verts[t + 1] + verts[t + 2]) / 3.0
		var out: Vector3 = Vector3(signf(center.x), 0.6, 0.0) if absf(absf(center.z) - 1.5) > 0.01 else Vector3(0, 0, signf(center.z))
		# Godot 正面是順時針：Plane(a, b, c) 的法線朝外＝從外面看得到（跟 SnowMound 的測試同一個判斷）
		if Plane(verts[t], verts[t + 1], verts[t + 2]).normal.dot(out) > 0.0:
			good_face += 1
		if normals[t].dot(out) > 0.0:
			good_normal += 1
	assert_eq(good_face, 6, "每個三角形的正面朝外")
	assert_eq(good_normal, 6, "法線朝外")
