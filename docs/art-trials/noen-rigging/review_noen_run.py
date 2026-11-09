import os
import bpy,json,math,os
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-run')));out=root/'animated_roundtrip';out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(root/'tailored_candidate.glb'));target=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==target for m in o.modifiers)]
bpy.ops.import_scene.fbx(filepath=str(root/'run_trial.fbx'));source=next(o for o in bpy.context.selected_objects if o.type=='ARMATURE');source.hide_render=True
corrections={b.name:(source.matrix_world@source.data.bones[b.name].matrix_local).inverted()@(target.matrix_world@b.bone.matrix_local) for b in target.pose.bones}
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
for loc,power,size in [((-3,4,5),550,4),((3,1,3),300,3),((0,-4,4),650,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2,4,1.3));cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.05;cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler()
report=[]
for frame in range(2,22):
 scene.frame_set(frame)
 for bone in target.pose.bones:
  bone.matrix=target.matrix_world.inverted()@source.matrix_world@source.pose.bones[bone.name].matrix@corrections[bone.name];bpy.context.view_layer.update()
 graph=bpy.context.evaluated_depsgraph_get();low=min((obj.evaluated_get(graph).matrix_world@v.co).z for obj in meshes for v in obj.evaluated_get(graph).data.vertices)
 hips=target.matrix_world@target.pose.bones['mixamorig:Hips'].head
 report.append({'frame':frame,'lowest_z':low,'hips':list(hips)})
 for bone in target.pose.bones:
  bone.rotation_mode='QUATERNION';bone.keyframe_insert('rotation_quaternion',frame=frame);bone.keyframe_insert('location',frame=frame)
 if frame in [2,10,19,27,36] and not os.environ.get("YUMING_SKIP_RENDERS"):scene.render.filepath=str(out/('walk_%02d.png'%frame));bpy.ops.render.render(write_still=True)
(out/'report.json').write_text(json.dumps(report,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(out/'walk_review.blend'))
print('MIN_GROUND',min(r['lowest_z'] for r in report),'MAX_GROUND',max(r['lowest_z'] for r in report))

scene.frame_start=2;scene.frame_end=21;target.animation_data.action.name='run_loop';bpy.ops.object.select_all(action='DESELECT');target.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=target
source.animation_data_clear();bpy.data.objects.remove(source,do_unlink=True)
bpy.ops.export_scene.gltf(filepath=str(root/'noen_run_preview.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_frame_range=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='run_loop')
