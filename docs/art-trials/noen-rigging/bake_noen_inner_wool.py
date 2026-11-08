import os
import bpy,math
from pathlib import Path
from io_scene_gltf2.blender.com.material_helpers import create_settings_group
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_inner_wool.blend'));obj=bpy.data.objects['Noen_Inner_Wool'];rig=bpy.data.objects['Noen_Skeleton']
mat=obj.data.materials[0];obj.data.materials.clear();obj.data.materials.append(mat)
for f in obj.data.polygons:f.material_index=0
for uv in list(obj.data.uv_layers):obj.data.uv_layers.remove(uv)
obj.data.uv_layers.new(name='Atlas');bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.bake.use_selected_to_active=False;scene.render.bake.margin=12
n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');output=n.get('Material Output');maps={}
for kind in ['DIFFUSE','NORMAL','EMIT']:
 if kind=='EMIT':
  emit=n.new('ShaderNodeEmission');combine=n.new('ShaderNodeCombineXYZ');ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.035;ao.samples=16;l.new(ao.outputs['AO'],combine.inputs['X']);combine.inputs['Y'].default_value=.92;combine.inputs['Z'].default_value=0;l.new(combine.outputs[0],emit.inputs['Color']);l.new(emit.outputs[0],output.inputs['Surface'])
 image=bpy.data.images.new('noen_inner_'+kind.lower(),width=1024,height=1024,alpha=False)
 if kind!='DIFFUSE':image.colorspace_settings.name='Non-Color'
 node=n.new('ShaderNodeTexImage');node.image=image;n.active=node;bpy.ops.object.bake(type=kind,pass_filter={'COLOR'} if kind=='DIFFUSE' else {'COLOR','DIRECT','INDIRECT'});image.filepath_raw=str(root/'textures'/(image.name+'.png'));image.file_format='PNG';image.save();n.remove(node);maps[kind]=image
final=bpy.data.materials.new('Noen_Inner_Wool_PBR');final.use_nodes=True;n=final.node_tree.nodes;l=final.node_tree.links;p=n.get('Principled BSDF');t=n.new('ShaderNodeTexImage');t.image=maps['DIFFUSE'];l.new(t.outputs[0],p.inputs['Base Color']);t=n.new('ShaderNodeTexImage');t.image=maps['NORMAL'];normal=n.new('ShaderNodeNormalMap');l.new(t.outputs[0],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal']);t=n.new('ShaderNodeTexImage');t.image=maps['EMIT'];sep=n.new('ShaderNodeSeparateColor');l.new(t.outputs[0],sep.inputs[0]);l.new(sep.outputs['Green'],p.inputs['Roughness']);l.new(sep.outputs['Blue'],p.inputs['Metallic']);settings=n.new('ShaderNodeGroup');settings.node_tree=bpy.data.node_groups.get('glTF Material Output') or create_settings_group('glTF Material Output');l.new(sep.outputs['Red'],settings.inputs['Occlusion']);obj.data.materials.clear();obj.data.materials.append(final)
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for mesh in meshes:mesh.select_set(True)
rig.rotation_euler.z=math.pi;bpy.ops.export_scene.gltf(filepath=str(root/'noen_candidate_v2.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False);rig.rotation_euler.z=0
bpy.ops.wm.save_as_mainfile(filepath=str(root/'noen_candidate_v2.blend'));print('TRIANGLES',sum(sum(len(f.vertices)-2 for f in mesh.data.polygons) for mesh in meshes))
