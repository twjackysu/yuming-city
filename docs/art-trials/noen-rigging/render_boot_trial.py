import os
"""Render neutral orthographic views of an imported static reconstruction."""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector

source=Path(sys.argv[sys.argv.index('--')+1])
out=source.parent/'renders'; out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(source))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert meshes,'No imported meshes'
def bounds():
    coords=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
    return Vector(tuple(min(p[i] for p in coords) for i in range(3))),Vector(tuple(max(p[i] for p in coords) for i in range(3)))
bpy.context.view_layer.update(); lo,hi=bounds(); span=hi-lo
# TripoSR is Z-up, but raw trimesh GLB is interpreted as glTF Y-up.
# Correct only the presentation, retaining the raw export unchanged.
root=bpy.data.objects.new('Presentation transform',None); bpy.context.collection.objects.link(root)
for o in [o for o in list(bpy.context.scene.objects) if o!=root and o.parent is None]: o.parent=root
axis=2
if axis==1: root.rotation_euler.x=-math.pi/2
elif axis==0: root.rotation_euler.y=-math.pi/2
bpy.context.view_layer.update(); lo,hi=bounds(); height=(hi-lo).z
root.scale=(1.76/height,)*3; bpy.context.view_layer.update(); lo,hi=bounds()
root.location=-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)); bpy.context.view_layer.update()
for obj in meshes:
    for polygon in obj.data.polygons:
        polygon.use_smooth=True
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=1024; scene.render.resolution_y=1024; scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral world'); scene.world.use_nodes=True; scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.15,.15,.15,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
for loc,power,size in [((3,-4,5),700,4),((-3,1,3),450,3),((0,4,4),500,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc); lamp=bpy.context.object; lamp.data.energy=power; lamp.data.shape='DISK'; lamp.data.size=size
    lamp.rotation_euler=(Vector((0,0,.9))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(); camera=bpy.context.object; scene.camera=camera; camera.data.type='ORTHO'; camera.data.ortho_scale=2.2
for label,loc in [('view_00',(0,-4,1.0)),('view_90',(4,0,1.0)),('view_180',(0,4,1.0)),('view_270',(-4,0,1.0)),('three_quarter',(3,-4,1.7))]:
    camera.location=loc; camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(label+'.png')); bpy.ops.render.render(write_still=True)
# Save a viewable scene; this is not an accepted character deliverable.
bpy.ops.wm.save_as_mainfile(filepath=str(source.parent/'noen_trial_review.blend'))
(out/'presentation.json').write_text(json.dumps({'status':'presentation_only','raw_axis_rotated_for_preview':axis,'body_scale_target_m':1.76,'warning':'Names are camera azimuths, not verified anatomical front/back.'},indent=2),encoding='utf-8')
