import os
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
sys.path.insert(0,str(Path(__file__).resolve().parent));from acclaim_motion import AcclaimMotion
source=Path(os.environ.get('CMU_MOCAP', str(Path.home()/'Tools\\cmu-mocap')));motion=AcclaimMotion(source/'02.asf',source/'02_07.amc');root=Path(os.environ.get('CMU_SWORD_WORK', str(Path.home()/'Documents\\cmu-sword-study')));root.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.environ.get('SHEILA_SWORD_MODEL', str(Path.home()/'Documents\\sheila-production\\tailored_baked.blend')));rig=bpy.data.objects['Sheila_Skeleton'];scene=bpy.context.scene;cam=scene.camera;cam.data.ortho_scale=3.0;scene.render.resolution_x=800;scene.render.resolution_y=800;scene.cycles.samples=16
conversion=Matrix.Rotation(math.pi/2,3,'X');mapping={'Spine':'lowerback','Spine1':'upperback','Spine2':'thorax','Neck':'upperneck','Head':'head'}
for side,prefix in [('Left','l'),('Right','r')]:
 for target,bone in [('Shoulder','clavicle'),('Arm','humerus'),('ForeArm','wrist'),('Hand','hand'),('UpLeg','femur'),('Leg','tibia'),('Foot','foot'),('ToeBase','toes')]:mapping[side+target]=prefix+bone
rest={bone.name:bone.matrix_local.copy() for bone in rig.data.bones};virtual={}
for target,bone in mapping.items():
 name='mixamorig:'+target
 if name not in rest:continue
 data=rig.data.bones[name];virtual[name]=(data.tail_local-data.head_local).rotation_difference(conversion@motion.bones[bone]['direction'])@rest[name].to_quaternion()
def palm_frame(finger,thumb):
 y=finger.normalized();x=(thumb-y*y.dot(thumb)).normalized();z=x.cross(y).normalized();x=y.cross(z).normalized();return Matrix((x,y,z)).transposed()
hand_frames={}
for side in ['Left','Right']:
 middle=rig.data.bones['mixamorig:'+side+'HandMiddle1'];tip=rig.data.bones['mixamorig:'+side+'HandMiddle3'];index=rig.data.bones['mixamorig:'+side+'HandIndex1'];pinky=rig.data.bones['mixamorig:'+side+'HandPinky1'];hand_frames[side]=palm_frame(tip.tail_local-middle.head_local,index.head_local-pinky.head_local)
# Solve a single closed grip in the authored rest geometry, independent of bone roll.
from itertools import product
frame=hand_frames['Right'];curl_normal=-frame.col[2];finger_y=frame.col[1];grip_axis=frame.col[0];knuckles=sum((rig.data.bones['mixamorig:RightHand'+f+'1'].head_local for f in ['Index','Middle','Ring','Pinky']),Vector())/4;grip_center=knuckles-finger_y*.025+curl_normal*.008;grip_angles={};grip_axes={}
for finger in ['Index','Middle','Ring','Pinky']:
 names=['mixamorig:RightHand'+finger+str(j) for j in [1,2,3]];axes=[]
 for name in names:
  data=rig.data.bones[name];axis=(data.tail_local-data.head_local).normalized().cross(curl_normal).normalized();axes.append(rest[name].to_3x3().inverted()@axis)
 grip_axes[finger]=axes;best=None
 for angles in product(range(70,116,5),range(45,111,5),range(10,76,5)):
  parent=rest['mixamorig:RightHand'];parent_rest=parent;points=[]
  for name,axis,angle in zip(names,axes,angles):
   matrix=parent@parent_rest.inverted()@rest[name]@Quaternion(axis,math.radians(angle)).to_matrix().to_4x4();points.append(matrix@Vector((0,rig.data.bones[name].length,0)));parent=matrix;parent_rest=rest[name]
  delta=points[-1]-grip_center;radial=delta-grip_axis*delta.dot(grip_axis);score=abs(radial.length-.027)*100+max(0.,delta.dot(finger_y)+.004)*10+max(0.,.006-delta.dot(curl_normal))*20
  for point in points[:-1]:
   delta=point-grip_center;distance=(delta-grip_axis*delta.dot(grip_axis)).length;score+=max(0.,.024-distance)*100
  score+=sum(a*a for a in angles)*.0000002
  if best is None or score<best[0]:best=(score,angles)
 grip_angles[finger]=best[1]
print('GRIP_ANGLES',grip_angles)
first_y=motion.frames[0]['root'][1]
def pose(index):
 start,end,rotation=motion.pose(index);heading=Matrix.Rotation(-math.radians(motion.frames[index]['root'][4]),3,'Z')
 for bone in rig.pose.bones:bone.rotation_mode='QUATERNION';bone.matrix_basis=Matrix.Identity(4)
 hips=rig.pose.bones['mixamorig:Hips'];matrix=(heading@conversion@rotation['root']@conversion.inverted()).to_quaternion().to_matrix().to_4x4()@rest[hips.name];matrix.translation=rest[hips.name].translation+Vector((0,0,(motion.frames[index]['root'][1]-first_y)*motion.metres_per_unit));hips.matrix=matrix;bpy.context.view_layer.update()
 for target,bone in mapping.items():
  name='mixamorig:'+target
  if name not in virtual:continue
  target_bone=rig.pose.bones[name];q=(heading@conversion@rotation[bone]@conversion.inverted()).to_quaternion()@virtual[name];matrix=q.to_matrix().to_4x4();matrix.translation=target_bone.head;target_bone.matrix=matrix;bpy.context.view_layer.update()
 for side,prefix in [('Left','l'),('Right','r')]:
  finger=heading@conversion@(end[prefix+'fingers']-end[prefix+'hand']);thumb=heading@conversion@(end[prefix+'thumb']-end[prefix+'hand']);frame=palm_frame(finger,thumb);hand=rig.pose.bones['mixamorig:'+side+'Hand'];matrix=(frame@hand_frames[side].inverted()@rest[hand.name].to_3x3()).to_4x4();matrix.translation=hand.head;hand.matrix=matrix;bpy.context.view_layer.update()
 rest_frame=hand_frames['Right'];palm_normal=-rest_frame.col[2]
 for finger,angles in grip_angles.items():
  for joint,angle,axis in zip([1,2,3],angles,grip_axes[finger]):rig.pose.bones['mixamorig:RightHand'+finger+str(joint)].rotation_quaternion=Quaternion(axis,math.radians(angle))
 for joint,angle in [(1,25),(2,35),(3,25)]:
  name='mixamorig:RightHandThumb'+str(joint);data=rig.data.bones[name];axis=(data.tail_local-data.head_local).normalized().cross(palm_normal).normalized();axis=rest[name].to_3x3().inverted()@axis;rig.pose.bones[name].rotation_quaternion=Quaternion(axis,math.radians(angle))
 bpy.context.view_layer.update();weapon=rig.pose.bones.get('weapon_socket')
 if weapon:
  hand=rig.pose.bones['mixamorig:RightHand'];transform=hand.matrix.to_3x3()@rest[hand.name].to_3x3().inverted();thumb_axis=(transform@rest_frame.col[0]).normalized();normal=(transform@rest_frame.col[2]).normalized();y=-thumb_axis;z=(normal-y*y.dot(normal)).normalized();x=y.cross(z).normalized();matrix=Matrix((x,y,z)).transposed().to_4x4();knuckles=sum((rig.data.bones['mixamorig:RightHand'+f+'1'].head_local for f in ['Index','Middle','Ring','Pinky']),Vector())/4;palm_center=knuckles-rest_frame.col[1]*.025+palm_normal*.008;matrix.translation=hand.matrix@(rest[hand.name].inverted()@palm_center);weapon.matrix=matrix
 bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get();boots=[o.evaluated_get(graph) for o in scene.objects if o.type=='MESH' and o.name.startswith('Sheila_Boot')];lowest=min((o.matrix_world@v.co).z for o in boots for v in o.data.vertices);matrix=hips.matrix.copy();matrix.translation.z-=lowest/rig.matrix_world.to_scale().z;hips.matrix=matrix;bpy.context.view_layer.update()
for frame in [1465]:
 pose(frame-1);cam.location=(2.6,-4,1.6);cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/('pose_%04d.png'%frame));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'sword_pose_review.blend'))

hand=rig.matrix_world@rig.pose.bones['mixamorig:RightHand'].head;cam.location=hand+Vector((1.8,-3,1));cam.rotation_euler=(hand-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.6;scene.render.filepath=str(root/'grip_review.png');bpy.ops.render.render(write_still=True)
