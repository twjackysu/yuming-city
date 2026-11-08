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


## D-115：shader 宣告了 fade_near／fade_far 的 ShaderMaterial 也會淡；沒宣告的（例如前兆範圍）不動。
func test_apply_sets_shader_fade() -> void:
	var root := Node3D.new()
	var iron: ShaderMaterial = Undertaker.frame_iron_material()
	var bar := CSGBox3D.new()
	bar.material = iron
	root.add_child(bar)
	var other := ShaderMaterial.new()
	other.shader = Shader.new()
	other.shader.code = "shader_type spatial;\nuniform float strength = 1.0;\nvoid fragment() { ALBEDO = vec3(strength); }\n"
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = other
	root.add_child(mi)
	var n: int = CameraFade.apply(root, 0.4, 1.0)
	assert_eq(n, 1, "只有鐵架材質")
	assert_true(absf(float(iron.get_shader_parameter("fade_near")) - 0.4) < 0.001 and absf(float(iron.get_shader_parameter("fade_far")) - 1.0) < 0.001, "鐵架的淡出距離")
	assert_true(other.get_shader_parameter("fade_far") == null, "沒有淡出 uniform 的 shader 不動")
	root.free()


## D-115（第四輪盤點第 6 項）：席菈、灰巡者、送葬者離鏡頭 1 m 以內淡掉（鏡頭在他們身體裡時不會整個畫面被擋住）。
func test_characters_fade_near_camera() -> void:
	var actors: Array[Node3D] = [Sheila.new(), Ashwalker.new(), Undertaker.new()]
	for a: Node3D in actors:
		tree.root.add_child(a)
		var far: float = CameraFade.CHARACTER_FAR
		if a is EnemyActor:
			far = (a as EnemyActor).camera_fade_range().y
		var faded: int = 0
		var opaque: int = 0
		for g: Node in a.find_children("*", "GeometryInstance3D", true, false):
			var mats: Array[Material] = []
			if g is CSGPrimitive3D and (g as CSGPrimitive3D).get("material") is Material:
				mats.append((g as CSGPrimitive3D).get("material") as Material)
			if (g as GeometryInstance3D).material_override != null:
				mats.append((g as GeometryInstance3D).material_override)
			if g is MeshInstance3D and (g as MeshInstance3D).mesh is PrimitiveMesh and ((g as MeshInstance3D).mesh as PrimitiveMesh).material != null:
				mats.append(((g as MeshInstance3D).mesh as PrimitiveMesh).material)
			for m: Material in mats:
				if m is BaseMaterial3D:
					var b := m as BaseMaterial3D
					if b.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER and absf(b.distance_fade_max_distance - far) < 0.001:
						faded += 1
					elif b.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED:
						opaque += 1
				elif m is ShaderMaterial and (m as ShaderMaterial).shader.resource_path == Undertaker.FRAME_IRON_SHADER:
					assert_true(absf(float(m.get_shader_parameter("fade_far")) - far) < 0.001, "送葬者的鐵架也淡")
					faded += 1
		assert_true(faded >= 5, "%s 的身體材質靠近鏡頭會淡（%d 個）" % [a.name, faded])
		assert_eq(opaque, 0, "%s 沒有漏掉的材質" % a.name)
		a.queue_free()
	await tree.process_frame
	assert_true(CameraFade.CHARACTER_NEAR < CameraFade.CHARACTER_FAR and CameraFade.CHARACTER_FAR <= 1.2, "一般角色只在很近的時候淡（不影響一般戰鬥距離）")
	var big := Vector2(Undertaker.BIG_FADE_NEAR, Undertaker.BIG_FADE_FAR)
	assert_true(big.y > CameraFade.CHARACTER_FAR and big.y < 2.5, "送葬者體型大，淡出範圍比較遠（%.1f m），但不到鎖定時的距離" % big.y)

