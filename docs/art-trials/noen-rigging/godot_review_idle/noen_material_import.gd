@tool
extends EditorScenePostImport
## Asset-specific bridge for Godot 4.7.2: the tested glTF import did not apply
## KHR_materials_specular.specularFactor=0.12 (Blender Specular IOR Level=0.06).
## Set this as the GLB's Import Script. Leaves all other material fields intact.
func _post_import(scene: Node) -> Object:
 _visit(scene)
 return scene
func _visit(node: Node) -> void:
 if node is MeshInstance3D:
  for surface in range(node.mesh.get_surface_count()):
   var material = node.mesh.surface_get_material(surface)
   if material is BaseMaterial3D and material.resource_name == "M_Noen_Hair":
    material.metallic_specular = 0.06
 for child in node.get_children(): _visit(child)
