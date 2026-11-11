extends TestCase
## 粒子外觀（D-056）：所有粒子面片都有圓形貼圖，不會是硬邊方塊。


func test_dots_are_shared_radial_textures() -> void:
	var soft: GradientTexture2D = ParticleLook.soft_dot()
	var hot: GradientTexture2D = ParticleLook.hot_dot()
	assert_true(soft == ParticleLook.soft_dot(), "柔邊圓點只建一次、大家共用")
	assert_true(hot == ParticleLook.hot_dot(), "火星亮點只建一次")
	assert_ne(soft, hot)
	for t: GradientTexture2D in [soft, hot]:
		assert_eq(t.fill, GradientTexture2D.FILL_RADIAL, "圓形")
		assert_true(is_equal_approx(t.gradient.sample(0.0).a, 1.0), "中心全亮")
		assert_true(t.gradient.sample(1.0).a < 0.01, "邊緣透明")
	# 火星的亮心比粉塵大、邊緣比較快淡掉
	assert_true(hot.gradient.sample(0.3).a > soft.gradient.sample(0.3).a, "火星亮心較大")
	assert_eq(EnemyActor.soft_dot_texture(), soft, "敵人倒地粉塵用同一張")


func test_material_additive_for_sparks() -> void:
	var dust: StandardMaterial3D = ParticleLook.material(Color(0.7, 0.7, 0.7, 0.6))
	assert_eq(dust.blend_mode, BaseMaterial3D.BLEND_MODE_MIX, "粉塵一般透明")
	assert_eq(dust.albedo_texture, ParticleLook.soft_dot())
	assert_eq(dust.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	var spark: StandardMaterial3D = ParticleLook.material(Color(1, 0.5, 0.1), true)
	assert_eq(spark.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "火星加法混色")
	assert_eq(spark.albedo_texture, ParticleLook.hot_dot())
	var ash: StandardMaterial3D = ParticleLook.material(Color.GRAY, false, BaseMaterial3D.BILLBOARD_PARTICLES)
	assert_eq(ash.billboard_mode, BaseMaterial3D.BILLBOARD_PARTICLES)
