extends TestCase
## 乾運河的美術（第 55 輪，D-173）：常數之間的關係與 shader 參數。場景層面在主線流程測試的 _assert_canal_art 檢查。

const CANAL: String = "res://scenes/levels/canal.gd"


func _const(name: String) -> Variant:
	return (load(CANAL) as GDScript).get_script_constant_map()[name]


func test_tide_line_sits_on_canal_wall() -> void:
	var bed_y: float = float(_const("BED_Y"))
	var tide: float = float(_const("TIDE_Y"))
	assert_true(tide > bed_y + 1.0, "舊水位線在河床上方一公尺以上（看得出是水位，不是牆腳髒）")
	assert_true(tide < -1.0, "舊水位線在岸頂下面（從岸上往下看得到線上一截乾的石頭）")
	assert_true(tide > bed_y + float(_const("SLUICE_PIER_H")) * 0.5, "閘道的矮石牆有一半泡過水")


func test_puddle_inside_wet_strip_and_canal() -> void:
	var x: float = float(_const("PUDDLE_X"))
	var half_w: float = float(_const("CANAL_HALF_W"))
	assert_true(absf(x) + 0.55 < half_w - 0.5, "水窪在河道中間、離兩邊的牆有距離")


func test_dry_mud_shader_defaults() -> void:
	var sh: Shader = load("res://src/world/dry_mud.gdshader") as Shader
	assert_not_null(sh, "dry_mud.gdshader 讀得到")
	var names: PackedStringArray = []
	for u: Dictionary in sh.get_shader_uniform_list():
		names.append(str(u["name"]))
	for n: String in ["mud_color", "crack_color", "cell_size", "crack_width", "wet_x", "wet_half"]:
		assert_true(n in names, "dry_mud 有參數 " + n)


func test_half_timber_tide_defaults_off() -> void:
	# 鎮上與室內的牆不受影響：tide_amount 預設 0
	var sh: Shader = load(FrostbridgeLook.HALF_TIMBER_SHADER) as Shader
	assert_true(sh.code.contains("uniform float tide_amount : hint_range(0.0, 1.0) = 0.0;"), "半木構 shader 的舊水位線預設關掉")


func test_mud_patch_under_the_fall_spots() -> void:
	var c: Vector3 = _const("MUD_PATCH_CENTER") as Vector3
	var r: Vector2 = _const("MUD_PATCH_RADIUS") as Vector2
	for p: Vector3 in _const("MUD_SPOTS") as PackedVector3Array:
		var q := Vector2((p.x - c.x) / r.x, (p.z - c.z) / r.y)
		assert_true(q.length() < 0.85, "摔下來的位置 %s 在泥裡" % str(p))
	assert_true(c.x - r.x * 1.3 > float(_const("CANAL_HALF_W")) + 0.4, "泥（含凸出去的邊）不壓到矮牆")


func test_mud_blob_mesh_faces_up() -> void:
	var script: GDScript = load(CANAL) as GDScript
	var mesh: ArrayMesh = script.call("mud_blob_mesh", Vector2(1.0, 0.6), 3) as ArrayMesh
	assert_eq(mesh.get_surface_count(), 1, "一個 surface")
	var faces: PackedVector3Array = mesh.get_faces()
	assert_true(faces.size() >= 28 * 3, "邊緣有 28 段")
	for i: int in range(0, faces.size(), 3):
		var nrm: Vector3 = (faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i])
		assert_true(nrm.y > 0.0, "第 %d 個三角形朝上（Godot 順時針是正面）" % (i / 3))
		if nrm.y <= 0.0:
			break


func test_debris_stone_is_soaked_wall_stone() -> void:
	# 河床碎石（D-198）：比牆石暗（泡過水）、偏綠灰（g 不低於 r），但比舊水位線下的牆面亮一點（斷面）
	var wall: Color = _const("WALL_STONE") as Color
	var d: Color = _const("DEBRIS_STONE") as Color
	assert_true(d.get_luminance() < wall.get_luminance(), "碎石比乾的牆石暗")
	assert_true(d.g >= d.r and d.b < d.r, "碎石偏綠灰")
	var stained: Color = Color(wall.r * 0.56, wall.g * 0.6, wall.b * 0.54)
	assert_true(d.get_luminance() > stained.get_luminance(), "碎石的斷面比水位線下的牆面亮一點")
	assert_true(float(_const("DEBRIS_LUMP_R")) > 0.5 and float(_const("DEBRIS_LUMP_R")) < 1.0, "多面體半徑照救援點的比例（乘上原本方塊的大小）")
