extends SceneTree
func find_type(node: Node, type_name: String):
 if node.is_class(type_name): return node
 for child in node.get_children():
  var found = find_type(child, type_name)
  if found: return found
 return null
func _initialize(): call_deferred("check")
func check():
 var actor = load("res://noen_walk_preview.glb").instantiate()
 root.add_child(actor)
 var player = find_type(actor, "AnimationPlayer")
 var skeleton = find_type(actor, "Skeleton3D")
 for clip in ["idle", "walk"]:
  if not player.has_animation(clip): push_error("Missing clip: " + clip); quit(2); return
 var poses = {}
 for clip in ["idle", "walk", "idle", "walk"]:
  player.play(clip); player.pause(); player.seek(0.8 if clip == "idle" else 0.27, true)
  await process_frame
  await process_frame
  var pose = []
  for i in skeleton.get_bone_count(): pose.append(skeleton.get_bone_global_pose(i))
  if poses.has(clip):
   for i in pose.size():
    var a: Transform3D = pose[i]
    var b: Transform3D = poses[clip][i]
    if a.origin.distance_to(b.origin) > 0.00001 or not a.basis.is_equal_approx(b.basis):
     push_error("Pose did not restore after switching: " + clip); quit(3); return
  poses[clip] = pose
 print("CLIP_SWITCH_OK idle -> walk -> idle -> walk bones=", skeleton.get_bone_count())
 quit()
