extends SceneTree
func find_type(node: Node, type_name: String):
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found = find_type(child, type_name)
		if found: return found
	return null
func collect_boots(node: Node, result: Array):
	if node is MeshInstance3D and "Boot" in node.name: result.append(node)
	for child in node.get_children(): collect_boots(child, result)
func _initialize():
	call_deferred("check")
func check():
	var actor = load("res://noen_walk_preview.glb").instantiate()
	root.add_child(actor)
	var player = find_type(actor, "AnimationPlayer")
	var skeleton = find_type(actor, "Skeleton3D")
	var boots: Array = []
	collect_boots(actor, boots)
	print("BOOTS ", boots.size())
	if boots.size() != 2:
		quit(2)
		return
	player.play("walk")
	player.pause()
	for time in [0.0, 0.28, 0.56, 0.84]:
		player.seek(time, true)
		await process_frame
		await process_frame
		var lowest = INF
		for boot in boots:
			var skin: Skin = boot.skin
			for surface in range(boot.mesh.get_surface_count()):
				var arrays = boot.mesh.surface_get_arrays(surface)
				var vertices = arrays[Mesh.ARRAY_VERTEX]
				var bones = arrays[Mesh.ARRAY_BONES]
				var weights = arrays[Mesh.ARRAY_WEIGHTS]
				var influences = bones.size() / vertices.size()
				for index in arrays[Mesh.ARRAY_INDEX]:
					var point = Vector3.ZERO
					for influence in range(influences):
						var offset = index * influences + influence
						var bind_index = bones[offset]
						var bone = skin.get_bind_bone(bind_index)
						if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind_index))
						point += (skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind_index) * vertices[index]) * weights[offset]
					lowest = min(lowest, (skeleton.global_transform * point).y)
		print("GROUND ", time, " ", lowest)
		if not is_finite(lowest) or abs(lowest) > 0.003:
			quit(3)
			return
	quit()
