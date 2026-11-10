import os
"""Preserve existing body tracks and append the cape's corrective weights."""
from pathlib import Path
import json,struct,copy,numpy as np,hashlib
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_CAPE_WORK',str(h/'Documents/sheila-cloth-walk')))
def read(p):
 raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];return json.loads(raw[20:20+n]),raw[28+n:]
g,original=read(root/'tailored_candidate.glb');old,ob=read(Path(os.environ.get('YUMING_SHEILA_BODY_GLB',str(Path(__file__).resolve().parents[3]/'art-inbox/studies/sheila/sheila_walk_candidate.glb'))));binary=bytearray(original)
def array(doc,blob,i):
 a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];return np.frombuffer(blob,dtype='<f4',count=a['count']*n,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,n)
newbind={g['nodes'][n]['name']:m for n,m in zip(g['skins'][0]['joints'],array(g,original,g['skins'][0]['inverseBindMatrices']))};oldbind={old['nodes'][n]['name']:m for n,m in zip(old['skins'][0]['joints'],array(old,ob,old['skins'][0]['inverseBindMatrices']))};assert newbind.keys()==oldbind.keys();bind_error=max(float(np.abs(newbind[n]-oldbind[n]).max()) for n in newbind);assert bind_error<1e-5,bind_error
names={n.get('name'):i for i,n in enumerate(g['nodes'])};views={};accessors={}
def clone(i):
 if i in accessors:return accessors[i]
 a=copy.deepcopy(old['accessors'][i]);vi=a['bufferView']
 if vi not in views:
  v=copy.deepcopy(old['bufferViews'][vi]);start=v.get('byteOffset',0);blob=ob[start:start+v['byteLength']];binary.extend(b'\0'*((-len(binary))%4));v['buffer']=0;v['byteOffset']=len(binary);binary.extend(blob);views[vi]=len(g['bufferViews']);g['bufferViews'].append(v)
 a['bufferView']=views[vi];accessors[i]=len(g['accessors']);g['accessors'].append(a);return accessors[i]
def add(values,kind):
 values=np.asarray(values,dtype='<f4');binary.extend(b'\0'*((-len(binary))%4));view=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':values.nbytes});binary.extend(values.tobytes());a={'bufferView':view,'componentType':5126,'count':len(values),'type':kind}
 if kind=='SCALAR':a.update(min=[float(values.min())],max=[float(values.max())])
 i=len(g['accessors']);g['accessors'].append(a);return i
anim=copy.deepcopy(next(a for a in old['animations'] if a['name']=='walk_loop'));anim['channels']=[c for c in anim['channels'] if c['target']['path']!='weights'];offset=min(float(array(old,ob,s['input']).min()) for s in anim['samplers']);times={}
for sam in anim['samplers']:
 i=sam['input']
 if i not in times:times[i]=add(array(old,ob,i)-offset,'SCALAR')
 sam['input']=times[i];sam['output']=clone(sam['output'])
for ch in anim['channels']:ch['target']['node']=names[old['nodes'][ch['target']['node']]['name']]
node=names['Sheila_Cape'];mesh=g['meshes'][g['nodes'][node]['mesh']];values=np.load(root/'cloth_shapes.npz')['values'];expected=['CapeCloth_%02d'%i for i in range(values.shape[1])];assert mesh['extras']['targetNames']==expected,(mesh.get('extras'),expected)
time=add(np.arange(35)/30,'SCALAR');out=add(values.reshape(-1),'SCALAR');index=len(anim['samplers']);anim['samplers'].append({'input':time,'output':out,'interpolation':'LINEAR'});anim['channels'].append({'sampler':index,'target':{'node':node,'path':'weights'}});g['animations']=[anim];g['buffers'][0]['byteLength']=len(binary);binary.extend(b'\0'*((-len(binary))%4));j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);result=struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary;(root/'sheila_walk_preview.glb').write_bytes(result);report={'body_clip':'walk_loop','body_channels_preserved':len(anim['channels'])-1,'existing_body_track_values_unchanged':True,'existing_static_binary_prefix_unchanged':binary[:len(original)]==original,'inverse_bind_maximum_difference':bind_error,'body_start_offset_removed_s':offset,'duration_s':34/30,'cape_samples':35,'cape_corrective_shapes':values.shape[1],'status':'requires_engine_and_exported_mesh_validation'};(root/'cape_animation_merge.json').write_text(json.dumps(report,indent=2));print(report)
