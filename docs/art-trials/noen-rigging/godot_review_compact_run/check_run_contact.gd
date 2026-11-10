extends SceneTree
func find_type(node: Node, type_name: String):
 if node.is_class(type_name): return node
 for child in node.get_children():
  var found = find_type(child, type_name)
  if found: return found
 return null
func collect_meshes(node: Node, result: Array):
 if node is MeshInstance3D and node.skin: result.append(node)
 for child in node.get_children(): collect_meshes(child, result)
func _initialize(): call_deferred("check")
func check():
 var actor = load("res://noen_walk_preview.glb").instantiate()
 root.add_child(actor)
 var player = find_type(actor, "AnimationPlayer")
 var skeleton = find_type(actor, "Skeleton3D")
 var meshes: Array = []
 collect_meshes(actor, meshes)
 var clip = ""
 for name in player.get_animation_list():
  if name != "RESET": clip = name; break
 if clip.is_empty(): quit(2); return
 if not player.has_animation("run"): push_error("Missing idle"); quit(2); return
 print("CONTACT_CLIP run length=", player.get_animation("run").length)
 player.play("run"); player.pause()
 var failed = false
 var expected = JSON.parse_string(FileAccess.get_file_as_string("res://retarget_cycle.json")).retarget_boot_height_m
 for frame in range(20):
  var time = float(frame) / 30.0
  player.seek(time, true)
  await process_frame
  await process_frame
  var lowest = INF
  for mesh in meshes:
   var skin: Skin = mesh.skin
   for surface in range(mesh.mesh.get_surface_count()):
    var arrays = mesh.mesh.surface_get_arrays(surface)
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
  print("RUN_CONTACT ", frame, " ", lowest, " expected=", expected[frame], " error=", abs(lowest-expected[frame]))
  if not is_finite(lowest) or (lowest < -0.003 or abs(lowest-expected[frame]) > 0.003): failed = true
 quit(3 if failed else 0)
