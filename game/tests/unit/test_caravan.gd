extends TestCase
## 傷者車隊：推進與進度、被打停下＋傷者、停下中不重複計、抵達、存讀；場景中被送葬者第二階段追著打。


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


func test_phase_two_chases_and_hits_caravan() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(60, 1, 60)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.position = Vector3(-3, 0, 7)
	root.add_child(player)
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(4, 0, 0), Vector3(4, 0, -30)])
	root.add_child(caravan)
	caravan.runner.speed = 0.4
	var boss := Undertaker.new()
	boss.state = GameState.new()
	boss.position = Vector3(0, 0, 4)
	root.add_child(boss)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(boss.target == player, "第一階段追最近的心跳（諾恩）")
	boss.enter_phase_two()
	await tree.physics_frame
	await tree.physics_frame
	assert_true(boss.target == caravan, "第二階段優先追車隊")
	var hits: Array[int] = [0]
	caravan.hit_taken.connect(func(_n: int) -> void: hits[0] += 1)
	for i: int in 400:
		await tree.physics_frame
		if hits[0] > 0:
			break
	assert_true(hits[0] > 0, "送葬者打中車隊")
	assert_eq(caravan.runner.injured, 1, "多一名傷者")
	assert_true(caravan.runner.is_stopped(), "車隊停下")
	assert_eq(caravan.health.hp, caravan.health.max_hp, "車隊的生命值不會真的掉")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


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
