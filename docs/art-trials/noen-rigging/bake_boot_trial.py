import os
import bpy,bmesh,math,json,numpy as np
from io_scene_gltf2.blender.com.material_helpers import create_settings_group
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('YUMING_BOOT_WORK', str(Path.home()/'Documents'/'noen-boots'/'seed81')));out=root/'game_ready';out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(root/'noen_triposg.glb'));high=next(o for o in bpy.context.scene.objects if o.type=='MESH');high.name='Boot_High';bpy.context.view_layer.objects.active=high;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
coords=np.empty(len(high.data.vertices)*3,dtype=np.float32);high.data.vertices.foreach_get('co',coords);coords=coords.reshape(-1,3);lo=coords.min(0);hi=coords.max(0);shaft=coords[coords[:,2]>lo[2]+(hi[2]-lo[2])*.85].mean(0)
coords[:,0]=(coords[:,0]-shaft[0])*.105/(hi[0]-lo[0]);coords[:,1]=(coords[:,1]-shaft[1])*.27/(hi[1]-lo[1]);coords[:,2]=(coords[:,2]-lo[2])*.31/(hi[2]-lo[2]);high.data.vertices.foreach_set('co',coords.ravel())
# Match a three-quarter reference camera; preserve UVs when the boot is later fitted.
direction=Vector((math.sin(math.radians(25))*math.cos(math.radians(11)),-math.cos(math.radians(25))*math.cos(math.radians(11)),math.sin(math.radians(11))))
right=Vector((math.cos(math.radians(25)),math.sin(math.radians(25)),0));up=direction.cross(right)
projected=np.stack((coords@np.array(right),coords@np.array(up)),axis=1);pmin=projected.min(0);pmax=projected.max(0)
image=bpy.data.images.load(str(root/'model_input.png'));pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
# Prepared input has a white margin. Bounds come from the original transparent cutout.
original=bpy.data.images.load(os.environ['YUMING_BOOT_FRONT_IMAGE']);pix=np.empty(len(original.pixels),dtype=np.float32);original.pixels.foreach_get(pix);a=pix.reshape(original.size[1],original.size[0],4)[:,:,3];ys,xs=np.nonzero(a>.8);umin,umax=xs.min()/original.size[0],xs.max()/original.size[0];vmin,vmax=ys.min()/original.size[1],ys.max()/original.size[1]
uvcoords=(projected-pmin)/(pmax-pmin);uvcoords[:,0]=umin+(umax-umin)*uvcoords[:,0];uvcoords[:,1]=vmin+(vmax-vmin)*uvcoords[:,1];indices=np.empty(len(high.data.loops),dtype=np.int32);high.data.loops.foreach_get('vertex_index',indices);uv=high.data.uv_layers.new(name='Reference');uv.data.foreach_set('uv',uvcoords[indices].astype(np.float32).ravel())
mat=bpy.data.materials.new('Boot_Leather_Source');mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=.72
tex=n.new('ShaderNodeTexImage');tex.image=original;uvnode=n.new('ShaderNodeUVMap');uvnode.uv_map='Reference';l.new(uvnode.outputs[0],tex.inputs['Vector'])
geo=n.new('ShaderNodeNewGeometry');dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';dot.inputs[1].default_value=direction;l.new(geo.outputs['Normal'],dot.inputs[0]);mask=n.new('ShaderNodeMapRange');mask.inputs['From Min'].default_value=.05;mask.inputs['From Max'].default_value=.45;l.new(dot.outputs['Value'],mask.inputs[0]);mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';l.new(mask.outputs[0],mul.inputs[0]);l.new(tex.outputs['Alpha'],mul.inputs[1]);mix=n.new('ShaderNodeMixRGB');l.new(mul.outputs[0],mix.inputs[0]);mix.inputs[1].default_value=(.043,.022,.012,1);l.new(tex.outputs['Color'],mix.inputs[2]);l.new(mix.outputs[0],p.inputs['Base Color'])

# Back projection uses the exact camera of the low-poly rear inspection render.
center=(coords.min(0)+coords.max(0))*.5;scale=1.76/.31;world=coords.copy();world[:,:2]-=center[:2];world*=scale;world[:,2]-=.88
backuv=np.stack((.5-world[:,0]/2.2,.5+(-.03*world[:,1]+.99955*world[:,2])/2.2),axis=1).astype(np.float32)
layer=high.data.uv_layers.new(name='RearReference');layer.data.foreach_set('uv',backuv[indices].ravel())
backimage=bpy.data.images.load(os.environ['YUMING_BOOT_REAR_IMAGE'])
backtex=n.new('ShaderNodeTexImage');backtex.image=backimage;backnode=n.new('ShaderNodeUVMap');backnode.uv_map='RearReference';l.new(backnode.outputs[0],backtex.inputs['Vector'])
backdot=n.new('ShaderNodeVectorMath');backdot.operation='DOT_PRODUCT';backdot.inputs[1].default_value=(0,1,0);l.new(geo.outputs['Normal'],backdot.inputs[0]);backmask=n.new('ShaderNodeMapRange');backmask.inputs['From Min'].default_value=.15;backmask.inputs['From Max'].default_value=.55;l.new(backdot.outputs['Value'],backmask.inputs[0])
grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=220;grain.inputs['Detail'].default_value=3;ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.025,.012,.006,1);ramp.color_ramp.elements[1].color=(.065,.033,.016,1);l.new(grain.outputs['Fac'],ramp.inputs[0]);backmix=n.new('ShaderNodeMixRGB');l.new(backmask.outputs[0],backmix.inputs[0]);l.new(ramp.outputs[0],backmix.inputs[1]);l.new(backtex.outputs['Color'],backmix.inputs[2]);l.new(backmix.outputs[0],mix.inputs[1])

noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=220;bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00008;bump.inputs['Strength'].default_value=.25;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);high.data.materials.clear();high.data.materials.append(mat)
for f in high.data.polygons:f.material_index=0;f.use_smooth=True
low=high.copy();low.data=high.data.copy();bpy.context.collection.objects.link(low);low.name='Boot_Low';bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low;dec=low.modifiers.new('Game topology','DECIMATE');dec.ratio=2000/len(low.data.polygons);bpy.ops.object.modifier_apply(modifier=dec.name);low.data.validate()
if low.data.has_custom_normals:low.data.normals_split_custom_set([(0,0,0)]*len(low.data.loops))
for face in low.data.polygons:face.use_smooth=True
for uv in list(low.data.uv_layers):low.data.uv_layers.remove(uv)
low.data.uv_layers.new(name='Atlas');bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
lowmat=bpy.data.materials.new('Boot_Baked_PBR');lowmat.use_nodes=True;low.data.materials.clear();low.data.materials.append(lowmat)
for f in low.data.polygons:f.material_index=0
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.008;scene.render.bake.max_ray_distance=.02;scene.render.bake.margin=12
high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
baked={}
for kind in ['DIFFUSE','NORMAL','EMIT']:
 if kind=='EMIT':
  emit=n.new('ShaderNodeEmission');combine=n.new('ShaderNodeCombineXYZ');ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.025;ao.samples=16;l.new(ao.outputs['AO'],combine.inputs['X']);combine.inputs['Y'].default_value=.72;combine.inputs['Z'].default_value=0;l.new(combine.outputs[0],emit.inputs['Color']);l.new(emit.outputs[0],n.get('Material Output').inputs['Surface'])
 im=bpy.data.images.new('boot_'+kind.lower(),width=2048,height=2048,alpha=False)
 if kind!='DIFFUSE':im.colorspace_settings.name='Non-Color'
 node=lowmat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;lowmat.node_tree.nodes.active=node
 bpy.ops.object.bake(type=kind,pass_filter={'COLOR'} if kind=='DIFFUSE' else {'COLOR','DIRECT','INDIRECT'})
 im.filepath_raw=str(out/(im.name+'.png'));im.file_format='PNG';im.save();lowmat.node_tree.nodes.remove(node);baked[kind]=im;print('BAKED',kind,flush=True)
n=lowmat.node_tree.nodes;l=lowmat.node_tree.links;p=n.get('Principled BSDF');t=n.new('ShaderNodeTexImage');t.image=baked['DIFFUSE'];l.new(t.outputs[0],p.inputs['Base Color']);t=n.new('ShaderNodeTexImage');t.image=baked['NORMAL'];nm=n.new('ShaderNodeNormalMap');l.new(t.outputs[0],nm.inputs['Color']);l.new(nm.outputs[0],p.inputs['Normal']);t=n.new('ShaderNodeTexImage');t.image=baked['EMIT'];sep=n.new('ShaderNodeSeparateColor');l.new(t.outputs[0],sep.inputs[0]);l.new(sep.outputs['Green'],p.inputs['Roughness']);l.new(sep.outputs['Blue'],p.inputs['Metallic'])
group=create_settings_group('glTF Material Output');node=n.new('ShaderNodeGroup');node.node_tree=group;l.new(sep.outputs['Red'],node.inputs['Occlusion'])
bpy.data.objects.remove(high,do_unlink=True);scene.render.bake.use_selected_to_active=False;bpy.ops.object.select_all(action='DESELECT');low.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/'boot_candidate.glb'),export_format='GLB',use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'boot_candidate.blend'))
(out/'report.json').write_text(json.dumps({'triangles':sum(len(f.vertices)-2 for f in low.data.polygons),'source_triangles':2059936,'status':'pending_material_and_fit_review'},indent=2))
