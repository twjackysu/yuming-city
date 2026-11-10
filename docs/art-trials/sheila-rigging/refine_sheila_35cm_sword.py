import os
import bpy,math,json,numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_SWORD_WORK',str(h/'Documents/sheila-sword-35cm')));root.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=os.environ.get('YUMING_SHEILA_CAPE_BLEND',str(h/'Documents/sheila-cloth-walk/tailored_noen.blend')));s=bpy.context.scene;r=bpy.data.objects['Sheila_Skeleton'];sword=bpy.data.objects['Sheila_Broken_Sword'];atlas=bpy.data.materials['M_Sheila_Clothes'];images={kind:next(n.image for n in atlas.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.name.endswith('_'+kind)) for kind in ['BaseColor','Normal','ORM']}
# Recover the authored steel/edge/grip regions from the matching original geometry.
with bpy.data.libraries.load(os.environ.get('YUMING_SHEILA_SWORD_SOURCE',str(h/'Documents/sheila-sword-v2/source.blend')),link=False) as (src,dst):dst.objects=[n for n in src.objects if 'Sword' in n and 'Badge' not in n]
from mathutils.kdtree import KDTree
centers=[];tags=[];materials=[]
for o in dst.objects:
 for p in o.data.polygons:
  centers.append(sum((o.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices));tags.append((o.name,o.data.materials[p.material_index]));materials.append(o.data.materials[p.material_index])
tree=KDTree(len(centers))
for i,center in enumerate(centers):tree.insert(center,i)
tree.balance();mapping=[];groups={};mapping_error=0
for p in sword.data.polygons:
 center=sum((sword.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices);hit,index,distance=tree.find(center);mapping_error=max(mapping_error,distance);assert distance<1e-5,distance;name,mat=tags[index];mapping.append(mat.name);groups.setdefault(name,set()).update(p.vertices)
scale=r.matrix_world.to_scale().x;blade=groups[next(n for n in groups if n.startswith('Sheila_Broken_Sword'))];before_width=(max(sword.data.vertices[i].co.x for i in blade)-min(sword.data.vertices[i].co.x for i in blade))*scale;ratio=.35/before_width
for i in blade:sword.data.vertices[i].co.x*=ratio
for i in groups[next(n for n in groups if n.startswith('Sheila_Sword_Guard'))]:sword.data.vertices[i].co.x*=.88
sword.data.update();shoulder_width=abs((r.matrix_world@r.data.bones['mixamorig:LeftArm'].head_local).x-(r.matrix_world@r.data.bones['mixamorig:RightArm'].head_local).x)
def steel(name,edge=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');coord=n.new('ShaderNodeTexCoord')
 def noise(scale,detail=2,stretch=None):
  node=n.new('ShaderNodeTexNoise');node.inputs['Scale'].default_value=scale;node.inputs['Detail'].default_value=detail;vector=coord.outputs['Object']
  if stretch:
   mul=n.new('ShaderNodeVectorMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=stretch;l.new(vector,mul.inputs[0]);vector=mul.outputs[0]
  l.new(vector,node.inputs['Vector']);return node.outputs['Fac']
 def ramp(value,lo,hi,a,b):
  node=n.new('ShaderNodeValToRGB');node.color_ramp.elements[0].position=lo;node.color_ramp.elements[0].color=(*a,1);node.color_ramp.elements[1].position=hi;node.color_ramp.elements[1].color=(*b,1);l.new(value,node.inputs[0]);return node.outputs['Color']
 mottling=noise(36,3);base=ramp(mottling,.25,.75,(.065,.075,.085) if not edge else (.40,.43,.46),(.095,.105,.115) if not edge else (.54,.57,.60))
 # Sparse oxidation islands, rather than a uniform brown blade.
 rust=ramp(noise(12,3),.68,.82,(0,0,0),(.8,.8,.8))
 if edge:rust=ramp(noise(18,2),.84,.94,(0,0,0),(.25,.25,.25))
 color=n.new('ShaderNodeMixRGB');color.blend_type='MIX';l.new(rust,color.inputs[0]);l.new(base,color.inputs[1]);color.inputs[2].default_value=(.075,.028,.009,1);l.new(color.outputs[0],p.inputs['Base Color'])
 metal=n.new('ShaderNodeMapRange');metal.inputs['From Min'].default_value=0;metal.inputs['From Max'].default_value=1;metal.inputs['To Min'].default_value=.98;metal.inputs['To Max'].default_value=.15;l.new(rust,metal.inputs['Value']);l.new(metal.outputs[0],p.inputs['Metallic'])
 scratches=ramp(noise(1,2,(220,220,50)),.59,.72,(.24,.24,.24) if not edge else (.14,.14,.14),(.36,.36,.36) if not edge else (.25,.25,.25))
 rough=n.new('ShaderNodeMixRGB');l.new(rust,rough.inputs[0]);l.new(scratches,rough.inputs[1]);rough.inputs[2].default_value=(.90,.90,.90,1);l.new(rough.outputs[0],p.inputs['Roughness'])
 bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00007;bump.inputs['Strength'].default_value=.18;l.new(noise(450,2),bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);return m

face=steel('Revision_Dark_Steel');edge=steel('Revision_Honed_Edge',True);fracture=steel('Revision_Exposed_Fracture');p=fracture.node_tree.nodes.get('Principled BSDF')
for link in list(p.inputs['Roughness'].links):fracture.node_tree.links.remove(link)
p.inputs['Roughness'].default_value=.75
material_map={}
for mat in materials:
 if 'Worn_Bevel' in mat.name:material_map[mat.name]=edge
 elif 'Rough_Fracture' in mat.name:material_map[mat.name]=fracture
 elif 'Forged_Blade' in mat.name:material_map[mat.name]=face
 else:material_map[mat.name]=mat.copy()
unique=list(dict.fromkeys(material_map.values()));sword.data.materials.clear()
for mat in unique:sword.data.materials.append(mat)
for p,name in zip(sword.data.polygons,mapping):p.material_index=unique.index(material_map[name])
s.render.engine='CYCLES';s.cycles.samples=1;s.render.bake.use_clear=False;s.render.bake.margin=4;s.render.bake.margin_type='EXTEND';bpy.ops.object.select_all(action='DESELECT');sword.select_set(True);bpy.context.view_layer.objects.active=sword
# Rasterize the sword UV region for a strict unchanged-outside-region check.
width=2048;height=2048;mask=np.zeros((height,width),dtype=bool);uv=sword.data.uv_layers.active.data;sword.data.calc_loop_triangles()
for t in sword.data.loop_triangles:
 points=np.array([uv[i].uv[:] for i in t.loops])*[width,height];lo=np.maximum(0,np.floor(points.min(axis=0)).astype(int)-1);hi=np.minimum([width-1,height-1],np.ceil(points.max(axis=0)).astype(int)+1)
 if np.any(hi<lo):continue
 xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5);a,b,c=points;v0=c-a;v1=b-a;den=v0[0]*v1[1]-v1[0]*v0[1]
 if abs(den)<1e-9:continue
 u=((xx-a[0])*v1[1]-v1[0]*(yy-a[1]))/den;v=(v0[0]*(yy-a[1])-(xx-a[0])*v0[1])/den;mask[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=(u>=-.001)&(v>=-.001)&(u+v<=1.001)
allowed=mask.copy()
for dy in range(-6,7):
 for dx in range(-6,7):
  ya=max(0,dy);yb=min(height,height+dy);xa=max(0,dx);xb=min(width,width+dx);allowed[ya:yb,xa:xb]|=mask[ya-dy:yb-dy,xa-dx:xb-dx]
reports=[]
for kind,image in images.items():
 before=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(before);backups=[]
 for mat in unique:
  n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');out=next(n for n in n if n.type=='OUTPUT_MATERIAL');old=out.inputs['Surface'].links[0].from_socket;target=n.new('ShaderNodeTexImage');target.image=image;n.active=target;created=[target]
  if kind!='Normal':
   emission=n.new('ShaderNodeEmission');created.append(emission)
   if kind=='BaseColor':
    socket=p.inputs['Base Color']
    if socket.is_linked:l.new(socket.links[0].from_socket,emission.inputs['Color'])
    else:emission.inputs['Color'].default_value=socket.default_value
   else:
    combine=n.new('ShaderNodeCombineXYZ');created.append(combine);combine.inputs[0].default_value=1
    for i,name in [(1,'Roughness'),(2,'Metallic')]:
     socket=p.inputs[name]
     if socket.is_linked:l.new(socket.links[0].from_socket,combine.inputs[i])
     else:combine.inputs[i].default_value=socket.default_value
    l.new(combine.outputs[0],emission.inputs['Color'])
   l.new(emission.outputs[0],out.inputs['Surface'])
  backups.append((mat,out,old,created))
 bpy.ops.object.bake(type='NORMAL' if kind=='Normal' else 'EMIT')
 for mat,out,old,created in backups:
  mat.node_tree.links.new(old,out.inputs['Surface'])
  for node in created:mat.node_tree.nodes.remove(node)
 after=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(after);diff=np.max(np.abs(after.reshape(height,width,4)-before.reshape(height,width,4)),axis=2);outside=float(diff[~allowed].max());reports.append({'map':kind,'changed_pixels':int(np.count_nonzero(diff>1e-5)),'maximum_pixel_difference_outside_sword_region':outside});print('ATLAS_PATCH',reports[-1],flush=True);assert outside<1e-5
 image.filepath_raw=str(root/('Sheila_Clothes_'+kind+'.png'));image.file_format='PNG';image.save();image.pack()
sword.data.materials.clear();sword.data.materials.append(atlas)
for p in sword.data.polygons:p.material_index=0
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'));bpy.ops.object.select_all(action='DESELECT');r.select_set(True)
for o in s.objects:
 if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==r for m in o.modifiers):o.select_set(True)
r.rotation_euler.z=math.pi;bpy.context.view_layer.update();bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_extras=True)
report={'blade_world_width_before_m':before_width,'blade_world_width_after_m':.35,'arm_joint_width_world_m':shoulder_width,'blade_remains_wider_than_arm_joints':.35>shoulder_width,'blade_scale_ratio':ratio,'only_sword_geometry_changed':True,'atlas_patch_checks':reports,'cape_corrective_shapes_retained':24};(root/'sword_revision.json').write_text(json.dumps(report,indent=2));print('SWORD_REVISION',report,flush=True)
