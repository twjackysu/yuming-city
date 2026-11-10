extends TestCase
## CoalPile（D-195）：閘道裡倒下來的那堆煤——錐形（中間高、外圈貼地）、塊狀起伏、平面著色、
## 正面朝外、散落的小煤塊、頂點色（煤黑＋煤粉）、同一個 seed 一樣。


func _tris(mesh: ArrayMesh) -> Array[PackedVector3Array]:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var out: Array[PackedVector3Array] = []
	var count: int = idx.size() if idx.size() > 0 else verts.size()
	for t: int in range(0, count, 3):
		var tri := PackedVector3Array()
		for k: int in 3:
			var v: int = idx[t + k] if idx.size() > 0 else t + k
			tri.append(verts[v])
		for k: int in 3:
			var v2: int = idx[t + k] if idx.size() > 0 else t + k
			tri.append(normals[v2])
		out.append(tri)
	return out


func test_heap_shape_cone_and_ground() -> void:
	var mesh: ArrayMesh = CoalPile.build(2.7, 2.3, 0.62, 7.3)
	assert_eq(mesh.get_surface_count(), 1, "一個 surface（堆＋小煤塊合在一起）")
	var aabb: AABB = mesh.get_aabb()
	assert_true(aabb.end.y > 0.62 * 0.9 and aabb.end.y < 0.62 + CoalPile.LUMP_AMP + CoalPile.LUMP_SIZE.y * 2.0, "最高點約 0.62 m：%s" % aabb)
	assert_true(aabb.position.y < 0.0 and aabb.position.y > -0.2, "外圈稍微低於 0（貼進河床）、小煤塊不會埋太深：%s" % aabb)
	assert_true(aabb.size.x < 2.7 * 1.4 and aabb.size.x > 2.7 * 0.8, "長度（含滾出去的小煤塊）：%s" % aabb)
	assert_true(aabb.size.z < 2.3 * 1.4 and aabb.size.z > 2.3 * 0.8, "寬度：%s" % aabb)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var near_h: float = 0.0
	var mid_lo: float = 1.0
	for v: Vector3 in verts:
		var d: float = Vector2(v.x / 1.35, v.z / 1.15).length()
		if d < 0.2:
			near_h = maxf(near_h, v.y)
		if d > 0.45 and d < 0.55:
			mid_lo = minf(mid_lo, v.y)
	assert_true(near_h > 0.62 * 0.85, "中間高（%.3f）" % near_h)
	assert_true(mid_lo < near_h - 0.1, "往外變低（中段最低 %.3f）" % mid_lo)
	assert_true(CoalPile.profile(0.0) == 1.0 and CoalPile.profile(1.0) == 0.0, "錐形：中心 1、外圈 0")
	assert_true(CoalPile.profile(0.3) > 1.0 - 0.3, "頂上圓（比直的錐高）")


func test_flat_shaded_and_front_faces_outward() -> void:
	var tris: Array[PackedVector3Array] = _tris(CoalPile.build(2.7, 2.3, 0.62, 7.3))
	assert_true(tris.size() > CoalPile.SEGMENTS * (2 * CoalPile.RINGS - 1), "堆的三角形都在（%d）" % tris.size())
	var flat: int = 0
	var agree: int = 0
	for tri: PackedVector3Array in tris:
		if tri[3].is_equal_approx(tri[4]) and tri[4].is_equal_approx(tri[5]):
			flat += 1
		# Godot 正面順時針：Plane(a, b, c) 的法線＝看得到的那一面；跟產生的法線同一個方向
		var pl := Plane(tri[0], tri[1], tri[2])
		if pl.normal.dot(tri[3]) > 0.9:
			agree += 1
	assert_eq(flat, tris.size(), "平面著色：每個三角形三個頂點同一個法線（一塊塊切面各自反光）")
	assert_eq(agree, tris.size(), "正面跟法線一致（%d/%d）" % [agree, tris.size()])
	# 堆本身（前 SEGMENTS × (2 RINGS - 1) 個三角形）朝上
	var heap_tris: int = CoalPile.SEGMENTS * (2 * CoalPile.RINGS - 1)
	var up: int = 0
	var tilted: int = 0
	for t: int in heap_tris:
		var pl2 := Plane(tris[t][0], tris[t][1], tris[t][2])
		if pl2.normal.y > 0.0:
			up += 1
		if pl2.normal.y < 0.97:
			tilted += 1
	assert_eq(up, heap_tris, "堆的每個三角形正面朝上")
	assert_true(tilted > heap_tris / 2, "大部分切面是斜的（塊狀起伏，不是一片平滑的殼：%d/%d）" % [tilted, heap_tris])


func test_lumps_scattered_and_colors() -> void:
	var mesh: ArrayMesh = CoalPile.build(2.7, 2.3, 0.62, 7.3)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(colors.size(), verts.size(), "每個頂點都有顏色")
	var heap_verts: int = CoalPile.SEGMENTS * (2 * CoalPile.RINGS - 1) * 3
	assert_eq(verts.size(), heap_verts + CoalPile.LUMPS * 8 * 3, "堆＋%d 顆八面體" % CoalPile.LUMPS)
	var outside: int = 0
	for n: int in range(heap_verts, verts.size(), 24):
		var c := Vector3.ZERO
		for k: int in 24:
			c += verts[n + k]
		c /= 24.0
		if Vector2(c.x / 1.35, c.z / 1.15).length() > 0.98:
			outside += 1
	assert_true(outside >= CoalPile.LUMPS_OUTSIDE - 1, "有幾顆滾到堆外的河床上（%d）" % outside)
	var darkest: float = 1.0
	var dustiest: float = 0.0
	for col: Color in colors:
		darkest = minf(darkest, col.r)
		dustiest = maxf(dustiest, col.r)
	assert_true(absf(darkest - CoalPile.COAL_COLOR.r) < 0.01, "最暗是煤黑（%.3f）" % darkest)
	assert_true(dustiest > CoalPile.COAL_COLOR.r + 0.06, "外圈有煤粉（%.3f）" % dustiest)
	var mat: StandardMaterial3D = CoalPile.material()
	assert_true(mat.vertex_color_use_as_albedo and mat.vertex_color_is_srgb, "材質吃頂點色（sRGB，煤才是黑的）")
	assert_true(mat.roughness <= 0.35 and mat.metallic_specular >= 0.7, "低粗糙度、高鏡面")


func test_deterministic_by_seed() -> void:
	var a: PackedVector3Array = CoalPile.build(2.0, 2.0, 0.5, 1.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var a2: PackedVector3Array = CoalPile.build(2.0, 2.0, 0.5, 1.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b: PackedVector3Array = CoalPile.build(2.0, 2.0, 0.5, 2.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(a, a2, "同一個 seed 一樣（位置雜湊，不靠亂數）")
	assert_true(a != b, "不同 seed 不同")


func test_lump_mesh_closed_and_outward() -> void:
	var mesh: ArrayMesh = CoalPile.lump_mesh(0.2, 4.0)
	var tris: Array[PackedVector3Array] = _tris(mesh)
	assert_eq(tris.size(), 8, "八面體：8 個面")
	for tri: PackedVector3Array in tris:
		var centroid: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
		var pl := Plane(tri[0], tri[1], tri[2])
		assert_true(pl.normal.dot(centroid) > 0.0, "正面朝外")
	var aabb: AABB = mesh.get_aabb()
	assert_true(aabb.size.length() > 0.2 and aabb.size.length() < 0.2 * 2.5 * 1.8, "大小約 0.2 m 半徑：%s" % aabb)
	assert_true(CoalPile.lump_mesh(0.2, 4.0).get_aabb() == aabb, "同一個 seed 一樣")
