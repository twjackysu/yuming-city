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
