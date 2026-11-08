import os
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')))
bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_base.blend'))
rig=bpy.data.objects['Noen_Skeleton'];coat=bpy.data.objects['Noen_Coat']
bpy.data.objects.remove(bpy.data.objects['Noen_Anatomy.shoes05'],do_unlink=True)
pants=bpy.data.objects['Noen_Anatomy.male_casualsuit01'];pants.name='Noen_Trousers_Shirt'
bm=bmesh.new();bm.from_mesh(pants.data)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z>1.10 or (abs(v.co.x)>.24 and v.co.z>.75)],context='VERTS')
for vert in bm.verts:
    if vert.co.z>.8:vert.co.x*=.82;vert.co.y*=.60
    if vert.co.z<.34:vert.co.z-=.035
bm.to_mesh(pants.data);bm.free()
bpy.ops.object.select_all(action='DESELECT');pants.select_set(True);bpy.context.view_layer.objects.active=pants
dec=pants.modifiers.new('Trouser budget','DECIMATE');dec.ratio=.65;bpy.ops.object.modifier_apply(modifier=dec.name)
# Separate open coat skirts, with a modest front opening and rear walking vent.
bm=bmesh.new();bm.from_mesh(coat.data)
cuts=[f for f in bm.faces if ((min(v.co.x for v in f.verts)<=0<=max(v.co.x for v in f.verts)) and ((f.calc_center_median().y<-.07 and f.calc_center_median().z<1.05) or (f.calc_center_median().y>.07 and f.calc_center_median().z<.74))) or (abs(f.calc_center_median().x)<.022 and f.calc_center_median().y<-.07 and f.calc_center_median().z<1.05) or (abs(f.calc_center_median().x)<.014 and f.calc_center_median().y>.07 and f.calc_center_median().z<.70)]
bmesh.ops.delete(bm,geom=cuts,context='FACES')
for v in bm.verts:
    if v.co.z<1.04 and v.co.y<-.07 and abs(v.co.x)<.16:
        v.co.x+=(1 if v.co.x>0 else -1)*.035*(1-min(1.,abs(v.co.x)/.16))*min(1.,(1.04-v.co.z)/.3)
for vert in bm.verts:
    if vert.co.y>0 and .90<vert.co.z<1.12:vert.co.y+=.035*max(0.,1-abs(vert.co.z-1.02)/.12)
bm.to_mesh(coat.data);bm.free();coat.data.validate()
def cloth_material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=.9
    coord=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=18;noise.inputs['Detail'].default_value=4;l.new(coord.outputs['Object'],noise.inputs[0])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=tuple(c*.85 for c in color)+(1,);ramp.color_ramp.elements[1].color=tuple(c*1.12 for c in color)+(1,);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
    waves=[]
    for axis in ['X','Z']:
        w=n.new('ShaderNodeTexWave');w.bands_direction=axis;w.inputs['Scale'].default_value=650;w.inputs['Distortion'].default_value=1.5;l.new(coord.outputs['Object'],w.inputs[0]);waves.append(w)
    mult=n.new('ShaderNodeMath');mult.operation='MULTIPLY';l.new(waves[0].outputs['Fac'],mult.inputs[0]);l.new(waves[1].outputs['Fac'],mult.inputs[1]);b=n.new('ShaderNodeBump');b.inputs['Distance'].default_value=.00013;b.inputs['Strength'].default_value=.35;l.new(mult.outputs[0],b.inputs['Height']);l.new(b.outputs[0],p.inputs['Normal'])
    return m
wool=cloth_material('M_Noen_Charcoal_Wool',(.065,.053,.041));lining=cloth_material('M_Noen_Lining',(.035,.03,.025));trousermat=cloth_material('M_Noen_Brown_Twill',(.09,.06,.035));patchmat=cloth_material('M_Noen_Repair_Cloth',(.105,.085,.055));threadmat=cloth_material('M_Noen_Linen_Thread',(.26,.21,.13))
coat.data.materials.clear();coat.data.materials.append(wool);pants.data.materials.clear();pants.data.materials.append(trousermat)
for o in [coat,pants]:
    for f in o.data.polygons:f.material_index=0
# Front and rear stitched repairs follow the garment surface, not floating planes.
bvh=BVHTree.FromPolygons([v.co for v in coat.data.vertices],[p.vertices[:] for p in coat.data.polygons],all_triangles=False)
def garment_point(x,z,front):
    hit,n,_,_=bvh.ray_cast(Vector((x,-1 if front else 1,z)),Vector((0,1 if front else -1,0)),2)
    if hit is None:raise ValueError('Patch outside coat')
    return hit+n*.005
def skin(obj,bone):
    obj.parent=rig;g=obj.vertex_groups.new(name='mixamorig:'+bone);g.add(list(range(len(obj.data.vertices))),1.,'REPLACE');mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig
def stroke(points,name,material,radius=.00065):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=1;c.bevel_depth=radius;c.bevel_resolution=0;s=c.splines.new('POLY');s.points.add(len(points)-1)
    for p,co in zip(s.points,points):p.co=(*co,1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(material)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');return bpy.context.object
for idx,(cx,cz,width,height,front) in enumerate([(-.105,.76,.07,.13,True),(.10,.56,.07,.10,True),(.10,.86,.075,.12,False),(-.10,.59,.07,.1,False)]):
    verts=[garment_point(cx+(i/4-.5)*width,cz+(j/4-.5)*height,front) for j in range(5) for i in range(5)]
    faces=[(j*5+i,j*5+i+1,(j+1)*5+i+1,(j+1)*5+i) for j in range(4) for i in range(4)]
    if not front:faces=[tuple(reversed(f)) for f in faces]
    mesh=bpy.data.meshes.new('Repair');mesh.from_pydata(verts,[],faces);o=bpy.data.objects.new('Noen_Patch_%02d'%idx,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(patchmat);skin(o,'Hips')
    for side in range(4):
        for k in range(6):
            t=(k+.2)/6;t2=(k+.7)/6
            if side<2:coords=[(cx+(q-.5)*width,cz+(-.5 if side==0 else .5)*height) for q in [t,t2]]
            else:coords=[(cx+(-.5 if side==2 else .5)*width,cz+(q-.5)*height) for q in [t,t2]]
            o=stroke([garment_point(x,z,front) for x,z in coords],'Repair_stitch',threadmat);skin(o,'Hips')
# The old generated result is used only for the independent leather boots.
bpy.ops.object.select_all(action='DESELECT');bpy.ops.import_scene.gltf(filepath=os.environ['YUMING_SG_MODEL'])
boots=next(o for o in bpy.context.selected_objects if o.type=='MESH');boots.name='Noen_Boots';bpy.context.view_layer.objects.active=boots;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
lo=min(v.co.z for v in boots.data.vertices);hi=max(v.co.z for v in boots.data.vertices)
for v in boots.data.vertices:v.co=Vector((v.co.x*1.76/(hi-lo),v.co.y*1.76/(hi-lo),(v.co.z-lo)*1.76/(hi-lo)))
bm=bmesh.new();bm.from_mesh(boots.data);bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,.255),plane_no=(0,0,1),clear_outer=True);bm.to_mesh(boots.data);bm.free()
dec=boots.modifiers.new('Boot topology','DECIMATE');dec.ratio=2200/len(boots.data.polygons);bpy.ops.object.modifier_apply(modifier=dec.name);boots.data.validate()
bootmat=cloth_material('M_Noen_Leather',(.07,.037,.019));bootmat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.52;boots.data.materials.clear();boots.data.materials.append(bootmat)
for side,sign in [('Left',1),('Right',-1)]:
    indices=[v.index for v in boots.data.vertices if v.co.x*sign>0]
    for i in indices:
        co=boots.data.vertices[i].co;co.x+=(.02+max(0.,.255-co.z)*.1)*sign;co.y-=.045
    g=boots.vertex_groups.new(name='mixamorig:'+side+'Foot');leg=boots.vertex_groups.new(name='mixamorig:'+side+'Leg')
    for i in indices:
        blend=max(0.,min(1.,(boots.data.vertices[i].co.z-.10)/.11));g.add([i],1-blend,'REPLACE');leg.add([i],blend,'REPLACE')
boots.parent=rig;mod=boots.modifiers.new('Skin','ARMATURE');mod.object=rig
for vertex in boots.data.vertices:
    if vertex.co.z>.19:
        factor=(vertex.co.z-.19)/.065;centerx=.194 if vertex.co.x>0 else -.194;vertex.co.x=centerx+(vertex.co.x-centerx)*(1-.22*factor);vertex.co.z+=.025*factor;vertex.co.y=-.02+(vertex.co.y+.02)*(1+.30*factor)
for face in boots.data.polygons:face.use_smooth=True
# Rigid wooden splint and linen wraps follow the injured anatomical right forearm.
bone=rig.data.bones['mixamorig:RightForeArm'];axis=(bone.tail_local-bone.head_local).normalized();u=axis.cross(Vector((0,0,1))).normalized();v=axis.cross(u).normalized();center=(bone.head_local+bone.tail_local)/2
wood=cloth_material('M_Noen_Splint_Wood',(.22,.115,.045));wood.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.7
for sign in [-1,1]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=center+u*.052*sign);o=bpy.context.object;o.name='Noen_Wood_Splint';o.rotation_euler=axis.to_track_quat('Z','Y').to_euler();o.scale=(.035,.009,.24);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel=o.modifiers.new('Soft worn edges','BEVEL');bevel.width=.002;bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name);o.data.materials.append(wood)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);skin(o,'RightForeArm')
for t in [-.075,0,.075]:
    verts=[]
    for s in [-1,1]:
        for i in range(32):
            theta=i*math.tau/32;verts.append(center+axis*(t+s*.013)+u*math.cos(theta)*.06+v*math.sin(theta)*.055)
    faces=[(i,(i+1)%32,(i+1)%32+32,i+32) for i in range(32)];mesh=bpy.data.meshes.new('Linen');mesh.from_pydata(verts,[],faces);o=bpy.data.objects.new('Noen_Linen_Wrap',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(threadmat);skin(o,'RightForeArm')

scene=bpy.context.scene;cam=scene.camera
# Independent skirt bones prevent the coat from stretching between the legs.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
for side,sx in [('L',1),('R',-1)]:
    for panel,sy in [('Front',-1),('Back',1)]:
        upper=rig.data.edit_bones.new('Coat_'+panel+'_'+side+'_Upper');upper.head=(sx*.10,sy*.11,1.03);upper.tail=(sx*.13,sy*.12,.72);upper.parent=rig.data.edit_bones['mixamorig:Hips']
        lower=rig.data.edit_bones.new('Coat_'+panel+'_'+side+'_Lower');lower.head=upper.tail;lower.tail=(sx*.15,sy*.13,.43);lower.parent=upper;lower.use_connect=True
bpy.ops.object.mode_set(mode='OBJECT')
cg={b.name:coat.vertex_groups.new(name=b.name) for b in rig.data.bones if b.name.startswith('Coat_')}
for vert in coat.data.vertices:
    z=vert.co.z
    if z>=1.13 or abs(vert.co.x)>.24:continue
    blend=max(0.,min(1.,(1.13-z)/.12))
    for old in list(vert.groups):
        group=coat.vertex_groups[old.group]
        if group.name.startswith('mixamorig:'):group.add([vert.index],old.weight*(1-blend),'REPLACE')
    left=max(0.,min(1.,vert.co.x/.20+.5));back=max(0.,min(1.,vert.co.y/.20+.5));lower=max(0.,min(1.,(.82-z)/.20))
    for side,sw in [('L',left),('R',1-left)]:
        for panel,pw in [('Front',1-back),('Back',back)]:
            for level,lw in [('Upper',1-lower),('Lower',lower)]:cg['Coat_'+panel+'_'+side+'_'+level].add([vert.index],blend*sw*pw*lw,'REPLACE')
# Combine sewn repairs and transfer the finished coat weights to them.
repairs=[o for o in scene.objects if o.name.startswith('Noen_Patch_') or o.name.startswith('Repair_stitch')]
bpy.ops.object.select_all(action='DESELECT')
for o in repairs:o.select_set(True)
bpy.context.view_layer.objects.active=repairs[0];bpy.ops.object.join();repairs=bpy.context.object;repairs.name='Noen_Sewn_Repairs'
repairs.vertex_groups.clear()
for group in coat.vertex_groups:repairs.vertex_groups.new(name=group.name)
dt=repairs.modifiers.new('Follow garment','DATA_TRANSFER');dt.object=coat;dt.use_vert_data=True;dt.data_types_verts={'VGROUP_WEIGHTS'};dt.vert_mapping='POLYINTERP_NEAREST';bpy.ops.object.modifier_apply(modifier=dt.name)
for label,loc in [('tailored_front',(0,-4,1)),('tailored_side',(4,0,1)),('tailored_back',(0,4,1))]:
    cam.location=loc;cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/(label+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'))
print('TRIANGLES',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in scene.objects if o.type=='MESH'))
