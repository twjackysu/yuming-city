extends TestCase
## 一百七十二階的美術（第 56 輪，D-174）：井壁整面方石、平台石板、台階三種深淺輪流。

const STAIRS: String = "res://scenes/levels/stairs.gd"


func test_shaft_wall_is_ashlar() -> void:
	var lv: Node = (load(STAIRS) as GDScript).new() as Node
	var m: ShaderMaterial = lv.call("shaft_wall_mat") as ShaderMaterial
	assert_eq(m.shader.resource_path, FrostbridgeLook.HALF_TIMBER_SHADER, "井壁用半木構 shader 的室內版")
	assert_true(float(m.get_shader_parameter("stone_height")) >= 99.0, "整面方石")
	assert_eq(float(m.get_shader_parameter("tide_amount")) if m.get_shader_parameter("tide_amount") != null else 0.0, 0.0, "沒有水位線")
	var landing: ShaderMaterial = lv.call("landing_mat") as ShaderMaterial
	assert_eq(float(landing.get_shader_parameter("grain_amount")), 0.0, "平台是石板")
	lv.free()


func test_steps_vary_without_rng() -> void:
	var lv: Node = (load(STAIRS) as GDScript).new() as Node
	var seen: Dictionary = {}
	for i: int in 12:
		seen[lv.call("step_mat", 1, i)] = true
	assert_eq(seen.size(), 3, "同一段樓梯裡三種深淺都有")
	assert_true(lv.call("step_mat", 2, 5) == lv.call("step_mat", 2, 5), "同一階永遠同一個材質（不靠 _rng）")
	lv.free()


## 第 57 輪（D-175）：樓梯底的門是直排木板＋鐵帶（之前是素色木板）；鐵帶在門板高度裡、門框在門板外
func test_gate_door_planks_and_straps() -> void:
	var lv: Node = (load(STAIRS) as GDScript).new() as Node
	var m: ShaderMaterial = lv.call("gate_door_mat") as ShaderMaterial
	assert_true(bool(m.get_shader_parameter("vertical_planks")), "門是直排木板")
	var consts: Dictionary = (load(STAIRS) as GDScript).get_script_constant_map()
	for y: float in consts["GATE_STRAPS"] as PackedFloat32Array:
		assert_true(y > 0.1 and y < 2.0, "鐵帶 %.2f 在門板上" % y)
	assert_true(float(consts["GATE_CASING_HALF"]) > 0.55 + 0.06, "門框在門板（半寬 0.55）外面，開門時不穿過門框")
	lv.free()
