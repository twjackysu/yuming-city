import bpy,math,os,json,numpy as np
from pathlib import Path
from mathutils import Vector
root=Path.home()/'Documents/undertaker-wool-pbr';root.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(Path.home()/'Documents/undertaker-production/triposg/body_baked/undertaker_body.blend'));obj=bpy.data.objects['Undertaker_Robes'];mat=obj.data.materials[0];n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');original=p.inputs['Base Color'].links[0].from_socket;oldnormal=p.inputs['Normal'].links[0].from_socket
# Keep the original source atlas explicitly while baking into the efficient new chart layout.
obj.data.uv_layers['Atlas'].name='SourceAtlas'
uvnode=n.new('ShaderNodeUVMap');uvnode.uv_map='SourceAtlas'
for node in list(n):
 if node.bl_idname=='ShaderNodeTexImage':l.new(uvnode.outputs[0],node.inputs['Vector'])
 if node.bl_idname=='ShaderNodeNormalMap':node.uv_map='SourceAtlas'
data=np.load(root/'uv_xatlas.npz');newuv=obj.data.uv_layers.new(name='Atlas');newuv.data.foreach_set('uv',data['uv'][data['indices'].ravel()].astype(np.float32).ravel());obj.data.uv_layers.active=newuv;newuv.active_render=True
geo=n.new('ShaderNodeNewGeometry');split=n.new('ShaderNodeSeparateXYZ');l.new(geo.outputs['Position'],split.inputs[0])
def mathnode(op,a,b=None):
 node=n.new('ShaderNodeMath');node.operation=op
 for i,value in enumerate([a,b]):
  if value is None:continue
  if isinstance(value,(float,int)):node.inputs[i].default_value=value
  else:l.new(value,node.inputs[i])
 return node.outputs[0]
def mapped(value,a,b,c=0,d=1):
 node=n.new('ShaderNodeMapRange');node.interpolation_type='SMOOTHSTEP';node.inputs['From Min'].default_value=a;node.inputs['From Max'].default_value=b;node.inputs['To Min'].default_value=c;node.inputs['To Max'].default_value=d;l.new(value,node.inputs[0]);return node.outputs[0]
def blend(factor,a,b):
 node=n.new('ShaderNodeMixRGB');l.new(factor,node.inputs[0])
 for i,value in enumerate([a,b],1):
  if isinstance(value,tuple):node.inputs[i].default_value=(*value,1)
  else:l.new(value,node.inputs[i])
 return node.outputs[0]
macro=n.new('ShaderNodeTexNoise');macro.inputs['Scale'].default_value=5;macro.inputs['Detail'].default_value=4;l.new(geo.outputs['Position'],macro.inputs['Vector']);wool=blend(macro.outputs['Fac'],(.003,.0045,.006),(.008,.010,.012))
hem=mapped(split.outputs['Z'],.1,.65,1,0);ash=mathnode('MULTIPLY',hem,mapped(macro.outputs['Fac'],.45,.7));wool=blend(ash,wool,(.018,.018,.017))
# CC0 scanned wool, mapped in metres; box projection keeps its weave continuous across UV charts.
scanroot=Path.home()/'Tools/cc0-materials/poly_wool_herringbone';mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(1/.2700788549,1/.2700788549,1/.2757000029);l.new(geo.outputs['Position'],mapping.inputs[0]);scans={}
for kind in ['diff','disp','rough']:
 node=n.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(scanroot/('poly_wool_herringbone_'+kind+'_2k.png')));node.projection='BOX';node.projection_blend=.12;l.new(mapping.outputs[0],node.inputs['Vector'])
 if kind!='diff':node.image.colorspace_settings.name='Non-Color'
 scans[kind]=node.outputs['Color']
scaled=n.new('ShaderNodeVectorMath');scaled.operation='SCALE';scaled.inputs[3].default_value=5;l.new(scans['diff'],scaled.inputs[0]);woven=n.new('ShaderNodeMixRGB');woven.blend_type='MULTIPLY';woven.inputs[0].default_value=1;l.new(wool,woven.inputs[1]);l.new(scaled.outputs[0],woven.inputs[2]);wool=woven.outputs[0]
separate=n.new('ShaderNodeSeparateColor');l.new(original,separate.inputs[0]);warm=mathnode('SUBTRACT',separate.outputs['Red'],separate.outputs['Blue']);skin=mapped(warm,.025,.07);skin=mathnode('MULTIPLY',skin,mapped(mathnode('ABSOLUTE',split.outputs['X']),.34,.45));skin=mathnode('MULTIPLY',skin,mapped(split.outputs['Z'],.95,1.12));skin=mathnode('MULTIPLY',skin,mapped(split.outputs['Z'],1.40,1.55,1,0));color=blend(skin,wool,original)
boot=mathnode('MULTIPLY',mapped(split.outputs['Z'],.12,.25,1,0),mapped(mathnode('ABSOLUTE',split.outputs['X']),.09,.18));boot=mathnode('MULTIPLY',boot,mapped(split.outputs['Y'],.00,.15,1,0));leather=blend(macro.outputs['Fac'],(.006,.004,.003),(.025,.018,.012));color=blend(boot,color,leather);l.new(color,p.inputs['Base Color'])
rough=blend(hem,(.84,.84,.84),(.60,.60,.60));rough=blend(skin,rough,(.62,.62,.62));rough=blend(boot,rough,(.58,.58,.58));rough=blend(mathnode('MULTIPLY',mathnode('SUBTRACT',1,skin),mathnode('SUBTRACT',1,boot)),rough,scans['rough']);l.new(rough,p.inputs['Roughness']);p.inputs['Metallic'].default_value=0
coords=n.new('ShaderNodeVectorMath');coords.operation='MULTIPLY';coords.inputs[1].default_value=(1100,650,110);l.new(geo.outputs['Position'],coords.inputs[0]);fiber=n.new('ShaderNodeTexNoise');fiber.inputs['Scale'].default_value=1;fiber.inputs['Detail'].default_value=2;l.new(coords.outputs[0],fiber.inputs['Vector']);bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00075;bump.inputs['Strength'].default_value=.7;l.new(scans['disp'],bump.inputs['Height']);l.new(oldnormal,bump.inputs['Normal']);l.new(bump.outputs[0],p.inputs['Normal'])
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.bake.use_selected_to_active=False;scene.render.bake.margin=2;bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;baked={}
for kind in ['DIFFUSE','NORMAL','EMIT']:
 if kind=='EMIT':
  emit=n.new('ShaderNodeEmission');combine=n.new('ShaderNodeCombineXYZ');orm=next(link.from_node for link in p.inputs['Roughness'].links) if False else None
  # Preserve the original geometric AO; roughness now follows cloth, skin and leather.
  oldao=next(node for node in n if node.bl_idname=='ShaderNodeGroup' and node.node_tree.name.startswith('glTF Material Output')).inputs['Occlusion'].links[0].from_socket;l.new(oldao,combine.inputs['X']);l.new(rough,combine.inputs['Y']);combine.inputs['Z'].default_value=0;l.new(combine.outputs[0],emit.inputs[0]);l.new(emit.outputs[0],n.get('Material Output').inputs['Surface'])
 image=bpy.data.images.new('undertaker_wool_'+kind.lower(),width=2048,height=2048,alpha=False)
 if kind!='DIFFUSE':image.colorspace_settings.name='Non-Color'
 node=n.new('ShaderNodeTexImage');node.image=image;n.active=node;bpy.ops.object.bake(type=kind,pass_filter={'COLOR'} if kind=='DIFFUSE' else {'COLOR','DIRECT','INDIRECT'});image.filepath_raw=str(root/(image.name+'.png'));image.file_format='PNG';image.save();baked[kind]=image;n.remove(node)
l.new(p.outputs[0],n.get('Material Output').inputs['Surface']);texture=n.new('ShaderNodeTexImage');texture.image=baked['DIFFUSE'];l.new(texture.outputs['Color'],p.inputs['Base Color']);texture=n.new('ShaderNodeTexImage');texture.image=baked['NORMAL'];normal=n.new('ShaderNodeNormalMap');l.new(texture.outputs[0],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal']);texture=n.new('ShaderNodeTexImage');texture.image=baked['EMIT'];separate=n.new('ShaderNodeSeparateColor');l.new(texture.outputs[0],separate.inputs[0]);l.new(separate.outputs['Green'],p.inputs['Roughness']);l.new(separate.outputs['Blue'],p.inputs['Metallic']);group=next(node for node in n if node.bl_idname=='ShaderNodeGroup' and node.node_tree.name.startswith('glTF Material Output'));l.new(separate.outputs['Red'],group.inputs['Occlusion'])
obj.data.uv_layers.remove(obj.data.uv_layers['SourceAtlas'])
bpy.ops.export_scene.gltf(filepath=str(root/'undertaker_wool_body.glb'),export_format='GLB',use_selection=True);bpy.ops.wm.save_as_mainfile(filepath=str(root/'undertaker_wool_body.blend'))
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.world=bpy.data.worlds.new('Neutral');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
for location,power,size in [((3,-4,5),850,4),((-3,-1,3),450,3),((0,4,4),800,3)]:
 bpy.ops.object.light_add(type='AREA',location=location);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.size=size;lamp.rotation_euler=(Vector((0,0,1.3))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.7
for name,location in [('front',(0,-5,1.3)),('back',(0,5,1.3)),('cloth_closeup',(0,-5,1.8))]:
 cam.data.ortho_scale=.8 if name=='cloth_closeup' else 2.7;cam.location=location;cam.rotation_euler=(Vector((0,0,1.8 if name=='cloth_closeup' else 1.2))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/(name+'.png'));bpy.ops.render.render(write_still=True)
