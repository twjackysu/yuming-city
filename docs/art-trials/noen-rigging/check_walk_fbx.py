import os
import bpy,json
from pathlib import Path
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')));bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/'walk_trial.fbx'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');action=rig.animation_data.action;first,last=map(int,action.frame_range)
bpy.context.scene.frame_set(first);start={b.name:b.matrix.copy() for b in rig.pose.bones};bpy.context.scene.frame_set(last)
errors={name:max(abs(start[name][i][j]-rig.pose.bones[name].matrix[i][j]) for i in range(4) for j in range(4)) for name in start}
report={'fps':bpy.context.scene.render.fps,'frames':[first,last],'bones':len(rig.data.bones),'mesh_count':sum(o.type=='MESH' for o in bpy.context.scene.objects),'maximum_loop_matrix_error':max(errors.values()),'largest_errors':sorted(errors.items(),key=lambda x:-x[1])[:5],'status':'structural_trial_only_visual_and_gameplay_checks_pending'}
(root/'walk_fbx_roundtrip.json').write_text(json.dumps(report,indent=2));print(report)
