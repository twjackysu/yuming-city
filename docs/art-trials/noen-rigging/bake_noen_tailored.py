import os
import bpy,math,json
from io_scene_gltf2.blender.com.material_helpers import create_settings_group
from pathlib import Path
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')))
bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_projected.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.bake.margin=8
folder=root/'textures';folder.mkdir(exist_ok=True)
# Join repeated accessories while preserving their weights and materials.
for prefix in ['Noen_Wood_Splint','Noen_Linen_Wrap']:
 objs=[o for o in scene.objects if o.type=='MESH' and o.name.startswith(prefix)]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join()
meshes=[o for o in scene.objects if o.type=='MESH']
def bake_image(obj,name,kind):
 size=2048 if obj.name in ['Noen_Anatomy','Noen_Coat'] else 1024
 image=bpy.data.images.new(name,width=size,height=size,alpha=False)
 if kind!='DIFFUSE':image.colorspace_settings.name='Non-Color'
 temps=[]
 for mat in obj.data.materials:
  node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.nodes.active=node;temps.append((mat,node))
 bpy.ops.object.bake(type=kind,pass_filter={'COLOR'} if kind=='DIFFUSE' else {'COLOR','DIRECT','INDIRECT'})
 image.filepath_raw=str(folder/(name+'.png'));image.file_format='PNG';image.save()
 for mat,node in temps:mat.node_tree.nodes.remove(node)
 return image
stats=[]
for obj in meshes:
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 alpha=any(s in obj.name for s in ['short02','eyebrow','high-poly'])
 # Cutout assets retain their authored alpha and UVs.
 if alpha:
  stats.append({'mesh':obj.name,'mode':'authored_cutout'});continue
 old=obj.data.uv_layers.active
 if old:
  for mat in obj.data.materials:
   n=mat.node_tree.nodes;l=mat.node_tree.links;uv=n.new('ShaderNodeUVMap');uv.uv_map=old.name
   for tex in [x for x in n if x.type=='TEX_IMAGE' and not x.inputs['Vector'].is_linked]:l.new(uv.outputs[0],tex.inputs['Vector'])
 if obj.name=='Noen_Anatomy':
  mat=obj.data.materials[0];n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');base_node=next(x for x in n if x.type=='TEX_IMAGE')
  faceuv=obj.data.uv_layers.new(name='FaceProjection')
  for face in obj.data.polygons:
      for li in face.loop_indices:
          co=obj.data.vertices[obj.data.loops[li].vertex_index].co;faceuv.data[li].uv=(.5+co.x/.55,.5+(co.z-1.6)/.55)
  uvnode=n.new('ShaderNodeUVMap');uvnode.uv_map='FaceProjection'
  portrait=n.new('ShaderNodeTexImage');portrait.image=bpy.data.images.load(os.environ['YUMING_NOEN_FACE_IMAGE']);portrait.extension='EXTEND';l.new(uvnode.outputs[0],portrait.inputs['Vector'])
  geo=n.new('ShaderNodeNewGeometry');dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';dot.inputs[1].default_value=(0,-1,0);l.new(geo.outputs['Normal'],dot.inputs[0])
  mask=n.new('ShaderNodeMapRange');mask.inputs['From Min'].default_value=.15;mask.inputs['From Max'].default_value=.65;l.new(dot.outputs['Value'],mask.inputs[0])
  xyz=n.new('ShaderNodeSeparateXYZ');l.new(geo.outputs['Position'],xyz.inputs[0]);height=n.new('ShaderNodeMapRange');height.inputs['From Min'].default_value=1.42;height.inputs['From Max'].default_value=1.49;l.new(xyz.outputs['Z'],height.inputs[0])
  mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';l.new(mask.outputs[0],mul.inputs[0]);l.new(height.outputs[0],mul.inputs[1])
  mix=n.new('ShaderNodeMixRGB');l.new(mul.outputs[0],mix.inputs[0]);l.new(base_node.outputs['Color'],mix.inputs[1]);l.new(portrait.outputs['Color'],mix.inputs[2]);l.new(mix.outputs[0],p.inputs['Base Color'])
 atlas=obj.data.uv_layers.new(name='BakedAtlas');obj.data.uv_layers.active_index=len(obj.data.uv_layers)-1;atlas.active_render=True
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
 key=obj.name.lower();base=bake_image(obj,key+'_basecolor','DIFFUSE');normal=bake_image(obj,key+'_normal','NORMAL')
 backups=[]
 for mat in obj.data.materials:
  n=mat.node_tree.nodes;l=mat.node_tree.links;out=next(x for x in n if x.type=='OUTPUT_MATERIAL');p=next(x for x in n if x.type=='BSDF_PRINCIPLED');previous=out.inputs['Surface'].links[0].from_socket
  emit=n.new('ShaderNodeEmission');combine=n.new('ShaderNodeCombineXYZ');ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.05;ao.samples=8;l.new(ao.outputs['AO'],combine.inputs['X']);combine.inputs['Y'].default_value=p.inputs['Roughness'].default_value;combine.inputs['Z'].default_value=p.inputs['Metallic'].default_value;l.new(combine.outputs[0],emit.inputs['Color']);l.new(emit.outputs[0],out.inputs['Surface']);backups.append((mat,out,previous,emit,combine,ao))
 orm=bake_image(obj,key+'_orm','EMIT')
 for mat,out,previous,*temp in backups:
  mat.node_tree.links.new(previous,out.inputs['Surface'])
  for n in temp:mat.node_tree.nodes.remove(n)
 mat=bpy.data.materials.new(key+'_PBR');mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
 tex=n.new('ShaderNodeTexImage');tex.image=base;l.new(tex.outputs['Color'],p.inputs['Base Color'])
 tex=n.new('ShaderNodeTexImage');tex.image=normal;nm=n.new('ShaderNodeNormalMap');l.new(tex.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs[0],p.inputs['Normal'])
 tex=n.new('ShaderNodeTexImage');tex.image=orm;sep=n.new('ShaderNodeSeparateColor');l.new(tex.outputs[0],sep.inputs[0]);l.new(sep.outputs['Green'],p.inputs['Roughness']);l.new(sep.outputs['Blue'],p.inputs['Metallic'])
 group=bpy.data.node_groups.get('glTF Material Output')
 if not group:group=create_settings_group('glTF Material Output')
 node=n.new('ShaderNodeGroup');node.node_tree=group;l.new(sep.outputs['Red'],node.inputs['Occlusion'])
 obj.data.materials.clear();obj.data.materials.append(mat)
 for polygon in obj.data.polygons:polygon.material_index=0
 for uv in list(obj.data.uv_layers):
  if uv.name!='BakedAtlas':obj.data.uv_layers.remove(uv)
 stats.append({'mesh':obj.name,'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons)})
 print('BAKED',obj.name,flush=True)
rig=bpy.data.objects['Noen_Skeleton'];bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in meshes:o.select_set(True)
rig.rotation_euler.z=math.pi
bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
rig.rotation_euler.z=0
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_baked.blend'))
(root/'bake_report.json').write_text(json.dumps(stats,indent=2))
