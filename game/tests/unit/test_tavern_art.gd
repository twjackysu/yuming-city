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


## 第 57 輪（D-175）：彌夏的鐘是沒有指針的座鐘（之前是小木箱）：鐘面在鐘身前面、刻度在鐘面裡、只剩一根軸
func test_clockless_clock_has_face_but_no_hands() -> void:
	var script: GDScript = load("res://scenes/levels/tavern.gd") as GDScript
	var c: Dictionary = script.get_script_constant_map()
	assert_eq(int(c["CLOCK_HOUR_MARKS"]), 12, "十二道刻度")
	assert_true(float(c["CLOCK_FACE_R"]) * 2.0 < float(c["CLOCK_W"]), "鐘面比鐘身窄")
	assert_true(float(c["CLOCK_FACE_R"]) < float(c["CLOCK_BODY_H"]) * 0.62 + 0.035, "鐘面不超出底座")
	var lv: Node3D = script.new() as Node3D
	lv.call("_build_clockless_clock", Vector3.ZERO)
	var clock: Node = lv.get_node("ClocklessClock")
	for n: String in ["ClockBody", "ClockDome", "ClockFace", "ClockBezel", "ClockMark0", "ClockSpindle"]:
		assert_true(clock.has_node(n), "座鐘有 " + n)
	var hands: int = 0
	for ch: Node in clock.get_children():
		if str(ch.name).contains("Hand"):
			hands += 1
	assert_eq(hands, 0, "沒有指針")
	lv.free()


## 窗外的光束（D-177）：從東北方窗外斜斜往下，越過吧台南端、落在地圖桌北邊；東牆四塊之間的洞剛好是窗。
func test_sun_beam_through_window() -> void:
	var script: GDScript = load("res://scenes/levels/tavern.gd") as GDScript
	var c: Dictionary = script.get_script_constant_map()
	var win: Vector3 = c["WINDOW_CENTER"]
	var size: Vector2 = c["WINDOW_SIZE"]
	var half: Vector2 = c["ROOM_HALF"]
	var dir: Vector3 = script.call("sun_beam_dir")
	var origin: Vector3 = script.call("sun_beam_origin")
	assert_true(dir.x < 0.0 and dir.y < 0.0 and dir.z > 0.0, "從東北方斜斜往下（往西南）")
	assert_true(origin.x > half.x + float(c["WALL_T"]), "光在窗外")
	# 天花板板子伸到牆外 0.5 m（x ROOM_HALF.x + 0.5）：往窗頂的光在那裡要低於天花板底
	var top: Vector3 = win + Vector3(0.0, size.x * 0.5, 0.0)
	var k: float = (origin.x - (half.x + 0.5)) / (origin.x - top.x)
	assert_true(lerpf(origin.y, top.y, k) < float(c["WALL_H"]), "光不會被伸出牆外的天花板擋住")
	# 光線接近平行（像太陽）：窗洞中心的光越過吧台（東面 x 4.95）時在吧台南端（z -0.8）以南、落在目標上；
	# 四個角落地都在目標 4.5 m 內（光斑不會拉成一長條），窗下緣的光落在吧台與地圖桌之間（x 4～5.2）
	var target: Vector3 = c["SUN_TARGET"]
	var mid: Vector3 = (win - origin).normalized()
	var at_counter: Vector3 = origin + mid * ((4.95 - origin.x) / mid.x)
	assert_true(at_counter.z > -0.8, "窗中心的光從吧台南端旁邊過（z %.2f）" % at_counter.z)
	assert_true((origin + mid * (-origin.y / mid.y)).distance_to(target) < 0.05, "窗中心的光落在目標")
	for sy: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p: Vector3 = win + Vector3(0.0, sy * size.x * 0.5, sz * size.y * 0.5)
			var ray: Vector3 = (p - origin).normalized()
			var on_floor: Vector3 = origin + ray * (-origin.y / ray.y)
			assert_true(on_floor.distance_to(target) < 4.5, "窗角 (%d, %d) 落地在目標附近（%.1f m）" % [sy, sz, on_floor.distance_to(target)])
			if sy < 0.0:
				assert_true(on_floor.x > 4.0 and on_floor.x < 5.2, "窗下緣的光落在吧台與地圖桌之間（x %.2f）" % on_floor.x)
	# 聚光燈的錐夠寬，整扇窗都在光裡（牆把多的擋掉）
	var corner_angle: float = rad_to_deg((win + Vector3(0.0, size.x * 0.5, size.y * 0.5) - origin).normalized().angle_to(dir))
	assert_true(corner_angle < float(c["SUN_ANGLE_DEG"]), "整扇窗都在光錐裡（%.1f°）" % corner_angle)
	# 東牆四塊：中間的洞剛好是窗
	var lv: Node3D = script.new() as Node3D
	lv.call("_build_east_wall", StandardMaterial3D.new())
	var names: PackedStringArray = ["WallE_N", "WallE_S", "WallE_Sill", "WallE_Head"]
	for n: String in names:
		assert_true(lv.has_node(n), "東牆有 " + n)
	var north: CSGBox3D = lv.get_node("WallE_N") as CSGBox3D
	var south: CSGBox3D = lv.get_node("WallE_S") as CSGBox3D
	var sill: CSGBox3D = lv.get_node("WallE_Sill") as CSGBox3D
	var head: CSGBox3D = lv.get_node("WallE_Head") as CSGBox3D
	assert_true(absf(north.position.z + north.size.z * 0.5 - (win.z - size.y * 0.5)) < 0.001, "北塊停在窗的北緣")
	assert_true(absf(south.position.z - south.size.z * 0.5 - (win.z + size.y * 0.5)) < 0.001, "南塊從窗的南緣開始")
	assert_true(absf(sill.size.y - (win.y - size.x * 0.5)) < 0.001, "窗下的牆到窗台")
	assert_true(absf(head.position.y - head.size.y * 0.5 - (win.y + size.x * 0.5)) < 0.001, "窗上的牆從窗頂開始")
	assert_true(absf(north.size.z + south.size.z + size.y - half.y * 2.0) < 0.001, "加起來是整面牆")
	lv.free()
