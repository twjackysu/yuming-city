extends SceneTree
func find_type(node: Node, type_name: String):
 if node.is_class(type_name): return node
 for child in node.get_children():
  var found = find_type(child, type_name)
  if found: return found
 return null
func _initialize(): call_deferred("check")
func check():
 var actor = load("res://undertaker_walk_preview.glb").instantiate()
 root.add_child(actor)
 var player = find_type(actor, "AnimationPlayer")
 var skeleton = find_type(actor, "Skeleton3D")
 var report = JSON.parse_string(FileAccess.get_file_as_string("res://joint_locators.json"))
 var frame_bone = skeleton.find_bone("frame_root")
 if frame_bone < 0: quit(2); return
 var clip = ""
 for name in player.get_animation_list():
  if name != "RESET": clip = name; break
 player.play(clip); player.pause()
 var max_error = 0.0
 for frame in range(59):
  player.seek(float(frame) / 30.0, true)
  await process_frame
  await process_frame
  for locator in report.locators:
   var node = actor.find_child(locator.name, true, false)
   if not node is Node3D:
    push_error("Missing imported joint locator: " + locator.name)
    quit(3); return
   var position = locator.bone_local_position
   var expected = skeleton.global_transform * skeleton.get_bone_global_pose(frame_bone) * Vector3(position[0], position[1], position[2])
   var error = node.global_position.distance_to(expected)
   max_error = max(max_error, error)
   if error > 0.0001:
    push_error("Locator detached: %s frame %s error %s" % [locator.name, frame, error])
    quit(4); return
 print("JOINT_LOCATORS_OK count=6 frames=59 samples=354 maximum_error_m=", max_error)
 quit()
