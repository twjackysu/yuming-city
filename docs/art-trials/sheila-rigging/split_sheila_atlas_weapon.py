import os
import bpy,bmesh,math,json,shutil
from pathlib import Path
home=Path.home();root=Path(os.environ.get('YUMING_SHEILA_ATLAS_WORK',str(home/'Documents/sheila-sword-delivery')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'));scene=bpy.context.scene;obj=bpy.data.objects['Sheila_Clothes'];existing=bpy.data.objects.get('Sheila_Broken_Sword')
if existing:
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);existing.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
group=obj.vertex_groups['weapon_socket'];spine=obj.vertex_groups['mixamorig:Spine2'];fixed=0
for vertex in obj.data.vertices:
 if vertex.co.y<0 and any(g.group==group.index and g.weight>.999 for g in vertex.groups):
  group.remove([vertex.index]);spine.add([vertex.index],1,'REPLACE');fixed+=1
print('RESTORED_CHEST_BADGE_TO_SPINE',fixed)
indices={v.index for v in obj.data.vertices if any(g.group==group.index and g.weight>.999 for g in v.groups)};assert len(indices)>100;before=set(scene.objects);bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;scene.tool_settings.mesh_select_mode=(True,False,False);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
for vertex in obj.data.vertices:vertex.select=vertex.index in indices
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT');new=list(set(scene.objects)-before);assert len(new)==1;new[0].name='Sheila_Broken_Sword';rig=bpy.data.objects['Sheila_Skeleton'];bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in scene.objects:
 if obj.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in obj.modifiers):obj.select_set(True)
rig.rotation_euler.z=math.pi;bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_extras=True);rig.rotation_euler.z=0;bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'));shutil.copy2(home/'Documents/sheila-motion/walk_trial.fbx',root/'walk_trial.fbx');print('KEPT_SEPARATE_WEAPON',len(indices),'source vertices')

