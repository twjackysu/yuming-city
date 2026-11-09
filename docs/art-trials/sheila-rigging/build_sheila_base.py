import os
import sys, math, json
from pathlib import Path
import bpy, bmesh, addon_utils
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
sys.path.insert(0,os.environ.get('YUMING_MPFB_SOURCE', str(Path.home()/'Tools'/'mpfb2'/'src')))
oldpath=bpy.utils.extension_path_user
bpy.utils.extension_path_user=lambda package,**kw: os.environ.get('YUMING_MPFB_USER', str(Path.home()/'Tools'/'mpfb-user')) if package=='mpfb' else oldpath(package,**kw)
addon_utils.enable('mpfb',default_set=True)
from mpfb.services.humanservice import HumanService
from mpfb.services.targetservice import TargetService
root=Path(os.environ.get('SHEILA_PRODUCTION', str(Path.home()/'Documents'/'sheila-production')));root.mkdir(exist_ok=True)
assets=Path(os.environ.get('YUMING_MPFB_ASSETS', str(Path.home()/'Tools'/'mpfb-user'/'data')))
macro=TargetService.get_default_macro_info_dict();macro.update(gender=0.,age=.50,muscle=.62,weight=.46,height=.58);macro['race']={'caucasian':.8,'asian':.15,'african':.05}
human=HumanService.create_human(macro_detail_dict=macro);human.name='Sheila_Anatomy'
HumanService.set_character_skin(str(assets/'skins/young_caucasian_female/young_caucasian_female.mhmat'),human,skin_type='MAKESKIN')
rig=HumanService.add_builtin_rig(human,'mixamo');rig.name='Sheila_Skeleton'
parts={}
for folder,name,kind in [('hair','ponytail01','Hair'),('eyebrows','eyebrow001','Eyebrows'),('eyes','high-poly','Eyes'),('clothes','male_casualsuit01','Clothes'),('clothes','punkduck_winter_coat','Clothes')]:
    path=assets/folder/name/(name+'.mhclo')
    parts[name]=HumanService.add_mhclo_asset(str(path),human,asset_type=kind,subdiv_levels=0)
coat=parts['punkduck_winter_coat'];coat.name='Sheila_Coat'
# Retain every garment as an independent mesh; original authored UVs and weights survive.
for o in [human,*parts.values()]:
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    arms=[m for m in o.modifiers if m.type=='ARMATURE']
    for m in arms:m.show_viewport=False
    bpy.ops.object.convert(target='MESH');o=bpy.context.object
    for m in list(o.modifiers):o.modifiers.remove(m)
    arm=o.modifiers.new('Skin','ARMATURE');arm.object=rig
    for p in o.data.polygons:p.use_smooth=True
# Inspect connected pieces before choosing tailoring edits.
bm=bmesh.new();bm.from_mesh(coat.data);remaining=set(bm.verts);pieces=[]
while remaining:
    stack=[remaining.pop()];component=[]
    while stack:
        v=stack.pop();component.append(v)
        for e in v.link_edges:
            v2=e.other_vert(v)
            if v2 in remaining:remaining.remove(v2);stack.append(v2)
    lo=[min(v.co[i] for v in component) for i in range(3)];hi=[max(v.co[i] for v in component) for i in range(3)]
    pieces.append({'vertices':len(component),'bounds':[lo,hi]})
bm.free();(root/'coat_parts.json').write_text(json.dumps(pieces,indent=2))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
for loc,power,size in [((3,-4,5),550,4),((-3,-1,3),300,3),((0,4,4),650,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.05
for label,loc in [('base_front',(0,-4,1)),('base_side',(4,0,1)),('base_back',(0,4,1))]:
    cam.location=loc;cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/(label+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_base.blend'))
print('TRIANGLES',[(o.name,sum(len(p.vertices)-2 for p in o.data.polygons)) for o in scene.objects if o.type=='MESH'])
