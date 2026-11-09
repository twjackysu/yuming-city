extends Node3D

func find_player(node: Node) -> AnimationPlayer:
 if node is AnimationPlayer:
  return node
 for child in node.get_children():
  var found = find_player(child)
  if found:
   return found
 return null

func enable_weakpoints(node: Node) -> int:
 var slots = 0
 if node is MeshInstance3D:
  for surface in range(node.mesh.get_surface_count()):
   var material = node.mesh.surface_get_material(surface)
   if material and material.resource_name == "M_FrameJoint":
    var glowing = material.duplicate()
    glowing.emission_enabled = true
    glowing.emission = Color(0.1, 0.65, 1.0)
    glowing.emission_energy_multiplier = 4.0
    node.set_surface_override_material(surface, glowing)
    slots += 1
 for child in node.get_children(): slots += enable_weakpoints(child)
 return slots

func _ready() -> void:
 var environment = WorldEnvironment.new()
 var settings = Environment.new()
 settings.background_mode = Environment.BG_COLOR
 settings.background_color = Color(0.055, 0.065, 0.08)
 settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color = Color(0.67, 0.74, 0.84)
 settings.ambient_light_energy = 0.3
 settings.ssao_enabled = true
 settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.environment = settings
 add_child(environment)
 var key = DirectionalLight3D.new()
 key.rotation_degrees = Vector3(-40, -35, 0)
 key.light_energy = 1.2
 key.shadow_enabled = true
 key.shadow_bias = 0.02
 key.shadow_normal_bias = 0.1
 key.directional_shadow_max_distance = 10.0
 add_child(key)
 var fill = DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-25, 140, 0)
 fill.light_color = Color(0.7, 0.78, 1.0)
 fill.light_energy = 0.65
 add_child(fill)
 var ground = MeshInstance3D.new()
 var plane = PlaneMesh.new()
 plane.size = Vector2(12, 12)
 ground.mesh = plane
 var material = StandardMaterial3D.new()
 material.albedo_color = Color(0.08, 0.095, 0.11)
 material.roughness = 0.9
 ground.material_override = material
 add_child(ground)
 var character = load("res://undertaker_walk_preview.glb").instantiate()
 add_child(character)
 var weakpoint_slots = enable_weakpoints(character)
 print("INDEPENDENT_WEAKPOINT_SLOTS ", weakpoint_slots)
 if weakpoint_slots != 1:
  get_tree().quit(4)
  return
 var camera = Camera3D.new()
 add_child(camera)
 camera.position = Vector3(3.1, 1.9, 5)
 camera.look_at(Vector3(0, 1.3, 0))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 3.2
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
 player.play(selected)
 player.pause()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://frames"))
 var title = Label.new()
 title.text = "UNDERTAKER / WORK IN PROGRESS"
 title.position = Vector2(24, 24)
 title.add_theme_font_size_override("font_size", 22)
 add_child(title)
 for i in range(1):
  player.seek(float(i) / 30.0, true)
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  var screenshot = get_viewport().get_texture().get_image()
  var result = screenshot.save_png("res://frames/weakpoint_%03d.png" % i)
  print("CAPTURE ", i, " ", result)
 get_tree().quit()
