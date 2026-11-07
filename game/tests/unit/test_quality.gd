extends TestCase
## 畫質三級：環境開關、MSAA、場景載入時自動套用。


func _env() -> Environment:
	var env := Environment.new()
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.ssao_enabled = true
	env.glow_enabled = true
	return env


func test_levels_toggle_effects() -> void:
	var env: Environment = _env()
	QualityPreset.apply_environment(env, QualityPreset.Level.LOW)
	assert_false(env.volumetric_fog_enabled, "低：關體積霧")
	assert_true(env.fog_enabled, "低：改用深度霧保住氛圍")
	assert_true(env.fog_density > 0.0, "深度霧有密度")
	assert_false(env.ssao_enabled, "低：關 SSAO")
	assert_false(env.glow_enabled, "低：關 Glow")
	assert_false(env.ssr_enabled)
	QualityPreset.apply_environment(env, QualityPreset.Level.MEDIUM)
	assert_true(env.volumetric_fog_enabled, "中：體積霧")
	assert_false(env.fog_enabled, "中：不疊深度霧")
	assert_true(env.ssao_enabled and env.glow_enabled, "中：SSAO＋Glow")
	assert_false(env.ssr_enabled, "中：沒有 SSR")
	QualityPreset.apply_environment(env, QualityPreset.Level.HIGH)
	assert_true(env.ssr_enabled, "高：SSR")
	assert_true(env.volumetric_fog_enabled and env.ssao_enabled)
	assert_true(absf(env.volumetric_fog_density - 0.03) < 0.0001, "不改場景調好的霧密度")
	QualityPreset.apply_environment(null, QualityPreset.Level.HIGH)  # 不應當機


func test_msaa_and_clamp() -> void:
	assert_eq(QualityPreset.msaa_for(QualityPreset.Level.LOW), Viewport.MSAA_DISABLED)
	assert_eq(QualityPreset.msaa_for(QualityPreset.Level.MEDIUM), Viewport.MSAA_2X)
	assert_eq(QualityPreset.msaa_for(QualityPreset.Level.HIGH), Viewport.MSAA_4X)
	assert_eq(QualityPreset.clamp_level(-3), QualityPreset.Level.LOW)
	assert_eq(QualityPreset.clamp_level(9), QualityPreset.Level.HIGH)
	assert_eq(QualityPreset.NAME_KEYS.size(), 3, "每級都有名稱 key")


func test_settings_apply_to_loaded_scene() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var before: int = int(settings.get("quality"))
	settings.call("set_quality", QualityPreset.Level.LOW)
	var we := WorldEnvironment.new()
	we.environment = _env()
	tree.root.add_child(we)
	assert_false(we.environment.volumetric_fog_enabled, "新進樹的 WorldEnvironment 自動套用低畫質")
	settings.call("set_quality", QualityPreset.Level.HIGH)
	assert_true(we.environment.ssr_enabled, "改畫質時套用到目前場景")
	assert_eq(tree.root.msaa_3d, Viewport.MSAA_4X, "MSAA 跟著畫質")
	settings.call("set_quality", before)
	we.queue_free()
	await tree.process_frame
