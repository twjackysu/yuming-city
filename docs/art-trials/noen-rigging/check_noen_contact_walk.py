import bpy,json,os
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(os.environ.get('YUMING_NOEN_WORK',str(Path.home()/'Documents/noen-surface-refinement')));bpy.ops.wm.open_mainfile(filepath=str(root/'animated_roundtrip/walk_review.blend'));scene=bpy.context.scene;coat=bpy.data.objects['Noen_Coat'];wood=next(o for o in scene.objects if o.type=='MESH' and 'Wood_Splint' in o.name);wrap=next(o for o in scene.objects if o.type=='MESH' and 'Linen_Wrap' in o.name);body=bpy.data.objects['Noen_Anatomy'];rig=next(m.object for m in body.modifiers if m.type=='ARMATURE');groups={g.index for g in body.vertex_groups if g.name.startswith('mixamorig:LeftHand')};hand_indices=[v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.5];assert len(hand_indices)>100
sign=1 if (rig.matrix_world@rig.data.bones['mixamorig:LeftHand'].head_local).x>0 else -1
def evaluated_points(obj,graph):
 evaluated=obj.evaluated_get(graph);return [evaluated.matrix_world@v.co for v in evaluated.data.vertices]
def tree(obj,points):return BVHTree.FromPolygons(points,[p.vertices[:] for p in obj.data.polygons],all_triangles=False)
front_panel_indices=[p.index for p in coat.data.polygons if all(abs(coat.data.vertices[i].co.x)<.24 and coat.data.vertices[i].co.z<1.1 for i in p.vertices)];assert len(front_panel_indices)>100
records=[]
for frame in range(2,37):
 scene.frame_set(frame);graph=bpy.context.evaluated_depsgraph_get();cp=evaluated_points(coat,graph);wp=evaluated_points(wood,graph);bp=evaluated_points(wrap,graph);body_points=evaluated_points(body,graph);hp=[body_points[i] for i in hand_indices];ct=tree(coat,cp);panel_tree=BVHTree.FromPolygons(cp,[coat.data.polygons[i].vertices[:] for i in front_panel_indices],all_triangles=True);wt=tree(wood,wp);gap=max(min(ct.find_nearest(p)[3],wt.find_nearest(p)[3]) for p in bp);distance=min(panel_tree.find_nearest(p)[3] for p in hp);minz=min(p.z for p in hp);maxz=max(p.z for p in hp);panel_vertices={i for pi in front_panel_indices for i in coat.data.polygons[pi].vertices};out=max(sign*cp[i].x for i in panel_vertices if minz-.025<=cp[i].z<=maxz+.025);clearance=min(sign*p.x for p in hp)-out;records.append({'frame':frame,'maximum_band_surface_gap_m':gap,'minimum_hand_front_panel_distance_m':distance,'left_hand_lateral_clearance_m':clearance})
report={'frames':35,'hand_vertices':len(hand_indices),'maximum_band_surface_gap_m':max(r['maximum_band_surface_gap_m'] for r in records),'minimum_hand_front_panel_distance_m':min(r['minimum_hand_front_panel_distance_m'] for r in records),'minimum_lateral_clearance_m':min(r['left_hand_lateral_clearance_m'] for r in records),'samples':records};report['passed']=report['maximum_band_surface_gap_m']<.004 and report['minimum_hand_front_panel_distance_m']>.005 and report['minimum_lateral_clearance_m']>.005;(root/'contact_pose_check.json').write_text(json.dumps(report,indent=2));print({k:v for k,v in report.items() if k!='samples'});assert report['passed']


