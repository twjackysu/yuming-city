import os
from pathlib import Path
import json,struct,numpy as np
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_CAPE_WORK',str(h/'Documents/sheila-cloth-walk')));p=root/'sheila_walk_preview.glb';raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=bytearray(raw[28+n:]);mesh=next(m for m in g['meshes'] if m.get('name')=='Sheila_Cape');prim=mesh['primitives'][0];types={5126:'<f4',5123:'<u2',5125:'<u4'};sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def read(i):
 a=g['accessors'][i];c=sizes[a['type']];out=np.zeros((a['count'],c),dtype=types[a['componentType']])
 if 'bufferView' in a:
  v=g['bufferViews'][a['bufferView']];out[:]=np.frombuffer(binary,dtype=types[a['componentType']],count=a['count']*c,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,c)
 if 'sparse' in a:
  sp=a['sparse'];ix=sp['indices'];v=g['bufferViews'][ix['bufferView']];indices=np.frombuffer(binary,dtype=types[ix['componentType']],count=sp['count'],offset=v.get('byteOffset',0)+ix.get('byteOffset',0));val=sp['values'];v=g['bufferViews'][val['bufferView']];out[indices]=np.frombuffer(binary,dtype=types[a['componentType']],count=sp['count']*c,offset=v.get('byteOffset',0)+val.get('byteOffset',0)).reshape(-1,c)
 return out
base=read(prim['attributes']['POSITION']);norm=read(prim['attributes']['NORMAL']);tri=read(prim['indices']).reshape(-1,3);deltas=np.array([read(t['POSITION']) for t in prim['targets']]);oldnorm=np.array([read(t['NORMAL']) for t in prim['targets']]);weights=np.load(root/'cloth_shapes.npz')['values'];weld,inv=np.unique(np.round(base,6),axis=0,return_inverse=True);tri_weld=inv[tri]
def geometric(v):
 f=np.cross(v[tri[:,1]]-v[tri[:,0]],v[tri[:,2]]-v[tri[:,0]]);accum=np.zeros((len(weld),3))
 for i in range(3):np.add.at(accum,tri_weld[:,i],f)
 accum/=np.maximum(np.linalg.norm(accum,axis=1,keepdims=True),1e-12);return accum[inv]
geo_base=geometric(base);positions=base[None]+np.einsum('fk,knc->fnc',weights,deltas);desired=np.array([geometric(v) for v in positions]);target=(desired-geo_base).reshape(len(weights),-1);fit=np.linalg.lstsq(weights,target,rcond=1e-6)[0].reshape(oldnorm.shape);old_recon=norm+np.einsum('fk,knc->fnc',weights,oldnorm);new_recon=norm+np.einsum('fk,knc->fnc',weights,fit)
def angles(v):
 v=v/np.maximum(np.linalg.norm(v,axis=2,keepdims=True),1e-12);return np.degrees(np.arccos(np.clip((v*desired).sum(axis=2),-1,1)))
a,b=angles(old_recon),angles(new_recon)
def add(v):
 v=np.asarray(v,dtype='<f4');binary.extend(b'\0'*((-len(binary))%4));view=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':v.nbytes});binary.extend(v.tobytes());i=len(g['accessors']);g['accessors'].append({'bufferView':view,'componentType':5126,'count':len(v),'type':'VEC3'});return i
for i,t in enumerate(prim['targets']):t['NORMAL']=add(fit[i]);t.pop('TANGENT',None)
g['buffers'][0]['byteLength']=len(binary);binary.extend(b'\0'*((-len(binary))%4));j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);out=struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary;(root/'sheila_walk_normal_fitted.glb').write_bytes(out);report={'samples':35,'shapes':len(fit),'before_mean_normal_error_degrees':float(a.mean()),'before_p99_normal_error_degrees':float(np.percentile(a,99)),'after_mean_normal_error_degrees':float(b.mean()),'after_p99_normal_error_degrees':float(np.percentile(b,99)),'positions_and_animation_unchanged':True};(root/'cape_normal_fit.json').write_text(json.dumps(report,indent=2));print(report);bounds=np.linalg.norm(deltas,axis=2).max(axis=1);(root/'cape_delta_bounds.json').write_text(json.dumps(bounds.tolist()))
