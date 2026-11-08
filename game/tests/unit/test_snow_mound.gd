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



## 雪堆外圈變薄（D-119）：UV2.x 是圈數（最高點 0、外圈 1）。
func test_ring_in_uv2() -> void:
	var mesh: ArrayMesh = SnowMound.build(1.4, 0.8, 0.12, 5.0)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_eq(uv2s.size(), verts.size(), "每個頂點都有 UV2")
	var top_k: float = 1.0
	var low_k: float = 0.0
	for n: int in verts.size():
		if verts[n].y > 0.115:
			top_k = minf(top_k, uv2s[n].x)
		if verts[n].y < 0.0:
			low_k = maxf(low_k, uv2s[n].x)
	assert_true(top_k < 0.01, "最高點 UV2.x＝0（%.3f）" % top_k)
	assert_true(low_k > 0.99, "外圈（貼進斜面那圈）UV2.x＝1（%.3f）" % low_k)


## 雪堆跟方塊的雪（沒有 UV2）合併成同一個 mesh：方塊的 UV2 補 0（不變薄），雪堆的圈數保留。
func test_batch_with_plain_snow_keeps_rings() -> void:
	var look := FrostbridgeLook.new()
	var batch := StaticBatch.new()
	batch.add_box_at(Vector3(1, 0.1, 1), Vector3(0, 5, 0), look.snow(), false)
	batch.add_mesh(SnowMound.build(1.0, 1.0, 0.1, 2.0), Transform3D.IDENTITY, look.snow())
	batch.add_box_at(Vector3(1, 0.1, 1), Vector3(0, 6, 0), look.snow(), false)
	var root := Node3D.new()
	batch.build(root, "T")
	var mi: MeshInstance3D = root.get_node("T").get_child(0) as MeshInstance3D
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_eq(uv2s.size(), verts.size(), "合併後每個頂點都有 UV2")
	var box_max: float = 0.0
	var mound_max: float = 0.0
	for n: int in verts.size():
		if verts[n].y > 4.0:
			box_max = maxf(box_max, uv2s[n].x)
		else:
			mound_max = maxf(mound_max, uv2s[n].x)
	assert_true(box_max < 0.001, "方塊的雪 UV2＝0：不變薄（%.3f）" % box_max)
	assert_true(mound_max > 0.99, "雪堆外圈的圈數保留（%.3f）" % mound_max)
	root.free()


## 街邊雪帶（D-126）：UV2.y＝往牆那側多遠（靠牆的邊 +1、靠街的邊 -1），雪 shader 用來讓靠牆的角落暗、
## 靠街那側才有腳印。不是街邊雪帶的雪堆 UV2.y 全是 0（屋頂、木堆上的雪不會有腳印）。
func test_street_bank_lean_in_uv2() -> void:
	var arrays: Array = SnowMound.build(2.4, 1.6, 0.2, 5.0, Vector2(0.0, -0.5), true).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var wall_side: float = -2.0
	var street_side: float = 2.0
	for n: int in verts.size():
		# 這個雪堆的牆在 -Z：越往 -Z，UV2.y 越大
		if verts[n].z < -0.7:
			wall_side = maxf(wall_side, uv2s[n].y)
		if verts[n].z > 0.7:
			street_side = minf(street_side, uv2s[n].y)
		assert_true(absf(uv2s[n].y) <= 1.0 + 0.001, "UV2.y 在 -1～1（%.3f）" % uv2s[n].y)
	assert_true(wall_side > 0.85, "靠牆的邊 UV2.y 接近 +1（%.3f）" % wall_side)
	assert_true(street_side < -0.85, "靠街的邊 UV2.y 接近 -1（%.3f）" % street_side)
	var plain: PackedVector2Array = SnowMound.build(2.4, 1.6, 0.2, 5.0, Vector2(0.0, -0.5)).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	var most: float = 0.0
	for uv: Vector2 in plain:
		most = maxf(most, absf(uv.y))
	assert_true(most < 0.001, "沒標 street_bank 的雪堆 UV2.y＝0（%.3f）" % most)


## 屋瓦上的薄雪（D-127）：UV2.y＝TILES_MARK＋沿模型 X 的公尺數（shader 用來畫屋瓦的橫紋、露出屋瓦），
## 跟街邊雪帶的 -1～1 分得開。
func test_on_tiles_marks_slope_meters() -> void:
	var arrays: Array = SnowMound.build(1.6, 1.0, 0.07, 3.0, Vector2.ZERO, false, true).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for n: int in verts.size():
		assert_true(uv2s[n].y > 5.0, "屋瓦上的雪 UV2.y 都大於 5（%.3f）" % uv2s[n].y)
		assert_true(absf(uv2s[n].y - SnowMound.TILES_MARK - verts[n].x) < 0.001, "UV2.y－TILES_MARK＝模型 X（%.3f vs %.3f）" % [uv2s[n].y, verts[n].x])


## 街邊雪帶的腳印座標（D-134）：UV＝(BANK_MARK＋沿著牆的公尺數, 離牆腳線多遠)。
## 沿著牆的座標跟世界一致（重疊的兩段算出來一樣，腳印接得起來）；離牆越遠 UV.y 越大；UV2 照舊。
func test_bank_uv_is_wall_meters() -> void:
	# 牆在 -Z（toward_wall＝-1）：越往 +Z 離牆越遠
	var arrays: Array = SnowMound.build_bank(2.4, 1.6, 0.2, 5.0, -1.0, 12.5, 0.5).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_eq(uvs.size(), verts.size(), "每個頂點都有 UV")
	assert_true(arrays[Mesh.ARRAY_INDEX] != null, "保留索引（StaticBatch 合併要有索引）")
	for n: int in verts.size():
		assert_true(uvs[n].x > 500.0, "UV.x 有 BANK_MARK（其他雪在 0～1）")
		assert_true(absf(uvs[n].x - SnowMound.BANK_MARK - 12.5 - verts[n].x) < 0.001, "沿著牆的公尺數")
		assert_true(absf(uvs[n].y - (0.5 + verts[n].z)) < 0.001, "離牆多遠（%.3f）" % uvs[n].y)
	var plain: PackedVector2Array = SnowMound.build(2.4, 1.6, 0.2, 5.0, Vector2(0.0, -0.5), true).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert_eq(uv2s, plain, "UV2（圈數、往牆那側多遠）跟 build 一樣")
	var other: PackedVector2Array = SnowMound.build(2.4, 1.6, 0.2, 5.0).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	for uv: Vector2 in other:
		assert_true(uv.x < 2.0, "其他雪堆的 UV 不會被當成雪帶")


## 一整條連續的街邊雪帶（D-136）：不是一串各有最高點的雪堆——沿著牆的高度慢慢起伏（相鄰兩列差很少），
## 兩端收成 0；靠牆高、往街薄到 0；正面朝上（兩個方向的牆都是）；UV／UV2 跟 build_bank 同一套。
func test_strip_is_continuous_bank() -> void:
	for toward_wall: float in [-1.0, 1.0]:
		var mesh: ArrayMesh = SnowMound.build_strip(12.0, 1.2, 0.3, 0.24, 7.0, toward_wall, 3.0)
		var arrays: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_true(idx != null and idx.size() > 0, "有索引（StaticBatch 合併要有索引）")
		var front_up: int = 0
		for t: int in range(0, idx.size(), 3):
			if Plane(verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]]).normal.y > 0.0:
				front_up += 1
		assert_eq(front_up, idx.size() / 3, "toward_wall=%d：每個三角形的正面朝上" % int(toward_wall))
		var aabb: AABB = mesh.get_aabb()
		assert_true(absf(aabb.size.x - 12.0) < 0.01, "沿著牆整段 12 m（%s）" % aabb)
		assert_true(aabb.end.y < 0.24 * 1.1 and aabb.end.y > 0.15, "最高約 0.24 m（%.3f）" % aabb.end.y)
		# 沿著牆每列的最高點：中段相鄰兩列（0.3 m）差不到 2.5 cm——不是一節一節的雪堆
		var ridge: Dictionary = {}
		for n: int in verts.size():
			var key: int = roundi(verts[n].x / SnowMound.STRIP_STEP * 10.0)
			ridge[key] = maxf(float(ridge.get(key, -1.0)), verts[n].y)
			var dfw: float = -toward_wall * verts[n].z
			assert_true(absf(uvs[n].y - dfw) < 0.001, "UV.y＝離牆腳線多遠（%.3f vs %.3f）" % [uvs[n].y, dfw])
			assert_true(absf(uvs[n].x - SnowMound.BANK_MARK - 3.0 - (verts[n].x + 6.0)) < 0.001, "UV.x＝BANK_MARK＋along0＋從 -X 端起算的公尺數")
			assert_true(uv2s[n].y <= 1.001 and uv2s[n].y >= -1.001, "UV2.y 在 -1～1")
			if dfw > 0.95 * 1.2:
				assert_true(verts[n].y < 0.03, "靠街的邊薄到 0（離牆 %.2f m 高 %.3f）" % [dfw, verts[n].y])
		var keys: Array = ridge.keys()
		keys.sort()
		var jump: float = 0.0
		for i: int in range(1, keys.size()):
			jump = maxf(jump, absf(float(ridge[keys[i]]) - float(ridge[keys[i - 1]])))
		assert_true(jump < 0.12, "沿著牆相鄰兩列最高點差 %.3f m（連兩端 1 m 的收口也不會大跳）" % jump)
		assert_true(float(ridge[keys[0]]) < 0.02 and float(ridge[keys[keys.size() - 1]]) < 0.02, "兩端收成 0")
		var mid: Array = keys.slice(keys.size() / 4, keys.size() * 3 / 4)
		var mid_jump: float = 0.0
		for i: int in range(1, mid.size()):
			mid_jump = maxf(mid_jump, absf(float(ridge[mid[i]]) - float(ridge[mid[i - 1]])))
		assert_true(mid_jump < 0.025, "中段相鄰兩列最高點差 %.3f m（慢慢起伏）" % mid_jump)
	var a: PackedVector3Array = SnowMound.build_strip(8.0, 1.0, 0.3, 0.24, 1.0, -1.0, 0.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var a2: PackedVector3Array = SnowMound.build_strip(8.0, 1.0, 0.3, 0.24, 1.0, -1.0, 0.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(a, a2, "同一個 seed 一樣（位置雜湊）")
