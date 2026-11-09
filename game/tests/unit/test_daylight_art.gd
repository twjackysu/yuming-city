extends TestCase
## 白晝城街道的美術（第 56 輪，D-174）：常數之間的關係與材質參數。場景層面在主線流程測試的 _assert_daylight_art 檢查。

const DAYLIGHT: String = "res://scenes/levels/daylight.gd"


func _const(name: String) -> Variant:
	return (load(DAYLIGHT) as GDScript).get_script_constant_map()[name]


func _level() -> Node:
	return (load(DAYLIGHT) as GDScript).new() as Node


func test_stone_band_below_first_windows() -> void:
	var h: float = float(_const("STREET_STONE_H"))
	assert_true(h >= 0.5, "牆腳石塊看得出來（至少半公尺）")
	assert_true(h + 0.1 < 1.9 - 0.07, "牆腳石塊在一樓的窗台下面（窗板底 1.9 m）")


func test_street_wall_is_stone_and_plaster_without_frame() -> void:
	var lv: Node = _level()
	var m: ShaderMaterial = lv.call("street_wall_mat") as ShaderMaterial
	assert_eq(m.shader.resource_path, FrostbridgeLook.HALF_TIMBER_SHADER, "房子的牆用半木構 shader 的室內版")
	assert_eq(float(m.get_shader_parameter("exterior")), 0.0, "不積雪、牆腳不濕（地底城沒有雪）")
	assert_eq(float(m.get_shader_parameter("stone_height")), float(_const("STREET_STONE_H")), "牆腳石塊的高度")
	assert_true(float(m.get_shader_parameter("post_spacing")) >= 99.0, "沒有木框（石頭砌的房子）")
	assert_eq(float(m.get_shader_parameter("brace_chance")), 0.0, "沒有斜撐")
	assert_eq(float(m.get_shader_parameter("soot")), 0.0, "不燻黑（白晝城沒有火）")
	assert_true(lv.call("street_wall_mat") == m, "同一個材質（共用）")
	lv.free()


func test_paving_and_shutters() -> void:
	var lv: Node = _level()
	var paving: ShaderMaterial = lv.call("paving_mat") as ShaderMaterial
	assert_eq(paving.shader.resource_path, InteriorLook.PLANK_SHADER, "地面是石板（plank_wood 關掉木紋）")
	assert_eq(float(paving.get_shader_parameter("grain_amount")), 0.0, "石板沒有木紋")
	assert_true(bool(paving.get_shader_parameter("along_z")), "沿街（南北）鋪")
	var shutter: ShaderMaterial = lv.call("shutter_mat") as ShaderMaterial
	assert_true(bool(shutter.get_shader_parameter("vertical_planks")), "窗板是直排木板")
	assert_true(float(shutter.get_shader_parameter("seam_dark")) < 0.6, "板縫不要太深（太深像鐵窗）")
	var ashlar: ShaderMaterial = lv.call("ashlar_mat") as ShaderMaterial
	assert_true(float(ashlar.get_shader_parameter("stone_height")) >= 99.0, "盡頭的牆整面方石")
	lv.free()


func test_trim_lighter_than_wall_stone() -> void:
	var trim: Color = _const("TRIM_STONE") as Color
	var stone: Color = _const("STONE") as Color
	assert_true(trim.get_luminance() > stone.get_luminance() + 0.08, "窗台、門楣比牆腳石淺（看得出一條）")


func test_dome_ribs_cover_whole_city() -> void:
	var lv: Node = _level()
	var n: int = int(lv.call("dome_rib_count"))
	var span: float = float(_const("GATE_Z")) - float(_const("END_Z"))
	assert_true(n >= int(span / float(_const("RIB_SPACING"))), "拱肋從後門排到街尾（%d 道）" % n)
	var rib: Vector2 = _const("RIB_SIZE") as Vector2
	assert_true(float(_const("CEILING_Y")) - rib.x > 12.0, "拱肋在高處，不擋路")
	lv.free()


func test_furnace_bands_on_body() -> void:
	var bands: PackedFloat32Array = _const("FURNACE_BANDS") as PackedFloat32Array
	assert_eq(bands.size(), 3, "三道鐵箍")
	for y: float in bands:
		assert_true(y > 0.16 and y < 2.1, "鐵箍 %.2f 在石座上面、爐身頂（2.1 m）下面" % y)
	assert_true(float(_const("FURNACE_PIPE_JOINT")) > 1.0, "煙管接頭不要太密")


## 第 57 輪（D-175）：後門的通道——台階在天花板下面、門板放得進平台、通道往裡變黑（油燈照常照得到）
func test_back_door_passage() -> void:
	var steps: int = int(_const("PASSAGE_STEPS"))
	var rise: float = float(_const("STEP_RISE"))
	assert_true(steps >= 4, "看得出是往上的樓梯（至少 4 階）")
	assert_true(rise >= 0.12 and rise <= 0.2, "一階的高度像樓梯（%.2f m）" % rise)
	assert_true(float(steps) * rise + 1.9 < float(_const("PASSAGE_CEILING")) + float(steps) * rise * 0.5 + 0.1, "最上一階還站得下一個人")
	var leaf: Vector2 = _const("GATE_DOOR_LEAF") as Vector2
	assert_true(leaf.x <= float(_const("PASSAGE_LANDING")), "門板靠牆時在平台範圍內（不插進台階）")
	assert_true(leaf.y < float(_const("GATE_H")), "門板比門洞矮")
	assert_true(float(_const("PASSAGE_DARK")) <= (load(DAYLIGHT) as GDScript).call("passage_length") as float, "走到台階頂之前就暗了")
	var lv: Node = _level()
	var m: ShaderMaterial = lv.call("passage_mat", Color(0.3, 0.3, 0.3)) as ShaderMaterial
	assert_eq(m.shader.resource_path, str(_const("DARK_PASSAGE_SHADER")), "通道用 dark_passage shader")
	assert_true(lv.call("passage_mat", Color(0.3, 0.3, 0.3)) == m, "同一個顏色共用材質")
	assert_true(float(m.get_shader_parameter("min_ambient")) < 0.1, "最深處幾乎沒有環境光")
	var origin: Vector3 = m.get_shader_parameter("dark_origin") as Vector3
	assert_true(origin.z > float(_const("GATE_Z")), "從牆後面才開始變暗（門框還是亮的）")
	lv.free()
	var code: String = (load(str(_const("DARK_PASSAGE_SHADER"))) as Shader).code
	assert_true(code.contains("AO_LIGHT_AFFECT = 0.0"), "只壓環境光，油燈的直接光照得到")


## 門房：矮牆比桌面低（從廣場看得到桌子與孩子）、屋頂往東斜、小窗在牆裡
func test_gatehouse_proportions() -> void:
	assert_true(float(_const("GATEHOUSE_SILL_H")) < 0.76 - 0.1, "前面的矮牆比桌面低")
	assert_true(float(_const("GATEHOUSE_ROOF_BACK_Y")) > float(_const("GATEHOUSE_ROOF_FRONT_Y")), "屋頂靠牆那端高、屋簷那端低")
	assert_true(float(_const("GATEHOUSE_ROOF_FRONT_Y")) >= 2.6, "屋簷下走得過去")
	var entry: Vector2 = _const("GATEHOUSE_ENTRY") as Vector2
	assert_true(entry.y - entry.x >= 0.9, "入口寬得讓人走進去")
	assert_true(entry.y < float(_const("GATE_Z")), "入口在廣場裡")
	var w: Vector4 = _const("GATEHOUSE_WINDOW") as Vector4
	assert_true(w.x - w.z * 0.5 > -float(_const("SQUARE_HALF")) and w.x + w.z * 0.5 < float(_const("GATEHOUSE_FRONT_X")) - 0.4, "小窗在北牆裡（不切到前面的石柱）")
	assert_true(w.y + w.w < float(_const("GATEHOUSE_WALL_H")) - 0.3, "窗上面還有一段牆")


## 晾衣繩：往下垂、兩端在煙管與東牆；衣服是起伏的薄片，不是方塊
func test_laundry_rope_and_garments() -> void:
	var script: GDScript = load(DAYLIGHT) as GDScript
	var a: Vector3 = script.call("rope_point", 0.0) as Vector3
	var b: Vector3 = script.call("rope_point", 1.0) as Vector3
	var mid: Vector3 = script.call("rope_point", 0.5) as Vector3
	assert_true(a.is_equal_approx(_const("ROPE_FROM") as Vector3) and b.is_equal_approx(_const("ROPE_TO") as Vector3), "繩子兩端")
	assert_true(mid.y < minf(a.y, b.y) - 0.1, "中間往下垂")
	var outlines: Array = script.call("garment_outlines") as Array
	assert_eq(outlines.size(), 4, "四件衣服")
	for i: int in outlines.size():
		var o: PackedVector2Array = outlines[i] as PackedVector2Array
		assert_false(Geometry2D.triangulate_polygon(o).is_empty(), "第 %d 件的輪廓能三角化" % i)
		var mesh: ArrayMesh = script.call("garment_mesh", o, i) as ArrayMesh
		var box: AABB = mesh.get_aabb()
		assert_true(box.size.z > 0.005 and box.size.z < 0.1, "第 %d 件有起伏、但還是薄的（%.3f m）" % [i, box.size.z])
		assert_true(mid.y + box.position.y > 1.6, "第 %d 件掛得比人高（不擋路）" % i)


## 壽命石碑：磨亮的黑石（映著穹頂的淡光），光澤很淡、字還是最亮的
func test_stele_polished_stone() -> void:
	var lv: Node = _level()
	var m: ShaderMaterial = lv.call("stele_stone_mat") as ShaderMaterial
	assert_eq(m.shader.resource_path, str(_const("POLISHED_STONE_SHADER")), "石碑用 polished_stone shader")
	var code: String = m.shader.code
	for u: String in ["sheen_top = 0.0", "sheen_rim = 0.0"]:
		assert_true(code.contains(u), "光澤很淡（%s…）" % u)
	assert_true((m.get_shader_parameter("sheen_color") as Color).is_equal_approx(_const("DOME_WHITE") as Color), "映的是穹頂的白燈")
	lv.free()
