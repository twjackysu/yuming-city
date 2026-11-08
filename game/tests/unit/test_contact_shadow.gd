extends TestCase
## 接地陰影（D-108）：諾恩、席菈、灰巡者腳下都有一片貼地、不投影的陰影。


func test_actors_have_contact_shadow() -> void:
	var actors: Array[Node3D] = [Sheila.new(), Ashwalker.new()]
	for a: Node3D in actors:
		tree.root.add_child(a)
		var mi: MeshInstance3D = a.get_node_or_null(ContactShadow.NODE_NAME) as MeshInstance3D
		assert_not_null(mi, "%s 腳下有接地陰影" % a.get_class())
		if mi != null:
			assert_true(mi.position.y > 0.0 and mi.position.y < 0.03, "貼地")
			assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "自己不投影")
			var plane: PlaneMesh = mi.mesh as PlaneMesh
			assert_true(plane.size.x > 0.8 and plane.size.x < 1.6, "大小跟人差不多（%.2f）" % plane.size.x)
		a.queue_free()
	await tree.process_frame


func test_attach_builds_soft_disc() -> void:
	var root := Node3D.new()
	var mi: MeshInstance3D = ContactShadow.attach(root, 0.5, 0.4)
	assert_eq(mi.get_parent(), root)
	var m: ShaderMaterial = mi.material_override as ShaderMaterial
	assert_true(m.shader.resource_path.ends_with("ground_shadow.gdshader"), "跟送葬者同一個 shader")
	assert_true(absf(float(m.get_shader_parameter("strength")) - 0.4) < 0.001, "強度")
	root.free()
