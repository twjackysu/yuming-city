extends TestCase
## SnowMound（D-102）：破屋頂上的雪堆——中間厚、邊緣薄到 0、輪廓不規則、法線朝上、正面朝上（順時針）。


func test_mound_bounds_and_thickness() -> void:
	var mesh: ArrayMesh = SnowMound.build(1.6, 0.9, 0.12, 3.7)
	assert_eq(mesh.get_surface_count(), 1, "一個 surface")
	var aabb: AABB = mesh.get_aabb()
	assert_true(aabb.size.x <= 1.6 + 0.001 and aabb.size.x > 1.6 * 0.7, "長度不超過、也不會縮太多：%s" % aabb)
	assert_true(aabb.size.z <= 0.9 + 0.001 and aabb.size.z > 0.9 * 0.7, "寬度：%s" % aabb)
	assert_true(aabb.end.y > 0.1 and aabb.end.y < 0.12 * 1.1, "最高點約 0.12 m：%s" % aabb)
	assert_true(aabb.position.y < 0.0 and aabb.position.y > -0.03, "外圈稍微低於 0（貼進斜面）：%s" % aabb)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(normals.size(), verts.size(), "每個頂點都有法線")
	assert_eq(uvs.size(), verts.size(), "每個頂點都有 UV（跟其他雪合併時格式一致）")
	# 中間厚、邊緣薄：離中心越遠越低
	var near_h: float = 0.0
	var far_h: float = 1.0
	for v: Vector3 in verts:
		var d: float = Vector2(v.x / 0.8, v.z / 0.45).length()
		if d < 0.3:
			near_h = maxf(near_h, v.y)
		if d > 0.75:
			far_h = minf(far_h, v.y)
	assert_true(near_h > 0.09, "中心厚（%.3f）" % near_h)
	assert_true(far_h <= 0.0, "邊緣薄到 0（%.3f）" % far_h)


func test_normals_up_and_front_faces_up() -> void:
	var mesh: ArrayMesh = SnowMound.build(1.2, 1.0, 0.15, 11.0)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var up: int = 0
	for n: Vector3 in normals:
		if n.y > 0.2:
			up += 1
	assert_eq(up, normals.size(), "法線都朝上（%d/%d）" % [up, normals.size()])
	# Godot 正面是順時針：Plane(a, b, c) 的法線朝上 = 從上面看得到
	var front_up: int = 0
	for t: int in range(0, idx.size(), 3):
		var pl := Plane(verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]])
		if pl.normal.y > 0.0:
			front_up += 1
	assert_eq(front_up, idx.size() / 3, "每個三角形的正面朝上（%d/%d）" % [front_up, idx.size() / 3])


func test_outline_differs_by_seed_and_is_deterministic() -> void:
	var a: PackedVector3Array = SnowMound.build(1.0, 1.0, 0.1, 1.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b: PackedVector3Array = SnowMound.build(1.0, 1.0, 0.1, 2.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var a2: PackedVector3Array = SnowMound.build(1.0, 1.0, 0.1, 1.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(a, a2, "同一個 seed 一樣（位置雜湊，不靠亂數）")
	assert_true(a != b, "不同 seed 輪廓不同")


## 街邊雪帶（D-105）：bias 讓最高點偏向一邊（靠牆那側高而陡、另一側緩），網格照樣正面朝上。
func test_peak_bias_leans_toward_wall() -> void:
	var mesh: ArrayMesh = SnowMound.build(2.4, 1.6, 0.2, 5.0, Vector2(0.0, 0.5))
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var top := Vector3(0, -1, 0)
	for v: Vector3 in verts:
		if v.y > top.y:
			top = v
	assert_true(top.z > 0.2, "最高點偏向 +Z（z=%.2f）" % top.z)
	# 同樣離中心 0.5 m：+Z 那側比 -Z 那側高
	var plus: float = 0.0
	var minus: float = 0.0
	for v: Vector3 in verts:
		if absf(v.x) < 0.5:
			if v.z > 0.45:
				plus = maxf(plus, v.y)
			elif v.z < -0.45:
				minus = maxf(minus, v.y)
	assert_true(plus > minus + 0.03, "靠牆那側比較厚（%.3f > %.3f）" % [plus, minus])
	var front_up: int = 0
	for t: int in range(0, idx.size(), 3):
		if Plane(verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]]).normal.y > 0.0:
			front_up += 1
	assert_eq(front_up, idx.size() / 3, "偏一邊也不會翻面（%d/%d）" % [front_up, idx.size() / 3])
	var far: Vector3 = SnowMound.build(2.4, 1.6, 0.2, 5.0, Vector2(0.0, 3.0)).get_aabb().end
	assert_true(far.z <= 0.8 + 0.001, "bias 太大也不會跑出輪廓（%s）" % far)
