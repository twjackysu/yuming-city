"""Add six non-deforming joint locator nodes to a rigidly skinned frame GLB.
Leaves mesh, textures, skeleton joint list and animation binary bytes unchanged.
"""
from pathlib import Path
import os,json,struct,hashlib,numpy as np
src=Path(os.environ.get('UNDERTAKER_INPUT_GLB',str(Path.home()/'Documents/undertaker-motion/undertaker_walk_preview.glb')))
out=Path(os.environ.get('UNDERTAKER_LOCATOR_WORK',str(Path.home()/'Documents/undertaker-joint-locators')));out.mkdir(exist_ok=True)
raw=src.read_bytes();length=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+length]);binary_chunk=raw[20+length:];binary=binary_chunk[8:]
def accessor(index):
 a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];dtype=np.dtype({5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]);c={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 return np.ndarray((a['count'],c),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',c*dtype.itemsize),dtype.itemsize)).copy()
frame=next(i for i,n in enumerate(g['nodes']) if n.get('name')=='frame_root');mesh_node=next(n for n in g['nodes'] if n.get('name')=='Frame_Joint_Weakpoints');skin=g['skins'][mesh_node['skin']];joint_index=skin['joints'].index(frame);inverse=accessor(skin['inverseBindMatrices'])[joint_index].reshape(4,4).T
vertices=[]
for p in g['meshes'][mesh_node['mesh']]['primitives']:
 assert g['materials'][p['material']]['name']=='M_FrameJoint'
 pos=accessor(p['attributes']['POSITION']);bones=accessor(p['attributes']['JOINTS_0']);weights=accessor(p['attributes']['WEIGHTS_0']);assert np.all(bones[weights>1e-6]==joint_index);assert np.allclose(weights.max(axis=1),1)
 vertices.append(pos)
vertices=np.concatenate(vertices);records=[]
for side,sign in [('L',-1),('R',1)]:
 for level,height in enumerate([1.18,1.82,2.55]):
  selected=vertices[(vertices[:,0]*sign>0)&(abs(vertices[:,1]-height)<.09)];assert len(selected)>20
  lo=selected.min(axis=0);hi=selected.max(axis=0);center=(lo+hi)/2;assert abs(abs(center[0])-.4)<.01 and abs(center[1]-height)<.01
  local=(inverse@np.r_[center,1])[:3];name=f'FrameJoint_{side}{level}';assert not any(n.get('name')==name for n in g['nodes'])
  index=len(g['nodes']);g['nodes'].append({'name':name,'translation':local.tolist(),'extras':{'purpose':'weakpoint_hit_target','frame_joint_side':side,'frame_joint_level':level,'suggested_radius_m':.07}});g['nodes'][frame].setdefault('children',[]).append(index)
  records.append({'name':name,'parent_bone':'frame_root','bone_local_position':local.tolist(),'bind_mesh_center':center.tolist(),'mesh_vertices':len(selected)})
encoded=json.dumps(g,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);result=struct.pack('<4sII',b'glTF',2,12+8+len(encoded)+len(binary_chunk))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+binary_chunk
output=out/'undertaker_walk_preview.glb';output.write_bytes(result)
report={'locators':records,'skinning_joints':len(skin['joints']),'binary_payload_unchanged':True,'input_sha256':hashlib.sha256(raw).hexdigest(),'output_sha256':hashlib.sha256(result).hexdigest(),'binary_sha256':hashlib.sha256(binary_chunk).hexdigest(),'status':'work_in_progress_not_final_art'};(out/'joint_locators.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
