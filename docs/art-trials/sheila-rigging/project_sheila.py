import os
import bpy,os,math
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('SHEILA_PRODUCTION', str(Path.home()/'Documents'/'sheila-production')));bpy.ops.wm.open_mainfile(filepath=str(root/'sheila_assembly.blend'))
front=bpy.data.images.load(os.environ['SHEILA_FRONT_IMAGE']);rear=bpy.data.images.load(os.environ['SHEILA_REAR_IMAGE']);graph=bpy.context.evaluated_depsgraph_get()
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH' or any(name in obj.name for name in ['ponytail','eyebrow','high-poly','Boot_']):continue
 for name,sign in [('FrontProjection',1),('RearProjection',-1)]:
  uv=obj.data.uv_layers.new(name=name);confidence=obj.data.attributes.new(name=name+'Visible',type='FLOAT',domain='CORNER');direction=Vector((0,sign,-.03)).normalized();coordinates={};visibility={}
  for vertex in obj.data.vertices:
   point=obj.matrix_world@vertex.co;u=.5+sign*point.x*.99/2.1;v=.5+(.03*sign*point.y+.99955*(point.z-.88))/2.1
   if sign<0:u*=.979;v=1-(1-v)*.979
   coordinates[vertex.index]=(u,v);hit,position,_,_,surface,_=bpy.context.scene.ray_cast(graph,point-direction*4,direction,distance=8);visibility[vertex.index]=1. if hit and surface==obj else 0.
  for loop in obj.data.loops:uv.data[loop.index].uv=coordinates[loop.vertex_index];confidence.data[loop.index].value=visibility[loop.vertex_index]
 for slot in obj.material_slots:
  mat=slot.material.copy();slot.material=mat;n=mat.node_tree.nodes;l=mat.node_tree.links;p=next(node for node in n if node.type=='BSDF_PRINCIPLED');base=p.inputs['Base Color'];original=base.links[0].from_socket if base.is_linked else None;constant=tuple(base.default_value)
  textures=[];visible=[]
  for name,image in [('FrontProjection',front),('RearProjection',rear)]:
   uvnode=n.new('ShaderNodeUVMap');uvnode.uv_map=name;tex=n.new('ShaderNodeTexImage');tex.image=image;l.new(uvnode.outputs[0],tex.inputs['Vector']);textures.append(tex);attribute=n.new('ShaderNodeAttribute');attribute.attribute_name=name+'Visible';visible.append(attribute)
  geo=n.new('ShaderNodeNewGeometry');sep=n.new('ShaderNodeSeparateXYZ');l.new(geo.outputs['Normal'],sep.inputs[0]);facing=n.new('ShaderNodeMapRange');facing.inputs['From Min'].default_value=-.4;facing.inputs['From Max'].default_value=.4;l.new(sep.outputs['Y'],facing.inputs[0]);color=n.new('ShaderNodeMixRGB');l.new(facing.outputs[0],color.inputs[0]);l.new(textures[1 if ('Sword' in obj.name) else 0].outputs['Color'],color.inputs[1]);l.new(textures[1].outputs['Color'],color.inputs[2]);mask=n.new('ShaderNodeMixRGB');l.new(facing.outputs[0],mask.inputs[0]);l.new(visible[0].outputs['Fac'],mask.inputs[1]);l.new(visible[1].outputs['Fac'],mask.inputs[2]);absolute=n.new('ShaderNodeMath');absolute.operation='ABSOLUTE';l.new(sep.outputs['Y'],absolute.inputs[0]);range_node=n.new('ShaderNodeMapRange');range_node.inputs['From Min'].default_value=.03;range_node.inputs['From Max'].default_value=.3;l.new(absolute.outputs[0],range_node.inputs[0]);product=n.new('ShaderNodeMath');product.operation='MULTIPLY';l.new(range_node.outputs[0],product.inputs[0]);l.new(mask.outputs[0],product.inputs[1]);final=n.new('ShaderNodeMixRGB');l.new(product.outputs[0],final.inputs[0]);l.new(original,final.inputs[1]) if original else setattr(final.inputs[1],'default_value',constant);l.new(color.outputs[0],final.inputs[2]);l.new(final.outputs[0],base)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'sheila_projected.blend'))
