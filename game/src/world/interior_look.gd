class_name InteriorLook
extends RefCounted
## 室內材質（第 53 輪，D-171）：酒館、柯德家共用；之後的室內場景照用。同一個 key 共用一個材質。
## - plank()：plank_wood.gdshader（世界座標木板：地板、天花板、桌面、門板、櫥櫃；不靠 CSG／BoxMesh 的 UV）
## - wall()：half_timber.gdshader 的室內版（exterior 0：不積雪、牆腳不濕）——牆腳石塊＋灰泥＋木框，天花板下燻黑
## - timber()：整根木頭（板寬拉大＝沒有板縫、只有木紋）：橫樑、桌腳、門框
## - flagstone()：石板（plank_wood.gdshader 關掉木紋）：鐘院內室的地板與天花板（第 54 輪，D-172）

const PLANK_SHADER: String = "res://src/world/plank_wood.gdshader"

var _mats: Dictionary = {}


## 木板。opts 直接設成 shader 參數（along_z、vertical_planks、wear、wet_spot、seam_dark、base_roughness）。
func plank(key: String, color: Color, width: float, length: float, opts: Dictionary = {}) -> ShaderMaterial:
	var k: String = "plank/" + key
	if _mats.has(k):
		return _mats[k] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(PLANK_SHADER) as Shader
	m.set_shader_parameter("wood_color", color)
	m.set_shader_parameter("plank_width", width)
	m.set_shader_parameter("plank_length", length)
	for p: String in opts:
		m.set_shader_parameter(p, opts[p])
	_mats[k] = m
	return m


## 整根木頭：沒有板縫、只有木紋。
func timber(color: Color, roughness: float = 0.82) -> ShaderMaterial:
	return plank("timber/%s/%.2f" % [color.to_html(), roughness], color, 8.0, 60.0, {"base_roughness": roughness})


## 室內牆：stone_h 以下石塊、以上灰泥＋木框。opts 直接設成 shader 參數
## （floor_height、post_spacing、beam_width、brace_chance、block_scale、soot、soot_top、soot_depth）。
## 不要木框：floor_height、post_spacing 設很大、brace_chance 0（只剩石塊上緣一道橫木）。
func wall(key: String, plaster: Color, stone: Color, stone_h: float, opts: Dictionary = {}) -> ShaderMaterial:
	var k: String = "wall/" + key
	if _mats.has(k):
		return _mats[k] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = load(FrostbridgeLook.HALF_TIMBER_SHADER) as Shader
	m.set_shader_parameter("plaster_color", plaster)
	m.set_shader_parameter("stone_color", stone)
	m.set_shader_parameter("stone_height", stone_h)
	m.set_shader_parameter("exterior", 0.0)
	for p: String in opts:
		m.set_shader_parameter(p, opts[p])
	_mats[k] = m
	return m



## 石板（地板，也可以當石頭天花板）：plank_wood.gdshader 關掉木紋（grain_amount 0）＝錯縫的長方形石板＋斑駁。
## size＝石板寬（公尺），長是寬的 1.4 倍上下浮動。opts 同 plank()。
func flagstone(key: String, color: Color, size: float, opts: Dictionary = {}) -> ShaderMaterial:
	var o: Dictionary = {"grain_amount": 0.0, "seam_dark": 0.6, "base_roughness": 0.72}
	o.merge(opts, true)
	return plank("stone/" + key, color, size, size * 1.4, o)
