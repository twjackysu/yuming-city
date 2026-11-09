from pathlib import Path
import json,math,os
import numpy as np
h=Path.home();path=Path(os.environ.get('YUMING_WALK_BVH',str(h/'Tools/accad-mocap/Male1_C03_Run.bvh')));lines=path.read_text().splitlines();nodes={};stack=[];current=None;channels=0
from mathutils import Vector,Matrix
for i,line in enumerate(lines):
 t=line.strip().split()
 if not t:continue
 if t[0] in ['ROOT','JOINT'] or t[:2]==['End','Site']:
  name=t[1] if t[0]!='End' else stack[-1]+'_End';nodes[name]={'parent':stack[-1] if stack else None,'offset':Vector(),'channels':[],'start':channels};current=name
 elif t[0]=='{':stack.append(current)
 elif t[0]=='}':stack.pop()
 elif t[0]=='OFFSET':nodes[current]['offset']=Vector(map(float,t[1:]))
 elif t[0]=='CHANNELS':nodes[current]['channels']=t[2:];nodes[current]['start']=channels;channels+=int(t[1])
 elif t[:2]==['Frame','Time:']:dt=float(t[2]);start=i+1;break
frames=[list(map(float,l.split())) for l in lines[start:] if l.strip()];conversion=Matrix.Rotation(math.pi/2,4,'X')
def sample(index):
 transforms={}
 for name,node in nodes.items():
  m=Matrix.Translation(node['offset'])
  for j,ch in enumerate(node['channels']):
   value=frames[index][node['start']+j]
   if ch.endswith('position'):
    v=Vector();v['XYZ'.index(ch[0])]=value;m=m@Matrix.Translation(v)
   else:m=m@Matrix.Rotation(math.radians(value),4,ch[0])
  if node['parent']:m=transforms[node['parent']]@m
  transforms[name]=m
 return {name:(conversion@m).translation for name,m in transforms.items()}
poses=[sample(i) for i in range(len(frames))];keys=[n for n in ['Spine','Neck','Head','LeftArm','LeftForeArm','LeftHand','RightArm','RightForeArm','RightHand','LeftUpLeg','LeftLeg','LeftFoot','LeftToeBase','RightUpLeg','RightLeg','RightFoot','RightToeBase'] if n in nodes];feature=[]
for p in poses:
 side=p['LeftUpLeg']-p['RightUpLeg'];side.z=0;side.normalize();forward=Vector((side.y,-side.x,0));up=Vector((0,0,1));feature.append([v.dot(axis) for n in keys for v in [p[n]-p['Hips']] for axis in [side,forward,up]])
feature=np.array(feature);best=(float('inf'),0,0)
for lag in range(round(.45/dt),round(.95/dt)):
 for i in range(2,len(frames)-lag-2):
  distance=(poses[i+lag]['Hips']-poses[i]['Hips']).length*.01
  if not .5<distance<4:continue
  err=float(np.mean((feature[i+lag]-feature[i])**2))
  if err<best[0]:best=(err,i,lag)
assert best[2]>0,best
error,first,lag=best
toe_names=['LeftToeBase_End','RightToeBase_End'];grounds={n:min(p[n].z for p in poses[first:first+lag+1]) for n in toe_names};heights=[max(0,min(poses[first+i][n].z-grounds[n] for n in toe_names))*.01 for i in range(lag+1)];heights[-1]=heights[0];phase=min(range(lag),key=lambda i:heights[i]);out=Path(os.environ.get('YUMING_NOEN_WORK',str(h/'Documents/noen-run')));out.mkdir(exist_ok=True);report={'source':path.name,'frame_time':dt,'source_start':first,'source_end':first+lag,'source_period_frames':lag,'duration_s':lag*dt,'output_frames':lag+1,'pose_mse_cm2':error,'source_root_distance_m':(poses[first+lag]['Hips']-poses[first]['Hips']).length*.01,'marker_ground_offsets_cm':grounds,'contact_phase_index':phase,'expected_minimum_boot_height_m':heights};(out/'source_cycle.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
