extends Node3D

func find_player(node: Node) -> AnimationPlayer:
 if node is AnimationPlayer:
  return node
 for child in node.get_children():
  var found = find_player(child)
  if found:
   return found
 return null

func _ready() -> void:
 var look = preload("res://src/world/frostbridge_look.gd")
 var settings = look.build_environment(self)
 var warm = OmniLight3D.new()
 warm.position = Vector3(-2, 2.4, -1.5)
 warm.light_color = look.LAMP
 warm.light_energy = 2.0
 warm.omni_range = 6.0
 warm.shadow_enabled = true
 add_child(warm)
 var ground = MeshInstance3D.new()
 var plane = PlaneMesh.new()
 plane.size = Vector2(24, 24)
 ground.mesh = plane
 ground.material_override = look.new().wet_ground(look.COBBLE, 0.55)
 add_child(ground)
 var character = load("res://noen_walk_preview.glb").instantiate()
 add_child(character)
 var camera = Camera3D.new()
 add_child(camera)
 camera.position = Vector3(2.3, 1.4, -4)
 camera.look_at(Vector3(0, 0.88, 0))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 2.1
 camera.current = true
 var player = find_player(character)
 if not player:
  push_error("No imported animation player")
  get_tree().quit(1)
  return
 var clips = player.get_animation_list()
 print("IMPORTED_CLIPS ", clips)
 var selected = ""
 for clip in clips:
  if clip != "RESET":
   selected = clip
   break
 if selected.is_empty():
  get_tree().quit(2)
  return
 player.play("idle")
 player.pause()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://frames"))
 var title = Label.new()
 title.text = "NOEN FRACTURE GUARD / WORK IN PROGRESS"
 title.position = Vector2(24, 24)
 title.add_theme_font_size_override("font_size", 22)
 add_child(title)
 for i in range(4):
  player.seek(float(i) * 0.8, true)
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  var screenshot = get_viewport().get_texture().get_image()
  var result = screenshot.save_png("res://frames/idle_night_%03d.png" % i)
  print("CAPTURE ", i, " ", result)
 get_tree().quit()
