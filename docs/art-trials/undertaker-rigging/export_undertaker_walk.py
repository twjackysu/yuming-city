import os
import os
import bpy,math
from pathlib import Path
from mathutils import Matrix
root=Path(os.environ.get('UNDERTAKER_WORK', str(Path.home()/'Documents'/'undertaker-motion')));bpy.ops.wm.open_mainfile(filepath=str(root/'mocap_walk_trial.blend'));rig=bpy.data.objects['Undertaker_Skeleton'];scene=bpy.context.scene
scene.frame_set(0)
for b in rig.pose.bones:
 b.matrix_basis=Matrix.Identity(4);b.keyframe_insert('rotation_quaternion',frame=0);b.keyframe_insert('location',frame=0)
scene.frame_start=1;scene.frame_end=59;rig.rotation_euler.z=math.pi;bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.fbx(filepath=str(root/'walk_trial.fbx'),use_selection=True,object_types={'ARMATURE'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,axis_forward='-Z',axis_up='Y')
