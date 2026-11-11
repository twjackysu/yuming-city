extends TestCase
## 推車（新劇情的 RbCart 用同一個 Caravan）：推進與進度、被打停下＋傷者、停下中不重複計、抵達、存讀；貼近鏡頭淡出、車的造型。


func _route() -> PackedVector3Array:
	return PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -10), Vector3(5, 0, -10)])


func test_advance_and_arrive() -> void:
	var r := CaravanRunner.new(_route())
	assert_true(absf(r.length() - 15.0) < 0.001, "路線長 15")
	r.speed = 1.0
	var arrived: Array[bool] = [false]
	r.arrived.connect(func() -> void: arrived[0] = true)
	r.tick(5.0)
	assert_true(r.position().distance_to(Vector3(0, 0, -5)) < 0.001, "走了 5 公尺：%s" % r.position())
	assert_true(absf(r.progress() - 1.0 / 3.0) < 0.001)
	assert_true(r.heading().distance_to(Vector3(0, 0, -1)) < 0.001, "第一段往 -Z")
	r.tick(7.0)
	assert_true(r.position().distance_to(Vector3(2, 0, -10)) < 0.001, "轉彎後：%s" % r.position())
	assert_true(r.heading().distance_to(Vector3(1, 0, 0)) < 0.001, "第二段往 +X")
	r.tick(10.0)
	assert_true(r.is_arrived and arrived[0], "抵達")
	assert_eq(r.progress(), 1.0)
	assert_false(r.hit(), "抵達後打不到")


func test_hit_stops_and_counts_once() -> void:
	var r := CaravanRunner.new(_route())
	r.speed = 1.0
	r.tick(2.0)
	assert_true(r.hit(), "第一次被打中")
	assert_eq(r.injured, 1)
	assert_true(r.is_stopped())
	assert_false(r.hit(), "停下中再被打不重複計")
	assert_eq(r.injured, 1)
	r.tick(1.5)
	assert_true(absf(r.traveled - 2.0) < 0.001, "停下時不前進")
	r.tick(0.6)
	assert_false(r.is_stopped(), "停 2 秒後恢復")
	r.tick(1.0)
	assert_true(r.traveled > 2.0, "繼續前進")
	assert_true(r.hit())
	assert_eq(r.injured, 2, "恢復後再被打算第二次")


func test_save_roundtrip() -> void:
	var r := CaravanRunner.new(_route())
	r.speed = 1.0
	r.tick(4.0)
	r.hit()
	var d: Dictionary = r.to_dict()
	var r2 := CaravanRunner.new(_route())
	r2.from_dict(d)
	assert_eq(r2.injured, 1)
	assert_true(absf(r2.traveled - 4.0) < 0.001)
	assert_false(r2.is_stopped(), "讀檔不停在被打的瞬間")
	r2.from_dict({"traveled": 999.0})
	assert_true(absf(r2.traveled - 15.0) < 0.001, "超出路線長度會夾住")


## 車隊從鏡頭旁經過時，提燈的燈罩貼近鏡頭不能變成一個白色圓盤：太近就淡掉。
func test_lantern_glass_fades_near_camera() -> void:
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -10)])
	tree.root.add_child(caravan)
	var glass: MeshInstance3D = caravan.find_child("LanternGlass", true, false) as MeshInstance3D
	assert_not_null(glass, "有提燈燈罩")
	if glass != null:
		var m: BaseMaterial3D = glass.material_override as BaseMaterial3D
		assert_eq(m.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER, "靠近鏡頭用抖動淡掉")
		assert_true(m.distance_fade_min_distance < m.distance_fade_max_distance and m.distance_fade_min_distance > 0.3, "淡掉的距離合理")
	caravan.queue_free()
	await tree.process_frame


## 推車從後面追上諾恩時會經過鏡頭底下（第三輪盤點第 9 項，D-106）：推車與傷者的材質離鏡頭太近就抖動淡掉，
## 燈罩維持自己的淡出距離。
func test_cart_fades_near_camera() -> void:
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -10)])
	tree.root.add_child(caravan)
	var mats: Array[BaseMaterial3D] = []
	_collect(caravan, mats)
	assert_true(mats.size() >= 6, "推車、布、傷者都有材質（%d）" % mats.size())
	var faded: int = 0
	for m: BaseMaterial3D in mats:
		if m.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER:
			faded += 1
	assert_eq(faded, mats.size(), "每個材質離鏡頭太近都會淡掉（%d/%d）" % [faded, mats.size()])
	var wood: BaseMaterial3D = (caravan.find_child("Cart", true, false).get_child(0) as MeshInstance3D).material_override as BaseMaterial3D
	assert_true(absf(wood.distance_fade_min_distance - Caravan.CART_FADE_NEAR) < 0.001, "推車木頭 %.2f" % wood.distance_fade_min_distance)
	assert_true(absf(wood.distance_fade_max_distance - Caravan.CART_FADE_FAR) < 0.001, "推車木頭 %.2f" % wood.distance_fade_max_distance)
	assert_true(Caravan.CART_FADE_FAR < PlayerController.CAMERA_DIST_COMBAT - 0.6, "戰鬥時鏡頭在諾恩身後 4.2 m：諾恩身邊的推車不會淡掉")
	var glass: MeshInstance3D = caravan.find_child("LanternGlass", true, false) as MeshInstance3D
	assert_true(absf((glass.material_override as BaseMaterial3D).distance_fade_max_distance - Caravan.GLASS_FADE_FAR) < 0.001, "燈罩維持自己的淡出距離")
	caravan.queue_free()
	await tree.process_frame


## 第四輪盤點（D-111）：推車不再是 CSG 方塊與實心圓柱輪——木板車斗、邊板與立樁、有輻條的木輪＋鐵輪框、車把＋橫把、燈柱。
func test_cart_is_built_like_a_cart() -> void:
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -10)])
	tree.root.add_child(caravan)
	var cart: Node3D = caravan.find_child("Cart", true, false) as Node3D
	var counts: Dictionary = {}
	var csg: int = 0
	for c: Node in cart.get_children():
		if c is CSGShape3D:
			csg += 1
		var key: String = String(c.name).rstrip("0123456789")
		counts[key] = int(counts.get(key, 0)) + 1
	assert_eq(csg, 0, "推車沒有 CSG 方塊")
	assert_eq(int(counts.get("Plank", 0)), Caravan.PLANKS, "車斗是一片片木板")
	assert_eq(int(counts.get("Tire", 0)), 2, "兩個輪子各一圈鐵輪框")
	assert_eq(int(counts.get("Felloe", 0)), 2, "木輪框")
	assert_eq(int(counts.get("Spoke", 0)), Caravan.SPOKE_BARS * 2, "每個輪子六根輻條")
	assert_eq(int(counts.get("Handle", 0)), 2, "兩根車把")
	assert_eq(int(counts.get("Grip", 0)), 1, "前端橫把")
	var tire: MeshInstance3D = cart.find_child("Tire*", false, false) as MeshInstance3D
	assert_true(tire != null and tire.mesh is TorusMesh, "輪框是圓環（中間看得穿）")
	if tire != null:
		assert_true(absf(tire.global_transform.basis.y.normalized().dot(caravan.global_transform.basis.x.normalized())) > 0.99, "輪軸沿車身左右")
		assert_true(absf(tire.position.y - Caravan.WHEEL_R) < 0.001, "輪子著地")
	# D-113：傷者包著頭巾（頭不是一顆光滑的球），其中一人纏著繃帶
	var wraps: int = cart.find_children("HeadWrap", "MeshInstance3D", true, false).size()
	assert_eq(wraps, 2, "兩名傷者都包著頭巾")
	assert_eq(cart.find_children("Bandage", "MeshInstance3D", true, false).size(), 1, "一人額頭纏著繃帶")
	var pole: Node3D = cart.find_child("LanternPole", false, false) as Node3D
	assert_not_null(pole, "提燈掛在燈柱上")
	if pole != null:
		assert_true(absf(pole.position.x - Caravan.LANTERN_POS.x) < 0.05, "燈柱在提燈正上方")
	caravan.queue_free()
	await tree.process_frame


func _collect(node: Node, out: Array[BaseMaterial3D]) -> void:
	var cands: Array = []
	if node is CSGPrimitive3D:
		cands.append(node.get("material"))
	if node is GeometryInstance3D:
		cands.append((node as GeometryInstance3D).material_override)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is PrimitiveMesh:
		cands.append(((node as MeshInstance3D).mesh as PrimitiveMesh).material)
	for c: Variant in cands:
		if c is BaseMaterial3D and not out.has(c):
			out.append(c as BaseMaterial3D)
	for child: Node in node.get_children():
		_collect(child, out)
