import bpy,math,json,os
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(os.environ.get('YUMING_NOEN_WORK',str(Path.home()/'Documents/noen-surface-refinement')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'));rig=bpy.data.objects['Noen_Skeleton'];coat=bpy.data.objects['Noen_Coat'];wrap=next(o for o in bpy.context.scene.objects if o.type=='MESH' and 'Linen_Wrap' in o.name);wood=next(o for o in bpy.context.scene.objects if o.type=='MESH' and 'Wood_Splint' in o.name)
def tree(obj):
 obj.data.calc_loop_triangles();return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.loop_triangles],all_triangles=True)
coat_tree=tree(coat);wood_tree=tree(wood);bone=rig.data.bones['mixamorig:RightForeArm'];axis=(bone.tail_local-bone.head_local).normalized();center=(bone.head_local+bone.tail_local)/2;locked=set();radii=[]
for vertex in wrap.data.vertices:
 point=wrap.matrix_world@vertex.co;axial=center+axis*(point-center).dot(axis);direction=(point-axial).normalized();hits=[]
 for kind,bvh in [('coat',coat_tree),('wood',wood_tree)]:
  location,normal,index,distance=bvh.ray_cast(axial,direction,.12)
  if location is not None:
   hits.append((distance,location,kind,index))
   if kind=='coat':locked.update(coat.data.loop_triangles[index].vertices)
 assert hits,'Band ray missed sleeve and splint'
 distance,location,kind,index=max(hits,key=lambda h:h[0]);vertex.co=wrap.matrix_world.inverted()@(location+direction*.0015);radii.append(distance)
# Contact faces share the rigid forearm transform, so cloth cannot separate from a band.
for index in locked:
 for group in coat.vertex_groups:group.remove([index])
 coat.vertex_groups['mixamorig:RightForeArm'].add([index],1,'REPLACE')
wrap.data.update();bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.context.scene.objects:
 if obj.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in obj.modifiers):obj.select_set(True)
rig.rotation_euler.z=math.pi;bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False);rig.rotation_euler.z=0;bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'));(root/'band_fit.json').write_text(json.dumps({'band_vertices':len(wrap.data.vertices),'locked_sleeve_vertices':len(locked),'radial_clearance_m':.0015,'surface_radius_min_m':min(radii),'surface_radius_max_m':max(radii)},indent=2))

