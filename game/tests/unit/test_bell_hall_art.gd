extends TestCase
## 鐘院飯廳的美術（第 54 輪，D-172）：常數之間的關係。場景層面（木板地、牆、白印、白燈）在主線流程測試的 _assert_bell_hall 檢查。

const HALL: String = "res://scenes/levels/bell_hall.gd"


func _const(name: String) -> Variant:
	return (load(HALL) as GDScript).get_script_constant_map()[name]


## 半木構 shader 的立柱在 u ≡ post_spacing / 2（mod post_spacing）；東西牆的 u＝世界 z
func _post_offset(u: float, spacing: float) -> float:
	var m: float = fposmod(u, spacing)
	return absf(m - spacing * 0.5)


func test_beams_rest_on_side_wall_posts() -> void:
	var spacing: float = float(_const("POST_SPACING"))
	for z: float in _const("BEAM_ZS") as Array:
		assert_true(_post_offset(z, spacing) < 0.01, "橫樑 z=%.1f 落在東西牆的壁柱上" % z)


func test_faded_frames_sit_on_plaster_between_posts() -> void:
	var spacing: float = float(_const("POST_SPACING"))
	var dado: float = float(_const("DADO_H"))
	var wall_h: float = float(_const("WALL_H"))
	var half: Vector2 = _const("ROOM_HALF") as Vector2
	var door_w: float = float(_const("DOOR_W"))
	for f: Array in _const("FADED_FRAMES") as Array:
		var u: float = float(f[1])
		var y: float = float(f[2])
		var w: float = float(f[3])
		var h: float = float(f[4])
		var tag: String = "%s %.1f" % [str(f[0]), u]
		assert_true(str(f[0]) in ["N", "W", "E"], tag + " 牆的代號")
		assert_true(y - h * 0.5 > dado + 0.3, tag + " 在石塊牆腳上面")
		assert_true(y + h * 0.5 + 0.15 < wall_h - 0.3, tag + " 離天花板（橫樑）有距離、釘子也在牆上")
		var along: float = half.x if str(f[0]) == "N" else half.y
		assert_true(absf(u) + w * 0.5 < along - 0.2, tag + " 不超出牆")
		# 不壓在壁柱上：白印的兩邊都離最近的壁柱中心至少半根柱寬
		var first: float = ceilf((u - w * 0.5 - spacing * 0.5) / spacing) * spacing + spacing * 0.5
		assert_true(first > u + w * 0.5 + 0.08 or first < u - w * 0.5 - 0.08, tag + " 在兩根壁柱之間")
		if str(f[0]) == "N":
			assert_true(absf(u) - w * 0.5 > door_w * 0.5 + 0.3, tag + " 不壓到內室的門框")


func test_hall_wall_is_quiet_interior() -> void:
	var src: String = (load(HALL) as GDScript).source_code
	assert_true(src.contains("\"brace_chance\": 0.0"), "城主家的牆沒有斜撐")
	assert_true(src.contains("\"soot\": 0.0"), "沒有爐火、不燻黑")


func test_flagstone_is_plank_without_grain() -> void:
	var look := InteriorLook.new()
	var m: ShaderMaterial = look.flagstone("t", Color(0.3, 0.3, 0.3), 0.9, {"wear": 0.4})
	assert_eq(m.shader.resource_path, InteriorLook.PLANK_SHADER, "石板沿用木板 shader")
	assert_eq(float(m.get_shader_parameter("grain_amount")), 0.0, "沒有木紋")
	assert_true(is_equal_approx(float(m.get_shader_parameter("plank_length")), 0.9 * 1.4), "長是寬的 1.4 倍")
	assert_eq(float(m.get_shader_parameter("wear")), 0.4, "opts 蓋過預設")
	assert_true(look.flagstone("t", Color.WHITE, 2.0) == m, "同一個 key 共用材質")
	var code: String = (load(InteriorLook.PLANK_SHADER) as Shader).code
	assert_true(code.contains("uniform float grain_amount : hint_range(0.0, 1.0) = 1.0;"), "預設有木紋（酒館、柯德家不變）")
