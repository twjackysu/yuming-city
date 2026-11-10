import os
import os
import bpy,math,re,json,os
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-compact-run')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'))
rig=bpy.data.objects['Noen_Skeleton'];scene=bpy.context.scene
lines=Path(os.environ.get('YUMING_WALK_BVH', str(Path.home()/'Tools'/'accad-mocap'/'Male1_C03_Run.bvh'))).read_text().splitlines();nodes={};stack=[];current=None;channels=0;data_start=0
for i,line in enumerate(lines):
 t=line.strip().split()
 if not t:continue
 if t[0] in ['ROOT','JOINT'] or t[:2]==['End','Site']:
  name=t[1] if t[0]!='End' else stack[-1]+'_End';nodes[name]={'parent':stack[-1] if stack else None,'offset':Vector(),'channels':[],'start':channels};current=name
 elif t[0]=='{':stack.append(current)
 elif t[0]=='}':stack.pop()
 elif t[0]=='OFFSET':nodes[current]['offset']=Vector(map(float,t[1:]))
 elif t[0]=='CHANNELS':nodes[current]['channels']=t[2:];nodes[current]['start']=channels;channels+=int(t[1])
 elif t[0]=='Frames:':count=int(t[1])
 elif t[:2]==['Frame','Time:']:dt=float(t[2]);data_start=i+1;break
frames=[list(map(float,l.split())) for l in lines[data_start:] if l.strip()]
conversion=Matrix.Rotation(math.pi/2,4,'X')
def sample(index):
 transforms={}
 for name,node in nodes.items():
  m=Matrix.Translation(node['offset']);vals=frames[index]
  for j,ch in enumerate(node['channels']):
   value=vals[node['start']+j]
   if ch.endswith('position'):
    vec=Vector();vec['XYZ'.index(ch[0])]=value;m=m@Matrix.Translation(vec)
   else:m=m@Matrix.Rotation(math.radians(value),4,ch[0])
  if node['parent']:m=transforms[node['parent']]@m
  transforms[name]=m
 return {name:(conversion@m).translation for name,m in transforms.items()}
a=sample(0);b=sample(min(len(frames)-1,120));velocity=b['Hips']-a['Hips'];angle=-math.pi/2-math.atan2(velocity.y,velocity.x);heading=Matrix.Rotation(angle,3,'Z')
mapping={'Spine':('ToSpine','Spine'),'Spine1':('Spine','Spine1'),'Spine2':('Spine1','Neck'),'Neck':('Neck','Head'),'Head':('Head','Head_End')}
for side in ['Left','Right']:
 for name,child in [('Shoulder','Arm'),('Arm','ForeArm'),('ForeArm','Hand'),('Hand','Hand_End'),('UpLeg','Leg'),('Leg','Foot'),('Foot','ToeBase')]:
  if side+child in nodes:mapping[side+name]=(side+name,side+child)

def minimum_boot_height():
 graph=bpy.context.evaluated_depsgraph_get();boots=[o.evaluated_get(graph) for o in scene.objects if o.type=='MESH' and o.name.startswith('Noen_Boot')]
 return min((boot.matrix_world@v.co).z for boot in boots for v in boot.data.vertices)

cycle=json.loads((root/'source_cycle.json').read_text());leg_scale=(rig.data.bones['mixamorig:LeftUpLeg'].length+rig.data.bones['mixamorig:LeftLeg'].length)/((nodes['LeftLeg']['offset'].length+nodes['LeftFoot']['offset'].length)*.01);desired=[0 if v*leg_scale<.015 else v*leg_scale for v in cycle['expected_minimum_boot_height_m']]
rig.animation_data_clear();scene.render.fps=30;scene.frame_start=1;scene.frame_end=cycle['output_frames'];resthip=rig.data.bones['mixamorig:Hips'].head_local.copy()
for f in range(1,scene.frame_end+1):
 scene.frame_set(f)
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 pos={name:heading@v for name,v in sample(min(len(frames)-1,cycle['source_start']+f-1)).items()}
 hips=rig.pose.bones['mixamorig:Hips'];hm=hips.matrix.copy();hm.translation=resthip+Vector((0,0,(pos['Hips'].z-a['Hips'].z)*.01));hips.matrix=hm
 bpy.context.view_layer.update()
 for name,(start,end) in mapping.items():
  bone=rig.pose.bones['mixamorig:'+name];direction=pos[end]-pos[start];rest=rig.data.bones[bone.name];q=(rest.tail_local-rest.head_local).rotation_difference(direction);target=q@rest.matrix_local.to_quaternion();m=target.to_matrix().to_4x4();m.translation=bone.head;bone.matrix=m;bpy.context.view_layer.update()

 # Guard the fractured right forearm near the abdomen instead of normal arm swing.
 upper=rig.pose.bones['mixamorig:RightArm'];forearm=rig.pose.bones['mixamorig:RightForeArm'];hand=rig.pose.bones['mixamorig:RightHand'];anchor=upper.head.copy();phase=(f-1)/(scene.frame_end-1)*math.tau;goal=anchor+Vector((.10,-.26+.004*math.sin(phase),-.28));axis=(goal-anchor).normalized();distance=(goal-anchor).length;l1=upper.bone.length;l2=forearm.bone.length;along=(l1*l1-l2*l2+distance*distance)/(2*distance);height=math.sqrt(max(0,l1*l1-along*along));pole=Vector((-.3,0,-.2));perpendicular=(pole-axis*pole.dot(axis)).normalized();elbow=anchor+axis*along+perpendicular*height
 for bone,direction in [(upper,elbow-anchor),(forearm,goal-elbow)]:
  rest=bone.bone;q=(rest.tail_local-rest.head_local).rotation_difference(direction)@rest.matrix_local.to_quaternion();matrix=q.to_matrix().to_4x4();matrix.translation=bone.head;bone.matrix=matrix;bpy.context.view_layer.update()
 middle=rig.data.bones['mixamorig:RightHandMiddle1'];tip=rig.data.bones['mixamorig:RightHandMiddle3'];index=rig.data.bones['mixamorig:RightHandIndex1'];pinky=rig.data.bones['mixamorig:RightHandPinky1'];fy=(tip.tail_local-middle.head_local).normalized();tx=index.head_local-pinky.head_local;tx=(tx-fy*tx.dot(fy)).normalized();dz=tx.cross(fy).normalized();restframe=Matrix((tx,fy,dz)).transposed();finger=Vector((.75,0,-.65)).normalized();dorsal=Vector((0,-1,0));thumb=finger.cross(dorsal).normalized();frame=Matrix((thumb,finger,dorsal)).transposed();matrix=(frame@restframe.inverted()@hand.bone.matrix_local.to_3x3()).to_4x4();matrix.translation=hand.head;hand.matrix=matrix;bpy.context.view_layer.update()
 from mathutils import Quaternion
 for finger in ['Index','Middle','Ring','Pinky']:
  for joint,angle in [(1,25),(2,35),(3,15)]:
   name='mixamorig:RightHand'+finger+str(joint);bone=rig.pose.bones[name];rest=bone.bone;curl=(rest.tail_local-rest.head_local).normalized().cross(-dz).normalized();curl=rest.matrix_local.to_3x3().inverted()@curl;bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(curl,math.radians(angle))
 bpy.context.view_layer.update()
 # Keep the left swing compact with a neutral wrist and half-closed hand.
 upper=rig.pose.bones['mixamorig:LeftArm'];forearm=rig.pose.bones['mixamorig:LeftForeArm'];hand=rig.pose.bones['mixamorig:LeftHand'];anchor=upper.head.copy();goal=anchor+Vector((.08,-.10-.12*math.sin(phase),-.25+.03*math.sin(phase)));axis=(goal-anchor).normalized();distance=(goal-anchor).length;l1=upper.bone.length;l2=forearm.bone.length;along=(l1*l1-l2*l2+distance*distance)/(2*distance);height=math.sqrt(max(0,l1*l1-along*along));pole=Vector((.10,.30,-.35));perpendicular=(pole-axis*pole.dot(axis)).normalized();elbow=anchor+axis*along+perpendicular*height
 for bone,direction in [(upper,elbow-anchor),(forearm,goal-elbow)]:
  rest=bone.bone;q=(rest.tail_local-rest.head_local).rotation_difference(direction)@rest.matrix_local.to_quaternion();matrix=q.to_matrix().to_4x4();matrix.translation=bone.head;bone.matrix=matrix;bpy.context.view_layer.update()
 middle=rig.data.bones['mixamorig:LeftHandMiddle1'];tip=rig.data.bones['mixamorig:LeftHandMiddle3'];index=rig.data.bones['mixamorig:LeftHandIndex1'];pinky=rig.data.bones['mixamorig:LeftHandPinky1'];fy=(tip.tail_local-middle.head_local).normalized();tx=index.head_local-pinky.head_local;tx=(tx-fy*tx.dot(fy)).normalized();dz=tx.cross(fy).normalized();restframe=Matrix((tx,fy,dz)).transposed();direction=(goal-elbow).normalized();finger=Vector((0,direction.y,direction.z)).normalized();dorsal=Vector((1,0,0));thumb=finger.cross(dorsal).normalized();frame=Matrix((thumb,finger,dorsal)).transposed();matrix=(frame@restframe.inverted()@hand.bone.matrix_local.to_3x3()).to_4x4();matrix.translation=hand.head;hand.matrix=matrix;bpy.context.view_layer.update()
 for finger in ['Index','Middle','Ring','Pinky']:
  for joint,angle in [(1,20),(2,40),(3,20)]:
   bone=rig.pose.bones['mixamorig:LeftHand'+finger+str(joint)];rest=bone.bone;curl=(rest.tail_local-rest.head_local).normalized().cross(-dz).normalized();curl=rest.matrix_local.to_3x3().inverted()@curl;bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(curl,math.radians(angle))
   if joint==1:
    d=(rest.tail_local-rest.head_local).normalized();qrest=rest.matrix_local.to_quaternion();adduct=d.rotation_difference(d.lerp(fy,.75).normalized());bone.rotation_quaternion=(qrest.inverted()@adduct@qrest)@bone.rotation_quaternion
 bpy.context.view_layer.update()
 for side,letter in [('Left','L'),('Right','R')]:
  thigh=rig.pose.bones['mixamorig:'+side+'UpLeg'];direction=thigh.tail-thigh.head;angle=math.atan2(direction.y,-direction.z)
  for panel in ['Front','Back']:
   upper=rig.pose.bones['Coat_'+panel+'_'+letter+'_Upper'];rest=rig.data.bones[upper.name]
   turn=angle*1.15+(-.10 if panel=='Front' else .10);m=Matrix.Rotation(turn,4,'X')@rest.matrix_local;m.translation=upper.head;upper.matrix=m;bpy.context.view_layer.update()
 lowest=minimum_boot_height();hm=hips.matrix.copy();hm.translation.z+=desired[f-1]-lowest;hips.matrix=hm;bpy.context.view_layer.update()
 for bone in rig.pose.bones:
  bone.rotation_mode='QUATERNION';bone.keyframe_insert('rotation_quaternion',frame=f)
 hips.keyframe_insert('location',frame=f)

# Correct the small captured cycle drift over the whole cycle, preserving timing.
scene.frame_set(1);startq={b.name:b.rotation_quaternion.copy() for b in rig.pose.bones};startloc=hips.location.copy()
scene.frame_set(scene.frame_end);endq={b.name:b.rotation_quaternion.copy() for b in rig.pose.bones};endloc=hips.location.copy()
from mathutils import Quaternion
for frame in range(1,scene.frame_end+1):
 scene.frame_set(frame);t=(frame-1)/(scene.frame_end-1);blend=t*t*(3-2*t)
 for bone in rig.pose.bones:
  correction=endq[bone.name].rotation_difference(startq[bone.name]);bone.rotation_quaternion=bone.rotation_quaternion@Quaternion().slerp(correction,blend);bone.keyframe_insert('rotation_quaternion',frame=frame)
 hips.location+=(startloc-endloc)*blend;hips.keyframe_insert('location',frame=frame)
for frame in range(1,scene.frame_end+1):
 scene.frame_set(frame);bpy.context.view_layer.update();lowest=minimum_boot_height();hm=hips.matrix.copy();hm.translation.z+=desired[frame-1]-lowest;hips.matrix=hm;hips.keyframe_insert('location',frame=frame)
# Start at a calibrated contact and retain a continuous, closed corrected cycle.
states=[]
for frame in range(1,scene.frame_end):
 scene.frame_set(frame);states.append({bone.name:(bone.rotation_quaternion.copy(),bone.location.copy()) for bone in rig.pose.bones})
phase=cycle['contact_phase_index'];rotated=[]
for frame in range(1,scene.frame_end+1):
 index=((frame-1)+phase)%len(states);scene.frame_set(frame)
 for bone in rig.pose.bones:
  bone.rotation_quaternion, bone.location=states[index][bone.name];bone.keyframe_insert('rotation_quaternion',frame=frame);bone.keyframe_insert('location',frame=frame)
 rotated.append(desired[index])
cycle['contact_snap_m']=.015;cycle['retarget_leg_scale']=leg_scale;cycle['retarget_boot_height_m']=rotated;cycle['reference_speed_mps']=cycle['source_root_distance_m']*leg_scale/((scene.frame_end-1)/30);(root/'retarget_cycle.json').write_text(json.dumps(cycle,indent=2))
scene.frame_set(10);cam=scene.camera;cam.data.ortho_scale=2.05;cam.location=(0,-4,1);cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/'mocap_run_trial.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'mocap_run_trial.blend'))
print('MOCAP_FRAMES',scene.frame_end,'SOURCE',len(frames),dt)
