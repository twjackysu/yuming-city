import os
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(os.environ.get('YUMING_NOEN_WORK', str(Path.home()/'Documents'/'noen-tailored')))
bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'))
rig=bpy.data.objects['Noen_Skeleton'];scene=bpy.context.scene;cam=scene.camera
out=root/'pose_review';out.mkdir(exist_ok=True)
def rotate(name,angle):
 b=rig.pose.bones[name];m=b.matrix.copy();p=m.translation.copy();b.matrix=Matrix.Translation(p)@Matrix.Rotation(math.radians(angle),4,'X')@Matrix.Translation(-p)@m;bpy.context.view_layer.update()
def render(label,loc):
 cam.location=loc;cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
rotate('mixamorig:LeftUpLeg',30);rotate('mixamorig:LeftLeg',-50);rotate('mixamorig:RightUpLeg',-20)
for panel in ['Front','Back']:
 rotate('Coat_'+panel+'_L_Upper',27);rotate('Coat_'+panel+'_L_Lower',-15)
 rotate('Coat_'+panel+'_R_Upper',-18);rotate('Coat_'+panel+'_R_Lower',10)
render('stride_front',(0,-4,1));render('stride_side',(4,0,1))
report={'bones':len(rig.data.bones),'meshes':[{ 'name':o.name,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)} for o in scene.objects if o.type=='MESH'],'status':'study_requires_visual_acceptance'}
(out/'report.json').write_text(json.dumps(report,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(out/'stride.blend'))
