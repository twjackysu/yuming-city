import os
import bpy,math
from pathlib import Path
root=Path(os.environ.get('SHEILA_PRODUCTION', str(Path.home()/'Documents'/'sheila-production')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_baked.blend'))
for obj in bpy.context.scene.objects:
 if obj.type!='MESH' or not any(x in obj.name for x in ['ponytail01','eyebrow','high-poly']):continue
 for mat in obj.data.materials:
  n=mat.node_tree.nodes;l=mat.node_tree.links;p=next(x for x in n if x.type=='BSDF_PRINCIPLED')
  im=bpy.data.images.new(obj.name+'_neutral_normal',width=4,height=4,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels[:]=[.5,.5,1,1]*16;im.pack();tex=n.new('ShaderNodeTexImage');tex.image=im;nm=n.new('ShaderNodeNormalMap');l.new(tex.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs[0],p.inputs['Normal'])
  rough=.18 if 'high-poly' in obj.name else .65
  im=bpy.data.images.new(obj.name+'_orm',width=4,height=4,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels[:]=[1,rough,0,1]*16;im.pack();tex=n.new('ShaderNodeTexImage');tex.image=im;sep=n.new('ShaderNodeSeparateColor');l.new(tex.outputs[0],sep.inputs[0]);l.new(sep.outputs['Green'],p.inputs['Roughness']);l.new(sep.outputs['Blue'],p.inputs['Metallic']);node=n.new('ShaderNodeGroup');node.node_tree=bpy.data.node_groups['glTF Material Output'];l.new(sep.outputs['Red'],node.inputs['Occlusion'])
rig=bpy.data.objects['Sheila_Skeleton'];bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.select_set(True)
rig.rotation_euler.z=math.pi
bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
rig.rotation_euler.z=0;bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_baked.blend'))
