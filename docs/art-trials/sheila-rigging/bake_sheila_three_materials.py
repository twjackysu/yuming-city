"""Consolidate the reviewed Noen study into three 2K PBR material atlases.
This is a texture/UV baking experiment, never an automatic art approval.
"""
import bpy,math,json,os,numpy as np
from pathlib import Path
from mathutils import Vector
from io_scene_gltf2.blender.com.material_helpers import create_settings_group
home=Path.home();root=Path(os.environ.get('YUMING_SHEILA_ATLAS_WORK',str(home/'Documents/sheila-sword-delivery')));root.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=os.environ.get('YUMING_SHEILA_SOURCE_BLEND',str(home/'Documents/sheila-sword-delivery/source.blend')));scene=bpy.context.scene;rig=bpy.data.objects['Sheila_Skeleton'];scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=4;scene.render.bake.margin_type='EXTEND'
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)];groups={'Skin':[],'Clothes':[],'Hair':[]}
for obj in meshes:
 group='Hair' if any(s in obj.name for s in ['ponytail01','eyebrow']) else 'Skin' if obj.name=='Sheila_Anatomy' or 'high-poly' in obj.name else 'Clothes';groups[group].append(obj)
 # Explicitly retain the source tangent basis while a new destination UV is active.
 old=obj.data.uv_layers.active or obj.data.uv_layers.new(name='SourceUV');oldname=old.name;old.name='SourceUV'
 for mat in obj.data.materials:
  n=mat.node_tree.nodes;l=mat.node_tree.links
  for node in list(n):
   if node.type=='UVMAP' and node.uv_map==oldname:node.uv_map='SourceUV'
   if node.type=='NORMAL_MAP':node.uv_map='SourceUV'
  uv=n.new('ShaderNodeUVMap');uv.uv_map='SourceUV'
  for node in list(n):
   if node.type=='TEX_IMAGE' and not node.inputs['Vector'].is_linked:l.new(uv.outputs[0],node.inputs['Vector'])
 obj.data.uv_layers.new(name='AtlasUV');obj.data.uv_layers.active=obj.data.uv_layers['AtlasUV'];obj.data.uv_layers['AtlasUV'].active_render=True
stats=[]
for group,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='Sheila_'+group
 # Multi-material source shaders remain on the joined mesh until all maps are baked.
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(80),island_margin=.002,area_weight=.3);bpy.ops.uv.pack_islands(rotate=True,margin_method='FRACTION',margin=.005);bpy.ops.object.mode_set(mode='OBJECT')
 materials=list(obj.data.materials);backups=[]
 for mat in materials:
  n=mat.node_tree.nodes;output=next(x for x in n if x.type=='OUTPUT_MATERIAL');p=next(x for x in n if x.type=='BSDF_PRINCIPLED');backups.append((mat,output,p,output.inputs['Surface'].links[0].from_socket))
 def source(socket):return socket.links[0].from_socket if socket.is_linked else None
 def bake(kind):
  image=bpy.data.images.new('Sheila_'+group+'_'+kind,width=2048,height=2048,alpha=kind=='BaseColor',float_buffer=False);image.colorspace_settings.name='sRGB' if kind=='BaseColor' else 'Non-Color';temporary=[]
  for mat,output,p,original in backups:
   n=mat.node_tree.nodes;l=mat.node_tree.links;target=n.new('ShaderNodeTexImage');target.image=image;n.active=target;created=[target]
   if kind=='Normal':l.new(original,output.inputs['Surface'])
   else:
    emission=n.new('ShaderNodeEmission');created.append(emission)
    if kind in ['BaseColor','Alpha']:
     socket=p.inputs['Base Color' if kind=='BaseColor' else 'Alpha'];s=source(socket)
     if s:l.new(s,emission.inputs['Color'])
     else:
      value=socket.default_value;emission.inputs['Color'].default_value=tuple(value) if kind=='BaseColor' else (value,value,value,1)
    else:
     combine=n.new('ShaderNodeCombineXYZ');created.append(combine);ao=next((x for x in n if x.type=='GROUP' and x.node_tree and x.node_tree.name.startswith('glTF Material Output')),None)
     for index,socket in enumerate([ao.inputs.get('Occlusion') if ao else None,p.inputs['Roughness'],p.inputs['Metallic']]):
      s=source(socket) if socket else None
      if s:l.new(s,combine.inputs[index])
      else:combine.inputs[index].default_value=1 if index==0 else socket.default_value
     l.new(combine.outputs[0],emission.inputs['Color'])
    l.new(emission.outputs[0],output.inputs['Surface'])
   temporary.append((mat,created))
  bpy.ops.object.bake(type='NORMAL' if kind=='Normal' else 'EMIT')
  for mat,created in temporary:
   for node in created:mat.node_tree.nodes.remove(node)
  for mat,output,p,original in backups:mat.node_tree.links.new(original,output.inputs['Surface'])
  return image
 base=bake('BaseColor');alpha=bake('Alpha');normal=bake('Normal');orm=bake('ORM')
 rgba=np.empty(len(base.pixels),dtype=np.float32);base.pixels.foreach_get(rgba);a=np.empty(len(alpha.pixels),dtype=np.float32);alpha.pixels.foreach_get(a);rgba.reshape(-1,4)[:,3]=a.reshape(-1,4)[:,0] if group in ['Skin','Hair'] else 1;base.pixels.foreach_set(rgba);base.update()
 for image,kind in [(base,'BaseColor'),(normal,'Normal'),(orm,'ORM')]:
  image.filepath_raw=str(root/('Sheila_'+group+'_'+kind+'.png'));image.file_format='PNG';image.save();image.pack()
 mat=bpy.data.materials.new('M_Sheila_'+group);mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
 tex=n.new('ShaderNodeTexImage');tex.image=base;l.new(tex.outputs['Color'],p.inputs['Base Color'])
 if group=='Hair':l.new(tex.outputs['Alpha'],p.inputs['Alpha'])
 if group=='Skin':
  cutoff=n.new('ShaderNodeMath');cutoff.operation='GREATER_THAN';cutoff.inputs[1].default_value=.35;l.new(tex.outputs['Alpha'],cutoff.inputs[0]);l.new(cutoff.outputs[0],p.inputs['Alpha'])
 tex=n.new('ShaderNodeTexImage');tex.image=normal;nm=n.new('ShaderNodeNormalMap');l.new(tex.outputs[0],nm.inputs['Color']);l.new(nm.outputs[0],p.inputs['Normal'])
 tex=n.new('ShaderNodeTexImage');tex.image=orm;sep=n.new('ShaderNodeSeparateColor');l.new(tex.outputs[0],sep.inputs[0]);l.new(sep.outputs['Green'],p.inputs['Roughness']);l.new(sep.outputs['Blue'],p.inputs['Metallic']);node=n.new('ShaderNodeGroup');node.node_tree=bpy.data.node_groups.get('glTF Material Output') or create_settings_group('glTF Material Output');l.new(sep.outputs['Red'],node.inputs['Occlusion'])
 if group=='Hair':p.inputs['Specular IOR Level'].default_value=.06;p.inputs['IOR'].default_value=1.45
 obj.data.materials.clear();obj.data.materials.append(mat)
 for poly in obj.data.polygons:poly.material_index=0
 obj.data.uv_layers.remove(obj.data.uv_layers['SourceUV']);obj.data.uv_layers.active=obj.data.uv_layers['AtlasUV'];obj.data.uv_layers['AtlasUV'].active_render=True
 stats.append({'group':group,'vertices':len(obj.data.vertices),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons)})
 print('BAKED_GROUP',group,flush=True)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in scene.objects:
 if obj.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in obj.modifiers):obj.select_set(True)
rig.rotation_euler.z=math.pi;bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False);rig.rotation_euler.z=0;bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'))
(root/'atlas_report.json').write_text(json.dumps({'groups':stats,'material_count':3,'textures':9,'texture_size':2048,'status':'visual_comparison_required'},indent=2))
scene.cycles.samples=32;scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100;cam=scene.camera
for name,pos,look,scale in [('portrait_front',(0,-3,1.64),(0,-.04,1.62),.46),('full_front',(0,-4,1),(0,0,.88),2.05),('portrait_threequarter',(1.8,-3,1.64),(0,-.04,1.62),.46)]:
 cam.location=pos;cam.rotation_euler=(Vector(look)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale;scene.render.filepath=str(root/(name+'.png'));bpy.ops.render.render(write_still=True)
