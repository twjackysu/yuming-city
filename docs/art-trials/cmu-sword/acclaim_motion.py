import os
"""Read CMU ASF/AMC numeric motion data without executing embedded content."""
from pathlib import Path
import math
from mathutils import Vector,Matrix,Euler
class AcclaimMotion:
 def __init__(self,asf,amc):
  for path in [asf,amc]:
   if Path(path).stat().st_size>20_000_000:raise ValueError('Motion input exceeds study size limit')
  self.bones={};self.hierarchy={};section='';current=None;self.unit_length=.45;self.root_orientation=Vector()
  for raw in Path(asf).read_text().splitlines():
   line=raw.strip()
   if not line or line.startswith('#'):continue
   if line.startswith(':'):section=line.split()[0];continue
   tokens=line.split()
   if section==':units' and tokens[0]=='length':self.unit_length=float(tokens[1])
   elif section==':root' and tokens[0]=='order':
    if tokens[1:]!=['TX','TY','TZ','RX','RY','RZ']:raise ValueError('Unsupported root channel order')
   elif section==':root' and tokens[0]=='axis':
    if tokens[1:]!=['XYZ']:raise ValueError('Unsupported root axis order')
   elif section==':root' and tokens[0]=='orientation':self.root_orientation=Vector(map(float,tokens[1:4]))
   elif section==':bonedata':
    if tokens[0]=='begin':current={}
    elif tokens[0]=='end':
     current['axis_matrix']=Euler(tuple(math.radians(a) for a in current['axis']),'XYZ').to_matrix();self.bones[current['name']]=current;current=None
    elif current is not None and tokens[0] in ['name','direction','length','axis','dof']:
     if tokens[0]=='axis' and tokens[4:]!=['XYZ']:raise ValueError('Unsupported bone axis order')
     key=tokens[0];current[key]=tokens[1] if key=='name' else float(tokens[1]) if key=='length' else tokens[1:] if key=='dof' else Vector(map(float,tokens[1:4]))
   elif section==':hierarchy' and tokens[0] not in ['begin','end']:
    for child in tokens[1:]:self.hierarchy[child]=tokens[0]
  if not math.isfinite(self.unit_length) or self.unit_length<=0 or self.root_orientation.length>1e-8:raise ValueError('Unsupported units or root rest orientation')
  for bone in self.bones.values():
   if not all(math.isfinite(v) for v in [*bone['direction'],*bone['axis'],bone['length']]) or bone['length']<0:raise ValueError('Invalid bone geometry')
   if any(channel not in ['rx','ry','rz'] for channel in bone.get('dof',[])):raise ValueError('Unsupported bone DOF')
  self.metres_per_unit=.0254/self.unit_length;self.frames=[];frame=None
  for raw in Path(amc).read_text().splitlines():
   line=raw.strip()
   if not line or line[0] in '#:':continue
   tokens=line.split()
   if len(tokens)==1 and tokens[0].isdigit():
    if frame is not None:self.frames.append(frame)
    frame={}
   else:
    values=[float(v) for v in tokens[1:]]
    if not all(math.isfinite(v) for v in values):raise ValueError('Nonfinite motion')
    frame[tokens[0]]=values
  if frame is not None:self.frames.append(frame)
  for frame in self.frames:
   if len(frame.get('root',[]))!=6:raise ValueError('Invalid root channels')
   for name,bone in self.bones.items():
    if len(frame.get(name,[]))!=len(bone.get('dof',[])):raise ValueError('Incomplete motion frame')
  self.order=[];remaining=set(self.bones)
  while remaining:
   ready=[name for name in self.bones if name in remaining and (self.hierarchy[name]=='root' or self.hierarchy[name] in self.order)]
   if not ready:raise ValueError('Invalid hierarchy')
   self.order.extend(ready);remaining.difference_update(ready)
 def pose(self,index):
  values=self.frames[index];root=values['root'];rot=Euler(tuple(math.radians(v) for v in root[3:6]),'XYZ').to_matrix();rotation={'root':rot};end={'root':Vector(root[:3])*self.metres_per_unit};start={}
  for name in self.order:
   bone=self.bones[name];channels=dict(zip(bone.get('dof',[]),values.get(name,[])));angles=[math.radians(channels.get('r'+axis,0)) for axis in 'xyz'];c=bone['axis_matrix'];rotation[name]=rotation[self.hierarchy[name]]@c@Euler(angles,'XYZ').to_matrix()@c.inverted();start[name]=end[self.hierarchy[name]];end[name]=start[name]+rotation[name]@bone['direction']*(bone['length']*self.metres_per_unit)
  return start,end,rotation
