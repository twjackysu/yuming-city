extends TestCase
## 冬夜天空（D-117）：背景用 sky shader（雲、月光、遠山），霧只蓋掉天空的一部分。


func test_environment_uses_night_sky() -> void:
	var root := Node3D.new()
	var env: Environment = FrostbridgeLook.build_environment(root)
	assert_eq(env.background_mode, Environment.BG_SKY, "背景是天空，不是一片平的顏色")
	assert_not_null(env.sky, "有 Sky")
	var mat: ShaderMaterial = env.sky.sky_material as ShaderMaterial
	assert_not_null(mat, "天空是 ShaderMaterial")
	assert_eq(mat.shader.resource_path, FrostbridgeLook.NIGHT_SKY_SHADER)
	assert_true(env.volumetric_fog_sky_affect < 0.8, "體積霧不把天空整片蓋掉")
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, "環境光照舊用顏色（天空不改變整體亮度）")
	QualityPreset.apply_environment(env, QualityPreset.Level.LOW)
	assert_true(env.fog_enabled, "低畫質用深度霧")
	assert_true(env.fog_sky_affect < 0.8, "低畫質的深度霧也不把天空整片蓋掉")
	root.free()


func test_sky_shader_is_static() -> void:
	# 用了 TIME 的天空每幀都要重算反射用的 radiance；雲要動之前先擋住
	var shader: Shader = load(FrostbridgeLook.NIGHT_SKY_SHADER) as Shader
	assert_not_null(shader)
	for line: String in shader.code.split("\n"):
		var code: String = line.split("//")[0]
		assert_false(code.contains("TIME"), "天空 shader 不用 TIME：%s" % line.strip_edges())
	assert_true(shader.code.contains("AT_CUBEMAP_PASS"), "星星不畫進反射")
