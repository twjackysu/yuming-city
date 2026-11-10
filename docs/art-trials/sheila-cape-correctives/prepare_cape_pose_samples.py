import os
"""Build finite pose samples for a cape corrective study; no runtime cloth solver."""
import bpy,json,os,numpy as np
from pathlib import Path
from mathutils import Matrix
home=Path.home();root=Path(os.environ.get('YUMING_SHEILA_CAPE_WORK',str(home/'Documents/sheila-cloth-walk')));root.mkdir(parents=True,exist_ok=True)
base=Path(os.environ.get('YUMING_SHEILA_NATIVE_BLEND',str(home/'Documents/sheila-sword-v2/source.blend')));pattern=Path(os.environ.get('YUMING_SHEILA_CAPE_PATTERN',str(Path(__file__).resolve().parent/'inputs/cape_draped_pattern.json')));fbx=Path(os.environ.get('YUMING_SHEILA_FBX',str(home/'Documents/sheila-motion/walk_trial.fbx')))
bpy.ops.wm.open_mainfile(filepath=str(base));scene=bpy.context.scene;scene.render.fps=30;rig=bpy.data.objects['Sheila_Skeleton'];coat=bpy.data.objects['Sheila_Coat'];bpy.data.objects.remove(bpy.data.objects['Sheila_White_Short_Cape'],do_unlink=True);data=json.loads(pattern.read_text());assert len(data['vertices'])==1280 and np.isfinite(data['vertices']).all();mesh=bpy.data.meshes.new('Shoulder-draped short cape');mesh.from_pydata(data['vertices'],[],data['faces']);mesh.update();cape=bpy.data.objects.new('Sheila_White_Short_Cape',mesh);scene.collection.objects.link(cape);cape.parent=rig;mod=cape.modifiers.new('Skin','ARMATURE');mod.object=rig
for name in rig.data.bones.keys():cape.vertex_groups.new(name=name)
for i,weights in enumerate(data['weights']):
 assert len(weights)<=4 and abs(sum(weights.values())-1)<.0001
 for name,value in weights.items():cape.vertex_groups[name].add([i],value,'REPLACE')
columns=80;rows=16
white=bpy.data.materials.new('Sheila_Ivory_Wool');white.use_nodes=True;n=white.node_tree.nodes;l=white.node_tree.links;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=.96;geo=n.new('ShaderNodeNewGeometry');xyz=n.new('ShaderNodeSeparateXYZ');l.new(geo.outputs['Position'],xyz.inputs[0]);height=n.new('ShaderNodeMapRange');height.interpolation_type='SMOOTHERSTEP';height.inputs['From Min'].default_value=1.12; height.inputs['From Max'].default_value=1.27;l.new(xyz.outputs['Z'],height.inputs[0]);noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=70;noise.inputs['Detail'].default_value=3;mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.16,.12,.075,1);mix.inputs[2].default_value=(.63,.62,.58,1);l.new(height.outputs[0],mix.inputs[0]);l.new(mix.outputs[0],p.inputs['Base Color']);fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=1100;fine.inputs['Detail'].default_value=2;bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00025;bump.inputs['Strength'].default_value=.2;l.new(fine.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);mesh.materials.append(white)
# Authored hem coordinate avoids an incorrect world-height threshold under rig scale.
attribute=mesh.attributes.new(name='CapeHemT',type='FLOAT',domain='POINT')
for vertex in mesh.vertices:attribute.data[vertex.index].value=(vertex.index//columns)/(rows-1)
hem=n.new('ShaderNodeAttribute');hem.attribute_name='CapeHemT';fade=n.new('ShaderNodeMapRange');fade.interpolation_type='SMOOTHERSTEP';fade.inputs['From Min'].default_value=.64;fade.inputs['From Max'].default_value=1;fade.inputs['To Min'].default_value=1;fade.inputs['To Max'].default_value=0;l.new(hem.outputs['Fac'],fade.inputs[0]);l.new(fade.outputs[0],mix.inputs[0])
coords=n.new('ShaderNodeTexCoord');scale=n.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/.27;l.new(coords.outputs['Object'],scale.inputs[0])
scan=n.new('ShaderNodeTexImage');scan.image=bpy.data.images.load(str(home/'Tools/cc0-materials/poly_wool_herringbone/poly_wool_herringbone_diff_2k.png'));scan.image.pack();scan.projection='BOX';scan.projection_blend=.2;l.new(scale.outputs[0],scan.inputs['Vector']);gray=n.new('ShaderNodeRGBToBW');l.new(scan.outputs['Color'],gray.inputs[0]);detail=n.new('ShaderNodeMapRange');detail.inputs['From Min'].default_value=.03;detail.inputs['From Max'].default_value=.5;detail.inputs['To Min'].default_value=.80;detail.inputs['To Max'].default_value=1.08;l.new(gray.outputs[0],detail.inputs[0]);modulate=n.new('ShaderNodeMixRGB');modulate.blend_type='MULTIPLY';modulate.inputs[0].default_value=1;l.new(mix.outputs[0],modulate.inputs[1]);l.new(detail.outputs[0],modulate.inputs[2]);l.new(modulate.outputs[0],p.inputs['Base Color'])
scan=n.new('ShaderNodeTexImage');scan.image=bpy.data.images.load(str(home/'Tools/cc0-materials/poly_wool_herringbone/poly_wool_herringbone_disp_2k.png'));scan.image.colorspace_settings.name='Non-Color';scan.image.pack();scan.projection='BOX';scan.projection_blend=.2;l.new(scale.outputs[0],scan.inputs['Vector']);l.new(scan.outputs['Color'],bump.inputs['Height']);bump.inputs['Distance'].default_value=.00045;bump.inputs['Strength'].default_value=.45
for polygon in mesh.polygons:polygon.use_smooth=True

bone_names=[b.name for b in rig.data.bones];index={n:i for i,n in enumerate(bone_names)};weights=np.zeros((len(mesh.vertices),len(index)))
for i,values in enumerate(data['weights']):
 for n,w in values.items():weights[i,index[n]]=w
# Match the original native body's axes before sampling FBX poses.
old=set(scene.objects);bpy.ops.import_scene.fbx(filepath=str(fbx));added=set(scene.objects)-old;source=next(o for o in added if o.type=='ARMATURE');alignment=rig.matrix_world@source.matrix_world.inverted();correction={b.name:(alignment@source.matrix_world@source.data.bones[b.name].matrix_local).inverted()@(rig.matrix_world@b.bone.matrix_local) for b in rig.pose.bones}
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
poses=[];skins=[];world=[];rest=np.array(data['vertices'])
for frame in range(2,37):
 scene.frame_set(frame)
 for b in rig.pose.bones:b.matrix=rig.matrix_world.inverted()@alignment@source.matrix_world@source.pose.bones[b.name].matrix@correction[b.name];bpy.context.view_layer.update()
 poses.append({b.name:[list(b.rotation_quaternion),list(b.location),list(b.scale)] for b in rig.pose.bones});matrices=np.array([np.array(rig.pose.bones[n].matrix@rig.data.bones[n].matrix_local.inverted()) for n in bone_names]);skin=np.einsum('ij,njk->nik',np.array(rig.matrix_world),np.einsum('nb,bjk->njk',weights,matrices));skins.append(skin);world.append(np.einsum('nij,nj->ni',skin,np.c_[rest,np.ones(len(rest))])[:,:3])
for o in added:bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data_clear()
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(root/'cloth_source.blend'));mesh.calc_loop_triangles();np.savez_compressed(root/'cloth_simulation.npz',world_positions=np.array(world),skin_matrices=np.array(skins),weights=weights,triangles=np.array([t.vertices[:] for t in mesh.loop_triangles]));(root/'source_pose_basis.json').write_text(json.dumps(poses));print('CAPE_POSE_SAMPLES',len(poses),'no dynamic cloth simulation')
