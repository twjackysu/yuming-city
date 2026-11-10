import os
import bpy,math,json
from pathlib import Path
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_SWORD_WORK',str(h/'Documents/sheila-sword-35cm')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'));s=bpy.context.scene;r=bpy.data.objects['Sheila_Skeleton'];mat=bpy.data.materials['M_Sheila_Clothes'];records=[]
for kind in ['BaseColor','Normal','ORM']:
 nodes=[n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.name.endswith('_'+kind)];assert len(nodes)==1;old=nodes[0].image;fresh=bpy.data.images.load(str(root/('Sheila_Clothes_'+kind+'.png')),check_existing=False);fresh.name='Revision_Sheila_Clothes_'+kind;fresh.colorspace_settings.name='sRGB' if kind=='BaseColor' else 'Non-Color';fresh.pack();nodes[0].image=fresh;records.append({'map':kind,'fresh_packed_image':fresh.name,'packed_bytes':len(fresh.packed_file.data)})
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'));bpy.ops.object.select_all(action='DESELECT');r.select_set(True)
for o in s.objects:
 if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==r for m in o.modifiers):o.select_set(True)
r.rotation_euler.z=math.pi;bpy.context.view_layer.update();bpy.ops.export_scene.gltf(filepath=str(root/'tailored_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_extras=True);(root/'packed_texture_refresh.json').write_text(json.dumps(records,indent=2));print(records)
