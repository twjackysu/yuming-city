import bpy,os,json,math
from pathlib import Path
from mathutils import Vector
home=Path.home();root=Path(os.environ.get('YUMING_NOEN_WORK',str(home/'Documents/noen-surface-refinement')));root.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.environ.get('YUMING_NOEN_SOURCE_BLEND',str(home/'Documents/noen-guarded-walk/tailored_noen.blend')));scene=bpy.context.scene;body=bpy.data.objects['Noen_Anatomy']
with bpy.data.libraries.load(os.environ.get('YUMING_NOEN_SKIN_DRIVER',str(home/'Documents/noen-tailored/tailored_projected.blend')),link=False) as (src,dst):dst.objects=['Noen_Anatomy']
source=dst.objects[0];assert len(source.data.vertices)==len(body.data.vertices) and len(source.data.loops)==len(body.data.loops);assert all((a.co-b.co).length<1e-6 for a,b in zip(source.data.vertices,body.data.vertices))
uv=body.data.uv_layers.new(name='SkinSourceUV')
for a,b in zip(uv.data,source.data.uv_layers.active.data):a.uv=b.uv
body.data.uv_layers.active=body.data.uv_layers['BakedAtlas'];body.data.uv_layers['BakedAtlas'].active_render=True
bpy.data.objects.remove(source,do_unlink=True)
mat=body.data.materials[0];n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');old=p.inputs['Base Color'].links[0].from_socket;old.node.interpolation='Closest'
for node in list(n):
 if node.type=='TEX_IMAGE' and not node.inputs['Vector'].is_linked:
  nodeuv=n.new('ShaderNodeUVMap');nodeuv.uv_map='BakedAtlas';l.new(nodeuv.outputs[0],node.inputs['Vector'])
skin=n.new('ShaderNodeTexImage');skin.image=bpy.data.images.load(str(home/'Tools/mpfb-user/data/skins/young_caucasian_male/young_lightskinned_male_diffuse.png'));nodeuv=n.new('ShaderNodeUVMap');nodeuv.uv_map='SkinSourceUV';l.new(nodeuv.outputs[0],skin.inputs['Vector'])
geo=n.new('ShaderNodeNewGeometry');sep=n.new('ShaderNodeSeparateXYZ');l.new(geo.outputs['Position'],sep.inputs[0]);height=n.new('ShaderNodeMapRange');height.interpolation_type='SMOOTHERSTEP';height.inputs['From Min'].default_value=1.485;height.inputs['From Max'].default_value=1.520;l.new(sep.outputs['Z'],height.inputs[0]);mix=n.new('ShaderNodeMixRGB');l.new(height.outputs[0],mix.inputs[0]);l.new(skin.outputs[0],mix.inputs[1]);l.new(old,mix.inputs[2]);l.new(mix.outputs[0],p.inputs['Base Color'])
# Only RGB albedo is rebaked; existing tangent normal and ORM maps remain unchanged.
image=bpy.data.images.new('Noen_Skin_Continuous_Albedo',width=2048,height=2048,alpha=False);target=n.new('ShaderNodeTexImage');target.image=image;n.active=target
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=8
bpy.ops.object.bake(type='DIFFUSE',pass_filter={'COLOR'});image.filepath_raw=str(root/'noen_skin_basecolor.png');image.file_format='PNG';image.save();image.pack()
l.new(target.outputs[0],p.inputs['Base Color'])
# Remove UV and nodes that only belonged to the temporary baking graph.
for node in [skin,nodeuv,geo,sep,height,mix]:n.remove(node)
body.data.uv_layers.remove(body.data.uv_layers['SkinSourceUV']);body.data.uv_layers.active=body.data.uv_layers['BakedAtlas']
hair=next(o for o in scene.objects if o.type=='MESH' and 'short02' in o.name);mat=hair.data.materials[0];n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');normal=next(node for node in n if node.bl_idname=='ShaderNodeNormalMap');texture=n.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(home/'Tools/mpfb-user/data/hair/short02/short02_normal.png'));texture.image.colorspace_settings.name='Non-Color';texture.image.pack();l.new(texture.outputs[0],normal.inputs['Color']);normal.inputs['Strength'].default_value=.65
p.inputs['Specular IOR Level'].default_value=.06
for link in list(p.inputs['Roughness'].links):l.remove(link)
p.inputs['Roughness'].default_value=.88
# Keep the existing cutout texture, authored UVs and full hair silhouette.
rig=bpy.data.objects['Noen_Skeleton'];bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in scene.objects:
 if obj.type=='MESH' and any(mod.type=='ARMATURE' and mod.object==rig for mod in obj.modifiers):obj.select_set(True)
rig.rotation_euler.z=math.pi;bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False);rig.rotation_euler.z=0
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'))
scene.cycles.samples=32;scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100;cam=scene.camera
for name,pos in [('portrait_front',(0,-3,1.64)),('portrait_threequarter',(1.8,-3,1.64)),('portrait_back',(0,3,1.64))]:
 cam.location=pos;cam.rotation_euler=(Vector((0,-.04,1.62))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.46;scene.render.filepath=str(root/(name+'.png'));bpy.ops.render.render(write_still=True)
(root/'surface_report.json').write_text(json.dumps({'triangles':sum(len(p.vertices)-2 for o in scene.objects if o.type=='MESH' for p in o.data.polygons),'hair_normal_source':'MakeHuman short02_normal.png (CC0)','hair_normal_strength':.65,'hair_specular_ior_level':.06,'hair_roughness':.88,'neck_blend_world_z':[1.485,1.520],'skin_source_uv_verified_identical_topology':True,'status':'work_in_progress_not_final_art'},indent=2))

