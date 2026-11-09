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
