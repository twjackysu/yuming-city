import os
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('UNDERTAKER_PRODUCTION', str(Path.home() / 'Documents\\undertaker-production')));bpy.ops.wm.open_mainfile(filepath=os.environ.get('UNDERTAKER_ANATOMY', str(Path.home() / 'Documents\\noen-production\\anatomy.blend')));human=bpy.data.objects['Noen_Anatomy'];rig=bpy.data.objects['Noen_Skeleton'];rig.name='Undertaker_Skeleton'
bpy.ops.object.select_all(action='DESELECT');human.select_set(True);bpy.context.view_layer.objects.active=human
for modifier in human.modifiers:
 if modifier.type=='ARMATURE':modifier.show_viewport=False
bpy.ops.object.convert(target='MESH');human=bpy.context.object
for modifier in list(human.modifiers):human.modifiers.remove(modifier)
lo=min(v.co.z for v in human.data.vertices);height=max(v.co.z for v in human.data.vertices)-lo;factor=2.35/height
for vertex in human.data.vertices:vertex.co=Vector((vertex.co.x*factor,vertex.co.y*factor,(vertex.co.z-lo)*factor))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
positions={bone.name:(bone.head.copy(),bone.tail.copy()) for bone in rig.data.edit_bones}
for bone in rig.data.edit_bones:
 head,tail=positions[bone.name];bone.head=Vector((head.x*factor,head.y*factor,(head.z-lo)*factor));bone.tail=Vector((tail.x*factor,tail.y*factor,(tail.z-lo)*factor))
frame=rig.data.edit_bones.new('frame_root');frame.head=(0,.42,1.8);frame.tail=(0,.42,2.1);frame.parent=rig.data.edit_bones['mixamorig:Spine2']
for side,sx in [('L',1),('R',-1)]:
 for panel,sy in [('Front',-1),('Back',1)]:
  upper=rig.data.edit_bones.new('Robe_'+panel+'_'+side+'_Upper');upper.head=(sx*.14,sy*.12,1.25);upper.tail=(sx*.20,sy*.18,.65);upper.parent=rig.data.edit_bones['mixamorig:Hips'];lower=rig.data.edit_bones.new('Robe_'+panel+'_'+side+'_Lower');lower.head=upper.tail;lower.tail=(sx*.25,sy*.20,.08);lower.parent=upper;lower.use_connect=True
 previous=frame
 for part in range(5):
  points=[(sx*.4,.46,z) for z in [1.145,.845,.545,.245,.045]]+[(sx*.6,.46,.012)]
  bone=rig.data.edit_bones.new('Chain_'+side+'_'+str(part));bone.head=points[part];bone.tail=points[part+1];bone.parent=previous;bone.use_connect=part>0;previous=bone
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.import_scene.gltf(filepath=str(root/'triposg/body_baked/undertaker_body.glb'));body=next(o for o in bpy.context.selected_objects if o.type=='MESH');body.name='Undertaker_Robes';bpy.context.view_layer.objects.active=body;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Fit wrist joints to the reconstructed cuffs before transferring weights.
deltas={}
for side,sign in [('Left',1),('Right',-1)]:
 old=rig.data.bones['mixamorig:'+side+'Hand'].head_local.copy();goal=Vector((sign*.52,0,1.28));deltas[side]=goal-old
 groups={group.index for group in human.vertex_groups if group.name.startswith('mixamorig:'+side+'Hand')}
 for vertex in human.data.vertices:
  weight=min(1.,sum(assignment.weight for assignment in vertex.groups if assignment.group in groups));vertex.co+=deltas[side]*weight
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT');snapshot={bone.name:(bone.head.copy(),bone.tail.copy()) for bone in rig.data.edit_bones}
for side,delta in deltas.items():
 rig.data.edit_bones['mixamorig:'+side+'ForeArm'].tail=snapshot['mixamorig:'+side+'Hand'][0]+delta
 for bone in rig.data.edit_bones:
  if bone.name.startswith('mixamorig:'+side+'Hand'):bone.head=snapshot[bone.name][0]+delta;bone.tail=snapshot[bone.name][1]+delta
bpy.ops.object.mode_set(mode='OBJECT');body.select_set(True);rig.select_set(False);bpy.context.view_layer.objects.active=body

for group in human.vertex_groups:body.vertex_groups.new(name=group.name)
transfer=body.modifiers.new('Anatomical skin transfer','DATA_TRANSFER');transfer.object=human;transfer.use_vert_data=True;transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST';bpy.ops.object.modifier_apply(modifier=transfer.name)
robe_groups={bone.name:body.vertex_groups.new(name=bone.name) for bone in rig.data.bones if bone.name.startswith('Robe_')}
# Semantic cloth weights avoid nearest-surface jumps between sleeves, fingers and hips.
def smoothstep(a,b,x):
 t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3-2*t)
bone_names={bone.name for bone in rig.data.bones}
for vertex in body.data.vertices:
 x,y,z=vertex.co;weights={body.vertex_groups[g.group].name:g.weight for g in vertex.groups if body.vertex_groups[g.group].name in bone_names}
 for name in list(weights):
  if 'Hand' in name and name.split('Hand')[1]:
   hand=name.split('Hand')[0]+'Hand';weights[hand]=weights.get(hand,0)+weights.pop(name)
 blend=1-smoothstep(1.23,1.38,z)
 weights={name:value*(1-blend) for name,value in weights.items()}
 left=smoothstep(-.2,.2,x);back=smoothstep(-.15,.15,y);lower=1-smoothstep(.5,.8,z)
 for side,sw in [('L',left),('R',1-left)]:
  for panel,pw in [('Front',1-back),('Back',back)]:
   for level,lw in [('Upper',1-lower),('Lower',lower)]:weights['Robe_'+panel+'_'+side+'_'+level]=blend*sw*pw*lw
 # Boot movement fades smoothly into the hem instead of cutting triangles at a threshold.
 foot=(1-smoothstep(.13,.26,z))*smoothstep(.07,.16,abs(x))*(1-smoothstep(.36,.48,abs(x)))*(1-smoothstep(-.02,.13,y))
 weights={name:value*(1-foot) for name,value in weights.items()};name='mixamorig:'+('Left' if x>0 else 'Right')+'Foot';weights[name]=weights.get(name,0)+foot
 arm=smoothstep(.30,.45,abs(x))*smoothstep(.88,1.10,z)*(1-smoothstep(1.88,2.03,z))
 weights={name:value*(1-arm) for name,value in weights.items()};side='Left' if x>0 else 'Right';hand=1-smoothstep(1.25,1.39,z);upper=smoothstep(1.55,1.76,z)
 for suffix,value in [('Hand',hand),('ForeArm',(1-hand)*(1-upper)),('Arm',(1-hand)*upper)]:
  name='mixamorig:'+side+suffix;weights[name]=weights.get(name,0)+arm*value
 for group in body.vertex_groups:group.remove([vertex.index])
 total=sum(weights.values())
 for name,value in weights.items():
  if value>1e-6:body.vertex_groups[name].add([vertex.index],value/total,'REPLACE')
# Welded-position adjacency also smooths UV-split copies consistently.
import numpy as np
names=sorted(bone_names);lookup={name:i for i,name in enumerate(names)};positions={};unique=[];ids=[]
for v in body.data.vertices:
 key=tuple(round(c,5) for c in v.co)
 if key not in positions:positions[key]=len(unique);unique.append([])
 ids.append(positions[key]);unique[ids[-1]].append(v.index)
values=np.zeros((len(unique),len(names)),dtype=np.float64)
for i,vertices in enumerate(unique):
 for vi in vertices:
  for g in body.data.vertices[vi].groups:
   name=body.vertex_groups[g.group].name
   if name in lookup:values[i,lookup[name]]+=g.weight/len(vertices)
edges=set()
for edge in body.data.edges:
 a,b=[ids[v] for v in edge.vertices]
 if a!=b:edges.add((min(a,b),max(a,b)))
a=np.array([v[0] for v in edges]);b=np.array([v[1] for v in edges]);degree=np.bincount(np.r_[a,b],minlength=len(unique));degree=np.maximum(degree,1)[:,None]
for iteration in range(12):
 totals=np.zeros_like(values);np.add.at(totals,a,values[b]);np.add.at(totals,b,values[a]);values=.55*values+.45*totals/degree
for vertex in body.data.vertices:
 row=values[ids[vertex.index]];selected=np.argsort(row)[-4:];total=sum(row[selected])
 for group in body.vertex_groups:group.remove([vertex.index])
 for i in selected:
  if row[i]>1e-6:body.vertex_groups[names[i]].add([vertex.index],float(row[i]/total),'REPLACE')
body.parent=rig;modifier=body.modifiers.new('Skin','ARMATURE');modifier.object=rig;bpy.data.objects.remove(human,do_unlink=True)
def metal(name,color,metallic=.8,rough=.7):
 mat=bpy.data.materials.new(name);mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=rough;noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=25;noise.inputs['Detail'].default_value=4;coordinates=n.new('ShaderNodeTexCoord');l.new(coordinates.outputs['Object'],noise.inputs['Vector']);ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.45;ramp.color_ramp.elements[0].color=(.025,.03,.035,1);ramp.color_ramp.elements[1].position=.65;ramp.color_ramp.elements[1].color=(*color,1);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color']);bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.0006;bump.inputs['Strength'].default_value=.45;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);oxidation=n.new('ShaderNodeMapRange');oxidation.inputs['From Min'].default_value=.45;oxidation.inputs['From Max'].default_value=.65;oxidation.inputs['To Min'].default_value=metallic;oxidation.inputs['To Max'].default_value=.05;l.new(noise.outputs['Fac'],oxidation.inputs[0]);l.new(oxidation.outputs[0],p.inputs['Metallic']);wear=n.new('ShaderNodeMapRange');wear.inputs['From Min'].default_value=.45;wear.inputs['From Max'].default_value=.65;wear.inputs['To Min'].default_value=max(.2,rough-.2);wear.inputs['To Max'].default_value=.9;l.new(noise.outputs['Fac'],wear.inputs[0]);l.new(wear.outputs[0],p.inputs['Roughness']);return mat
rust=metal('M_FrameRust',(.14,.065,.025));joint=metal('M_FrameJoint',(.22,.12,.04),.7,.65)
def skin(obj,bone):
 obj.parent=rig;group=obj.vertex_groups.new(name=bone);group.add(list(range(len(obj.data.vertices))),1,'REPLACE');modifier=obj.modifiers.new('Skin','ARMATURE');modifier.object=rig

def bar(name,location,dimensions,material):
 bpy.ops.mesh.primitive_cube_add(size=1,location=location);obj=bpy.context.object;obj.name=name;obj.scale=dimensions;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel=obj.modifiers.new('Forged edge','BEVEL');bevel.width=.004;bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);obj.data.materials.append(material);skin(obj,'frame_root');return obj
# Exactly two vertical posts and three crossbars.
for side,sx in [('L',1),('R',-1)]:bar('Frame_Post_'+side,(sx*.4,.42,1.75),(.07,.06,1.70),rust)
for index,z in enumerate([1.18,1.82,2.55]):
 bar('Frame_Crossbar_'+str(index),(0,.42,z),(.86,.06,.065),rust)
 for side,sx in [('L',1),('R',-1)]:
  bar('Frame_Joint_Plate_'+side+str(index),(sx*.4,.465,z),(.105,.025,.105),joint)
  bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.026,depth=.025,location=(sx*.4,.49,z),rotation=(math.pi/2,0,0));obj=bpy.context.object;obj.name='Frame_Joint_Bolt';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);obj.data.materials.append(joint);skin(obj,'frame_root')
# Interlocking elliptical links; each chain has five controllable segments and a grounded tail.
for side,sx in [('L',1),('R',-1)]:
 for index in range(26):
  if index<22:
   location=(sx*.4,.46,1.12-index*.05);rotation=(math.pi/2,0,(index%2)*math.pi/2);scale=(1,1.5,1)
  else:
   location=(sx*(.4+(index-21)*.045),.46,.027 if index==22 else (.012 if index==24 else .033));rotation=(0,0,0) if index%2==0 else (math.pi/2,0,0);scale=(1.5,1,1)
  bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,major_radius=.027,minor_radius=.006,location=location,rotation=rotation);obj=bpy.context.object;obj.name='Chain_Link_'+side+'_%02d'%index;obj.scale=scale;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);obj.data.materials.append(rust)
  for face in obj.data.polygons:face.use_smooth=True
  skin(obj,'Chain_'+side+'_'+str(4 if index>=22 else min(3,index//6)))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.world=bpy.data.worlds.new('Review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
for location,power,size in [((3,-4,5),850,4),((-3,-1,3),450,3),((0,4,4),800,3)]:
 bpy.ops.object.light_add(type='AREA',location=location);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.size=size;lamp.rotation_euler=(Vector((0,0,1.3))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=3.05
for label,location in [('undertaker_front',(0,-5,1.4)),('undertaker_back',(0,5,1.4)),('undertaker_threequarter',(3,-5,1.7))]:
 cam.location=location;cam.rotation_euler=(Vector((0,0,1.3))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/(label+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'undertaker_assembly.blend'));(root/'assembly_report.json').write_text(json.dumps({'bones':len(rig.data.bones),'triangles':sum(sum(len(f.vertices)-2 for f in obj.data.polygons) for obj in scene.objects if obj.type=='MESH'),'posts':2,'crossbars':3,'chain_links':52,'required_material':'M_FrameJoint','status':'pose_and_material_review_pending'},indent=2))
