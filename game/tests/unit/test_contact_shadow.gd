extends TestCase
## 接地陰影：諾恩、席菈、灰巡者腳下都有一片貼地、不投影的陰影。


func test_attach_builds_soft_disc() -> void:
	var root := Node3D.new()
	var mi: MeshInstance3D = ContactShadow.attach(root, 0.5, 0.4)
	assert_eq(mi.get_parent(), root)
	var m: ShaderMaterial = mi.material_override as ShaderMaterial
	assert_true(m.shader.resource_path.ends_with("ground_shadow.gdshader"), "跟送葬者同一個 shader")
	assert_true(absf(float(m.get_shader_parameter("strength")) - 0.4) < 0.001, "強度")
	root.free()
