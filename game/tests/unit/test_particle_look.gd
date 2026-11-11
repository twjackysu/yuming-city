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


## 席菈燃燒劍的火星。
func test_sheila_fire_sparks_are_round() -> void:
	var sheila := Sheila.new()
	tree.root.add_child(sheila)
	# 沒有諾恩可以跟：不跑移動（劍與火星在 _ready 就建好了）
	sheila.set_physics_process(false)
	assert_true(sheila.find_child("FireSparks", true, false) != null, "有劍上的火星")
	assert_eq(ParticleLook.untextured(sheila), [] as Array[String], "席菈身上的粒子都有圓形貼圖")
	sheila.queue_free()
	await tree.process_frame


## 重現石拱化灰的灰燼。
func test_arch_ash_is_round() -> void:
	var site := NineBreathSite.new()
	site.state = GameState.new()
	tree.root.add_child(site)
	await tree.process_frame
	assert_true(site.find_child("Ash", true, false) != null, "有化灰的灰燼")
	assert_eq(ParticleLook.untextured(site), [] as Array[String], "石拱的粒子都有圓形貼圖")
	site.queue_free()
	await tree.process_frame
