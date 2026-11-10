import os
"""Convert pose-sampled cloth into compact, skinned corrective shapes."""
import bpy,json,numpy as np,math
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
from mathutils.bvhtree import BVHTree
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_CAPE_WORK',str(h/'Documents/sheila-cloth-walk')));data=np.load(root/'cloth_simulation.npz');world=data['world_positions'].copy();skins=data['skin_matrices'];triangles=data['triangles'];poses=json.loads((root/'source_pose_basis.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(root/'cloth_source.blend'));s=bpy.context.scene;r=bpy.data.objects['Sheila_Skeleton'];c=bpy.data.objects['Sheila_White_Short_Cape'];coat=bpy.data.objects['Sheila_Coat']
rest=np.array([v.co[:] for v in c.data.vertices]);world=np.einsum('fnij,nj->fni',skins,np.c_[rest,np.ones(len(rest))])[:,:,:3]
def pose(i):
 for b in r.pose.bones:
  q,l,sc=poses[i][b.name];b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion(q);b.location=l;b.scale=sc
 bpy.context.view_layer.update()
def collider():
 dg=bpy.context.evaluated_depsgraph_get();o=coat.evaluated_get(dg);o.data.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[t.vertices[:] for t in o.data.loop_triangles],all_triangles=True)
# Make the simulated cycle periodic before solving the final surface constraints.
seam=world[-1]-world[0];before=world.copy();world-=np.linspace(0,1,len(world))[:,None,None]*seam
reports=[];trees=[]
for frame in range(35):
 pose(frame);tree=collider();trees.append(tree);maxstep=0
 for iteration in range(16):
  points=world[frame];samples=np.r_[points,points[triangles].mean(axis=1)];delta=np.zeros_like(points);magnitude=np.zeros(len(points));count=0;minimum=1
  for i,p in enumerate(samples):
   indices=[i] if i<len(points) else triangles[i-len(points)];row=sum(int(v)//80 for v in indices)/len(indices)
   if row<5:
    center=r.matrix_world@r.pose.bones['mixamorig:Spine2'].head;center.z-=.06;direction=Vector(p)-center;length=direction.length
    if length<1e-6:continue
    direction.normalize();hit,n,idx,distance=tree.ray_cast(center+direction*.85,-direction,.85)
    if hit is None:continue
    depth=(hit-center).dot(direction)+.006-length
    if depth<=.0001:continue
    d=np.array(direction)*depth;signed=.006-depth
   else:
    hit,n,idx,distance=tree.find_nearest(Vector(p));signed=(Vector(p)-hit).dot(n)
    if signed>=.006 or distance>.045:continue
    d=np.array(n)*(.006-signed)
   minimum=min(minimum,signed);count+=1
   for v in indices:
    size=np.linalg.norm(d)
    if size>magnitude[v]:magnitude[v]=size;delta[v]=d
  maxstep=max(maxstep,float(magnitude.max()));world[frame]+=delta*1.02
  if count==0:break
 reports.append({'frame':frame,'remaining_constraints_last_iteration':count,'minimum_signed_distance_last_iteration_m':minimum,'maximum_step_m':maxstep,'total_projection_displacement_max_m':float(np.linalg.norm(world[frame]-(before[frame]-seam*frame/34),axis=1).max())})
 print('PROJECTED',frame,reports[-1],flush=True)
world[-1]=world[0]
local=np.einsum('fnij,fnj->fni',np.linalg.inv(skins),np.concatenate([world,np.ones((*world.shape[:2],1))],axis=2))[:,:,:3];mean=local[:-1].mean(axis=0);flat=(local-mean).reshape(35,-1);u,sv,vt=np.linalg.svd(flat,full_matrices=False);selected=None
for rank in [8,12,16,24,34]:
 coeff=u[:,:rank]*sv[:rank];reconstructed=mean+(coeff@vt[:rank]).reshape(local.shape);err=np.linalg.norm(reconstructed-local,axis=2)
 if err.max()<.0015:selected=rank;break
assert selected is not None
# Scale each shape so its animation coefficient stays in [-1, 1].
scale=np.maximum(np.max(np.abs(coeff),axis=0),1e-8);shapes=vt[:rank].reshape(rank,len(mean),3)*scale[:,None,None];values=coeff/scale;values[-1]=values[0]
for v,p in zip(c.data.vertices,mean):v.co=p
c.data.update();c.shape_key_add(name='Basis')
for i,delta in enumerate(shapes):
 key=c.shape_key_add(name='CapeCloth_%02d'%i);key.slider_min=-1;key.slider_max=1
 for v,p in zip(key.data,mean+delta):v.co=p
attr=c.data.attributes.new(name='CapeVertex',type='FLOAT',domain='POINT')
for a in attr.data:a.value=1
for b in r.pose.bones:b.matrix_basis=Matrix.Identity(4)
np.savez_compressed(root/'cloth_shapes.npz',values=values,local_reference=local,world_reference=world,skin_matrices=skins,triangles=triangles)
report={'samples':35,'source_vertices':len(mean),'corrective_shapes':rank,'pca_maximum_vertex_error_m':float(err.max()),'pca_rms_vertex_error_m':float(np.sqrt((err*err).mean())),'maximum_input_loop_drift_m':float(np.linalg.norm(seam,axis=1).max()),'maximum_projection_displacement_m':max(r['total_projection_displacement_max_m'] for r in reports),'projection_samples':reports,'status':'pending_engine_and_visual_checks'};(root/'cloth_shape_report.json').write_text(json.dumps(report,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(root/'morph_source.blend'));print('CLOTH_SHAPES',rank,'ERROR_MAX_M',float(err.max()),flush=True)
# Review the actual corrected pose before atlas work.
pose(17)
for i,value in enumerate(values[17]):c.data.shape_keys.key_blocks['CapeCloth_%02d'%i].value=value
s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=1200;s.render.resolution_y=1200;s.render.resolution_percentage=100;cam=s.camera;cam.location=(2.6,-4,1.5);cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.05;s.render.filepath=str(root/'cape_hybrid_pose17.png');bpy.ops.render.render(write_still=True)
