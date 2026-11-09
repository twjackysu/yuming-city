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
 var indices = {}
 for i in skeleton.get_bone_count():
  for suffix in ["RightArm", "RightHand", "LeftFoot", "RightFoot"]:
   if skeleton.get_bone_name(i).ends_with(suffix): indices[suffix] = i
 if indices.size() != 4 or not player.has_animation("idle"): quit(2); return
 player.play("idle"); player.pause()
 var minimum_drop = INF
 var maximum_drop = -INF
 var foot_start = {}
 var maximum_foot_motion = 0.0
 for frame in range(97):
  player.seek(float(frame)/30.0, true)
  await process_frame
  await process_frame
  var shoulder = skeleton.global_transform * skeleton.get_bone_global_pose(indices.RightArm).origin
  var wrist = skeleton.global_transform * skeleton.get_bone_global_pose(indices.RightHand).origin
  minimum_drop = min(minimum_drop, shoulder.y-wrist.y)
  maximum_drop = max(maximum_drop, shoulder.y-wrist.y)
  for foot in ["LeftFoot", "RightFoot"]:
   var point = skeleton.global_transform * skeleton.get_bone_global_pose(indices[foot]).origin
   if frame == 0: foot_start[foot] = point
   maximum_foot_motion = max(maximum_foot_motion, point.distance_to(foot_start[foot]))
 print("IDLE_GUARD frames=97 minimum_drop_m=",minimum_drop," maximum_drop_m=",maximum_drop," maximum_foot_bone_motion_m=",maximum_foot_motion)
 quit(0 if minimum_drop>.20 and maximum_drop<.38 and maximum_foot_motion<.0001 else 3)
