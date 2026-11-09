import bpy,math,json,os,bmesh
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
home=Path.home();root=Path(os.environ.get('YUMING_SHEILA_WEAPON_WORK',str(home/'Documents/sheila-sword-delivery')));root.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=os.environ.get('YUMING_SHEILA_BASE_BLEND',str(home/'Documents/sheila-production/tailored_baked.blend')));scene=bpy.context.scene;rig=bpy.data.objects['Sheila_Skeleton'];coat=bpy.data.objects['Sheila_Coat']
old=[o for o in scene.objects if o.type=='MESH' and (('Sword' in o.name or 'Broken_Sword' in o.name) and 'Badge' not in o.name)];print('REPLACE_SWORD',[o.name for o in old]);assert old
for obj in old:bpy.data.objects.remove(obj,do_unlink=True)
def skin(obj,bone):
 obj.parent=rig;g=obj.vertex_groups.new(name=bone);g.add(list(range(len(obj.data.vertices))),1,'REPLACE');mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig

def steel(name,edge=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');coord=n.new('ShaderNodeTexCoord')
 def noise(scale,detail=2,stretch=None):
  node=n.new('ShaderNodeTexNoise');node.inputs['Scale'].default_value=scale;node.inputs['Detail'].default_value=detail;vector=coord.outputs['Object']
  if stretch:
   mul=n.new('ShaderNodeVectorMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=stretch;l.new(vector,mul.inputs[0]);vector=mul.outputs[0]
  l.new(vector,node.inputs['Vector']);return node.outputs['Fac']
 def ramp(value,lo,hi,a,b):
  node=n.new('ShaderNodeValToRGB');node.color_ramp.elements[0].position=lo;node.color_ramp.elements[0].color=(*a,1);node.color_ramp.elements[1].position=hi;node.color_ramp.elements[1].color=(*b,1);l.new(value,node.inputs[0]);return node.outputs['Color']
 mottling=noise(36,3);base=ramp(mottling,.25,.75,(.16,.18,.20) if not edge else (.40,.43,.46),(.20,.22,.24) if not edge else (.54,.57,.60))
 # Sparse oxidation islands, rather than a uniform brown blade.
 rust=ramp(noise(12,3),.68,.82,(0,0,0),(.8,.8,.8))
 if edge:rust=ramp(noise(18,2),.84,.94,(0,0,0),(.25,.25,.25))
 color=n.new('ShaderNodeMixRGB');color.blend_type='MIX';l.new(rust,color.inputs[0]);l.new(base,color.inputs[1]);color.inputs[2].default_value=(.075,.028,.009,1);l.new(color.outputs[0],p.inputs['Base Color'])
 metal=n.new('ShaderNodeMapRange');metal.inputs['From Min'].default_value=0;metal.inputs['From Max'].default_value=1;metal.inputs['To Min'].default_value=.94;metal.inputs['To Max'].default_value=.15;l.new(rust,metal.inputs['Value']);l.new(metal.outputs[0],p.inputs['Metallic'])
 scratches=ramp(noise(1,2,(220,220,50)),.59,.72,(.42,.42,.42) if not edge else (.18,.18,.18),(.58,.58,.58) if not edge else (.34,.34,.34))
 rough=n.new('ShaderNodeMixRGB');l.new(rust,rough.inputs[0]);l.new(scratches,rough.inputs[1]);rough.inputs[2].default_value=(.90,.90,.90,1);l.new(rough.outputs[0],p.inputs['Roughness'])
 bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00007;bump.inputs['Strength'].default_value=.18;l.new(noise(450,2),bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);return m
face=steel('Sheila_Forged_Blade');edge=steel('Sheila_Worn_Bevel',True);fracture=steel('Sheila_Rough_Fracture');fracture.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.92
xs=[-.275,-.255,-.17,-.05,-.025,0,.025,.06,.12,.255,.275];ends=[(-.275,.96),(-.17,.87),(-.05,.91),(.06,.84),(.12,.92),(.275,.89)]
def bottom(x):
 for (a,z),(b,w) in zip(ends,ends[1:]):
  if a-1e-6<=x<=b+1e-6:return z+(w-z)*(x-a)/(b-a)
 raise ValueError(x)
def thickness(x):
 a=abs(x)
 if a>=.255:return .001+(.007-.001)*(.275-a)/.020
 if a>=.025:return .007+(.016-.007)*(.255-a)/.230
 return .010+.006*a/.025
verts=[];faces=[];matids=[];rows=6;cols=len(xs)
for side in [-1,1]:
 for row in range(rows):
  t=row/(rows-1)
  for x in xs:verts.append((x*.8*(1-.35*t),.2825+side*thickness(x),1.42*(1-t)+(bottom(x)-.20)*t))
for side in range(2):
 for row in range(rows-1):
  for col in range(cols-1):
   a=side*rows*cols+row*cols+col;f=(a,a+1,a+1+cols,a+cols);faces.append(f if side==0 else tuple(reversed(f)));matids.append(1 if col in [0,cols-2] else 0)
for row in range(rows-1):
 for col in [0,cols-1]:
  a=row*cols+col;b=a+cols;faces.append((a,b,b+rows*cols,a+rows*cols));matids.append(1)
for row in [0,rows-1]:
 for col in range(cols-1):
  a=row*cols+col;faces.append((a,a+rows*cols,a+1+rows*cols,a+1));matids.append(2 if row==rows-1 else 0)
mesh=bpy.data.meshes.new('Forged fractured blade');mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new('Sheila_Broken_Sword',mesh);scene.collection.objects.link(obj)
for mat in [face,edge,fracture]:mesh.materials.append(mat)
for polygon,index in zip(mesh.polygons,matids):polygon.material_index=index
# Consistent outward normals on both blade faces and all fracture walls.
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();skin(obj,'weapon_socket')
def bar(name,center,dimensions,mat,bevel):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center);obj=bpy.context.object;obj.name=name;obj.scale=dimensions;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);obj.data.materials.append(mat);mod=obj.modifiers.new('Forged edge','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name);skin(obj,'weapon_socket');return obj
guard_profile=[(-.31,1.415),(-.28,1.46),(-.15,1.475),(0,1.468),(.15,1.475),(.28,1.46),(.31,1.415),(.26,1.425),(.12,1.442),(-.12,1.442),(-.26,1.425)]
gv=[(x*.85,y,1.445+(z-1.445)*.6) for y in [.2695,.2955] for x,z in guard_profile];count=len(guard_profile);gf=[tuple(reversed(range(count))),tuple(range(count,2*count))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)];mesh=bpy.data.meshes.new('Curved forged guard');mesh.from_pydata(gv,[],gf);guard=bpy.data.objects.new('Sheila_Sword_Guard',mesh);scene.collection.objects.link(guard);mesh.materials.append(face);bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();bpy.ops.object.select_all(action='DESELECT');guard.select_set(True);bpy.context.view_layer.objects.active=guard;mod=guard.modifiers.new('Rounded forged edge','BEVEL');mod.width=.003;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name);skin(guard,'weapon_socket')
leather=bpy.data.materials.new('Sheila_Grip_Leather');leather.use_nodes=True;p=leather.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.035,.018,.01,1);p.inputs['Roughness'].default_value=.87
bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.0185,depth=.21,location=(0,.2825,1.565));grip=bpy.context.object;grip.name='Sheila_Sword_Grip';grip.scale.y=.88;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);grip.data.materials.append(leather);skin(grip,'weapon_socket')
wrapmat=leather.copy();wrapmat.name='Sheila_Grip_Wrapped_Leather';wrapmat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.055,.027,.012,1)
for ring in range(8):
 verts=[]
 for z in [1.485+ring*.022,1.495+ring*.022]:
  for i in range(16):
   angle=i*math.tau/16;verts.append((.0195*math.cos(angle),.2825+.0172*math.sin(angle),z))
 faces=[(i,(i+1)%16,(i+1)%16+16,i+16) for i in range(16)];mesh=bpy.data.meshes.new('Leather grip winding');mesh.from_pydata(verts,[],faces);obj=bpy.data.objects.new('Sheila_Sword_Grip_Wrap',mesh);scene.collection.objects.link(obj);mesh.materials.append(wrapmat);skin(obj,'weapon_socket')
bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.025,depth=.025,location=(0,.2825,1.684));pommel=bpy.context.object;pommel.name='Sheila_Sword_Pommel';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);pommel.data.materials.append(face);skin(pommel,'weapon_socket')

bpy.ops.wm.save_as_mainfile(filepath=str(root/'source.blend'))
