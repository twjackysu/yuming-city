import os
import bpy,json,math
from pathlib import Path
root=Path(os.environ.get('YUMING_NOEN_WORK',str(Path.home()/'Documents/noen-guarded-walk')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'));rig=bpy.data.objects['Noen_Skeleton'];report=[]
for obj in bpy.context.scene.objects:
 if obj.type!='MESH' or not any(word in obj.name.lower() for word in ['coat','tunic','sleeve']):continue
 changed=0
 for side in ['Left','Right']:
  groups={g.index for g in obj.vertex_groups if g.name.startswith('mixamorig:'+side+'Hand')};target=obj.vertex_groups.get('mixamorig:'+side+'ForeArm')
  if target is None:continue
  for vertex in obj.data.vertices:
   amount=sum(g.weight for g in vertex.groups if g.group in groups)
   if amount>1e-8:
    for index in groups:obj.vertex_groups[index].remove([vertex.index])
    target.add([vertex.index],amount,'ADD');changed+=1
 report.append({'mesh':obj.name,'changed_vertices':changed})
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.context.scene.objects:
 if obj.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in obj.modifiers):obj.select_set(True)
rig.rotation_euler.z=math.pi;bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False);rig.rotation_euler.z=0;bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'));(root/'cuff_repair.json').write_text(json.dumps(report,indent=2));print('CUFF_REPAIR',report)
