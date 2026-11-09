import bpy,json,os
from pathlib import Path
from mathutils.kdtree import KDTree
home=Path.home();root=Path(os.environ.get('YUMING_SHEILA_ATLAS_WORK',str(home/'Documents/sheila-sword-delivery')));bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.render.fps=30
sets=[]
for path in [home/'Documents/sheila-motion/sheila_walk_preview.glb',root/'sheila_walk_preview.glb']:
 old=set(scene.objects);bpy.ops.import_scene.gltf(filepath=str(path));new=set(scene.objects)-old;sets.append([o for o in new if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers) and not ('Sword' in o.name and 'Badge' not in o.name)])
def points(objects,graph):return [o.evaluated_get(graph).matrix_world@v.co for o in objects for v in o.evaluated_get(graph).data.vertices]
def kd(points):
 t=KDTree(len(points))
 for i,p in enumerate(points):t.insert(p,i)
 t.balance();return t
maximum=0;records=[]
for frame in range(35):
 scene.frame_set(frame);graph=bpy.context.evaluated_depsgraph_get();a=points(sets[0],graph);b=points(sets[1],graph);at=kd(a);bt=kd(b);error=max(max(at.find(p)[2] for p in b),max(bt.find(p)[2] for p in a));maximum=max(maximum,error);records.append({'frame':frame,'maximum_bidirectional_vertex_distance_m':error})
report={'frames':35,'source_vertices':len(a),'atlas_vertices':len(b),'maximum_bidirectional_vertex_distance_m':maximum,'tolerance_m':.00001,'passed':maximum<.00001,'samples':records};(root/'posed_geometry_equivalence.json').write_text(json.dumps(report,indent=2));print({k:v for k,v in report.items() if k!='samples'});assert report['passed']

