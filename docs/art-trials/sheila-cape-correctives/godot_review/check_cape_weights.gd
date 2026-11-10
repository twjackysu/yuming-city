extends SceneTree
func find_type(node: Node, type_name: String):
 if node.is_class(type_name): return node
 for child in node.get_children():
  var found = find_type(child, type_name)
  if found: return found
 return null
func find_cape(node: Node):
 if node is MeshInstance3D and node.name == "Sheila_Cape": return node
 for child in node.get_children():
  var found = find_cape(child)
  if found: return found
 return null
func _initialize(): call_deferred("check")
func check():
 var actor = load("res://sheila_walk_preview.glb").instantiate()
 root.add_child(actor)
 var player = find_type(actor, "AnimationPlayer")
 var cape = find_cape(actor)
 var expected = JSON.parse_string(FileAccess.get_file_as_string("res://cape_expected_weights.json"))
 if cape == null or cape.mesh.get_blend_shape_count() != 24 or not player.has_animation("walk"): quit(2); return
 player.play("walk"); player.pause()
 var worst = 0.0
 var worst_bound = 0.0
 var bounds = JSON.parse_string(FileAccess.get_file_as_string("res://cape_delta_bounds.json"))
 for sample in range(69):
  var frame = float(sample) * 0.5
  player.seek(frame / 30.0, true)
  await process_frame
  await process_frame
  var left = int(floor(frame))
  var right = mini(left + 1, 34)
  var mix_value = frame - float(left)
  var displacement_bound = 0.0
  for i in range(24):
   var value = lerpf(float(expected[left][i]), float(expected[right][i]), mix_value)
   var error = absf(cape.get_blend_shape_value(i) - value)
   worst = maxf(worst, error)
   displacement_bound += error * float(bounds[i])
  worst_bound = maxf(worst_bound, displacement_bound)
 print("CAPE_WEIGHT_CHECK samples=69 shapes=24 maximum_weight_error=", worst, " conservative_vertex_displacement_bound_m=", worst_bound)
 quit(3 if worst > 0.001 or worst_bound > 0.0001 else 0)
