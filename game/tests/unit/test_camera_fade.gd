extends TestCase
## CameraFade（D-106）：一棵節點樹裡的材質都設成靠近鏡頭抖動淡掉；自己有淡出設定的不動；同一個材質只算一次。


func test_apply_sets_dither_fade() -> void:
	var root := Node3D.new()
	var shared := StandardMaterial3D.new()
	var box := CSGBox3D.new()
	box.material = shared
	root.add_child(box)
	var box2 := CSGBox3D.new()
	box2.material = shared
	root.add_child(box2)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.material = StandardMaterial3D.new()
	mi.mesh = mesh
	box.add_child(mi)
	var own := StandardMaterial3D.new()
	own.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	own.distance_fade_min_distance = 0.5
	own.distance_fade_max_distance = 1.0
	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	glass.material_override = own
	root.add_child(glass)
	var n: int = CameraFade.apply(root, 1.2, 2.8)
	assert_eq(n, 2, "共用的材質只算一次、自己有淡出的不算")
	assert_eq(shared.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER, "CSG 的材質")
	assert_true(absf(shared.distance_fade_min_distance - 1.2) < 0.001 and absf(shared.distance_fade_max_distance - 2.8) < 0.001, "淡出距離")
	assert_eq((mesh.material as BaseMaterial3D).distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER, "子節點的 mesh 材質")
	assert_true(absf(own.distance_fade_max_distance - 1.0) < 0.001, "自己有淡出設定的不動")
	root.free()
