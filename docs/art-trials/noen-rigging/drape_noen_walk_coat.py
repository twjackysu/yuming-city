import bpy,math,json,os
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
h=Path.home();out=Path(os.environ.get('YUMING_NOEN_WORK',str(h/'Documents/noen-coat-drape')));out.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=os.environ.get('YUMING_NOEN_WALK_BLEND',str(h/'Documents/noen-surface-refinement/mocap_walk_trial.blend')));s=bpy.context.scene;r=bpy.data.objects['Noen_Skeleton']
print('MESHES',[(o.name,len(o.data.vertices)) for o in s.objects if o.type=='MESH'])
for f in range(s.frame_start,s.frame_end+1):
 s.frame_set(f)
 for b in r.pose.bones:
  if not b.name.startswith('Coat_') or not b.name.endswith('Lower'):continue
  up=b.parent;angle=math.atan2((up.tail-up.head).y,-(up.tail-up.head).z);pitch=max(-.24,min(.24,angle*.35));rest=b.bone;d=rest.tail_local-rest.head_local;length=math.hypot(d.y,d.z);target=Vector((d.x,math.sin(pitch)*length,-math.cos(pitch)*length));q=d.rotation_difference(target)@rest.matrix_local.to_quaternion();m=q.to_matrix().to_4x4();m.translation=b.head;b.matrix=m;b.rotation_mode='QUATERNION';b.keyframe_insert('rotation_quaternion',frame=f);bpy.context.view_layer.update()
s.frame_set(9);s.render.engine='CYCLES';s.cycles.samples=16;s.render.resolution_x=800;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.filepath=str(out/'coat_drape.png');bpy.ops.render.render(write_still=True);bpy.ops.wm.save_as_mainfile(filepath=str(out/'mocap_walk_trial.blend'))
