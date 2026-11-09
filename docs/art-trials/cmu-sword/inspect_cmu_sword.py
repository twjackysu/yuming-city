import os
import bpy,sys,json,math
from pathlib import Path
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).resolve().parent));from acclaim_motion import AcclaimMotion
root=Path(os.environ.get('CMU_MOCAP', str(Path.home()/'Tools\\cmu-mocap')));motion=AcclaimMotion(root/'02.asf',root/'02_07.amc');conversion=Matrix.Rotation(math.pi/2,3,'X');metrics=[]
for index in range(len(motion.frames)):
 start,end,rotation=motion.pose(index);point=conversion@(end['rhand']-end['root']);metrics.append({'frame':index+1,'right_hand':list(point)})
for i in range(1,len(metrics)):metrics[i]['speed']=(Vector(metrics[i]['right_hand'])-Vector(metrics[i-1]['right_hand'])).length*120
candidates=sorted(metrics[1:],key=lambda row:-row['speed']);peaks=[]
for row in candidates:
 if all(abs(row['frame']-p['frame'])>100 for p in peaks):peaks.append(row)
 if len(peaks)==10:break
out=Path(os.environ.get('CMU_SWORD_WORK', str(Path.home()/'Documents\\cmu-sword-study')));out.mkdir(exist_ok=True);(out/'source_metrics.json').write_text(json.dumps({'frames':len(metrics),'fps':120,'metres_per_unit':motion.metres_per_unit,'speed_peaks':peaks},indent=2));print('MOTION',len(metrics),'PEAKS',[(p['frame'],round(p['speed'],2)) for p in peaks])
