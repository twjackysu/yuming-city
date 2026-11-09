import os
"""Append a name-mapped idle clip without re-encoding existing geometry/textures.
Complete every skin-joint TRS pose per clip to make animation switching reliable.
"""
from pathlib import Path
import json,struct,copy,numpy as np,hashlib
h=Path.home();root=Path(os.environ.get('YUMING_NOEN_IDLE_WORK',str(h/'Documents/noen-idle')))
def read(path):
 b=path.read_bytes();n=struct.unpack_from('<I',b,12)[0];return json.loads(b[20:20+n]),b[28+n:]
g,original=read(Path(os.environ.get('YUMING_NOEN_BASE_GLB',str(Path(__file__).resolve().parents[3]/'art-inbox/studies/noen/noen_walk_candidate.glb'))));idle,ib=read(root/'noen_idle_preview.glb');binary=bytearray(original);g['animations']=[a for a in g['animations'] if a.get('name')!='idle_loop'];names={n['name']:i for i,n in enumerate(g['nodes']) if 'name'in n};assert len(names)==len(g['nodes'])
def array(doc,data,index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];c={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];return np.frombuffer(data,dtype='<f4',count=a['count']*c,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(a['count'],c)
base_bind={g['nodes'][n]['name']:m for n,m in zip(g['skins'][0]['joints'],array(g,original,g['skins'][0]['inverseBindMatrices']))};idle_bind={idle['nodes'][n]['name']:m for n,m in zip(idle['skins'][0]['joints'],array(idle,ib,idle['skins'][0]['inverseBindMatrices']))};assert base_bind.keys()==idle_bind.keys();error=max(float(np.max(np.abs(base_bind[n]-idle_bind[n]))) for n in base_bind);assert error<1e-5,error
views={};accessors={}
def clone_accessor(index):
 if index in accessors:return accessors[index]
 a=copy.deepcopy(idle['accessors'][index]);vi=a['bufferView']
 if vi not in views:
  v=copy.deepcopy(idle['bufferViews'][vi]);start=v.get('byteOffset',0);blob=ib[start:start+v['byteLength']];binary.extend(b'\0'*((-len(binary))%4));v['byteOffset']=len(binary);v['buffer']=0;binary.extend(blob);views[vi]=len(g['bufferViews']);g['bufferViews'].append(v)
 a['bufferView']=views[vi];accessors[index]=len(g['accessors']);g['accessors'].append(a);return accessors[index]
for anim in idle['animations']:
 a=copy.deepcopy(anim);a['name']='idle_loop'
 for sampler in a['samplers']:
  sampler['input']=clone_accessor(sampler['input']);sampler['output']=clone_accessor(sampler['output'])
 for channel in a['channels']:channel['target']['node']=names[idle['nodes'][channel['target']['node']]['name']]
 g['animations'].append(a)
def add_array(values,kind):
 values=np.asarray(values,dtype='<f4');blob=values.tobytes();binary.extend(b'\0'*((-len(binary))%4));vi=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(blob)});binary.extend(blob);a={'bufferView':vi,'componentType':5126,'count':len(values),'type':kind}
 if kind=='SCALAR':a['min']=[float(values.min())];a['max']=[float(values.max())]
 index=len(g['accessors']);g['accessors'].append(a);return index
counts={}
for anim in g['animations']:
 source=g if anim['name']!='idle_loop' else idle
 inputs={sampler['input'] for sampler in anim['samplers']};offset=min(float(array(g,binary,i).min()) for i in inputs);normalized={i:add_array(array(g,binary,i)-offset,'SCALAR') for i in inputs}
 for sampler in anim['samplers']:sampler['input']=normalized[sampler['input']]
 source_nodes={n['name']:n for n in source['nodes'] if 'name'in n};present={(c['target']['node'],c['target']['path']) for c in anim['channels']};duration=max(g['accessors'][s['input']].get('max',[0])[0] for s in anim['samplers']);assert duration>0;time=add_array([[0],[duration]],'SCALAR');filled=0
 for node_index in g['skins'][0]['joints']:
  node=source_nodes[g['nodes'][node_index]['name']];assert 'matrix'not in node
  for path,default,kind in [('translation',[0,0,0],'VEC3'),('rotation',[0,0,0,1],'VEC4'),('scale',[1,1,1],'VEC3')]:
   if (node_index,path) in present:continue
   value=node.get(path,default);output=add_array([value,value],kind);sampler=len(anim['samplers']);anim['samplers'].append({'input':time,'output':output,'interpolation':'LINEAR'});anim['channels'].append({'sampler':sampler,'target':{'node':node_index,'path':path}});filled+=1
 counts[anim['name']]={'duration_s':duration,'start_time_offset_removed_s':offset,'constant_pose_channels_added':filled,'channels':len(anim['channels'])}
g['buffers'][0]['byteLength']=len(binary);binary.extend(b'\0'*((-len(binary))%4));data=json.dumps(g,separators=(',',':')).encode();data+=b' '*((-len(data))%4);out=struct.pack('<4sII',b'glTF',2,12+8+len(data)+8+len(binary))+struct.pack('<I4s',len(data),b'JSON')+data+struct.pack('<I4s',len(binary),b'BIN\0')+binary;(root/'noen_idle_walk_candidate.glb').write_bytes(out);assert binary[:len(original)]==original
(root/'clip_merge_report.json').write_text(json.dumps({'clips':counts,'inverse_bind_maximum_difference':error,'existing_binary_prefix_unchanged':True,'existing_binary_sha256':hashlib.sha256(original).hexdigest(),'status':'requires_engine_switching_test'},indent=2));print(counts)
