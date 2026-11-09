import os
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('SHEILA_PRODUCTION', str(Path.home()/'Documents'/'sheila-production')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_base.blend'));rig=bpy.data.objects['Sheila_Skeleton'];coat=bpy.data.objects['Sheila_Coat']
def material(name,color,metal=0,rough=.8):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=130;bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.0002;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);return m
def skin(obj,bone):
 obj.parent=rig;g=obj.vertex_groups.new(name='mixamorig:'+bone);g.add(list(range(len(obj.data.vertices))),1,'REPLACE');mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig
slate=material('Sheila_Dark_Quilted_Tunic',(.035,.042,.047));iron=material('Sheila_Oxidized_Iron',(.065,.07,.075),.8,.55);silver=material('Sheila_Silver_Badge',(.36,.38,.40),.9,.38);copper=material('Sheila_Copper',(.24,.095,.034),.85,.45)
bm=bmesh.new();bm.from_mesh(coat.data);bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,.84),plane_no=(0,0,1),clear_inner=True);bm.to_mesh(coat.data);bm.free();coat.data.materials.clear();coat.data.materials.append(slate)
for f in coat.data.polygons:f.material_index=0
suit=bpy.data.objects['Sheila_Anatomy.male_casualsuit01'];suit.data.materials.clear();suit.data.materials.append(material('Sheila_Twill',(.055,.043,.03)))
for f in suit.data.polygons:f.material_index=0
for v in suit.data.vertices:
 if v.co.z>.85:v.co.x*=.90;v.co.y*=.82
# Independent short cape, open at the front with shallow woven folds.
verts=[];faces=[];columns=80;rows=12
for row in range(rows):
 t=row/(rows-1)
 for column in range(columns):
  theta=math.radians(38)+(math.tau-math.radians(76))*column/(columns-1);rx=.075+(.34-.075)*math.sin(t*math.pi/2);ry=.065+(.21-.065)*math.sin(t*math.pi/2);fold=.012*math.sin(theta*14)*t*t;z=1.43-.28*t+.015*math.cos(theta*9)*t*t;verts.append((math.sin(theta)*(rx+fold),-math.cos(theta)*(ry+fold),z))
for row in range(rows-1):
 for column in range(columns-1):
  a=row*columns+column;faces.append((a,a+1,a+1+columns,a+columns))
from mathutils.bvhtree import BVHTree
bvh=BVHTree.FromPolygons([v.co for v in coat.data.vertices],[f.vertices[:] for f in coat.data.polygons])
for i,(x,y,z) in enumerate(verts):
 hit,normal,_,_=bvh.ray_cast(Vector((x,y,2)),Vector((0,0,-1)),2)
 if hit is not None:verts[i]=(x,y,max(z,hit.z+.015))
for iteration in range(3):
 for face in faces:
  center=sum((Vector(verts[i]) for i in face),Vector())/len(face);hit,_,_,_=bvh.ray_cast(Vector((center.x,center.y,2)),Vector((0,0,-1)),2)
  if hit is not None and hit.z+.015>center.z:
   lift=hit.z+.015-center.z
   for index in face:verts[index]=(verts[index][0],verts[index][1],verts[index][2]+lift)
mesh=bpy.data.meshes.new('Short cape');mesh.from_pydata(verts,[],faces);cape=bpy.data.objects.new('Sheila_White_Short_Cape',mesh);bpy.context.collection.objects.link(cape);skin(cape,'Spine2')
wool=material('Sheila_White_Wool',(.57,.55,.49),rough=.94);n=wool.node_tree.nodes;l=wool.node_tree.links;p=n.get('Principled BSDF');geo=n.new('ShaderNodeNewGeometry');xyz=n.new('ShaderNodeSeparateXYZ');l.new(geo.outputs['Position'],xyz.inputs[0]);height=n.new('ShaderNodeMapRange');height.inputs['From Min'].default_value=1.20;height.inputs['From Max'].default_value=1.33;l.new(xyz.outputs['Z'],height.inputs[0]);mix=n.new('ShaderNodeMixRGB');l.new(height.outputs[0],mix.inputs[0]);mix.inputs[1].default_value=(.12,.095,.065,1);mix.inputs[2].default_value=(.57,.55,.49,1);l.new(mix.outputs[0],p.inputs['Base Color']);cape.data.materials.append(wool)
for f in mesh.polygons:f.use_smooth=True

cape.vertex_groups.clear()
for group in coat.vertex_groups:cape.vertex_groups.new(name=group.name)
bpy.ops.object.select_all(action='DESELECT');cape.select_set(True);bpy.context.view_layer.objects.active=cape
transfer=cape.modifiers.new('Cape follows shoulders','DATA_TRANSFER');transfer.object=coat;transfer.use_vert_data=True;transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST';bpy.ops.object.modifier_move_up(modifier=transfer.name);bpy.ops.object.modifier_apply(modifier=transfer.name)

# Actual three crossed miniature swords on the chest.
def bar(name,start,end,width,depth,mat,bone):
 delta=Vector(end)-Vector(start);bpy.ops.mesh.primitive_cube_add(size=1,location=(Vector(start)+Vector(end))/2);obj=bpy.context.object;obj.name=name;obj.rotation_euler=delta.to_track_quat('Z','Y').to_euler();obj.scale=(width,depth,delta.length);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);obj.data.materials.append(mat);skin(obj,bone);return obj
for angle in [-40,0,40]:
 a=math.radians(angle);center=Vector((-.075,-.151,1.37));direction=Vector((math.sin(a),0,math.cos(a)));bar('Sheila_Badge_Sword',center-direction*.026,center+direction*.026,.003,.002,silver,'Spine2');cross=Vector((direction.z,0,-direction.x));bar('Sheila_Badge_Guard',center-direction*.017-cross*.009,center-direction*.017+cross*.009,.002,.002,silver,'Spine2')
# Broad broken blade, rigidly attached to the back; lower edge is fractured.
profile=[(-.275,1.42),(.275,1.42),(.275,.89),(.12,.92),(.06,.84),(-.05,.91),(-.17,.87),(-.275,.96)];verts=[(x,y,z) for y in [.27,.295] for x,z in profile];count=len(profile);faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)];mesh=bpy.data.meshes.new('Broken blade');mesh.from_pydata(verts,[],faces);sword=bpy.data.objects.new('Sheila_Broken_Sword',mesh);bpy.context.collection.objects.link(sword);sword.data.materials.append(iron);skin(sword,'Spine2');bar('Sheila_Sword_Guard',(-.32,.285,1.45),(.32,.285,1.45),.025,.035,iron,'Spine2');bar('Sheila_Sword_Grip',(0,.285,1.46),(0,.285,1.67),.04,.035,material('Sheila_Grip_Leather',(.035,.02,.012)),'Spine2')
bpy.ops.mesh.primitive_torus_add(major_radius=.010,minor_radius=.002,major_segments=24,minor_segments=6,location=(.079,-.005,1.52),rotation=(math.pi/2,0,0));ear=bpy.context.object;ear.name='Sheila_Left_Copper_Earring';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);ear.data.materials.append(copper);skin(ear,'Head')
# Fit the already-made original boot design to Sheila's ankle positions.
with bpy.data.libraries.load(os.environ.get('SHEILA_BOOT_SOURCE', str(Path.home()/'Documents'/'noen-tailored'/'noen_candidate_v2.blend')),link=False) as (data,target):target.objects=[name for name in data.objects if name in ['Noen_Boot_Left','Noen_Boot_Right','Noen_Skeleton']]
source_rig=next(o for o in target.objects if o.type=='ARMATURE')
for obj in target.objects:
 if obj.type!='MESH':continue
 bpy.context.collection.objects.link(obj);side='Left' if 'Left' in obj.name else 'Right';delta=rig.data.bones['mixamorig:'+side+'Foot'].head_local-source_rig.data.bones['mixamorig:'+side+'Foot'].head_local
 for v in obj.data.vertices:v.co.x+=delta.x;v.co.y+=delta.y
 obj.name='Sheila_Boot_'+side;obj.parent=rig
 for mod in obj.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
bpy.data.objects.remove(source_rig,do_unlink=True)

# Remove concealed skin and the redundant shirt sleeves; retain authored weights.
body=bpy.data.objects['Sheila_Anatomy'];bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<1.36 and not (abs(v.co.x)>.43 and v.co.z>.82)],context='VERTS');bm.to_mesh(body.data);bm.free()
bm=bmesh.new();bm.from_mesh(suit.data);bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z>1.05],context='VERTS');bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,.25),plane_no=(0,0,1),clear_inner=True)
for vertex in bm.verts:
 if vertex.co.z<.4:
  side='Left' if vertex.co.x>0 else 'Right';foot=rig.data.bones['mixamorig:'+side+'Foot'].head_local;knee=rig.data.bones['mixamorig:'+side+'Leg'].head_local;t=max(0.,min(1.,(vertex.co.z-foot.z)/(knee.z-foot.z)));center=foot.lerp(knee,t);factor=1-.35*max(0.,min(1.,(.4-vertex.co.z)/.08));vertex.co.x=center.x+(vertex.co.x-center.x)*factor;vertex.co.y=center.y+(vertex.co.y-center.y)*factor
bm.to_mesh(suit.data);bm.free()
bpy.ops.object.select_all(action='DESELECT');suit.select_set(True);bpy.context.view_layer.objects.active=suit;dec=suit.modifiers.new('Trouser budget','DECIMATE');dec.ratio=.60;bpy.ops.object.modifier_apply(modifier=dec.name)
eyes=bpy.data.objects['Sheila_Anatomy.high-poly'];bpy.ops.object.select_all(action='DESELECT');eyes.select_set(True);bpy.context.view_layer.objects.active=eyes;dec=eyes.modifiers.new('Eye budget','DECIMATE');dec.ratio=.5;bpy.ops.object.modifier_apply(modifier=dec.name)
# Normalize overall height using visible, connected body geometry.
height=max(v.co.z for v in body.data.vertices);rig.scale=(1.75/height,)*3

scene=bpy.context.scene;cam=scene.camera;cam.data.ortho_scale=2.1
for label,loc in [('sheila_front',(0,-4,1)),('sheila_back',(0,4,1)),('sheila_threequarter',(2.6,-4,1.4))]:
 cam.location=loc;cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/(label+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'sheila_assembly.blend'));print('TRIANGLES',sum(sum(len(f.vertices)-2 for f in obj.data.polygons) for obj in scene.objects if obj.type=='MESH'))
