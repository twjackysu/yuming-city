import os
import bpy,json,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_CAPE_WORK',str(h/'Documents/sheila-cloth-walk')));bpy.ops.wm.open_mainfile(filepath=str(root/'cloth_source.blend'));s=bpy.context.scene;s.render.fps=30;native=bpy.data.objects['Sheila_Skeleton'];coat=bpy.data.objects['Sheila_Coat'];native_coat=[coat.matrix_world@v.co for v in coat.data.vertices]
def kd(points):
 t=KDTree(len(points))
 for i,p in enumerate(points):t.insert(p,i)
 t.balance();return t
def frame(r):
 def p(n):return r.matrix_world@r.data.bones['mixamorig:'+n].head_local
 origin=p('Hips');x=(p('LeftUpLeg')-p('RightUpLeg')).normalized();z=p('Head')-origin;z=(z-x*z.dot(x)).normalized();y=z.cross(x).normalized();m=Matrix((x,y,z)).transposed().to_4x4();m.translation=origin;return m
old=set(s.objects);bpy.ops.import_scene.gltf(filepath=str(root/'sheila_walk_normal_fitted.glb'));new=set(s.objects)-old;r=next(o for o in new if o.type=='ARMATURE');clothes=next(o for o in new if o.type=='MESH' and o.name.startswith('Sheila_Clothes'));cape=next(o for o in new if o.type=='MESH' and o.name.startswith('Sheila_Cape'));alignment=frame(native)@frame(r).inverted();tree=kd(native_coat);members={v.index for v in clothes.data.vertices if tree.find(alignment@clothes.matrix_world@v.co)[2]<.0001};clothes.data.calc_loop_triangles();ct=[t.vertices[:] for t in clothes.data.loop_triangles if all(v in members for v in t.vertices)];assert len(ct)==6242,len(ct);cape.data.calc_loop_triangles();tris=[t.vertices[:] for t in cape.data.loop_triangles];edges=lambda triangles:list({tuple(sorted((int(t[i]),int(t[(i+1)%3])))) for t in triangles for i in range(3)});ce=edges(tris);be=edges(ct);data=np.load(root/'cloth_shapes.npz')
# Blender's glTF importer sets slider minima from initial weights; expand for the full signed PCA curve.
for key in list(cape.data.shape_keys.key_blocks)[1:]:key.slider_min=-1.1;key.slider_max=1.1

with bpy.data.libraries.load(str(root/'morph_source.blend'),link=False) as (src,dst):dst.meshes=['Shoulder-draped short cape']
basis=[native.matrix_world@v.co for v in dst.meshes[0].vertices];mapping=kd(basis);lookup=[mapping.find(alignment@cape.matrix_world@v.co)[1] for v in cape.data.vertices];maximum_error=0;samples=[]
for sample in range(69):
 time=sample*.5;s.frame_set(int(time),subframe=time-int(time));dg=bpy.context.evaluated_depsgraph_get();a=clothes.evaluated_get(dg);b=cape.evaluated_get(dg);cv=[a.matrix_world@v.co for v in a.data.vertices];pv=[b.matrix_world@v.co for v in b.data.vertices];bodytree=BVHTree.FromPolygons(cv,ct,all_triangles=True);capetree=BVHTree.FromPolygons(pv,tris,all_triangles=True);hits=[]
 for label,verts,pairs,bvh in [('cape_edge',pv,ce,bodytree),('coat_edge',cv,be,capetree)]:
  for i,j in pairs:
   d=verts[j]-verts[i];length=d.length
   if length<1e-8:continue
   hit,n,index,dist=bvh.ray_cast(verts[i]+d.normalized()*1e-6,d.normalized(),length-2e-6)
   if hit is not None:hits.append({'kind':label,'a':i,'b':j,'target_triangle':index})
 error=None
 if sample%2==0:
  points=np.array([(alignment@p)[:] for p in pv]);expected=data['world_reference'][sample//2][lookup];error=float(np.linalg.norm(points-expected,axis=1).max());maximum_error=max(maximum_error,error)
 samples.append({'time_s':time/30,'intersecting_edges':len(hits),'maximum_position_error_m':error,'examples':hits[:4]});print('GLB_CLOTH',sample,'intersections',len(hits),'error',error,flush=True)
report={'samples':69,'fps_sampling':60,'coat_triangles':len(ct),'cape_triangles':len(tris),'maximum_intersecting_edges':max(x['intersecting_edges'] for x in samples),'maximum_cape_position_error_m':maximum_error,'passed':maximum_error<.002 and all(x['intersecting_edges']==0 for x in samples),'results':samples};(root/'exported_cape_gate.json').write_text(json.dumps(report,indent=2));print('EXPORTED_CAPE_GATE',report['passed']);assert report['passed']
