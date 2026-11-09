import os
import bpy,json,os,math
from pathlib import Path
root=Path(os.environ.get('YUMING_NOEN_WORK',str(Path.home()/'Documents/noen-guarded-walk')))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(root/'walk_trial.fbx'));rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');scene=bpy.context.scene
start,end=map(round,rig.animation_data.action.frame_range);scene.frame_set(start);first={b.name:b.matrix.copy() for b in rig.pose.bones};scene.frame_set(end);difference=max(abs(b.matrix[i][j]-first[b.name][i][j]) for b in rig.pose.bones for i in range(4) for j in range(4));meshes=sum(o.type=='MESH' for o in scene.objects)
report={'bones':len(rig.data.bones),'meshes':meshes,'fps':scene.render.fps,'frame_start':start,'frame_end':end,'loop_max_matrix_error':difference,'without_skin':meshes==0,'in_place':True}
hips=[]
for frame in range(start,end+1):
 scene.frame_set(frame);p=rig.matrix_world@rig.pose.bones['mixamorig:Hips'].head;hips.append(p.copy())
# FBX source is Y-up, Blender importer restores Z-up.
report['horizontal_hip_range_m']=max(max(p[i] for p in hips)-min(p[i] for p in hips) for i in [0,1])
report['passed']=meshes==0 and scene.render.fps==30 and difference<.0001 and report['horizontal_hip_range_m']<.001
(root/'walk_fbx_roundtrip.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));assert report['passed']
