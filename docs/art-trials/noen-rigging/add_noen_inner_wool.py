import os
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_boots_v2.blend'));rig=bpy.data.objects['Noen_Skeleton'];body=bpy.data.objects['Noen_Anatomy']
shirt=body.copy();shirt.data=body.data.copy();bpy.context.collection.objects.link(shirt);shirt.name='Noen_Inner_Wool'
bm=bmesh.new();bm.from_mesh(shirt.data)
for co,normal,inner in [((0,0,1.22),(0,0,1),True),((0,0,1.445),(0,0,1),False),((-.14,0,0),(1,0,0),True),((.14,0,0),(1,0,0),False),((0,-.005,0),(0,1,0),False)]:
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=co,plane_no=normal,clear_inner=inner,clear_outer=not inner)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS');bm.normal_update()
for vertex in bm.verts:
 if vertex.co.z>1.40:vertex.co.z-=.018*max(0.,1-(vertex.co.x/.10)**2)*min(1.,(vertex.co.z-1.40)/.045)
 vertex.co+=vertex.normal*.0025
 vertex.co.y-=.008
bm.to_mesh(shirt.data);bm.free();shirt.data.validate()
if shirt.data.has_custom_normals:shirt.data.normals_split_custom_set([(0,0,0)]*len(shirt.data.loops))
mat=bpy.data.materials.new('Inner_Wool_Source');mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=.92
texcoord=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=650;noise.inputs['Detail'].default_value=2;l.new(texcoord.outputs['Object'],noise.inputs[0]);ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.038,.029,.021,1);ramp.color_ramp.elements[1].color=(.068,.052,.035,1);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color']);bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00035;bump.inputs['Strength'].default_value=.4;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);shirt.data.materials.clear();shirt.data.materials.append(mat)
for face in shirt.data.polygons:face.material_index=0;face.use_smooth=True

# Raised neckline follows the fitted front of the neck; reuse its skin weights.
bm=bmesh.new();bm.from_mesh(shirt.data)
points=[]
for vertex in bm.verts:
 expected=1.445-.018*max(0.,1-(vertex.co.x/.10)**2)
 if abs(vertex.co.z-expected)<.004 and any(edge.is_boundary for edge in vertex.link_edges):points.append(vertex.co.copy())
bm.free();points.sort(key=lambda co:co.x)
if len(points)>10:points=[points[round(i*(len(points)-1)/9)] for i in range(10)]
if len(points)>2:
 curve=bpy.data.curves.new('Wool neckline','CURVE');curve.dimensions='3D';curve.bevel_depth=.0018;curve.bevel_resolution=0;spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
 for point,co in zip(spline.points,points):point.co=(*co,1)
 collar=bpy.data.objects.new('Wool neckline',curve);bpy.context.collection.objects.link(collar);collar.data.materials.append(mat)
 bpy.ops.object.select_all(action='DESELECT');collar.select_set(True);bpy.context.view_layer.objects.active=collar;bpy.ops.object.convert(target='MESH');collar=bpy.context.object
 for group in shirt.vertex_groups:collar.vertex_groups.new(name=group.name)
 transfer=collar.modifiers.new('Neck skin weights','DATA_TRANSFER');transfer.object=shirt;transfer.use_vert_data=True;transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST';bpy.ops.object.modifier_apply(modifier=transfer.name)
 collar.parent=rig;arm=collar.modifiers.new('Skin','ARMATURE');arm.object=rig
 shirt.select_set(True);bpy.context.view_layer.objects.active=shirt;bpy.ops.object.join()

scene=bpy.context.scene;cam=scene.camera;cam.location=(0,-4,1.4);cam.rotation_euler=(Vector((0,0,1.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.8;scene.render.filepath=str(root/'inner_wool_review.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_inner_wool.blend'));print('SHIRT_TRIANGLES',sum(len(f.vertices)-2 for f in shirt.data.polygons))
