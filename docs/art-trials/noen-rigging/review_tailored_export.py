import os
import bpy, math, json
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')));out=root/'roundtrip';out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'tailored_candidate.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
for loc,power,size in [((-3,4,5),550,4),((3,1,3),300,3),((0,-4,4),650,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.05
def render(label,loc=(0,4,1),look=(0,0,.88),scale=2.05):
    cam.location=loc;cam.rotation_euler=(Vector(look)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale;scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
def reset():
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
def rotate(name,axis,angle):
    b=rig.pose.bones['mixamorig:'+name];m=rig.matrix_world@b.matrix;p=m.translation.copy()
    b.matrix=rig.matrix_world.inverted()@Matrix.Translation(p)@Matrix.Rotation(math.radians(angle),4,axis)@Matrix.Translation(-p)@m
    bpy.context.view_layer.update()
render('rest_front');render('rest_back',(0,-4,1));render('rest_portrait',(0,4,1.6),(0,0,1.6),.55)

print('ROUNDTRIP_REST_RENDERED')
