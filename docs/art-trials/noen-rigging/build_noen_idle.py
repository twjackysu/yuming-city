import os
"""Author a closed 3.2-second breathing idle retaining the fracture guard pose."""
import bpy,math,json,os,shutil
from pathlib import Path
from mathutils import Matrix,Quaternion
home=Path.home();root=Path(os.environ.get('YUMING_NOEN_IDLE_WORK',str(home/'Documents/noen-idle')));root.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(home/'Documents/noen-surface-refinement/mocap_walk_trial.blend'));scene=bpy.context.scene;scene.frame_set(18);source=bpy.data.objects['Noen_Skeleton'];basis={b.name:b.matrix_basis.copy() for b in source.pose.bones}
bpy.ops.wm.open_mainfile(filepath=str(home/'Documents/noen-three-materials/tailored_noen.blend'));rig=bpy.data.objects['Noen_Skeleton'];scene=bpy.context.scene;rig.animation_data_clear();scene.render.fps=30;scene.frame_start=1;scene.frame_end=97
rest={}
for bone in rig.pose.bones:
 lower=any(s in bone.name for s in ['UpLeg','Leg','Foot','ToeBase']) or bone.name.startswith('Coat_') or bone.name=='mixamorig:Hips'
 bone.matrix_basis=Matrix.Identity(4) if lower else basis[bone.name];bone.rotation_mode='QUATERNION';rest[bone.name]=bone.matrix_basis.copy()
boots=[o for o in scene.objects if o.type=='MESH' and 'Clothes' in o.name]
# Geometry is merged into one clothing atlas mesh; identify boot vertices by bind height.
cloth=boots[0];boot_indices=[v.index for v in cloth.data.vertices if (cloth.matrix_world@v.co).z<.15];assert len(boot_indices)>50
reports=[]
for frame in range(1,98):
 scene.frame_set(frame);phase=(frame-1)/96*math.tau
 for bone in rig.pose.bones:bone.matrix_basis=rest[bone.name]
 for name,angle in [('Spine1',.25*math.sin(phase)),('Spine2',-.12*math.sin(phase)),('Head',.4*math.sin(phase))]:
  bone=rig.pose.bones['mixamorig:'+name];bone.rotation_quaternion=bone.rotation_quaternion@Quaternion((1,0,0),math.radians(angle))
 bpy.context.view_layer.update();ev=cloth.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[ev.matrix_world@ev.data.vertices[i].co for i in boot_indices];minimum=min(p.z for p in points);hips=rig.pose.bones['mixamorig:Hips'];hips.location.z-=minimum;bpy.context.view_layer.update()
 for bone in rig.pose.bones:
  bone.keyframe_insert('rotation_quaternion',frame=frame);bone.keyframe_insert('location',frame=frame);bone.keyframe_insert('scale',frame=frame)
 reports.append({'frame':frame,'boot_correction_m':minimum})
rig.animation_data.action.name='idle_loop';bpy.ops.wm.save_as_mainfile(filepath=str(root/'idle_source.blend'))
# An unexported identity pose supplies the FBX bind rest.
scene.frame_set(0)
for bone in rig.pose.bones:
 bone.matrix_basis=Matrix.Identity(4);bone.keyframe_insert('rotation_quaternion',frame=0);bone.keyframe_insert('location',frame=0);bone.keyframe_insert('scale',frame=0)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;rig.rotation_euler.z=math.pi;bpy.ops.export_scene.fbx(filepath=str(root/'idle_trial.fbx'),use_selection=True,object_types={'ARMATURE'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,axis_forward='-Z',axis_up='Y');shutil.copy2(root/'idle_trial.fbx',root/'walk_trial.fbx');shutil.copy2(home/'Documents/noen-three-materials/tailored_candidate.glb',root/'tailored_candidate.glb');(root/'idle_build.json').write_text(json.dumps({'frames':97,'fps':30,'duration_s':3.2,'motions':'standing rest legs, breathing torso, guarded right forearm, relaxed left hand','status':'requires_roundtrip_and_engine_review','ground_adjustments':reports},indent=2))
