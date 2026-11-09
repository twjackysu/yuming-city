import os
import bpy,json,math
from pathlib import Path
root=Path(os.environ.get('YUMING_NOEN_WORK',str(Path.home()/'Documents/noen-guarded-walk')));bpy.ops.wm.open_mainfile(filepath=str(root/'animated_roundtrip/walk_review.blend'));scene=bpy.context.scene;wood=next(o for o in scene.objects if o.type=='MESH' and 'Wood_Splint' in o.name);rig=next(m.object for m in wood.modifiers if m.type=='ARMATURE');edges=[]
for edge in wood.data.edges:
 a,b=edge.vertices;length=((wood.matrix_world@wood.data.vertices[a].co)-(wood.matrix_world@wood.data.vertices[b].co)).length
 if length>.015:edges.append((a,b,length))
maximum=0;drops=[]
for frame in range(2,37):
 scene.frame_set(frame);evaluated=wood.evaluated_get(bpy.context.evaluated_depsgraph_get());positions=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
 maximum=max(maximum,max(abs((positions[a]-positions[b]).length/length-1) for a,b,length in edges));shoulder=rig.matrix_world@rig.pose.bones['mixamorig:RightArm'].head;hand=rig.matrix_world@rig.pose.bones['mixamorig:RightHand'].head;drops.append(shoulder.z-hand.z)
scene.frame_set(2);first={b.name:b.matrix.copy() for b in rig.pose.bones};scene.frame_set(36);loop=max(abs(b.matrix[i][j]-first[b.name][i][j]) for b in rig.pose.bones for i in range(4) for j in range(4));report={'frames':35,'splint_edges_checked':len(edges),'maximum_splint_relative_edge_change':maximum,'shoulder_to_wrist_vertical_drop_min_m':min(drops),'shoulder_to_wrist_vertical_drop_max_m':max(drops),'loop_max_matrix_error':loop};report['passed']=maximum<.0001 and .20<min(drops) and max(drops)<.38 and loop<.0001;(root/'guarded_pose_check.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));assert report['passed']
