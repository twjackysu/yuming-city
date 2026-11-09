import os
import bpy,math
from pathlib import Path
from mathutils import Matrix,Vector
root=Path(os.environ.get('SHEILA_PRODUCTION', str(Path.home()/'Documents'/'sheila-production')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_baked.blend'));rig=bpy.data.objects['Sheila_Skeleton']
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT');bone=rig.data.edit_bones.new('weapon_socket');bone.head=(0,.285,1.565);bone.tail=(0,.285,1.67);bone.parent=rig.data.edit_bones['mixamorig:Spine2'];bpy.ops.object.mode_set(mode='OBJECT')
for obj in bpy.context.scene.objects:
 if obj.type=='MESH' and ('Sword' in obj.name):
  obj.vertex_groups.clear();group=obj.vertex_groups.new(name='weapon_socket');group.add(list(range(len(obj.data.vertices))),1.,'REPLACE')
rig['weapon_socket']='weapon_socket';rig['equip_hand']='mixamorig:RightHand';rig['weapon_grip_local_axis']='blade points along negative local Y; adjust hand socket rotation for each animation'
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)];bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
rig.rotation_euler.z=math.pi;bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_extras=True);rig.rotation_euler.z=0;bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_baked.blend'))
# Diagnostic equip pose; the saved/exported candidate above keeps its back-mounted rest pose.
rig.pose.bones['weapon_socket'].matrix=rig.pose.bones['mixamorig:RightHand'].matrix@Matrix.Rotation(math.pi/2,4,'X');bpy.context.view_layer.update();scene=bpy.context.scene;cam=scene.camera;cam.location=(2.6,-4,1.4);cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.1;scene.render.filepath=str(root/'right_hand_socket_review.png');bpy.ops.render.render(write_still=True)
