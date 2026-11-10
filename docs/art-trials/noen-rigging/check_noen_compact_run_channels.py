import os
from pathlib import Path
import struct,json,numpy as np
h=Path.home();root=Path(os.environ.get('YUMING_NOEN_WORK',str(h/'Documents/noen-compact-run')));base=Path(os.environ.get('YUMING_NOEN_BASE_GLB',str(Path(__file__).resolve().parents[3]/'art-inbox/studies/noen/noen_walk_candidate.glb')));new=root/'noen_idle_walk_run_candidate.glb'
def load(p):
 b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];return json.loads(b[20:20+n]),b[28+n:]
def tracks(p):
 g,b=load(p);a=next(x for x in g['animations'] if x['name']=='run_loop');result={}
 for ch in a['channels']:
  sampler=a['samplers'][ch['sampler']];ac=g['accessors'][sampler['output']];v=g['bufferViews'][ac['bufferView']];count={'VEC3':3,'VEC4':4}[ac['type']];array=np.frombuffer(b,dtype='<f4',count=ac['count']*count,offset=v.get('byteOffset',0)+ac.get('byteOffset',0)).reshape(-1,count);result[(g['nodes'][ch['target']['node']]['name'],ch['target']['path'])]=array
 return result
x,y=tracks(base),tracks(new);changed={}
for k,a in x.items():
 b=y[k];err=float(np.max(np.abs(np.repeat(a,len(b),axis=0)-b))) if len(a)==1 else float(np.max(np.abs(a-b))) if a.shape==b.shape else None
 if err is None or err>1e-5:changed['/'.join(k)]={'before_keys':len(a),'after_keys':len(b),'maximum_component_delta':err}
report={'changed_tracks':changed,'all_changes_are_left_arm_or_hand':all(k.startswith(('mixamorig:LeftArm/','mixamorig:LeftForeArm/','mixamorig:LeftHand')) for k in changed),'tolerance':1e-5};(root/'animation_preservation.json').write_text(json.dumps(report,indent=2));print(report);assert report['all_changes_are_left_arm_or_hand']
