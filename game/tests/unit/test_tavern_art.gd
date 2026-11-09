extends TestCase
## 酒館的美術（第 53 輪，D-171）：室內木板 shader 與半木構牆的室內版。
## 場景層面（地板、牆、窗框、蠟燭只在入夜點）在主線流程測試的 [ch1_tavern]／[ch1_dinner] 檢查。

const PLANK: String = "res://scenes/levels/tavern.gd"


func _code(path: String) -> String:
	return (load(path) as Shader).code


func test_half_timber_interior_keeps_outdoor_default() -> void:
	var code: String = _code(FrostbridgeLook.HALF_TIMBER_SHADER)
	assert_true(code.contains("uniform float exterior : hint_range(0.0, 1.0) = 1.0;"), "預設是室外（鎮上的房子不變）")
	assert_true(code.contains("uniform float soot : hint_range(0.0, 1.0) = 0.0;"), "預設不燻黑")
	# 雪與濕牆腳都乘上 exterior
	for key: String in ["ledge * 0.8 * exterior", "detail * exterior", "* 0.3)) * exterior", "* 0.28)) * exterior", "n.y) * exterior"]:
		assert_true(code.contains(key), "室內不積雪、不濕：%s" % key)


func test_plank_shader_uniforms() -> void:
	var tavern: GDScript = load(PLANK) as GDScript
	var path: String = str(tavern.get("PLANK_SHADER"))
	var code: String = _code(path)
	for u: String in ["wood_color", "plank_width", "plank_length", "along_z", "vertical_planks", "wear", "wet_spot", "seam_dark", "base_roughness"]:
		assert_true(code.contains(" %s" % u), "plank_wood 有 %s" % u)
	assert_false(code.contains("TIME"), "不用 TIME（靜態）")


func test_door_wet_spot_covers_the_door() -> void:
	var tavern: GDScript = load(PLANK) as GDScript
	var wet: Vector4 = tavern.get("DOOR_WET") as Vector4
	var door: Vector3 = tavern.get("DOOR_POS") as Vector3
	assert_true(Vector2(wet.x - door.x, wet.y - door.z).length() < 0.5, "雪水在門口")
	assert_true(wet.z >= 1.0 and wet.w > 0.0 and wet.w <= 1.0, "大小與強度合理")
