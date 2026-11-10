import os
from pathlib import Path
import json,struct,numpy as np
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_SWORD_WORK',str(h/'Documents/sheila-sword-35cm')))
def load(p):
 raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];return json.loads(raw[20:20+n]),raw[28+n:]
def read(g,b,i):
 a=g['accessors'][i];c={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dtype=np.dtype({5126:'<f4',5121:'<u1',5123:'<u2',5125:'<u4'}[a['componentType']]);out=np.zeros((a['count'],c),dtype=dtype)
 if 'bufferView' in a:
  v=g['bufferViews'][a['bufferView']];off=v.get('byteOffset',0)+a.get('byteOffset',0);out[:]=np.ndarray((a['count'],c),dtype=dtype,buffer=b,offset=off,strides=(v.get('byteStride',c*dtype.itemsize),dtype.itemsize))
 if 'sparse' in a:
  sp=a['sparse'];ix=sp['indices'];v=g['bufferViews'][ix['bufferView']];indices=np.frombuffer(b,dtype={5121:'<u1',5123:'<u2',5125:'<u4'}[ix['componentType']],count=sp['count'],offset=v.get('byteOffset',0)+ix.get('byteOffset',0));vv=sp['values'];v=g['bufferViews'][vv['bufferView']];out[indices]=np.frombuffer(b,dtype=dtype,count=sp['count']*c,offset=v.get('byteOffset',0)+vv.get('byteOffset',0)).reshape(-1,c)
 return out
old,ob=load(Path(os.environ.get('YUMING_SHEILA_BASE_GLB',str(Path(__file__).resolve().parents[3]/'art-inbox/studies/sheila/sheila_walk_candidate.glb'))));new,nb=load(root/'sheila_walk_normal_fitted.glb');newnodes={n['name']:n for n in new['nodes']};records=[]
for node in old['nodes']:
 if 'mesh' not in node or node['name']=='Sheila_Broken_Sword':continue
 a=old['meshes'][node['mesh']];z=new['meshes'][newnodes[node['name']]['mesh']];assert len(a['primitives'])==len(z['primitives']);maximum=0;checked=0
 for p,q in zip(a['primitives'],z['primitives']):
  pairs=[(p['indices'],q['indices'])]+[(v,q['attributes'][k]) for k,v in p['attributes'].items()]
  for t,u in zip(p.get('targets',[]),q.get('targets',[])):pairs += [(v,u[k]) for k,v in t.items()]
  for i,j in pairs:
   x=read(old,ob,i);y=read(new,nb,j);assert x.shape==y.shape;maximum=max(maximum,float(np.abs(x.astype(float)-y.astype(float)).max()));checked+=1
 records.append({'node':node['name'],'accessor_arrays_compared':checked,'maximum_component_difference':maximum});assert maximum<1e-6
report={'passed':True,'non_sword_meshes':records,'positions_normals_uv_skin_and_morph_arrays_preserved':True};(root/'non_sword_preservation.json').write_text(json.dumps(report,indent=2));print(report)
