import os
import bpy,math,os
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'))
front=bpy.data.images.load(os.environ['YUMING_NOEN_FRONT_MATERIAL'])
rear=bpy.data.images.load(os.environ['YUMING_NOEN_REAR_MATERIAL'])
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH' or obj.name.startswith('Noen_Anatomy'):continue
 for name,sign in [('FrontMaterial',1),('RearMaterial',-1)]:
  uv=obj.data.uv_layers.new(name=name)
  for face in obj.data.polygons:
   for li in face.loop_indices:
    co=obj.matrix_world@obj.data.vertices[obj.data.loops[li].vertex_index].co;u=.5+sign*co.x*.99/2.05;v=.5+(co.z-.88)/2.05
    if sign<0:u*=1200/1254;v=1-(1-v)*1200/1254
    uv.data[li].uv=(u,v)
 mat=bpy.data.materials.new(obj.name+'_Projection');mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=.85 if 'Coat' in obj.name or 'Trousers' in obj.name else .65
 tex=[]
 for name,img in [('FrontMaterial',front),('RearMaterial',rear)]:
  uv=n.new('ShaderNodeUVMap');uv.uv_map=name;t=n.new('ShaderNodeTexImage');t.image=img;l.new(uv.outputs[0],t.inputs['Vector']);tex.append(t)
 geo=n.new('ShaderNodeNewGeometry');sep=n.new('ShaderNodeSeparateXYZ');l.new(geo.outputs['Normal'],sep.inputs[0]);mapn=n.new('ShaderNodeMapRange');mapn.inputs['From Min'].default_value=-.4;mapn.inputs['From Max'].default_value=.4;l.new(sep.outputs['Y'],mapn.inputs[0]);mix=n.new('ShaderNodeMixRGB');l.new(mapn.outputs[0],mix.inputs[0]);l.new(tex[0].outputs['Color'],mix.inputs[1]);l.new(tex[1].outputs['Color'],mix.inputs[2])
 absolute=n.new('ShaderNodeMath');absolute.operation='ABSOLUTE';l.new(sep.outputs['Y'],absolute.inputs[0]);confidence=n.new('ShaderNodeMapRange');confidence.inputs['From Min'].default_value=.12;confidence.inputs['From Max'].default_value=.50;l.new(absolute.outputs[0],confidence.inputs[0]);final=n.new('ShaderNodeMixRGB');l.new(confidence.outputs[0],final.inputs[0]);final.inputs[1].default_value=(.035,.037,.040,1) if 'Coat' in obj.name else (.055,.035,.02,1);l.new(mix.outputs[0],final.inputs[2]);l.new(final.outputs[0],p.inputs['Base Color'])
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=650;bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00018;bump.inputs['Strength'].default_value=.25;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 obj.data.materials.clear();obj.data.materials.append(mat)
 for f in obj.data.polygons:f.material_index=0

# Separate leather belt and iron buckle from the projected cloth material.
import bmesh
coat=bpy.data.objects['Noen_Coat'];bm=bmesh.new();bm.from_mesh(coat.data);bm.faces.ensure_lookup_table();remaining=set(bm.verts)
for name,color,metal in [('Belt_Leather',(.035,.018,.009,1),0),('Buckle_Iron',(.055,.05,.045,1),.8)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color;p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.65;coat.data.materials.append(m)
while remaining:
 stack=[remaining.pop()];component=[]
 while stack:
  vertex=stack.pop();component.append(vertex)
  for edge in vertex.link_edges:
   other=edge.other_vert(vertex)
   if other in remaining:remaining.remove(other);stack.append(other)
 if len(component)<500:
  index=1 if len(component)>100 and len(component)<220 else 2
  for vertex in component:
   for face in vertex.link_faces:face.material_index=index
bm.to_mesh(coat.data);bm.free()
hair=bpy.data.objects['Noen_Anatomy.short02']
for material in hair.data.materials:
 n=material.node_tree.nodes;l=material.node_tree.links;p=n.get('Principled BSDF');socket=p.inputs['Base Color'].links[0].from_socket;mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(.35,.28,.23,1);l.new(socket,mix.inputs[1]);l.new(mix.outputs[0],p.inputs['Base Color']);p.inputs['Roughness'].default_value=.7

scene=bpy.context.scene;cam=scene.camera
for label,loc in [('projected_front',(0,-4,1)),('projected_back',(0,4,1)),('projected_threequarter',(2.6,-4,1.5))]:
 cam.location=loc;cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/(label+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_projected.blend'))
