import os
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')));bootfile=Path(os.environ.get('YUMING_BOOT_MODEL', str(Path.home()/'Documents'/'noen-boots'/'seed81'/'game_ready'/'boot_candidate.glb')))
bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_baked.blend'));rig=bpy.data.objects['Noen_Skeleton'];bpy.data.objects.remove(bpy.data.objects['Noen_Boots'],do_unlink=True)

from io_scene_gltf2.blender.com.material_helpers import create_settings_group
old=bpy.data.node_groups.get('glTF Material Output')
if old:
 old.name='Legacy_Occlusion_Only';new=create_settings_group('glTF Material Output')
 for material in bpy.data.materials:
  if not material.use_nodes:continue
  for node in material.node_tree.nodes:
   if node.type=='GROUP' and node.node_tree==old:
    sources=[link.from_socket for link in node.inputs['Occlusion'].links];node.node_tree=new
    for source in sources:material.node_tree.links.new(source,node.inputs['Occlusion'])

bpy.ops.import_scene.gltf(filepath=str(bootfile));left=next(o for o in bpy.context.selected_objects if o.type=='MESH');left.name='Noen_Boot_Left';bpy.context.view_layer.objects.active=left;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
right=left.copy();right.data=left.data.copy();bpy.context.collection.objects.link(right);right.name='Noen_Boot_Right'
for obj,side,sign in [(left,'Left',1),(right,'Right',-1)]:
 foot=rig.data.bones['mixamorig:'+side+'Foot'].head_local;knee=rig.data.bones['mixamorig:'+side+'Leg'].head_local
 for vertex in obj.data.vertices:
  co=vertex.co;co.x*=sign
  if co.z>.14:co.x*=1+min(1.,(co.z-.14)/.12)*.18
  fraction=max(0.,min(1.,(co.z-foot.z)/(knee.z-foot.z)));co.x+=foot.x+(knee.x-foot.x)*fraction;co.y+=foot.y+(knee.y-foot.y)*fraction
 if sign<0:
  bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 if obj.data.has_custom_normals:obj.data.normals_split_custom_set([(0,0,0)]*len(obj.data.loops))
 obj.vertex_groups.clear();fg=obj.vertex_groups.new(name='mixamorig:'+side+'Foot');lg=obj.vertex_groups.new(name='mixamorig:'+side+'Leg')
 for vertex in obj.data.vertices:
  blend=max(0.,min(1.,(vertex.co.z-.10)/.12));fg.add([vertex.index],1-blend,'REPLACE');lg.add([vertex.index],blend,'REPLACE')
 obj.parent=rig;mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig
pants=bpy.data.objects['Noen_Trousers_Shirt']
for vertex in pants.data.vertices:
 if vertex.co.z>=.35:continue
 side='Left' if vertex.co.x>0 else 'Right';foot=rig.data.bones['mixamorig:'+side+'Foot'].head_local;knee=rig.data.bones['mixamorig:'+side+'Leg'].head_local;t=max(0.,min(1.,(vertex.co.z-foot.z)/(knee.z-foot.z)));center=foot.lerp(knee,t);factor=1-.3*max(0.,min(1.,(.35-vertex.co.z)/.06));vertex.co.x=center.x+(vertex.co.x-center.x)*factor;vertex.co.y=center.y+(vertex.co.y-center.y)*factor
scene=bpy.context.scene;cam=scene.camera
for label,loc,look,scale in [('boots_v2_front',(0,-4,1),(0,0,.88),2.05),('boots_v2_back',(0,4,1),(0,0,.88),2.05),('boots_v2_close',(0,-2,.24),(0,0,.17),.65)]:
 cam.location=loc;cam.rotation_euler=(Vector(look)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale;scene.render.filepath=str(root/(label+'.png'));bpy.ops.render.render(write_still=True)
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
rig.rotation_euler.z=math.pi
bpy.ops.export_scene.gltf(filepath=str(root/'noen_boots_v2.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
rig.rotation_euler.z=0;bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_boots_v2.blend'))
print('TRIANGLES',sum(sum(len(f.vertices)-2 for f in obj.data.polygons) for obj in meshes))
